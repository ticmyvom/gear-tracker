class AddPowerSourceToGears < ActiveRecord::Migration[8.1]
  def change
    add_column :gears, :power_source, :string

    # Fuel entries now cover electricity too, so the amount carries its own unit.
    rename_column :fuel_entries, :gallons, :amount
    add_column :fuel_entries, :unit, :string, null: false, default: "gal"
    change_column_default :fuel_entries, :unit, from: "gal", to: nil
    add_column :fuel_entries, :minutes, :integer
    change_column_null :fuel_entries, :total_price, true

    reversible do |direction|
      direction.up do
        # Before this, only vehicles could log fuel, and always in gallons of gas.
        execute <<~SQL
          UPDATE gears SET power_source = 'gasoline'
          WHERE LOWER(TRIM(category)) = 'vehicle' OR id IN (SELECT gear_id FROM fuel_entries)
        SQL
      end
    end
  end
end
