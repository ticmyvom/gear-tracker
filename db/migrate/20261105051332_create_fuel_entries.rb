class CreateFuelEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :fuel_entries do |t|
      t.references :gear, null: false, foreign_key: true
      t.date :filled_on, null: false
      t.decimal :total_price, precision: 12, scale: 2, null: false
      t.decimal :gallons, precision: 10, scale: 3, null: false
      t.decimal :odometer, precision: 10, scale: 1
      t.decimal :trip, precision: 10, scale: 1

      t.timestamps
    end
  end
end
