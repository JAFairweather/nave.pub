#!/usr/bin/env bash
# Probe the REAL CSS custom-property tokens the OpenClaw cockpit defines, so the
# Nave skin can target the actual names instead of guessed ones. Read-only.
# Prints only CSS variable NAMES + theme selectors — no secrets, no personal data.
set -u
# Reach openclaw:57419 from inside the nave network via the luke container (has fetch).
oc() { docker compose exec -T luke node -e 'fetch(process.argv[1]).then(r=>r.text()).then(t=>process.stdout.write(t)).catch(e=>process.stderr.write(String(e)))' "$1" 2>/dev/null; }

echo "=== cockpit shell: linked css/js assets ==="
HTML="$(oc http://openclaw:57419/)"
echo "$HTML" | grep -oE '(href|src)="[^"]*\.(css|js)"' | sort -u | head -40
echo

CSSPATHS="$(echo "$HTML" | grep -oE 'href="[^"]*\.css"' | sed 's/href="//;s/"$//' | sort -u)"
echo "=== defined custom-property NAMES per css (the real token vocabulary) ==="
for css in $CSSPATHS; do
  case "$css" in http*) url="$css";; /*) url="http://openclaw:57419$css";; *) url="http://openclaw:57419/$css";; esac
  echo "── $css ──"
  oc "$url" | grep -oE '\-\-[a-zA-Z0-9-]+[[:space:]]*:' | sed 's/[[:space:]]*:$//' | sort -u | tr '\n' ' '
  echo; echo
done

echo "=== theme selectors (how dark/light is switched) ==="
for css in $CSSPATHS; do
  case "$css" in http*) url="$css";; /*) url="http://openclaw:57419$css";; *) url="http://openclaw:57419/$css";; esac
  oc "$url" | grep -oE '(\[data-theme[^]]*\]|\.dark\b|\.light\b|:root[^{]{0,40})' | sort -u | head -20
done
echo "== oc-skin-probe done =="
