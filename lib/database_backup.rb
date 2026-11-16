# Copies the database into a backup folder, before migrations and on request
# (see lib/tasks/db_backup.rake). With keep_days set, as in production, it also
# deletes backups older than that, so deleted data doesn't linger longer than
# the privacy page promises.
class DatabaseBackup
  def initialize(dir: Rails.root.join("storage/backups"), keep_days: Rails.configuration.x.local_backup_retention_days)
    @dir = Pathname(dir)
    @keep_days = keep_days
  end

  def create
    path = @dir.join("#{Rails.env}-#{Time.current.strftime('%Y%m%d-%H%M%S-%L')}.sqlite3")
    FileUtils.mkdir_p(@dir)
    # VACUUM INTO takes a consistent copy, even while the server is running.
    connection.execute("VACUUM INTO #{connection.quote(path.to_s)}")
    prune(older_than_days: @keep_days) if @keep_days
    path
  end

  def prune(older_than_days:)
    cutoff = older_than_days.days.ago
    @dir.glob("*.sqlite3").select { it.mtime < cutoff }.each(&:delete)
  end

  private
    def connection
      ActiveRecord::Base.lease_connection
    end
end
