require "test_helper"
require "rake"

# Checks the production and deploy configuration for the promises the app
# makes: data on a persistent volume, backups that keep deleted data only as
# long as the privacy page says, HTTPS, rotated logs, and no secrets in git.
class DeploymentTest < ActiveSupport::TestCase
  def deploy = YAML.load(ERB.new(Rails.root.join("config/deploy.yml").read).result)
  def database = YAML.load(ERB.new(Rails.root.join("config/database.yml").read).result, aliases: true)
  def litestream = YAML.load_file(Rails.root.join("config/litestream.yml"))

  # --- Data and backups ---

  test "every production database lives in storage/, which is the persistent volume" do
    assert_equal %w[ cache primary queue ], database["production"].keys.sort
    database["production"].each_value { |config| assert_match %r{\Astorage/[\w.]+\.sqlite3\z}, config["database"] }
    assert_includes deploy["volumes"].map { it.split(":").last }, "/rails/storage"
  end

  test "Litestream backs up the main production database" do
    paths = litestream["dbs"].map { it["path"] }

    assert_equal [ "/rails/#{database["production"]["primary"]["database"]}" ], paths
    assert_equal "s3", litestream["dbs"].first.dig("replica", "type")
  end

  test "backups upload rarely enough to stay inside R2's free tier" do
    seconds = litestream["dbs"].first.dig("replica", "sync-interval")[/\A(\d+)s\z/, 1].to_i
    uploads_a_month = 30.days / seconds

    assert_operator uploads_a_month, :<=, 300_000, "leaves room under R2's 1 million free uploads for compaction"
  end

  test "backups keep deleted data no longer than the privacy page says" do
    days = Rails.configuration.x.backup_retention_days

    assert_equal "#{days * 24}h", litestream.dig("snapshot", "retention")
    assert_operator litestream.dig("snapshot", "interval").to_i, :<=, days * 24
  end

  test "the database is backed up before deploys change it" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("db:prepare")

    assert_includes Rake::Task["db:prepare"].prerequisites, "backup_before_migrate"
    assert_includes Rake::Task["db:migrate"].prerequisites, "backup_before_migrate"
  end

  # --- Serving the site ---

  test "the site is served over HTTPS, with the host set in one place" do
    assert deploy.dig("proxy", "ssl")
    assert_equal deploy.dig("proxy", "host"), deploy.dig("env", "clear", "APP_HOST")
  end

  test "container logs are rotated, so they're only kept briefly" do
    options = deploy.dig("logging", "options")

    assert_match(/\A\d+m\z/, options["max-size"])
    assert_operator options["max-file"].to_i, :<=, 5
  end

  test "the app doesn't deploy as root" do
    assert_not_equal "root", deploy.dig("ssh", "user").to_s
    assert deploy.dig("ssh", "user").present?
  end

  # --- Secrets ---

  test "secrets are passed as secrets, never as plain settings" do
    clear = deploy.dig("env", "clear").keys
    secret = deploy.dig("env", "secret")

    assert_empty clear.grep(/PASSWORD|SECRET|KEY\b|_KEY_|TOKEN/)
    assert_includes secret, "RAILS_MASTER_KEY"
    assert_includes secret, "SMTP_PASSWORD"
    assert_includes secret, "LITESTREAM_SECRET_ACCESS_KEY"
  end

  test "the Kamal secrets file only refers to secrets, never contains them" do
    lines = Rails.root.join(".kamal/secrets").readlines(chomp: true).reject { it.blank? || it.start_with?("#") }

    assert lines.any?
    lines.each { assert_match(/\A[A-Z_]+=\$/, it, "#{it.split("=").first} must come from ENV or a command, not a value") }
  end

  test "the Docker image leaves out secrets and local data, but keeps the API docs" do
    ignored = Rails.root.join(".dockerignore").readlines(chomp: true)

    [ "/config/master.key", "/.env*", "/storage/*", "/.kamal" ].each { assert_includes ignored, it }
    assert_not ignored.any? { File.fnmatch?(it.delete_prefix("/"), "docs/api.md") || it == "/docs" || it == "/docs/" }
  end
end
