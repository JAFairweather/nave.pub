#!/usr/bin/env bash
# Apply the cockpit-subdomain fix: re-patch OpenClaw's config (adds
# cockpit.nave.pub to controlUi.allowedOrigins), restart openclaw to pick it up,
# then validate + reload Caddy for the new cockpit.nave.pub vhost. run-script
# pulls the nave.pub repo first, so the Caddyfile is current.
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
cd "$D"

echo "== 1. re-patch openclaw config (allowedOrigins += cockpit.nave.pub) =="
bash "$D/ops/oc-config-patch.sh" 2>&1 | grep -iE 'allowedOrigins|authMode|bind|telegram' || true

echo "== 2. restart openclaw to pick up allowedOrigins =="
docker compose restart openclaw 2>&1 | tail -2
for i in $(seq 1 25); do docker logs deploy-openclaw-1 2>&1 | grep -qiE 'http server listening' && break; sleep 1; done
docker logs --tail 30 deploy-openclaw-1 2>&1 | grep -iE 'http server listening|telegram.*starting provider' | tail -3

echo "== 3. validate + reload Caddy (new cockpit.nave.pub vhost) =="
docker run --rm -e ACME_EMAIL=x -v "$D/caddy/Caddyfile:/etc/caddy/Caddyfile:ro" \
  caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile 2>&1 | tail -2
docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile \
  && echo "caddy reloaded OK" || echo "caddy reload FAILED"

echo "== 4. probe the new vhost (expect gate 302 with no cookie; cert may take a few s) =="
sleep 3
curl -skS -o /dev/null -w 'cockpit.nave.pub/:  %{http_code}  loc=%{redirect_url}\n' https://cockpit.nave.pub/ || echo "  (cert still provisioning — retry in a moment)"
echo "== done — open https://cockpit.nave.pub (clean-Alby window) =="
