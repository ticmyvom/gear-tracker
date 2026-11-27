require "test_helper"

# The README is a table of contents for the docs, so a moved or renamed page
# must not leave a broken link behind.
class DocsTest < ActiveSupport::TestCase
  test "links between the docs and to screenshots point to files that exist" do
    pages = [ "README.md", "CONTRIBUTING.md", "CHANGELOG.md", *Dir["docs/*.md"] ].map { Rails.root.join(it) }

    pages.each do |page|
      targets = page.read.scan(/\]\(([^)\s]+)\)|src="([^"]+)"/).flatten.compact
      targets.reject { it.match?(%r{\A(https?:|mailto:|#)}) }.each do |target|
        assert page.dirname.join(target.split("#").first).exist?, "#{page.relative_path_from(Rails.root)} links to missing #{target}"
      end
    end
  end
end
