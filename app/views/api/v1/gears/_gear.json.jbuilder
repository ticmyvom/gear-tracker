costs = ->(totals) { totals&.map { |currency, amount| { currency: currency, amount: amount.to_f.round(2) } } }

json.call(gear, :id, :name, :category, :category_name, :power_source, :parent_id, :purchased_on, :currency, :purchased_from, :notes)
json.price gear.price&.to_f
json.fuel_kinds(gear.fuel_units.map { FuelEntry::KINDS.key(it) })
json.total_cost costs.call(gear.total_cost)
json.cost_per_year costs.call(gear.cost_per_year)
json.call(gear, :created_at, :updated_at)
