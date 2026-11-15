require "test_helper"
require "rake"

class DemoTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("demo:reset")
    Rake::Task["demo:reset"].reenable
  end

  test "demo:reset refuses to wipe the database unless demo mode is on" do
    ENV.delete("GEAR_TRACKER_DEMO")

    assert_raises(SystemExit) { capture_io { Rake::Task["demo:reset"].invoke } }
    assert User.exists?(users(:one).id)
  end
end
