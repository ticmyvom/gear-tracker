# Whether the tank was filled up (or the battery charged to its usual level).
# Efficiency is only exact between full tanks. Entries made before this count as
# full, which is how their efficiency was worked out until now.
class AddFilledUpToFuelEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :fuel_entries, :filled_up, :boolean, default: true, null: false
  end
end
