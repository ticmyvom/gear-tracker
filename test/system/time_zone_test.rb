require "application_system_test_case"

class TimeZoneTest < ApplicationSystemTestCase
  def browser_zone = page.evaluate_script("Intl.DateTimeFormat().resolvedOptions().timeZone")

  test "signing in fills in a missing time zone from the browser" do
    sign_in_as users(:one)

    assert_equal browser_zone, users(:one).reload.time_zone
  end

  test "settings suggest the browser's time zone until one is saved" do
    sign_in_as users(:one)
    users(:one).update!(time_zone: nil)
    visit edit_settings_path

    assert_equal browser_zone, find_field("Time zone").value
  end
end
