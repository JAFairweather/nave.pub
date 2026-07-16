#!/usr/bin/env bash
# Repair-and-prove for the migrated OpenClaw state, so vanilla OpenClaw can
# adopt Hostinger's state. Runs entirely on the box-local COPY at
# deploy/openclaw-state/.openclaw — the live Hostinger instance
# (openclaw-kajk-openclaw-1, exposed :57419) is never touched — and every
# container here is `--network none` so nothing binds a public port.
#
# The vanilla image refuses to report the gateway ready if a startup migration
# didn't complete cleanly (our copy came from 2026.6.9; the image is 2026.7.1),
# and it names the remedy itself: `openclaw doctor --fix`. So: fix, then prove
# the gateway reaches ready.
set -u
STATE=/root/nave.pub/deploy/openclaw-state/.openclaw
IMG=ghcr.io/openclaw/openclaw:2026.7.1

[ -d "$STATE" ] || { echo "no migrated state at $STATE — run the migration copy first"; exit 1; }

echo "== 1. openclaw doctor --fix (against the mounted state copy) =="
docker run --rm --network none \
  -v "$STATE:/home/node/.openclaw" \
  "$IMG" node openclaw.mjs doctor --fix 2>&1
echo "doctor exit: $?"

echo
echo "== 2. re-attempt gateway boot (isolated · loopback · no exposed port) =="
docker rm -f oc-test >/dev/null 2>&1 || true
docker run -d --name oc-test --network none \
  -v "$STATE:/home/node/.openclaw" \
  "$IMG" node openclaw.mjs gateway --bind loopback --port 18789 >/dev/null 2>&1
# Give startup migrations + the gateway a moment to settle.
for i in $(seq 1 10); do
  RUNNING=$(docker inspect -f '{{.State.Running}}' oc-test 2>/dev/null)
  [ "$RUNNING" = "true" ] || break
  # If it logged "ready" we can stop early.
  docker logs oc-test 2>&1 | grep -qi 'gateway.*ready\|ready.*gateway\|listening' && break
  sleep 1
done
RUNNING=$(docker inspect -f '{{.State.Running}}' oc-test 2>/dev/null)
EXIT=$(docker inspect -f '{{.State.ExitCode}}' oc-test 2>/dev/null)
echo "RESULT: running=$RUNNING exit=$EXIT"
echo "── last 45 log lines ──"
docker logs --tail 45 oc-test 2>&1
docker rm -f oc-test >/dev/null 2>&1 || true
echo "── cleaned up ──"
echo "== done =="
