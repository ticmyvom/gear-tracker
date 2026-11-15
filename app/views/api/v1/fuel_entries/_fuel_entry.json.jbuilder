# Values are in the user's units, named by the *_unit fields.
json.call(fuel_entry, :id, :gear_id)
json.date fuel_entry.filled_on
json.kind fuel_entry.kind
json.amount fuel_entry.entered_amount&.to_f
json.amount_unit fuel_entry.amount_label
json.total_price fuel_entry.total_price&.to_f
json.currency fuel_entry.currency
json.minutes fuel_entry.minutes
json.rate fuel_entry.usage_rate&.to_f&.round(3)
json.rate_unit fuel_entry.usage_rate_label
json.odometer fuel_entry.entered_odometer&.to_f
json.trip fuel_entry.entered_trip&.to_f
json.distance_unit fuel_entry.distance_label
json.efficiency fuel_entry.distance_per_unit&.to_f&.round(2)
json.efficiency_unit "#{fuel_entry.distance_label}/#{fuel_entry.amount_label}"
json.notes fuel_entry.notes
json.call(fuel_entry, :created_at, :updated_at)
