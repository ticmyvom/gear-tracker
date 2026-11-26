json.call(expense, :id, :gear_id)
json.date expense.spent_on
json.call(expense, :description, :category, :category_name, :currency, :vendor, :notes)
json.amount expense.amount&.to_f
json.odometer expense.entered_odometer&.to_f
json.distance_unit expense.distance_label
json.call(expense, :created_at, :updated_at)
