require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "rejects a duplicate email address regardless of case" do
    user = User.new(email_address: users(:one).email_address.upcase, password: "long enough")

    assert_not user.valid?
  end

  test "new users default to dollars, miles and US gallons" do
    user = User.new

    assert_equal "USD", user.currency
    assert_equal "mi", user.distance_unit
    assert_equal "us_gal", user.volume_unit
  end

  test "rejects unknown currency and units" do
    user = users(:one)

    assert_not user.update(currency: "XYZ")
    assert_not user.update(currency: "USD", distance_unit: "furlong")
    assert_not user.update(distance_unit: "mi", volume_unit: "barrel")
  end

  test "rejects a short password" do
    assert_not User.new(email_address: "new@example.com", password: "short").valid?
  end

  # --- Public profile ---

  test "tidies username and display name" do
    user = User.new(username: "  Trail-Runner ", display_name: "  Trail   Runner ")

    assert_equal [ "trail-runner", "Trail Runner" ], [ user.username, user.display_name ]
    assert_nil User.new(username: "  ", display_name: " ").then { [ it.username, it.display_name ].compact.presence }
  end

  test "usernames are 3 to 30 letters, numbers or inner dashes, and not reserved" do
    user = users(:one)
    %w[ abc trail-runner x1y ].push("a" * 30).each do |name|
      user.username = name
      assert user.valid?, "#{name} should be allowed"
    end
    %w[ ab -abc abc- a_b a.b admin settings ].push("a" * 31, "héllo").each do |name|
      user.username = name
      assert_not user.valid?, "#{name} should be refused"
    end
  end

  test "usernames are unique regardless of case" do
    users(:one).update!(username: "trail-runner")

    assert_not users(:two).update(username: "Trail-Runner")
    assert_includes users(:two).errors[:username], "has already been taken"
  end

  test "a public profile needs a username and display name" do
    user = users(:one)
    user.profile_public = true

    assert_not user.valid?
    assert_equal [ "is needed for a public profile" ], user.errors[:username]
    assert_equal [ "is needed for a public profile" ], user.errors[:display_name]
  end

  test "public gear is the top-level gear marked public, and none while the profile is private" do
    user = users(:one)
    gears(:prius).update!(public: true)
    gears(:tires).update_columns(public: true) # components never count, even if marked

    assert_empty user.public_gears
    user.update!(username: "one", display_name: "One", profile_public: true)
    assert_equal [ gears(:prius) ], user.public_gears.to_a
  end

  test "time zones are stored by IANA name, and unknown ones as none" do
    assert_equal "America/Los_Angeles", User.new(time_zone: "Pacific Time (US & Canada)").time_zone
    assert_equal "America/Boise", User.new(time_zone: "America/Boise").time_zone
    assert_nil User.new(time_zone: "Mars/Olympus_Mons").time_zone
  end

  test "time zone choices share one option per zone and keep a saved zone Rails doesn't name" do
    assert_includes User.time_zone_options, [ "(GMT+07:00) Bangkok, Hanoi", "Asia/Bangkok" ]
    assert_equal [ "America/Boise", "America/Boise" ], User.time_zone_options("America/Boise").first
    assert_equal User.time_zone_options, User.time_zone_options("Asia/Bangkok")
  end

  test "today is in the user's time zone, or UTC without one" do
    travel_to Time.utc(2026, 11, 27, 4, 47) do
      assert_equal Date.new(2026, 11, 26), User.new(time_zone: "America/Los_Angeles").in_time_zone { Date.current }
      assert_equal Date.new(2026, 11, 27), User.new.in_time_zone { Date.current }
    end
  end
end
