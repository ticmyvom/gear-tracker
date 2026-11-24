require "test_helper"
require Rails.root.join("db/migrate/20261123130000_standardize_expense_categories")

class StandardizeExpenseCategoriesTest < ActiveSupport::TestCase
  # An expense with the old free text, skipping validation.
  def expense(text, notes: nil)
    gears(:prius).expenses.create!(spent_on: Date.current, description: "Old", amount: 1).tap { it.update_columns(category: text, notes: notes) }
  end

  test "maps names and similar old text to keys, and keeps unknown text in the notes" do
    repair, wash, accessory, unknown, empty, spaces =
      expense(" Repair "), expense("Car wash"), expense("Accessory"), expense("Road trip", notes: "Fun"), expense(""), expense("  ")

    StandardizeExpenseCategories.new.up

    assert_equal [ "repair", "cleaning", "parts", "other", nil, nil ], [ repair, wash, accessory, unknown, empty, spaces ].map { it.reload.category }
    assert_equal "Category: Road trip\n\nFun", unknown.notes
    assert_nil spaces.notes
  end

  test "its keys are all in the list" do
    assert_empty StandardizeExpenseCategories::SIMILAR.values - StandardizeExpenseCategories::NAMES.keys
    assert_empty StandardizeExpenseCategories::NAMES.keys - Expense::CATEGORIES.keys
  end

  test "rolling back turns keys back into names" do
    StandardizeExpenseCategories.new.down

    assert_equal "Maintenance", expenses(:oil_change).reload.category
  end
end
