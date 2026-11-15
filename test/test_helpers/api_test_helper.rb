module ApiTestHelper
  extend ActiveSupport::Concern

  included do
    # Each test starts with a fresh request count, so rate limits don't carry over.
    setup { Rails.configuration.x.rate_limit_store&.clear }
  end

  # Fixture tokens: "gt_one_write", "gt_one_read" and "gt_two_write".
  def api_headers(token = "gt_one_write")
    { "Authorization" => "Bearer #{token}" }
  end

  def json
    response.parsed_body
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include ApiTestHelper
end
