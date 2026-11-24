# What kind of vehicle it is, so similar ones can be found and compared.
class AddVehicleDetailsToGears < ActiveRecord::Migration[8.1]
  def change
    add_column :gears, :year, :integer
    add_column :gears, :make, :string
    add_column :gears, :model, :string
    add_column :gears, :trim, :string
  end
end
