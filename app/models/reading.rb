# A measurement over time, like tire pressure. Readings of vehicles and their
# parts can also note the odometer, stored in kilometers and shown in the
# owner's units.
class Reading < ApplicationRecord
  include EnteredUnits

  SUGGESTED_NAMES = [ "Tire pressure FL", "Tire pressure FR", "Tire pressure RL", "Tire pressure RR", "Tread depth" ].freeze

  belongs_to :gear
  delegate :distance_unit, to: :gear

  entered_fields odometer: 1
  before_validation :store_entered_values

  validates :read_on, :name, presence: true
  validates :value, presence: true, numericality: true
  validates :odometer, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  private
    def stored_unit_for(_field) = "km"
    def preferred_unit_for(_field) = distance_unit
end
