#!/bin/bash
# retire-brokered-env.sh — M4 close-out: delete the last two brokered
# credentials from the platform env now that they arrive as Nvoy grants
# (nact docs/migration-status-2026-07.md §5 M4). The migration's acceptance
# line: a secret is migrated when the Director-signed scope is its ONLY
# durable home — these env lines are the last other home.
#
# Strips exactly:  TELEGRAM_BOT_TOKEN   (pre-flip approvals bot — retired;
#                                        the granted telegram-nactjaf re-issue
#                                        carries @navenactorbot's token)
#                  ANTHROPIC_API_KEY    (platform copy; grant-sourced value
#                                        overrides it every sweep. The ENGINE's
#                                        own copy in openclaw.env is M6 —
#                                        deliberately untouched here.)
# from:
#   1. secrets/nave.enc.env  (the SOPS source — decrypt → filter → re-encrypt
#      per the ritual documented in secrets/.sops.yaml; ciphertext backup kept)
#   2. the live nave.env + luke.env alias (consumer copies never had them)
# then recreates nactor and VERIFIES: env names gone from the container AND
# the grant reader still loads both credentials from the relays. On failed
# verification it restores the live env files and recreates nactor again.
#
# Prints the NEW nave.enc.env as base64 (ciphertext — safe to log) between
# markers: lift it into deploy/secrets/nave.enc.env in a repo PR promptly —
# until that lands, the box working tree differs from the repo and a redeploy
# would resurrect the lines.
#
# Rollback (either var, any time): re-add the KEY=value line from the
# Bitwarden note via the .sops.yaml edit ritual, redeploy or re-run the env
# regeneration, recreate nactor. The bootstrap-env loader stays wired; a
# grant-sourced value simply overrides it again.
set -eu
cd "$(pwd)"  # run-script guarantees cwd = the deploy dir
STRIP='TELEGRAM_BOT_TOKEN|ANTHROPIC_API_KEY'
STAMP=$(date +%Y%m%d-%H%M%S)

[ -f secrets/nave.enc.env ] || { echo "✗ secrets/nave.enc.env not found (cwd $(pwd))"; exit 1; }
command -v sops >/dev/null || { echo "✗ sops not installed"; exit 1; }
C=$(docker ps -qf name=nactor | head -1)
[ -n "$C" ] || { echo "✗ no nactor container running"; exit 1; }

# --- Preflight: refuse to strip unless the grants are actually serving -------
LOADED=$(docker logs --tail 300 "$C" 2>&1 | grep 'credential-grants: loaded' | tail -1 || true)
echo "reader last sweep: ${LOADED:-<none>}"
case "$LOADED" in
  *telegram-nactjaf*anthropic*|*anthropic*telegram-nactjaf*) echo "✓ preflight: both credentials grant-sourced" ;;
  *) echo "✗ preflight FAILED — reader is not loading telegram-nactjaf + anthropic from grants; aborting with nothing changed"; exit 1 ;;
esac

# --- 1. SOPS source: decrypt → filter → re-encrypt (ciphertext backup kept) --
cd secrets
cp nave.enc.env "nave.enc.env.bak-$STAMP"
trap 'rm -f nave.plain.tmp nave.filtered.tmp' EXIT
sops --input-type dotenv --output-type dotenv -d nave.enc.env > nave.plain.tmp
chmod 600 nave.plain.tmp
grep -vE "^($STRIP)=" nave.plain.tmp > nave.filtered.tmp
chmod 600 nave.filtered.tmp
BEFORE=$(wc -l < nave.plain.tmp); AFTER=$(wc -l < nave.filtered.tmp)
echo "sops bundle: $BEFORE lines → $AFTER (removed $((BEFORE - AFTER)))"
[ "$((BEFORE - AFTER))" -le 2 ] || { echo "✗ would remove more than 2 lines — aborting"; exit 1; }
mv nave.filtered.tmp nave.env.tmp.env   # name must match the .sops.yaml path_regex
sops --input-type dotenv --output-type dotenv -e nave.env.tmp.env > nave.enc.env.new
rm -f nave.env.tmp.env
mv nave.enc.env.new nave.enc.env
echo "✓ secrets/nave.enc.env rewritten (backup: nave.enc.env.bak-$STAMP)"
cd ..

# --- 2. Live env files (what the running compose reads) ----------------------
for f in nave.env luke.env; do
  [ -f "$f" ] || continue
  cp "$f" "$f.bak-$STAMP"; chmod 600 "$f.bak-$STAMP"
  grep -vE "^($STRIP)=" "$f" > "$f.tmp"; chmod 600 "$f.tmp"; mv "$f.tmp" "$f"
  echo "✓ $f stripped (backup: $f.bak-$STAMP)"
done

# --- 3. Recreate nactor + verify --------------------------------------------
docker compose up -d --force-recreate nactor
C=$(docker ps -qf name=nactor | head -1)
echo "verifying container env…"
LEFT=$(docker exec "$C" sh -c "env | cut -d= -f1 | grep -E '^($STRIP)$' || true")
if [ -n "$LEFT" ]; then echo "✗ still set in container: $LEFT"; VERIFY_FAIL=1; else echo "✓ env clean"; VERIFY_FAIL=0; fi

echo "waiting for the boot grant sweep…"
OK=0
for i in $(seq 1 12); do
  sleep 10
  L=$(docker logs --tail 100 "$C" 2>&1 | grep 'credential-grants: loaded' | tail -1 || true)
  case "$L" in
    *telegram-nactjaf*anthropic*|*anthropic*telegram-nactjaf*) OK=1; echo "✓ reader sweep: $L"; break ;;
  esac
done
[ "$OK" = 1 ] || VERIFY_FAIL=1

if [ "$VERIFY_FAIL" = 1 ]; then
  echo "✗ VERIFICATION FAILED — restoring live env files and recreating nactor"
  for f in nave.env luke.env; do [ -f "$f.bak-$STAMP" ] && cp "$f.bak-$STAMP" "$f"; done
  mv "secrets/nave.enc.env.bak-$STAMP" secrets/nave.enc.env
  docker compose up -d --force-recreate nactor
  echo "restored. Nothing retired."
  exit 1
fi

# --- 4. Emit the new ciphertext for the repo PR ------------------------------
echo "== BEGIN nave.enc.env base64 (lift into deploy/secrets/nave.enc.env via PR) =="
base64 -w0 secrets/nave.enc.env
echo
echo "== END nave.enc.env base64 =="
echo "NOTE: box working tree now differs from the repo for secrets/nave.enc.env"
echo "until that PR lands. Backups (*.bak-$STAMP) are box-local; remove after."
echo "✓ retired: TELEGRAM_BOT_TOKEN + ANTHROPIC_API_KEY — grants are now the only durable home"
