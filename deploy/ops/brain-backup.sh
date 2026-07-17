#!/usr/bin/env bash
# Off-box, encrypted snapshot of Luke's brain.
#
# Tars Luke's workspace (SOUL/IDENTITY/USER/AGENTS/HEARTBEAT/TOOLS/MEMORY,
# memory/, punchlist, and the workspace git history) + the engine config
# (openclaw.json), age-encrypts the tarball to the box's SOPS age key's PUBLIC
# recipient — the same key the owner holds off-box — and commits the ciphertext
# to the private luke-brain repo, pushing via the box deploy key. Rotated: keeps
# the newest N snapshots.
#
# The plaintext brain never leaves the box; only the age ciphertext is pushed.
# Requires brain-backup-setup.sh to have run (age installed, deploy key added to
# the repo, repo cloned). Idempotent; intended to run daily from cron.
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
OC="$D/openclaw-state/.openclaw"
REPO="$D/luke-brain-repo"
KEY="$D/luke-brain-deploy.key"
SOPSKEY="${HOME:-/root}/.config/sops/age/keys.txt"
KEEP="${BRAIN_BACKUP_KEEP:-30}"

command -v age >/dev/null 2>&1 || { echo "✗ age not installed — run brain-backup-setup.sh"; exit 1; }
[ -d "$REPO/.git" ]     || { echo "✗ no repo clone at $REPO — run brain-backup-setup.sh"; exit 1; }
[ -f "$SOPSKEY" ]       || { echo "✗ no sops age key at $SOPSKEY"; exit 1; }
[ -d "$OC/workspace" ]  || { echo "✗ no workspace at $OC/workspace"; exit 1; }

RECIP="$(age-keygen -y "$SOPSKEY" 2>/dev/null)"
[ -n "$RECIP" ] || { echo "✗ couldn't derive age recipient from the box key"; exit 1; }

export GIT_SSH_COMMAND="ssh -i $KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
git -C "$REPO" pull --ff-only origin main >/dev/null 2>&1 || true

mkdir -p "$REPO/snapshots"
STAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
OUT="$REPO/snapshots/brain-$STAMP.tar.gz.age"

# tar (workspace + engine config) → gzip → age-encrypt, all streamed: the
# plaintext tarball never touches disk, only the ciphertext.
if tar czf - -C "$OC" workspace openclaw.json 2>/dev/null | age -r "$RECIP" -o "$OUT"; then
  echo "✓ encrypted snapshot: snapshots/brain-$STAMP.tar.gz.age ($(stat -c '%s' "$OUT" 2>/dev/null) bytes → $RECIP)"
else
  echo "✗ tar|age failed"; rm -f "$OUT"; exit 1
fi

# Prune: keep the newest $KEEP snapshots.
ls -1t "$REPO"/snapshots/brain-*.tar.gz.age 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r old; do
  git -C "$REPO" rm -q "$old" 2>/dev/null || rm -f "$old"
  echo "  pruned $(basename "$old")"
done

cd "$REPO"
git add snapshots
if git -c user.email=luke@nave.pub -c user.name=Luke commit -q -m "brain snapshot $STAMP"; then
  for i in 1 2 3 4; do
    if git push origin main; then echo "✓ pushed"; break; fi
    echo "  push failed (attempt $i)"; [ "$i" -lt 4 ] && sleep $((i * 2))
  done
else
  echo "(nothing new to commit)"
fi
echo "== brain-backup done: $STAMP =="
