require "test_helper"

class VehicleStatsTest < ActiveSupport::TestCase
  # The truck's owner uses EUR, km and liters. Nothing is logged to start with.
  setup do
    @truck = gears(:truck)
    @truck.fuel_entries.destroy_all
    @truck.update!(price: 10_000)
    @start = 2.years.ago.to_date
  end

  def stats(**units) = VehicleStats.new(Gear.find(@truck.id), **units)

  def fuel(days, amount: 40, price: nil, odometer: nil, gear: @truck, **more)
    gear.fuel_entries.create!(filled_on: @start + days, amount: amount, total_price: price, odometer: odometer, **more)
  end

  def spend(days, amount, category: nil, gear: @truck, **more)
    gear.expenses.create!(spent_on: @start + days, description: "Cost", amount: amount, category: category, **more)
  end

  def part(**more) = users(:two).gears.create!(name: "Tires", category: "parts", parent: @truck, **more)

  # Full 40 L tanks, a month apart, that went these distances after a first one.
  def tanks(*distances)
    odometer = 1000
    fuel(0, odometer: odometer)
    distances.each.with_index(1) { |distance, index| fuel(index * 30, odometer: odometer += distance) }
  end

  test "nothing logged yet" do
    assert_not stats.any?
    assert_equal 0, stats.days_tracked
    assert_empty stats.running_costs
    assert_empty stats.breakdown
    assert_nil stats.running_cost_per_year
    assert_nil stats.distance
    assert_nil stats.cost_per_distance
    assert_nil stats.average_efficiency
    assert_nil stats.latest_efficiency
  end

  test "running costs are fuel, expenses and parts, without the purchase price" do
    fuel(0, price: 60)
    spend(1, 100)
    spend(2, 25, gear: part(price: 400))

    assert_equal Costs.new("EUR" => 585), stats.running_costs
    assert stats.any?
  end

  test "running cost per year is over the time tracked" do
    spend(0, 300)
    spend(365, 700)

    assert_equal 365, stats.days_tracked
    assert_in_delta 1000, stats.running_cost_per_year["EUR"], 1
  end

  test "running cost per year waits for enough logs" do
    spend(0, 300)
    spend(179, 300)
    assert_nil stats.running_cost_per_year

    spend(180, 10)
    assert_in_delta 610 * 365.25 / 180, stats.running_cost_per_year["EUR"], 0.01
  end

  test "undated parts and future dates count in total but not per year" do
    spend(0, 300)
    spend(365, 700)
    part(price: 400)
    @truck.expenses.create!(spent_on: 1.year.from_now, description: "Typo", amount: 50)

    assert_equal Costs.new("EUR" => 1450), stats.running_costs
    assert_equal 365, stats.days_tracked
    assert_in_delta 1000, stats.running_cost_per_year["EUR"], 1
  end

  test "breakdown has shares by category, largest first" do
    fuel(0, price: 50)
    spend(1, 25, category: "insurance")
    spend(2, 15)
    part(price: 10)

    slices = stats.breakdown.fetch("EUR")
    assert_equal [ [ "Fuel", 50 ], [ "Insurance", 25 ], [ "No category", 15 ], [ "Parts & accessories", 10 ] ], slices.map { [ it.name, it.amount ] }
    assert_equal [ 50, 25, 15, 10 ], slices.map(&:percent)
  end

  test "breakdown adds part purchases to parts expenses, and keeps currencies apart" do
    spend(1, 30, category: "parts")
    part(price: 70)
    spend(2, 5, currency: "USD")

    assert_equal [ [ "Parts & accessories", 100, 100 ] ], stats.breakdown.fetch("EUR").map(&:to_h).map(&:values)
    assert_equal [ [ "No category", 5, 100 ] ], stats.breakdown.fetch("USD").map(&:to_h).map(&:values)
  end

  test "distance is from the first odometer to the latest, whichever log it's in" do
    fuel(0, odometer: 1000)
    part.readings.create!(read_on: @start + 10, name: "Tread depth", value: 6, odometer: 1800)
    fuel(5, odometer: 9_999) # a typo in between doesn't matter
    assert_equal 800, stats.distance

    spend(20, 50, odometer: 2000)
    assert_equal 1000, stats.distance
    assert_in_delta 621.4, stats(distance_unit: "mi").distance, 0.1
  end

  test "distance needs two odometers, and one that went up" do
    fuel(0, odometer: 1000)
    assert_nil stats.distance

    fuel(5, odometer: 900)
    assert_nil stats.distance
  end

  test "cost per distance counts only costs between the odometers" do
    spend(0, 5000) # long before
    fuel(100, odometer: 1000, price: 60) # for the distance before it
    spend(200, 400)
    fuel(400, odometer: 11_000, price: 100)
    spend(500, 9000) # after

    assert_equal Costs.new("EUR" => 0.05), stats.cost_per_distance
  end

  test "cost per distance waits for enough time between odometers" do
    fuel(0, odometer: 1000)
    fuel(100, odometer: 2000, price: 60)

    assert_nil stats.cost_per_distance
  end

  test "average is all the distance over all the fuel" do
    fuel(0, odometer: 1000)
    fuel(30, odometer: 1400, amount: 40) # 10 km/L
    fuel(60, odometer: 1550, amount: 10) # 15 km/L

    assert_equal 11, stats.average_efficiency
    assert_equal 15, stats.latest_efficiency
  end

  test "best and worst wait for five full tanks" do
    tanks(400, 440, 360, 400)
    assert_nil stats.best_efficiency
    assert_nil stats.worst_efficiency

    fuel(150, odometer: 3020) # 420 km
    assert_equal [ 11, 9 ], [ stats.best_efficiency, stats.worst_efficiency ]
  end

  test "flagged tanks are left out until they're checked" do
    tanks(400, 400, 400, 400, 400, 1200)
    assert_equal [ 1, 10, 10, 2000 ], [ stats.flagged_count, stats.best_efficiency, stats.average_efficiency, stats.distance ]

    @truck.fuel_entries.order(:filled_on).last.update!(efficiency_checked: true)
    assert_equal [ 0, 30, 3200 ], [ stats.flagged_count, stats.best_efficiency, stats.distance ]
  end

  test "efficiency is in the units asked for" do
    tanks(400)

    assert_equal [ 10, "km/L" ], [ stats.average_efficiency, stats.efficiency_label ]
    american = stats(distance_unit: "mi", volume_unit: "us_gal")
    assert_in_delta 23.52, american.average_efficiency, 0.01
    assert_equal "mi/gal", american.efficiency_label
  end

  test "electric vehicles use kWh, whatever the volume unit" do
    @truck.update!(power_source: "electric")
    tanks(200)

    assert_equal [ 5, "km/kWh" ], [ stats.average_efficiency, stats.efficiency_label ]
  end

  test "plug-in hybrids have no efficiency, but do have a distance" do
    @truck.update!(power_source: "plug_in_hybrid")
    fuel(0, odometer: 1000)
    fuel(30, odometer: 1400, trip: 400)

    assert_not stats.efficiency?
    assert_nil stats.average_efficiency
    assert_equal 400, stats.distance
  end

  test "counts logs, with those of components, and missed fill-ups" do
    tanks(400, 400)
    fuel(90, odometer: 2600, missed_previous: true)
    spend(1, 5)
    spend(2, 5, gear: part)

    assert_equal [ 4, 2, 1 ], [ stats.fuel_count, stats.expense_count, stats.missed_count ]
  end

  test "more components don't take more queries" do
    work = -> { stats.then { [ it.running_costs, it.distance, it.days_tracked ] } }
    part(price: 1).readings.create!(read_on: @start, name: "Tread depth", value: 6)
    count = 0
    ActiveSupport::Notifications.subscribed(->(*) { count += 1 }, "sql.active_record", &work)
    3.times { part(price: 1).expenses.create!(spent_on: @start, description: "Cost", amount: 1) }

    assert_queries_count(count, &work)
  end

  test "a vehicle without a power source has no efficiency" do
    @truck.update!(power_source: nil)
    spend(0, 5)

    assert_not stats.efficiency?
    assert_nil stats.average_efficiency
  end
end
