class ExpensesController < ApplicationController
  before_action :set_gear
  before_action :set_expense, only: %i[ edit update destroy ]

  def new
    @expense = @gear.expenses.new(spent_on: Date.current)
  end

  def edit
  end

  def create
    @expense = @gear.expenses.new(expense_params)

    if @expense.save
      redirect_to @gear, notice: "Expense added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @expense.update(expense_params)
      redirect_to @gear, notice: "Expense updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @expense.destroy!
    redirect_to @gear, notice: "Expense deleted.", status: :see_other
  end

  private
    def set_gear
      @gear = Current.user.gears.find(params[:gear_id])
    end

    def set_expense
      @expense = @gear.expenses.find(params[:id])
    end

    def expense_params
      params.expect(expense: %i[ spent_on description category amount currency vendor ])
    end
end
