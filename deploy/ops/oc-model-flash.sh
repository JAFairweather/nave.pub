#!/usr/bin/env bash
# Move Luke off gemini-3.1-pro-preview: the primary engine model becomes Gemini 3.5 Flash with low thinking.
# Pro was set at OpenClaw's first setup and never revisited; it is the dearest Gemini tier, a preview (the
# tightest rate limits), and its ~32k-token turns share the Google project's quota with the R1's spoken summaries.
# Idempotent; backs up openclaw.json first; prints model names and counts only.
#
#   Ops → run-script → oc-model-flash.sh
#
# What it does:
#   1. agents.defaults.model.primary → MODEL, agents.defaults.thinkingDefault → THINK, through the engine's own
#      `openclaw config set` (schema-checked: a key this build doesn't know fails here, before any restart).
#      Fallbacks are left as they are; Pro stays selectable with /model for a hard task.
#   2. an agents.list entry that pins its own Pro model is moved to MODEL too (named, never silently kept)
#   3. sessions holding a /model override are counted: they keep their model until /model or /new
#   4. restart openclaw, wait up to 5 min for healthy, then look for a live call to MODEL answered 200.
#      Unhealthy → the backup is restored and openclaw recreated.
set -u
MODEL=google/gemini-3.5-flash
THINK=low
OLD=google/gemini-3.1-pro-preview
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
cd "$D"
J="$D/openclaw-state/.openclaw/openclaw.json"
S="$D/openclaw-state/.openclaw/agents/main/sessions/sessions.json"
OC=deploy-openclaw-1
command -v jq >/dev/null || { echo "jq required"; exit 1; }
[ -f "$J" ] || { echo "no openclaw.json at $J"; exit 1; }
docker inspect -f '{{.State.Running}}' "$OC" 2>/dev/null | grep -qx true || { echo "$OC is not running"; exit 1; }
oc() { docker exec -i "$OC" "$@" </dev/null; }

B="$J.bak-model-flash-$(date +%Y%m%d%H%M%S)"
cp "$J" "$B"
echo "── before ──"
jq -r '"  primary:   \(.agents.defaults.model.primary // .agents.defaults.model // "?")",
       "  fallbacks: \((.agents.defaults.model | objects | .fallbacks) // [] | join(", "))",
       "  thinking:  \(.agents.defaults.thinkingDefault // "(unset)")",
       "  allowlist: \(.agents.defaults.models // {} | keys | length) model(s)",
       "  per-agent: \([.agents.list[]? | select(.model != null) | "\(.id)=\(.model.primary? // .model)"] | join(", ") | if . == "" then "none" else . end)"' "$J"

echo
echo "── 1. primary + thinking ──"
# With an allowlist (agents.defaults.models), a primary outside it is refused: add MODEL, keep the rest.
if jq -e '.agents.defaults.models | type == "object"' "$J" >/dev/null 2>&1 && ! jq -e --arg m "$MODEL" '.agents.defaults.models | has($m)' "$J" >/dev/null; then
  oc openclaw config set "agents.defaults.models[\"$MODEL\"]" '{}' --strict-json >/dev/null \
    || { echo "  ✗ could not add $MODEL to the allowlist"; exit 1; }
  echo "  ✓ $MODEL added to the allowlist"
fi
oc openclaw config set agents.defaults.model.primary "\"$MODEL\"" --strict-json >/dev/null \
  || { echo "  ✗ config set primary failed — nothing restarted"; cp "$B" "$J"; exit 1; }
oc openclaw config set agents.defaults.thinkingDefault "\"$THINK\"" --strict-json >/dev/null \
  || { echo "  ✗ config set thinkingDefault failed — nothing restarted"; cp "$B" "$J"; exit 1; }
echo "  ✓ primary $MODEL, thinking $THINK"

echo
echo "── 2. per-agent pins ──"
if jq -e --arg o "$OLD" '[.agents.list[]? | select((.model.primary? // .model) == $o)] | length > 0' "$J" >/dev/null 2>&1; then
  jq --arg o "$OLD" --arg m "$MODEL" '
    .agents.list |= map(if (.model | type) == "string" and .model == $o then .model = $m
                        elif (.model | type) == "object" and .model.primary == $o then .model.primary = $m
                        else . end)' "$J" > "$J.tmp" && mv "$J.tmp" "$J"
  echo "  ✓ moved to $MODEL: $(jq -r --arg m "$MODEL" '[.agents.list[] | select((.model.primary? // .model) == $m) | .id] | join(", ")' "$J")"
else
  echo "  none pin $OLD"
fi
chown 1000:1000 "$J" 2>/dev/null || true

echo
echo "── 3. sessions with their own model ──"
if [ -f "$S" ]; then
  jq -r '[to_entries[] | select(.value.modelOverride != null)] | "  \(length) session(s) keep a /model override\(if length > 0 then ": " + (map("\(.key) → \(.value.modelOverride)") | join(", ")) else "" end)"' "$S" 2>/dev/null \
    || echo "  (sessions store unreadable — skipped)"
  echo "  (those keep their model: type /model $MODEL in them, or /new)"
else
  echo "  no sessions store at the expected path — skipped"
fi

echo
echo "── 4. restart + verify ──"
docker compose up -d --force-recreate --no-deps openclaw >/dev/null 2>&1 && echo "  recreated"
# Up to 5 min: a boot that probes the model takes over a minute (the first run, 2026-10-25, was still
# "starting" at 60 s and rolled back for nothing). Only "unhealthy", or not healthy by then, restores.
for i in $(seq 1 60); do
  ST="$(docker inspect --format '{{.State.Health.Status}}' "$OC" 2>/dev/null || echo '?')"
  [ "$ST" = healthy ] && { echo "  openclaw: healthy after $((i * 5)) s"; break; }
  [ "$ST" = unhealthy ] && break
  sleep 5
done
if [ "${ST:-}" != healthy ]; then
  echo "  ✗ not healthy (status: ${ST:-unknown}) — restoring $(basename "$B") and recreating"
  # Why, before the recreate throws this container away: restarts, the last exit, the health probe's own
  # output, and the log's error lines (the tail alone is just the next boot's startup phases).
  echo "  restarts: $(docker inspect -f '{{.RestartCount}}' "$OC" 2>/dev/null), last exit: $(docker inspect -f '{{.State.ExitCode}} {{.State.Error}}' "$OC" 2>/dev/null)"
  echo "  health probe (last 3):"
  docker inspect -f '{{range .State.Health.Log}}{{.ExitCode}} {{.Output}}{{"\n"}}{{end}}' "$OC" 2>/dev/null | grep -v '^$' | tail -3 | cut -c1-300 | sed 's/^/    /'
  echo "  log errors:"
  docker logs --tail 600 "$OC" 2>&1 | grep -iE 'error|fatal|invalid|unknown|unsupported|exit|thinking|gemini-3\.5' | grep -v 'startup phase' | tail -25 | cut -c1-300 | sed 's/^/  | /'
  cp "$B" "$J"; chown 1000:1000 "$J" 2>/dev/null || true
  docker compose up -d --force-recreate --no-deps openclaw >/dev/null 2>&1
  exit 1
fi
# A live call to the new model, answered 200 (boot usually fires one; else the next turn or beat will).
NAME=${MODEL#google/}
for i in $(seq 1 18); do
  LOGS=$(docker logs --tail 400 "$OC" 2>&1)
  echo "$LOGS" | grep -q "model-fetch] start .*$NAME" && echo "$LOGS" | grep -qE 'model-fetch] response provider=google .*status=200' && { OK=1; break; }
  sleep 10
done
if [ "${OK:-}" = 1 ]; then
  echo "  ✓ a call to $NAME went out and was answered 200:"
  docker logs --tail 400 "$OC" 2>&1 | grep -E "model-fetch] (start .*$NAME|response provider=google)" | tail -2 | sed 's/^/    /'
else
  echo "  · no call to $NAME seen in 3 min — healthy, so not rolled back; send Luke a message and check luke-logs"
fi
echo "== model-flash done — backup: $(basename "$B") =="
