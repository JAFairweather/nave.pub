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

# Read through the contents API, NOT raw.githubusercontent.com. The raw host is CDN-cached
# for minutes, so a guard pointed at it reports drift against a version that was already
# merged - it cries wolf precisely when someone has just fixed the thing, which is how a
# check earns the habit of being ignored. Caught by running this against a freshly merged
# source: the API had the change and raw did not.
SRC="${WAGGLE_SRC:-https://api.github.com/repos/JAFairweather/waggle/contents/console/index.html?ref=main}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINE="$HERE/index.html"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT

curl -fsSL -H 'Accept: application/vnd.github.raw' -H 'Cache-Control: no-cache' "$SRC" -o "$TMP"

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
