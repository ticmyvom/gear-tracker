require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "demo mode shows and fills in the demo sign-in" do
    ENV["GEAR_TRACKER_DEMO"] = "1"
    get new_session_path

    assert_select ".demo", text: /changes are thrown away/
    assert_select "input[name=email_address][value=?]", Demo::EMAIL
    assert_select "input[name=password][value=?]", Demo::PASSWORD
  ensure
    ENV.delete("GEAR_TRACKER_DEMO")
  end

  test "outside demo mode the sign-in page doesn't mention the demo" do
    get new_session_path

    assert_select ".demo", count: 0
    assert_no_match Demo::PASSWORD, response.body
  end

  test "every page shows the app version" do
    get new_session_path

    assert_select "footer", text: /Gear Tracker #{Regexp.escape(GearTracker::VERSION)}/
  end

  test "create fills in a missing time zone from the browser" do
    post session_path, params: { email_address: @user.email_address, password: "password", time_zone: "America/Denver" }

    assert_equal "America/Denver", @user.reload.time_zone
  end

  test "create keeps a saved time zone, like when signing in while traveling" do
    @user.update!(time_zone: "America/New_York")
    post session_path, params: { email_address: @user.email_address, password: "password", time_zone: "Europe/Paris" }

    assert_equal "America/New_York", @user.reload.time_zone
  end
end
