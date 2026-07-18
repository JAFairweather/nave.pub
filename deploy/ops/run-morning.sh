#!/usr/bin/env bash
# Run the unified morning brief (luke-morning.mjs) with everything it needs:
# brain identity + broker (brain.env), Telegram target (luke.env), the pinned
# himalaya binary + IMAP-only mail config (mounted read-only). Called by cron
# at 7:20 ET; pass --dry-run to test without sending.
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
cd "$D"
docker run --rm --network nave \
  --env-file "$D/luke.env" --env-file "$D/brain.env" \
  -e HIMALAYA_BIN=/usr/local/bin/himalaya \
  -v "$D/openclaw-tools/himalaya:/usr/local/bin/himalaya:ro" \
  -v "$D/openclaw-state/.openclaw/mail/config.toml:/root/.config/himalaya/config.toml:ro" \
  -v "$D/openclaw-state/.openclaw/mail:/data/.openclaw/mail:ro" \
  -v "$D/brain-state:/state:ro" \
  luke:latest node luke-morning.mjs "$@"
