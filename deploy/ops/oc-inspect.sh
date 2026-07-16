#!/usr/bin/env bash
# Survey the OpenClaw state to inform improvement proposals — STRUCTURE and
# CONFIG only, never the content of personal memory. Prints:
#   • directory shape + sizes
#   • openclaw.json config keys (agents, model, channels, cron, gateway auth)
#   • agent names + their instruction FILE SIZES (not contents)
#   • memory index shape: table names + row counts (not rows)
#   • cron schedule entries
# Reads the box-local migrated COPY by default; falls back to the live
# Hostinger state dir if the copy isn't present. Read-only: no writes, no
# secrets printed.
set -u
STATE=/root/nave.pub/deploy/openclaw-state/.openclaw
[ -d "$STATE" ] || STATE=/docker/openclaw-kajk/data/.openclaw
[ -d "$STATE" ] || { echo "no openclaw state found"; exit 1; }
echo "== state root: $STATE =="
echo
echo "== top-level shape (depth 2, dirs + sizes) =="
du -h --max-depth=2 "$STATE" 2>/dev/null | sort -rh | head -40
echo
echo "== openclaw.json — config keys (values redacted for secret-ish keys) =="
CFG="$STATE/openclaw.json"
if [ -f "$CFG" ]; then
  # Print structure with jq if present; redact anything that looks secret.
  if command -v jq >/dev/null 2>&1; then
    jq '
      def redact: if type=="string" and (test("[A-Za-z0-9_-]{24,}")) then "«redacted»" else . end;
      walk(if type=="object" then with_entries(
        if (.key|test("token|secret|key|apiKey|password";"i")) then .value="«redacted»" else . end
      ) else . end)
      | {version: .meta.lastTouchedVersion, model: (.model // .agents.main.model // "?"),
         gatewayAuthMode: (.gateway.auth.mode // "?"),
         channels: (.channels // {} | keys),
         agents: (.agents // {} | keys),
         cronKeys: (.cron // {} | keys),
         topKeys: keys}
    ' "$CFG" 2>/dev/null || echo "(jq parse failed; raw key list:)"
    command -v jq >/dev/null 2>&1 || true
  fi
  echo "── raw top-level keys ──"
  grep -oE '^\s{2}"[a-zA-Z0-9_]+"' "$CFG" 2>/dev/null | tr -d ' "' | sort -u | head -60
else
  echo "(no openclaw.json at $CFG)"
fi
echo
echo "== agents dir — names + instruction sizes (NOT contents) =="
AG="$STATE/agents"
if [ -d "$AG" ]; then
  for d in "$AG"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    size=$(du -sh "$d" 2>/dev/null | cut -f1)
    files=$(find "$d" -type f 2>/dev/null | wc -l)
    echo "  • $name  ($size, $files files)"
    # list the notable config/instruction files by name+size only
    find "$d" -maxdepth 1 -type f \( -name '*.json' -o -name '*.md' -o -name '*.txt' \) -printf '      %f (%s bytes)\n' 2>/dev/null | head -12
  done
else
  echo "(no agents dir)"
fi
echo
echo "== memory — index shape (table names + ROW COUNTS only, never rows) =="
for db in $(find "$STATE" -maxdepth 3 -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' 2>/dev/null | head -10); do
  echo "  db: ${db#$STATE/}"
  if command -v sqlite3 >/dev/null 2>&1; then
    for t in $(sqlite3 "$db" ".tables" 2>/dev/null); do
      n=$(sqlite3 "$db" "select count(*) from \"$t\";" 2>/dev/null)
      echo "      $t: $n rows"
    done
  else
    echo "      (sqlite3 not installed — size $(du -h "$db" 2>/dev/null | cut -f1))"
  fi
done
echo
echo "== cron / schedule files (names + sizes) =="
find "$STATE" -path '*cron*' -type f -printf '  %p (%s bytes)\n' 2>/dev/null | sed "s#$STATE/##" | head -20
echo "== done =="
