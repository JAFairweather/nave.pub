#!/usr/bin/env bash
# Arm a ONE-TIME, nostr-gated reveal of a box-side secret.
#
# Drops a single-use record into luke's state dir (./luke-state/reveals, mounted
# at /state/reveals in the luke container). luke-reveal.mjs serves it ONCE behind
# the same nostr gate as the cockpit/console, then burns it. The secret VALUE is
# never printed to this (public) Actions log — only the reveal URL + TTL.
#
# Default target: the SOPS master age key's private line (AGE-SECRET-KEY-1…) —
# the one line the owner saves to a password manager as the master recovery key.
#
#   Ops → run-script → reveal-arm.sh
#
# Override via the box env (rare): REVEAL_SRC=<file> REVEAL_LABEL="…" REVEAL_TTL_MIN=15
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
STATE="$D/luke-state/reveals"
TTL_MIN="${REVEAL_TTL_MIN:-15}"
LABEL="${REVEAL_LABEL:-SOPS master age key — private line (AGE-SECRET-KEY-1…)}"
SRC="${REVEAL_SRC:-${HOME:-/root}/.config/sops/age/keys.txt}"

command -v jq >/dev/null 2>&1     || { echo "jq required";      exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "openssl required"; exit 1; }
[ -f "$SRC" ] || { echo "source secret not found: $SRC"; exit 1; }

mkdir -p "$STATE"
chmod 700 "$D/luke-state" "$STATE" 2>/dev/null || true

# For the sops key file, reveal ONLY the private-key line — that's the single
# line the owner saves. For any other source, reveal the whole file.
VALUE="$(grep -E '^AGE-SECRET-KEY-1' "$SRC" | head -1)"
[ -n "$VALUE" ] || VALUE="$(cat "$SRC")"
[ -n "$VALUE" ] || { echo "source is empty"; exit 1; }

ID="$(openssl rand -hex 16)"
EXP=$(( $(date +%s) + TTL_MIN * 60 ))
F="$STATE/$ID.json"

umask 077
# jq --arg JSON-encodes the value safely (handles any special chars); the value
# is passed via argv to jq only, never echoed.
jq -n --arg id "$ID" --arg label "$LABEL" --arg value "$VALUE" --argjson exp "$EXP" \
  '{id:$id,label:$label,value:$value,expiresAt:$exp}' > "$F"
chmod 600 "$F"
unset VALUE

echo "── one-time reveal armed ──"
echo "  URL : https://console.nave.pub/reveal/$ID"
echo "  what: $LABEL"
echo "  TTL : ${TTL_MIN} min (expires $(date -u -d "@$EXP" +%FT%TZ 2>/dev/null || echo "$EXP epoch"))"
echo "  file: $F (perms $(stat -c '%a' "$F" 2>/dev/null))"
echo
echo "Open the URL, Alby-sign if prompted, click 'Reveal & copy', and paste the"
echo "line into your password manager. It is shown once, then deleted."
echo "== value NOT printed here (public log); it lives only in the box-local file =="
