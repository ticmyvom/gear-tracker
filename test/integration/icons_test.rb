require "test_helper"

class IconsTest < ActionDispatch::IntegrationTest
  # A PNG's width and height are stored at bytes 16 to 23.
  def png_size(path) = File.binread(path, 8, 16).unpack("NN")

  test "every icon a page links to exists, at the size it claims" do
    get privacy_path
    links = css_select("link[rel=icon], link[rel=apple-touch-icon]")
    assert_equal 3, links.size

    links.each do |link|
      file = Rails.public_path.join(link["href"].delete_prefix("/"))
      assert file.exist?, "#{link["href"]} is missing from public/"
      expected = link["sizes"] || "180x180" # apple-touch-icon is always 180×180
      assert_equal expected, png_size(file).join("x"), link["href"]
    end
  end
end
