#!/usr/bin/env bash
# Make Luke keep punchlist.md honest on his own. Adds a "close the loop"
# directive to his always-on instructions (AGENTS.md) so he spots completions in
# ANY conversation and auto-checks them (confirming only when uncertain), plus a
# ledger-hygiene note to HEARTBEAT.md, and checks off the two items James has
# already reported done. Edits Luke's box-local, git-tracked workspace and
# commits there. Idempotent. No restart needed — the agent reads these files at
# runtime.
set -u
WS=/root/nave.pub/deploy/openclaw-state/.openclaw/workspace
cd "$WS" 2>/dev/null || { echo "no workspace at $WS"; exit 1; }

# The workspace is a bind mount owned by the container's openclaw user, but this
# ops step runs as root over SSH — so git refuses ("detected dubious ownership").
# Whitelist the path so the workspace commit below actually lands. Idempotent:
# git dedups safe.directory entries.
git config --global --add safe.directory "$WS" 2>/dev/null || true

MARK="Closing the loop — keep the punchlist true"
if grep -qF "$MARK" AGENTS.md 2>/dev/null; then
  echo "· AGENTS.md already has the directive — skipping"
else
  cat >> AGENTS.md <<'MD'

## Closing the loop — keep the punchlist true

`punchlist.md` is a live ledger, not a static list. Keep it honest on your own:

- **Spot completions as they happen.** Any time James signals — in ANY message,
  or in a morning discipline-check reply — that a punchlist item or a commitment
  is done ("done", "finished", "handled", "took care of", "completed", "✅"…),
  treat it as an instruction to update the ledger. Don't wait to be asked.
- **Act by default.** When it's clear which item he means, check it off in
  `punchlist.md` (`- [ ]` → `- [x]`, keep the text as a record), commit the
  workspace, and acknowledge in one short line ("✓ checked off: blue-tape
  upstairs"). Never re-surface a checked item.
- **Confirm only when genuinely uncertain.** If it's ambiguous which item he
  means, or whether it's truly closed vs. partial, ask ONE tight yes/no first
  ("Mark 'Write Epiq JD' done? y/n") and update on his yes. Certainty means just
  do it; uncertainty is the only reason to ask.
- **New commitments too.** If he mentions a new to-do or promise, add it to
  `punchlist.md` (unchecked) so nothing is lost — same reflex, other direction.
- The morning stale-item flag and the briefing read ONLY open `- [ ]` items, so a
  properly-closed loop never nags him about something already finished.
MD
  echo "✓ appended close-the-loop directive to AGENTS.md"
fi

if grep -qF "Ledger hygiene" HEARTBEAT.md 2>/dev/null; then
  echo "· HEARTBEAT.md already has the ledger-hygiene note — skipping"
else
  cat >> HEARTBEAT.md <<'MD'

## Ledger hygiene (every heartbeat)
Before flagging any stale item, reconcile `punchlist.md` with what James has
actually reported: check off (`- [ ]` → `- [x]`) anything he's said is done since
the list was last touched, and add anything he newly committed to. Only OPEN
items are eligible to be flagged or briefed — never nag about something finished.
See "Closing the loop" in `AGENTS.md`.
MD
  echo "✓ appended ledger-hygiene note to HEARTBEAT.md"
fi

# Check off the two items James has confirmed complete.
sed -i 's/^- \[ \] \(.*Blue tape the upstairs.*\)/- [x] \1/' punchlist.md
sed -i 's/^- \[ \] \(.*Write Epiq job description.*\)/- [x] \1/' punchlist.md
echo "-- punchlist (those two items now) --"
grep -nE '\[[ x]\].*(Blue tape the upstairs|Write Epiq job)' punchlist.md || echo "  (items not found — check punchlist format)"

git add AGENTS.md HEARTBEAT.md punchlist.md 2>/dev/null
git -c user.email=luke@nave.pub -c user.name=Luke \
  commit -q -m "close-the-loop: auto-reconcile punchlist on reported completions; check off blue-tape + Epiq JD" 2>&1 | tail -2 \
  || echo "(nothing to commit / workspace git skipped)"
echo "== done — Luke now reconciles completions automatically =="
