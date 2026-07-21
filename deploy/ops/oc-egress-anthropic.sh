#!/bin/bash
# oc-egress-anthropic.sh — M6 leg 1 (rehearsal, fallback-tier provider), v3.
#
# v3 design, from the engine's documented auth precedence (learned across runs
# 29853057307/29853598973/29855970067): for BUILTIN provider ids the engine
# resolves auth from its AUTH PROFILES / SecretRef store — a provider-entry
# apiKey does NOT win, and deleting the profile breaks resolution
# (auth-profile-failure → unauthenticated calls). So v3 inverts the approach:
#
#   • auth.profiles stay UNTOUCHED — routing changes, auth resolution doesn't
#   • models.providers.anthropic gains ONLY baseUrl → the proxy (docs-blessed
#     "narrow request setting" for a builtin; native dialect + headers kept)
#   • the profile's STORED SECRET is replaced with the dummy token via the
#     engine's own CLI (models auth paste-api-key --profile-id anthropic:default)
#   • ANTHROPIC_API_KEY leaves openclaw.env (no env-resolved auth path either)
#
# After this, the engine authenticates with a worthless value over a proxied
# route; Nactor injects the grant-sourced real key. The real key's only homes:
# the Nvoy grant (durable) and Nactor RAM (runtime).
#
# ROLLBACK NOTE (the one asymmetry): the store swap is not auto-reversible —
# the real key is deliberately no longer on the box. The script's auto-restore
# reverts ROUTING (config + env backups); if it fires after the swap, the
# engine is direct-to-provider with a dummy key for THIS provider until either
# the cutover is re-run fixed, or the Director re-pastes the real key from
# Bitwarden (printf KEY | docker exec -i <engine> node openclaw.mjs models
# auth paste-api-key --provider anthropic --profile-id anthropic:default).
# Fallback-tier provider ⇒ Luke stays functional on the primary throughout.
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

echo "== preflight: proxy chain from the ENGINE's network position =="
PF=$(docker exec -e TOK="$TOK" "$E" node -e 'fetch("http://nactor:8791/api/proxy/anthropic/v1/models",{headers:{"x-api-key":process.env.TOK}}).then(r=>console.log(r.status)).catch(e=>console.log("ERR "+e.message))' 2>&1 | tail -1)
echo "  engine → proxy → provider: $PF"
[ "$PF" = "200" ] || { echo "✗ preflight failed — proxy not serving anthropic"; exit 1; }

cp "$CFG" "$CFG.bak-egress-$STAMP"
cp "$ENVF" "$ENVF.bak-egress-$STAMP" 2>/dev/null || touch "$ENVF.bak-egress-$STAMP"

echo "== 1. route: baseUrl-only override on the builtin provider =="
tmp=$(mktemp)
jq --arg url "$PROXY" '
  .models.providers.anthropic = ((.models.providers.anthropic // {}) + { baseUrl: $url })
' "$CFG" > "$tmp" && mv "$tmp" "$CFG" || { echo "✗ jq patch failed"; exit 1; }
chown 1000:1000 "$CFG" 2>/dev/null || true
chmod 644 "$CFG"

echo "== 2. auth: swap the profile's stored secret to the dummy (engine CLI) =="
if printf '%s\n' "$TOK" | docker exec -i "$E" node openclaw.mjs models auth paste-api-key --provider anthropic --profile-id anthropic:default >/dev/null 2>&1; then
  echo "  ✓ anthropic:default now holds the dummy token (store write; value never logged)"
else
  echo "✗ profile swap failed — restoring routing, nothing else changed"
  mv "$CFG.bak-egress-$STAMP" "$CFG"; chown 1000:1000 "$CFG" 2>/dev/null || true; chmod 644 "$CFG"
  rm -f "$ENVF.bak-egress-$STAMP"
  exit 1
fi

echo "== 3. env: retire the engine-held key =="
grep -vE '^ANTHROPIC_API_KEY=' "$ENVF" > "$ENVF.tmp" 2>/dev/null || true
mv "$ENVF.tmp" "$ENVF"; chmod 600 "$ENVF"

echo "== 4. recreate + verify =="
docker compose --profile cutover up -d --force-recreate openclaw
OK=0
for i in $(seq 1 30); do
  sleep 2
  docker logs --tail 40 "$(docker ps -qf name=openclaw | head -1)" 2>&1 | grep -qiE 'gateway.*ready|http server listening' && { OK=1; break; }
done
E=$(docker ps -qf name=openclaw | head -1)
if [ "$OK" = 1 ]; then
  if docker logs --tail 200 "$E" 2>&1 | grep -q 'auth-profile-failure'; then
    echo "  ✗ auth-profile-failure in boot log — resolution broke"
    OK=0
  else
    echo "  ✓ no auth-profile-failure — profile resolution intact"
  fi
fi
if [ "$OK" = 1 ]; then
  V=$(docker exec -e TOK="$TOK" "$E" node -e 'fetch("http://nactor:8791/api/proxy/anthropic/v1/models",{headers:{"x-api-key":process.env.TOK}}).then(r=>console.log(r.status)).catch(e=>console.log("ERR "+e.message))' 2>&1 | tail -1)
  echo "  post-restart chain check: $V"
  [ "$V" = "200" ] || OK=0
fi
if [ "$OK" != 1 ]; then
  echo "── failed-boot engine log (captured before restore) ──"
  docker logs --tail 30 "$(docker ps -aqf name=openclaw | head -1)" 2>&1 | sed 's/^/  /'
  echo "✗ VERIFICATION FAILED — restoring routing (config + env) and recreating."
  echo "  NOTE: the anthropic:default profile now holds the DUMMY token; the real"
  echo "  key lives in the Nvoy grant. Re-run once fixed, or re-paste from"
  echo "  Bitwarden via: printf KEY | docker exec -i <engine> node openclaw.mjs \\"
  echo "    models auth paste-api-key --provider anthropic --profile-id anthropic:default"
  mv "$CFG.bak-egress-$STAMP" "$CFG"
  chown 1000:1000 "$CFG" 2>/dev/null || true; chmod 644 "$CFG"
  mv "$ENVF.bak-egress-$STAMP" "$ENVF"
  docker compose --profile cutover up -d --force-recreate openclaw
  exit 1
fi
echo "── engine log tail ──"
docker logs --tail 15 "$E" 2>&1 | sed 's/^/  /'
echo "✓ anthropic egress CUT OVER (v3) — profile intact, dummy in the store, route"
echo "  via Nactor. The engine holds no real anthropic key; fallback completions"
echo "  now prove proxied egress organically. Backups: *.bak-egress-$STAMP"
