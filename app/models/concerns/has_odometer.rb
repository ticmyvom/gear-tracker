# An optional odometer, for records of vehicles and their parts, like readings
# and expenses. Stored in kilometers and typed and shown in the owner's units
# as entered_odometer.
module HasOdometer
  extend ActiveSupport::Concern
  include EnteredUnits

  included do
    delegate :distance_unit, to: :gear

    entered_fields odometer: 1
    before_validation :store_entered_values
    validates :odometer, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  end

  private
    def stored_unit_for(_field) = "km"
    def preferred_unit_for(_field) = distance_unit
end
