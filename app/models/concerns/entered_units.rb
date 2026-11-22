# A record that stores values in kilometers and liters (or kWh), but is typed
# and shown in its owner's units through entered_<field> attributes.
#
# Including models list their fields with `entered_fields odometer: 1` (field =>
# decimal places shown), define stored_unit_for(field) and preferred_unit_for(field),
# and run `before_validation :store_entered_values` once those units are known.
module EnteredUnits
  extend ActiveSupport::Concern

  class_methods do
    def entered_fields(fields)
      fields.each do |field, decimals|
        # The value in the owner's units: as typed, or converted from what's stored.
        define_method(:"entered_#{field}") do
          entered_values.fetch(field) { preferred(field)&.round(decimals) }
        end

        define_method(:"entered_#{field}=") { |value| entered_values[field] = value }
      end
    end
  end

  # "mi" or "km"
  def distance_label
    Units::LABELS.fetch(distance_unit)
  end

  private
    def entered_values
      @entered_values ||= {}
    end

    def store_entered_values
      entered_values.each do |field, value|
        number = BigDecimal(value.to_s, exception: false) if value.present?
        # Anything that isn't a number is kept as typed, so validation reports it.
        self[field] = number ? Units.convert(number, preferred_unit_for(field), stored_unit_for(field)) : value.presence
      end
    end

    def preferred(field)
      Units.convert(self[field], stored_unit_for(field), preferred_unit_for(field))
    end
end
