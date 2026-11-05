require "test_helper"

class FuelEntryTest < ActiveSupport::TestCase
  test "only total price and gallons are required" do
    fuel_entry = gears(:prius).fuel_entries.create!(total_price: 30, gallons: 9)

    assert_equal Date.current, fuel_entry.filled_on
    assert_nil fuel_entry.odometer
    assert_nil fuel_entry.trip
  end

  test "requires total price and gallons" do
    fuel_entry = gears(:prius).fuel_entries.new

    assert_not fuel_entry.valid?
    assert fuel_entry.errors.include?(:total_price)
    assert fuel_entry.errors.include?(:gallons)
  end

  test "gallons must be positive" do
    assert_not gears(:prius).fuel_entries.new(total_price: 30, gallons: 0).valid?
  end

  test "odometer and trip can't be negative" do
    assert_not gears(:prius).fuel_entries.new(total_price: 30, gallons: 9, odometer: -1).valid?
    assert_not gears(:prius).fuel_entries.new(total_price: 30, gallons: 9, trip: -1).valid?
  end

  test "mpg is trip divided by gallons" do
    assert_in_delta 42.88, fuel_entries(:fill_up).mpg, 0.01
  end

  test "mpg is unknown without a trip" do
    assert_nil FuelEntry.new(gallons: 9).mpg
    assert_nil FuelEntry.new(gallons: 9, trip: 0).mpg
  end

  test "gear must be a vehicle" do
    assert_not gears(:tires).fuel_entries.new(total_price: 30, gallons: 9).valid?
  end

  test "existing entries stay editable if the gear stops being a vehicle" do
    gears(:prius).update!(category: "Other")

    assert fuel_entries(:fill_up).update(gallons: 11)
  end
end
