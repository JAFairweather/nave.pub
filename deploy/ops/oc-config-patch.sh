#!/usr/bin/env bash
# Patch the box-local OpenClaw state COPY's config for the self-hosted
# trusted-proxy migration. Operates ONLY on deploy/openclaw-state (the copy) —
# never the live instance. Idempotent; keeps a .premigrate.bak. Run at cutover
# (or any time to boot-test the target config via oc-resync-boot's boot step).
#
# What it sets:
#   • gateway.auth.mode = trusted-proxy   (no shared token)
#   • gateway.trustedProxies = the nave bridge subnet
#   • gateway.auth.trustedProxy.userHeader/allowUsers  (Caddy asserts the operator)
#   • gateway.bind = all                  (reachable from Caddy on the nave net)
#   • channels.telegram.enabled = false   (STAGED: off until the real cutover)
#   • clears the break-glass controlUi flags the boot warned about
set -u
CFG=/root/nave.pub/deploy/openclaw-state/.openclaw/openclaw.json
[ -f "$CFG" ] || { echo "no config at $CFG — run oc-resync-boot.sh first"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }

cp "$CFG" "$CFG.premigrate.bak"
tmp=$(mktemp)
jq '
  .gateway.auth.mode = "trusted-proxy"
  | .gateway.trustedProxies = ["172.19.0.0/16"]
  | .gateway.auth.trustedProxy = ((.gateway.auth.trustedProxy // {})
      + { userHeader: "X-Forwarded-User", allowUsers: ["jaf@dequalsf.com"] })
  # trusted-proxy and a shared token are mutually exclusive — drop the leftover token.
  | del(.gateway.auth.token) | del(.gateway.token)
  | .gateway.bind = "lan"
  | (if (.channels | type) == "object" and (.channels.telegram | type) == "object"
       then .channels.telegram.enabled = false else . end)
  | .gateway.controlUi = ((.gateway.controlUi // {})
      + { allowInsecureAuth: false,
          dangerouslyAllowHostHeaderOriginFallback: false,
          dangerouslyDisableDeviceAuth: false })
  # The cockpit is reached via Caddy at luke.nave.pub — allow that origin.
  | .gateway.controlUi.allowedOrigins = (((.gateway.controlUi.allowedOrigins // []) + ["https://luke.nave.pub"]) | unique)
' "$CFG" > "$tmp" && mv "$tmp" "$CFG" || { echo "jq patch failed"; exit 1; }

echo "patched OK. summary:"
jq '{authMode: .gateway.auth.mode, bind: .gateway.bind,
     trustedProxies: .gateway.trustedProxies,
     allowUsers: .gateway.auth.trustedProxy.allowUsers,
     telegramEnabled: (.channels.telegram.enabled // "n/a"),
     controlUi: .gateway.controlUi}' "$CFG"
