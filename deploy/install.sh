#!/usr/bin/env bash
#
# Reboot-savvy install for the localized OpenSprinkler UI on the Raspberry Pi.
# Idempotent — safe to re-run after a `git pull`. Run on the Pi:
#
#     sudo bash deploy/install.sh
#
# What it sets up (all persist across reboots):
#   - nginx site on :8088 serving this repo's www/ tree (LAN-only, plain HTTP)
#   - a ufw rule allowing :8088 from the LAN (the Pi's default policy is DROP)
#   - nginx enabled on boot
#
# Updating the UI later is just `git pull` in this repo (nginx serves www/
# directly; the JS modules are loaded individually, no build step).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_SRC="$REPO_DIR/deploy/nginx-os-localized-ui.conf"
CONF_DST="/etc/nginx/sites-available/os-localized-ui"
LAN="10.0.0.0/24"
PORT=8088

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo bash deploy/install.sh" >&2
    exit 1
fi

echo "Repo: $REPO_DIR"

# Guard: the nginx conf hard-codes the canonical repo path; refuse if mismatched
EXPECTED="/home/pi/github/opensprinkler-localized-ui"
if [ "$REPO_DIR" != "$EXPECTED" ]; then
    echo "WARNING: repo is at $REPO_DIR but the nginx conf roots at $EXPECTED/www." >&2
    echo "Either clone to $EXPECTED or edit deploy/nginx-os-localized-ui.conf first." >&2
fi

# 1. nginx site (served straight from the repo working tree)
cp "$CONF_SRC" "$CONF_DST"
ln -sf "$CONF_DST" /etc/nginx/sites-enabled/os-localized-ui

# 1b. retire the ad-hoc test config from initial bring-up, if present
rm -f /etc/nginx/sites-enabled/os-ui-test /etc/nginx/sites-available/os-ui-test

# 2. firewall: LAN-only access to the UI port (the Pi's INPUT policy is DROP)
ufw allow from "$LAN" to any port "$PORT" proto tcp comment "os-localized-ui" || true

# 3. ensure nginx starts on boot, validate, and load the new config
systemctl enable nginx >/dev/null 2>&1 || true
nginx -t
systemctl reload nginx

IP="$(hostname -I | awk '{print $1}')"
echo "Installed. Localized UI: http://${IP}:${PORT}/   (LAN only)"
echo "Add controller 10.0.0.17:5000; set 'Use Metric' off and Flow Pulse Rate = 1 gal/pulse."
