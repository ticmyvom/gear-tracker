json.call(reading, :id, :gear_id)
json.date reading.read_on
json.call(reading, :name, :unit, :notes)
json.value reading.value&.to_f
json.odometer reading.entered_odometer&.to_f
json.distance_unit reading.distance_label
json.call(reading, :created_at, :updated_at)
