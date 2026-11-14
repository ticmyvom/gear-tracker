class Gear < ApplicationRecord
  SUGGESTED_CATEGORIES = %w[ Vehicle Tires Tools Electronics Outdoor Kitchen Clothing ].freeze
  POWER_SOURCES = {
    "manual" => "Manual (human-powered)",
    "gasoline" => "Gasoline",
    "diesel" => "Diesel",
    "propane" => "Propane",
    "electric" => "Electric",
    "plug_in_hybrid" => "Plug-in hybrid (gasoline + electric)"
  }.freeze
  FUEL_UNITS = {
    "gasoline" => %w[ gal ],
    "diesel" => %w[ gal ],
    "propane" => %w[ gal ],
    "electric" => %w[ kWh ],
    "plug_in_hybrid" => %w[ gal kWh ]
  }.freeze

  belongs_to :user
  belongs_to :parent, class_name: "Gear", optional: true, inverse_of: :components
  has_many :components, class_name: "Gear", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :expenses, dependent: :destroy
  has_many :readings, dependent: :destroy
  has_many :fuel_entries, dependent: :destroy

  scope :top_level, -> { where(parent_id: nil) }

  normalizes :power_source, with: ->(source) { source.presence }

  validates :name, presence: true
  validates :power_source, inclusion: { in: POWER_SOURCES.keys }, allow_nil: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :parent_is_allowed

  # Purchase price plus every expense and fuel entry, including those of components.
  def total_cost
    (price || 0) + expenses.sum(&:amount) + fuel_entries.sum { it.total_price || 0 } + components.sum(&:total_cost)
  end

  # Counts at least one year, so a new purchase isn't extrapolated into a huge yearly figure.
  def cost_per_year
    return unless purchased_on

    years_owned = (Date.current - purchased_on).to_f / 365.25
    total_cost.to_f / [ years_owned, 1 ].max
  end

  def power_source_name
    POWER_SOURCES[power_source]
  end

  # Gallons and/or kWh; empty for gear that doesn't take fuel or electricity.
  def fuel_units
    FUEL_UNITS.fetch(power_source, [])
  end

  # Only vehicles get odometer and miles fields.
  def vehicle?
    category.to_s.strip.casecmp?("Vehicle")
  end

  private
    def parent_is_allowed
      return if parent_id.blank?

      if parent.nil? || parent.user_id != user_id || parent_id == id || parent.parent_id.present?
        errors.add(:parent, "must be one of your other top-level gears")
      elsif components.exists?
        errors.add(:parent, "can't be set on gear that has its own components")
      end
    end
end
