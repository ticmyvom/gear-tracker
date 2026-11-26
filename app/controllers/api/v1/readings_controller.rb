module Api
  module V1
    class ReadingsController < GearRecordsController
      DATE_COLUMN = :read_on
      CREATE_FIELDS = UPDATE_FIELDS = %i[ date name value unit odometer notes ].freeze    end
  end
end
