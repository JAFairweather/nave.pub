#!/bin/sh
# nave.pub#130 split — rollback for split-04-cutover.sh. Restores the
# kind-24133 carve-out on relay.nave.pub if the transport split causes a
# signing outage. Does NOT tear down transport.nave.pub or touch the bunker's
# dashboard relay list — those are left running/repointed; this only
# reopens relay.nave.pub as a fallback path again.
#
# Usage (run as root on the relay box, from the repo):
#   sh deploy/relay/split-05-rollback.sh [path-to-allowlist.json.bak.TIMESTAMP]
#
# With no argument, sets allowKinds back to [24133] on the CURRENT
# allowlist.json directly (equivalent to undoing split-04 without needing the
# timestamped backup file split-04 printed).
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

BACKUP="${1:-}"
if [ -n "$BACKUP" ]; then
  if [ ! -f "$BACKUP" ]; then
    echo "backup file not found: $BACKUP" >&2
    exit 1
  fi
  cp "$BACKUP" allowlist.json
  echo "restored allowlist.json from $BACKUP"
else
  python3 - <<'PY'
import json
with open("allowlist.json") as f:
    c = json.load(f)
c["allowKinds"] = [24133]
with open("allowlist.json", "w") as f:
    json.dump(c, f, indent=2)
    f.write("\n")
PY
  echo "restored allowKinds to [24133] on allowlist.json"
fi

docker compose restart strfry
echo "--- rollback applied. relay.nave.pub accepts 24133 again. ---"
echo "transport.nave.pub and the bunker's dashboard relay list are unaffected — repoint the bunker back manually if you also want to undo step 3."
