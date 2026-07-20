#!/bin/sh
# Fix the bunker front-proxy. The relay-box Caddy was reaching the Bunker46 web
# app through the host's published :8080, which runs through the box's
# docker/nftables firewall and flapped — intermittent 502s and plain-text error
# bodies the browser tried to save as "document.txt". This connects the relay
# Caddy DIRECTLY to the bunker web container over a shared docker network
# (container-to-container), bypassing the host port + firewall entirely.
#
# Run on the relay box:  cd /root/nave.pub && git pull && sh deploy/relay/fix-bunker-proxy.sh
#
# Non-destructive: uses `docker network connect` (additive), so Bunker46's own
# networking (web -> server/db/redis) is left completely untouched.
set -e
echo "== bunker front-proxy fix =="

# 1) Shared network (idempotent).
docker network create naveedge 2>/dev/null && echo "  created naveedge" || echo "  naveedge already exists"

# 2) Attach the bunker web container to it — additive, keeps its existing nets.
if docker network connect naveedge bunker46-web-1 2>/dev/null; then
  echo "  attached bunker46-web-1 to naveedge"
else
  echo "  bunker46-web-1 already on naveedge (or not found — check 'docker ps')"
fi

# 3) Recreate the relay Caddy so it joins naveedge and loads the new Caddyfile
#    (bunker.nave.pub -> bunker46-web-1:8080).
( cd /root/nave.pub/deploy/relay && docker compose up -d )

# 4) Prove it from the box (hits the front Caddy locally over TLS).
sleep 3
echo "== test: front Caddy -> bunker web =="
curl -sSI --max-time 8 https://bunker.nave.pub/ --resolve bunker.nave.pub:443:127.0.0.1 | head -4 \
  || echo "  (still failing — send me the output above)"
echo "== done — expect: HTTP/2 200 + content-type: text/html =="
