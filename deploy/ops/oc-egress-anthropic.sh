#!/bin/bash
# oc-egress-anthropic.sh — M6 leg 1 (the rehearsal, fallback-tier provider):
# route the engine's anthropic model calls through Nactor's dummy-token proxy
# and remove the engine-held key. After this, the engine holds NO anthropic
# credential — any successful anthropic completion is proof of proxied egress.
#
# Per the oc-config-patch.sh lesson: touches ONLY the anthropic provider entry
# + auth profile + env line. No steady-state toggles.
#
#   1. preflight: proxy live (403/200 probe), engine up, config present
#   2. backup openclaw.json + openclaw.env (.bak-egress-<stamp>)
#   3. jq: models.providers.anthropic gains baseUrl → nactor proxy + apiKey →
#      the dummy token (models array preserved); auth.profiles["anthropic:default"]
#      deleted (no second key path); ANTHROPIC_API_KEY stripped from openclaw.env
#   4. recreate the engine, wait healthy
#   5. verify the full chain FROM the engine's container: proxy models-list
#      returns 200 with the dummy token; engine log tail shown for errors
#   6. any failure → restore both backups, recreate, exit 1
#
# Rollback later: restore the two .bak-egress-<stamp> files + recreate.
set -eu
STAMP=$(date +%Y%m%d-%H%M%S)
CFG=openclaw-state/.openclaw/openclaw.json
ENVF=openclaw.env
PROXY=http://nactor:8791/api/proxy/anthropic
[ -f "$CFG" ] || { echo "✗ no $CFG (cwd $(pwd))"; exit 1; }
command -v jq >/dev/null || { echo "✗ jq required"; exit 1; }
TOK=$(grep '^NACT_PROXY_TOKEN=' nave.env | head -1 | cut -d= -f2-)
[ -n "$TOK" ] || { echo "✗ NACT_PROXY_TOKEN not in nave.env — run proxy-token-mint.sh first"; exit 1; }
E=$(docker ps -qf name=openclaw | head -1)
[ -n "$E" ] || { echo "✗ engine container not running"; exit 1; }
N=$(docker ps -qf name=nactor | head -1)

echo "== preflight: proxy chain from the ENGINE's network position =="
PF=$(docker exec -e TOK="$TOK" "$E" node -e 'fetch("http://nactor:8791/api/proxy/anthropic/v1/models",{headers:{"x-api-key":process.env.TOK}}).then(r=>console.log(r.status)).catch(e=>console.log("ERR "+e.message))' 2>&1 | tail -1)
echo "  engine → proxy → provider: $PF"
[ "$PF" = "200" ] || { echo "✗ preflight failed — proxy not serving anthropic"; exit 1; }

cp "$CFG" "$CFG.bak-egress-$STAMP"
cp "$ENVF" "$ENVF.bak-egress-$STAMP" 2>/dev/null || touch "$ENVF.bak-egress-$STAMP"
tmp=$(mktemp)
jq --arg url "$PROXY" --arg tok "$TOK" '
  .models.providers.anthropic = ((.models.providers.anthropic // {})
      + { baseUrl: $url, apiKey: $tok })
  | del(.auth.profiles["anthropic:default"])
' "$CFG" > "$tmp" && mv "$tmp" "$CFG" || { echo "✗ jq patch failed"; exit 1; }
# mktemp creates root:600 and the engine runs as uid 1000 — restore ownership
# and a readable mode or the gateway boot-blocks on EACCES (learned run
# 29853598973, the captured failed-boot log).
chown 1000:1000 "$CFG" 2>/dev/null || true
chmod 644 "$CFG"
grep -vE '^ANTHROPIC_API_KEY=' "$ENVF" > "$ENVF.tmp" 2>/dev/null || true
mv "$ENVF.tmp" "$ENVF"; chmod 600 "$ENVF"
echo "✓ patched: provider → proxy, dummy key in; auth profile + env key OUT"

docker compose --profile cutover up -d --force-recreate openclaw
echo "waiting for the gateway…"
OK=0
for i in $(seq 1 30); do
  sleep 2
  docker logs --tail 40 "$(docker ps -qf name=openclaw | head -1)" 2>&1 | grep -qiE 'gateway.*ready|http server listening' && { OK=1; break; }
done
E=$(docker ps -qf name=openclaw | head -1)
if [ "$OK" = 1 ] && [ -n "$E" ]; then
  V=$(docker exec -e TOK="$TOK" "$E" node -e 'fetch("http://nactor:8791/api/proxy/anthropic/v1/models",{headers:{"x-api-key":process.env.TOK}}).then(r=>console.log(r.status)).catch(e=>console.log("ERR "+e.message))' 2>&1 | tail -1)
  echo "  post-restart chain check: $V"
  [ "$V" = "200" ] || OK=0
fi
if [ "$OK" != 1 ]; then
  echo "── failed-boot engine log (captured before restore) ──"
  docker logs --tail 30 "$(docker ps -aqf name=openclaw | head -1)" 2>&1 | sed 's/^/  /'
  echo "✗ VERIFICATION FAILED — restoring config + env and recreating"
  mv "$CFG.bak-egress-$STAMP" "$CFG"
  chown 1000:1000 "$CFG" 2>/dev/null || true; chmod 644 "$CFG"
  mv "$ENVF.bak-egress-$STAMP" "$ENVF"
  docker compose --profile cutover up -d --force-recreate openclaw
  echo "restored. Nothing cut over."
  exit 1
fi
echo "── engine log tail ──"
docker logs --tail 15 "$E" 2>&1 | sed 's/^/  /'
echo "✓ anthropic egress CUT OVER — engine holds no anthropic key; completions on"
echo "  anthropic fallback models now prove proxied egress. Backups: *.bak-egress-$STAMP"
