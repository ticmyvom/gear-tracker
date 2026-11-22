require "test_helper"
require "backup_drill"

# bin/backup-drill needs R2 and the live server, so these tests cover its
# checks; running it for real is the drill itself.
class BackupDrillTest < ActiveSupport::TestCase
  def with_database(path)
    db = SQLite3::Database.new(path)
    db.execute_batch("CREATE TABLE gears (name TEXT); INSERT INTO gears VALUES ('a'), ('b'); CREATE TABLE users (email TEXT);")
    db.close
  end

  test "counts the rows in every table of an undamaged copy" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "copy.sqlite3")
      with_database(path)

      assert_equal({ "gears" => 2, "users" => 0 }, BackupDrill.counts(path))
    end
  end

  test "fails on a damaged or unreadable copy" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "copy.sqlite3")
      File.write(path, "not a database" * 100)

      error = assert_raises(BackupDrill::Failed) { BackupDrill.counts(path) }
      assert_match "can't be read", error.message
    end
  end

  test "lists the tables whose counts differ" do
    assert_empty BackupDrill.differences({ "gears" => 2 }, { "gears" => 2 })
    assert_equal({ "gears" => [ 2, 3 ], "users" => [ nil, 1 ] }, BackupDrill.differences({ "gears" => 2 }, { "gears" => 3, "users" => 1 }))
  end

  test "stops before doing anything when the secrets aren't loaded" do
    BackupDrill::SECRETS.each { ENV.delete(it) } # tests never have real secrets

    error = assert_raises(BackupDrill::Failed) { BackupDrill.new(out: StringIO.new).run }
    assert_match "source ~/.config/gear-tracker/production.env", error.message
  end

  test "reads the server and database from the deploy and Litestream config" do
    drill = BackupDrill.new(out: StringIO.new)

    assert_equal "/rails/storage/production.sqlite3", drill.database
    assert_equal "deploy", drill.deploy.dig("ssh", "user")
  end

  test "the command is executable and valid Ruby" do
    command = Rails.root.join("bin/backup-drill")

    assert command.executable?
    assert system("ruby", "-c", command.to_s, out: File::NULL)
  end
end
