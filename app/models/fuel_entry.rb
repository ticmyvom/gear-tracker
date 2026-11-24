# A fuel fill-up or a log of electricity used, for gear that runs on either.
#
# The database keeps kilometers and liters ("l") or kWh. Forms and the log use
# the owner's preferred units through the entered_* attributes.
class FuelEntry < ApplicationRecord
  include Priced
  include EnteredUnits

  entered_fields amount: 3, odometer: 1, trip: 1

  belongs_to :gear
  delegate :distance_unit, :volume_unit, to: :gear

  before_validation { self.filled_on ||= Date.current }
  # Keeps the unit the entry was logged in, even if the gear's power source changes later.
  before_validation(on: :create) { self.unit = gear&.fuel_units&.first if unit.blank? }
  # Runs after the unit is known, since that decides whether the amount is converted.
  before_validation :store_entered_values
  before_validation :store_time_used

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :total_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :odometer, :trip, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :filled_up, :missed_previous, inclusion: { in: [ true, false ] }
  validate :gear_uses_unit, on: :create

  # Before it's saved, a new entry takes its unit from the gear.
  def display_unit
    unit.presence || gear&.fuel_units&.first
  end

  def electric?
    display_unit == "kWh"
  end

  # What the API calls each stored unit.
  KINDS = { "fuel" => "l", "energy" => "kWh" }.freeze

  def self.unit_for_kind(kind)
    KINDS.fetch(kind.to_s, kind) # an unknown kind fails the unit validation
  end

  def kind
    KINDS.key(display_unit)
  end

  # The only place these names are set; views ask for them by unit.
  def self.log_name_for(units)
    if units.include?("kWh")
      units.include?("l") ? "Fuel and energy use" : "Energy use"
    else
      "Fuel"
    end
  end

  def self.label_for(unit)
    unit == "kWh" ? "energy entry" : "fuel entry"
  end

  def label
    self.class.label_for(display_unit)
  end

  # Time used is typed as hours and/or minutes, and stored as total minutes.
  attr_writer :used_hours, :used_minutes

  def used_hours
    defined?(@used_hours) ? @used_hours : minutes&.div(60)&.nonzero?
  end

  def used_minutes
    defined?(@used_minutes) ? @used_minutes : minutes&.modulo(60)&.nonzero?
  end

  # "gal", "L", "UK gal" or "kWh"
  def amount_label
    Units::LABELS.fetch(preferred_unit_for(:amount))
  end

  # Distance since the entry before, in the owner's units: typed, or from the odometers.
  def distance
    Units.convert(gear.fuel_economy.distance(self), "km", distance_unit)&.round(1) if gear
  end

  # Distance per unit of fuel or energy, like mi/gal or km/L, since the last full tank.
  def distance_per_unit
    per_unit = gear&.fuel_economy&.per_unit(self)
    Units.convert(per_unit, "km", distance_unit) / Units.convert(1, stored_unit_for(:amount), preferred_unit_for(:amount)) if per_unit
  end

  # About how many fill-ups went unlogged just before this one.
  def missed_before
    gear ? gear.fuel_economy.missed_before(self) : 0
  end

  # Average power in watts for electricity, or fuel per hour, like L/h.
  def usage_rate
    return unless minutes&.positive?

    per_hour = preferred(:amount) * 60 / minutes
    electric? ? per_hour * 1000 : per_hour # kWh per hour is kW
  end

  # "W", or fuel per hour like "L/h"
  def usage_rate_label
    electric? ? "W" : "#{amount_label}/h"
  end

  private
    def currency_owner
      gear&.user
    end

    def store_time_used
      return unless defined?(@used_hours) || defined?(@used_minutes)

      typed = [ @used_hours, @used_minutes ]
      hours, mins = numbers = typed.map { BigDecimal(it.to_s, exception: false) if it.present? }

      self.minutes =
        if typed.all?(&:blank?)
          nil
        elsif typed.zip(numbers).any? { |text, number| text.present? && (number.nil? || number.negative?) }
          typed.join(" ") # not a valid number, so validation reports it
        else
          ((hours || 0) * 60 + (mins || 0)).round
        end
    end

    def stored_unit_for(field)
      if field == :amount
        electric? ? "kWh" : "l"
      else
        "km"
      end
    end

    def preferred_unit_for(field)
      if field == :amount
        electric? ? "kWh" : volume_unit
      else
        distance_unit
      end
    end

    def gear_uses_unit
      if gear.nil? || gear.fuel_units.empty?
        errors.add(:gear, "must run on fuel or electricity")
      elsif gear.fuel_units.exclude?(unit)
        errors.add(:unit, "isn't used by this gear")
      end
    end
end
