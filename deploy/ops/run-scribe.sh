#!/usr/bin/env bash
# RETIRED 2026-07-24 — the Director's drafting hand lives on the Mac now.
#
# James's Quill drafting has relocated to the sovereign device (warm.contact#43,
# stages 1+2 live): `warm quill-draft` composes on the Mac that holds the key,
# through the Director's `credential:anthropic` grant, and seals each draft to
# his npub PEN-DIRECT — the desk verifies the pen cryptographically (nact#44 /
# ngage#11). First light landed 2026-07-24. This box path was an opt-in interim
# that was never taken (no quill.env, no cron), and the whole point of AD-10 is
# that the drafting key never touches the box — so the interim is now sealed.
#
# This runner refuses by default. It is kept, not deleted, only as documented
# break-glass: if the Mac is unavailable AND the Director explicitly chooses to
# place his key on the box for one run, set SCRIBE_ALLOW_BOX=1. That choice
# copies a sovereign key onto shared infrastructure — prefer the Mac.
#
#   warm quill-draft --dry-run          # the sovereign path (on the Mac)
#   SCRIBE_ALLOW_BOX=1 bash run-scribe.sh --dry-run   # break-glass only
set -u
FLAG="${1:-}"
if [ -f /root/nave.pub/deploy/.flipped ]; then DEPLOY=/root/nave.pub/deploy; else DEPLOY=/root/noir/deploy; fi

# --- BUNKER MODE (luke#25): the sanctioned always-on drafter -----------------
# If quill-bunker.env is present, the scribe signs as jaf-quill-bunker over a
# scoped NIP-46 connection to Bunker46 (SCRIBE_SIGNER=nip46 + SCRIBE_BUNKER_URI
# in that sealed env). The key NEVER touches this host — so this is a first-class
# run (typically scheduled by Luke from OpenClaw), not break-glass, and needs no
# quill.env and no SCRIBE_ALLOW_BOX. This is the path that resolves the AD-10
# objection that retired the raw-key scribe.
BUNKERENV="$DEPLOY/quill-bunker.env"
if [ -f "$BUNKERENV" ]; then
  cd "$DEPLOY" 2>/dev/null || { echo "no deploy dir"; exit 1; }
  CONSUMER="$DEPLOY/nave-consumer.env"
  [ -f "$DEPLOY/nave.env" ] && grep -vE '^(ANTHROPIC_API_KEY|TELEGRAM_BOT_TOKEN)=' "$DEPLOY/nave.env" > "$CONSUMER" && chmod 600 "$CONSUMER"
  [ -f "$CONSUMER" ] || { echo "no consumer env ($CONSUMER) — run a deploy first"; exit 1; }
  BRAINENV=""; NETARG=""
  if [ -f "$DEPLOY/brain.env" ]; then
    BRAINENV="--env-file $DEPLOY/brain.env"
    NET=$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' deploy-nactor-1 2>/dev/null)
    [ -n "$NET" ] && NETARG="--network $NET"
  fi
  mkdir -p "$DEPLOY/brain-state"
  # The scheduler caps drafts per run (MAX_DRAFTS) — forward it only when the
  # caller sets it, so ad-hoc runs keep the scribe's own default.
  MAXARG=""
  [ -n "${MAX_DRAFTS:-}" ] && MAXARG="-e MAX_DRAFTS=$MAX_DRAFTS"
  echo "── jaf-scribe ${FLAG:-(LIVE)} @ $(date -u +%FT%TZ) [BUNKER — key in Bunker46${MAX_DRAFTS:+, max $MAX_DRAFTS drafts}] ──"
  docker run --rm --env-file "$CONSUMER" --env-file "$BUNKERENV" $BRAINENV $NETARG $MAXARG \
    -e SCRIBE_LEDGER=/state/scribe-ledger.json \
    -v "$DEPLOY/brain-state:/state" \
    luke:latest node jaf-scribe.mjs $FLAG
  echo "── scribe done (bunker) ──"
  exit 0
fi

# --- RAW-KEY-ON-BOX (retired; break-glass only) ------------------------------
if [ "${SCRIBE_ALLOW_BOX:-}" != "1" ]; then
  echo "✗ the raw-key box scribe is RETIRED (2026-07-24). Configure BUNKER mode instead"
  echo "  (drop quill-bunker.env with SCRIBE_SIGNER=nip46 + SCRIBE_BUNKER_URI — the key stays"
  echo "  in Bunker46, luke#25), or draft on the Mac ('warm quill-draft', warm.contact#43)."
  echo "  Raw key on the box is break-glass only: SCRIBE_ALLOW_BOX=1 bash run-scribe.sh"
  exit 1
fi

echo "⚠ BREAK-GLASS: running the retired RAW-KEY box scribe. This places James's Quill's key on"
echo "  shared infrastructure. Prefer BUNKER mode (quill-bunker.env) or the Mac (warm.contact#43)."
cd "$DEPLOY" 2>/dev/null || { echo "no deploy dir"; exit 1; }

# Same consumer env as the brain: brokered creds stripped. The scribe signs as
# JAMES'S QUILL (npub13uuznpc…); quill.env holds its QUILL_NSEC, which the
# Director provides for this one break-glass run and should remove after.
CONSUMER="$DEPLOY/nave-consumer.env"
if [ -f "$DEPLOY/nave.env" ]; then
  grep -vE '^(ANTHROPIC_API_KEY|TELEGRAM_BOT_TOKEN)=' "$DEPLOY/nave.env" > "$CONSUMER" && chmod 600 "$CONSUMER"
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
  echo "✗ no quill.env — break-glass still needs the Director to place James's Quill's"
  echo "  nsec into $QUILLENV as QUILL_NSEC for this one run, then remove it. Prefer the Mac."
  exit 1
fi

mkdir -p "$DEPLOY/brain-state"
echo "── jaf-scribe ${FLAG:-(LIVE — issuing draft grants)} @ $(date -u +%FT%TZ) [BREAK-GLASS] ──"
docker run --rm --env-file "$CONSUMER" --env-file "$QUILLENV" $BRAINENV $NETARG \
  -e SCRIBE_LEDGER=/state/scribe-ledger.json \
  -v "$DEPLOY/brain-state:/state" \
  luke:latest node jaf-scribe.mjs $FLAG
echo "── scribe done ──"
