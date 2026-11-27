require "test_helper"

class GearsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index requires sign in" do
    sign_out
    get gears_path
    assert_redirected_to new_session_path
  end

  test "index lists only my top-level gear" do
    get gears_path

    assert_response :success
    assert_select "td a", text: "2010 Toyota Prius"
    assert_select "td a", text: "Michelin tires", count: 0
    assert_select "td a", text: "Cordless drill", count: 0
  end

  test "show displays components, expenses and readings" do
    get gear_path(gears(:prius))

    assert_response :success
    assert_select "td a", text: "Michelin tires"
    assert_select "td", text: "Oil change"
    assert_select "td", text: "Tire pressure FL"
    assert_select "dd", text: "$8,715.00"
  end

  test "show offers fuel entries only for gear that uses fuel or electricity" do
    get gear_path(gears(:prius))
    assert_select "dd", text: "Gasoline"
    assert_select "a", text: "Add fuel entry"
    assert_select "td", text: "$40.00"
    assert_select "td", text: "42.9 mi/gal"

    get gear_path(gears(:tires))
    assert_select "dd", text: "Not powered"
    assert_select "a", text: "Add fuel entry", count: 0
  end

  test "show offers both entries for a plug-in hybrid" do
    get gear_path(gears(:phev))

    assert_select "h2", text: "Fuel and energy use"
    assert_select "a[href=?]", new_gear_fuel_entry_path(gears(:phev), unit: "l"), text: "Add fuel entry"
    assert_select "a[href=?]", new_gear_fuel_entry_path(gears(:phev), unit: "kWh"), text: "Add energy entry"
  end

  test "show leaves out fuel columns nobody filled in" do
    get gear_path(gears(:prius))
    assert_select "th", text: "Efficiency"
    assert_select "th", text: "Rate", count: 0

    gears(:prius).fuel_entries.create!(amount: 1, minutes: 30)
    get gear_path(gears(:prius))
    assert_select "th", text: "Rate"
  end

  test "show uses the user's currency and units" do
    sign_in_as users(:two)
    gears(:truck).fuel_entries.create!(entered_amount: "40", entered_trip: "500", total_price: "70")
    get gear_path(gears(:truck))

    assert_select "td", text: "€70.00"
    assert_select "td", text: "40 L"
    assert_select "td", text: "12.5 km/L"
  end

  test "amounts keep their currency after the setting changes" do
    users(:one).update!(currency: "EUR")
    get gear_path(gears(:prius))

    assert_select "dd", text: "$8,000.00"
    assert_select "td", text: "$50.00"
    assert_select "td", text: "$40.00"
  end

  test "new gear form picks the user's currency" do
    get new_gear_path
    assert_select "select[name=?] option[selected][value=USD]", "gear[currency]"

    sign_in_as users(:two)
    get new_gear_path
    assert_select "select[name=?] option[selected][value=EUR]", "gear[currency]"
  end

  test "edit form picks the gear's own currency, not the setting" do
    users(:one).update!(currency: "EUR")
    get edit_gear_path(gears(:prius))

    assert_select "select[name=?] option[selected][value=USD]", "gear[currency]"
  end

  test "create and update with a chosen currency" do
    post gears_path, params: { gear: { name: "Souvenir", price: "2000", currency: "JPY" } }
    assert_equal "JPY", Gear.last.currency

    patch gear_path(gears(:prius)), params: { gear: { price: "7500", currency: "CAD" } }
    assert_equal [ 7500, "CAD" ], gears(:prius).reload.values_at(:price, :currency)
  end

  test "update rejects an unknown currency" do
    patch gear_path(gears(:prius)), params: { gear: { currency: "XYZ" } }

    assert_response :unprocessable_content
    assert_equal "USD", gears(:prius).reload.currency
  end

  test "small electricity use shows as average watts, not 0.00" do
    sign_in_as users(:two)
    gears(:drill).fuel_entries.create!(entered_amount: "0.014", minutes: 180)
    get gear_path(gears(:drill))

    assert_select "td", text: "4.67 W"
  end

  test "time used shows as hours and minutes" do
    sign_in_as users(:two)
    gears(:drill).fuel_entries.create!(amount: 0.1, minutes: 90)
    gears(:drill).fuel_entries.create!(amount: 0.1, minutes: 180)
    gears(:drill).fuel_entries.create!(amount: 0.1, minutes: 45)
    get gear_path(gears(:drill))

    assert_select "th", text: "Time used"
    assert_select "td", text: "1 h 30 min"
    assert_select "td", text: "3 h"
    assert_select "td", text: "45 min"
  end

  test "fuel use per hour keeps small values readable" do
    gears(:prius).fuel_entries.create!(entered_amount: "0.05", minutes: 120)
    get gear_path(gears(:prius))

    assert_select "td", text: "0.025 gal/h"
  end

  test "show adds a notes column only to tables that have notes" do
    get gear_path(gears(:prius))
    assert_select "th", text: "Notes", count: 0

    expenses(:oil_change).update!(notes: "Synthetic 0W-20")
    fuel_entries(:fill_up).update!(notes: "Costco")
    gears(:prius).readings.first.update!(notes: "Cold morning")
    get gear_path(gears(:prius))

    assert_select "th", text: "Notes", count: 3
    assert_select "td.notes", text: "Synthetic 0W-20"
    assert_select "td.notes", text: "Costco"
    assert_select "td.notes", text: "Cold morning"
  end

  test "show offers energy entries for electric gear" do
    sign_in_as users(:two)
    get gear_path(gears(:drill))

    assert_select "h2", text: "Energy use"
    assert_select "a", text: "Add energy entry"
  end

  test "a vehicle can be listed from its form, off by default" do
    get edit_gear_path(gears(:prius))
    Gear::LISTING_FIELDS.each { assert_select ".vehicle-only input[type=checkbox]:not([checked])[name=?]", "gear[#{it}]" }
    assert_select "p", text: /not its nickname or your name/
    assert_select "p", text: /Your profile is private, so your name isn't shown/

    get gear_path(gears(:prius))
    assert_select "dd", text: "Not listed"

    patch gear_path(gears(:prius)), params: { gear: { listed: "1", listed_costs: "1" } }
    assert_equal [ true, false, true, false, false ], gears(:prius).reload.values_at(*Gear::LISTING_FIELDS)
    follow_redirect!
    assert_select "dd a[href=?]", vehicle_path(gears(:prius)), text: "Listed"
  end

  test "the private profile note goes away once the profile is public" do
    users(:one).update!(username: "one", display_name: "One", profile_public: true)
    get edit_gear_path(gears(:prius))

    assert_select "p", text: /Your profile is private/, count: 0
  end

  test "a vehicle's page shows its stats" do
    get gear_path(gears(:prius))

    assert_select "h2", text: "Stats"
    assert_select "dd", text: /\A\$715.00/ # $40 fuel, $50 oil change, $600 tires, $25 rotation
    assert_select "td", text: "83.9%"
    assert_select "dt", text: "Running cost per mi"
    assert_select "dd", text: /after 180 days between odometers/
  end

  test "stats name the currency only when there's more than one" do
    get gear_path(gears(:prius))
    assert_select "th", text: "Running costs"

    gears(:prius).expenses.create!(spent_on: Date.current, description: "Toll", amount: 5, currency: "EUR")
    get gear_path(gears(:prius))
    assert_select "th", text: "Running costs in EUR"
  end

  test "stats mention missed and unusual fuel entries" do
    [ 240_442, 240_842, 241_242, 242_442 ].each { gears(:prius).fuel_entries.create!(entered_amount: 10, entered_odometer: it) }
    gears(:prius).fuel_entries.create!(entered_amount: 10, entered_odometer: 243_300, missed_previous: true)
    get gear_path(gears(:prius))

    assert_select "dd", text: /and about 1 missed/
    assert_select ".alert", text: /Left out of efficiency and distance until you check: 1 unusual fuel entry/
  end

  test "other gear and vehicles with nothing logged have no stats" do
    [ :tires, :phev ].each do |gear|
      get gear_path(gears(gear))
      assert_select "h2", text: "Stats", count: 0
    end
  end

  test "create" do
    assert_difference -> { users(:one).gears.count } do
      post gears_path, params: { gear: { name: "Tent", power_source: "manual", price: "199.99", purchased_on: "2026-01-02", purchased_from: "REI" } }
    end

    assert_redirected_to Gear.last
    assert_equal "REI", Gear.last.purchased_from
    assert_equal "manual", Gear.last.power_source
  end

  test "vehicle details are saved, shown and offered for editing" do
    post gears_path, params: { gear: { name: "Daily", category: "vehicle", year: "2015", make: "honda", model: "Fit", trim: "EX" } }
    assert_redirected_to Gear.last

    get gear_path(Gear.last)
    assert_select "dt", text: "Vehicle"
    assert_select "dd", text: "2015 Honda Fit EX"

    get edit_gear_path(Gear.last)
    assert_select ".vehicle-only input[name='gear[year]'][value='2015']"
    assert_select ".vehicle-only datalist#makes option[value=Honda]"
  end

  test "a vehicle without a nickname shows its details once, and an empty nickname field" do
    post gears_path, params: { gear: { name: "", category: "vehicle", year: "2015", make: "Honda", model: "Fit" } }

    get gear_path(Gear.last)
    assert_select "h1", text: "2015 Honda Fit"
    assert_select "dt", text: "Vehicle", count: 0

    get edit_gear_path(Gear.last)
    assert_select "input[name='gear[name]']:not([value])"
  end

  test "edit fills in a nickname or a name" do
    [ :prius, :tires ].each do |gear|
      get edit_gear_path(gears(gear))
      assert_select "input[name='gear[name]'][value=?]", gears(gear).name
    end
  end

  test "a bad year re-renders the form with the error" do
    post gears_path, params: { gear: { name: "Daily", category: "vehicle", year: "99" } }

    assert_response :unprocessable_content
    assert_select ".errors", text: /Year must be greater than or equal to 1885/
  end

  test "show has no vehicle row for other gear" do
    get gear_path(gears(:tires))
    assert_select "dt", text: "Vehicle", count: 0
  end

  test "create a component from the new form" do
    get new_gear_path(parent_id: gears(:prius).id)
    assert_select "option[selected][value=?]", gears(:prius).id.to_s

    post gears_path, params: { gear: { name: "Battery", parent_id: gears(:prius).id } }
    assert_equal gears(:prius), Gear.last.parent
  end

  test "create with invalid data re-renders the form" do
    assert_no_difference -> { Gear.count } do
      post gears_path, params: { gear: { name: "" } }
    end

    assert_response :unprocessable_content
  end

  test "can't attach gear to another user's gear" do
    assert_no_difference -> { Gear.count } do
      post gears_path, params: { gear: { name: "Sneaky", parent_id: gears(:drill).id } }
    end

    assert_response :unprocessable_content
  end

  test "update" do
    patch gear_path(gears(:prius)), params: { gear: { name: "The Prius" } }

    assert_redirected_to gears(:prius)
    assert_equal "The Prius", gears(:prius).reload.name
  end

  test "edit form for gear with components" do
    get edit_gear_path(gears(:prius))

    assert_response :success
    assert_select "select[name=?]", "gear[parent_id]", count: 0
  end

  test "destroying a component returns to its parent" do
    delete gear_path(gears(:tires))

    assert_redirected_to gears(:prius)
  end

  test "another user's gear is off limits" do
    drill = gears(:drill)

    get gear_path(drill)
    assert_response :not_found
    get edit_gear_path(drill)
    assert_response :not_found
    patch gear_path(drill), params: { gear: { name: "Mine now" } }
    assert_response :not_found
    delete gear_path(drill)
    assert_response :not_found

    assert_equal "Cordless drill", drill.reload.name
  end

  # --- Public profile ---

  test "top-level gear can be made public, with or without costs" do
    patch gear_path(gears(:prius)), params: { gear: { public: "1", public_costs: "1" } }

    assert gears(:prius).reload.public_costs
    get gear_path(gears(:prius))
    assert_select "dd", "Shown, with costs"
  end

  test "the public checkboxes are only on top-level gear, with a hint while the profile is private" do
    get edit_gear_path(gears(:prius))
    assert_select "input[type=checkbox][name='gear[public]']"
    assert_select "p", text: /Your profile is private/

    get edit_gear_path(gears(:tires))
    assert_select "input[name='gear[public]']", count: 0
  end

  test "show links to each section it has, each with a key" do
    get gear_path(gears(:prius))
    links = css_select("nav.section-nav a").map { [ it["href"], it["aria-keyshortcuts"] ] }
    assert_equal [ [ "#stats", "s" ], [ "#components", "c" ], [ "#fuel_entries", "f" ], [ "#expenses", "e" ], [ "#readings", "r" ] ], links
    links.each { |href, _| assert_select "h2#{href}" }

    get gear_path(gears(:tires)) # a component, not powered
    assert_equal %w[ #expenses #readings ], css_select("nav.section-nav a").map { it["href"] }
  end
end
