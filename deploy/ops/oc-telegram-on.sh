#!/usr/bin/env bash
# Enable Telegram on the self-hosted OpenClaw after the cutover (the old instance
# is retired, so single-owner — no double-connect risk). Flips
# channels.telegram.enabled=true in the state config and restarts the container,
# then tails the log for the telegram channel coming up.
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
CFG=$D/openclaw-state/.openclaw/openclaw.json
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }
[ -f "$CFG" ] || { echo "no config at $CFG"; exit 1; }

tmp=$(mktemp)
jq '(if (.channels | type) == "object" and (.channels.telegram | type) == "object"
       then .channels.telegram.enabled = true else . end)' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
echo "channels.telegram.enabled = $(jq -r '.channels.telegram.enabled // "n/a"' "$CFG")"

cd "$D" && docker compose --profile cutover restart openclaw 2>&1 | tail -3
echo "waiting for the gateway + telegram to come up…"
for i in $(seq 1 25); do
  docker logs deploy-openclaw-1 2>&1 | grep -qiE 'http server listening' && break
  sleep 1
done
echo "── openclaw log (channel / telegram / ready lines) ──"
docker logs --tail 60 deploy-openclaw-1 2>&1 | grep -iE 'telegram|channel|sidecar|http server listening' | tail -20
echo "== done — send Luke a Telegram message to confirm he answers =="
