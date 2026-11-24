# The demo: a sign-in and sample gear for people trying the app, e.g. in a
# GitHub Codespace. Dates are relative to the day it's loaded, so it always
# looks current. Demo mode is on when GEAR_TRACKER_DEMO=1, and never in production.
module Demo
  EMAIL = "demo@example.com"
  PASSWORD = "demo-password"

  def self.enabled?(env: ENV, rails_env: Rails.env)
    env["GEAR_TRACKER_DEMO"] == "1" && !rails_env.production?
  end

  # Replaces the demo user and their gear; other users are left alone.
  def self.load!
    ActiveRecord::Base.transaction do
      User.find_by(email_address: EMAIL)&.destroy!
      user = User.create!(email_address: EMAIL, password: PASSWORD, currency: "USD", distance_unit: "mi", volume_unit: "us_gal")

      add_prius_prime(user)
      add_heated_mattress_pad(user)
      add_bicycle(user)
      user.gears.create!(name: "Rain jacket", category: "clothing", price: 120, purchased_on: 4.years.ago.to_date, purchased_from: "Outdoor store")
    end
  end

  class << self
    private
      def add_prius_prime(user)
        prius = user.gears.create!(name: "2020 Toyota Prius Prime", category: "vehicle", year: 2020, make: "Toyota", model: "Prius Prime", power_source: "plug_in_hybrid",
          price: 21_500, purchased_on: 2.years.ago.to_date, purchased_from: "Used car dealer",
          notes: "Plug-in hybrid: about 25 miles on a charge, then about 54 mpg on gas.")

        # Odometer and miles since the last fill-up or charge, about 54 mpg on gas.
        [
          [ 60, "fuel", 9.6, 32.64, 149_100.0, 520.0, nil, "Gas station on the way home" ],
          [ 46, "energy", 8.8, 1.32, 149_350.0, 25.0, 330, "Garage outlet, overnight" ],
          [ 32, "fuel", 9.5, 32.30, 149_620.0, 520.0, nil, nil ],
          [ 16, "energy", 8.6, 1.29, 149_800.0, 24.6, 320, "Garage outlet, overnight" ],
          [ 2, "fuel", 7.0, 23.80, 150_000.0, 380.0, nil, "Road trip" ]
        ].each do |days_ago, kind, amount, price, odometer, trip, minutes, notes|
          prius.fuel_entries.create!(filled_on: days_ago.days.ago.to_date, unit: FuelEntry.unit_for_kind(kind),
            entered_amount: amount, total_price: price, entered_odometer: odometer, entered_trip: trip, minutes: minutes, notes: notes)
        end

        prius.expenses.create!(spent_on: 70.days.ago.to_date, description: "Oil change", category: "maintenance", amount: 69.99, vendor: "Quick lube", notes: "0W-16 synthetic")
        prius.expenses.create!(spent_on: 120.days.ago.to_date, description: "Registration", category: "registration", amount: 85.50, vendor: "DMV")
        prius.readings.create!(read_on: 2.days.ago.to_date, name: "Odometer", value: 150_000, unit: "mi")
        prius.readings.create!(read_on: 2.days.ago.to_date, name: "Tire pressure FL", value: 36, unit: "psi")

        tires = user.gears.create!(name: "All-season tires", category: "parts", parent: prius, price: 640, purchased_on: 1.year.ago.to_date, purchased_from: "Tire shop")
        tires.expenses.create!(spent_on: 90.days.ago.to_date, description: "Rotation", category: "maintenance", amount: 25, vendor: "Tire shop")
      end

      def add_heated_mattress_pad(user)
        pad = user.gears.create!(name: "Heated mattress pad", category: "heating_cooling", power_source: "electric",
          price: 59.99, purchased_on: 1.year.ago.to_date, purchased_from: "Online store")

        # 0.288 kWh over 9 hours is 32 W on average.
        pad.fuel_entries.create!(filled_on: 8.days.ago.to_date, entered_amount: 0.405, used_hours: 9, total_price: 0.06, notes: "Medium setting, cold night")
        pad.fuel_entries.create!(filled_on: 1.day.ago.to_date, entered_amount: 0.288, used_hours: 9, total_price: 0.04, notes: "Low setting overnight")
      end

      def add_bicycle(user)
        bike = user.gears.create!(name: "Commuter bicycle", category: "bicycle", power_source: "manual",
          price: 450, purchased_on: 3.years.ago.to_date, purchased_from: "Bike shop")
        bike.expenses.create!(spent_on: 45.days.ago.to_date, description: "Tune-up", category: "maintenance", amount: 60, vendor: "Bike shop")
      end
  end
end
