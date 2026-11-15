require "test_helper"

class Api::V1::DocsTest < ActionDispatch::IntegrationTest
  test "the docs are readable without a token" do
    get api_v1_docs_path

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal Rails.root.join("docs/api.md").read, response.body
  end

  test "the docs list every currency, power source and fuel kind the API accepts" do
    docs = Rails.root.join("docs/api.md").read

    [ *User::CURRENCIES.keys, *Gear::POWER_SOURCES.keys, *FuelEntry::KINDS.keys ].each do |value|
      assert_includes docs, "`#{value}`"
    end
  end

  test "the docs list every field each endpoint accepts" do
    docs = Rails.root.join("docs/api.md").read

    [ *Api::V1::GearsController::FIELDS, *Api::V1::ExpensesController::CREATE_FIELDS,
      *Api::V1::FuelEntriesController::CREATE_FIELDS, *Api::V1::ReadingsController::CREATE_FIELDS ].uniq.each do |field|
      assert_includes docs, "`#{field}`"
    end
  end
end
