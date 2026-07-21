#!/bin/bash
# oc-egress-google.sh — M6 leg 2 (THE PRIMARY): route the engine's google/
# Gemini model calls through Nactor's dummy-token proxy and remove the
# engine-held key. Run AFTER oc-egress-anthropic.sh has held for a bit — this
# is the primary engine model; the rehearsal leg de-risks the pattern.
#
# Requires the Director-issued `credential:google` grant to be live in Nactor
# (Issue the pending request in the Nvoy console first) — preflight refuses
# otherwise. After this leg, the engine holds NO provider keys at all: every
# model call goes credential-less to Nactor, which injects grant-sourced keys.
#
#   1. preflight: reader has loaded `google` from a grant; proxy serves the
#      google models list end-to-end from the engine's container
#   2. backup openclaw.json + openclaw.env
#   3. jq: models.providers.google created with baseUrl → proxy, apiKey →
#      dummy token, and a models array copied from the google/* ids already
#      configured in agents.defaults.model (no new model policy introduced);
#      auth.profiles["google:default"] deleted; GEMINI/GOOGLE env lines
#      stripped from openclaw.env if present
#   4. recreate engine, wait healthy, re-verify the chain
#   5. organic verification: the PRIMARY model exercises immediately in normal
#      operation — watch the log tail printed at the end; auth failures there
#      = run the rollback (restore the two .bak-egress-<stamp> files, recreate)
#   6. any in-script failure → automatic restore + recreate + exit 1
set -eu
STAMP=$(date +%Y%m%d-%H%M%S)
CFG=openclaw-state/.openclaw/openclaw.json
ENVF=openclaw.env
PROXY=http://nactor:8791/api/proxy/google
[ -f "$CFG" ] || { echo "✗ no $CFG (cwd $(pwd))"; exit 1; }
command -v jq >/dev/null || { echo "✗ jq required"; exit 1; }
TOK=$(grep '^NACT_PROXY_TOKEN=' nave.env | head -1 | cut -d= -f2-)
[ -n "$TOK" ] || { echo "✗ NACT_PROXY_TOKEN not in nave.env — run proxy-token-mint.sh first"; exit 1; }
E=$(docker ps -qf name=openclaw | head -1)
[ -n "$E" ] || { echo "✗ engine container not running"; exit 1; }
N=$(docker ps -qf name=nactor | head -1)

echo "== preflight 1: the google credential is grant-sourced in Nactor =="
L=$(docker logs --tail 300 "$N" 2>&1 | grep 'credential-grants: loaded' | tail -1 || true)
echo "  reader last sweep: ${L:-<none>}"
case "$L" in
  *google*) echo "  ✓ google loaded from a grant" ;;
  *) echo "✗ Nactor has not loaded a google grant — Issue the pending credential:google request in the Nvoy console, wait one sweep (≤5 min), re-run"; exit 1 ;;
esac
echo "== preflight 2: proxy chain from the engine's container =="
PF=$(docker exec -e TOK="$TOK" "$E" node -e 'fetch("http://nactor:8791/api/proxy/google/v1beta/models",{headers:{"x-goog-api-key":process.env.TOK}}).then(r=>console.log(r.status)).catch(e=>console.log("ERR "+e.message))' 2>&1 | tail -1)
echo "  engine → proxy → provider: $PF"
[ "$PF" = "200" ] || { echo "✗ preflight failed — proxy not serving google"; exit 1; }

cp "$CFG" "$CFG.bak-egress-$STAMP"
cp "$ENVF" "$ENVF.bak-egress-$STAMP" 2>/dev/null || touch "$ENVF.bak-egress-$STAMP"
tmp=$(mktemp)
jq --arg url "$PROXY" --arg tok "$TOK" '
  # google/* model ids the agent already uses (primary + fallbacks) become the
  # provider entry model list — copied, not invented.
  ([.agents.defaults.model.primary] + (.agents.defaults.model.fallbacks // [])
     | map(select(type == "string" and startswith("google/")))
     | map(sub("^google/"; ""))) as $gm
  | .models.providers.google = { baseUrl: $url, apiKey: $tok, models: $gm }
  | del(.auth.profiles["google:default"])
' "$CFG" > "$tmp" && mv "$tmp" "$CFG" || { echo "✗ jq patch failed"; exit 1; }
# mktemp creates root:600 and the engine runs as uid 1000 — restore ownership
# and a readable mode or the gateway boot-blocks on EACCES (learned run
# 29853598973, the captured failed-boot log).
chown 1000:1000 "$CFG" 2>/dev/null || true
chmod 644 "$CFG"
grep -vE '^(GEMINI_API_KEY|GOOGLE_API_KEY|GOOGLE_GENERATIVE_AI_API_KEY)=' "$ENVF" > "$ENVF.tmp" 2>/dev/null || true
mv "$ENVF.tmp" "$ENVF"; chmod 600 "$ENVF"
echo "✓ patched: google provider → proxy with dummy key; auth profile + any env keys OUT"

docker compose --profile cutover up -d --force-recreate openclaw
echo "waiting for the gateway…"
OK=0
for i in $(seq 1 30); do
  sleep 2
  docker logs --tail 40 "$(docker ps -qf name=openclaw | head -1)" 2>&1 | grep -qiE 'gateway.*ready|http server listening' && { OK=1; break; }
done
E=$(docker ps -qf name=openclaw | head -1)
if [ "$OK" = 1 ] && [ -n "$E" ]; then
  V=$(docker exec -e TOK="$TOK" "$E" node -e 'fetch("http://nactor:8791/api/proxy/google/v1beta/models",{headers:{"x-goog-api-key":process.env.TOK}}).then(r=>console.log(r.status)).catch(e=>console.log("ERR "+e.message))' 2>&1 | tail -1)
  echo "  post-restart chain check: $V"
  [ "$V" = "200" ] || OK=0
fi
# ORGANIC proof — the engine's transport log prints the provider URL per model
# call, and boot always fires an agent run + heartbeat on the primary model.
# Require a real call routed through the proxy AND a 200 response: this is the
# definitive test that the engine's own pathing honors the provider baseUrl
# (the chain check above only proves the proxy works when called directly).
if [ "$OK" = 1 ]; then
  echo "  organic proof: waiting for a live model call routed via the proxy…"
  ORG=0
  for i in $(seq 1 18); do
    sleep 10
    LOGS=$(docker logs --tail 300 "$E" 2>&1)
    if echo "$LOGS" | grep -q 'model-fetch] start .*url=http://nactor:8791/api/proxy/google' \
       && echo "$LOGS" | grep -qE 'model-fetch] response provider=google .*status=200'; then ORG=1; break; fi
  done
  if [ "$ORG" = 1 ]; then
    echo "  ✓ organic model call proxied and answered 200:"
    docker logs --tail 300 "$E" 2>&1 | grep -E 'model-fetch] (start .*nactor:8791|response provider=google)' | tail -2 | sed 's/^/    /'
  else
    echo "  ✗ no proxied model call observed within 3 min"
    OK=0
  fi
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
echo "── engine log tail (watch the next few organic turns for auth errors) ──"
docker logs --tail 20 "$E" 2>&1 | sed 's/^/  /'
echo "✓ google egress CUT OVER — the engine now holds ZERO provider keys; every"
echo "  model call (primary included) rides the dummy token through Nactor,"
echo "  which injects grant-sourced keys. Revocation = rotate the scope in Nvoy."
echo "  Rollback: restore *.bak-egress-$STAMP (config + env), recreate openclaw."
