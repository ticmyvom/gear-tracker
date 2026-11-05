class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :gear, null: false, foreign_key: true
      t.date :spent_on, null: false
      t.string :description, null: false
      t.string :category
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :vendor

      t.timestamps
    end
  end
end
