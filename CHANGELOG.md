# Changelog

Notable changes to Gear Tracker. Versions follow [Semantic Versioning](https://semver.org/):
a **patch** release fixes bugs, a **minor** release adds features, and a **major**
release changes something users or API clients rely on.

The API has its own version in its path (`/api/v1`), which changes only when the API
changes in a way that breaks existing clients.

## [Unreleased]

- Dates like "today" follow your time zone, not the server's, so entries made in
  the evening no longer default to tomorrow. It's set from your browser when you
  sign up or next sign in, and can be changed in Settings. In the API, a date left
  out means today in your time zone, and `/me` includes `time_zone` and `today`
- Expenses of vehicles and their parts can note the odometer too, like "oil change
  at 152,300 mi". It also counts toward a vehicle's distance tracked
- A listed vehicle shows its owner's name only if they tick "Also show my name",
  even when their profile is public. Vehicles listed before now hide it
- After adding, changing or deleting an expense, fuel entry or reading, the gear
  page opens at that section, not at the top. Cancel does the same

## [0.3.0] - 2026-11-24

What vehicles really cost, and public profiles.

- A public Vehicles page at `/vehicles`, with filters by make and model, shows what
  listed vehicles really cost. Owners choose to list each vehicle, and whether to
  show its price, running costs, and efficiency; nothing is listed by default, and
  the owner's name is shown only while their profile is public
- A vehicle's page shows its stats: running costs in total, per year, per mile or
  km and by category; average, best, worst and latest efficiency; and how much
  was logged
- Fuel efficiency no longer needs a typed distance: without one, it's worked out
  from the odometers. Fuel entries note whether the tank was filled up, and a
  partial fill-up counts toward the next full one, so it can't skew efficiency.
  They can also note that a fill-up before them wasn't logged, which leaves that
  tank out, and estimate how many were missed. An unusually high or low efficiency
  is flagged until you fix it or say it's right. Plug-in hybrids still need a typed
  distance
- Expense categories are picked from a list too, like Maintenance, Insurance or
  Parking & tolls, and move over the same way gear categories did. In the API,
  an expense's `category` is now one of the list's keys, and responses add
  `category_name`
- Vehicles can note their year, make, model and trim, on the website, in the API
  and in data files. Their name is now an optional nickname; without one, they're
  named by those details
- Gear categories are picked from a list, like Vehicle, Electronics or Household,
  instead of typed. Existing categories move to the closest one; any that don't
  fit become Other, with the old text kept in the notes. In the API, `category`
  is now one of the list's keys, and responses add `category_name`
- Readings of vehicles and their parts can note the odometer, in your units
- `bin/backup-drill` proves the off-site backups work in one command: it restores
  the latest one, checks it, compares it with the live database and deletes it
- Public profiles: pick a display name and username in Settings and turn your
  profile on, then choose which gear to show at `/u/<username>`, each with or
  without its costs. Everything is private by default, and private profiles
  look the same as ones that don't exist
- A People page at `/u` lists every public profile, linked from every page
- Import a downloaded data file into a new account from Settings, converted to
  your units; a file with any problem imports nothing, and an account that
  already has gear can't import, so nothing gets copied twice

## [0.2.0] - 2026-11-15

Ready to host.

- Delete your account, or download all your data as a JSON file, from Settings
- A privacy page, linked from every page
- Production setup: a Docker image deployed with Kamal, with HTTPS, durable
  background jobs for email, and rate limits that survive restarts
- Off-site backups with Litestream, kept 7 days; the server's own pre-update
  backups are also deleted after 7 days
- A hosting guide (`docs/hosting.md`) and a script that locks a new server down

## [0.1.0] - 2026-11-15

The first version.

- Gear with purchase date, price and seller; components such as tires that count
  toward their parent's cost; total cost and cost per year
- Expenses, readings, and notes on each
- Power sources: manual, gasoline, diesel, propane, electric and plug-in hybrid
- Fuel and energy logs with time used, usage rate (fuel per hour or average watts)
  and efficiency (such as miles per gallon)
- Settings for currency, miles or kilometers, and US gallons, UK gallons or liters;
  each price and expense keeps its own currency
- JSON API for agents and scripts, with read-only or read-and-write tokens
- A demo with sample gear that runs in a GitHub Codespace
- Database backups before each migration
