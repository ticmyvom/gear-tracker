require "erb"
require "json"
require "open3"
require "sqlite3"
require "tmpdir"
require "yaml"

# Proves the off-site backups work: restores the latest backup from R2 into a
# private temporary folder, checks the copy isn't damaged, compares its row
# counts with the live database, then deletes it. It prints only counts, never
# anyone's data. Run it with bin/backup-drill (see docs/hosting.md, step 12).
class BackupDrill
  class Failed < StandardError; end

  ROOT = File.expand_path("..", __dir__)
  SECRETS = %w[ LITESTREAM_REPLICA_BUCKET LITESTREAM_REPLICA_ENDPOINT LITESTREAM_ACCESS_KEY_ID LITESTREAM_SECRET_ACCESS_KEY ].freeze

  # Runs on the server through bin/rails runner, and prints each table's row count as JSON.
  LIVE_COUNTS = <<~RUBY
    c = ActiveRecord::Base.connection
    puts c.tables.sort.to_h { [ it, c.select_value("SELECT COUNT(*) FROM \#{c.quote_table_name(it)}") ] }.to_json
  RUBY

  def self.config(name, erb: false)
    text = File.read(File.join(ROOT, "config", name))
    YAML.load(erb ? ERB.new(text).result : text)
  end

  # Each table's row count, after checking the file isn't damaged.
  def self.counts(path)
    db = SQLite3::Database.new(path, readonly: true)
    result = db.get_first_value("PRAGMA integrity_check")
    raise Failed, "The restored copy is damaged: #{result}" unless result == "ok"

    tables = db.execute("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name").flatten
    tables.to_h { [ it, db.get_first_value("SELECT COUNT(*) FROM \"#{it}\"") ] }
  rescue SQLite3::Exception => error
    raise Failed, "The restored copy can't be read: #{error.message}"
  ensure
    db&.close
  end

  # Tables whose counts differ, as { table => [restored, live] }.
  def self.differences(restored, live)
    (restored.keys | live.keys).sort.filter_map { [ it, [ restored[it], live[it] ] ] unless restored[it] == live[it] }.to_h
  end

  attr_reader :deploy, :database

  def initialize(out: $stdout)
    @out = out
    @deploy = self.class.config("deploy.yml", erb: true)
    @database = self.class.config("litestream.yml").dig("dbs", 0, "path")
  end

  def run
    missing = SECRETS.reject { ENV[it].to_s.strip.length.positive? }
    raise Failed, "Missing #{missing.join(", ")}. Load the secrets first: source ~/.config/gear-tracker/production.env" if missing.any?

    Dir.mktmpdir("backup-drill-") do |dir| # private to you, and deleted at the end, even after an error
      copy = File.join(dir, "restored.sqlite3")
      say "Restoring the latest backup of #{@database} from R2..."
      restore(copy)
      restored = self.class.counts(copy)
      say "The copy isn't damaged. Comparing it with the live database..."
      report(restored, live_counts)
    end
  end

  private
    def say(text) = @out.puts(text)

    def restore(copy)
      output, status = Open3.capture2e("bundle", "exec", "litestream", "restore", "-config", "config/litestream.yml", "-o", copy, @database, chdir: ROOT)
      raise Failed, "Litestream couldn't restore:\n#{output}" unless status.success? && File.exist?(copy)
    end

    def live_counts
      host = Array(@deploy.dig("servers", "web")).first
      container = "$(docker ps -q -f label=service=#{@deploy["service"]} -f label=role=web | head -1)"
      output, status = Open3.capture2e("ssh", "#{@deploy.dig("ssh", "user")}@#{host}", "docker exec -i #{container} bin/rails runner -", stdin_data: LIVE_COUNTS)
      raise Failed, "Couldn't read the live database:\n#{output}" unless status.success?

      JSON.parse(output.lines.last.to_s)
    rescue JSON::ParserError
      raise Failed, "The live database's counts didn't come back as expected:\n#{output}"
    end

    def report(restored, live)
      width = restored.keys.map(&:length).max
      say format("  %-#{width}s  %8s  %8s", "table", "backup", "live")
      restored.each_key { say format("  %-#{width}s  %8d  %8s", it, restored[it], live.fetch(it, "-")) }

      differences = self.class.differences(restored, live)
      if differences.empty?
        say "PASSED: the backup matches the live database. The copy was deleted."
      else
        raise Failed, "The backup differs from the live database in: #{differences.keys.join(", ")}. " \
          "If someone used the site in the last minute, wait a minute and run it again."
      end
    end
end
