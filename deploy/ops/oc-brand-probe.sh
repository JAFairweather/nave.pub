#!/usr/bin/env bash
# What's needed to rebrand the cockpit: (1) any NATIVE branding config in
# openclaw.json (the clean path), (2) whether the brand lives in the served
# HTML shell or is client-rendered, (3) the class names for the logo/wordmark,
# the update banner, and the message avatar. Read-only; no secrets printed.
set -u
OC=/root/nave.pub/deploy/openclaw-state/.openclaw
J="$OC/openclaw.json"
oc(){ docker compose exec -T luke node -e 'fetch(process.argv[1]).then(r=>r.text()).then(t=>process.stdout.write(t)).catch(e=>process.stderr.write(""+e))' "$1" 2>/dev/null; }

echo "=== 1. native branding config? (controlUi keys + any brand/title/name/logo) ==="
jq -c '.gateway.controlUi // {} | keys' "$J" 2>/dev/null
jq -r 'paths as $p | ($p|map(tostring)|join(".")) as $k | select($k|test("brand|title|appName|logo|productName|displayName";"i")) | $k' "$J" 2>/dev/null | grep -ivE 'nsec|token|secret|key|npub' | sort -u | head -30
echo

echo "=== 2. is the brand in the served shell (light DOM) or client-rendered? ==="
HTML="$(oc http://openclaw:57419/)"
echo -n "shell contains the word OpenClaw: "; echo "$HTML" | grep -ic openclaw
echo -n "shell <title>: "; echo "$HTML" | grep -oiE '<title>[^<]*</title>' | head -1
echo -n "shell has an <img>/<svg> logo in body head: "; echo "$HTML" | grep -oiE '<(img|svg)[^>]{0,60}' | head -3
echo

echo "=== 3. brand / banner / avatar class names in the css ==="
for css in $(echo "$HTML" | grep -oE 'href="[^"]*\.css"' | sed 's/href="//;s/"$//'); do
  url="http://openclaw:57419/${css#./}"
  oc "$url" | grep -oE '\.[a-zA-Z0-9_-]*(brand|logo|mascot|masthead|topbar|sidebar|nav-|banner|update|announce|avatar|wordmark|app-name|product)[a-zA-Z0-9_-]*' | sort -u | tr '\n' ' '
done
echo
echo "== oc-brand-probe done =="
