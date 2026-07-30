#!/usr/bin/env bash
# The console here is a MIRROR. Its source of truth is console/ in JAFairweather/waggle;
# this copy exists only so nave.pub can serve it as a static site.
#
# A mirror that is copied by hand drifts silently, and it already did: the sign-in rework
# landed in the source and was never re-copied, so the live page served the previous build
# for a day. It looked fine - the stale page rendered without complaint - and failed only
# at the moment someone tried to sign in, because the importmap it carried was missing the
# two entries the signer module needs. Nothing reported it. That is the failure this guards.
#
# Compares byte-for-byte against the published source. Exits non-zero on any difference.
set -euo pipefail

SRC="${WAGGLE_RAW:-https://raw.githubusercontent.com/JAFairweather/waggle/main/console/index.html}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINE="$HERE/index.html"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT

curl -fsSL "$SRC" -o "$TMP"

# A truncated or error-page response would otherwise "match" nothing and pass quietly.
bytes=$(wc -c < "$TMP" | tr -d ' ')
if [ "$bytes" -lt 4096 ]; then
  echo "verify-mirror: refusing to compare - fetched only ${bytes} bytes from the source." >&2
  echo "                that is too small to be the console; treat this as a failed check." >&2
  exit 2
fi

if diff -q "$TMP" "$MINE" >/dev/null; then
  echo "verify-mirror: console matches the source in JAFairweather/waggle (${bytes} bytes)."
else
  echo "verify-mirror: DRIFT - the mirrored console differs from the source." >&2
  echo >&2
  diff -u "$MINE" "$TMP" | head -60 >&2
  echo >&2
  echo "  fix: cp <waggle-repo>/console/index.html $MINE" >&2
  exit 1
fi
