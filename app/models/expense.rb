class Expense < ApplicationRecord
  include Priced

  SUGGESTED_CATEGORIES = %w[ Maintenance Repair Insurance Registration Accessory ].freeze

  belongs_to :gear

  validates :spent_on, :description, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  private
    def currency_owner
      gear&.user
    end
end
