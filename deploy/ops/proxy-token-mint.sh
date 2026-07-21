#!/bin/bash
# proxy-token-mint.sh — M6 step 0: mint NACT_PROXY_TOKEN and enable Nactor's
# egress proxy (nact docs/migration-status-2026-07.md §5 M6).
#
# The token is C-class infra (never remotely rotated) — SOPS-only is its
# sanctioned home (migration.md class C). This script:
#   1. generates a 64-hex token (skips minting if the bundle already has one)
#   2. adds it to secrets/nave.enc.env via the .sops.yaml ritual (backup kept)
#   3. adds it to the live nave.env + luke.env; STRIPS it from the consumer
#      envs (sites.sh strips it on future deploys too — same PR)
#   4. recreates nactor and verifies end-to-end: without the token the proxy
#      answers 403; WITH it, /api/proxy/anthropic/v1/models returns 200 from
#      the real provider (CREDS.anthropic is grant-sourced)
#   5. emits the new bundle as base64 (ciphertext) for the repo-sync PR
#
# The token value never leaves the box and is never printed.
set -eu
STAMP=$(date +%Y%m%d-%H%M%S)
[ -f secrets/nave.enc.env ] || { echo "✗ secrets/nave.enc.env not found (cwd $(pwd))"; exit 1; }
command -v sops >/dev/null || { echo "✗ sops not installed"; exit 1; }

cd secrets
trap 'rm -f nave.plain.tmp nave.env.tmp.env' EXIT
sops --input-type dotenv --output-type dotenv -d nave.enc.env > nave.plain.tmp
chmod 600 nave.plain.tmp
if grep -q '^NACT_PROXY_TOKEN=' nave.plain.tmp; then
  echo "· bundle already carries NACT_PROXY_TOKEN — reusing (no rotation)"
  TOK=$(grep '^NACT_PROXY_TOKEN=' nave.plain.tmp | head -1 | cut -d= -f2-)
  cd ..
else
  TOK=$(head -c32 /dev/urandom | od -An -tx1 | tr -d ' \n')
  cp nave.enc.env "nave.enc.env.bak-$STAMP"
  { cat nave.plain.tmp; printf 'NACT_PROXY_TOKEN=%s\n' "$TOK"; } > nave.env.tmp.env
  chmod 600 nave.env.tmp.env
  sops --input-type dotenv --output-type dotenv -e nave.env.tmp.env > nave.enc.env.new
  mv nave.enc.env.new nave.enc.env
  echo "✓ NACT_PROXY_TOKEN minted into secrets/nave.enc.env (backup: nave.enc.env.bak-$STAMP)"
  cd ..
  for f in nave.env luke.env; do
    [ -f "$f" ] || continue
    { grep -vE '^NACT_PROXY_TOKEN=' "$f"; printf 'NACT_PROXY_TOKEN=%s\n' "$TOK"; } > "$f.tmp"
    chmod 600 "$f.tmp"; mv "$f.tmp" "$f"
  done
  echo "✓ live nave.env + luke.env updated"
fi
# Consumers never get the egress token (least privilege; sites.sh also strips
# it on regeneration as of this PR).
for f in nave-consumer.env luke-consumer.env; do
  [ -f "$f" ] || continue
  grep -vE '^NACT_PROXY_TOKEN=' "$f" > "$f.tmp"; chmod 600 "$f.tmp"; mv "$f.tmp" "$f"
done

docker compose up -d --force-recreate nactor
N=$(docker ps -qf name=nactor | head -1)
sleep 3
echo "verify: no token → expect 403"
NOTOK=$(docker exec "$N" node -e 'fetch("http://127.0.0.1:8791/api/proxy/anthropic/v1/models").then(r=>console.log(r.status))' 2>&1 | tail -1)
echo "  status: $NOTOK"
echo "verify: with token → expect 200 from the real provider (grant-sourced key injected)"
WITHTOK=$(docker exec -e TOK="$TOK" "$N" node -e 'fetch("http://127.0.0.1:8791/api/proxy/anthropic/v1/models",{headers:{"x-api-key":process.env.TOK}}).then(r=>console.log(r.status))' 2>&1 | tail -1)
echo "  status: $WITHTOK"
[ "$NOTOK" = "403" ] && [ "$WITHTOK" = "200" ] || { echo "✗ proxy verification failed (got $NOTOK / $WITHTOK)"; exit 1; }
echo "✓ egress proxy LIVE — dummy-token gate up, real key injected from RAM"

echo "== BEGIN nave.enc.env base64 (lift into deploy/secrets/nave.enc.env via PR) =="
base64 -w0 secrets/nave.enc.env
echo
echo "== END nave.enc.env base64 =="
