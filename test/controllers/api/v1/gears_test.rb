require "test_helper"

class Api::V1::GearsTest < ActionDispatch::IntegrationTest
  test "index lists gear with totals per currency" do
    get api_v1_gears_path, headers: api_headers

    assert_response :success
    prius = json["gears"].find { it["name"] == "2010 Toyota Prius" }
    assert_equal [ { "currency" => "USD", "amount" => 8715.0 } ], prius["total_cost"]
    assert_equal [ "fuel" ], prius["fuel_kinds"]
    assert_equal 8000.0, prius["price"]
  end

  test "show includes components" do
    get api_v1_gear_path(gears(:prius)), headers: api_headers

    assert_equal [ { "id" => gears(:tires).id, "name" => "Michelin tires" } ], json["components"]
  end

  test "create" do
    post api_v1_gears_path, params: { name: "Air filter", category: "Household", power_source: "electric", price: 89.99, purchased_on: "2026-11-01" }, headers: api_headers, as: :json

    assert_response :created
    gear = users(:one).gears.find(json["id"])
    assert_equal [ "Air filter", "electric", 89.99, "USD" ], [ gear.name, gear.power_source, gear.price, gear.currency ]
    assert_equal api_v1_gear_url(gear), response.location
    assert_equal [ "energy" ], json["fuel_kinds"]
    assert_equal [ "household", "Household" ], json.values_at("category", "category_name")
  end

  test "vehicle details can be read, sent and cleared" do
    get api_v1_gear_path(gears(:prius)), headers: api_headers
    assert_equal [ 2010, "Toyota", "Prius", "Two" ], json.values_at("year", "make", "model", "trim")

    post api_v1_gears_path, params: { name: "Daily", category: "vehicle", year: 2015, make: "honda", model: "Fit" }, headers: api_headers, as: :json
    assert_response :created
    assert_equal [ 2015, "Honda", "Fit", nil ], json.values_at("year", "make", "model", "trim")

    patch api_v1_gear_path(gears(:prius)), params: { trim: nil }, headers: api_headers, as: :json
    assert_nil gears(:prius).reload.trim
  end

  test "a vehicle can be added without a name" do
    post api_v1_gears_path, params: { category: "vehicle", year: 2015, make: "Honda" }, headers: api_headers, as: :json

    assert_response :created
    assert_equal "2015 Honda", json["name"]
  end

  test "create refuses a category that isn't on the list, and names the allowed ones" do
    post api_v1_gears_path, params: { name: "Air filter", category: "Home" }, headers: api_headers, as: :json

    assert_response :unprocessable_content
    assert_match "must be one of: vehicle, bicycle", json["details"]["category"].first
  end

  test "create reports validation errors per field" do
    post api_v1_gears_path, params: { name: "", power_source: "nuclear" }, headers: api_headers, as: :json

    assert_response :unprocessable_content
    assert_includes json["details"]["name"], "can't be blank"
    assert_includes json["details"]["power_source"], "is not included in the list"
  end

  test "update changes only the fields sent" do
    patch api_v1_gear_path(gears(:prius)), params: { notes: "Bought in Austin" }, headers: api_headers, as: :json

    assert_response :success
    assert_equal [ "Bought in Austin", "2010 Toyota Prius" ], gears(:prius).reload.values_at(:notes, :name)
  end

  test "null clears a field" do
    gears(:prius).update!(notes: "Old note")
    patch api_v1_gear_path(gears(:prius)), params: { notes: nil }, headers: api_headers, as: :json

    assert_response :success
    assert_nil gears(:prius).reload.notes
  end

  test "a misspelled field is reported, not ignored" do
    post api_v1_gears_path, params: { name: "Tent", prise: 200 }, headers: api_headers, as: :json

    assert_response :unprocessable_content
    assert_match "Unknown field: prise", json["error"]
    assert_match "Allowed: name", json["error"]
  end

  test "a date that isn't YYYY-MM-DD is reported" do
    post api_v1_gears_path, params: { name: "Tent", purchased_on: "last Tuesday" }, headers: api_headers, as: :json

    assert_response :unprocessable_content
    assert_equal "purchased_on must be a date like 2026-01-31", json["error"]
  end
end
