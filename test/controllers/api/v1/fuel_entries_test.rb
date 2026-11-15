require "test_helper"

class Api::V1::FuelEntriesTest < ActionDispatch::IntegrationTest
  test "an energy entry with time used, as an agent would log it" do
    post api_v1_gear_fuel_entries_path(gears(:drill)), params: { amount: 0.014, hours: 3, notes: "Bedroom" }, headers: api_headers("gt_two_write"), as: :json

    assert_response :created
    assert_equal [ "energy", 0.014, "kWh", 180, 4.667, "W" ], json.values_at("kind", "amount", "amount_unit", "minutes", "rate", "rate_unit")
  end

  test "hours and minutes add up" do
    post api_v1_gear_fuel_entries_path(gears(:prius)), params: { amount: 1, hours: 1.5, minutes: 10 }, headers: api_headers, as: :json

    assert_equal 100, json["minutes"]
  end

  test "amounts and distances are in the user's units" do
    post api_v1_gear_fuel_entries_path(gears(:prius)), params: { amount: 10, trip: 300, odometer: 100_000 }, headers: api_headers, as: :json

    assert_equal [ 10.0, "gal", 300.0, 100_000.0, "mi", 30.0, "mi/gal" ], json.values_at("amount", "amount_unit", "trip", "odometer", "distance_unit", "efficiency", "efficiency_unit")
    assert_in_delta 37.854, FuelEntry.find(json["id"]).amount, 0.001 # stored in liters
  end

  test "a metric user's entries are in km and liters" do
    get api_v1_gear_fuel_entries_path(gears(:truck)), headers: api_headers("gt_two_write")

    assert_equal [ "L", "km" ], json["fuel_entries"].first.values_at("amount_unit", "distance_unit")
  end

  test "a plug-in hybrid takes either kind, fuel by default" do
    post api_v1_gear_fuel_entries_path(gears(:phev)), params: { amount: 8 }, headers: api_headers, as: :json
    assert_equal "fuel", json["kind"]

    post api_v1_gear_fuel_entries_path(gears(:phev)), params: { kind: "energy", amount: 12 }, headers: api_headers, as: :json
    assert_equal [ "energy", "kWh" ], json.values_at("kind", "amount_unit")
  end

  test "a kind the gear doesn't use is rejected" do
    [ "energy", "plutonium" ].each do |kind|
      post api_v1_gear_fuel_entries_path(gears(:prius)), params: { kind: kind, amount: 8 }, headers: api_headers, as: :json

      assert_response :unprocessable_content
      assert_includes json["details"]["unit"], "isn't used by this gear"
    end
  end

  test "the kind can't be changed later" do
    patch api_v1_gear_fuel_entry_path(gears(:prius), fuel_entries(:fill_up)), params: { kind: "energy" }, headers: api_headers, as: :json

    assert_response :unprocessable_content
    assert_match "Unknown field: kind", json["error"]
  end

  test "gear that doesn't use fuel can't log it" do
    post api_v1_gear_fuel_entries_path(gears(:tires)), params: { amount: 8 }, headers: api_headers, as: :json

    assert_response :unprocessable_content
    assert_includes json["details"]["gear"], "must run on fuel or electricity"
  end

  test "zero time used is rejected" do
    post api_v1_gear_fuel_entries_path(gears(:prius)), params: { amount: 1, minutes: 0 }, headers: api_headers, as: :json

    assert_response :unprocessable_content
    assert_match "Time used must be greater than 0", json["error"]
  end
end
