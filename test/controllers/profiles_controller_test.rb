require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(username: "trail-runner", display_name: "Trail Runner", profile_public: true)
    gears(:prius).update!(public: true, notes: "VIN 1234 secret")
  end

  test "anyone can see a public profile and its public gear, signed in or not" do
    get profile_path(username: "trail-runner")

    assert_response :success
    assert_select "h1", "Trail Runner"
    assert_select "h3", "2010 Toyota Prius"
    assert_select "li", text: /Michelin tires/ # components come with their parent
    assert_select "h3", text: "Plug-in hybrid", count: 0 # not marked public
  end

  test "shows nothing private: no email, notes, prices or records" do
    get profile_path(username: "trail-runner")

    [ "one@example.com", "VIN 1234", "Private seller", "Oil change", "Tire pressure", "$8,000" ].each { assert_no_match it, response.body }
    assert_select "dt", text: "Total cost", count: 0
  end

  test "shows costs only for gear whose owner chose to" do
    gears(:prius).update!(public_costs: true)

    get profile_path(username: "trail-runner")

    assert_select "dt", text: "Total cost"
    assert_select "dt", text: "Cost per year"
  end

  test "asks search engines not to list it" do
    get profile_path(username: "trail-runner")

    assert_equal "noindex", response.headers["X-Robots-Tag"]
    assert_select "meta[name=robots][content=noindex]"
  end

  test "the address ignores case" do
    get profile_path(username: "Trail-Runner")

    assert_response :success
  end

  test "a private profile looks exactly like one that doesn't exist" do
    @user.update!(profile_public: false)

    # Both are a plain 404; in production that's always the static public/404.html.
    [ "trail-runner", "nobody-here" ].each do |username|
      get profile_path(username: username)

      assert_response :not_found
    end
  end

  test "a public profile without public gear shows just the name" do
    gears(:prius).update!(public: false)

    get profile_path(username: "trail-runner")

    assert_select "h1", "Trail Runner"
    assert_select "p", "No public gear yet."
  end
end
