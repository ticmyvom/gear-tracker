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
