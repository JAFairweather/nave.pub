#!/usr/bin/env bash
# Recreate nactor so it picks up the CURRENT nactor.env (editing the env file
# does NOT reload a running container), then run the calendar verify. Use this
# after changing any GOOGLE_OAUTH_* value. Never prints the token or events.
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
cd "$D"
echo "▸ recreating nactor to load the current env…"
docker compose up -d --force-recreate --no-deps nactor >/dev/null 2>&1 && echo "  recreated" || echo "  recreate failed"
# Give it a moment to boot + reload creds.
for i in 1 2 3 4 5 6 7 8 9 10; do
  H="$(docker compose exec -T nactor node -e "fetch('http://localhost:8791/api/health').then(r=>r.json()).then(j=>process.stdout.write('ok:'+j.credentials)).catch(()=>process.stdout.write('down'))" 2>/dev/null || echo down)"
  case "$H" in ok:*) echo "  nactor healthy ($H)"; break;; esac
  sleep 1
done
echo
bash "$D/ops/gcal-verify.sh"
