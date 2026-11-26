require "test_helper"

class VehiclesControllerTest < ActionDispatch::IntegrationTest
  ALL = { listed: true, listed_price: true, listed_costs: true, listed_economy: true }.freeze

  setup do
    @prius = gears(:prius)
    @prius.update!(name: "Anh's baby", notes: "VIN 1234", listed: true)
  end

  def list(gear, **changes) = gear.update!(listed: true, **changes)
  def shown = css_select("tbody td:first-child a").map(&:text)

  # A year of logs, so every stat has something to show.
  def log_a_year
    @prius.fuel_entries.destroy_all
    7.times { @prius.fuel_entries.create!(filled_on: 400.days.ago.to_date + it * 60, entered_amount: 10, entered_odometer: 1000 + it * 400, total_price: 30) }
  end

  test "lists only listed vehicles, by their details" do
    list gears(:truck), make: "Ford", model: "F-150", year: 2001

    get vehicles_path

    assert_response :success
    assert_equal [ "2001 Ford F-150", "2010 Toyota Prius Two" ], shown
    assert_select "th", text: "Purchaseprice" # "Purchase<br>price"
    assert_select "header nav a[href=?]", vehicles_path
  end

  test "says so when there are none" do
    @prius.update!(listed: false)
    get vehicles_path
    assert_select "p", text: "No vehicles yet."
  end

  test "filters by make and model, in any case" do
    list gears(:truck), make: "Ford", model: "F-150"
    list gears(:phev), make: "Toyota", model: "RAV4"

    get vehicles_path(make: "toyota")
    assert_equal [ "Toyota RAV4", "2010 Toyota Prius Two" ].sort, shown.sort
    assert_select "select[name=model] option", text: "F-150", count: 0

    get vehicles_path(make: "Toyota", model: "prius")
    assert_equal [ "2010 Toyota Prius Two" ], shown

    get vehicles_path(make: "Toyota", model: "F-150")
    assert_select "p", text: "No vehicles match."
  end

  test "odd filters and pages don't break it" do
    [ { make: { a: 1 }, model: [ "x" ] }, { page: "abc" }, { page: -1 }, { page: { a: 1 } }, { page: 10**30 }, { make: "'; DROP TABLE gears" } ].each do |params|
      get vehicles_path(params)
      assert_response :success, params.inspect
    end
  end

  test "pages through many vehicles" do
    30.times { users(:one).gears.create!(category: "vehicle", make: "Honda", model: "Fit", year: 1990 + it, listed: true) }

    get vehicles_path(make: "Honda")
    assert_equal 25, shown.size
    assert_select "a", text: "< Previous", count: 0
    assert_select "a[href=?]", vehicles_path(make: "Honda", page: 2), text: "Next >"

    get vehicles_path(make: "Honda", page: 2)
    assert_equal 5, shown.size
    assert_select "a", text: "Next >", count: 0
  end

  test "more vehicles don't take more queries" do
    count = -> { n = 0; ActiveSupport::Notifications.subscribed(->(*) { n += 1 }, "sql.active_record") { get vehicles_path }; n }
    add = ->(i) do
      car = users(:two).gears.create!(category: "vehicle", make: "Honda", model: "Fit", power_source: "gasoline", year: 2000 + i, **ALL)
      users(:two).gears.create!(name: "Tires", parent: car, price: 5)
      car.fuel_entries.create!(amount: 10)
    end
    add.(0)
    count.call
    before = count.call
    5.times { add.(it + 1) }

    assert_equal before, count.call
  end

  test "a listed vehicle shows only its details unless the owner chose more" do
    get vehicle_path(@prius)

    assert_response :success
    assert_select "h1", "2010 Toyota Prius Two"
    assert_select "dd", text: "Gasoline"
    assert_select "h2", text: "Stats", count: 0
    assert_no_match "$", css_select("main").text

    get vehicles_path
    assert_no_match "$", css_select("main").text
  end

  test "never shows the nickname, owner, notes, vendors, dates, descriptions or parts' names" do
    @prius.update!(**ALL)
    log_a_year
    secrets = [ "Anh", "one@example.com", "VIN 1234", "Private seller", "Oil change", "Michelin", "Discount Tire", "Tire pressure",
      @prius.purchased_on.to_s, *@prius.fuel_entries.pluck(:filled_on).map(&:to_s) ]

    [ vehicle_path(@prius), vehicles_path ].each do |path|
      get path
      secrets.each { assert_no_match it, response.body }
    end
  end

  test "each choice shows its own part" do
    log_a_year
    parts = { "Purchase price" => :listed_price, "Running costs" => :listed_costs, "Running cost per year" => :listed_costs,
      "Distance tracked" => :listed_economy, "Average efficiency" => :listed_economy, "Expenses" => :listed_economy }

    %i[ listed_price listed_costs listed_economy ].each do |choice|
      @prius.update!(**ALL, listed_price: false, listed_costs: false, listed_economy: false, choice => true)
      get vehicle_path(@prius)

      parts.each { |label, part| assert_select "dt", { text: label, count: part == choice ? 1 : 0 }, "#{label} with only #{choice}" }
      assert_select "dt", text: "Total cost so far", count: 0
      assert_select "dt", text: /Running cost per mi/, count: 0
      assert_select "table", count: choice == :listed_costs ? 1 : 0
    end
  end

  test "total cost and cost per mile show once the parts they're made of do" do
    log_a_year
    @prius.update!(**ALL)
    get vehicle_path(@prius)

    assert_select "dt", text: "Total cost so far"
    assert_select "dt", text: "Running cost per mi"
    assert_select "dd", text: "40.0 mi/gal"
  end

  test "each choice shows its own part of the list too" do
    log_a_year
    columns = { listed_price: [ 2 ], listed_costs: [ 3 ], listed_economy: [ 5, 6 ] }

    columns.each do |choice, filled|
      @prius.update!(**ALL, listed_price: false, listed_costs: false, listed_economy: false, choice => true)
      get vehicles_path

      cells = css_select("tbody tr:first-child td").map { it.text.strip }
      assert_equal filled, (2..6).reject { cells[it] == "-" }, choice.to_s
    end
  end

  test "the owner's name shows only while their profile is public" do
    get vehicle_path(@prius)
    assert_select "dt", text: "Owner", count: 0

    users(:one).update!(username: "trail-runner", display_name: "Trail Runner", profile_public: true)
    get vehicle_path(@prius)
    assert_select "dd a[href=?]", profile_path(username: "trail-runner"), text: "Trail Runner"

    users(:one).update!(profile_public: false)
    get vehicle_path(@prius)
    assert_no_match "Trail Runner", response.body
  end

  test "an unlisted vehicle looks like one that doesn't exist, even to its owner" do
    @prius.update!(listed: false)
    sign_in_as users(:one)

    [ vehicle_path(@prius), vehicle_path(gears(:drill)), vehicle_path(id: 999_999_999) ].each do |path|
      get path
      assert_response :not_found
    end
  end

  test "a signed-in visitor sees their own units, and amounts in the owner's currency" do
    log_a_year
    @prius.update!(**ALL)
    sign_in_as users(:two)
    get vehicle_path(@prius)

    assert_select "dd", text: "17.0 km/L"
    assert_select "dt", text: "Running cost per km"
    assert_select "dd", text: "$8,000.00"
  end

  test "unusual fuel entries aren't pointed out to visitors" do
    log_a_year
    @prius.fuel_entries.create!(entered_amount: 10, entered_odometer: 99_000)
    @prius.update!(**ALL)
    get vehicle_path(@prius)

    assert_no_match "unusual", response.body
  end

  test "asks search engines not to list it" do
    [ vehicles_path, vehicle_path(@prius) ].each do |path|
      get path

      assert_equal "noindex", response.headers["X-Robots-Tag"]
      assert_select "meta[name=robots][content=noindex]"
    end
  end
end
