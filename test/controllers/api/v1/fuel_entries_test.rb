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

  test "efficiency from the odometer, and partial fill-ups" do
    log = ->(**fields) { post api_v1_gear_fuel_entries_path(gears(:prius)), params: fields, headers: api_headers, as: :json }

    log.(amount: 2, odometer: 240_142, filled_up: false)
    assert_equal [ false, 100.0, nil, nil ], json.values_at("filled_up", "distance", "trip", "efficiency")

    log.(amount: 8, odometer: 240_542)
    assert_equal [ true, 400.0, 50.0 ], json.values_at("filled_up", "distance", "efficiency")

    patch api_v1_gear_fuel_entry_path(gears(:prius), json["id"]), params: { trip: 300 }, headers: api_headers, as: :json
    assert_equal [ 300.0, 40.0 ], json.values_at("distance", "efficiency")
  end

  test "a missed fill-up leaves efficiency out" do
    post api_v1_gear_fuel_entries_path(gears(:prius)), params: { amount: 10, odometer: 241_500, missed_previous: true }, headers: api_headers, as: :json

    assert_equal [ true, 2, nil ], json.values_at("missed_previous", "missed_before", "efficiency")
  end

  test "an unusual efficiency is flagged until it's checked" do
    entry = nil
    [ 240_442, 240_842, 241_242, 242_442 ].each { entry = gears(:prius).fuel_entries.create!(entered_amount: 10, entered_odometer: it) }
    path = api_v1_gear_fuel_entry_path(gears(:prius), entry)

    get path, headers: api_headers
    assert_equal [ "high", false ], json.values_at("efficiency_flag", "efficiency_checked")

    patch path, params: { efficiency_checked: true }, headers: api_headers, as: :json
    assert_equal [ nil, true ], json.values_at("efficiency_flag", "efficiency_checked")
  end

  test "the checkboxes can't be null" do
    %w[ filled_up missed_previous efficiency_checked ].each do |field|
      post api_v1_gear_fuel_entries_path(gears(:prius)), params: { amount: 2, field => nil }, headers: api_headers, as: :json

      assert_response :unprocessable_content
      assert json["details"].key?(field)
    end
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

  test "a date left out is today in the user's time zone" do
    users(:one).update!(time_zone: "America/Los_Angeles")

    travel_to Time.utc(2026, 11, 27, 4, 47) do
      post api_v1_gear_fuel_entries_path(gears(:prius)), params: { amount: 9 }, headers: api_headers, as: :json
      assert_equal "2026-11-26", json["date"]

      get api_v1_me_path, headers: api_headers
      assert_equal [ "America/Los_Angeles", "2026-11-26" ], json.values_at("time_zone", "today")
    end
  end
end
