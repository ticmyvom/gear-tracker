class Reading < ApplicationRecord
  SUGGESTED_NAMES = [ "Odometer", "Tire pressure FL", "Tire pressure FR", "Tire pressure RL", "Tire pressure RR", "Tread depth" ].freeze

  belongs_to :gear

  validates :read_on, :name, presence: true
  validates :value, presence: true, numericality: true
end
