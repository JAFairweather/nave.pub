#!/usr/bin/env bash
# Prove the Hostinger image boots Luke's migrated state to a READY gateway,
# running the gateway DIRECTLY (openclaw gateway) instead of the server.mjs
# token wrapper. This is the exact compatibility check the vanilla image
# FAILED (vanilla=2026.7.1 hit a Memory Core index conflict); the Hostinger
# image is 2026.6.9 — same version as the state — so it should adopt it cleanly.
#
# Safe: runs on the box-local COPY only, --network none, no published port; the
# live Hostinger instance is never touched.
set -u
STATE=/root/nave.pub/deploy/openclaw-state/.openclaw
IMG=ghcr.io/hostinger/hvps-openclaw:latest
[ -d "$STATE" ] || { echo "no migrated state at $STATE"; exit 1; }

docker rm -f oc-hosttest >/dev/null 2>&1 || true
# HOME=/data → openclaw reads state at /data/.openclaw (matches the live layout).
docker run -d --name oc-hosttest --network none \
  -e HOME=/data \
  -v "$STATE:/data/.openclaw" \
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
