#!/usr/bin/env bash
# Phase 2 groundwork — install the himalaya IMAP CLI + Luke's mail config.
#
# The upstream OpenClaw image doesn't bundle the himalaya binary (the old
# Hostinger image did), so the bundled skill shows "blocked: bin:himalaya".
# This script:
#   1. downloads a PINNED static himalaya release into deploy/openclaw-tools/
#      (box-local, gitignored; mounted into the container by compose)
#   2. writes an IMAP-ONLY himalaya config — no SMTP backend is configured, so
#      SENDING IS IMPOSSIBLE BY CONSTRUCTION (draft-only guarantee); drafts are
#      saved to [Gmail]/Drafts over IMAP for you to review + send in Gmail
#   3. writes the app-password file from luke-mail.env (if present)
#   4. validates the binary runs in-container
#
# Secrets: the app password is read from deploy/luke-mail.env and written only
# to a 600 file inside openclaw-state; it is never printed.
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
cd "$D"
HV="v1.2.0"   # pinned; bump deliberately
TOOLS="$D/openclaw-tools"
MAILDIR="$D/openclaw-state/.openclaw/mail"
mkdir -p "$TOOLS" "$MAILDIR"

echo "── 1. himalaya binary ($HV, static musl) ──"
if [ -x "$TOOLS/himalaya" ]; then
  echo "  already present: $("$TOOLS/himalaya" --version 2>/dev/null || echo '(version check needs container)')"
else
  ok=0
  # Asset name verified against the v1.2.0 release page: himalaya.x86_64-linux.tgz
  for url in \
    "https://github.com/pimalaya/himalaya/releases/download/$HV/himalaya.x86_64-linux.tgz" \
    "https://github.com/pimalaya/himalaya/releases/latest/download/himalaya.x86_64-linux.tgz"; do
    echo "  trying: $url"
    if curl -fsSL "$url" -o /tmp/himalaya.tgz 2>/dev/null; then ok=1; break; fi
  done
  [ "$ok" = 1 ] || { echo "  ✗ could not download a himalaya release asset"; exit 1; }
  tar -xzf /tmp/himalaya.tgz -C /tmp
  BIN="$(find /tmp -maxdepth 2 -name himalaya -type f | head -1)"
  [ -n "$BIN" ] || { echo "  ✗ archive had no himalaya binary"; exit 1; }
  install -m 755 "$BIN" "$TOOLS/himalaya"
  rm -rf /tmp/himalaya.tgz "$BIN"
  echo "  installed → openclaw-tools/himalaya"
fi

echo
echo "── 2. IMAP-only config (no SMTP = cannot send) ──"
ADDR="$(grep -E '^GMAIL_ADDRESS=' luke-mail.env 2>/dev/null | cut -d= -f2- | tr -d '\r')"
[ -n "$ADDR" ] || ADDR="james.a.fairweather@gmail.com"
cat > "$MAILDIR/config.toml" <<EOF
# Luke's mail — READ + DRAFT ONLY. There is deliberately no SMTP/send backend
# in this file: himalaya cannot send. Drafts land in [Gmail]/Drafts via IMAP.
[accounts.gmail]
default = true
email = "$ADDR"
display-name = "James Fairweather"
backend.type = "imap"
backend.host = "imap.gmail.com"
backend.port = 993
backend.encryption.type = "tls"
backend.login = "$ADDR"
backend.auth.type = "password"
backend.auth.cmd = "cat /data/.openclaw/mail/app-passwd"
folder.alias.inbox = "INBOX"
folder.alias.drafts = "[Gmail]/Drafts"
folder.alias.sent = "[Gmail]/Sent Mail"
EOF
echo "  wrote mail/config.toml (account: $ADDR)"

echo
echo "── 3. app password ──"
# Google shows the password as 4 groups ("xxxx xxxx xxxx xxxx"); pastes arrive
# with spaces/dashes/NBSPs/quotes. The real password is strictly alphanumeric,
# so strip everything else — this exact class of paste artifact cost us an hour
# on the OAuth refresh token earlier.
PW="$(grep -E '^GMAIL_APP_PASSWORD=' luke-mail.env 2>/dev/null | cut -d= -f2- | tr -cd 'a-zA-Z0-9')"
if [ -n "$PW" ]; then
  umask 077; printf '%s' "$PW" > "$MAILDIR/app-passwd"; unset PW
  echo "  ✓ app-passwd written from luke-mail.env (never printed)"
else
  echo "  ⚠ luke-mail.env not found or missing GMAIL_APP_PASSWORD — write it, then re-run this script"
fi
chown -R 1000:1000 "$MAILDIR"; chmod 600 "$MAILDIR"/* 2>/dev/null
chown 1000:1000 "$TOOLS/himalaya" 2>/dev/null || true

echo
echo "── 4. binary runs in-container? ──"
docker run --rm -v "$TOOLS/himalaya:/usr/local/bin/himalaya:ro" --entrypoint himalaya \
  ghcr.io/openclaw/openclaw:2026.7.1-browser --version 2>&1 | head -1

echo
if [ -f "$MAILDIR/app-passwd" ]; then
  echo "── 5. live IMAP check (counts only) ──"
  docker run --rm --network nave \
    -v "$TOOLS/himalaya:/usr/local/bin/himalaya:ro" \
    -v "$D/openclaw-state/.openclaw/mail:/data/.openclaw/mail:ro" \
    -e HOME=/data --entrypoint sh \
    ghcr.io/openclaw/openclaw:2026.7.1-browser \
    -c 'mkdir -p /tmp/hc/.config/himalaya && cp /data/.openclaw/mail/config.toml /tmp/hc/.config/himalaya/ && HOME=/tmp/hc himalaya envelope list --page-size 3 2>&1 | sed -E "s/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+/<addr>/g; s/\|[^|]{8,}\|/| <subject> |/g" | head -8'
  echo "  (subjects/addresses masked in this public log)"
else
  echo "── 5. live IMAP check skipped (no app-passwd yet) ──"
fi
echo "== mail-setup done =="
