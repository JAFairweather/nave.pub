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

# Same consumer env as the brain: brokered creds stripped. The scribe signs as
# JAMES'S QUILL (npub13uuznpc…) — the Director's own reconnection-agent instance,
# already minted + profiled in warm.contact — NOT as luke (nact#26, AD-10) and
# NOT as any key minted here. quill.env holds James's Quill's QUILL_NSEC, which
# the Director provides; its sovereign home is the Mac (warm.contact#43).
# Regenerate the consumer env from luke.env when present.
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

QUILLENV="$DEPLOY/quill.env"
if [ ! -f "$QUILLENV" ]; then
  echo "✗ no quill.env — the scribe signs as JAMES'S QUILL (npub13uuznpc…), the"
  echo "  personal instance already minted in warm.contact (scripts/mint-quill-identity.sh)."
  echo "  Its key is the Director's; it is NEVER minted here. To run the interim box"
  echo "  scribe, the Director drops James's Quill's nsec into $QUILLENV as QUILL_NSEC."
  echo "  The sovereign home for this identity is the Mac (warm.contact#43), where its"
  echo "  key lives — the box path is an opt-in interim, not a new key."
  exit 1
fi

mkdir -p "$DEPLOY/brain-state"
echo "── jaf-scribe ${FLAG:-(LIVE — issuing draft grants)} @ $(date -u +%FT%TZ) ──"
docker run --rm --env-file "$CONSUMER" --env-file "$QUILLENV" $BRAINENV $NETARG \
  -e SCRIBE_LEDGER=/state/scribe-ledger.json \
  -v "$DEPLOY/brain-state:/state" \
  luke:latest node jaf-scribe.mjs $FLAG
echo "── scribe done ──"
