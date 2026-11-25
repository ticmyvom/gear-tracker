# Whether the owner checked an unusual efficiency and says it's right.
class AddEfficiencyCheckedToFuelEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :fuel_entries, :efficiency_checked, :boolean, default: false, null: false
  end
end
