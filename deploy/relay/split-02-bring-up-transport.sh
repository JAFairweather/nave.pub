#!/bin/sh
# nave.pub#130 split, step 2 of 5 — bring up transport.nave.pub, the dedicated
# NIP-46 transport relay. Only stands up the new strfry-transport service and
# recreates Caddy to load its vhost; does NOT touch the strfry service or its
# write policy. Nothing signs through transport.nave.pub yet — that's step 3.
#
# PREREQ (only you can do this): point transport.nave.pub's DNS at this box —
# same IP as relay.nave.pub / bunker.nave.pub. Without it Caddy can't obtain a
# TLS cert and will keep retrying against Let's Encrypt.
#
# Run as root on the relay box, from the repo:
#   cd /root/nave.pub && git pull && sh deploy/relay/split-02-bring-up-transport.sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

echo "--- checking DNS for transport.nave.pub ---"
RESOLVED=$(getent hosts transport.nave.pub 2>/dev/null | awk '{print $1}' | head -1 || true)
RELAY_IP=$(getent hosts relay.nave.pub 2>/dev/null | awk '{print $1}' | head -1 || true)
if [ -z "$RESOLVED" ]; then
  echo "transport.nave.pub does not resolve yet. Point its DNS at this box (relay.nave.pub currently resolves to: ${RELAY_IP:-unknown}) and re-run." >&2
  exit 1
fi
if [ -n "$RELAY_IP" ] && [ "$RESOLVED" != "$RELAY_IP" ]; then
  echo "WARNING: transport.nave.pub -> $RESOLVED, relay.nave.pub -> $RELAY_IP. Expected the same box. Continuing, but check this." >&2
fi

echo "--- bringing up strfry-transport (new service only; strfry/allowlist untouched) ---"
docker compose up -d --build strfry-transport

echo "--- recreating caddy so it loads the new vhost (bind-mounted Caddyfile changes need this) ---"
docker compose up -d --force-recreate caddy

sleep 3
echo "--- verifying transport.nave.pub answers NIP-11 ---"
curl -sS https://transport.nave.pub -H 'Accept: application/nostr+json'
echo
echo "OK if that printed a JSON doc naming the transport relay. A TLS/502 error usually means Caddy is still obtaining its cert — retry in a minute, or check: docker compose logs -f caddy"
