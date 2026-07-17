#!/usr/bin/env bash
# Run Luke's calendar beat as a DRY RUN: fetch today's agenda THROUGH Nactor's
# gcal broker and print the briefing (no Telegram send). Proves the full beat
# path — broker auth, the OAuth token mint, the gcal query with time params, and
# the formatter — end to end. Pass SEND=1 to actually deliver it to your Telegram.
#
#   Ops → run-script → gcal-brief.sh          # dry run, prints the briefing
#   (box) SEND=1 … gcal-brief.sh              # also sends to TELEGRAM_APPROVER_ID
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
cd "$D"
# The beat needs BRAIN_NSEC + NACT_BROKER_URL (brain.env) and TELEGRAM_APPROVER_ID
# (luke.env). Layer both, exactly as the brain cron does. Image is luke:latest.
ARGS="--dry-run"; [ "${SEND:-0}" = "1" ] && ARGS=""
echo "▸ luke-calendar ${ARGS:-<live send>} (via broker; token/creds never printed)"
docker run --rm --network nave \
  --env-file "$D/luke.env" --env-file "$D/brain.env" \
  luke:latest node luke-calendar.mjs $ARGS
echo "== gcal-brief done =="
