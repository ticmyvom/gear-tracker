require "test_helper"

class FuelEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @gear = gears(:prius)
  end

  test "new" do
    get new_gear_fuel_entry_path(@gear)
    assert_response :success
  end

  test "create with only the required fields" do
    assert_difference -> { @gear.fuel_entries.count } do
      post gear_fuel_entries_path(@gear), params: { fuel_entry: { total_price: "35.20", entered_amount: "9.8", entered_odometer: "", entered_trip: "", filled_on: "" } }
    end

    assert_redirected_to @gear
    assert_equal Date.current, FuelEntry.last.filled_on
    assert_nil FuelEntry.last.odometer
  end

  test "create with odometer and trip" do
    post gear_fuel_entries_path(@gear), params: { fuel_entry: { total_price: "35.20", entered_amount: "9.8", entered_odometer: "240500", entered_trip: "458.3", filled_on: "2026-01-02" } }

    assert_equal 240500, FuelEntry.last.entered_odometer
    assert_equal 458.3.to_d, FuelEntry.last.entered_trip
  end

  test "filled up is ticked by default, and can be unticked" do
    get new_gear_fuel_entry_path(@gear)
    assert_select "input[type=checkbox][checked][name=?]", "fuel_entry[filled_up]"

    post gear_fuel_entries_path(@gear), params: { fuel_entry: { entered_amount: "3", filled_up: "0" } }
    assert_not FuelEntry.last.filled_up?
    follow_redirect!
    assert_select "td", text: "3 gal partial"
  end

  test "a missed fill-up can be noted, and the gear page shows about how many" do
    get new_gear_fuel_entry_path(@gear)
    assert_select "input[type=checkbox]:not([checked])[name=?]", "fuel_entry[missed_previous]"

    post gear_fuel_entries_path(@gear), params: { fuel_entry: { entered_amount: "10", entered_odometer: "241500", filled_up: "1", missed_previous: "1" } }
    follow_redirect!

    # 1,458 mi at the usual 42.9 mi/gal takes 34 gal; 10 were logged, and fill-ups are about 10.25.
    assert_select "td", text: "10 gal about 2 missed before"
  end

  test "an unusual efficiency is flagged on the gear page and the form, until it's checked" do
    entry = nil
    [ 400, 400, 400, 1200 ].inject(240_042) do |odometer, distance|
      entry = @gear.fuel_entries.create!(entered_amount: 10, entered_odometer: odometer + distance)
      odometer + distance
    end

    get gear_path(@gear)
    assert_select "a[href=?]", edit_gear_fuel_entry_path(@gear, entry), text: "Unusually high: check", count: 1

    get edit_gear_fuel_entry_path(@gear, entry)
    assert_select ".alert", text: /120.0 mi\/gal is unusually high.\s+It's usually about 40.0/
    assert_select ".alert", text: /Did you miss logging a fill-up before this one/
    assert_select "input[type=checkbox][name=?]", "fuel_entry[efficiency_checked]"

    patch gear_fuel_entry_path(@gear, entry), params: { fuel_entry: { efficiency_checked: "1" } }
    follow_redirect!
    assert_select "a", text: /Unusually/, count: 0

    get edit_gear_fuel_entry_path(@gear, entry) # so it can be unticked
    assert_select ".alert", count: 0
    assert_select "input[type=checkbox][checked][name=?]", "fuel_entry[efficiency_checked]"
  end

  test "an unusually low efficiency points to the entry before" do
    entry = nil
    [ 240_442, 240_842, 241_242, 241_342 ].each { entry = @gear.fuel_entries.create!(entered_amount: 10, entered_odometer: it) }

    get edit_gear_fuel_entry_path(@gear, entry)
    assert_select ".alert", text: /unusually low.*Was the fill-up before this one only partial\? If so, untick “Filled up \(full tank\)” on that entry/m
  end

  test "an ordinary entry isn't asked to be checked" do
    get edit_gear_fuel_entry_path(@gear, fuel_entries(:fill_up))
    assert_select "input[name=?]", "fuel_entry[efficiency_checked]", count: 0
  end

  test "the gear page shows distance and efficiency worked out from the odometers" do
    post gear_fuel_entries_path(@gear), params: { fuel_entry: { entered_amount: "10", entered_odometer: "240542", filled_up: "1" } }
    follow_redirect!

    assert_select "td", text: "500"
    assert_select "td", text: "50.0 mi/gal"
  end

  test "a plug-in hybrid isn't told its distance is worked out" do
    get new_gear_fuel_entry_path(@gear)
    assert_select "p", text: /Leave this distance blank/

    get new_gear_fuel_entry_path(gears(:phev))
    assert_select "p", text: /Leave this distance blank/, count: 0
  end

  test "create requires an amount" do
    assert_no_difference -> { FuelEntry.count } do
      post gear_fuel_entries_path(@gear), params: { fuel_entry: { total_price: "", entered_amount: "" } }
    end

    assert_response :unprocessable_content
  end

  test "create rejects gear that doesn't use fuel" do
    assert_no_difference -> { FuelEntry.count } do
      post gear_fuel_entries_path(gears(:tires)), params: { fuel_entry: { total_price: "30", entered_amount: "9" } }
    end

    assert_response :unprocessable_content
  end

  test "create an energy entry with time used" do
    sign_in_as users(:two)
    post gear_fuel_entries_path(gears(:drill)), params: { fuel_entry: { entered_amount: "0.25", used_hours: "", used_minutes: "20", total_price: "" } }

    assert_redirected_to gears(:drill)
    assert_equal "Energy entry added.", flash[:notice]
    assert_equal "kWh", FuelEntry.last.unit
    assert_equal 20, FuelEntry.last.minutes
    assert_nil FuelEntry.last.total_price
  end

  test "a plug-in hybrid can log either unit" do
    get new_gear_fuel_entry_path(gears(:phev), unit: "kWh")
    assert_select "label", text: "Energy (kWh)"
    assert_select "input[type=hidden][name=?][value=kWh]", "fuel_entry[unit]"

    post gear_fuel_entries_path(gears(:phev)), params: { fuel_entry: { entered_amount: "12", unit: "kWh" } }
    assert_equal "Energy entry added.", flash[:notice]
    assert_equal "kWh", FuelEntry.last.unit

    post gear_fuel_entries_path(gears(:phev)), params: { fuel_entry: { entered_amount: "8", unit: "l" } }
    assert_equal "Fuel entry added.", flash[:notice]
    assert_equal "l", FuelEntry.last.unit
  end

  test "create rejects a unit the gear doesn't use" do
    assert_no_difference -> { FuelEntry.count } do
      post gear_fuel_entries_path(@gear), params: { fuel_entry: { entered_amount: "12", unit: "kWh" } }
    end

    assert_response :unprocessable_content
  end

  test "a metric user enters km and liters" do
    sign_in_as users(:two)
    get new_gear_fuel_entry_path(gears(:truck))
    assert_select "label", text: "Fuel (L)"
    assert_select "label", text: "Current odometer (km, optional)"

    post gear_fuel_entries_path(gears(:truck)), params: { fuel_entry: { entered_amount: "40", entered_trip: "500" } }
    assert_equal 40, FuelEntry.last.amount
    assert_equal 500, FuelEntry.last.trip
  end

  test "update price and currency" do
    patch gear_fuel_entry_path(@gear, fuel_entries(:fill_up)), params: { fuel_entry: { total_price: "55", currency: "CAD" } }

    assert_equal [ 55, "CAD" ], fuel_entries(:fill_up).reload.values_at(:total_price, :currency)
  end

  test "create with notes" do
    post gear_fuel_entries_path(@gear), params: { fuel_entry: { entered_amount: "9", notes: "Road trip" } }

    assert_equal "Road trip", FuelEntry.last.notes
  end

  test "time used can be typed in hours, minutes or both" do
    sign_in_as users(:two)

    { [ "3", "" ] => 180, [ "1", "30" ] => 90, [ "2.5", "" ] => 150, [ "", "90" ] => 90 }.each do |(hours, minutes), total|
      post gear_fuel_entries_path(gears(:drill)), params: { fuel_entry: { entered_amount: "0.1", used_hours: hours, used_minutes: minutes } }
      assert_equal total, FuelEntry.last.minutes, "#{hours} h #{minutes} min"
    end
  end

  test "clearing both time boxes removes the time used" do
    fuel_entries(:fill_up).update!(minutes: 30)
    patch gear_fuel_entry_path(@gear, fuel_entries(:fill_up)), params: { fuel_entry: { used_hours: "", used_minutes: "" } }

    assert_nil fuel_entries(:fill_up).reload.minutes
  end

  test "time used of zero is rejected" do
    assert_no_difference -> { FuelEntry.count } do
      post gear_fuel_entries_path(@gear), params: { fuel_entry: { entered_amount: "9", used_hours: "0", used_minutes: "0" } }
    end

    assert_response :unprocessable_content
    assert_select ".errors", text: /Time used must be greater than 0/
  end

  test "edit splits time used into hours and minutes" do
    fuel_entries(:fill_up).update!(minutes: 95)
    get edit_gear_fuel_entry_path(@gear, fuel_entries(:fill_up))

    assert_select "input[name=?][value=1]", "fuel_entry[used_hours]"
    assert_select "input[name=?][value=35]", "fuel_entry[used_minutes]"
  end

  test "only vehicles get distance fields" do
    get new_gear_fuel_entry_path(@gear)
    assert_select "input[name=?]", "fuel_entry[entered_trip]"

    sign_in_as users(:two)
    get new_gear_fuel_entry_path(gears(:drill))
    assert_select "input[name=?]", "fuel_entry[entered_trip]", count: 0
  end

  test "edit" do
    get edit_gear_fuel_entry_path(@gear, fuel_entries(:fill_up))
    assert_response :success
  end

  test "update" do
    patch gear_fuel_entry_path(@gear, fuel_entries(:fill_up)), params: { fuel_entry: { entered_amount: "11" } }

    assert_redirected_to @gear
    assert_equal 11, fuel_entries(:fill_up).reload.entered_amount
  end

  test "update can't change the unit" do
    patch gear_fuel_entry_path(gears(:phev), gears(:phev).fuel_entries.create!(amount: 8)), params: { fuel_entry: { unit: "kWh" } }

    assert_equal "l", FuelEntry.last.reload.unit
  end

  test "saving and deleting go back to the fuel entries" do
    delete gear_fuel_entry_path(@gear, fuel_entries(:fill_up))
    follow_redirect!
    assert_select "h2#fuel_entries[data-controller=scroll-into-view]"
  end

  test "destroy" do
    assert_difference -> { FuelEntry.count }, -1 do
      delete gear_fuel_entry_path(@gear, fuel_entries(:fill_up))
    end
  end

  test "another user's fuel entries are off limits" do
    post gear_fuel_entries_path(gears(:truck)), params: { fuel_entry: { total_price: "30", entered_amount: "9" } }
    assert_response :not_found

    delete gear_fuel_entry_path(gears(:truck), fuel_entries(:truck_fill_up))
    assert_response :not_found

    delete gear_fuel_entry_path(@gear, fuel_entries(:truck_fill_up))
    assert_response :not_found

    assert FuelEntry.exists?(fuel_entries(:truck_fill_up).id)
  end
end
