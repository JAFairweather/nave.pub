#!/usr/bin/env bash
# Point the live luke-brain schedule at the canonical runner (broker + NIP-98 +
# continuity ledger), replacing the old direct-key/bearer invocation. Idempotent:
# rewrites only the '# luke-brain-schedule' line and its CRON_TZ; every other
# crontab entry is preserved untouched. Schedule stays 08:00 & 17:00 ET.
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then DEPLOY=/root/nave.pub/deploy; else DEPLOY=/root/noir/deploy; fi
RUNNER="$DEPLOY/ops/run-brain.sh"
[ -f "$RUNNER" ] || { echo "runner not found: $RUNNER (pull nave.pub first)"; exit 1; }

LINE="0 8,17 * * * bash $RUNNER >> /var/log/luke-brain.log 2>&1 # luke-brain-schedule"

echo "── before ──"; crontab -l 2>/dev/null | grep -E 'CRON_TZ|luke-brain' || echo "(none)"

# Keep all non-brain lines as-is; append CRON_TZ + the brain line at the end so
# the timezone applies to the brain job only (doesn't retro-scope other jobs).
BASE=$(crontab -l 2>/dev/null | grep -v 'luke-brain-schedule' | grep -v '^CRON_TZ=America/New_York')
printf '%s\n' "$BASE" > /tmp/cron.new
{ echo 'CRON_TZ=America/New_York'; echo "$LINE"; } >> /tmp/cron.new
# Drop any leading blank line a missing crontab would create.
sed -i '/^$/N;/^\n$/D' /tmp/cron.new
crontab /tmp/cron.new && rm -f /tmp/cron.new

echo "── after ──"; crontab -l 2>/dev/null | grep -E 'CRON_TZ|luke-brain'
echo "installed. next fires 08:00 / 17:00 America/New_York."
