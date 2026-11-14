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
      post gear_fuel_entries_path(@gear), params: { fuel_entry: { total_price: "35.20", amount: "9.8", odometer: "", trip: "", filled_on: "" } }
    end

    assert_redirected_to @gear
    assert_equal Date.current, FuelEntry.last.filled_on
    assert_nil FuelEntry.last.odometer
  end

  test "create with odometer and trip" do
    post gear_fuel_entries_path(@gear), params: { fuel_entry: { total_price: "35.20", amount: "9.8", odometer: "240500", trip: "458.3", filled_on: "2026-01-02" } }

    assert_equal 240500, FuelEntry.last.odometer
    assert_equal 458.3.to_d, FuelEntry.last.trip
  end

  test "create requires an amount" do
    assert_no_difference -> { FuelEntry.count } do
      post gear_fuel_entries_path(@gear), params: { fuel_entry: { total_price: "", amount: "" } }
    end

    assert_response :unprocessable_content
  end

  test "create rejects gear that doesn't use fuel" do
    assert_no_difference -> { FuelEntry.count } do
      post gear_fuel_entries_path(gears(:tires)), params: { fuel_entry: { total_price: "30", amount: "9" } }
    end

    assert_response :unprocessable_content
  end

  test "create an energy entry with minutes of use" do
    sign_in_as users(:two)
    post gear_fuel_entries_path(gears(:drill)), params: { fuel_entry: { amount: "0.25", minutes: "20", total_price: "" } }

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

    post gear_fuel_entries_path(gears(:phev)), params: { fuel_entry: { amount: "12", unit: "kWh" } }
    assert_equal "Energy entry added.", flash[:notice]
    assert_equal "kWh", FuelEntry.last.unit

    post gear_fuel_entries_path(gears(:phev)), params: { fuel_entry: { amount: "8", unit: "gal" } }
    assert_equal "Fuel entry added.", flash[:notice]
    assert_equal "gal", FuelEntry.last.unit
  end

  test "create rejects a unit the gear doesn't use" do
    assert_no_difference -> { FuelEntry.count } do
      post gear_fuel_entries_path(@gear), params: { fuel_entry: { amount: "12", unit: "kWh" } }
    end

    assert_response :unprocessable_content
  end

  test "only vehicles get distance fields" do
    get new_gear_fuel_entry_path(@gear)
    assert_select "input[name=?]", "fuel_entry[trip]"

    sign_in_as users(:two)
    get new_gear_fuel_entry_path(gears(:drill))
    assert_select "input[name=?]", "fuel_entry[trip]", count: 0
  end

  test "edit" do
    get edit_gear_fuel_entry_path(@gear, fuel_entries(:fill_up))
    assert_response :success
  end

  test "update" do
    patch gear_fuel_entry_path(@gear, fuel_entries(:fill_up)), params: { fuel_entry: { amount: "11" } }

    assert_redirected_to @gear
    assert_equal 11, fuel_entries(:fill_up).reload.amount
  end

  test "update can't change the unit" do
    patch gear_fuel_entry_path(gears(:phev), gears(:phev).fuel_entries.create!(amount: 8)), params: { fuel_entry: { unit: "kWh" } }

    assert_equal "gal", FuelEntry.last.reload.unit
  end

  test "destroy" do
    assert_difference -> { FuelEntry.count }, -1 do
      delete gear_fuel_entry_path(@gear, fuel_entries(:fill_up))
    end
  end

  test "another user's fuel entries are off limits" do
    post gear_fuel_entries_path(gears(:truck)), params: { fuel_entry: { total_price: "30", amount: "9" } }
    assert_response :not_found

    delete gear_fuel_entry_path(gears(:truck), fuel_entries(:truck_fill_up))
    assert_response :not_found

    delete gear_fuel_entry_path(@gear, fuel_entries(:truck_fill_up))
    assert_response :not_found

    assert FuelEntry.exists?(fuel_entries(:truck_fill_up).id)
  end
end
