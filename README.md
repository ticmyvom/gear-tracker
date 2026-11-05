# Gear Tracker

Own gears, not stuff. A text-based web app for recording what you own, when you
bought it, where from, and what it has really cost you. Each user sees only
their own gear.

- **Gear**: anything you own, with its purchase date, price, and where you bought it.
- **Components**: gear that belongs to other gear, like a set of tires on a car.
  Their costs count toward the parent's total.
- **Expenses**: money spent after the purchase, like repairs or insurance.
- **Fuel entries**: fill-ups for gear in the Vehicle category, with total price and
  gallons, plus optional odometer and trip.
- **Readings**: measurements over time, like tire pressure or odometer.

## Running it

Requires Ruby 3.4.2.

    bundle install
    bin/rails db:prepare
    bin/rails server

Then open http://localhost:3000 and sign up.

## Tests

    bin/rails test

## Before deploying

Password reset emails need SMTP settings and a real host in
`config/environments/production.rb`.
