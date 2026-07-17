#!/usr/bin/env bash
# Review P1c — reframe HEARTBEAT.md to the real two-beat schedule.
# The native heartbeat is OFF; two cron beats (07:00 / 22:00) drive it. This
# renames the stale "heartbeat tick" / "midday tick" framing to "beats" so the
# file describes what actually runs. NO content or behavior change — the
# discipline check, briefing, standing context, nostr scan, post idea, evening
# close-the-loop and ledger-hygiene rules are all untouched. Done in place with
# sed so James's personal standing-context never leaves the box.
set -u
WS=/root/nave.pub/deploy/openclaw-state/.openclaw/workspace
cd "$WS" 2>/dev/null || { echo "no workspace at $WS"; exit 1; }
git config --global --add safe.directory "$WS" 2>/dev/null || true
cp HEARTBEAT.md HEARTBEAT.md.pre-review
sed -i \
  -e 's|On every heartbeat you read this file and decide|When a beat fires, follow this file and decide|' \
  -e 's|## By time of day|## The two daily beats|' \
  -e 's|\*\*Morning (first tick[^*]*\*\*|**Morning beat — 07:00**|' \
  -e 's|\*\*Midday (ticks[^*]*\*\*|**Between the beats (no scheduled midday check)**|' \
  -e 's|\*\*Evening (last tick[^*]*\*\*|**Evening beat — 22:00**|' \
  -e 's|## Ledger hygiene (every heartbeat)|## Ledger hygiene (every beat)|' \
  HEARTBEAT.md
echo "-- reframed lines (framing only; no personal content) --"
grep -nE 'When a beat fires|## The two daily beats|Morning beat —|Between the beats|Evening beat —|Ledger hygiene \(every beat\)' HEARTBEAT.md || echo "(no matches — patterns need a look)"
git add HEARTBEAT.md
git -c user.email=luke@nave.pub -c user.name=Luke \
  commit -q -m "review P1: reframe HEARTBEAT.md to the two-beat schedule (tick/midday language -> beats; no content change)" 2>&1 | tail -2 \
  || echo "(nothing to commit / workspace git skipped)"
echo "== review P1c applied — Phase A complete =="
