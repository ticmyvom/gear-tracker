# Each amount keeps the currency it was entered in, so changing the currency
# setting only affects new records.
class AddCurrencyToPricedRecords < ActiveRecord::Migration[8.1]
  TABLES = %i[ gears expenses fuel_entries ].freeze

  def change
    TABLES.each do |table|
      add_column table, :currency, :string, null: false, default: "USD"
      change_column_default table, :currency, from: "USD", to: nil
    end

    reversible do |direction|
      direction.up do
        execute "UPDATE gears SET currency = (SELECT currency FROM users WHERE users.id = gears.user_id)"
        %w[ expenses fuel_entries ].each do |table|
          execute <<~SQL
            UPDATE #{table} SET currency = (
              SELECT users.currency FROM gears JOIN users ON users.id = gears.user_id WHERE gears.id = #{table}.gear_id
            )
          SQL
        end
      end
    end
  end
end
