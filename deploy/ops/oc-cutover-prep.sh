#!/usr/bin/env bash
# Cutover Step 0 — capture the LIVE OpenClaw's provider env into a box-local
# openclaw.env for the self-hosted service. Run while the OLD instance is still
# UP (this reads from it). Never prints a secret value — only the names written.
# The Gemini/agent credentials also ride along inside the migrated state
# (OpenClaw's auth store), so this env is belt-and-suspenders for anything
# OpenClaw reads from the environment. Same exposure as the live instance today
# (root-only, gitignored); brokering these through the NCP proxy is the next step.
set -u
LIVE=openclaw-kajk-openclaw-1
OUT=/root/nave.pub/deploy/openclaw.env
docker inspect "$LIVE" >/dev/null 2>&1 || { echo "live container $LIVE not found — is it already retired?"; exit 1; }

: > "$OUT.tmp"
wrote=""
for v in ANTHROPIC_API_KEY GEMINI_API_KEY GOOGLE_API_KEY GOOGLE_GENERATIVE_AI_API_KEY OPENAI_API_KEY; do
  val=$(docker exec "$LIVE" printenv "$v" 2>/dev/null || true)
  if [ -n "$val" ]; then printf '%s=%s\n' "$v" "$val" >> "$OUT.tmp"; wrote="$wrote $v"; fi
done
tz=$(docker exec "$LIVE" printenv TZ 2>/dev/null || true)
printf 'TZ=%s\n' "${tz:-America/New_York}" >> "$OUT.tmp"
mv "$OUT.tmp" "$OUT"; chmod 600 "$OUT"
echo "wrote $OUT — provider vars captured (names only):${wrote:- (none in env; they ride in the migrated state)}  + TZ"
echo "next: you stop the old container in hPanel + remove the :57419 port, then I resync + patch + bring up the new one."
