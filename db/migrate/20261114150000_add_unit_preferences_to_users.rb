class AddUnitPreferencesToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :currency, :string, null: false, default: "USD"
    add_column :users, :distance_unit, :string, null: false, default: "mi"
    add_column :users, :volume_unit, :string, null: false, default: "us_gal"

    # Fuel entries stay in miles and US gallons. More decimal places let a value
    # typed in km or liters convert back exactly.
    change_column :fuel_entries, :amount, :decimal, precision: 16, scale: 6, null: false
    change_column :fuel_entries, :odometer, :decimal, precision: 16, scale: 6
    change_column :fuel_entries, :trip, :decimal, precision: 16, scale: 6
  end

  def down
    change_column :fuel_entries, :amount, :decimal, precision: 10, scale: 3, null: false
    change_column :fuel_entries, :odometer, :decimal, precision: 10, scale: 1
    change_column :fuel_entries, :trip, :decimal, precision: 10, scale: 1

    remove_column :users, :currency
    remove_column :users, :distance_unit
    remove_column :users, :volume_unit
  end
end
