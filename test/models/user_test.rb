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

  test "rejects a short password" do
    assert_not User.new(email_address: "new@example.com", password: "short").valid?
  end
end
