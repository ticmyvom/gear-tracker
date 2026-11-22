require "test_helper"
require "rake"
require "open3"

# Checks the production and deploy configuration for the promises the app
# makes: data on a persistent volume, backups that keep deleted data only as
# long as the privacy page says, HTTPS, rotated logs, and no secrets in git.
class DeploymentTest < ActiveSupport::TestCase
  def deploy = YAML.load(ERB.new(Rails.root.join("config/deploy.yml").read).result)
  def database = YAML.load(ERB.new(Rails.root.join("config/database.yml").read).result, aliases: true)
  def litestream = YAML.load_file(Rails.root.join("config/litestream.yml"))

  # Litestream durations are written like "10s", "5m" or "1h30m".
  DURATION_UNITS = { "h" => 1.hour, "m" => 1.minute, "s" => 1.second }

  def duration(text)
    parts = text.to_s.scan(/(\d+)([hms])/)
    assert parts.any? && parts.join == text, "can't read the duration #{text.inspect}"
    parts.sum(0.seconds) { |amount, unit| amount.to_i * DURATION_UNITS[unit] }
  end

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
    uploads_a_month = 30.days / duration(litestream["dbs"].first.dig("replica", "sync-interval"))

    assert_operator uploads_a_month, :<=, 300_000, "leaves room under R2's 1 million free uploads for compaction"
  end

  test "backups keep deleted data no longer than the privacy page says" do
    days = Rails.configuration.x.backup_retention_days.days

    assert_equal days, duration(litestream.dig("snapshot", "retention"))
    assert_operator duration(litestream.dig("snapshot", "interval")), :<=, days
  end

  test "reads Litestream durations, and refuses ones it doesn't understand" do
    assert_equal 10.seconds, duration("10s")
    assert_equal 90.minutes, duration("1h30m")
    assert_equal 168.hours, duration("168h")
    [ "500ms", "7d", "10", nil ].each do |text|
      assert_raises(Minitest::Assertion) { duration(text) }
    end
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

  test "deploying stops if a secret from the shell isn't loaded, naming it" do
    hook = Rails.root.join(".kamal/hooks/pre-deploy").to_s
    names = Rails.root.join(".kamal/secrets").read.scan(/^([A-Z_]+)=\$\1$/).flatten
    assert_includes names, "LITESTREAM_REPLICA_BUCKET"
    all_set = names.to_h { [ it, "x" ] }

    _, error, status = Open3.capture3(all_set.merge("LITESTREAM_REPLICA_BUCKET" => ""), hook)
    assert_not status.success?
    assert_match "missing LITESTREAM_REPLICA_BUCKET.", error

    assert Open3.capture3(all_set, hook).last.success?
  end
end
