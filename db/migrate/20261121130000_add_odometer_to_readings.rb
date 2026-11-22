# Lets a reading note the odometer, in kilometers like fuel entries.
class AddOdometerToReadings < ActiveRecord::Migration[8.1]
  def change
    add_column :readings, :odometer, :decimal, precision: 16, scale: 6
  end
end
