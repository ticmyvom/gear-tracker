require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  teardown { Current.reset }

  test "time tracked is in days, then months and years" do
    assert_equal [ "0 days", "1 day", "59 days", "2 months", "1 year", "1 year 1 month", "2 years 6 months" ],
      [ 0, 1, 59, 61, 366, 400, 914 ].map { time_tracked(it) }
  end

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

  test "money uses a record's own currency when given" do
    assert_equal "£12.00", money(12, "GBP")
  end

  test "money shows mixed totals per currency" do
    assert_equal "$10.00 + €5.50", money(Costs.new("USD" => 10, "EUR" => 5.5))
    assert_equal "$0.00", money(Costs.new)
  end

  test "distances get commas and at most one decimal place" do
    assert_equal "240,042", distance(240042)
    assert_equal "1,234.6", distance(BigDecimal("1234.56"))
    assert_equal "450.2", distance(450.2)
    assert_nil distance(nil)
  end
end
