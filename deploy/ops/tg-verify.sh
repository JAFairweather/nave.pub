#!/usr/bin/env bash
# Verify the telegram channel actually came up after oc-telegram-on.sh.
# Read-only. Never prints the bot token.
set -u
OC=/root/nave.pub/deploy/openclaw-state/.openclaw
J="$OC/openclaw.json"

echo "=== config: channels.telegram.enabled ==="
jq -c '.channels.telegram.enabled' "$J"
echo

echo "=== token reaches the openclaw container? (masked) ==="
docker exec deploy-openclaw-1 sh -c 'if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then echo "SET (len=${#TELEGRAM_BOT_TOKEN})"; else echo UNSET; fi' 2>&1
echo

echo "=== latest boot: from the most recent [gateway] starting... onward ==="
# Print only the log tail since the last gateway (re)start, and pull the lines
# that reveal plugin count + telegram provider + any channel error.
docker logs deploy-openclaw-1 2>&1 | awk '
  /\[gateway\] starting\.\.\.|received SIGUSR1|starting HTTP server/ { buf=""; cap=1 }
  cap { buf=buf $0 "\n" }
  END { print buf }
' | grep -iE 'http server listening|telegram|channel|sidecar|provider|getupdates|error|fail|unauthor|401' | tail -30
echo
echo "=== plugin count on the current boot (telegram present?) ==="
docker logs deploy-openclaw-1 2>&1 | grep -E 'http server listening' | tail -1
echo "== tg-verify done =="
