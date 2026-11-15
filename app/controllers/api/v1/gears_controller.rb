module Api
  module V1
    # Gear can be listed, read, added and changed, but not deleted: deleting gear
    # also deletes its components and every record, which is left to the website.
    class GearsController < BaseController
      FIELDS = %i[ name category power_source parent_id purchased_on price currency purchased_from notes ].freeze

      before_action :set_gear, only: %i[ show update ]

      def index
        @gears = current_user.gears.includes(:expenses, :fuel_entries, components: %i[ expenses fuel_entries ]).order(:name)
      end

      def show
      end

      def create
        @gear = current_user.gears.new(gear_params)

        if @gear.save
          render :show, status: :created, location: api_v1_gear_url(@gear)
        else
          render_invalid @gear
        end
      end

      def update
        if @gear.update(gear_params)
          render :show
        else
          render_invalid @gear
        end
      end

      private
        def set_gear
          @gear = current_user.gears.find(params[:id])
        end

        def gear_params
          body_params(FIELDS).tap { check_date(it["purchased_on"], "purchased_on") }
        end
    end
  end
end
