# A fuel fill-up or a log of electricity used, for gear that runs on either.
class FuelEntry < ApplicationRecord
  belongs_to :gear

  before_validation { self.filled_on ||= Date.current }
  # Keeps the unit the entry was logged in, even if the gear's power source changes later.
  before_validation(on: :create) { self.unit = gear&.fuel_unit if unit.blank? }

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :total_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :odometer, :trip, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :gear_uses_fuel, on: :create

  # Before it's saved, a new entry takes its unit from the gear.
  def display_unit
    unit.presence || gear&.fuel_unit
  end

  def electric?
    display_unit == "kWh"
  end

  # The only place these names are set; views ask for them by unit.
  def self.log_name_for(unit)
    unit == "kWh" ? "Energy use" : "Fuel"
  end

  def self.label_for(unit)
    unit == "kWh" ? "energy entry" : "fuel entry"
  end

  def label
    self.class.label_for(display_unit)
  end

  # Miles per gallon or per kWh.
  def distance_per_unit
    trip / amount if trip&.positive?
  end

  # Gallons or kWh per hour of use.
  def amount_per_hour
    amount * 60 / minutes if minutes&.positive?
  end

  private
    def gear_uses_fuel
      errors.add(:gear, "must run on fuel or electricity") unless gear&.fuel_unit
    end
end
