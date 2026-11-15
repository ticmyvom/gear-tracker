require "test_helper"

class VersionTest < ActiveSupport::TestCase
  test "the version is major.minor.patch" do
    assert_match(/\A\d+\.\d+\.\d+\z/, GearTracker::VERSION)
  end

  test "the changelog has an entry for the current version" do
    assert_match(/^## \[#{Regexp.escape(GearTracker::VERSION)}\] - \d{4}-\d{2}-\d{2}$/, Rails.root.join("CHANGELOG.md").read)
  end
end
