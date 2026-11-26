require "test_helper"

class AccountImportTest < ActiveSupport::TestCase
  setup { @user = User.create!(email_address: "new@example.com", password: "password", currency: "EUR", distance_unit: "km", volume_unit: "l") }

  # A small export file, written in miles and US gallons.
  def file(gears = [ gear ], account: { "distance_unit" => "mi", "volume_unit" => "us_gal" })
    { "app_version" => "0.2.0", "account" => account, "gears" => gears }.to_json
  end

  def gear(**changes)
    { "id" => 1, "name" => "Van", "power_source" => "plug_in_hybrid", "currency" => "USD", "parent_id" => nil,
      "purchased_on" => "2024-05-01", "price" => 20000.5, "total_cost" => [ { "currency" => "USD", "amount" => 1 } ],
      "expenses" => [ { "id" => 7, "date" => "2025-01-02", "description" => "Brakes", "amount" => 300.1, "currency" => "USD" } ],
      "fuel_entries" => [
        { "id" => 8, "date" => "2025-02-03", "kind" => "fuel", "amount" => 10, "currency" => "USD", "odometer" => 1000, "trip" => 300, "minutes" => 90, "rate" => 99 },
        { "id" => 9, "date" => "2025-02-04", "kind" => "energy", "amount" => 12.5, "currency" => "USD" }
      ],
      "readings" => [ { "id" => 10, "date" => "2025-03-04", "name" => "Tire pressure", "value" => 35, "unit" => "psi" } ] }.merge(changes.stringify_keys)
  end

  def import(json) = AccountImport.new(@user, json).save!

  def assert_nothing_imported(json, message)
    error = assert_no_changes -> { [ Gear.count, Expense.count, FuelEntry.count, Reading.count ] } do
      assert_raises(AccountImport::Invalid) { import(json) }
    end
    assert_match message, error.message
  end

  test "adds the gear and its records to the account" do
    counts = import(file)

    van = @user.gears.find_by!(name: "Van")
    assert_equal [ Date.new(2024, 5, 1), 20000.5.to_d, "USD", "plug_in_hybrid" ], [ van.purchased_on, van.price, van.currency, van.power_source ]
    assert_equal [ [ Date.new(2025, 1, 2), "Brakes", 300.1.to_d ] ], van.expenses.pluck(:spent_on, :description, :amount)
    assert_equal [ [ Date.new(2025, 3, 4), "Tire pressure", 35, "psi" ] ], van.readings.pluck(:read_on, :name, :value, :unit)
    assert_equal({ "gears" => 1, "expenses" => 1, "fuel entries" => 2, "readings" => 1 }, counts)
  end

  test "converts fuel from the file's units, and leaves energy in kWh" do
    import(file)

    fuel, energy = @user.gears.find_by!(name: "Van").fuel_entries.order(:filled_on)
    assert_in_delta 37.854, fuel.amount, 0.001 # 10 US gallons in liters
    assert_in_delta 1609.344, fuel.odometer, 0.001 # 1000 miles in km
    assert_in_delta 482.803, fuel.trip, 0.001
    assert_equal [ "l", 90 ], [ fuel.unit, fuel.minutes ]
    assert_equal [ "kWh", 12.5.to_d ], [ energy.unit, energy.amount ]
  end

  test "keeps whether the tank was filled up, one was missed and it was checked, and gives older entries the defaults" do
    entry = { "date" => "2025-02-03", "kind" => "fuel", "amount" => 10, "currency" => "USD" }
    import(file([ gear("fuel_entries" => [ entry.merge("filled_up" => false, "missed_previous" => true, "efficiency_checked" => true), entry.merge("filled_up" => true, "missed_previous" => false), entry ]) ]))

    assert_equal [ [ false, true, true ], [ true, false, false ], [ true, false, false ] ], @user.gears.find_by!(name: "Van").fuel_entries.order(:id).pluck(:filled_up, :missed_previous, :efficiency_checked)
  end

  test "refuses a filled_up that isn't true or false" do
    [ "no", nil, { "a" => 1 } ].each do |value|
      assert_nothing_imported file([ gear("fuel_entries" => [ { "date" => "2025-02-03", "kind" => "fuel", "amount" => 10, "filled_up" => value } ]) ]), "filled_up"
    end
  end

  test "never lists an imported vehicle" do
    import(file([ gear("category" => "vehicle", "make" => "Ford", "model" => "Transit", "listed" => true, "listed_price" => true) ]))

    assert_equal [ false, false ], @user.gears.find_by!(name: "Van").values_at(:listed, :listed_price)
  end

  test "attaches components to their new parent, whatever order the file lists them in" do
    tires = gear("id" => 2, "name" => "Tires", "parent_id" => 1, "power_source" => nil, "fuel_entries" => [])
    import(file([ tires, gear ]))

    assert_equal @user.gears.find_by!(name: "Van"), @user.gears.find_by!(name: "Tires").parent
  end

  test "never attaches gear to gear that isn't in the file, like another user's" do
    other = gear("parent_id" => gears(:prius).id, "fuel_entries" => [])

    assert_nothing_imported file([ other ]), "is a component of gear that isn't in the file"
  end

  test "only imports into an account with no gear, so a second import can't make copies" do
    import(file)

    assert_nothing_imported file, "already has gear"

    @user = users(:two) # had gear before any import
    assert_nothing_imported file, "already has gear"
  end

  test "imports nothing if any record is invalid, and says which" do
    bad = gear("readings" => [ { "date" => "2025-03-04", "name" => "", "value" => 35 } ])

    assert_nothing_imported file([ bad ]), "A reading of Gear “Van”: Name can't be blank"
  end

  test "imports nothing if a date isn't a date" do
    assert_nothing_imported file([ gear("purchased_on" => "last May") ]), "purchased_on that isn't a date"
  end

  test "imports nothing if a value isn't text or a number" do
    assert_nothing_imported file([ gear("name" => { "evil" => true }) ]), "unexpected value for name"
    assert_nothing_imported file([ "Van" ]), "unexpected entry"
  end

  test "refuses files that aren't Gear Tracker exports" do
    [ "not json", "[]", { "gears" => [] }.to_json, file(account: { "distance_unit" => "furlongs", "volume_unit" => "l" }) ].each do |json|
      assert_nothing_imported json, "isn't a Gear Tracker data file"
    end
  end

  test "imported gear starts private, whatever the file says" do
    import(file([ gear("public" => true, "public_costs" => true) ]))

    van = @user.gears.find_by!(name: "Van")
    assert_equal [ false, false ], [ van.public, van.public_costs ]
  end

  test "keeps known categories and turns older free-text ones into Other, keeping the text" do
    import(file([ gear("category" => "Heating & cooling"), gear("id" => 2, "name" => "Bed", "category" => "Bedroom stuff", "notes" => "Soft", "fuel_entries" => []) ]))

    assert_equal "heating_cooling", @user.gears.find_by!(name: "Van").category
    bed = @user.gears.find_by!(name: "Bed")
    assert_equal [ "other", "Category: Bedroom stuff\n\nSoft" ], [ bed.category, bed.notes ]
  end

  test "does the same for an expense's category" do
    expense = { "date" => "2025-01-02", "description" => "Trip", "amount" => 5, "currency" => "USD" }
    import(file([ gear("expenses" => [ expense.merge("category" => "Accessory"), expense.merge("category" => "Snacks", "notes" => "Chips"), expense ]) ]))

    expenses = @user.gears.find_by!(name: "Van").expenses.order(:id)
    assert_equal [ [ "parts", nil ], [ "other", "Category: Snacks\n\nChips" ], [ nil, nil ] ], expenses.pluck(:category, :notes)
  end

  test "converts an expense's odometer from the file's units" do
    expense = { "date" => "2025-01-02", "description" => "Brakes", "amount" => 300, "currency" => "USD", "odometer" => 1000 }
    import(file([ gear("expenses" => [ expense ]) ]))

    assert_in_delta 1609.344, @user.gears.find_by!(name: "Van").expenses.sole.odometer, 0.001
  end

  test "converts a reading's odometer from the file's units" do
    reading = { "date" => "2025-03-04", "name" => "Tread depth", "value" => 6, "odometer" => 1000 }
    import(file([ gear("readings" => [ reading ]) ]))

    assert_in_delta 1609.344, @user.gears.find_by!(name: "Van").readings.sole.odometer, 0.001
  end
end
