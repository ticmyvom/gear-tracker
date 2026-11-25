# How far gear went on the fuel or electricity in its log, in kilometers and
# liters (or kWh).
#
# Filling up replaces what was used since the last time it was full, so
# efficiency is worked out from one full tank to the next: all the distance
# since then, over all the fuel added since then. A partial fill-up has none of
# its own; it counts toward the next full one.
#
# After a missed (unlogged) fill-up the fuel isn't all known, so there's no
# efficiency until the next full tank, unless the distance since the missed one
# was typed.
#
# An efficiency far from the usual one is flagged for the owner to check, since
# it's often a missed or partial fill-up, or a typo.
class FuelEconomy
  # Below or above this many times the median is unusual. A missed fill-up about
  # doubles it, while weather and hills change it less.
  USUAL = 0.6..1.5
  # With fewer tanks, there's no telling which one is off.
  FLAG_AFTER = 4

  # From one full tank to the next.
  Tank = Data.define(:entry, :distance, :amount) do
    def per_unit = distance / amount
  end

  # Full tanks in date order, without any flagged ones.
  attr_reader :tanks

  def initialize(gear)
    entries = gear.fuel_entries.select(&:persisted?).sort_by { [ it.filled_on, it.id ] }
    # With both fuel and electricity, the odometer can't tell which one moved it.
    @units = gear.fuel_units | entries.map(&:unit)
    @entries = entries
    @tanks = []
    @legs = {}
    @per_unit = {}
    @missed = {}
    @flags = {}
    @usual = {}
    entries.group_by(&:unit).each_value { measure(it) }
  end

  # False when both fuel and electricity were used.
  def one_source?
    @units.one?
  end

  # "l" or "kWh", when there's only one.
  def unit
    @units.first if one_source?
  end

  def missed_total
    @missed.values.sum
  end

  def flagged_count
    @entries.count { flag(it) }
  end

  # Distance since the entry before: as typed, or else from the odometers.
  def distance(entry)
    @legs[entry.id]
  end

  # Distance per liter or kWh since the last full tank.
  def per_unit(entry)
    @per_unit[entry.id]
  end

  # About how many fill-ups went unlogged just before this one; 0 if none did.
  def missed_before(entry)
    @missed.fetch(entry.id, 0)
  end

  # :high or :low if the efficiency is unusual and the owner hasn't checked it.
  def flag(entry)
    @flags[entry.id] unless entry.efficiency_checked?
  end

  # The median distance per liter or kWh.
  def usual_per_unit(unit)
    @usual[unit]
  end

  private
    def measure(entries)
      previous = last_full = nil
      fuel_known = true
      tank = []
      measured = []
      gaps = {} # entries after a missed fill-up => distance since the entry before

      entries.each do |entry|
        if entry.missed_previous?
          gaps[entry] = between(previous, entry)
          last_full = nil
          fuel_known = entry.trip.present?
          tank = []
        end
        tank << entry
        @legs[entry.id] = entry.trip || between(previous, entry)

        if entry.filled_up?
          distance = tank_distance(tank, last_full) if fuel_known
          if distance&.positive?
            amount = tank.sum(&:amount)
            @per_unit[entry.id] = distance / amount
            measured << Tank.new(entry, distance, amount)
          end
          last_full = entry
          fuel_known = true
          tank = []
        end
        previous = entry
      end

      flag_unusual(measured.map(&:entry))
      measured = measured.reject { flag(it.entry) }
      @tanks += measured
      gaps.each { |entry, distance| @missed[entry.id] = estimate_missed(entry, distance, measured, entries) }
    end

    def flag_unusual(entries)
      return if entries.empty?

      values = entries.map { per_unit(it) }.sort
      median = @usual[entries.first.unit] = (values[(values.size - 1) / 2] + values[values.size / 2]) / 2
      return if entries.size < FLAG_AFTER

      entries.each do |entry|
        ratio = per_unit(entry) / median
        @flags[entry.id] = ratio > USUAL.end ? :high : :low unless USUAL.cover?(ratio)
      end
    end

    def tank_distance(tank, last_full)
      legs = tank.map { @legs[it.id] }
      legs.all? ? legs.sum : between(last_full, tank.last)
    end

    # nil unless both odometers are known and it went up, so a typo isn't counted.
    def between(earlier, later)
      return unless one_source? && earlier&.odometer && later.odometer

      (later.odometer - earlier.odometer).then { it if it.positive? }
    end

    # The fuel that distance usually takes, less what was logged, in usual fill-ups.
    # At least the one the owner said was missed.
    def estimate_missed(entry, distance, measured, entries)
      full = entries.select(&:filled_up?)
      return 1 if distance.nil? || measured.empty? || full.empty?

      usual_per_unit = measured.sum(&:distance) / measured.sum(&:amount)
      usual_amount = full.sum(&:amount) / full.size
      [ ((distance / usual_per_unit - entry.amount) / usual_amount).round, 1 ].max
    end
end
