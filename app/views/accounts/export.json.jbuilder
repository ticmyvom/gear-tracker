# Uses the API's formats, so amounts are in the user's units and labeled.
json.app_version GearTracker::VERSION
json.exported_at Time.current
json.account do
  json.call(Current.user, :email_address, :username, :display_name, :profile_public, :currency, :distance_unit, :volume_unit, :created_at)
end
json.gears @gears do |gear|
  json.partial! "api/v1/gears/gear", gear: gear
  json.call(gear, :public, :public_costs)
  json.expenses gear.expenses.sort_by(&:spent_on), partial: "api/v1/expenses/expense", as: :expense
  json.fuel_entries gear.fuel_entries.sort_by { [ it.filled_on, it.id ] }, partial: "api/v1/fuel_entries/fuel_entry", as: :fuel_entry
  json.readings gear.readings.sort_by(&:read_on), partial: "api/v1/readings/reading", as: :reading
end
