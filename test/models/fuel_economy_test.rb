require "test_helper"

class FuelEconomyTest < ActiveSupport::TestCase
  # The truck's owner uses km and liters, so nothing is converted.
  setup do
    @truck = gears(:truck)
    @truck.fuel_entries.destroy_all
  end

  def log(amount, odometer: nil, trip: nil, full: true, missed: false, gear: @truck, on: "2026-01-01")
    gear.fuel_entries.create!(amount: amount, odometer: odometer, trip: trip, filled_up: full, missed_previous: missed, filled_on: on)
  end

  def efficiency(entry) = FuelEntry.find(entry.id).distance_per_unit
  def distance(entry) = FuelEntry.find(entry.id).distance
  def missed_before(entry) = FuelEntry.find(entry.id).missed_before

  test "works out distance and efficiency from the odometers" do
    first, second = log(40, odometer: 1000), log(50, odometer: 1500)

    assert_nil efficiency(first)
    assert_nil distance(first)
    assert_equal [ 500, 10 ], [ distance(second), efficiency(second) ]
  end

  test "a typed distance wins, for when a fill-up in between wasn't logged" do
    log(40, odometer: 1000)
    second = log(50, odometer: 2000, trip: 400)

    assert_equal [ 400, 8 ], [ distance(second), efficiency(second) ]
  end

  test "a partial fill-up has no efficiency, and counts toward the next full one" do
    log(40, odometer: 1000)
    partial, full = log(10, odometer: 1300, full: false), log(40, odometer: 1500)

    assert_equal 300, distance(partial)
    assert_nil efficiency(partial)
    assert_equal 10, efficiency(full) # 500 km on 50 L, not 200 km on 40 L
  end

  test "several partial fill-ups in a row, with typed distances" do
    log(40)
    log(10, trip: 120, full: false)
    log(10, trip: 80, full: false)
    full = log(30, trip: 300)

    assert_equal 10, efficiency(full)
  end

  test "a partial fill-up without an odometer is bridged by the full ones" do
    log(40, odometer: 1000)
    log(10, full: false)
    full = log(40, odometer: 1500)

    assert_nil distance(full)
    assert_equal 10, efficiency(full)
  end

  test "a full tank without an odometer isn't skipped over" do
    log(40, odometer: 1000)
    unknown, after = log(50), log(40, odometer: 2000)

    assert_nil efficiency(unknown)
    assert_nil efficiency(after) # 1000 km took 90 L, but how far each tank went is unknown
  end

  test "after a partial fill-up and no full one before it, efficiency counts only what's known" do
    log(10, odometer: 1000, full: false)
    full = log(40, odometer: 1400)

    assert_nil efficiency(full)
  end

  test "after a missed fill-up there's no efficiency, and the next tank is right again" do
    log(40, odometer: 1000)
    after_missed, following = log(40, odometer: 1800, missed: true), log(40, odometer: 2200)

    assert_nil efficiency(after_missed)
    assert_equal 800, distance(after_missed) # still really driven
    assert_equal 10, efficiency(following)
  end

  test "a typed distance since the missed fill-up gives an efficiency" do
    log(40, odometer: 1000)

    assert_equal 10, efficiency(log(40, odometer: 1800, trip: 400, missed: true))
  end

  test "a partial fill-up after a missed one keeps efficiency unknown until after the next full one" do
    log(40, odometer: 1000)
    partial, full, following = log(10, odometer: 1800, missed: true, full: false), log(40, odometer: 2000), log(40, odometer: 2400)

    assert_nil efficiency(partial)
    assert_nil efficiency(full)
    assert_equal 10, efficiency(following)
  end

  test "a missed fill-up drops partial ones before it" do
    log(40, odometer: 1000)
    log(10, odometer: 1100, full: false)

    assert_equal 10, efficiency(log(40, odometer: 1900, trip: 400, missed: true))
  end

  test "estimates how many fill-ups were missed from the usual efficiency and fill-up" do
    log(40, odometer: 1000)
    usual = log(40, odometer: 1400) # 10 km/L
    one, three = log(40, odometer: 2200, missed: true), log(40, odometer: 3800, missed: true)

    assert_equal [ 0, 1, 3 ], [ usual, one, three ].map { missed_before(it) }
  end

  test "the estimate allows for a typed distance" do
    log(40, odometer: 1000)
    log(40, odometer: 1400)

    assert_equal 2, missed_before(log(40, odometer: 2600, trip: 400, missed: true))
  end

  test "the estimate is at least one, even without odometers or a usual efficiency" do
    log(40)
    assert_equal 1, missed_before(log(40, missed: true))

    log(40, odometer: 1000)
    log(40, odometer: 1400)
    assert_equal 1, missed_before(log(40, odometer: 1410, missed: true))
  end

  test "an odometer that goes down is ignored" do
    log(40, odometer: 1000)
    typo = log(40, odometer: 900)

    assert_nil distance(typo)
    assert_nil efficiency(typo)
  end

  test "entries are ordered by date, not by when they were logged" do
    later = log(50, odometer: 1500, on: "2026-02-01")
    log(40, odometer: 1000)

    assert_equal 10, efficiency(later)
  end

  test "a plug-in hybrid needs a typed distance, since either source may have moved it" do
    phev = gears(:phev)
    log(8, odometer: 1000, gear: phev)
    worked_out, typed = log(8, odometer: 1800, gear: phev), log(8, odometer: 2600, trip: 400, gear: phev)

    assert_nil efficiency(worked_out)
    assert_in_delta 50, FuelEconomy.new(phev.reload).per_unit(typed), 0.001
  end

  test "unsaved entries are left out" do
    log(40, odometer: 1000)
    @truck.fuel_entries.new(amount: nil)

    assert FuelEconomy.new(@truck)
  end

  test "listing entries works it out once" do
    3.times { log(40, odometer: 1000 + it * 500) }
    gear = Gear.find(@truck.id)

    assert_queries_count(3) { gear.fuel_entries.order(:id).each(&:distance_per_unit) } # the list, the log, and the owner's units
  end
end
