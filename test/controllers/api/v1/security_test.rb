require "test_helper"

# Every way into the API without the right token must fail, and a token must
# only ever reach its own user's data.
class Api::V1::SecurityTest < ActionDispatch::IntegrationTest
  # --- Signing in ---

  test "no token is rejected" do
    get api_v1_gears_path

    assert_response :unauthorized
    assert_equal "Missing or invalid API token", json["error"]
    assert_match "Bearer", response.headers["WWW-Authenticate"]
  end

  test "a wrong token is rejected" do
    get api_v1_gears_path, headers: api_headers("gt_wrong")
    assert_response :unauthorized
  end

  test "a token's digest is not accepted as the token" do
    get api_v1_gears_path, headers: api_headers(api_tokens(:one_write).token_digest)
    assert_response :unauthorized
  end

  test "a revoked token is rejected" do
    api_tokens(:one_write).destroy!

    get api_v1_gears_path, headers: api_headers("gt_one_write")
    assert_response :unauthorized
  end

  test "a token in the URL is rejected, since URLs end up in logs and history" do
    get api_v1_gears_path(token: "gt_one_write")
    assert_response :unauthorized

    get api_v1_gears_path(access_token: "gt_one_write")
    assert_response :unauthorized
  end

  test "a token sent as a basic auth password is rejected" do
    get api_v1_gears_path, headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("one@example.com", "gt_one_write") }
    assert_response :unauthorized
  end

  test "a signed-in browser session is not enough, which also rules out cross-site request forgery" do
    sign_in_as users(:one)

    get api_v1_gears_path
    assert_response :unauthorized

    assert_no_difference -> { Gear.count } do
      post api_v1_gears_path, params: { name: "Forged" }, as: :json
    end
  end

  test "an email and password are not accepted" do
    get api_v1_gears_path, headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("one@example.com", "password") }
    assert_response :unauthorized
  end

  test "using a token records when it was last used" do
    assert_changes -> { api_tokens(:one_write).reload.last_used_at } do
      get api_v1_gears_path, headers: api_headers
    end
  end

  # --- Another user's data ---

  test "lists only the token owner's gear" do
    get api_v1_gears_path, headers: api_headers

    names = json["gears"].pluck("name")
    assert_includes names, gears(:prius).name
    assert_not_includes names, gears(:truck).name
    assert_not_includes names, gears(:drill).name
  end

  test "another user's gear and records are not found, for every action" do
    truck = gears(:truck)
    their_fill_up = fuel_entries(:truck_fill_up)
    their_expense = expenses(:drill_bits)

    requests = [
      -> { get api_v1_gear_path(truck), headers: api_headers },
      -> { patch api_v1_gear_path(truck), params: { name: "Mine now" }, headers: api_headers, as: :json },
      -> { get api_v1_gear_fuel_entries_path(truck), headers: api_headers },
      -> { post api_v1_gear_fuel_entries_path(truck), params: { amount: 5 }, headers: api_headers, as: :json },
      -> { get api_v1_gear_fuel_entry_path(truck, their_fill_up), headers: api_headers },
      -> { patch api_v1_gear_fuel_entry_path(truck, their_fill_up), params: { amount: 1 }, headers: api_headers, as: :json },
      -> { delete api_v1_gear_fuel_entry_path(truck, their_fill_up), headers: api_headers },
      # Their record through one of my own gears:
      -> { get api_v1_gear_expense_path(gears(:prius), their_expense), headers: api_headers },
      -> { patch api_v1_gear_expense_path(gears(:prius), their_expense), params: { amount: 1 }, headers: api_headers, as: :json },
      -> { delete api_v1_gear_expense_path(gears(:prius), their_expense), headers: api_headers }
    ]

    assert_no_changes -> { [ truck.reload.attributes, their_fill_up.reload.attributes, their_expense.reload.attributes, FuelEntry.count ] } do
      requests.each_with_index do |request, index|
        request.call
        assert_response :not_found, "request #{index}"
        assert_equal({ "error" => "Not found" }, json, "request #{index}")
      end
    end
  end

  test "can't move a record onto another user's gear" do
    patch api_v1_gear_expense_path(gears(:prius), expenses(:oil_change)), params: { gear_id: gears(:truck).id }, headers: api_headers, as: :json

    assert_response :unprocessable_content
    assert_equal gears(:prius), expenses(:oil_change).reload.gear
  end

  test "can't make another user's gear the parent" do
    patch api_v1_gear_path(gears(:prius)), params: { parent_id: gears(:truck).id }, headers: api_headers, as: :json

    assert_response :unprocessable_content
    assert_nil gears(:prius).reload.parent_id
  end

  test "can't hand gear to another user" do
    post api_v1_gears_path, params: { name: "Gift", user_id: users(:two).id }, headers: api_headers, as: :json

    assert_response :unprocessable_content
    assert_match "user_id", json["error"]
  end

  # --- Read-only tokens ---

  test "a read-only token can read" do
    get api_v1_gears_path, headers: api_headers("gt_one_read")
    assert_response :success

    get api_v1_gear_expenses_path(gears(:prius)), headers: api_headers("gt_one_read")
    assert_response :success
  end

  test "a read-only token can't create, change or delete anything" do
    prius = gears(:prius)
    oil_change = expenses(:oil_change)
    read_only = api_headers("gt_one_read")

    assert_no_changes -> { [ Gear.count, Expense.count, prius.reload.name, oil_change.reload.amount ] } do
      post api_v1_gears_path, params: { name: "New" }, headers: read_only, as: :json
      assert_response :forbidden

      patch api_v1_gear_path(prius), params: { name: "Renamed" }, headers: read_only, as: :json
      assert_response :forbidden

      post api_v1_gear_expenses_path(prius), params: { description: "Wash", amount: 10 }, headers: read_only, as: :json
      assert_response :forbidden

      patch api_v1_gear_expense_path(prius, oil_change), params: { amount: 1 }, headers: read_only, as: :json
      assert_response :forbidden

      delete api_v1_gear_expense_path(prius, oil_change), headers: read_only
      assert_response :forbidden
    end
    assert_equal "This token is read-only", json["error"]
  end

  # --- Requests that try to break things ---

  test "gear can't be deleted through the API, since that also deletes all its records" do
    delete "/api/v1/gears/#{gears(:prius).id}", headers: api_headers

    assert_response :not_found
    assert Gear.exists?(gears(:prius).id)
  end

  test "an id with SQL or other text in it finds nothing" do
    [ "#{gears(:prius).id}%20OR%201=1", "#{gears(:truck).id}%20OR%201=1", "0%20OR%201=1", "#{gears(:prius).id}abc" ].each do |id|
      get "/api/v1/gears/#{id}", headers: api_headers
      assert_response :not_found, id

      get "/api/v1/gears/#{id}/expenses", headers: api_headers
      assert_response :not_found, id
    end
  end

  test "malformed JSON is a bad request" do
    post api_v1_gears_path, params: "{ not json", headers: api_headers.merge("Content-Type" => "application/json")

    assert_response :bad_request
    assert_equal "Request body isn't valid JSON", json["error"]
  end

  test "too many requests are refused" do
    100.times { get api_v1_me_path, headers: api_headers }
    assert_response :success

    get api_v1_me_path, headers: api_headers
    assert_response :too_many_requests
  end

  test "too many requests without a token are refused too, which slows down guessing" do
    100.times { get api_v1_me_path, headers: api_headers("gt_guess") }

    get api_v1_me_path, headers: api_headers
    assert_response :too_many_requests
  end

  # --- Responses ---

  test "responses aren't cached and can't be read by other websites" do
    get api_v1_gears_path, headers: api_headers.merge("Origin" => "https://evil.example")

    assert_match "no-store", response.headers["Cache-Control"]
    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "me shows settings but not the email address or other tokens" do
    travel_to Time.utc(2026, 11, 27, 4, 47)
    get api_v1_me_path, headers: api_headers

    assert_equal({ "currency" => "USD", "distance_unit" => "mi", "volume_unit" => "us_gal", "time_zone" => "UTC", "today" => "2026-11-27", "token" => { "name" => "Agent on laptop", "permission" => "write" } }, json)
  end
end
