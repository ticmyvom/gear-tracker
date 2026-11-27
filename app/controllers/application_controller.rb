class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  # After saving a record, the section of the gear page to go back to; see section_heading.
  add_flash_types :section
  # Dates like "today" follow the signed-in user's time zone, not the server's.
  around_action { |_, action| authenticated? ? Current.user.in_time_zone(&action) : action.call }

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
