#!/usr/bin/env bash
# Telegram diagnostic — why isn't Luke replying to interactive messages?
# Read-only. Prints config + startup-log facts about the telegram plugin and
# channel. NEVER prints the bot token: every value is masked to a boolean.
set -u
OC=/root/nave.pub/deploy/openclaw-state/.openclaw
J="$OC/openclaw.json"
[ -f "$J" ] || { echo "no openclaw.json at $J"; exit 1; }

mask() { # turn any string into <set,len=N> so a token never lands in the log
  local v; v="$(cat)"; if [ -z "$v" ] || [ "$v" = "null" ]; then echo "<empty>"; else echo "<set,len=${#v}>"; fi
}

echo "=== 1. plugins.entries.telegram ==="
jq -c '.plugins.entries.telegram // "ABSENT"' "$J"
echo
echo "=== 2. channels.telegram (token masked) ==="
jq -c '(.channels.telegram // "ABSENT") | if type=="object" then (.token = (if .token then "<set>" else "<none>" end)) else . end' "$J"
echo
echo "=== 3. all plugin entry keys + enabled flags ==="
jq -c '.plugins.entries | to_entries | map({(.key): (.value.enabled)}) | add' "$J"
echo
echo "=== 4. all channel keys + enabled flags ==="
jq -c '.channels | to_entries | map({(.key): (.value.enabled)}) | add' "$J"
echo

echo "=== 5. diff telegram sections vs backups ==="
for b in openclaw.json.pre-deviceauth-off openclaw.json.pre-bindauto openclaw.json.pre-p1config openclaw.json.pre-thinking; do
  if [ -f "$OC/$b" ]; then
    ce="$(jq -c '.channels.telegram.enabled // "ABSENT"' "$OC/$b" 2>/dev/null)"
    pe="$(jq -c '.plugins.entries.telegram.enabled // "ABSENT"' "$OC/$b" 2>/dev/null)"
    echo "  $b : channel.enabled=$ce  plugin.enabled=$pe"
  fi
done
cur_ce="$(jq -c '.channels.telegram.enabled // "ABSENT"' "$J")"
cur_pe="$(jq -c '.plugins.entries.telegram.enabled // "ABSENT"' "$J")"
echo "  CURRENT : channel.enabled=$cur_ce  plugin.enabled=$cur_pe"
echo

echo "=== 6. openclaw startup log: plugin load + channel/provider init ==="
# Grab the current boot's log and pull the lines that mention plugins, channels,
# telegram, providers, sidecars — anything explaining a skip.
docker logs deploy-openclaw-1 2>&1 | tail -400 \
  | grep -iE 'plugin|channel|telegram|provider|sidecar|starting|skip|disabl|error|fail' \
  | tail -60
echo
echo "=== 7. telegram state dir ==="
ls -la "$OC/telegram" 2>/dev/null || echo "(no $OC/telegram dir)"
ls -la "$OC/state" 2>/dev/null | head -20 || true
echo "== tg-diag done =="
