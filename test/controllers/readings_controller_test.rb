require "test_helper"

class ReadingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @gear = gears(:prius)
  end

  test "new" do
    get new_gear_reading_path(@gear)
    assert_response :success
  end

  test "create" do
    assert_difference -> { @gear.readings.count } do
      post gear_readings_path(@gear), params: { reading: { read_on: "2026-01-02", name: "Tire pressure FR", value: "34.5", unit: "psi" } }
    end

    assert_redirected_to @gear
  end

  test "create with notes" do
    post gear_readings_path(@gear), params: { reading: { read_on: "2026-01-02", name: "Tire pressure FR", value: "30", notes: "Slow leak?" } }

    assert_equal "Slow leak?", Reading.last.notes
  end

  test "create requires a value" do
    assert_no_difference -> { Reading.count } do
      post gear_readings_path(@gear), params: { reading: { read_on: "2026-01-02", name: "Odometer", value: "" } }
    end

    assert_response :unprocessable_content
  end

  test "update" do
    patch gear_reading_path(@gear, readings(:pressure)), params: { reading: { value: "36" } }

    assert_redirected_to @gear
    assert_equal 36, readings(:pressure).reload.value
  end

  test "saving and deleting go back to the readings" do
    delete gear_reading_path(@gear, readings(:pressure))
    follow_redirect!
    assert_select "h2#readings[data-controller=scroll-into-view]"
  end

  test "destroy" do
    assert_difference -> { Reading.count }, -1 do
      delete gear_reading_path(@gear, readings(:pressure))
    end
  end

  test "another user's readings are off limits" do
    delete gear_reading_path(gears(:drill), readings(:drill_hours))
    assert_response :not_found

    delete gear_reading_path(@gear, readings(:drill_hours))
    assert_response :not_found

    assert Reading.exists?(readings(:drill_hours).id)
  end

  # --- Odometer ---

  test "vehicles and their parts get an odometer field, other gear doesn't" do
    [ gears(:prius), gears(:tires) ].each do |gear|
      get new_gear_reading_path(gear)
      assert_select "label", "Odometer (mi, optional)"
    end

    get new_gear_reading_path(gears(:phev).tap { it.update!(category: "household") })
    assert_select "input[name='reading[entered_odometer]']", count: 0
  end

  test "a reading saves the odometer, and the gear page shows it in the owner's units" do
    post gear_readings_path(@gear), params: { reading: { read_on: "2026-01-02", name: "Tread depth", value: "6", entered_odometer: "120000" } }

    assert_in_delta 120000 * 1.609344, @gear.readings.find_by!(name: "Tread depth").odometer, 0.01
    get gear_path(@gear)
    assert_select "th", "Odometer (mi)"
    assert_select "td", "120,000"
  end
end
