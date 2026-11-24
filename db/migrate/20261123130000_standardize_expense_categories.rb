# Moves expenses from free-text categories to the fixed list in Expense::CATEGORIES.
# The mapping is copied here, not read from the model, so this migration keeps
# doing the same thing even if the list changes later. Text that doesn't match
# becomes "other", and the old text is kept at the top of the expense's notes.
class StandardizeExpenseCategories < ActiveRecord::Migration[8.1]
  class MigrationExpense < ActiveRecord::Base
    self.table_name = "expenses"
  end

  NAMES = {
    "maintenance" => "Maintenance", "repair" => "Repair", "tires" => "Tires", "parts" => "Parts & accessories",
    "insurance" => "Insurance", "registration" => "Registration & inspection",
    "taxes" => "Taxes & fees", "financing" => "Loan interest & lease", "parking" => "Parking & tolls",
    "cleaning" => "Cleaning", "subscriptions" => "Subscriptions", "other" => "Other"
  }.freeze

  # Old free text, lowercased => new key, beyond the keys and names themselves.
  SIMILAR = {
    "service" => "maintenance", "oil change" => "maintenance", "tune-up" => "maintenance",
    "repairs" => "repair", "tire" => "tires", "part" => "parts", "accessory" => "parts", "accessories" => "parts",
    "inspection" => "registration", "tax" => "taxes", "fee" => "taxes", "fees" => "taxes",
    "loan interest" => "financing", "interest" => "financing", "lease" => "financing",
    "toll" => "parking", "tolls" => "parking", "car wash" => "cleaning", "wash" => "cleaning", "subscription" => "subscriptions"
  }.freeze

  def up
    MigrationExpense.where.not(category: [ nil, "" ]).find_each do |expense|
      text = expense.category.strip
      key = NAMES.find { |k, name| text.casecmp?(k) || text.casecmp?(name) }&.first || SIMILAR[text.downcase]
      if text.empty?
        expense.update_columns(category: nil)
      elsif key
        expense.update_columns(category: key)
      else
        expense.update_columns(category: "other", notes: [ "Category: #{text}", expense.notes.presence ].compact.join("\n\n"))
      end
    end
    MigrationExpense.where(category: "").update_all(category: nil)
  end

  # Turns keys back into names. Text that became "other" stays "Other"; its old
  # text is still at the top of the notes.
  def down
    NAMES.each { |key, name| MigrationExpense.where(category: key).update_all(category: name) }
  end
end
