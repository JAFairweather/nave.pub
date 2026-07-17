#!/usr/bin/env bash
# Validate + hot-reload Caddy after a Caddyfile change (run-script pulls the
# nave.pub repo first, so the box's ./caddy/Caddyfile is current before reload).
# The caddy container mounts the ./caddy DIRECTORY, so it reads the file live.
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
cd "$D"
echo "-- cockpit upstream now --"; grep -A4 '@cockpit' caddy/Caddyfile | grep -i reverse_proxy
echo "-- validate --"
docker run --rm -e ACME_EMAIL=x -v "$D/caddy/Caddyfile:/etc/caddy/Caddyfile:ro" \
  caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile 2>&1 | tail -3
echo "-- reload --"
docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile \
  && echo "reloaded OK" || echo "reload FAILED"
