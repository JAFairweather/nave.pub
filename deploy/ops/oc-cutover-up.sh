#!/usr/bin/env bash
# Cutover Steps 2-4 — run AFTER the old instance is stopped in hPanel.
# Snapshot the (now quiescent) state, patch it for trusted-proxy with channels
# OFF, bring up the self-hosted openclaw on the nave network (no published
# port), and confirm Caddy/Nactor can reach it. Telegram gets enabled in a
# later step, after the cockpit is verified.
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
SRC=/docker/openclaw-kajk/data/.openclaw
DST=$D/openclaw-state/.openclaw

echo "== 1. fresh consistent snapshot (old instance stopped) =="
[ -d "$SRC" ] || { echo "live state dir $SRC missing"; exit 1; }
mkdir -p "$DST"
rsync -a --delete --exclude 'npm/' --exclude 'browser/' --exclude 'browsers/' --exclude 'logs/' --exclude '*.log' "$SRC/" "$DST/"
chown -R 1000:1000 "$DST" 2>/dev/null || true
echo "  snapshot: $(du -sh "$DST" | cut -f1)"

echo "== 2. ensure ANTHROPIC_API_KEY in openclaw.env (from Director .env) =="
OUT=$D/openclaw.env; touch "$OUT"; chmod 600 "$OUT"
if ! grep -q '^ANTHROPIC_API_KEY=' "$OUT"; then
  k=$(grep '^ANTHROPIC_API_KEY=' "$D/.env" 2>/dev/null | cut -d= -f2-)
  if [ -n "$k" ]; then printf 'ANTHROPIC_API_KEY=%s\n' "$k" >> "$OUT"; echo "  added ANTHROPIC_API_KEY (from .env, value not shown)"; else echo "  (none in .env — relying on migrated auth store in state)"; fi
else echo "  already present"; fi

echo "== 3. patch state config: trusted-proxy, channels OFF, clear break-glass flags =="
bash "$D/ops/oc-config-patch.sh"

echo "== 4. bring up self-hosted openclaw (nave net, no published port) =="
cd "$D" && docker compose --profile cutover up -d openclaw 2>&1 | tail -6

echo "== 5. wait for the gateway to report ready =="
for i in $(seq 1 25); do
  docker logs deploy-openclaw-1 2>&1 | grep -qiE 'http server listening' && { echo "  ready seen"; break; }
  R=$(docker inspect -f '{{.State.Running}}' deploy-openclaw-1 2>/dev/null)
  [ "$R" = "true" ] || { echo "  container not running (exit $(docker inspect -f '{{.State.ExitCode}}' deploy-openclaw-1 2>/dev/null))"; break; }
  sleep 1
done
echo "── openclaw log (tail) ──"; docker logs --tail 22 deploy-openclaw-1 2>&1
echo "── reachability from the nave network (Nactor → openclaw:57419) ──"
docker compose exec -T nactor node -e "require('net').connect(57419,'openclaw').on('connect',()=>{console.log('  REACHABLE: openclaw:57419 is up on the nave net');process.exit(0)}).on('error',e=>{console.log('  NOT reachable ('+e.code+') — check gateway.bind');process.exit(1)})" 2>&1 || true
echo "== done — if reachable + ready, next is the Caddy repoint =="
