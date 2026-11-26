require "application_system_test_case"

class GearSectionsTest < ApplicationSystemTestCase
  setup do
    @gear = gears(:prius)
    # Enough entries that the page has to scroll to reach the lower sections.
    25.times { @gear.fuel_entries.create!(entered_amount: 10, filled_on: Date.current - it) }
    sign_in_as users(:one)
  end

  # The heading is at the top of the window, or as near as the page can scroll,
  # and the address ends in #id, so reloading stays there.
  def assert_at_section(id)
    page.document.synchronize do
      top, max = page.evaluate_script(<<~JS)
        [ (document.getElementById("#{id}")?.getBoundingClientRect().top ?? NaN) + window.scrollY,
          document.documentElement.scrollHeight - window.innerHeight ]
      JS
      wanted = [ top, max ].min if top # nil until the gear page has loaded
      unless wanted&.positive? && URI(current_url).fragment == id && (scrolled - wanted).abs <= 5
        raise Capybara::ExpectationNotMet, "expected the #{id} heading at the top of the window (#{wanted}), was #{scrolled}, at #{current_url}"
      end
    end
  end

  test "saving an expense goes back to the expenses" do
    visit gear_path(@gear)
    click_on "Add expense"
    fill_in "Description", with: "Car wash"
    fill_in "expense[amount]", with: "12"
    click_on "Create Expense"

    assert_text "Car wash"
    assert_at_section "expenses"

    refresh
    assert_at_section "expenses"
  end

  test "deleting a reading goes back to the readings" do
    visit edit_gear_reading_path(@gear, readings(:pressure))
    accept_confirm { click_on "Delete reading" }

    assert_text "Reading deleted."
    assert_no_text "Tire pressure FL"
    assert_at_section "readings"
  end

  test "an ordinary visit starts at the top" do
    visit gear_path(@gear)
    assert_equal 0, scrolled
  end

  test "editing a fuel entry and cancelling both go back to the fuel log" do
    visit gear_path(@gear)
    first(:link, "Edit", href: %r{/fuel_entries/}).click
    click_on "Save fuel entry"
    assert_at_section "fuel_entries"

    visit gear_path(@gear)
    click_on "Add reading"
    click_on "Cancel"
    assert_at_section "readings"
  end
end
