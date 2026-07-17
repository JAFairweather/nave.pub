#!/usr/bin/env bash
# Punchlist split — teach Luke to keep punchlist.md in TWO tracks (Renovation vs
# Commitments) and present them appropriately in the beats. Edits ONLY AGENTS.md
# (Luke's operating manual). The actual reorg of existing items is left to Luke,
# who alone has the private context to categorize them correctly — this script
# never reads or prints any punchlist content. Commits the workspace as Luke with
# a backup. Idempotent (guarded by a marker).
set -u
WS=/root/nave.pub/deploy/openclaw-state/.openclaw/workspace
cd "$WS" 2>/dev/null || { echo "no workspace at $WS"; exit 1; }
git config --global --add safe.directory "$WS" 2>/dev/null || true
[ -f AGENTS.md ] || { echo "no AGENTS.md in workspace"; exit 1; }

if grep -q 'The punchlist has two tracks' AGENTS.md; then
  echo "· two-track policy already present — nothing to do"; exit 0
fi

cp AGENTS.md AGENTS.md.pre-punchsplit
cat >> AGENTS.md <<'AGENTS_EOF'

## The punchlist has two tracks
`punchlist.md` is kept in two clearly-headed sections — never merge them:

- **## 🔨 Renovation** — house/property project tasks (paint, tile, blue-tape, fixtures,
  contractor follow-ups). Steady-progress work: track them and surface the next concrete
  action when James asks, or when one is clearly stalled — but don't nag the whole list
  every morning. Momentum, not pressure.
- **## 📋 Commitments** — the personal & professional promises James made (a JD to write, a
  call to return, a deadline he set). These ARE the accountability items: the morning
  discipline-check leads with these — the open ones, and any going stale — because these are
  what decide whether the day held to its word.

Keeping it true:
- New items go under the right track. When James signals one done, check it off in place
  (same close-the-loop reflex) — never move a checked item between tracks.
- Both beats read OPEN `- [ ]` items from BOTH sections, but PRESENT them by track:
  Commitments first (accountability), Renovation second (progress).
- If `punchlist.md` is still a single flat list, reorganize it into these two sections the
  first time you touch it — keep every item and its checked/unchecked state exactly. You're
  sorting, not editing.
AGENTS_EOF

echo "✓ AGENTS.md: two-track punchlist policy added ($(wc -l < AGENTS.md) lines, was $(wc -l < AGENTS.md.pre-punchsplit))"
git add AGENTS.md
git -c user.email=luke@nave.pub -c user.name=Luke \
  commit -q -m "punchlist: two-track policy (Renovation / Commitments)" 2>&1 | tail -1 \
  || echo "(nothing to commit)"
echo "== punchlist two-track policy applied — Luke reorganizes the items himself =="
