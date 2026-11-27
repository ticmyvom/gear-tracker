require "application_system_test_case"

class GearSectionsTest < ApplicationSystemTestCase
  setup do
    @gear = gears(:prius)
    # Enough entries that the page has to scroll to reach the lower sections.
    25.times { @gear.fuel_entries.create!(entered_amount: 10, filled_on: Date.current - it) }
    sign_in_as users(:one)
  end

  # The heading is near the top of the window, or as near as the page can scroll,
  # and the address ends in #id, so reloading stays there.
  def assert_at_section(id)
    page.document.synchronize do
      # The heading stops its scroll margin below the top, clear of the section nav.
      top, max = page.evaluate_script(<<~JS)
        (heading => [ heading && heading.getBoundingClientRect().top + window.scrollY - parseFloat(getComputedStyle(heading).scrollMarginTop),
          document.documentElement.scrollHeight - window.innerHeight ])(document.getElementById("#{id}"))
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

  test "keys jump to each section, but not while typing" do
    visit gear_path(@gear)

    find("body").send_keys("r")
    assert_at_section "readings"
    find("body").send_keys("e")
    assert_at_section "expenses"
    find("body").send_keys("f")
    assert_at_section "fuel_entries"
    find("body").send_keys("c")
    assert_at_section "components"
    find("body").send_keys("s")
    assert_at_section "stats"

    # The gear page has no text fields yet, so this adds one to type in.
    visit gear_path(@gear)
    page.execute_script('document.querySelector("h1").insertAdjacentHTML("afterend", "<input id=typing>")')
    fill_in "typing", with: "scfer"
    assert_field "typing", with: "scfer"
    assert_equal 0, scrolled
  end

  test "the section nav stays in view while scrolling" do
    visit gear_path(@gear)
    click_on "Readings"
    assert_at_section "readings"

    assert_operator page.evaluate_script('document.querySelector(".section-nav").getBoundingClientRect().top'), :>=, 0
    click_on "Expenses"
    assert_at_section "expenses"
  end
end
