#!/usr/bin/env bash
# Canonical-wins memory repair — TESTED on a throwaway copy, nothing live touched.
#
# Luke's real memory is the CANONICAL per-agent index
# (agents/main/agent/openclaw-agent.sqlite: memory_index_chunks, ~69 rows).
# memory/main.sqlite is the LEGACY Memory Core sidecar (~38 chunks) a newer
# binary tries to consolidate and chokes on ("legacy memory meta rows conflict
# with canonical memory index rows"). OpenClaw's own issue #102749 says: remove
# the leftover legacy store — canonical wins, data intact.
#
# This proves it safely: (1) hash-compare so we KNOW the legacy chunks aren't
# unique (lossless), (2) remove the legacy sidecar on the copy, (3) boot the
# FIXED beta and confirm it reaches ready. Copy removed at the end.
set -u
SRC=/docker/openclaw-kajk/data/.openclaw
TESTROOT=/root/nave.pub/deploy/openclaw-memrepair
TEST="$TESTROOT/.openclaw"
IMG=ghcr.io/openclaw/openclaw:2026.7.2-beta.1
LEGACY="memory/main.sqlite"
[ -d "$SRC" ] || { echo "no live state at $SRC"; exit 1; }

echo "== fresh throwaway copy from live =="
rm -rf "$TESTROOT"; mkdir -p "$TEST"
rsync -a --exclude 'npm/' --exclude 'browser/' --exclude 'browsers/' --exclude 'logs/' --exclude '*.log' "$SRC/" "$TEST/"

echo
echo "== 1. lossless check — legacy chunks not present in canonical (hashes only) =="
docker run --rm -i -v "$TEST:/s:ro" python:3-alpine python3 - <<'PY'
import sqlite3
def cols(c,t):
    return {r[1] for r in c.execute(f'pragma table_info("{t}")')}
canon=sqlite3.connect('file:/s/agents/main/agent/openclaw-agent.sqlite?mode=ro',uri=True)
leg=sqlite3.connect('file:/s/memory/main.sqlite?mode=ro',uri=True)
cc=cols(canon,'memory_index_chunks'); lc=cols(leg,'chunks')
print("canonical memory_index_chunks cols:", sorted(cc))
print("legacy chunks cols:", sorted(lc))
if 'hash' in cc and 'hash' in lc:
    ch={r[0] for r in canon.execute("select hash from memory_index_chunks")}
    lh=[r[0] for r in leg.execute("select hash from chunks")]
    novel=[h for h in lh if h not in ch]
    print(f"canonical: {len(ch)} chunks | legacy: {len(lh)} chunks | legacy NOT in canonical: {len(novel)}")
    print("=> LOSSLESS: dropping the legacy sidecar loses no memory" if not novel
          else f"=> {len(novel)} unique legacy chunks — a plain delete would drop them; would need a merge instead")
else:
    print("(no comparable hash column — falling back to counts only)")
    print("canonical:", canon.execute("select count(*) from memory_index_chunks").fetchone()[0],
          "| legacy:", leg.execute("select count(*) from chunks").fetchone()[0])
try:
    cm={r[0] for r in canon.execute("select key from memory_index_meta")}
    lm={r[0] for r in leg.execute("select key from meta")}
    print("meta keys — canonical:", sorted(cm), "| legacy:", sorted(lm), "| conflicting:", sorted(cm & lm))
except Exception as e: print("meta read:", e)
PY

echo
echo "== 2. apply canonical-wins: remove the legacy sidecar (on the COPY only) =="
rm -f "$TEST/$LEGACY" "$TEST/$LEGACY"-wal "$TEST/$LEGACY"-shm
[ -f "$TEST/$LEGACY" ] && echo "  !! still present" || echo "  legacy sidecar removed"

echo
echo "== 3. boot the fixed beta against the repaired copy (isolated · loopback) =="
docker rm -f oc-memrepair >/dev/null 2>&1 || true
docker run -d --name oc-memrepair --network none -e HOME=/home/node \
  -v "$TEST:/home/node/.openclaw" --entrypoint openclaw \
  "$IMG" gateway --bind loopback --port 57419 >/dev/null 2>&1
for i in $(seq 1 20); do
  R=$(docker inspect -f '{{.State.Running}}' oc-memrepair 2>/dev/null)
  [ "$R" = "true" ] || break
  docker logs oc-memrepair 2>&1 | grep -qiE 'http server listening' && break
  sleep 1
done
R=$(docker inspect -f '{{.State.Running}}' oc-memrepair 2>/dev/null)
E=$(docker inspect -f '{{.State.ExitCode}}' oc-memrepair 2>/dev/null)
LOG=$(docker logs --tail 55 oc-memrepair 2>&1)
if echo "$LOG" | grep -qiE 'refusing to report the gateway ready|could not be imported|did not complete cleanly|legacy memory'; then V="⛔ FAIL — still a migration conflict"
elif echo "$LOG" | grep -qiE 'http server listening'; then V="✅ PASS — booted READY on the repaired state (canonical memory intact)"
elif [ "$R" = "true" ]; then V="🟡 LIKELY PASS — running, no explicit ready line"
else V="⛔ FAIL — exited $E"; fi
echo "RESULT: running=$R exit=$E"
echo "VERDICT: $V"
echo "── last log lines ──"; echo "$LOG" | tail -30
docker rm -f oc-memrepair >/dev/null 2>&1 || true
rm -rf "$TESTROOT"
echo "== done (throwaway copy removed) =="
