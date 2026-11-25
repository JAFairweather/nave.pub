#!/usr/bin/env bash
# Canonical luke-brain runner — used by cron AND the ops button, so the live
# scheduled run and a manual run take the exact same path: the credential
# broker (the brain signs NIP-98 as `brain`; no API key or bot token in its
# env) with the P3 continuity ledger mounted. Pass --dry-run to gather + draft
# without proposing.
#
#   bash deploy/ops/run-brain.sh            # LIVE (proposes to Telegram)
#   bash deploy/ops/run-brain.sh --dry-run  # gather + draft + print only
set -u
FLAG="${1:-}"
if [ -f /root/nave.pub/deploy/.flipped ]; then DEPLOY=/root/nave.pub/deploy; else DEPLOY=/root/noir/deploy; fi
cd "$DEPLOY" 2>/dev/null || { echo "no deploy dir"; exit 1; }

# Consumer env: the brokered creds (ANTHROPIC_API_KEY, TELEGRAM_BOT_TOKEN) are
# stripped — the brain reaches those providers through Nactor. Regenerate from
# nave.env when present so it's always current with the latest secrets.
CONSUMER="$DEPLOY/nave-consumer.env"
if [ -f "$DEPLOY/nave.env" ]; then
  grep -vE '^(ANTHROPIC_API_KEY|TELEGRAM_BOT_TOKEN)=' "$DEPLOY/nave.env" > "$CONSUMER" && chmod 600 "$CONSUMER"
fi
[ -f "$CONSUMER" ] || { echo "no consumer env ($CONSUMER) — run a deploy first"; exit 1; }

# Broker identity (box-local, gitignored): BRAIN_NSEC + NACT_BROKER_URL. The
# brain calls http://nactor:8791, so join Nactor's compose network (detected
# dynamically). If brain.env is absent the brain has no LLM path in the consumer
# env — so require it here rather than silently no-op.
BRAINENV=""; NETARG=""; NET=""
if [ -f "$DEPLOY/brain.env" ]; then
  BRAINENV="--env-file $DEPLOY/brain.env"
  NET=$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' deploy-nactor-1 2>/dev/null)
  [ -n "$NET" ] && NETARG="--network $NET"
else
  echo "⚠ no brain.env — the brain has no key in the consumer env; run ops/gen-brain-key.sh"
fi

# Which provider drafts. OpenAI since 25 Nov 2026, through the broker like every other credential: it needs
# the broker's `openai` provider and a Director grant of `credential:openai` to the brain identity. Until
# that grant lands the run fails with the broker's own "credential 'openai' not imported". To go back, run
# with DRAFT_PROVIDER=anthropic (a one-off: DRAFT_PROVIDER=anthropic bash ops/run-brain.sh --dry-run) or
# change the default here. An env file that sets DRAFT_PROVIDER is overridden by this line on purpose: the
# choice lives in git.
PROVIDER="${DRAFT_PROVIDER:-openai}"
case "$PROVIDER" in anthropic|openai) ;; *) echo "DRAFT_PROVIDER '$PROVIDER' is not anthropic or openai"; exit 1 ;; esac

# P3 continuity ledger: box-local, writable, survives redeploys (gitignored).
mkdir -p "$DEPLOY/brain-state"

echo "── luke-brain ${FLAG:-(LIVE — proposing to Telegram)} ${BRAINENV:+(broker on${NET:+ · net=$NET})} · drafts on $PROVIDER @ $(date -u +%FT%TZ) ──"
docker run --rm --env-file "$CONSUMER" $BRAINENV $NETARG \
  -e BRAIN_LEDGER=/state/ledger.json \
  -e DRAFT_PROVIDER="$PROVIDER" \
  -v "$DEPLOY/brain-state:/state" \
  luke:latest node luke-brain.mjs $FLAG
echo "── brain done ──"
