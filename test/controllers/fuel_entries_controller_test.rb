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
      post gear_fuel_entries_path(@gear), params: { fuel_entry: { total_price: "35.20", gallons: "9.8", odometer: "", trip: "", filled_on: "" } }
    end

    assert_redirected_to @gear
    assert_equal Date.current, FuelEntry.last.filled_on
    assert_nil FuelEntry.last.odometer
  end

  test "create with odometer and trip" do
    post gear_fuel_entries_path(@gear), params: { fuel_entry: { total_price: "35.20", gallons: "9.8", odometer: "240500", trip: "458.3", filled_on: "2026-01-02" } }

    assert_equal 240500, FuelEntry.last.odometer
    assert_equal 458.3.to_d, FuelEntry.last.trip
  end

  test "create requires total price and gallons" do
    assert_no_difference -> { FuelEntry.count } do
      post gear_fuel_entries_path(@gear), params: { fuel_entry: { total_price: "", gallons: "" } }
    end

    assert_response :unprocessable_content
  end

  test "create rejects gear that isn't a vehicle" do
    assert_no_difference -> { FuelEntry.count } do
      post gear_fuel_entries_path(gears(:tires)), params: { fuel_entry: { total_price: "30", gallons: "9" } }
    end

    assert_response :unprocessable_content
  end

  test "edit" do
    get edit_gear_fuel_entry_path(@gear, fuel_entries(:fill_up))
    assert_response :success
  end

  test "update" do
    patch gear_fuel_entry_path(@gear, fuel_entries(:fill_up)), params: { fuel_entry: { gallons: "11" } }

    assert_redirected_to @gear
    assert_equal 11, fuel_entries(:fill_up).reload.gallons
  end

  test "destroy" do
    assert_difference -> { FuelEntry.count }, -1 do
      delete gear_fuel_entry_path(@gear, fuel_entries(:fill_up))
    end
  end

  test "another user's fuel entries are off limits" do
    post gear_fuel_entries_path(gears(:truck)), params: { fuel_entry: { total_price: "30", gallons: "9" } }
    assert_response :not_found

    delete gear_fuel_entry_path(gears(:truck), fuel_entries(:truck_fill_up))
    assert_response :not_found

    delete gear_fuel_entry_path(@gear, fuel_entries(:truck_fill_up))
    assert_response :not_found

    assert FuelEntry.exists?(fuel_entries(:truck_fill_up).id)
  end
end
