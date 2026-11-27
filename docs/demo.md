# Try the demo

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/ticmyvom/gear-tracker?devcontainer_path=.devcontainer/demo/devcontainer.json&quickstart=1)

The button starts Gear Tracker in your own GitHub Codespace, free with a GitHub
account. After a minute or two the app opens in a new tab with sample gear:

- a **2020 Toyota Prius Prime** plug-in hybrid at 150,000 miles, with gas fill-ups
  (about 54 mpg) and charging sessions
- a **heated mattress pad** that averaged 32 W over a 9-hour night
- a bicycle, a rain jacket, and the Prius's tires as a component

Sign in as `demo@example.com` with password `demo-password` (the sign-in page fills
them in). Add, change and delete anything: the demo resets every time the Codespace
starts, and your changes never leave your Codespace. Delete the Codespace from
[github.com/codespaces](https://github.com/codespaces) when you're done.

A Codespace keeps the version it was created with; the page footer shows which one.
To try a newer version, delete the old Codespace and create a new one.

To run the demo on your own computer, use a separate database so your own data isn't
wiped:

    export GEAR_TRACKER_DEMO=1 DATABASE_URL=sqlite3:storage/demo.sqlite3
    bin/rails demo:reset
    bin/rails server

`demo:reset` wipes the database it's pointed at, so it refuses to run without
`GEAR_TRACKER_DEMO=1`, and never runs in production. The demo data is in `lib/demo.rb`.
