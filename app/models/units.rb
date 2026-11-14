# Distance and volume units a user can choose, and conversion between them.
module Units
  DISTANCES = { "mi" => "Miles", "km" => "Kilometers" }.freeze
  VOLUMES = { "us_gal" => "US gallons", "uk_gal" => "UK gallons", "l" => "Liters" }.freeze
  LABELS = { "mi" => "mi", "km" => "km", "us_gal" => "gal", "uk_gal" => "UK gal", "l" => "L", "kWh" => "kWh" }.freeze

  # Size of each unit in kilometers or liters.
  SIZES = {
    "mi" => BigDecimal("1.609344"),
    "km" => BigDecimal("1"),
    "us_gal" => BigDecimal("3.785411784"),
    "uk_gal" => BigDecimal("4.54609"),
    "l" => BigDecimal("1")
  }.freeze

  def self.convert(value, from, to)
    return value if value.nil? || from == to

    value * SIZES.fetch(from) / SIZES.fetch(to)
  end
end
