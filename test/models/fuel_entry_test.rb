require "test_helper"

class FuelEntryTest < ActiveSupport::TestCase
  test "only the amount is required" do
    fuel_entry = gears(:prius).fuel_entries.create!(amount: 9)

    assert_equal Date.current, fuel_entry.filled_on
    assert_nil fuel_entry.total_price
    assert_nil fuel_entry.minutes
    assert_nil fuel_entry.odometer
    assert_nil fuel_entry.trip
  end

  test "amount must be positive" do
    assert_not gears(:prius).fuel_entries.new.valid?
    assert_not gears(:prius).fuel_entries.new(amount: 0).valid?
  end

  test "price, odometer and trip can't be negative" do
    assert_not gears(:prius).fuel_entries.new(amount: 9, total_price: -1).valid?
    assert_not gears(:prius).fuel_entries.new(amount: 9, odometer: -1).valid?
    assert_not gears(:prius).fuel_entries.new(amount: 9, trip: -1).valid?
  end

  test "minutes must be a positive whole number" do
    assert_not gears(:drill).fuel_entries.new(amount: 1, minutes: 0).valid?
    assert_not gears(:drill).fuel_entries.new(amount: 1, minutes: 1.5).valid?
  end

  test "unit comes from the gear's power source" do
    assert_equal "gal", gears(:prius).fuel_entries.create!(amount: 9).unit
    assert_equal "kWh", gears(:drill).fuel_entries.create!(amount: 0.2).unit
  end

  test "unit stays the same if the gear's power source changes" do
    gears(:prius).update!(power_source: "electric")

    assert fuel_entries(:fill_up).update(amount: 11)
    assert_equal "gal", fuel_entries(:fill_up).reload.unit
  end

  test "distance per unit is trip divided by amount" do
    assert_in_delta 42.88, fuel_entries(:fill_up).distance_per_unit, 0.01
  end

  test "distance per unit is unknown without a trip" do
    assert_nil FuelEntry.new(amount: 9).distance_per_unit
    assert_nil FuelEntry.new(amount: 9, trip: 0).distance_per_unit
  end

  test "amount per hour uses the minutes of use" do
    assert_in_delta 1.2, FuelEntry.new(amount: 0.3, minutes: 15).amount_per_hour, 0.001
    assert_nil FuelEntry.new(amount: 0.3).amount_per_hour
  end

  test "gear must run on fuel or electricity" do
    assert_not gears(:tires).fuel_entries.new(amount: 9).valid?
    assert_not users(:one).gears.create!(name: "Bike", power_source: "manual").fuel_entries.new(amount: 9).valid?
  end

  test "existing entries stay editable if the gear stops using fuel" do
    gears(:prius).update!(power_source: "manual")

    assert fuel_entries(:fill_up).update(amount: 11)
  end
end
