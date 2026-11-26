module Api
  module V1
    # Shared actions for the records that belong to a gear: expenses, fuel
    # entries and readings. Each subclass names its fields and date column. In the
    # API every record's date is called "date".
    class GearRecordsController < BaseController
      before_action :set_gear
      before_action :set_record, only: %i[ show update destroy ]
      helper_method :record_name

      def index
        @records = records.order(self.class::DATE_COLUMN => :desc, id: :desc).limit(limit)
        render "api/v1/gear_records/index"
      end

      def show
        render "api/v1/gear_records/show"
      end

      def create
        @record = records.new(record_params(self.class::CREATE_FIELDS))

        if @record.save
          render "api/v1/gear_records/show", status: :created, location: url_for([ :api, :v1, @gear, @record ])
        else
          render_invalid @record
        end
      end

      def update
        if @record.update(record_params(self.class::UPDATE_FIELDS))
          render "api/v1/gear_records/show"
        else
          render_invalid @record
        end
      end

      def destroy
        @record.destroy!
        head :no_content
      end

      private
        def set_gear
          @gear = current_user.gears.find(params[:gear_id])
        end

        def set_record
          @record = records.find(params[:id])
        end

        # expenses, fuel_entries or readings of the gear
        def records
          @gear.public_send(controller_name)
        end

        # expense, fuel_entry or reading
        def record_name
          controller_name.singularize
        end

        # Odometers are in the user's distance unit.
        def record_params(fields)
          attributes = body_params(fields).transform_keys { it == "odometer" ? "entered_odometer" : it }
          if attributes.key?("date")
            check_date(attributes["date"], "date")
            attributes[self.class::DATE_COLUMN.to_s] = attributes.delete("date")
          end
          attributes
        end

        # Newest first; 100 by default, at most 500.
        def limit
          Integer(params.fetch(:limit, 100)).clamp(1, 500)
        rescue ArgumentError, TypeError
          raise InvalidFields, "limit must be a whole number"
        end
    end
  end
end
