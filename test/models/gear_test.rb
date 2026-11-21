require "test_helper"

class GearTest < ActiveSupport::TestCase
  test "total cost includes price, expenses, fuel and components" do
    assert_equal Costs.new("USD" => 8715), gears(:prius).total_cost
  end

  test "total cost is empty without a price or records" do
    assert_empty users(:one).gears.create!(name: "Gift").total_cost
  end

  test "total cost keeps currencies apart" do
    users(:one).update!(currency: "EUR")
    gears(:prius).expenses.create!(spent_on: Date.current, description: "Toll abroad", amount: 30)

    assert_equal Costs.new("USD" => 8715, "EUR" => 30), gears(:prius).reload.total_cost
  end

  test "new gear takes the owner's currency, and keeps it when the setting changes" do
    gear = users(:one).gears.create!(name: "Tent", price: 300)
    assert_equal "USD", gear.currency

    users(:one).update!(currency: "GBP")
    assert_equal "USD", gear.reload.currency
    assert_equal "GBP", users(:one).gears.create!(name: "Stove").currency
  end

  test "currency must be a known one" do
    assert_not users(:one).gears.new(name: "Tent", currency: "XYZ").valid?
  end

  test "cost per year divides by years owned" do
    gear = users(:one).gears.create!(name: "Tent", price: 300, purchased_on: 3.years.ago.to_date)

    assert_in_delta 100, gear.cost_per_year["USD"], 0.5
  end

  test "cost per year counts at least one year" do
    gear = users(:one).gears.create!(name: "Tent", price: 300, purchased_on: 1.week.ago.to_date)

    assert_equal Costs.new("USD" => 300), gear.cost_per_year
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

  test "fuel units depend on the power source" do
    assert_equal %w[ l ], Gear.new(power_source: "gasoline").fuel_units
    assert_equal %w[ kWh ], Gear.new(power_source: "electric").fuel_units
    assert_equal %w[ l kWh ], Gear.new(power_source: "plug_in_hybrid").fuel_units
    assert_empty Gear.new(power_source: "manual").fuel_units
    assert_empty Gear.new.fuel_units
  end

  test "vehicle category ignores case and spaces" do
    assert Gear.new(category: " vehicle ").vehicle?
    assert_not Gear.new(category: "Tools").vehicle?
    assert_not Gear.new.vehicle?
  end

  test "power source must be a known one, and blank means not powered" do
    assert_not users(:one).gears.new(name: "Kite", power_source: "wind").valid?
    assert_nil users(:one).gears.create!(name: "Kite", power_source: "").power_source
  end

  test "total cost counts fuel entries without a price as zero" do
    gears(:prius).fuel_entries.create!(amount: 5)

    assert_equal Costs.new("USD" => 8715), gears(:prius).total_cost
  end

  test "destroying gear removes its components and records" do
    assert_difference -> { Gear.count } => -2, -> { Expense.count } => -2, -> { Reading.count } => -1, -> { FuelEntry.count } => -1 do
      gears(:prius).destroy!
    end
  end

  test "only top-level gear can be public, and costs are shown only on public gear" do
    tires = gears(:tires)
    tires.update!(public: true, public_costs: true)
    assert_equal [ false, false ], [ tires.public, tires.public_costs ]

    prius = gears(:prius)
    prius.update!(public: false, public_costs: true)
    assert_not prius.public_costs
  end
end
