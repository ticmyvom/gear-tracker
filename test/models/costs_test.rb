require "test_helper"

class CostsTest < ActiveSupport::TestCase
  test "adds amounts per currency" do
    costs = Costs.new.add(10, "USD").add(5, "EUR").add(2.5, "USD")

    assert_equal 12.5, costs["USD"]
    assert_equal 5, costs["EUR"]
    assert_equal 0, costs["GBP"]
  end

  test "ignores nil amounts" do
    assert_empty Costs.new.add(nil, "USD")
  end

  test "combines and divides" do
    total = Costs.new("USD" => 10) + Costs.new("USD" => 5, "EUR" => 4)

    assert_equal Costs.new("USD" => 15, "EUR" => 4), total
    assert_equal Costs.new("USD" => 7.5, "EUR" => 2), total / 2
  end

  test "sums records by their currency" do
    expenses = [ Expense.new(amount: 10, currency: "USD"), Expense.new(amount: 3, currency: "EUR"), Expense.new(amount: 5, currency: "USD") ]

    assert_equal Costs.new("USD" => 15, "EUR" => 3), Costs.of(expenses, :amount)
  end
end
