class StoreFuelEntriesInMetric < ActiveRecord::Migration[8.1]
  KM_PER_MILE = "1.609344"
  LITERS_PER_US_GALLON = "3.785411784"

  def up
    execute "UPDATE fuel_entries SET amount = ROUND(amount * #{LITERS_PER_US_GALLON}, 6), unit = 'l' WHERE unit = 'gal'"
    execute "UPDATE fuel_entries SET odometer = ROUND(odometer * #{KM_PER_MILE}, 6), trip = ROUND(trip * #{KM_PER_MILE}, 6)"
  end

  def down
    execute "UPDATE fuel_entries SET amount = ROUND(amount / #{LITERS_PER_US_GALLON}, 6), unit = 'gal' WHERE unit = 'l'"
    execute "UPDATE fuel_entries SET odometer = ROUND(odometer / #{KM_PER_MILE}, 6), trip = ROUND(trip / #{KM_PER_MILE}, 6)"
  end
end
