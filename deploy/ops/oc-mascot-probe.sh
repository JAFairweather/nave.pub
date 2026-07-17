#!/usr/bin/env bash
# Find the exact element/source of the pig mascot used as the CHAT avatar, so we
# can swap it precisely (the brand mark already swapped; the message avatar uses
# a different class). Read-only.
set -u
oc(){ docker compose exec -T luke node -e 'fetch(process.argv[1]).then(r=>r.text()).then(t=>process.stdout.write(t)).catch(e=>process.stderr.write(""+e))' "$1" 2>/dev/null; }
HTML="$(oc http://openclaw:57419/)"
JS="$(echo "$HTML" | grep -oE '(src|href)="[^"]*index[^"]*\.js"' | sed 's/.*="//;s/"$//' | head -1)"
BODY="$(oc "http://openclaw:57419/${JS#./}")"
echo "js bundle: ${JS} (${#BODY} bytes)"
echo
echo "=== asset files referenced (mascot/pig/claw/logo/avatar/face) ==="
echo "$BODY" | grep -oiE '[A-Za-z0-9_-]+\.(svg|png|webp)' | sort -u | grep -iE 'mascot|pig|claw|logo|brand|avatar|face|hog|char' | head -30
echo
echo "=== all distinct asset basenames in the bundle (first 50) ==="
echo "$BODY" | grep -oiE '[A-Za-z0-9_-]+\.(svg|png|webp|jpg)' | sort -u | head -50
echo
echo "=== does the mascot come from an inline data-uri svg? (count) ==="
echo -n "  data:image/svg occurrences: "; echo "$BODY" | grep -oiE 'data:image/svg\+xml' | wc -l
echo
echo "=== agent-chat / avatar class variants near 'agent-chat' (raw) ==="
echo "$BODY" | grep -oiE 'agent-chat__avatar[A-Za-z_-]*' | sort -u
echo "$BODY" | grep -oiE 'agent-avatar[A-Za-z_-]*|chat-avatar[A-Za-z_-]*|assistant-avatar[A-Za-z_-]*' | sort -u
echo "== oc-mascot-probe done =="
