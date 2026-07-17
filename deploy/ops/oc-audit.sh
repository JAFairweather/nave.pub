#!/usr/bin/env bash
# READ-ONLY audit: how fully is Luke's OpenClaw actually employed?
# Prints structure, names, flags, schedules, and sizes — NEVER secret values or
# personal file contents. Every key matching token/secret/password/nsec/apikey/
# credential/auth/env is redacted before printing, so this is public-log safe.
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
cd "$D"
ST="$D/openclaw-state/.openclaw"
J="$ST/openclaw.json"
RED='walk(if type=="object" then with_entries(if (.key|test("token|secret|password|nsec|api-?key|credential|auth|cookie";"i")) then .value="•••" elif .key=="env" then .value="•••" else . end) else . end)'

echo "===== 1. engine ====="
docker inspect --format 'image: {{.Config.Image}}' deploy-openclaw-1 2>/dev/null
docker logs deploy-openclaw-1 2>&1 | grep -oiE 'v?2026\.[0-9]+\.[0-9]+' | tail -1
echo
echo "===== 2. config top-level keys ====="
jq -r 'keys | join("  ")' "$J" 2>/dev/null || { echo "(no openclaw.json at $J)"; }
echo
echo "===== 3. agents (ids + workspaces only) ====="
jq -r '.agents | if type=="object" then (.list // [.]) else (. // []) end
       | map({id: (.id // .name // "default"), workspace: (.workspace // null), model: (.model // null)})' "$J" 2>/dev/null | head -40
echo
echo "===== 4. channels (which, enabled) ====="
jq -r '.channels // {} | to_entries | map({channel: .key, enabled: (.value.enabled // "?")})' "$J" 2>/dev/null
echo
echo "===== 5. gateway + heartbeat + dream-ish config (redacted) ====="
jq -r "$RED | {gateway: (.gateway // {}), heartbeat: (.agents.defaults.heartbeat // .heartbeat // \"(not set)\"), dream: (.dream // .agents.defaults.dream // \"(no dream key)\"), memory: (.memory // .agents.defaults.memory // \"(no memory key)\"), compaction: (.agents.defaults.compaction // \"(default)\")}" "$J" 2>/dev/null | head -60
echo
echo "===== 6. cron / scheduled work =====";
jq -r '.cron // "(no cron key in config)"' "$J" 2>/dev/null | head -30
for f in "$ST/cron/jobs.json" "$ST/cron.json"; do
  [ -f "$f" ] && { echo "--- $f ---"; jq -r 'if type=="object" then (.jobs // []) else . end | map({name: (.name // .id), schedule: (.schedule // .cron // .expr // null), enabled: (.enabled // true)})' "$f" 2>/dev/null | head -40; }
done
echo "--- box crontab (names/paths only) ---"
crontab -l 2>/dev/null | grep -v '^#' | sed 's/--env-file [^ ]*/--env-file …/g' | head -10
echo
echo "===== 7. workspace (Luke's brain files — names+sizes only) ====="
ls -la "$ST/workspace" 2>/dev/null | awk '{print $5, $9}' | grep -v '^$' | head -30
echo "--- memory dir (most recent) ---"
ls -lat "$ST/workspace/memory" 2>/dev/null | awk '{print $5, $6, $7, $9}' | head -12
[ -f "$ST/workspace/MEMORY.md" ] && echo "MEMORY.md: $(wc -l < "$ST/workspace/MEMORY.md") lines"
echo
echo "===== 8. skills — installed vs bundled ====="
echo "--- workspace/custom skills ---"
ls "$ST/workspace/skills" 2>/dev/null | head -30 || echo "(none)"
ls "$ST/skills" 2>/dev/null | head -30 || true
echo "--- bundled in the engine image ---"
docker compose exec -T openclaw sh -lc 'ls /app/skills 2>/dev/null | head -80' 2>/dev/null || echo "(no /app/skills)"
echo
echo "===== 9. nodes / paired devices ====="
jq -r '.nodes // "(no nodes key)"' "$J" 2>/dev/null | head -20
ls "$ST/devices" 2>/dev/null | head -10 || echo "(no devices dir)"
ls "$ST/nodes" 2>/dev/null | head -10 || true
echo
echo "===== 10. does THIS build know 'dreaming'? (source grep, counts only) ====="
docker compose exec -T openclaw sh -lc 'timeout 25 grep -rioE "dream(ing|s)?" /app/dist /app/src /app/*.js 2>/dev/null | cut -d: -f2- | tr "[:upper:]" "[:lower:]" | sort | uniq -c | sort -rn | head -6; echo "(heartbeat refs: $(timeout 20 grep -rio "heartbeat" /app/dist 2>/dev/null | wc -l))"' 2>/dev/null || echo "(grep unavailable)"
echo
echo "===== 12. engine inventory — skills/tools/browser/commands/models/plugins config ====="
jq -r "$RED | {skills: (.skills // \"(none)\"), tools: (.tools // \"(none)\"), browser: (.browser // \"(none)\"), commands: (.commands // \"(none)\"), models: (.models | if type==\"object\" then keys else (. // \"(none)\") end), plugins: (.plugins | if type==\"object\" then (to_entries | map({(.key): (if (.value|type)==\"object\" then (.value|keys) else .value end)})) else (. // \"(none)\") end)}" "$J" 2>/dev/null | head -100
echo "--- engine CLI inventory (skills + cron, if the CLI exists) ---"
docker compose exec -T openclaw sh -lc 'command -v openclaw >/dev/null 2>&1 && { echo "[skills list]"; timeout 20 openclaw skills list 2>&1 | head -50; echo; echo "[cron list]"; timeout 15 openclaw cron list 2>&1 | head -20; } || echo "(no openclaw CLI in PATH)"' 2>/dev/null || echo "(exec failed)"
echo
echo "===== 11. box resources (for the Hostinger question) ====="
echo "cores: $(nproc)"; free -h | head -2; df -h / | tail -1; uptime
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' 2>/dev/null | head -12
echo
echo "== oc-audit done (read-only, redacted) =="
