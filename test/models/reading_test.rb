require "test_helper"

class ReadingTest < ActiveSupport::TestCase
  test "the odometer is typed in the owner's units and stored in kilometers" do
    reading = gears(:prius).readings.create!(read_on: Date.current, name: "Tread depth", value: 6, entered_odometer: "1000")

    saved = Reading.find(reading.id)
    assert_in_delta 1609.344, saved.odometer, 0.001
    assert_equal 1000, saved.entered_odometer
    assert_equal "mi", saved.distance_label
  end

  test "the odometer is optional, and can't be negative or text" do
    assert gears(:prius).readings.new(read_on: Date.current, name: "Pressure", value: 35).valid?
    [ "-5", "lots" ].each do |odometer|
      assert_not gears(:prius).readings.new(read_on: Date.current, name: "Pressure", value: 35, entered_odometer: odometer).valid?
    end
  end
end
