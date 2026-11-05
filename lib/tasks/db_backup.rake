namespace :db do
  def database_path
    Rails.root.join(ActiveRecord::Base.connection_db_config.database)
  end

  def backup_database
    backup_path = Rails.root.join("storage/backups", "#{Rails.env}-#{Time.current.strftime('%Y%m%d-%H%M%S-%L')}.sqlite3")
    FileUtils.mkdir_p(backup_path.dirname)
    # VACUUM INTO takes a consistent copy, even while the server is running.
    ActiveRecord::Base.lease_connection.execute("VACUUM INTO #{ActiveRecord::Base.lease_connection.quote(backup_path.to_s)}")
    puts "Backed up database to #{backup_path.relative_path_from(Rails.root)}"
  end

  desc "Copy the database to storage/backups"
  task backup: :load_config do
    backup_database
  end

  desc "Replace the database with a backup: bin/rails db:restore FILE=storage/backups/name.sqlite3 (stop the server first)"
  task restore: %i[ load_config check_protected_environments ] do
    file = ENV.fetch("FILE") { abort "Pass the backup to restore: bin/rails db:restore FILE=storage/backups/name.sqlite3" }
    backup_path = Rails.root.join(file)
    abort "No backup found at #{file}" unless backup_path.file?

    # Catches a wrong or damaged file before anything is replaced.
    begin
      SQLite3::Database.new(backup_path.to_s, readonly: true) do |db|
        abort "#{file} is damaged" unless db.get_first_value("PRAGMA integrity_check") == "ok"
      end
    rescue SQLite3::Exception
      abort "#{file} isn't a SQLite database"
    end

    backup_database if database_path.file?
    ActiveRecord::Base.connection_handler.clear_all_connections!(:all)

    # Leftover write-ahead files belong to the old database and must not be applied to the backup.
    FileUtils.rm_f([ "#{database_path}-wal", "#{database_path}-shm" ])
    FileUtils.cp(backup_path, database_path)

    puts "Restored #{file}. Run bin/rails db:migrate if the backup is older than the current code."
  end

  task backup_before_migrate: :load_config do
    next unless database_path.file? && ActiveRecord::Base.connection_pool.migration_context.needs_migration?

    backup_database
  end

  task migrate: :backup_before_migrate
  task rollback: :backup
end
