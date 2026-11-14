require "test_helper"

class UnitsTest < ActiveSupport::TestCase
  test "converts distance" do
    assert_in_delta 160.934, Units.convert(100, "mi", "km"), 0.001
    assert_in_delta 62.137, Units.convert(100, "km", "mi"), 0.001
  end

  test "converts volume" do
    assert_in_delta 3.785, Units.convert(1, "us_gal", "l"), 0.001
    assert_in_delta 4.546, Units.convert(1, "uk_gal", "l"), 0.001
    assert_in_delta 0.833, Units.convert(1, "us_gal", "uk_gal"), 0.001
  end

  test "leaves nil and same-unit values alone" do
    assert_nil Units.convert(nil, "mi", "km")
    assert_equal 5, Units.convert(5, "kWh", "kWh")
  end
end
