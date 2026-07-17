#!/usr/bin/env bash
# Phase 1 — "turn the engine on": enable heartbeat + nightly dreaming, and tidy
# Luke's workspace. Idempotent; backs up openclaw.json first; prints structure
# and counts only (never memory contents — they're personal).
#
#   Ops → run-script → oc-engine-on.sh
#
# What it does:
#   1. heartbeat.every 0m → 30m (the rest — flash model, isolatedSession,
#      lightContext, activeHours 07-22 ET, telegram target — is already set)
#   2. dreaming on: nightly sweep (default 03:00) in memory-core, ET timezone,
#      Dream-Diary subagent pinned to the cheap flash model
#   3. workspace hygiene: stray logs + stale .pre-*/.bak/.retired backups moved
#      to workspace/data/archive/ so they never pollute Luke's context
#   4. restart openclaw + verify health
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
cd "$D"
J="$D/openclaw-state/.openclaw/openclaw.json"
W="$D/openclaw-state/.openclaw/workspace"
command -v jq >/dev/null || { echo "jq required"; exit 1; }
[ -f "$J" ] || { echo "no openclaw.json at $J"; exit 1; }

cp "$J" "$J.bak-engine-on-$(date +%Y%m%d%H%M%S)"
echo "── 1+2. config: heartbeat 30m + dreaming on ──"
echo "plugins present: $(jq -r '.plugins.entries // {} | keys | join(" ")' "$J" 2>/dev/null | cut -c1-200)"
jq '
  # heartbeat lives under agents.defaults on this box; patch wherever it exists,
  # defaulting to agents.defaults if neither block is present yet.
  ( if (.agents.defaults.heartbeat // null) != null then .agents.defaults.heartbeat.every = "30m"
    elif (.heartbeat // null) != null            then .heartbeat.every = "30m"
    else .agents.defaults.heartbeat = { every: "30m" } end )
  # dreaming: official keys per docs — plugins.entries.memory-core.config.dreaming
  | .plugins.entries."memory-core".config.dreaming.enabled = true
  | .plugins.entries."memory-core".config.dreaming.timezone = "America/New_York"
  | .plugins.entries."memory-core".config.dreaming.model = "google/gemini-3-flash-preview"
  | .plugins.entries."memory-core".subagent.allowModelOverride = true
' "$J" > "$J.tmp" && mv "$J.tmp" "$J"
chown 1000:1000 "$J" 2>/dev/null || true
echo "heartbeat.every now: $(jq -r '.agents.defaults.heartbeat.every // .heartbeat.every // "?"' "$J")"
echo "dreaming now: $(jq -c '.plugins.entries."memory-core".config.dreaming // "?"' "$J")"

echo
echo "── 3. workspace hygiene (names only) ──"
mkdir -p "$W/data/archive"
moved=0
for f in "$W"/full_log.txt "$W"/long_log.txt "$W"/doc.txt "$W"/models.txt \
         "$W"/*.pre-* "$W"/*.bak-* "$W"/*.retired; do
  [ -f "$f" ] || continue
  mv "$f" "$W/data/archive/" && { echo "  archived: $(basename "$f")"; moved=$((moved+1)); }
done
chown -R 1000:1000 "$W/data/archive" 2>/dev/null || true
echo "  ($moved file(s) archived)"

echo
echo "── 4. restart + verify ──"
docker compose up -d --force-recreate --no-deps openclaw >/dev/null 2>&1 && echo "  recreated"
for i in $(seq 1 20); do
  ST="$(docker inspect --format '{{.State.Health.Status}}' deploy-openclaw-1 2>/dev/null || echo '?')"
  [ "$ST" = healthy ] && { echo "  openclaw: healthy"; break; }
  sleep 3
done
[ "${ST:-}" = healthy ] || { echo "  ✗ not healthy yet (status: ${ST:-unknown}) — check luke-logs/ops status"; exit 1; }
docker logs deploy-openclaw-1 2>&1 | tail -5 | sed 's/^/  | /'
echo "== engine-on done — first heartbeat within ~30m (07:00–22:00 ET); first dream tonight ~03:00 =="
