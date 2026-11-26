require "test_helper"

# Tests that need a real browser, like where the page scrolls to. They run in a
# headless Firefox with `bin/rails test:system`, not with `bin/rails test`.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_firefox, screen_size: [ 1000, 700 ]

  def sign_in_as(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button "Sign in"
    assert_no_current_path new_session_path
  end

  # How far the page is scrolled down, in pixels.
  def scrolled = page.evaluate_script("window.scrollY")
end
