require "test_helper"

# Expenses, fuel entries and readings share their actions, so most behavior is
# tested once here, through expenses and readings.
class Api::V1::GearRecordsTest < ActionDispatch::IntegrationTest
  setup { @prius = gears(:prius) }

  test "index lists newest first, with a limit" do
    @prius.expenses.create!(spent_on: Date.current, description: "Wash", amount: 15)

    get api_v1_gear_expenses_path(@prius, limit: 1), headers: api_headers

    assert_response :success
    assert_equal [ "Wash" ], json["expenses"].pluck("description")
  end

  test "a limit that isn't a number is reported" do
    get api_v1_gear_expenses_path(@prius, limit: "lots"), headers: api_headers

    assert_response :unprocessable_content
  end

  test "create an expense, using date for the date" do
    post api_v1_gear_expenses_path(@prius), params: { date: "2026-11-02", description: "Toll", amount: 12, currency: "EUR", notes: "Trip to Lyon" }, headers: api_headers, as: :json

    assert_response :created
    expense = @prius.expenses.find(json["id"])
    assert_equal [ Date.new(2026, 11, 2), 12, "EUR", "Trip to Lyon" ], expense.values_at(:spent_on, :amount, :currency, :notes)
    assert_equal "2026-11-02", json["date"]
    assert_equal api_v1_gear_expense_url(@prius, expense), response.location
  end

  test "an expense in the default currency" do
    post api_v1_gear_expenses_path(@prius), params: { date: "2026-11-02", description: "Wash", amount: 10 }, headers: api_headers, as: :json

    assert_equal "USD", json["currency"]
  end

  test "create reports missing fields" do
    post api_v1_gear_expenses_path(@prius), params: { amount: 12 }, headers: api_headers, as: :json

    assert_response :unprocessable_content
    assert_includes json["details"]["description"], "can't be blank"
  end

  test "a bad date is reported, not replaced" do
    post api_v1_gear_expenses_path(@prius), params: { date: "yesterday", description: "Toll", amount: 12 }, headers: api_headers, as: :json

    assert_response :unprocessable_content
    assert_equal "date must be a date like 2026-01-31", json["error"]
  end

  test "update and delete a reading" do
    reading = @prius.readings.first

    patch api_v1_gear_reading_path(@prius, reading), params: { value: 33.5, notes: "After rotation" }, headers: api_headers, as: :json
    assert_response :success
    assert_equal [ 33.5, "After rotation" ], reading.reload.values_at(:value, :notes)

    delete api_v1_gear_reading_path(@prius, reading), headers: api_headers
    assert_response :no_content
    assert_not Reading.exists?(reading.id)
  end

  test "create a reading" do
    post api_v1_gear_readings_path(@prius), params: { date: "2026-11-02", name: "Tire pressure FL", value: 34, unit: "psi" }, headers: api_headers, as: :json

    assert_response :created
    assert_equal [ "Tire pressure FL", 34.0, "psi" ], json.values_at("name", "value", "unit")
  end

  test "records of a component are reached through the component" do
    get api_v1_gear_expenses_path(gears(:tires)), headers: api_headers

    assert_equal [ "Rotation" ], json["expenses"].pluck("description")
  end
end
