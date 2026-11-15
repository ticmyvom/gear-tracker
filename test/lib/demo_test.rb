require "test_helper"

class DemoTest < ActiveSupport::TestCase
  setup { Demo.load! }

  def demo_user = User.find_by!(email_address: Demo::EMAIL)

  test "the demo user can sign in, in dollars, miles and US gallons" do
    assert User.authenticate_by(email_address: Demo::EMAIL, password: Demo::PASSWORD)
    assert_equal %w[ USD mi us_gal ], demo_user.values_at(:currency, :distance_unit, :volume_unit)
  end

  test "the heated mattress pad used 32 W over 9 hours" do
    pad = demo_user.gears.find_by!(name: "Heated mattress pad")
    night = pad.fuel_entries.order(:filled_on).last

    assert_equal "electric", pad.power_source
    assert_equal 540, night.minutes
    assert_in_delta 32, night.usage_rate, 0.01
  end

  test "the Prius Prime is a plug-in hybrid at 150,000 miles with gas and charging entries" do
    prius = demo_user.gears.find_by!(name: "2020 Toyota Prius Prime")
    entries = prius.fuel_entries.order(:filled_on)

    assert_equal "plug_in_hybrid", prius.power_source
    assert_equal BigDecimal("150000"), entries.last.entered_odometer
    assert_equal %w[ energy fuel ], entries.map(&:kind).uniq.sort
    assert_operator entries.count, :>=, 4
    entries.select { it.kind == "fuel" && it.distance_per_unit }.each do |fill_up|
      assert_in_delta 54, fill_up.distance_per_unit, 2, "a Prius Prime gets about 54 mpg"
    end
  end

  test "odometer readings only go up" do
    odometers = demo_user.gears.find_by!(name: "2020 Toyota Prius Prime").fuel_entries.order(:filled_on).map(&:entered_odometer)

    assert_equal odometers.sort, odometers
  end

  test "shows the other kinds of gear too" do
    sources = demo_user.gears.pluck(:power_source)

    assert_includes sources, "manual"
    assert_includes sources, nil
    assert demo_user.gears.find_by!(name: "2020 Toyota Prius Prime").components.any?
  end

  test "dates are recent, so the demo always looks current" do
    latest = FuelEntry.joins(:gear).where(gears: { user_id: demo_user.id }).maximum(:filled_on)

    assert_operator latest, :>=, 1.week.ago.to_date
    assert_operator latest, :<=, Date.current
  end

  test "loading again starts the demo user over without touching anyone else" do
    demo_user.gears.first.expenses.create!(spent_on: Date.current, description: "Visitor's change", amount: 1)
    counts = -> { [ Gear.count, Expense.count, FuelEntry.count, Reading.count ] }
    other_gear = gears(:prius).attributes

    Demo.load!

    assert_not Expense.exists?(description: "Visitor's change")
    assert_equal other_gear, gears(:prius).reload.attributes
    assert_equal 1, User.where(email_address: Demo::EMAIL).count
    before = counts.call
    Demo.load!
    assert_equal before, counts.call
  end

  test "demo mode is on only when GEAR_TRACKER_DEMO is 1, and never in production" do
    development = ActiveSupport::EnvironmentInquirer.new("development")

    assert Demo.enabled?(env: { "GEAR_TRACKER_DEMO" => "1" }, rails_env: development)
    assert_not Demo.enabled?(env: {}, rails_env: development)
    assert_not Demo.enabled?(env: { "GEAR_TRACKER_DEMO" => "true" }, rails_env: development)
    assert_not Demo.enabled?(env: { "GEAR_TRACKER_DEMO" => "1" }, rails_env: ActiveSupport::EnvironmentInquirer.new("production"))
  end
end
