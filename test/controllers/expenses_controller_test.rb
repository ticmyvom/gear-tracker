require "test_helper"

class ExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @gear = gears(:prius)
  end

  test "new" do
    get new_gear_expense_path(@gear)
    assert_response :success
  end

  test "create" do
    assert_difference -> { @gear.expenses.count } do
      post gear_expenses_path(@gear), params: { expense: { spent_on: "2026-01-02", description: "Fuel", amount: "30.50", vendor: "Costco" } }
    end

    assert_redirected_to @gear
  end

  test "category is picked from the list, and shown by name" do
    get new_gear_expense_path(@gear)
    assert_select "select[name=?] option[value=parking]", "expense[category]", text: "Parking & tolls"

    post gear_expenses_path(@gear), params: { expense: { spent_on: "2026-01-02", description: "Bridge", category: "parking", amount: "8" } }
    follow_redirect!
    assert_select "td", text: "Parking & tolls"
  end

  test "create refuses a category that isn't on the list" do
    assert_no_difference -> { Expense.count } do
      post gear_expenses_path(@gear), params: { expense: { spent_on: "2026-01-02", description: "Chips", category: "Snacks", amount: "8" } }
    end

    assert_response :unprocessable_content
  end

  test "saving goes back to the expenses, and only then" do
    post gear_expenses_path(@gear), params: { expense: { spent_on: "2026-01-02", description: "Wash", amount: "9" } }
    assert_equal :expenses, flash[:section]
    follow_redirect!
    assert_select "h2#expenses[data-controller=scroll-into-view]"
    assert_select "[data-controller=scroll-into-view]", count: 1

    get gear_path(@gear)
    assert_select "h2#expenses:not([data-controller])"
  end

  test "cancel goes back to the expenses" do
    get new_gear_expense_path(@gear)
    assert_select "a[href=?]", gear_path(@gear, anchor: "expenses"), text: "Cancel"
  end

  test "create requires an amount" do
    assert_no_difference -> { Expense.count } do
      post gear_expenses_path(@gear), params: { expense: { spent_on: "2026-01-02", description: "Fuel", amount: "" } }
    end

    assert_response :unprocessable_content
  end

  test "update" do
    patch gear_expense_path(@gear, expenses(:oil_change)), params: { expense: { amount: "60" } }

    assert_redirected_to @gear
    assert_equal 60, expenses(:oil_change).reload.amount
  end

  test "create in another currency" do
    post gear_expenses_path(@gear), params: { expense: { spent_on: "2026-01-02", description: "Toll", amount: "12", currency: "EUR" } }

    assert_equal "EUR", Expense.last.currency
    follow_redirect!
    assert_select "td", text: "€12.00"
  end

  test "update amount and currency together" do
    patch gear_expense_path(@gear, expenses(:oil_change)), params: { expense: { amount: "45", currency: "GBP" } }

    assert_equal [ 45, "GBP" ], expenses(:oil_change).reload.values_at(:amount, :currency)
  end

  test "edit form picks the expense's currency" do
    get edit_gear_expense_path(@gear, expenses(:oil_change))

    assert_select "select[name=?] option[selected][value=USD]", "expense[currency]"
  end

  test "create and edit with notes" do
    post gear_expenses_path(@gear), params: { expense: { spent_on: "2026-01-02", description: "Brakes", amount: "300", notes: "Front pads only.\nRotors next time." } }
    assert_equal "Front pads only.\nRotors next time.", Expense.last.notes

    get edit_gear_expense_path(@gear, Expense.last)
    assert_select "textarea[name=?]", "expense[notes]", text: "Front pads only.\nRotors next time."
  end

  test "destroy" do
    assert_difference -> { Expense.count }, -1 do
      delete gear_expense_path(@gear, expenses(:oil_change))
    end
  end

  test "another user's expenses are off limits" do
    post gear_expenses_path(gears(:drill)), params: { expense: { spent_on: "2026-01-02", description: "Bits", amount: "5" } }
    assert_response :not_found

    delete gear_expense_path(gears(:drill), expenses(:drill_bits))
    assert_response :not_found

    delete gear_expense_path(@gear, expenses(:drill_bits))
    assert_response :not_found

    assert Expense.exists?(expenses(:drill_bits).id)
  end
end
