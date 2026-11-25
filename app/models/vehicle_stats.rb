# What a vehicle has cost to run and how far it went, from its logs and those of
# its components. Running costs are fuel, expenses and parts, without the
# vehicle's own purchase price. Distances are shown in the units asked for, so
# vehicles of owners with different units can be compared.
class VehicleStats
  Cost = Data.define(:date, :amount, :currency, :slice)
  Slice = Data.define(:name, :amount, :percent)

  # A yearly bill in a short log would look like a much bigger one.
  MIN_DAYS = 180
  # With fewer full tanks, best and worst say little.
  MIN_TANKS = 5
  DAYS_PER_YEAR = 365.25

  RECORDS = %i[ expenses fuel_entries readings ].freeze

  attr_reader :gear, :distance_unit, :volume_unit

  def initialize(gear, distance_unit: gear.distance_unit, volume_unit: gear.volume_unit)
    @gear = gear
    @distance_unit = distance_unit
    @volume_unit = volume_unit
    @today = Date.current
    # All components' records at once, not a few queries for each component.
    ActiveRecord::Associations::Preloader.new(records: [ gear ], associations: [ *RECORDS, { components: RECORDS } ]).call
  end

  def any?
    fuel_entries.any? || expenses.any? || readings.any?
  end

  def running_costs
    Costs.of(costs, :amount)
  end

  # Days from the first dated record to the latest.
  def days_tracked
    dates = [ costs.filter_map(&:date), readings.map(&:read_on), fuel_entries.map(&:filled_on) ].flatten.reject { it > @today }
    dates.any? ? (dates.max - dates.min).to_i : 0
  end

  def running_cost_per_year
    return if days_tracked < MIN_DAYS

    Costs.of(costs.select { it.date && it.date <= @today }, :amount) / (days_tracked / DAYS_PER_YEAR)
  end

  # Currency => slices, largest first. Percentages are within one currency.
  def breakdown
    costs.group_by(&:currency).transform_values do |in_currency|
      total = in_currency.sum(&:amount)
      in_currency.group_by(&:slice).map do |name, slice|
        amount = slice.sum(&:amount)
        Slice.new(name, amount, amount * 100 / total)
      end.sort_by { [ -it.amount, it.name ] }
    end
  end

  # From the first odometer to the latest. nil if there's only one.
  def distance
    Units.convert(km_tracked, "km", distance_unit)
  end

  # Only costs between the first and latest odometers, so older ones aren't
  # spread over a distance that doesn't include them.
  def cost_per_distance
    return unless distance && days_between_odometers >= MIN_DAYS

    first, last = odometers.first.first, odometers.last.first
    Costs.of(costs.select { it.date&.then { |date| date > first && date <= last } }, :amount) / distance
  end

  # All the distance over all the fuel, so small fill-ups don't count too much.
  def average_efficiency
    efficiency(tanks.sum(&:distance) / tanks.sum(&:amount)) if tanks.any?
  end

  def best_efficiency
    efficiency(tanks.map(&:per_unit).max) if enough_tanks?
  end

  def worst_efficiency
    efficiency(tanks.map(&:per_unit).min) if enough_tanks?
  end

  def latest_efficiency
    efficiency(tanks.last.per_unit) if tanks.any?
  end

  # False for plug-in hybrids: there's no telling which miles used fuel.
  def efficiency?
    gear.fuel_economy.one_source?
  end

  def distance_label
    Units::LABELS.fetch(distance_unit)
  end

  # Like "mi/gal" or "km/kWh"
  def efficiency_label
    "#{distance_label}/#{Units::LABELS.fetch(amount_unit)}"
  end

  def fuel_count = fuel_entries.size
  def expense_count = expenses.size
  def missed_count = gear.fuel_economy.missed_total
  def flagged_count = gear.fuel_economy.flagged_count

  private
    def gears
      @gears ||= [ gear, *gear.components ]
    end

    def expenses = @expenses ||= gears.flat_map { it.expenses.to_a }
    def readings = @readings ||= gears.flat_map { it.readings.to_a }
    def fuel_entries = @fuel_entries ||= gears.flat_map { it.fuel_entries.to_a }

    def costs
      @costs ||= [
        *expenses.map { Cost.new(it.spent_on, it.amount, it.currency, it.category_name || "No category") },
        *fuel_entries.map { Cost.new(it.filled_on, it.total_price, it.currency, "Fuel") },
        *gear.components.map { Cost.new(it.purchased_on, it.price, it.currency, Expense::CATEGORIES.fetch("parts")) }
      ].select { it.amount&.positive? }
    end

    # [ date, km ] in date order. Flagged fill-ups wait until they're checked.
    def odometers
      @odometers ||= [
        *gear.fuel_entries.reject { gear.fuel_economy.flag(it) }.map { [ it.filled_on, it.odometer ] },
        *readings.map { [ it.read_on, it.odometer ] }
      ].select { |date, km| km && date <= @today }.sort
    end

    def km_tracked
      return if odometers.size < 2

      (odometers.last.last - odometers.first.last).then { it if it.positive? }
    end

    def days_between_odometers
      (odometers.last.first - odometers.first.first).to_i
    end

    def tanks
      efficiency? ? gear.fuel_economy.tanks : []
    end

    def enough_tanks?
      tanks.size >= MIN_TANKS
    end

    # "kWh", or the volume unit
    def amount_unit
      gear.fuel_economy.unit == "kWh" ? "kWh" : volume_unit
    end

    def efficiency(km_per_unit)
      Units.efficiency(km_per_unit, gear.fuel_economy.unit, distance_unit, amount_unit)
    end
end
