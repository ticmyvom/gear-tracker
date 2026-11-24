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
class FuelEconomy
  def initialize(gear)
    entries = gear.fuel_entries.select(&:persisted?).sort_by { [ it.filled_on, it.id ] }
    # With both fuel and electricity, the odometer can't tell which one moved it.
    @use_odometer = (gear.fuel_units | entries.map(&:unit)).one?
    @legs = {}
    @per_unit = {}
    @missed = {}
    entries.group_by(&:unit).each_value { measure(it) }
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

  private
    def measure(entries)
      previous = last_full = nil
      fuel_known = true
      tank = []
      measured = [] # [ distance, amount ] of each full tank
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
            measured << [ distance, amount ]
          end
          last_full = entry
          fuel_known = true
          tank = []
        end
        previous = entry
      end

      gaps.each { |entry, distance| @missed[entry.id] = estimate_missed(entry, distance, measured, entries) }
    end

    def tank_distance(tank, last_full)
      legs = tank.map { @legs[it.id] }
      legs.all? ? legs.sum : between(last_full, tank.last)
    end

    # nil unless both odometers are known and it went up, so a typo isn't counted.
    def between(earlier, later)
      return unless @use_odometer && earlier&.odometer && later.odometer

      (later.odometer - earlier.odometer).then { it if it.positive? }
    end

    # The fuel that distance usually takes, less what was logged, in usual fill-ups.
    # At least the one the owner said was missed.
    def estimate_missed(entry, distance, measured, entries)
      full = entries.select(&:filled_up?)
      return 1 if distance.nil? || measured.empty? || full.empty?

      usual_per_unit = measured.sum(&:first) / measured.sum(&:last)
      usual_amount = full.sum(&:amount) / full.size
      [ ((distance / usual_per_unit - entry.amount) / usual_amount).round, 1 ].max
    end
end
