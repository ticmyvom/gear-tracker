# Changelog

Notable changes to Gear Tracker. Versions follow [Semantic Versioning](https://semver.org/):
a **patch** release fixes bugs, a **minor** release adds features, and a **major**
release changes something users or API clients rely on. Until 1.0.0, the app isn't
publicly hosted yet.

The API has its own version in its path (`/api/v1`), which changes only when the API
changes in a way that breaks existing clients.

## [Unreleased]

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
