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
    assert_select "th", text: "Per hour", count: 0

    gears(:prius).fuel_entries.create!(amount: 1, minutes: 30)
    get gear_path(gears(:prius))
    assert_select "th", text: "Per hour"
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

  test "show offers energy entries for electric gear" do
    sign_in_as users(:two)
    get gear_path(gears(:drill))

    assert_select "h2", text: "Energy use"
    assert_select "a", text: "Add energy entry"
  end

  test "create" do
    assert_difference -> { users(:one).gears.count } do
      post gears_path, params: { gear: { name: "Tent", power_source: "manual", price: "199.99", purchased_on: "2026-01-02", purchased_from: "REI" } }
    end

    assert_redirected_to Gear.last
    assert_equal "REI", Gear.last.purchased_from
    assert_equal "manual", Gear.last.power_source
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
end
