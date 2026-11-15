namespace :demo do
  desc "Wipe the database and load the demo (only with GEAR_TRACKER_DEMO=1, never in production)"
  task reset: :environment do
    abort "demo:reset wipes the database, so it only runs with GEAR_TRACKER_DEMO=1, and never in production." unless Demo.enabled?

    Rake::Task["db:schema:load"].invoke
    Demo.load!
    puts "Demo ready. Sign in as #{Demo::EMAIL} with password #{Demo::PASSWORD}"
  end
end
