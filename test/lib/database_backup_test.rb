require "test_helper"

class DatabaseBackupTest < ActiveSupport::TestCase
  # VACUUM INTO can't run inside the transaction each test normally gets.
  self.use_transactional_tests = false

  setup do
    @dir = Pathname(Dir.mktmpdir)
    @backup = DatabaseBackup.new(dir: @dir)
  end

  teardown { FileUtils.rm_rf(@dir) }

  test "create copies the database into the backup folder" do
    path = @backup.create

    assert path.file?
    assert_equal @dir, path.dirname
    SQLite3::Database.new(path.to_s, readonly: true) do |db|
      assert_equal "ok", db.get_first_value("PRAGMA integrity_check")
      assert_operator db.get_first_value("SELECT COUNT(*) FROM gears"), :>, 0
    end
  end

  test "prune deletes backups older than the given number of days, and keeps newer ones and other files" do
    old = @dir.join("test-old.sqlite3").tap { FileUtils.touch(it, mtime: 8.days.ago.to_time) }
    recent = @dir.join("test-recent.sqlite3").tap { FileUtils.touch(it, mtime: 6.days.ago.to_time) }
    other = @dir.join("notes.txt").tap { FileUtils.touch(it, mtime: 30.days.ago.to_time) }

    @backup.prune(older_than_days: 7)

    assert_not old.exist?
    assert recent.exist?
    assert other.exist?
  end

  test "create prunes old backups when a retention is set" do
    old = @dir.join("test-old.sqlite3").tap { FileUtils.touch(it, mtime: 8.days.ago.to_time) }

    DatabaseBackup.new(dir: @dir, keep_days: 7).create

    assert_not old.exist?
    assert_equal 1, @dir.glob("*.sqlite3").size
  end

  test "create keeps every backup when no retention is set, as in development" do
    old = @dir.join("test-old.sqlite3").tap { FileUtils.touch(it, mtime: 400.days.ago.to_time) }

    @backup.create

    assert old.exist?
  end

  test "production keeps local backups only as long as the privacy page promises" do
    production = Rails.root.join("config/environments/production.rb").read

    assert_match "config.x.local_backup_retention_days = config.x.backup_retention_days", production
    assert_nil Rails.configuration.x.local_backup_retention_days
  end
end
