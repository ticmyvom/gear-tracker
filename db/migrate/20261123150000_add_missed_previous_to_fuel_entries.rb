# Whether a fill-up (or charge) before this one wasn't logged, so the fuel since
# the last full tank isn't all known.
class AddMissedPreviousToFuelEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :fuel_entries, :missed_previous, :boolean, default: false, null: false
  end
end
