#!/bin/sh
# nave.pub#130 split, step 1 of 5 — fix the NIP-11 description's false privacy
# claim. Touches strfry.conf only; write policy (allowlist.json) is untouched,
# so this does not change what anyone can write or sign. Safe to run standalone,
# any time, independent of the rest of the split.
#
# Run as root on the relay box, from the repo:
#   cd /root/nave.pub && git pull && sh deploy/relay/split-01-nip11-fix.sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

echo "--- restarting strfry to pick up the corrected NIP-11 description ---"
docker compose restart strfry

sleep 2
echo "--- verifying ---"
DOC=$(curl -sS https://relay.nave.pub -H 'Accept: application/nostr+json')
echo "$DOC"
case "$DOC" in
  *"NOT authenticated"*)
    echo "OK — live description now discloses open reads." ;;
  *)
    echo "UNEXPECTED — description does not mention open reads. Check strfry.conf was pulled and strfry actually restarted." >&2
    exit 1 ;;
esac
