class FuelEntriesController < ApplicationController
  before_action :set_gear
  before_action :set_fuel_entry, only: %i[ edit update destroy ]

  def new
    @fuel_entry = @gear.fuel_entries.new(filled_on: Date.current, unit: params[:unit])
  end

  def edit
  end

  def create
    @fuel_entry = @gear.fuel_entries.new(fuel_entry_params(:unit))

    if @fuel_entry.save
      redirect_to @gear, section: :fuel_entries, notice: "#{@fuel_entry.label.capitalize} added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @fuel_entry.update(fuel_entry_params)
      redirect_to @gear, section: :fuel_entries, notice: "#{@fuel_entry.label.capitalize} updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @fuel_entry.destroy!
    redirect_to @gear, section: :fuel_entries, notice: "#{@fuel_entry.label.capitalize} deleted.", status: :see_other
  end

  private
    def set_gear
      @gear = Current.user.gears.find(params[:gear_id])
    end

    def set_fuel_entry
      @fuel_entry = @gear.fuel_entries.find(params[:id])
    end

    # The unit can only be chosen when an entry is created, so old entries keep their meaning.
    def fuel_entry_params(*create_only)
      params.expect(fuel_entry: [ :filled_on, :total_price, :currency, :entered_amount, :used_hours, :used_minutes, :entered_odometer, :entered_trip, :filled_up, :missed_previous, :efficiency_checked, :notes, *create_only ])
    end
end
