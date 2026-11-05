class FuelEntry < ApplicationRecord
  belongs_to :gear

  before_validation { self.filled_on ||= Date.current }

  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :gallons, presence: true, numericality: { greater_than: 0 }
  validates :odometer, :trip, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :gear_is_a_vehicle, on: :create

  def mpg
    trip / gallons if trip&.positive?
  end

  private
    def gear_is_a_vehicle
      errors.add(:gear, "must be in the Vehicle category") unless gear&.vehicle?
    end
end
