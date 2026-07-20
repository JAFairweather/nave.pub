#!/bin/sh
# Nave SSH rekey — install the single management key on a box, safely.
# Run from your MAC (where ~/.ssh/nave_mgmt lives). See deploy/ops/ssh-standard.md.
#
#   sh rekey.sh root@HOST          # install key + verify (leaves password ON)
#   sh rekey.sh root@HOST --lock   # + disable password/root-password (only after verify)
#
# It APPENDS the key (existing keys, incl. the CI deploy key, are kept), fixes
# perms + SELinux, and REFUSES to disable passwords unless key login is proven —
# so it cannot lock you out. Keep a console/second session open the first time.
set -eu
HOST="${1:?usage: sh rekey.sh user@host [--lock]}"
LOCK="${2:-}"
KEYFILE="${MGMT_KEY:-$HOME/.ssh/nave_mgmt}"
PUBFILE="${MGMT_PUB:-$KEYFILE.pub}"
[ -f "$PUBFILE" ] || { echo "no pubkey at $PUBFILE — make one: ssh-keygen -t ed25519 -f $KEYFILE -C nave-mgmt"; exit 1; }
PUB="$(cat "$PUBFILE")"

echo "→ installing management key on $HOST (append; existing keys kept)"
ssh "$HOST" "sh -s" <<EOF
set -e
mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
grep -qxF '$PUB' ~/.ssh/authorized_keys || printf '%s\n' '$PUB' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
command -v restorecon >/dev/null 2>&1 && restorecon -Rv ~/.ssh >/dev/null 2>&1 || true
echo "  installed on \$(hostname)"
EOF

echo "→ verifying key-only login…"
if ssh -i "$KEYFILE" -o IdentitiesOnly=yes -o PasswordAuthentication=no "$HOST" 'echo KEY_OK' 2>/dev/null | grep -q KEY_OK; then
  echo "  ✓ key login works"
else
  echo "  ✗ key-only login FAILED — NOT locking. Check authorized_keys / SELinux and re-run."
  exit 1
fi

if [ "$LOCK" = "--lock" ]; then
  echo "→ key verified — locking $HOST to key-only (disabling passwords)"
  ssh -i "$KEYFILE" -o IdentitiesOnly=yes "$HOST" "sh -s" <<'EOF'
set -e
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sshd -t && { systemctl reload sshd 2>/dev/null || systemctl reload ssh; }
echo "  password auth OFF; root is key-only"
EOF
  echo "  ✓ locked. Open a FRESH 'ssh -i $KEYFILE $HOST' to confirm before closing your current session."
else
  echo "→ password auth left ON. Re-run with --lock once you've confirmed key login."
fi
