module Api
  module V1
    class ExpensesController < GearRecordsController
      DATE_COLUMN = :spent_on
      CREATE_FIELDS = UPDATE_FIELDS = %i[ date description category amount currency vendor notes ].freeze
    end
  end
end
