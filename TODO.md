# To do

## Features
- [ ] Mark gear as sold or retired, so cost per year stops falling after you let it go
- [ ] Show the latest value of each reading, and filter reading history (e.g. one tire's pressure)

## Before deploying
- [ ] Buy a domain
- [ ] Choose a host and put the app online
- [ ] Set up Resend for password reset email (https://resend.com/setup.md)
  - Use a subdomain, e.g. `mail.yourdomain.com`
  - Keep the Rails mailer and send over SMTP
  - Use a sending-only key, stored in Rails credentials
  - Set the real host and `from` address in `config/environments/production.rb` and `app/mailers/application_mailer.rb`
- [ ] Give the queue a durable backend, since emails queued in the web process are lost on restart
