class Gear < ApplicationRecord
  include Priced

  # Stored by key, so a name can change without touching saved gear.
  CATEGORIES = {
    "vehicle" => "Vehicle",
    "bicycle" => "Bicycle",
    "parts" => "Parts & accessories",
    "tools" => "Tools",
    "electronics" => "Electronics",
    "computers" => "Computers",
    "appliances" => "Appliances",
    "kitchen" => "Kitchen",
    "heating_cooling" => "Heating & cooling",
    "household" => "Household",
    "outdoor" => "Outdoor & camping",
    "sports" => "Sports & fitness",
    "clothing" => "Clothing & shoes",
    "music" => "Music",
    "other" => "Other"
  }.freeze
  POWER_SOURCES = {
    "manual" => "Manual (human-powered)",
    "gasoline" => "Gasoline",
    "diesel" => "Diesel",
    "propane" => "Propane",
    "electric" => "Electric",
    "plug_in_hybrid" => "Plug-in hybrid (gasoline + electric)"
  }.freeze
  FUEL_UNITS = {
    "gasoline" => %w[ l ],
    "diesel" => %w[ l ],
    "propane" => %w[ l ],
    "electric" => %w[ kWh ],
    "plug_in_hybrid" => %w[ l kWh ]
  }.freeze

  # What kind of vehicle it is, in the order it's written.
  VEHICLE_FIELDS = %i[ year make model trim ].freeze
  # Suggested while typing, and how each is spelled; any other make is fine too.
  MAKES = [
    "Acura", "Alfa Romeo", "Audi", "BMW", "Buick", "BYD", "Cadillac", "Chevrolet", "Chrysler", "Dodge", "Ducati", "Fiat",
    "Ford", "Genesis", "GMC", "Harley-Davidson", "Honda", "Hyundai", "Infiniti", "Isuzu", "Jaguar", "Jeep", "Kawasaki",
    "Kia", "Land Rover", "Lexus", "Lincoln", "Lucid", "Mazda", "Mercedes-Benz", "Mercury", "Mini", "Mitsubishi", "Nissan",
    "Peugeot", "Polestar", "Pontiac", "Porsche", "Ram", "Renault", "Rivian", "Saab", "Saturn", "Scion", "Skoda", "Subaru",
    "Suzuki", "Tesla", "Toyota", "Triumph", "VinFast", "Volkswagen", "Volvo", "Yamaha"
  ].freeze

  belongs_to :user
  belongs_to :parent, class_name: "Gear", optional: true, inverse_of: :components
  has_many :components, class_name: "Gear", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :expenses, dependent: :destroy
  has_many :readings, dependent: :destroy
  has_many :fuel_entries, dependent: :destroy

  delegate :distance_unit, :volume_unit, to: :user

  scope :top_level, -> { where(parent_id: nil) }

  normalizes :power_source, with: ->(source) { source.presence }
  # Accepts a key or a name in any case, like "Vehicle"; anything else fails validation.
  normalizes :category, with: ->(text) { category_key_for(text) || text.strip.presence }
  normalizes :make, with: ->(text) { text.squish.then { |typed| MAKES.find { it.casecmp?(typed) } || typed.presence } }
  normalizes :model, :trim, with: ->(text) { text.squish.presence }
  before_validation :name_after_vehicle, if: :vehicle?
  # Components are shown as part of their parent, so only top-level gear is made public on its own.
  before_validation { self.public = self.public_costs = false if parent_id.present? }
  before_validation { self.public_costs = false unless public? }

  validates :name, presence: true, unless: :vehicle?
  validate { errors.add(:base, "Add a year, make or model, or a nickname") if vehicle? && name.blank? }
  validates :power_source, inclusion: { in: POWER_SOURCES.keys }, allow_nil: true
  validates :category, inclusion: { in: CATEGORIES.keys, message: "must be one of: #{CATEGORIES.keys.join(", ")}" }, allow_nil: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  # Cars date from 1885, and next year's models are sold early.
  validates :year, allow_nil: true, numericality: { only_integer: true, greater_than_or_equal_to: 1885, less_than_or_equal_to: ->(_) { Date.current.year + 1 } }
  validates :make, :model, :trim, length: { maximum: 50 }
  validate :parent_is_allowed

  # Purchase price plus every expense and fuel entry, including those of components.
  def total_cost
    Costs.new.add(price, currency) + Costs.of(expenses, :amount) + Costs.of(fuel_entries, :total_price) + components.sum(Costs.new, &:total_cost)
  end

  # Counts at least one year, so a new purchase isn't extrapolated into a huge yearly figure.
  def cost_per_year
    return unless purchased_on

    years_owned = (Date.current - purchased_on).to_f / 365.25
    total_cost / [ years_owned, 1 ].max
  end

  def power_source_name
    POWER_SOURCES[power_source]
  end

  # Liters and/or kWh; empty for gear that doesn't take fuel or electricity.
  def fuel_units
    FUEL_UNITS.fetch(power_source, [])
  end

  def self.category_key_for(text)
    text = text.to_s.strip
    CATEGORIES.find { |key, name| text.casecmp?(key) || text.casecmp?(name) }&.first
  end

  def category_name
    CATEGORIES[category]
  end

  # Only vehicles get odometer and miles fields.
  def vehicle?
    category == "vehicle"
  end

  # "2010 Toyota Prius Two", from whichever parts are filled in.
  def vehicle_name
    join_vehicle_fields { public_send(it) } if vehicle?
  end

  # A name the owner chose, rather than one filled in from the vehicle's details.
  def nickname
    name unless name == vehicle_name
  end

  # Vehicles and their parts, like tires, can note the odometer on readings.
  def tracks_odometer?
    vehicle? || parent&.vehicle?
  end

  private
    def currency_owner
      user
    end

    def join_vehicle_fields(&)
      VEHICLE_FIELDS.filter_map(&).join(" ").presence
    end

    # Without a nickname, a vehicle is named by its details, and renamed when they change.
    def name_after_vehicle
      self.name = vehicle_name if name.blank? || name == join_vehicle_fields { attribute_in_database(it) }
    end

    def parent_is_allowed
      return if parent_id.blank?

      if parent.nil? || parent.user_id != user_id || parent_id == id || parent.parent_id.present?
        errors.add(:parent, "must be one of your other top-level gears")
      elsif components.exists?
        errors.add(:parent, "can't be set on gear that has its own components")
      end
    end
end
