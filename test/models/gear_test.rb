require "test_helper"

class GearTest < ActiveSupport::TestCase
  test "total cost includes price, expenses, fuel and components" do
    assert_equal 8715, gears(:prius).total_cost
  end

  test "total cost treats a missing price as zero" do
    assert_equal 0, users(:one).gears.create!(name: "Gift").total_cost
  end

  test "cost per year divides by years owned" do
    gear = users(:one).gears.create!(name: "Tent", price: 300, purchased_on: 3.years.ago.to_date)

    assert_in_delta 100, gear.cost_per_year, 0.5
  end

  test "cost per year counts at least one year" do
    gear = users(:one).gears.create!(name: "Tent", price: 300, purchased_on: 1.week.ago.to_date)

    assert_equal 300, gear.cost_per_year
  end

  test "cost per year is unknown without a purchase date" do
    assert_nil gears(:drill).cost_per_year
  end

  test "price can't be negative" do
    assert_not users(:one).gears.new(name: "Tent", price: -1).valid?
  end

  test "parent must belong to the same user" do
    gear = users(:one).gears.new(name: "Stolen", parent: gears(:drill))

    assert_not gear.valid?
    assert_includes gear.errors[:parent], "must be one of your other top-level gears"
  end

  test "components can't be nested" do
    assert_not users(:one).gears.new(name: "Valve", parent: gears(:tires)).valid?
  end

  test "gear can't be its own parent" do
    prius = gears(:prius)
    prius.parent = prius

    assert_not prius.valid?
  end

  test "gear with components can't become a component" do
    prius = gears(:prius)
    prius.parent = users(:one).gears.create!(name: "Garage")

    assert_not prius.valid?
  end

  test "fuel unit depends on the power source" do
    assert_equal "gal", Gear.new(power_source: "gasoline").fuel_unit
    assert_equal "kWh", Gear.new(power_source: "electric").fuel_unit
    assert_nil Gear.new(power_source: "manual").fuel_unit
    assert_nil Gear.new.fuel_unit
  end

  test "power source must be a known one, and blank means not powered" do
    assert_not users(:one).gears.new(name: "Kite", power_source: "wind").valid?
    assert_nil users(:one).gears.create!(name: "Kite", power_source: "").power_source
  end

  test "total cost counts fuel entries without a price as zero" do
    gears(:prius).fuel_entries.create!(amount: 5)

    assert_equal 8715, gears(:prius).total_cost
  end

  test "destroying gear removes its components and records" do
    assert_difference -> { Gear.count } => -2, -> { Expense.count } => -2, -> { Reading.count } => -1, -> { FuelEntry.count } => -1 do
      gears(:prius).destroy!
    end
  end
end
