# Public pages that ask search engines not to list them.
module NotIndexed
  extend ActiveSupport::Concern

  included do
    before_action { response.headers["X-Robots-Tag"] = "noindex" }
  end
end
