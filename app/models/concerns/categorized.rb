# A category picked from the model's CATEGORIES. It's stored by key, so a name
# can change without touching saved records. Models may define CATEGORY_ALIASES,
# other lowercase text to accept for a key.
module Categorized
  extend ActiveSupport::Concern

  CATEGORY_ALIASES = {}.freeze

  included do
    # Accepts a key or a name in any case, like "Vehicle"; anything else fails validation.
    normalizes :category, with: ->(text) { category_key_for(text) || text.strip.presence }
    validates :category, allow_nil: true, inclusion: {
      in: ->(record) { record.class::CATEGORIES.keys },
      message: ->(record, _) { "must be one of: #{record.class::CATEGORIES.keys.join(", ")}" }
    }
  end

  class_methods do
    def category_key_for(text)
      text = text.to_s.strip
      self::CATEGORIES.find { |key, name| text.casecmp?(key) || text.casecmp?(name) }&.first || self::CATEGORY_ALIASES[text.downcase]
    end
  end

  def category_name
    self.class::CATEGORIES[category]
  end
end
