json.partial! "api/v1/gears/gear", gear: @gear
json.components @gear.components.order(:name), :id, :name
