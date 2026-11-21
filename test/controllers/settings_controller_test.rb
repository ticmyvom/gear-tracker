require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "edit" do
    get edit_settings_path

    assert_response :success
    assert_select "option[selected][value=USD]"
  end

  test "update saves currency and units" do
    patch settings_path, params: { user: { currency: "GBP", distance_unit: "km", volume_unit: "uk_gal" } }

    assert_redirected_to edit_settings_path
    assert_equal %w[ GBP km uk_gal ], users(:one).reload.values_at(:currency, :distance_unit, :volume_unit)
  end

  test "update rejects an unknown unit" do
    patch settings_path, params: { user: { distance_unit: "furlong" } }

    assert_response :unprocessable_content
    assert_equal "mi", users(:one).reload.distance_unit
  end

  test "update can't change the email address" do
    patch settings_path, params: { user: { email_address: "new@example.com", currency: "EUR" } }

    assert_equal "one@example.com", users(:one).reload.email_address
  end

  test "requires sign in" do
    sign_out
    get edit_settings_path

    assert_redirected_to new_session_path
  end

  # --- Public profile ---

  test "making the profile public links to it" do
    patch settings_path, params: { user: { display_name: "Trail Runner", username: "Trail-Runner", profile_public: "1" } }

    assert_redirected_to edit_settings_path
    assert_equal [ "Trail Runner", "trail-runner", true ], users(:one).reload.values_at(:display_name, :username, :profile_public)
    follow_redirect!
    assert_select "a[href=?]", profile_path(username: "trail-runner")
  end

  test "a public profile needs a username and display name" do
    patch settings_path, params: { user: { profile_public: "1" } }

    assert_response :unprocessable_content
    assert_select "li", "Username is needed for a public profile"
    assert_not users(:one).reload.profile_public
  end

  test "saving currency leaves the profile alone" do
    users(:one).update!(username: "one", display_name: "One", profile_public: true)

    patch settings_path, params: { user: { currency: "GBP" } }

    assert users(:one).reload.profile_public
  end
end
