#!/usr/bin/env bash
# One-time setup for the off-box brain backup. Idempotent — re-run as needed.
#
#   1. Ensure `age` is installed (the tarball encryptor).
#   2. Generate a box-local SSH deploy key for the private luke-brain repo and
#      print its PUBLIC half.
#   3. Clone the repo (works only AFTER the deploy key is added with write access).
#   4. Once cloned, install a daily cron that runs brain-backup.sh.
#
# The private deploy key stays box-local (gitignored, 0600) and never leaves the
# box. First run prints the key and stops (clone fails until you add it); add the
# key on GitHub, then re-run to finish.
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
KEY="$D/luke-brain-deploy.key"
REPO="$D/luke-brain-repo"
REMOTE="git@github.com:JAFairweather/luke-brain.git"

# 1. age -------------------------------------------------------------------
if ! command -v age >/dev/null 2>&1; then
  echo "installing age…"
  (apt-get update -qq && apt-get install -y -qq age) >/dev/null 2>&1 || true
fi
if command -v age >/dev/null 2>&1; then echo "✓ age: $(command -v age)"; else echo "✗ age missing — install it manually (apt-get install age)"; fi

# 2. deploy key ------------------------------------------------------------
if [ ! -f "$KEY" ]; then
  ssh-keygen -t ed25519 -N '' -C 'luke-brain-backup@nave' -f "$KEY" >/dev/null
  echo "✓ generated deploy key"
else
  echo "· deploy key already present"
fi
chmod 600 "$KEY"

# 3. clone -----------------------------------------------------------------
export GIT_SSH_COMMAND="ssh -i $KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
if [ -d "$REPO/.git" ]; then
  echo "✓ repo already cloned at $REPO"
elif git clone "$REMOTE" "$REPO" 2>/dev/null; then
  echo "✓ cloned luke-brain → $REPO"
else
  echo
  echo "── NEXT: add this as a WRITE deploy key on github.com/JAFairweather/luke-brain ──"
  echo "   repo → Settings → Deploy keys → Add deploy key → tick 'Allow write access'"
  echo
  cat "$KEY.pub"
  echo
  echo "then re-run brain-backup-setup.sh to clone + finish."
  exit 0
fi

# 4. daily cron ------------------------------------------------------------
CRON_LINE="40 3 * * * cd $D && bash ops/brain-backup.sh >> /var/log/luke-brain-backup.log 2>&1"
if crontab -l 2>/dev/null | grep -q 'brain-backup.sh'; then
  echo "· cron already installed"
else
  ( crontab -l 2>/dev/null; echo "$CRON_LINE" ) | crontab -
  echo "✓ installed daily cron (03:40 box time) — logs: /var/log/luke-brain-backup.log"
fi
echo
echo "== setup complete — run brain-backup.sh now for the first snapshot =="
