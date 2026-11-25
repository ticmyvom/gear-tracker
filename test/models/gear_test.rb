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

  test "category takes a key or a name in any case, and stores the key" do
    assert_equal "vehicle", Gear.new(category: " Vehicle ").category
    assert_equal "heating_cooling", Gear.new(category: "heating & COOLING").category
    assert_equal "Heating & cooling", Gear.new(category: "heating_cooling").category_name
    assert_nil Gear.new(category: " ").category
  end

  test "category must be on the list" do
    gear = Gear.new(category: "Spaceship")

    assert_not gear.valid?
    assert_match "must be one of", gear.errors[:category].first
  end

  test "vehicle name joins the parts that are filled in, for vehicles only" do
    assert_equal "2010 Toyota Prius Two", gears(:prius).vehicle_name
    assert_equal "Toyota Prius", Gear.new(category: "vehicle", make: "Toyota", model: "Prius").vehicle_name
    assert_nil gears(:phev).vehicle_name
    assert_nil Gear.new(category: "other", make: "Toyota").vehicle_name
  end

  test "a vehicle without a nickname is named by its details, and renamed when they change" do
    car = users(:one).gears.create!(category: "vehicle", year: 2015, make: "Honda", model: "Fit")
    assert_equal [ "2015 Honda Fit", nil ], [ car.name, car.nickname ]

    car.update!(year: 2016)
    assert_equal "2016 Honda Fit", car.name

    car.update!(name: "Daily", trim: "EX")
    assert_equal %w[ Daily Daily ], [ car.name, car.nickname ]

    car.update!(name: "")
    assert_equal "2016 Honda Fit EX", car.name
  end

  test "a nickname stays when the details change" do
    gears(:prius).update!(year: 2011)
    assert_equal "2010 Toyota Prius", gears(:prius).name
  end

  test "a vehicle needs a nickname or details, and other gear needs a name" do
    car = users(:one).gears.new(category: "vehicle")
    assert_not car.valid?
    assert_equal [ "Add a year, make or model, or a nickname" ], car.errors.full_messages

    tent = users(:one).gears.new(category: "outdoor", make: "Toyota")
    assert_not tent.valid?
    assert_equal [ "Name can't be blank" ], tent.errors.full_messages
  end

  test "only top-level vehicles can be listed, and nothing is by default" do
    assert_equal [ false ] * 4, gears(:prius).values_at(*Gear::LISTING_FIELDS)

    gears(:prius).update!(listed: true, listed_price: true, listed_costs: true, listed_economy: true)
    gears(:tires).update!(listed: true, make: "A", model: "B")
    assert_equal [ gears(:prius) ], Gear.listed.to_a

    gears(:prius).update!(category: "other")
    assert_equal [ false ] * 4, gears(:prius).values_at(*Gear::LISTING_FIELDS)
  end

  test "unlisting a vehicle turns off what it showed, so listing it again starts over" do
    gears(:prius).update!(listed: true, listed_price: true)
    gears(:prius).update!(listed: false)

    assert_not gears(:prius).listed_price?
  end

  test "a listed vehicle needs a make and model" do
    assert_not gears(:phev).update(listed: true)
    assert_equal [ "Add a make and model to list it on the Vehicles page" ], gears(:phev).errors.full_messages
  end

  test "known makes get one spelling, and others are kept as typed" do
    assert_equal "Toyota", Gear.new(make: " TOYOTA ").make
    assert_equal "Mercedes-Benz", Gear.new(make: "mercedes-benz").make
    assert_equal "My Kit Car", Gear.new(make: "My  Kit Car").make
    assert_equal [ nil, nil, nil ], Gear.new(make: " ", model: "", trim: " ").values_at(:make, :model, :trim)
  end

  test "suggested makes are in order and listed once" do
    assert_equal Gear::MAKES.uniq.sort_by(&:downcase), Gear::MAKES
  end

  test "year must be a sensible whole number, or blank" do
    valid = ->(year) { gears(:prius).tap { it.year = year }.valid? }

    [ "", 1885, 2010, Date.current.year + 1 ].each { assert valid.(it), it.inspect }
    [ 1884, Date.current.year + 2, "soon", 2010.5 ].each { assert_not valid.(it), it.inspect }
  end

  test "make, model and trim can't be too long" do
    %i[ make model trim ].each do |field|
      assert_not Gear.new(field => "x" * 51).tap(&:valid?).errors[field].empty?
    end
  end

  test "vehicles and their parts track the odometer" do
    assert gears(:prius).vehicle?
    assert gears(:tires).tracks_odometer? # a part of the Prius
    assert_not gears(:tires).vehicle?
    assert_not gears(:drill).tracks_odometer?
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
