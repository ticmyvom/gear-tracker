require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  teardown { Current.reset }

  test "money uses dollars without a signed-in user" do
    assert_equal "$1,234.50", money(1234.5)
    assert_equal "-", money(nil)
  end

  test "money uses the user's currency" do
    Current.session = users(:one).sessions.create!

    users(:one).update!(currency: "EUR")
    assert_equal "€1,234.50", money(1234.5)

    users(:one).update!(currency: "JPY")
    assert_equal "¥1,235", money(1234.5)

    users(:one).update!(currency: "VND")
    assert_equal "1,234,500 ₫", money(1_234_500)
  end
end
