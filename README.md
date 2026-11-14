# Gear Tracker

Own gears, not stuff. A text-based web app for recording what you own, when you
bought it, where from, and what it has really cost you. Each user sees only
their own gear.

- **Gear**: anything you own, with its purchase date, price, and where you bought it.
- **Components**: gear that belongs to other gear, like a set of tires on a car.
  Their costs count toward the parent's total.
- **Expenses**: money spent after the purchase, like repairs or insurance.
- **Power source**: what makes the gear go: nothing, human power, gasoline, diesel,
  propane, electricity, or both gasoline and electricity for a plug-in hybrid.
- **Fuel entries**: fill-ups (gallons) or energy use (kWh) for gear that runs on fuel or
  electricity. Add minutes of use to see gallons or kWh per hour, or miles driven to
  see miles per gallon or per kWh.
- **Readings**: measurements over time, like tire pressure or odometer.
- **Settings**: your currency, miles or kilometers, and US gallons, UK gallons or
  liters. Fuel entries are stored in kilometers and liters and shown in your units, so
  changing units updates old entries too. Changing currency only changes the symbol.

## Running it

Requires Ruby 3.4.2.

    bundle install
    bin/rails db:prepare
    bin/rails server

Then open http://localhost:3000 and sign up.

## Tests

    bin/rails test

## Keeping your data

The database is one file, `storage/development.sqlite3`. It isn't stored in git.

`bin/rails db:migrate` and `db:rollback` save a copy to `storage/backups` before
changing anything. To make or restore a copy yourself:

    bin/rails db:backup
    bin/rails db:restore FILE=storage/backups/name.sqlite3

Stop the server before restoring. Restoring saves a copy of the current database
first. Backups live on the same disk, so copy them elsewhere too.

## Before deploying

Password reset emails need SMTP settings and a real host in
`config/environments/production.rb`.
