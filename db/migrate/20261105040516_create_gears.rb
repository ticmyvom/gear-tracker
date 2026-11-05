class CreateGears < ActiveRecord::Migration[8.1]
  def change
    create_table :gears do |t|
      t.references :user, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :gears }
      t.string :name, null: false
      t.string :category
      t.date :purchased_on
      t.decimal :price, precision: 12, scale: 2
      t.string :purchased_from
      t.text :notes

      t.timestamps
    end
  end
end
