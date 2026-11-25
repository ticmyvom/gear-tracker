# What the owner of a vehicle chose to show on the public Vehicles page. All off
# by default, and separate from the public profile, which they agreed to before
# this page existed.
class AddVehicleListingToGears < ActiveRecord::Migration[8.1]
  def change
    add_column :gears, :listed, :boolean, default: false, null: false
    add_column :gears, :listed_price, :boolean, default: false, null: false
    add_column :gears, :listed_costs, :boolean, default: false, null: false
    add_column :gears, :listed_economy, :boolean, default: false, null: false
    add_index :gears, :listed
  end
end
