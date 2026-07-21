#!/bin/bash
# oc-egress-google.sh — M6 leg 2 (THE PRIMARY), v3. Run AFTER the anthropic
# rehearsal leg has verified — this is the primary engine model.
#
# Same v3 design as the rehearsal (see oc-egress-anthropic.sh header for the
# full rationale): auth profile UNTOUCHED, baseUrl-only routing override on
# the builtin provider (native google-generative-ai dialect + x-goog-api-key
# headers preserved), the profile's stored secret swapped to the dummy token
# via the engine's own CLI, and any GEMINI/GOOGLE env keys retired. Preflight
# refuses until Nactor's reader holds the Director-issued credential:google
# grant. Verification is the decisive ORGANIC gate: the engine's transport
# log must show a live model call to the proxy answered 200 — boot fires an
# agent run + heartbeat on the primary model, so a healthy cutover proves
# itself within seconds.
#
# ROLLBACK NOTE: as with the rehearsal, the store swap is not auto-reversible
# (the real key deliberately leaves the box — it lives in the Nvoy grant).
# Auto-restore reverts routing only; recovery from a post-swap failure is
# re-running fixed, or the Director re-pasting from Bitwarden:
#   printf KEY | docker exec -i <engine> node openclaw.mjs models auth \
#     paste-api-key --provider google --profile-id google:default
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
  *) echo "✗ Nactor has not loaded a google grant — issue credential:google in the Nvoy console, wait one sweep (≤5 min), re-run"; exit 1 ;;
esac
echo "== preflight 2: proxy chain from the engine's container =="
PF=$(docker exec -e TOK="$TOK" "$E" node -e 'fetch("http://nactor:8791/api/proxy/google/v1beta/models",{headers:{"x-goog-api-key":process.env.TOK}}).then(r=>console.log(r.status)).catch(e=>console.log("ERR "+e.message))' 2>&1 | tail -1)
echo "  engine → proxy → provider: $PF"
[ "$PF" = "200" ] || { echo "✗ preflight failed — proxy not serving google"; exit 1; }

cp "$CFG" "$CFG.bak-egress-$STAMP"
cp "$ENVF" "$ENVF.bak-egress-$STAMP" 2>/dev/null || touch "$ENVF.bak-egress-$STAMP"

echo "== 1. route: baseUrl-only override on the builtin provider =="
tmp=$(mktemp)
jq --arg url "$PROXY" '
  # api pinned explicitly: the google provider comes from a PLUGIN, and any
  # models.providers.google entry shadows it with a generic custom provider
  # whose default dialect is openai-completions (Bearer auth, /chat/completions
  # — the 403s of runs 29855970067 + 29857432037). Pinning the native dialect
  # keeps x-goog-api-key auth and /v1beta paths, which is what the proxy speaks.
  .models.providers.google = ((.models.providers.google // {})
      + { baseUrl: $url, api: "google-generative-ai" })
' "$CFG" > "$tmp" && mv "$tmp" "$CFG" || { echo "✗ jq patch failed"; exit 1; }
chown 1000:1000 "$CFG" 2>/dev/null || true
chmod 644 "$CFG"

echo "== 2. auth: swap the profile's stored secret to the dummy (engine CLI) =="
if printf '%s\n' "$TOK" | docker exec -i "$E" node openclaw.mjs models auth paste-api-key --provider google --profile-id google:default >/dev/null 2>&1; then
  echo "  ✓ google:default now holds the dummy token (store write; value never logged)"
else
  echo "✗ profile swap failed — restoring routing, nothing else changed"
  mv "$CFG.bak-egress-$STAMP" "$CFG"; chown 1000:1000 "$CFG" 2>/dev/null || true; chmod 644 "$CFG"
  rm -f "$ENVF.bak-egress-$STAMP"
  exit 1
fi

echo "== 3. env: retire any engine-held google keys =="
grep -vE '^(GEMINI_API_KEY|GOOGLE_API_KEY|GOOGLE_GENERATIVE_AI_API_KEY)=' "$ENVF" > "$ENVF.tmp" 2>/dev/null || true
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
  V=$(docker exec -e TOK="$TOK" "$E" node -e 'fetch("http://nactor:8791/api/proxy/google/v1beta/models",{headers:{"x-goog-api-key":process.env.TOK}}).then(r=>console.log(r.status)).catch(e=>console.log("ERR "+e.message))' 2>&1 | tail -1)
  echo "  post-restart chain check: $V"
  [ "$V" = "200" ] || OK=0
fi
# ORGANIC proof — the decisive gate: a real model call, routed via the proxy,
# answered 200, in the engine's own transport log. Native dialect is preserved
# in v3, so the call shape is google-generative-ai against the proxied baseUrl.
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
  echo "✗ VERIFICATION FAILED — restoring routing (config + env) and recreating."
  echo "  NOTE: the google:default profile now holds the DUMMY token; the real key"
  echo "  lives in the Nvoy grant. Re-run once fixed, or re-paste from Bitwarden:"
  echo "  printf KEY | docker exec -i <engine> node openclaw.mjs models auth \\"
  echo "    paste-api-key --provider google --profile-id google:default"
  mv "$CFG.bak-egress-$STAMP" "$CFG"
  chown 1000:1000 "$CFG" 2>/dev/null || true; chmod 644 "$CFG"
  mv "$ENVF.bak-egress-$STAMP" "$ENVF"
  docker compose --profile cutover up -d --force-recreate openclaw
  exit 1
fi
echo "── engine log tail (watch the next organic turns for auth errors) ──"
docker logs --tail 20 "$E" 2>&1 | sed 's/^/  /'
echo "✓ google egress CUT OVER (v3) — the PRIMARY now rides the dummy token"
echo "  through Nactor with the grant-sourced key injected from RAM. The engine"
echo "  holds ZERO real provider keys. Revocation = rotate the scope in Nvoy."
echo "  Rollback: restore *.bak-egress-$STAMP routing + re-paste key from Bitwarden."
