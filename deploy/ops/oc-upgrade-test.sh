#!/usr/bin/env bash
# oc-upgrade-test <image-tag>
#
# Dry-run an OpenClaw version change WITHOUT touching anything live. Takes a
# fresh COPY of Luke's current live state, boots the CANDIDATE image against it
# (isolated: --network none, no published port), and reports whether it reaches
# a ready gateway — surfacing any state-migration conflict. Neither the live
# instance NOR the staged cutover copy is touched: a throwaway dir is used and
# removed at the end.
#
# This is the safe path to ANY future upgrade — and the concrete path to pure
# upstream vanilla: point it at a vanilla tag and see whether it adopts Luke's
# memory cleanly BEFORE you ever commit. Green here = safe to switch; a conflict
# here = you found out on a copy, live untouched.
#
#   # via the Ops button, task=custom:
#   bash deploy/ops/oc-upgrade-test.sh ghcr.io/openclaw/openclaw:2026.8.0
#   bash deploy/ops/oc-upgrade-test.sh ghcr.io/hostinger/hvps-openclaw:latest
set -u
IMG="${1:-}"
if [ -z "$IMG" ]; then
  echo "usage: oc-upgrade-test.sh <image-tag>"
  echo "  e.g. ghcr.io/openclaw/openclaw:2026.8.0      (test upstream vanilla)"
  echo "       ghcr.io/hostinger/hvps-openclaw:latest  (test the Hostinger build)"
  exit 1
fi
SRC=/docker/openclaw-kajk/data/.openclaw
TESTROOT=/root/nave.pub/deploy/openclaw-upgradetest
TEST="$TESTROOT/.openclaw"
[ -d "$SRC" ] || { echo "no live state at $SRC"; exit 1; }

echo "== candidate image: $IMG =="
echo "▸ pulling (if needed)…"
docker pull "$IMG" >/dev/null 2>&1 || { echo "⚠ could not pull $IMG — bad tag, or not logged in to the registry?"; exit 1; }

echo
echo "== 1. fresh throwaway copy of LIVE state (never the cutover copy) =="
rm -rf "$TESTROOT"; mkdir -p "$TEST"
rsync -a --delete \
  --exclude 'npm/' --exclude 'browser/' --exclude 'browsers/' \
  --exclude 'logs/' --exclude '*.log' \
  "$SRC/" "$TEST/"
chown -R 1000:1000 "$TEST" 2>/dev/null || true
echo -n "state written by version: "; grep -o '"lastTouchedVersion":"[^"]*"' "$TEST/openclaw.json" 2>/dev/null || echo "(unknown)"

echo
echo "== 2. detect the candidate image's layout =="
IMG_HOME=$(docker run --rm --entrypoint sh "$IMG" -c 'printf %s "$HOME"' 2>/dev/null | tr -d '\r')
[ -n "$IMG_HOME" ] || IMG_HOME=/home/node
HAS_BIN=$(docker run --rm --entrypoint sh "$IMG" -c 'command -v openclaw 2>/dev/null || true' 2>/dev/null | tr -d '\r')
echo "HOME=$IMG_HOME   openclaw entrypoint=${HAS_BIN:-'(none — will use: node openclaw.mjs)'}"

echo
echo "== 3. boot the candidate gateway-direct (isolated · loopback · no port) =="
docker rm -f oc-upgradetest >/dev/null 2>&1 || true
if [ -n "$HAS_BIN" ]; then
  docker run -d --name oc-upgradetest --network none -e HOME="$IMG_HOME" \
    -v "$TEST:$IMG_HOME/.openclaw" --entrypoint openclaw \
    "$IMG" gateway --bind loopback --port 57419 >/dev/null 2>&1
else
  docker run -d --name oc-upgradetest --network none -e HOME="$IMG_HOME" \
    -v "$TEST:$IMG_HOME/.openclaw" --entrypoint node \
    "$IMG" openclaw.mjs gateway --bind loopback --port 57419 >/dev/null 2>&1
fi

for i in $(seq 1 20); do
  R=$(docker inspect -f '{{.State.Running}}' oc-upgradetest 2>/dev/null)
  [ "$R" = "true" ] || break
  docker logs oc-upgradetest 2>&1 | grep -qiE 'http server listening|gateway.*ready|listening' && break
  sleep 1
done
R=$(docker inspect -f '{{.State.Running}}' oc-upgradetest 2>/dev/null)
E=$(docker inspect -f '{{.State.ExitCode}}' oc-upgradetest 2>/dev/null)
LOG=$(docker logs --tail 60 oc-upgradetest 2>&1)

echo
# Check FAILURE signatures FIRST — the "refusing to report the gateway ready"
# error itself contains the words "gateway ready", so a naive ready-match would
# false-positive on a failed boot. Only a definitive listening line is a PASS.
if echo "$LOG" | grep -qiE 'refusing to report the gateway ready|could not be imported|did not complete cleanly|legacy memory meta rows conflict|migrations did not complete|older than the config|refusing to run'; then
  VERDICT="⛔ FAIL — state-migration conflict. Do NOT upgrade live to this image yet (see log below). Live is untouched."
elif echo "$LOG" | grep -qiE 'http server listening|\[gateway\] .*listening'; then
  VERDICT="✅ PASS — the candidate adopted Luke's state and the gateway came up READY. Safe to upgrade live to this image."
elif [ "$R" = "true" ]; then
  VERDICT="🟡 LIKELY PASS — still running, but no explicit 'http server listening' line matched. Skim the log to confirm."
else
  VERDICT="⛔ FAIL — container exited (code $E) before reporting ready. See log below. Live is untouched."
fi
echo "RESULT: running=$R exit=$E"
echo "VERDICT: $VERDICT"
echo "── last 60 log lines ──"
echo "$LOG"

docker rm -f oc-upgradetest >/dev/null 2>&1 || true
rm -rf "$TESTROOT"
echo "── cleaned up (container + throwaway copy removed) ──"
echo "== done =="
