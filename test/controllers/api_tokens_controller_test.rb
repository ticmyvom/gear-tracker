require "test_helper"

class ApiTokensControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "settings list the user's own tokens without revealing them" do
    get edit_settings_path

    assert_select "td", text: "Agent on laptop"
    assert_select "td", text: "Read-only dashboard"
    assert_select "td", text: "Other user's agent", count: 0
    assert_no_match api_tokens(:one_write).token_digest, response.body
  end

  test "create shows the new token once" do
    assert_difference -> { users(:one).api_tokens.count } do
      post api_tokens_path, params: { api_token: { name: "Claude", permission: "read" } }
    end

    assert_response :success
    token = css_select("code#new-api-token").text
    assert_equal users(:one).api_tokens.last, ApiToken.authenticate(token)
    assert_equal "read", ApiToken.authenticate(token).permission
    assert_match "no-store", response.headers["Cache-Control"]

    get edit_settings_path
    assert_no_match token, response.body
  end

  test "create with a missing name shows the error" do
    assert_no_difference -> { ApiToken.count } do
      post api_tokens_path, params: { api_token: { name: "", permission: "write" } }
    end

    assert_response :unprocessable_content
    assert_select ".errors", text: /Name can't be blank/
  end

  test "create can't make a token for another user" do
    post api_tokens_path, params: { api_token: { name: "Sneaky", permission: "write", user_id: users(:two).id } }

    assert_equal users(:one), ApiToken.find_by!(name: "Sneaky").user
  end

  test "revoke" do
    assert_difference -> { ApiToken.count }, -1 do
      delete api_token_path(api_tokens(:one_write))
    end

    assert_redirected_to edit_settings_path
    assert_nil ApiToken.authenticate("gt_one_write")
  end

  test "another user's token can't be revoked" do
    assert_no_difference -> { ApiToken.count } do
      delete api_token_path(api_tokens(:two_write))
    end

    assert_response :not_found
  end

  test "an API token can't be used to manage tokens" do
    sign_out
    headers = { "Authorization" => "Bearer gt_one_write" }

    assert_no_difference -> { ApiToken.count } do
      post api_tokens_path, params: { api_token: { name: "Escalated", permission: "write" } }, headers: headers
      delete api_token_path(api_tokens(:one_read)), headers: headers
    end

    assert_redirected_to new_session_path
  end
end
