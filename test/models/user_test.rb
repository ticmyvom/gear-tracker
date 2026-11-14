require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "rejects a duplicate email address regardless of case" do
    user = User.new(email_address: users(:one).email_address.upcase, password: "long enough")

    assert_not user.valid?
  end

  test "new users default to dollars, miles and US gallons" do
    user = User.new

    assert_equal "USD", user.currency
    assert_equal "mi", user.distance_unit
    assert_equal "us_gal", user.volume_unit
  end

  test "rejects unknown currency and units" do
    user = users(:one)

    assert_not user.update(currency: "XYZ")
    assert_not user.update(currency: "USD", distance_unit: "furlong")
    assert_not user.update(distance_unit: "mi", volume_unit: "barrel")
  end

  test "rejects a short password" do
    assert_not User.new(email_address: "new@example.com", password: "short").valid?
  end
end
