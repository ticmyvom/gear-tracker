class ReadingsController < ApplicationController
  before_action :set_gear
  before_action :set_reading, only: %i[ edit update destroy ]

  def new
    @reading = @gear.readings.new(read_on: Date.current)
  end

  def edit
  end

  def create
    @reading = @gear.readings.new(reading_params)

    if @reading.save
      redirect_to @gear, notice: "Reading added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @reading.update(reading_params)
      redirect_to @gear, notice: "Reading updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @reading.destroy!
    redirect_to @gear, notice: "Reading deleted.", status: :see_other
  end

  private
    def set_gear
      @gear = Current.user.gears.find(params[:gear_id])
    end

    def set_reading
      @reading = @gear.readings.find(params[:id])
    end

    def reading_params
      params.expect(reading: %i[ read_on name value unit entered_odometer notes ])
    end
end
