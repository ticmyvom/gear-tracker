require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "pages only allow scripts and styles from this app" do
    get new_session_path

    policy = response.headers["Content-Security-Policy"]
    assert_match "default-src 'self'", policy
    assert_match "object-src 'none'", policy
    assert_match "frame-ancestors 'none'", policy
    assert_match(/script-src 'self' 'nonce-\S+'/, policy)
    assert_no_match "unsafe-inline", policy
    assert_no_match "unsafe-eval", policy
  end

  test "the app's own inline scripts carry this request's nonce" do
    get new_session_path

    nonce = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]
    assert_select "meta[name=csp-nonce][content=?]", nonce
    assert_select "script[type=importmap][nonce=?]", nonce
  end

  test "each request gets a new nonce" do
    nonces = 2.times.map do
      get new_session_path
      response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]
    end

    assert_not_equal nonces.first, nonces.last
  end
end
