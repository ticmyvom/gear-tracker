module Api
  module V1
    # Serves docs/api.md as plain text, so people and agents can read it without a token.
    class DocsController < ActionController::API
      def show
        render plain: Rails.root.join("docs/api.md").read, content_type: "text/plain"
      end
    end
  end
end
