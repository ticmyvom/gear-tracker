module Api
  module V1
    # Amounts, odometer and trip are in the user's preferred units, as on the
    # website. Time used is "hours" and/or "minutes", added together.
    class FuelEntriesController < GearRecordsController
      DATE_COLUMN = :filled_on
      UPDATE_FIELDS = %i[ date amount total_price currency hours minutes odometer trip filled_up missed_previous efficiency_checked notes ].freeze
      # The kind (fuel or energy) can only be chosen when an entry is created.
      CREATE_FIELDS = [ :kind, *UPDATE_FIELDS ].freeze
      MODEL_FIELDS = { "amount" => "entered_amount", "odometer" => "entered_odometer", "trip" => "entered_trip", "hours" => "used_hours", "minutes" => "used_minutes" }.freeze

      private
        def record_params(fields)
          attributes = super.transform_keys { MODEL_FIELDS.fetch(it, it) }
          attributes["unit"] = FuelEntry.unit_for_kind(attributes.delete("kind")) if attributes.key?("kind")
          attributes
        end
    end
  end
end
