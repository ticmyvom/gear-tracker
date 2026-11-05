class FuelEntriesController < ApplicationController
  before_action :set_gear
  before_action :set_fuel_entry, only: %i[ edit update destroy ]

  def new
    @fuel_entry = @gear.fuel_entries.new(filled_on: Date.current)
  end

  def edit
  end

  def create
    @fuel_entry = @gear.fuel_entries.new(fuel_entry_params)

    if @fuel_entry.save
      redirect_to @gear, notice: "Fuel entry added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @fuel_entry.update(fuel_entry_params)
      redirect_to @gear, notice: "Fuel entry updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @fuel_entry.destroy!
    redirect_to @gear, notice: "Fuel entry deleted.", status: :see_other
  end

  private
    def set_gear
      @gear = Current.user.gears.find(params[:gear_id])
    end

    def set_fuel_entry
      @fuel_entry = @gear.fuel_entries.find(params[:id])
    end

    def fuel_entry_params
      params.expect(fuel_entry: %i[ filled_on total_price gallons odometer trip ])
    end
end
