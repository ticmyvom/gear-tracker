# Lets an expense note the odometer, like "oil change at 152,300 mi", in
# kilometers like readings and fuel entries.
class AddOdometerToExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :expenses, :odometer, :decimal, precision: 16, scale: 6
  end
end
