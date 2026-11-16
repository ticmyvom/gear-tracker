require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  # --- Deleting an account ---

  test "deleting the account removes the user and everything they own" do
    user = users(:one)
    owned = -> { [ user.gears.count, Expense.joins(:gear).where(gears: { user_id: user.id }).count, user.api_tokens.count, user.sessions.count ] }
    assert owned.call.all?(&:positive?)

    delete account_path, params: { password: "password" }

    assert_redirected_to new_session_path
    assert_not User.exists?(user.id)
    assert_equal [ 0, 0, 0, 0 ], owned.call
    assert_empty cookies[:session_id]
  end

  test "deleting needs the current password" do
    assert_no_difference -> { User.count } do
      delete account_path, params: { password: "wrong" }
    end

    assert_redirected_to edit_settings_path
    assert_equal "That password isn't right. Your account wasn't deleted.", flash[:alert]
  end

  test "deleting one account leaves other users alone" do
    other = [ users(:two).gears.count, users(:two).api_tokens.count ]

    delete account_path, params: { password: "password" }

    assert_equal other, [ users(:two).gears.count, users(:two).api_tokens.count ]
  end

  test "deleting needs a browser session, not an API token" do
    sign_out
    delete account_path, params: { password: "password" }, headers: { "Authorization" => "Bearer gt_one_write" }

    assert_redirected_to new_session_path
    assert User.exists?(users(:one).id)
  end

  # --- Downloading your data ---

  test "export downloads all of the user's data as a JSON file" do
    get export_account_path

    assert_response :success
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_match "gear-tracker-#{Date.current.iso8601}.json", response.headers["Content-Disposition"]

    data = response.parsed_body
    assert_equal GearTracker::VERSION, data["app_version"]
    assert_equal "one@example.com", data["account"]["email_address"]
    prius = data["gears"].find { it["name"] == "2010 Toyota Prius" }
    assert_equal [ "Oil change" ], prius["expenses"].pluck("description")
    assert_equal 10.5, prius["fuel_entries"].first["amount"]
    assert_equal "Tire pressure FL", prius["readings"].first["name"]
    assert_includes data["gears"].pluck("name"), "Michelin tires"
  end

  test "export has nothing from other users and no secrets" do
    get export_account_path

    body = response.body
    [ "Old truck", "Cordless drill", "two@example.com" ].each { assert_no_match it, body }
    [ "password_digest", "token_digest", users(:one).password_digest, api_tokens(:one_write).token_digest ].each { assert_no_match it, body }
    assert_match "no-store", response.headers["Cache-Control"]
  end

  test "export needs to be signed in" do
    sign_out
    get export_account_path

    assert_redirected_to new_session_path
  end

  # --- Privacy ---

  test "the privacy page is public and linked from every page" do
    sign_out
    get privacy_path
    assert_response :success
    assert_select "h1", text: "Privacy"

    get new_session_path
    assert_select "footer a[href=?]", privacy_path
  end
end
