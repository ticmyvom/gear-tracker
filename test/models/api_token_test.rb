require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "a new token is long, random and shown only on the new record" do
    api_token = users(:one).api_tokens.create!(name: "Agent", permission: "write")

    assert_match(/\Agt_[1-9A-HJ-NP-Za-km-z]{40}\z/, api_token.token)
    assert_nil ApiToken.find(api_token.id).token
    assert_not_equal api_token.token, users(:one).api_tokens.create!(name: "Other", permission: "write").token
  end

  test "only a digest of the token is stored" do
    api_token = users(:one).api_tokens.create!(name: "Agent", permission: "write")
    stored = ApiToken.connection.select_rows("SELECT * FROM api_tokens WHERE id = #{api_token.id}").flatten.map(&:to_s)

    assert_not_includes stored, api_token.token
    assert_equal OpenSSL::Digest::SHA256.hexdigest(api_token.token), api_token.token_digest
  end

  test "authenticate finds the token by its plain value" do
    api_token = users(:one).api_tokens.create!(name: "Agent", permission: "read")

    assert_equal api_token, ApiToken.authenticate(api_token.token)
    assert_equal api_tokens(:one_write), ApiToken.authenticate("gt_one_write")
  end

  test "authenticate rejects wrong, blank and digest values" do
    assert_nil ApiToken.authenticate("gt_wrong")
    assert_nil ApiToken.authenticate("")
    assert_nil ApiToken.authenticate(nil)
    assert_nil ApiToken.authenticate(api_tokens(:one_write).token_digest)
  end

  test "requires a name and a known permission" do
    assert_not users(:one).api_tokens.new(permission: "write").valid?
    assert_not users(:one).api_tokens.new(name: "Agent", permission: "admin").valid?
    assert_not users(:one).api_tokens.new(name: "Agent").valid?
  end

  test "write permission" do
    assert api_tokens(:one_write).write?
    assert_not api_tokens(:one_read).write?
  end

  test "used! records the time, at most once a minute" do
    api_token = api_tokens(:one_write)
    api_token.used!
    first_use = api_token.reload.last_used_at
    assert_not_nil first_use

    travel 30.seconds do
      api_token.used!
      assert_equal first_use, api_token.reload.last_used_at
    end

    travel 2.minutes do
      api_token.used!
      assert_operator api_token.reload.last_used_at, :>, first_use
    end
  end

  test "deleting a user deletes their tokens" do
    assert_difference -> { ApiToken.count }, -2 do
      users(:one).destroy!
    end
  end
end
