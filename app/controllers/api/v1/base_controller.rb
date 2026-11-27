module Api
  module V1
    # The JSON API for agents and scripts. It signs in only with a personal
    # access token in the Authorization header, never with the browser's session
    # cookie, so other websites can't make requests on a user's behalf.
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      # Raised when a request sends a field the endpoint doesn't accept.
      class InvalidFields < StandardError; end

      # Fields come straight from the JSON body, not nested under a key.
      wrap_parameters false

      before_action { response.headers["Cache-Control"] = "no-store" }
      # Counts requests per IP address before checking the token, so guessing is slowed down too.
      rate_limit to: 100, within: 1.minute, store: Rails.configuration.x.rate_limit_store || Rails.cache,
        with: -> { render_error :too_many_requests, "Too many requests. Try again in a minute." }
      before_action :authenticate
      before_action :require_write_permission, unless: -> { request.get? || request.head? }
      # A date left out, like a fuel entry's, means today in the user's time zone.
      around_action { |_, action| current_user.in_time_zone(&action) }

      rescue_from ActiveRecord::RecordNotFound, with: -> { render_error :not_found, "Not found" }
      rescue_from ActionDispatch::Http::Parameters::ParseError, with: -> { render_error :bad_request, "Request body isn't valid JSON" }
      rescue_from InvalidFields, with: ->(error) { render_error :unprocessable_content, error.message }

      private
        attr_reader :current_user, :current_api_token

        def authenticate
          @current_api_token = authenticate_with_http_token { |token| ApiToken.authenticate(token) }

          if current_api_token
            current_api_token.used!
            @current_user = current_api_token.user
          else
            response.headers["WWW-Authenticate"] = %(Bearer realm="Gear Tracker")
            render_error :unauthorized, "Missing or invalid API token"
          end
        end

        def require_write_permission
          render_error :forbidden, "This token is read-only" unless current_api_token.write?
        end

        # The JSON body's fields, rejecting any not in the list, so a typo like
        # "ammount" or an attempt to set "user_id" is reported, not silently ignored.
        def body_params(fields)
          unknown = request.request_parameters.keys - fields.map(&:to_s)
          raise InvalidFields, "Unknown field#{"s" if unknown.many?}: #{unknown.join(", ")}. Allowed: #{fields.join(", ")}" if unknown.any?

          params.permit(*fields).to_h
        end

        # Dates must be YYYY-MM-DD; anything else would otherwise be quietly dropped.
        def check_date(value, field)
          Date.iso8601(value.to_s) if value.present?
        rescue Date::Error
          raise InvalidFields, "#{field} must be a date like 2026-01-31"
        end

        def render_error(status, message, details = nil)
          render json: { error: message, details: details }.compact, status: status
        end

        def render_invalid(record)
          render_error :unprocessable_content, record.errors.full_messages.to_sentence, record.errors.to_hash
        end
    end
  end
end
