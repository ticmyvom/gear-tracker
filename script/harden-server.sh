#!/usr/bin/env bash
# Prepares a fresh Ubuntu 24.04 server for Gear Tracker, safely. Run it once,
# as root, from your computer (see docs/hosting.md):
#
#   ssh root@YOUR_SERVER_IP 'bash -s' < script/harden-server.sh
#
# It:
#   - installs updates, Docker, a firewall, fail2ban and automatic security updates
#   - creates the "deploy" user that Kamal connects as, with your SSH key
#   - turns off password logins and root logins over SSH
#
# Before closing your root session, check that `ssh deploy@YOUR_SERVER_IP`
# works in another terminal. After this, root can't log in over SSH.
set -euo pipefail

DEPLOY_USER=deploy

if [[ $EUID -ne 0 ]]; then
  echo "Run this as root." >&2
  exit 1
fi

# Without a key for root, turning off passwords would lock everyone out.
if [[ ! -s /root/.ssh/authorized_keys ]]; then
  echo "Root has no SSH key in /root/.ssh/authorized_keys. Add yours first (most providers do when you create the server). Nothing was changed." >&2
  exit 1
fi

echo "== Installing updates and packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade
apt-get install -y docker.io ufw fail2ban unattended-upgrades
systemctl enable --now docker

echo "== Creating the $DEPLOY_USER user"
# Same SSH key as root, no password. Being in the docker group lets Kamal run
# containers; note that this is as powerful as root on this server.
if ! id -u "$DEPLOY_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
fi
usermod -aG docker "$DEPLOY_USER"
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
install -m 600 -o "$DEPLOY_USER" -g "$DEPLOY_USER" /root/.ssh/authorized_keys "/home/$DEPLOY_USER/.ssh/authorized_keys"

echo "== Locking down SSH: keys only, no root login"
# Files in sshd_config.d are read in order and the first value wins, so this
# 10- file overrides the provider's own (often 50-cloud-init.conf).
cat > /etc/ssh/sshd_config.d/10-gear-tracker.conf <<'CONF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
CONF
sshd -t # stops here, before applying, if the config has a mistake
systemctl reload ssh

echo "== Firewall: only SSH and the website"
# Docker's published ports skip ufw, so only publish what should be public;
# Kamal publishes just 80 and 443, for its proxy.
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "== Blocking repeated failed SSH logins"
systemctl enable --now fail2ban

echo "== Automatic security updates, restarting at 4:00 when needed"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'CONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
CONF
cat > /etc/apt/apt.conf.d/52gear-tracker-upgrades <<'CONF'
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
CONF
systemctl enable --now unattended-upgrades

echo
echo "Done. Now, in a new terminal, check that this works before closing this one:"
echo "  ssh $DEPLOY_USER@$(hostname -I | awk '{print $1}') docker ps"
