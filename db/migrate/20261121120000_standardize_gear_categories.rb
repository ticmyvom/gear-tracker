# Moves gear from free-text categories to the fixed list in Gear::CATEGORIES.
# The mapping is copied here, not read from the model, so this migration keeps
# doing the same thing even if the list changes later. Text that doesn't match
# becomes "other", and the old text is kept at the top of the gear's notes.
class StandardizeGearCategories < ActiveRecord::Migration[8.1]
  class MigrationGear < ActiveRecord::Base
    self.table_name = "gears"
  end

  NAMES = {
    "vehicle" => "Vehicle", "bicycle" => "Bicycle", "parts" => "Parts & accessories", "tools" => "Tools",
    "electronics" => "Electronics", "computers" => "Computers", "appliances" => "Appliances", "kitchen" => "Kitchen",
    "heating_cooling" => "Heating & cooling", "household" => "Household", "outdoor" => "Outdoor & camping",
    "sports" => "Sports & fitness", "clothing" => "Clothing & shoes", "music" => "Music", "other" => "Other"
  }.freeze

  # Old free text, lowercased => new key, beyond the keys and names themselves.
  SIMILAR = {
    "car" => "vehicle", "truck" => "vehicle", "motorcycle" => "vehicle", "bike" => "bicycle",
    "tire" => "parts", "tires" => "parts", "parts" => "parts", "accessories" => "parts",
    "tool" => "tools", "cable" => "electronics", "sound" => "electronics", "audio" => "electronics",
    "home energy monitor" => "electronics", "phone" => "electronics", "watch" => "electronics", "smartwatch" => "electronics",
    "tablet" => "computers", "computer" => "computers", "laptop" => "computers",
    "appliance" => "appliances", "cleaning" => "appliances", "heating" => "heating_cooling", "cooling" => "heating_cooling",
    "home" => "household", "furniture" => "household", "bedroom" => "household", "outdoor" => "outdoor",
    "camping" => "outdoor", "sports" => "sports", "fitness" => "sports", "clothing" => "clothing", "shoes" => "clothing"
  }.freeze

  def up
    MigrationGear.where.not(category: [ nil, "" ]).find_each do |gear|
      text = gear.category.strip
      key = NAMES.find { |k, name| text.casecmp?(k) || text.casecmp?(name) }&.first || SIMILAR[text.downcase]
      if key
        gear.update_columns(category: key)
      else
        gear.update_columns(category: "other", notes: [ "Category: #{text}", gear.notes.presence ].compact.join("\n\n"))
      end
    end
    MigrationGear.where(category: "").update_all(category: nil)
  end

  # Turns keys back into names. Text that became "other" stays "Other"; its old
  # text is still at the top of the notes.
  def down
    NAMES.each { |key, name| MigrationGear.where(category: key).update_all(category: name) }
  end
end
