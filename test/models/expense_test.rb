require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  test "category takes a key, a name in any case or an alias, and stores the key" do
    assert_equal "parking", Expense.new(category: " parking & TOLLS ").category
    assert_equal "Parking & tolls", Expense.new(category: "parking").category_name
    assert_equal "parts", Expense.new(category: "Accessory").category
    assert_nil Expense.new(category: " ").category
  end

  test "category is optional, but must be on the list" do
    expense = expenses(:oil_change)
    expense.category = nil
    assert expense.valid?

    expense.category = "Snacks"
    assert_not expense.valid?
    assert_match "must be one of: maintenance, repair", expense.errors[:category].first
  end

  test "the odometer is optional, typed in the owner's units and stored in kilometers" do
    expense = gears(:prius).expenses.create!(spent_on: Date.current, description: "Oil change", amount: 60, entered_odometer: "1000")

    assert_in_delta 1609.344, expense.reload.odometer, 0.001
    assert_equal 1000, Expense.find(expense.id).entered_odometer
    assert expenses(:oil_change).valid?
    [ "-5", "lots" ].each do |odometer|
      assert_not expenses(:oil_change).tap { it.entered_odometer = odometer }.valid?, odometer
    end
  end

  test "aliases lead to keys on the list" do
    assert_empty Expense::CATEGORY_ALIASES.values - Expense::CATEGORIES.keys
  end
end
