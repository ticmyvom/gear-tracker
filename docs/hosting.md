# Hosting Gear Tracker

How to put Gear Tracker online on a small rented server (a VPS), safely and
cheaply. Follow the steps in order; each ends with a check, so you know it
worked before moving on.

Plan for an afternoon, plus waiting time for DNS (minutes to a few hours).

## What it costs

| What | Where | About |
| --- | --- | --- |
| Domain | Cloudflare Registrar | $10–13 a year for a `.com` or `.dev` |
| Server | A small VPS, e.g. Hetzner, DigitalOcean or Vultr | $4–6 a month |
| Email (password resets) | Resend, free plan | $0 up to 3,000 emails a month |
| Off-site backups | Cloudflare R2, free tier | $0 up to 10 GB |
| HTTPS certificate | Let's Encrypt, through Kamal | $0 |

About **$60–80 a year** in total.

## How it fits together

- **Kamal** (already set up in `config/deploy.yml`) builds the app into a Docker
  image on your computer, sends it to the server over SSH, and starts it behind
  its proxy, which gets and renews the HTTPS certificate.
- The databases live in a Docker volume on the server. **Litestream** copies the
  main one to R2 continuously, keeping 7 days, as the privacy page promises.
- Before every update to the database, the app also saves a copy on the server,
  deleted after 7 days.
- Secrets never go into git or the image. Kamal reads them from your computer
  when you deploy (`.kamal/secrets`) and passes them to the app.

## 1. Accounts and passwords

You'll create accounts at Cloudflare, a VPS provider and Resend.

- Use a **password manager** (e.g. Bitwarden, free) for every password, key and
  token in this guide.
- Turn on **two-factor authentication** on each account. Anyone in these accounts
  could take over the site.
- Save `config/master.key` in the password manager now. It decrypts the app's
  credentials and isn't in git; if you lose it, everyone gets signed out and the
  key has to be replaced.

## 2. Docker on your computer

Kamal builds the image locally. On Pop!_OS or Ubuntu:

    sudo apt install docker.io docker-buildx
    sudo usermod -aG docker $USER

Log out and back in, then check:

    docker run --rm hello-world

Being in the `docker` group is as powerful as `sudo` on your computer; that's
normal for Docker.

**Check the image builds and starts:**

    docker build -t gear-tracker .
    docker run --rm -p 8080:80 -e RAILS_MASTER_KEY=$(cat config/master.key) -e APP_HOST=localhost gear-tracker

Open http://localhost:8080, sign up, and look around. This copy's data is thrown
away when you stop it with Ctrl+C.

## 3. Domain

1. Create a Cloudflare account and buy the domain under **Domain Registration**.
   Cloudflare sells at cost and doesn't mark up renewals.
2. Turn on auto-renew, so the domain can't lapse and be bought by someone else.

The examples below use `yourdomain.com`; use your own. The app goes on a
subdomain, `gear.yourdomain.com`, so the same domain can host other apps later.

## 4. Server

Create the smallest VPS with at least 1 GB of memory (2 GB is more comfortable):

- **Image:** Ubuntu 26.04 LTS.
- **Architecture:** x86 (Intel/AMD). For an ARM server, change `arch` under
  `builder` in `config/deploy.yml` to `arm64`.
- **SSH key:** add yours, and no password. If you don't have one:

      ssh-keygen -t ed25519 -C "gear-tracker deploy"

  Give it a passphrase. Paste the contents of `~/.ssh/id_ed25519.pub` into the
  provider's SSH key field.
- **Location:** near you and your users.

Note the server's IPv4 address. **Check:** `ssh root@YOUR_SERVER_IP` logs you in
without asking for a password (only your key's passphrase).

## 5. Lock the server down

From the project folder on your computer, run the hardening script on the
server. It installs Docker, a firewall (only SSH and web traffic), fail2ban and
automatic security updates, adds swap if the server has none, creates the
`deploy` user Kamal connects as, and turns off password and root logins:

    ssh root@YOUR_SERVER_IP 'bash -s' < script/harden-server.sh

It stops without changing anything if root has no SSH key, so you can't be
locked out. Read it first; it's short and commented.

**Check, in a new terminal, before closing the root one:**

    ssh deploy@YOUR_SERVER_IP docker ps

It should log in and print an empty list of containers. Also check that
`ssh root@YOUR_SERVER_IP` is now refused.

## 6. Point the domain at the server

In Cloudflare, under the domain's **DNS → Records**, add:

| Type | Name | Content | Proxy status |
| --- | --- | --- | --- |
| A | `gear` | your server's IPv4 address | DNS only (grey cloud) |

"DNS only" lets Kamal's proxy get the HTTPS certificate directly. (If you later
turn the orange cloud on, set **SSL/TLS** to **Full (strict)**.)

**Check:** `getent hosts gear.yourdomain.com` prints your server's address. This can
take a few minutes.

## 7. Email for password resets

1. Create a Resend account and add the domain **`mail.yourdomain.com`** under
   **Domains**. A subdomain keeps the main domain's email reputation separate;
   the app sends from `no-reply@mail.yourdomain.com` (`MAIL_FROM` in
   `config/deploy.yml`). Resend's free plan allows one domain, so later apps
   share this one.
2. Add the DNS records Resend shows to Cloudflare. Resend can add them for you
   if you let it connect to Cloudflare.
3. Add a DMARC record so others can't easily send email pretending to be you:

   | Type | Name | Content |
   | --- | --- | --- |
   | TXT | `_dmarc.mail` | `v=DMARC1; p=quarantine;` |

4. Once Resend shows the domain as verified, create an **API key** with
   **Sending access** only, limited to that domain. Save it as `SMTP_PASSWORD`.

## 8. Off-site backups

1. In Cloudflare, open **R2**. Cloudflare may ask for a payment method to turn it
   on; staying under 10 GB is free.
2. Create a bucket, e.g. `gear-tracker-backups`. Keep public access **off**.
3. Under **R2 → Manage API tokens**, create a token with **Object Read & Write**,
   limited to that bucket. Save:
   - the **Access Key ID** as `LITESTREAM_ACCESS_KEY_ID`
   - the **Secret Access Key** as `LITESTREAM_SECRET_ACCESS_KEY`
   - the bucket name as `LITESTREAM_REPLICA_BUCKET`
   - the endpoint, `https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com`, as
     `LITESTREAM_REPLICA_ENDPOINT`

## 9. Secrets on your computer

Kamal reads secrets from your shell when you deploy (see `.kamal/secrets`). Keep
them in a file outside the project, readable only by you:

    mkdir -p ~/.config/gear-tracker
    touch ~/.config/gear-tracker/production.env
    chmod 600 ~/.config/gear-tracker/production.env

Put the values from steps 7 and 8 in it:

    export SMTP_PASSWORD=re_...
    export LITESTREAM_REPLICA_BUCKET=gear-tracker-backups
    export LITESTREAM_REPLICA_ENDPOINT=https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com
    export LITESTREAM_ACCESS_KEY_ID=...
    export LITESTREAM_SECRET_ACCESS_KEY=...

Before each deploy, load them into the terminal you deploy from:

    source ~/.config/gear-tracker/production.env

Keep a copy in your password manager too. Never put the values in the project.

## 10. Configure and deploy

At the top of `config/deploy.yml`, set your server's address, your domain and
the app's subdomain:

    <% server = "YOUR_SERVER_IP" %>
    <% domain = "yourdomain.com" %>
    <% host = "gear.#{domain}" %>

Commit that change. Then, with the secrets loaded:

    bin/ci
    bin/kamal setup

`bin/kamal setup` builds the image, sends it to the server, starts the app
behind the proxy and gets the certificate. It takes several minutes the first
time. Later updates use `bin/kamal deploy` (see step 13).

## 11. Check it works

- [ ] `https://gear.yourdomain.com` loads, with a padlock, and `http://` redirects to it.
- [ ] Sign up, add a gear, and sign out and in again.
- [ ] **Forgot password?** sends an email that arrives, and its link works.
- [ ] `bin/kamal logs` shows requests and no errors.
- [ ] Backups are reaching R2:

      bin/kamal app exec "bundle exec litestream ltx -config config/litestream.yml /rails/storage/production.sqlite3"

  It lists at least one file. Nothing listed means Litestream isn't running;
  check the secrets.

## 12. Prove the backups work

Backups only count once you've restored one. Do this after the first deploy,
then every few months. On your computer, with the secrets loaded:

    bin/backup-drill

It restores the latest backup from R2 into a private temporary folder, checks
the copy isn't damaged, compares each table's row count with the live database,
and deletes the copy, which holds real people's data. It prints only counts and
ends with `PASSED` or `FAILED` and the reason. If the counts differ because
someone used the site that minute, run it again a minute later.

## 13. Updating the site

1. Run `bin/ci`, and fix anything that fails.
2. For a release, follow **Releasing a version** in [CONTRIBUTING.md](../CONTRIBUTING.md) (version,
   changelog, tag).
3. Load the secrets and run `bin/kamal deploy`. If they aren't loaded, the deploy
   stops before changing anything (`.kamal/hooks/pre-deploy`); without them the
   app can't start, since it won't run without its backups.

The database is backed up on the server before any migration runs. If a deploy
goes wrong, `bin/kamal rollback VERSION` returns to an earlier image; versions
are listed by `bin/kamal app containers`.

## 14. Upkeep

**Every month, about 10 minutes:**

- Check GitHub's security alerts for the repository (turn on **Dependabot
  alerts** under Settings → Code security), update gems with `bundle update`,
  run `bin/ci`, and deploy.
- `bin/kamal logs` for repeated errors, and `bin/kamal disk` for disk space
  (look into it above 80%). `bin/kamal users` shows how many people signed up.
- The backup check in step 11.

**Every few months:** the restore drill in step 12.

The server installs security updates by itself and restarts at 4:00 when one
needs it; the app comes back on its own.

## If something goes wrong

**The server is lost or broken.** Create a new server (steps 4–6, pointing DNS at
the new address), deploy with `bin/kamal setup`, then restore the database into
it:

    bin/kamal app exec "bundle exec litestream restore -config config/litestream.yml -o /rails/storage/restored.sqlite3 /rails/storage/production.sqlite3"
    bin/kamal app stop
    bin/kamal app exec "sh -c 'mv storage/restored.sqlite3 storage/production.sqlite3 && rm -f storage/production.sqlite3-wal storage/production.sqlite3-shm'"
    bin/kamal app start

`bin/kamal app exec` runs each command in a new container with the app's
settings and volume, so it works while the app is stopped.

**A secret leaked** (committed, pasted, or a device was lost):

- Resend or R2 key: delete it in their dashboard, create a new one, update
  `production.env`, and `bin/kamal deploy`.
- `config/master.key`: run `bin/rails credentials:edit` after moving the old key
  aside to create a new key and credentials, then deploy. Everyone is signed out.
- Your SSH key: add a new key to `/home/deploy/.ssh/authorized_keys` on the
  server and remove the old one.

**Someone reports a security problem:** see "Reporting a security problem" in
[CONTRIBUTING.md](../CONTRIBUTING.md). Fix it, deploy, then credit them if they'd like.

## Later: a home server instead

Kamal deploys the same way to any Ubuntu machine. For a home server, run it on a
dedicated machine or VM on a separate network from your other devices (a guest
network or VLAN), use `script/harden-server.sh` the same way, and reach it
through a Cloudflare Tunnel instead of opening router ports, which keeps your
home address private. Don't commit a home IP address to `config/deploy.yml` (a
VPS's address is fine, since its DNS record makes it public anyway); the tunnel
means the config doesn't need one.
