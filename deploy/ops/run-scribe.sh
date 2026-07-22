#!/usr/bin/env bash
# Canonical jaf-scribe runner — same broker discipline as run-brain.sh. The
# scribe drafts posts in the DIRECTOR's first person and issues each as a
# draft:post scope granted to his npub (review + sign happens in Ngage —
# ngage.nave.pub — with HIS key; nothing here can post as him).
#
#   bash deploy/ops/run-scribe.sh            # LIVE (issues grants)
#   bash deploy/ops/run-scribe.sh --dry-run  # gather + draft + print only
set -u
FLAG="${1:-}"
if [ -f /root/nave.pub/deploy/.flipped ]; then DEPLOY=/root/nave.pub/deploy; else DEPLOY=/root/noir/deploy; fi
cd "$DEPLOY" 2>/dev/null || { echo "no deploy dir"; exit 1; }

# Same consumer env as the brain: brokered creds stripped; LUKE_NSEC stays
# (the scribe signs scopes/wraps as luke — an on-box role key, NOT the
# Director's). Regenerate from luke.env when present.
CONSUMER="$DEPLOY/luke-consumer.env"
if [ -f "$DEPLOY/luke.env" ]; then
  grep -vE '^(ANTHROPIC_API_KEY|TELEGRAM_BOT_TOKEN)=' "$DEPLOY/luke.env" > "$CONSUMER" && chmod 600 "$CONSUMER"
fi
[ -f "$CONSUMER" ] || { echo "no consumer env ($CONSUMER) — run a deploy first"; exit 1; }

BRAINENV=""; NETARG=""; NET=""
if [ -f "$DEPLOY/brain.env" ]; then
  BRAINENV="--env-file $DEPLOY/brain.env"
  NET=$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' deploy-nactor-1 2>/dev/null)
  [ -n "$NET" ] && NETARG="--network $NET"
else
  echo "⚠ no brain.env — no LLM path in the consumer env; run ops/gen-brain-key.sh"
fi

mkdir -p "$DEPLOY/brain-state"
echo "── jaf-scribe ${FLAG:-(LIVE — issuing draft grants)} @ $(date -u +%FT%TZ) ──"
docker run --rm --env-file "$CONSUMER" $BRAINENV $NETARG \
  -e SCRIBE_LEDGER=/state/scribe-ledger.json \
  -v "$DEPLOY/brain-state:/state" \
  luke:latest node jaf-scribe.mjs $FLAG
echo "── scribe done ──"
