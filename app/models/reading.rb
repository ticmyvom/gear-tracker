# A measurement over time, like tire pressure. Readings of vehicles and their
# parts can also note the odometer, stored in kilometers and shown in the
# owner's units.
class Reading < ApplicationRecord
  include HasOdometer

  SUGGESTED_NAMES = [ "Tire pressure FL", "Tire pressure FR", "Tire pressure RL", "Tire pressure RR", "Tread depth" ].freeze

  belongs_to :gear

  validates :read_on, :name, presence: true
  validates :value, presence: true, numericality: true
end
