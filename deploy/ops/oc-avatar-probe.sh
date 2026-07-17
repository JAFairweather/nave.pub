#!/usr/bin/env bash
# Find the RIGHT way to swap the pig for Luke's avatar: (1) a native
# agent-avatar/logo field in openclaw.json, or (2) how the brand logo + chat
# avatar actually render in the bundle (img vs div, and the default asset).
set -u
OC=/root/nave.pub/deploy/openclaw-state/.openclaw
J="$OC/openclaw.json"
oc(){ docker compose exec -T luke node -e 'fetch(process.argv[1]).then(r=>r.text()).then(t=>process.stdout.write(t)).catch(e=>process.stderr.write(""+e))' "$1" 2>/dev/null; }

echo "=== 1. native avatar/image/icon/logo field in openclaw.json? ==="
jq -r 'paths as $p | ($p|map(tostring)|join(".")) as $k | select($k|test("avatar|image|icon|logo|picture";"i")) | $k + " = " + (getpath($p)|tostring)' "$J" 2>/dev/null | grep -ivE 'nsec|token|secret|key' | head -30
echo "(nothing above = no native field)"
echo

HTML="$(oc http://openclaw:57419/)"
JS="$(echo "$HTML" | grep -oE '(src|href)="[^"]*index[^"]*\.js"' | sed 's/.*="//;s/"$//' | head -1)"
BODY="$(oc "http://openclaw:57419/${JS#./}")"
echo "js bundle: ${JS} (${#BODY} bytes)"
echo
echo "=== 2. brand logo render (element + nearby markup) ==="
echo "$BODY" | grep -oE '.{50}sidebar-brand__logo.{110}' | head -3
echo
echo "=== 3. chat avatar render ==="
echo "$BODY" | grep -oE '.{40}agent-chat__avatar.{130}' | head -4
echo
echo "=== 4. default mascot/pig/brand asset refs ==="
echo "$BODY" | grep -oiE '[a-z0-9_/.-]*(mascot|pig|claw|brand|avatar|logo)[a-z0-9_/.-]*\.(png|svg|webp)' | sort -u | head -20
echo "== oc-avatar-probe done =="
