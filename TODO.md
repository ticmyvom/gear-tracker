# To do

## Features
- [ ] Try the API token section of Settings in a real browser: create a token, copy it, check it works with `curl`, then revoke it (so far only tested by automated tests)
- [ ] Mark gear as sold or retired, so cost per year stops falling after you let it go
- [ ] Show the latest value of each reading, and filter reading history (e.g. one tire's pressure)

## Data
- [ ] Regularly copy `storage/backups` off this machine (external drive or cloud), since a disk failure would take the backups too
- [ ] Remove old files from `storage/backups` now and then, since nothing deletes them automatically

## After putting the code on GitHub
- [ ] Check that the demo Codespace resets when it restarts (opening and signing in work)

## Before deploying
- [ ] Turn on private vulnerability reporting in the GitHub repository's settings, so the README's "Report a vulnerability" link works
- [ ] Follow `docs/hosting.md`: buy the domain, rent and harden the VPS, set up Resend and the R2 backup bucket, then deploy
- [ ] After the first deploy, restore a backup once to prove backups work
- [ ] When running more than one server, move background jobs to their own server (see `SOLID_QUEUE_IN_PUMA` in `config/deploy.yml`)
