require "test_helper"
require Rails.root.join("db/migrate/20261121120000_standardize_gear_categories")

class StandardizeGearCategoriesTest < ActiveSupport::TestCase
  def with_category(gear, text, notes: nil)
    gear.update_columns(category: text, notes: notes) # the old free text, skipping validation
    gear
  end

  test "maps names and similar old text to keys, and keeps unknown text in the notes" do
    car = with_category(gears(:prius), " Vehicle ")
    tires = with_category(gears(:tires), "Tires")
    drill = with_category(gears(:drill), "Cordless stuff", notes: "Blue")
    truck = with_category(gears(:truck), "")

    StandardizeGearCategories.new.up

    assert_equal [ "vehicle", "parts", "other", nil ], [ car, tires, drill, truck ].map { it.reload.category }
    assert_equal "Category: Cordless stuff\n\nBlue", drill.notes
  end

  test "rolling back turns keys back into names" do
    StandardizeGearCategories.new.down

    assert_equal [ "Vehicle", "Parts & accessories" ], [ gears(:prius), gears(:tires) ].map { it.reload.category }
  end
end
