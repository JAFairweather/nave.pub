#!/usr/bin/env bash
# Refresh the box-local OpenClaw state COPY from the LIVE Hostinger instance,
# then prove the Hostinger image boots it gateway-direct to READY.
#
# Why re-sync: an earlier VANILLA `doctor --fix` (2026.7.1) bumped the previous
# copy's config to 2026.7.1, so the older Hostinger binary (2026.6.9) now
# refuses it. The live state is the untouched source of truth (2026.6.9); a
# fresh copy restores a clean config the image can adopt.
#
# Safe: reads the live state read-only (rsync source), writes only to the COPY,
# and boots a throwaway container --network none with no published port. The
# live instance keeps running untouched.
set -u
SRC=/docker/openclaw-kajk/data/.openclaw
DST=/root/nave.pub/deploy/openclaw-state/.openclaw
IMG=ghcr.io/hostinger/hvps-openclaw:latest
[ -d "$SRC" ] || { echo "no live state at $SRC"; exit 1; }

echo "== 1. fresh re-sync from live (excluding caches/browsers/logs) =="
mkdir -p "$DST"
rsync -a --delete \
  --exclude 'npm/' --exclude 'browser/' --exclude 'browsers/' \
  --exclude 'logs/' --exclude '*.log' \
  "$SRC/" "$DST/"
chown -R 1000:1000 "$DST" 2>/dev/null || true
echo -n "config version: "; grep -o '"lastTouchedVersion":"[^"]*"' "$DST/openclaw.json" 2>/dev/null || echo "(meta not found)"
echo -n "size: "; du -sh "$DST" | cut -f1

echo
echo "== 2. boot the Hostinger image gateway-direct (isolated · loopback) =="
docker rm -f oc-hosttest >/dev/null 2>&1 || true
docker run -d --name oc-hosttest --network none \
  -e HOME=/data \
  -v "$DST:/data/.openclaw" \
  --entrypoint openclaw \
  "$IMG" gateway --bind loopback --port 57419 >/dev/null 2>&1
for i in $(seq 1 18); do
  R=$(docker inspect -f '{{.State.Running}}' oc-hosttest 2>/dev/null)
  [ "$R" = "true" ] || break
  docker logs oc-hosttest 2>&1 | grep -qiE 'ready|listening|gateway up' && break
  sleep 1
done
R=$(docker inspect -f '{{.State.Running}}' oc-hosttest 2>/dev/null)
E=$(docker inspect -f '{{.State.ExitCode}}' oc-hosttest 2>/dev/null)
echo "RESULT: running=$R exit=$E   (running=true or a clean 'ready' log = PASS)"
echo "── last 45 log lines ──"
docker logs --tail 45 oc-hosttest 2>&1
docker rm -f oc-hosttest >/dev/null 2>&1 || true
echo "── cleaned up ──"
echo "== done =="
