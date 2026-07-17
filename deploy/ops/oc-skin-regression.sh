#!/usr/bin/env bash
# Regression suite for the Nave cockpit skin + rebrand.
#
# The skin/rebrand is coupled to OpenClaw's class names + CSS tokens, so an
# OpenClaw upgrade can silently break it. Run this AFTER EVERY UPGRADE: it
# asserts every class + token the look depends on still exists in the live
# bundle, and that luke serves + injects the skin correctly (tokens, rebrand
# rules, avatar data-URI, rebranded title + favicon). Exits non-zero on any
# drift, naming exactly what broke. Read-only.
set -u
oc(){   docker compose exec -T luke node -e 'fetch(process.argv[1]).then(r=>r.text()).then(t=>process.stdout.write(t)).catch(e=>process.stderr.write(""+e))' "$1" 2>/dev/null; }
occk(){ docker compose exec -T luke node -e 'fetch(process.argv[1],{headers:{"x-forwarded-host":"cockpit.nave.pub"}}).then(r=>r.text()).then(t=>process.stdout.write(t)).catch(e=>process.stderr.write(""+e))' "$1" 2>/dev/null; }
FAIL=0
pass(){ echo "  ✓ $1"; }
fail(){ echo "  ✗ $1"; FAIL=1; }

echo "=== OpenClaw version under test ==="
docker logs deploy-openclaw-1 2>&1 | grep -oiE 'v?2026\.[0-9]+\.[0-9]+' | tail -1
docker inspect --format '{{.Config.Image}}' deploy-openclaw-1 2>/dev/null
echo

HTML="$(oc http://openclaw:57419/)"
CSSPATH="$(echo "$HTML" | grep -oE 'href="[^"]*\.css"' | sed 's/href="//;s/"$//' | head -1)"
CSS="$(oc "http://openclaw:57419/${CSSPATH#./}")"
echo "bundle css: ${CSSPATH:-<none>} (${#CSS} bytes)"; echo

echo "=== 1. rebrand-critical CLASSES still in the bundle ==="
# (v2026.7.1 removed sidebar-brand__eyebrow — the NAVE kicker now rides
#  sidebar-brand__title::before; __identity is the new wrapper we also watch.)
for c in sidebar-brand__logo sidebar-brand__identity sidebar-brand__title update-banner agent-chat__avatar--logo btn login-gate__logo; do
  echo "$CSS" | grep -q "\.$c" && pass "class .$c" || fail "class .$c MISSING — rebrand selector drifted"
done
echo

echo "=== 2. key theme TOKENS still defined ==="
for t in --bg --bg-content --panel --card --border --text --chat-text --accent --primary --ring --muted --ok --warn --danger --destructive --font-display --mono --radius --shadow-md --tool-shell --secondary --chrome --popover --input --cm-bg --md-preview-document-bg; do
  echo "$CSS" | grep -q -- "$t" && pass "token $t" || fail "token $t MISSING — skin override is now dead"
done
echo

echo "=== 3. light-mode selector mechanism intact ==="
echo "$CSS" | grep -q 'data-theme-mode' && pass "data-theme-mode selector" || fail "data-theme-mode MISSING — light mode broke"
echo

echo "=== 4. luke serves + injects the skin ==="
SKIN="$(occk http://localhost:8790/__nave-skin.css)"
echo "  (served skin: ${#SKIN} bytes)"
echo "$SKIN" | grep -q -- '--tool-shell' && pass "served skin carries tokens" || fail "served skin stale/empty"
echo "$SKIN" | grep -q 'sidebar-brand__logo' && pass "served skin carries rebrand rules" || fail "served skin missing rebrand"
echo "$SKIN" | grep -q 'data:image/png;base64' && pass "served skin carries the avatar data-URI" || fail "avatar data-URI missing"
DOC="$(occk http://localhost:8790/)"
echo "$DOC" | grep -q '__nave-skin.css' && pass "document: skin <link> injected" || fail "document: skin link missing"
echo "$DOC" | grep -q 'Luke · Nave' && pass "document: title rebranded" || fail "document: title not rebranded"
echo "$DOC" | grep -q 'avatars/luke.png' && pass "document: favicon set to Luke" || fail "document: favicon not set"
echo

echo "=== 5. shadow-DOM-piercing mascot swap injected ==="
# The JS swap is the durable fix for mascots CSS can't reach (shadow DOM). If an
# upgrade or refactor drops it, the chat/brand pig can resurface silently.
echo "$DOC" | grep -q 'el.shadowRoot' && pass "document: shadow-DOM walker injected" || fail "document: mascot-swap script missing"
echo "$DOC" | grep -q 'MutationObserver' && pass "document: re-apply observer injected" || fail "document: MutationObserver missing"
echo

if [ "$FAIL" = 0 ]; then
  echo "== ✅ SKIN REGRESSION PASS — cockpit rebrand intact =="
else
  echo "== ❌ SKIN REGRESSION FAIL — a dependency drifted; fix luke-skin.mjs before trusting the cockpit look =="
  exit 1
fi
