require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "create signs the new user in" do
    assert_difference -> { User.count } do
      post registration_path, params: { user: { email_address: "new@example.com", password: "long enough", password_confirmation: "long enough" } }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create rejects mismatched passwords" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: { email_address: "new@example.com", password: "long enough", password_confirmation: "different" } }
    end

    assert_response :unprocessable_content
  end
end
