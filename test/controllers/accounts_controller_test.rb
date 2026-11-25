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
    assert_equal [ nil, nil, false ], data["account"].values_at("username", "display_name", "profile_public")
    assert_equal [ false ] * 6, prius.values_at("public", "public_costs", *Gear::LISTING_FIELDS.map(&:to_s))
  end

  test "export keeps the order of fuel entries from the same day" do
    20.times { gears(:prius).fuel_entries.create!(amount: it + 1, filled_on: "2025-01-01") }
    get export_account_path

    ids = response.parsed_body["gears"].find { it["name"] == "2010 Toyota Prius" }["fuel_entries"].pluck("id")
    assert_equal gears(:prius).fuel_entries.order(:filled_on, :id).ids, ids
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

  # --- Importing your data ---

  def upload(json) = Rack::Test::UploadedFile.new(StringIO.new(json), "application/json", original_filename: "data.json")

  test "a downloaded file imports into another account, converted to its units" do
    get export_account_path
    exported = response.body
    new_user = User.create!(email_address: "new@example.com", password: "password", distance_unit: "km", volume_unit: "l")
    sign_in_as new_user

    post import_account_path, params: { file: upload(exported) }

    assert_redirected_to root_path
    assert_equal "Imported 3 gears, 2 expenses, 1 fuel entry, and 1 reading.", flash[:notice]
    copy = new_user.gears.find_by!(name: "2010 Toyota Prius")
    original = fuel_entries(:fill_up)
    assert_in_delta original.amount, copy.fuel_entries.sole.amount, 0.01
    assert_in_delta original.odometer, copy.fuel_entries.sole.odometer, 0.1
    assert_equal copy, new_user.gears.find_by!(name: "Michelin tires").parent
    assert_equal [ "Oil change" ], copy.expenses.pluck(:description)
    assert_equal [ 2010, "Toyota", "Prius", "Two" ], copy.values_at(*Gear::VEHICLE_FIELDS)
  end

  test "settings offers the import form only while the account has no gear" do
    get edit_settings_path
    assert_select "form[action=?]", import_account_path, count: 0
    assert_select "p", text: /only works into an account with no gear/

    sign_in_as User.create!(email_address: "new@example.com", password: "password")
    get edit_settings_path
    assert_select "form[action=?][enctype='multipart/form-data'] input[type=file][name=file]", import_account_path
  end

  test "a bad file imports nothing and says why" do
    assert_no_difference -> { Gear.count } do
      post import_account_path, params: { file: upload("not json") }
    end

    assert_redirected_to edit_settings_path
    assert_equal "That isn't a Gear Tracker data file. Use one from “Download all your data”. Nothing was imported.", flash[:alert]
  end

  test "importing needs a file, no bigger than the limit" do
    post import_account_path
    assert_match "Choose a file", flash[:alert]

    post import_account_path, params: { file: upload(" " * (AccountImport::MAX_SIZE + 1)) }
    assert_match "too big", flash[:alert]
  end

  test "importing needs to be signed in" do
    sign_out
    assert_no_difference -> { Gear.count } do
      post import_account_path, params: { file: upload("{}") }
    end

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
