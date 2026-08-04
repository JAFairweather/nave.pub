#!/usr/bin/env bash
# Static regression for the #135 deployment boundary. It intentionally does not need SOPS,
# Docker, a relay, or any secret: a no-SOPS host is precisely the case that must still delete
# an obsolete plaintext waggle-wake.env.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITES="$ROOT/sites.sh"
COMPOSE="$ROOT/docker-compose.yml"

fail() { echo "keyless-waggle-wake: FAIL — $*" >&2; exit 1; }
test "$(grep -c '^rm -f waggle-wake\.env$' "$SITES")" -eq 1 || fail 'legacy env cleanup must occur exactly once'
cleanup_line="$(grep -n '^rm -f waggle-wake\.env$' "$SITES" | cut -d: -f1)"
secrets_line="$(grep -n '^if \[ -n "\$SECRETS_SRC"' "$SITES" | cut -d: -f1)"
test "$cleanup_line" -lt "$secrets_line" || fail 'legacy env cleanup must precede optional SOPS setup'
! grep -q 'wagglewake\.age\|wake-watcher\.mjs' "$SITES" || fail 'sites.sh still contains the keyed watcher path'

# Execute the no-SOPS branch in an isolated copy. The git stub lets the synchronizer pass
# without network; the important assertion is that its early cleanup removes the legacy file.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/deploy" "$tmp/bin"
cp "$SITES" "$tmp/deploy/sites.sh"
for app in nave noir nvelope nontact notegate ntrigue nvoy ngage nherit nscope nact luke waggle; do
  mkdir -p "$tmp/deploy/sites/$app/.git"
done
printf '%s\n' '#!/bin/sh' 'exit 0' > "$tmp/bin/git"
chmod 755 "$tmp/bin/git"
touch "$tmp/deploy/waggle-wake.env"
PATH="$tmp/bin:$PATH" bash "$tmp/deploy/sites.sh" >/dev/null
test ! -e "$tmp/deploy/waggle-wake.env" || fail 'no-SOPS run retained legacy plaintext env'

service="$(awk '/^  waggle-wake:/{p=1} p{print} p && /^  [a-zA-Z0-9_-]+:$/ && $0 !~ /^  waggle-wake:$/ {exit}' "$COMPOSE")"
printf '%s\n' "$service" | grep -q 'keyless-wake-watcher\.mjs' || fail 'Compose does not start the keyless watcher'
printf '%s\n' "$service" | grep -q 'WAKE_RECIPIENT=' || fail 'Compose lacks an explicit public recipient'
! printf '%s\n' "$service" | grep -qE 'NVOY_NSEC|waggle-wake\.env|WAKE_NOTIFY|tools/wake-watcher\.mjs' || fail 'Compose still exposes the keyed watcher path'
echo 'keyless-waggle-wake: all passed'
