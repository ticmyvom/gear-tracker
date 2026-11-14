class GearsController < ApplicationController
  before_action :set_gear, only: %i[ show edit update destroy ]
  helper_method :parent_options

  def index
    @gears = Current.user.gears.top_level.includes(:expenses, :fuel_entries, components: %i[ expenses fuel_entries ]).order(:name)
  end

  def show
    @components = @gear.components.includes(:expenses, :fuel_entries).order(:name)
    @fuel_entries = @gear.fuel_entries.order(filled_on: :desc, id: :desc)
    @expenses = @gear.expenses.order(spent_on: :desc, id: :desc)
    @readings = @gear.readings.order(read_on: :desc, id: :desc)
  end

  def new
    @gear = Current.user.gears.new(parent_id: params[:parent_id])
  end

  def edit
  end

  def create
    @gear = Current.user.gears.new(gear_params)

    if @gear.save
      redirect_to @gear, notice: "Gear added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @gear.update(gear_params)
      redirect_to @gear, notice: "Gear updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @gear.destroy!
    redirect_to @gear.parent || gears_path, notice: "Gear deleted.", status: :see_other
  end

  private
    def set_gear
      @gear = Current.user.gears.find(params[:id])
    end

    def parent_options
      Current.user.gears.top_level.where.not(id: @gear.id).order(:name)
    end

    def gear_params
      params.expect(gear: %i[ name category power_source parent_id purchased_on price purchased_from notes ])
    end
end
