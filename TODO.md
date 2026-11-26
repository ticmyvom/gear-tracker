# To do

## Commands to run now and then
- Monthly, or after a burst of deploys: `bin/kamal server exec "df -h /"` shows how full the server's disk is. Look into it if Use% is over 80% (36% on 2026-11-24)

## Features
- [x] After adding, changing or deleting an expense, fuel entry or reading, go back to its section of the gear page instead of the top
- [ ] A "Save and add another" button, for adding several of the same kind in a row
- [ ] Try the API token section of Settings in a real browser: create a token, copy it, check it works with `curl`, then revoke it (so far only tested by automated tests)
- [ ] Mark gear as sold or retired, so cost per year stops falling after you let it go
- [ ] Show the latest value of each reading, and filter reading history (e.g. one tire's pressure)
- [x] A page listing all public profiles, each name in a box with a transparent border
- [ ] A support page; supporters' names get a colored border with the year attached, like a license plate registration sticker

## Data
- [ ] Regularly copy `storage/backups` off this machine (external drive or cloud), since a disk failure would take the backups too
- [ ] Remove old files from `storage/backups` now and then, since nothing deletes them automatically

## After putting the code on GitHub
- [ ] Check that the demo Codespace resets when it restarts (opening and signing in work)

## Before deploying
- [ ] Turn on private vulnerability reporting in the GitHub repository's settings, so the README's "Report a vulnerability" link works
- [x] Follow `docs/hosting.md`: buy the domain, rent and harden the VPS, set up Resend and the R2 backup bucket, then deploy
- [x] After the first deploy, restore a backup once to prove backups work (2026-11-20; repeat every few months)
- [ ] When running more than one server, move background jobs to their own server (see `SOLID_QUEUE_IN_PUMA` in `config/deploy.yml`)
