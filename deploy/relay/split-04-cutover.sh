#!/bin/sh
# nave.pub#130 split, step 4 of 5 — CUTOVER. Removes the kind-24133 carve-out
# from relay.nave.pub's write policy by emptying allowKinds in allowlist.json
# and restarting strfry. No code change, no rebuild — the carve-out was
# already config-driven.
#
# THIS IS THE ONE STEP THAT CAN BREAK SIGNING if run before you've personally
# verified a real sign round-trip over transport.nave.pub (split-03's manual
# checklist). Requires CONFIRM=1 to run at all — that gate is deliberate, not
# decoration.
#
# Run as root on the relay box, from the repo:
#   cd /root/nave.pub && git pull
#   CONFIRM=1 sh deploy/relay/split-04-cutover.sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if [ "${CONFIRM:-}" != "1" ]; then
  cat <<'EOF' >&2
Refusing to run without CONFIRM=1.

Before setting it, you must have already:
  - brought up transport.nave.pub                    (split-02)
  - repointed the bunker's signer relays to it        (split-03, dashboard)
  - done a REAL sign approval on your phone through transport.nave.pub and
    watched it actually succeed

If all of that is true and verified, not assumed:
  CONFIRM=1 sh deploy/relay/split-04-cutover.sh
EOF
  exit 1
fi

BACKUP="allowlist.json.bak.$(date +%Y%m%dT%H%M%S)"
cp allowlist.json "$BACKUP"
echo "backed up allowlist.json -> $BACKUP"

python3 - <<'PY'
import json
with open("allowlist.json") as f:
    c = json.load(f)
c["allowKinds"] = []
with open("allowlist.json", "w") as f:
    json.dump(c, f, indent=2)
    f.write("\n")
PY
echo "--- allowlist.json: allowKinds now empty ---"

docker compose restart strfry
sleep 2

echo "--- verifying cutover took ---"
if command -v nak >/dev/null 2>&1; then
  RANDKEY=$(nak key generate)

  OUT=$(nak event -k 24133 -c 'post-cutover-should-reject' --sec "$RANDKEY" relay.nave.pub 2>&1)
  echo "$OUT"
  case "$OUT" in
    *"success."*)
      echo "FAIL — relay.nave.pub STILL accepts 24133 from an unlisted key. Cutover did not take." >&2
      echo "Run: sh deploy/relay/split-05-rollback.sh $BACKUP" >&2
      exit 1 ;;
    *) echo "OK — relay.nave.pub now rejects 24133 from unlisted keys." ;;
  esac

  OUT=$(nak event -k 24133 -c 'transport-still-open-post-cutover' --sec "$RANDKEY" transport.nave.pub 2>&1)
  echo "$OUT"
  case "$OUT" in
    *"success."*) echo "OK — transport.nave.pub still carries 24133 traffic." ;;
    *)
      echo "WARNING — transport.nave.pub rejected 24133 just now. It is the ONLY path for signing after this cutover and it just failed a smoke test. Investigate immediately; consider rollback." >&2 ;;
  esac
else
  echo "nak not found — cannot auto-verify. Do a manual sign test through the bunker RIGHT NOW and confirm it still works." >&2
fi

echo
echo "--- cutover complete. If signing breaks anywhere, run: sh deploy/relay/split-05-rollback.sh $BACKUP"
