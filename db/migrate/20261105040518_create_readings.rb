class CreateReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :readings do |t|
      t.references :gear, null: false, foreign_key: true
      t.date :read_on, null: false
      t.string :name, null: false
      t.decimal :value, precision: 12, scale: 3, null: false
      t.string :unit

      t.timestamps
    end
  end
end
