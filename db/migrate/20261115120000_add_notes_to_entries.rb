class AddNotesToEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :expenses, :notes, :text
    add_column :fuel_entries, :notes, :text
    add_column :readings, :notes, :text
  end
end
