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
#   • clears the break-glass controlUi flags the boot warned about
#
# Post-cutover hardening: this script NO LONGER touches channels.telegram
# (that's oc-telegram-on.sh's job) and NO LONGER force-resets
# dangerouslyDisableDeviceAuth — it PRESERVES whichever value is live. Both used
# to be forced to cutover-staging defaults (telegram off, device-auth on), and a
# stray re-run silently took Luke's Telegram down and re-broke the cockpit login.
# A migration-prep tool must never clobber steady-state operating toggles.
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
  # channels.telegram is deliberately NOT touched here — oc-telegram-on.sh owns
  # that toggle. Forcing it off here silently killed Luke's interactive replies.
  # dangerouslyDisableDeviceAuth is PRESERVED (defaults false only if unset), so a
  # re-run can't re-enable device pairing and re-break the cockpit login.
  | .gateway.controlUi = ((.gateway.controlUi // {})
      + { allowInsecureAuth: false,
          dangerouslyAllowHostHeaderOriginFallback: false })
  | .gateway.controlUi.dangerouslyDisableDeviceAuth =
      (.gateway.controlUi.dangerouslyDisableDeviceAuth // false)
  # The cockpit is served at cockpit.nave.pub (root, behind the gate) — allow it.
  | .gateway.controlUi.allowedOrigins = (((.gateway.controlUi.allowedOrigins // []) + ["https://cockpit.nave.pub","https://luke.nave.pub"]) | unique)
' "$CFG" > "$tmp" && mv "$tmp" "$CFG" || { echo "jq patch failed"; exit 1; }

echo "patched OK. summary:"
jq '{authMode: .gateway.auth.mode, bind: .gateway.bind,
     trustedProxies: .gateway.trustedProxies,
     allowUsers: .gateway.auth.trustedProxy.allowUsers,
     telegramEnabled: (.channels.telegram.enabled // "n/a"),
     controlUi: .gateway.controlUi}' "$CFG"
