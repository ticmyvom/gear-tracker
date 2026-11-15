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
- [ ] Buy a domain
- [ ] Choose a host and put the app online
- [ ] Set up Resend for password reset email (https://resend.com/setup.md)
  - Use a subdomain, e.g. `mail.yourdomain.com`
  - Keep the Rails mailer and send over SMTP
  - Use a sending-only key, stored in Rails credentials
  - Set the real host and `from` address in `config/environments/production.rb` and `app/mailers/application_mailer.rb`
- [ ] Choose a host with a persistent disk or volume, since many hosts wipe files on deploy, and set the production path in `config/database.yml` to it
- [ ] Run `bin/rails db:migrate` when deploying, not `db:prepare`, or call `db:backup` first, because only `db:migrate` backs up automatically
- [ ] Set up scheduled backups in production, stored away from the server
- [ ] If the app runs on more than one server, give rate limits a shared cache (e.g. Solid Cache), since each server otherwise counts API and sign-in requests separately
- [ ] Give the queue a durable backend, since emails queued in the web process are lost on restart
