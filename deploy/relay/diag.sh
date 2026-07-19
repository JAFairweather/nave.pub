#!/bin/sh
# One-shot relay/bunker diagnostic. Run on the relay VPS:
#   cd /root/nave.pub && git pull && sh deploy/relay/diag.sh
# Prints one compact block to paste back. Reveals no secrets.
echo "===== NAVE RELAY/BUNKER DIAG ====="
echo "--- containers ---"
docker ps --format '{{.Names}} | {{.Status}} | {{.Ports}}' 2>/dev/null | grep -Ei 'relay|bunker|strfry|caddy|web|server|db|redis' || echo "(docker ps failed)"
echo "--- bunker web on :8080 (local) ---"
curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080 2>&1 || echo "(no answer on 8080 — bunker web not up)"
echo "--- relay public ---"
curl -sS -o /dev/null -w "HTTP %{http_code}\n" https://relay.nave.pub 2>&1 | head -1
echo "--- bunker public ---"
curl -sSI https://bunker.nave.pub 2>&1 | head -3
echo "--- caddy last errors ---"
docker compose -f /root/nave.pub/deploy/relay/docker-compose.yml logs --tail=40 caddy 2>/dev/null | grep -iE 'error|obtain|certificate|tls|502|bunker' | tail -8 || echo "(no caddy log)"
echo "--- bunker compose state ---"
[ -d /root/bunker46 ] && docker compose -f /root/bunker46/docker-compose.yml ps 2>/dev/null | tail -6 || echo "(no /root/bunker46 — setup.sh not run?)"
echo "===== END ====="
