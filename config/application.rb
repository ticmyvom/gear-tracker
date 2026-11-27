require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module GearTracker
  # Semantic versioning (major.minor.patch); see the VERSION file and CHANGELOG.md.
  VERSION = File.read(File.expand_path("../VERSION", __dir__)).strip
  # The code and its documentation; the README is the table of contents.
  REPOSITORY_URL = "https://github.com/ticmyvom/gear-tracker".freeze

  class Application < Rails::Application
    # How long backups keep deleted data; the privacy page promises this.
    config.x.backup_retention_days = 7
    # Local backups in storage/backups are kept forever unless set (production sets it).
    config.x.local_backup_retention_days = nil

    # Who emails come from; production sets the real address.
    config.x.mail_from = "Gear Tracker <no-reply@example.com>"

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
