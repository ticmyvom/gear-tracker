module Api
  module V1
    class ReadingsController < GearRecordsController
      DATE_COLUMN = :read_on
      CREATE_FIELDS = UPDATE_FIELDS = %i[ date name value unit odometer notes ].freeze

      private
        # The odometer is in the user's distance unit, like on fuel entries.
        def record_params(fields)
          super.transform_keys { it == "odometer" ? "entered_odometer" : it }
        end
    end
  end
end
