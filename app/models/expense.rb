class Expense < ApplicationRecord
  include Priced
  include Categorized

  CATEGORIES = {
    "maintenance" => "Maintenance",
    "repair" => "Repair",
    "tires" => "Tires",
    "parts" => "Parts & accessories",
    "insurance" => "Insurance",
    "registration" => "Registration & inspection",
    "taxes" => "Taxes & fees",
    "financing" => "Loan interest & lease",
    "parking" => "Parking & tolls",
    "cleaning" => "Cleaning",
    "subscriptions" => "Subscriptions",
    "other" => "Other"
  }.freeze
  # Suggested before the list was fixed, so it's in older data files.
  CATEGORY_ALIASES = { "accessory" => "parts" }.freeze

  belongs_to :gear

  validates :spent_on, :description, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  private
    def currency_owner
      gear&.user
    end
end
