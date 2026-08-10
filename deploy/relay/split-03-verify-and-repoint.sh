#!/bin/sh
# nave.pub#130 split, step 3 of 5 — automated smoke tests for
# transport.nave.pub, then the manual checklist to repoint the bunker at it.
#
# The repoint itself is a Bunker46 DASHBOARD action (no config file, no env
# var to script) — this script automates what CAN be automated and prints
# exactly what to click for the rest. Nothing here changes relay.nave.pub's
# write policy; the main relay keeps accepting 24133 until step 4.
#
# Requires `nak` (https://github.com/fiatjaf/nak) for the automated checks.
# Without it, the checks are skipped and only the manual checklist prints.
#
# Run as root on the relay box, from the repo:
#   cd /root/nave.pub && git pull && sh deploy/relay/split-03-verify-and-repoint.sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

# nak's exit code does NOT reflect relay-level rejection (an "OK false" from
# the relay still exits 0) — it only reflects connection failure. Every check
# below greps nak's own "publishing to ... success."/"failed:" line instead of
# trusting $?.
if ! command -v nak >/dev/null 2>&1; then
  echo "nak not found — install it to run the automated checks below (see https://github.com/fiatjaf/nak). Skipping to the manual checklist." >&2
else
  RANDKEY=$(nak key generate)

  echo "--- transport.nave.pub: kind 24133 from an unlisted key should be ACCEPTED ---"
  OUT=$(nak event -k 24133 -c 'transport-split-smoke-test' --sec "$RANDKEY" transport.nave.pub 2>&1)
  echo "$OUT"
  case "$OUT" in
    *"success."*) echo "OK" ;;
    *) echo "FAIL — transport relay did not accept 24133 from an unlisted key. Do not repoint the bunker until this passes." >&2; exit 1 ;;
  esac

  echo "--- transport.nave.pub: kind 1 should be REJECTED (only 24133 belongs here) ---"
  OUT=$(nak event -k 1 -c 'should be rejected' --sec "$RANDKEY" transport.nave.pub 2>&1)
  echo "$OUT"
  case "$OUT" in
    *"success."*) echo "FAIL — transport relay accepted a non-24133 event; it should carry only NIP-46 transport traffic." >&2; exit 1 ;;
    *) echo "OK — rejected as expected." ;;
  esac

  echo "--- relay.nave.pub: kind 24133 should STILL be accepted for now (cutover is step 4, not yet run) ---"
  OUT=$(nak event -k 24133 -c 'main-relay-still-open-smoke-test' --sec "$RANDKEY" relay.nave.pub 2>&1)
  echo "$OUT"
  case "$OUT" in
    *"success."*) echo "OK — main relay unchanged, as expected before step 4." ;;
    *) echo "NOTE — main relay already rejects 24133. If step 4 hasn't run yet, that's unexpected; investigate before continuing." >&2 ;;
  esac
fi

cat <<'EOF'

============================================================
MANUAL STEP — this is a Bunker46 dashboard setting, not a file. It cannot be
scripted from here.

  1. Open https://bunker.nave.pub in a browser, log in.
  2. Settings -> signer relays. Set the relay list to:
       wss://transport.nave.pub
       wss://relay.damus.io
       wss://nos.lol
     (own relay + 2 public fallbacks — no single-relay lockout, same pattern
     as the original bunker setup.)
  3. Save.
  4. Do a REAL sign: open a Nave app on your phone, trigger a login/NIP-98
     challenge, approve it in the bunker app. Confirm it actually completes —
     not just that the dashboard saved.

Only after step 4 above succeeds for real should you run split-04-cutover.sh.
That script refuses to run without an explicit CONFIRM=1 for exactly this
reason.
============================================================
EOF
