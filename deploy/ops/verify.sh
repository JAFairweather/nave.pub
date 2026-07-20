#!/usr/bin/env bash
# Post-deploy verification harness. Exercises the REAL paths — not just HTTP —
# so config/runtime breaks fail the deploy instead of surfacing hours later.
# Every check below maps to a class of failure we actually hit:
#   • containers not up            • a service silently crash-looping
#   • vhost != 200                 • Caddy vhost/cert broken
#   • nactor health/creds          • broker down or credentials not loaded
#   • luke webhook registered      • approval taps silently dropped
#   • brain dry-run clean          • missing import / broker path / JSON parse
#
# Exit 0 = all critical checks pass; exit 1 = at least one failed (deploy goes
# red). Set VERIFY_BRAIN=0 to skip the (Anthropic-calling) brain dry-run.
set -u
FAIL=0
pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*"; FAIL=1; }
warn() { echo "  ⚠ $*"; }

if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
cd "$D" 2>/dev/null || { echo "no deploy dir"; exit 1; }
echo "== nave verify @ $(date -u +%FT%TZ) · $D =="

echo "-- containers --"
crit_up() { s=$(docker inspect -f '{{.State.Status}}' "deploy-$1-1" 2>/dev/null || echo missing); [ "$s" = running ] && pass "$1: running" || fail "$1: $s"; }
warn_up() { s=$(docker inspect -f '{{.State.Status}}' "deploy-$1-1" 2>/dev/null || echo missing); [ "$s" = running ] && pass "$1: running" || warn "$1: $s"; }
crit_up nactor; crit_up luke; crit_up caddy
warn_up director; warn_up openclaw

echo "-- vhosts (local TLS via caddy) --"
for h in nave.pub nact.nave.pub luke.nave.pub nvoy.nave.pub noir.nave.pub; do
  code=$(curl -sk -o /dev/null -w '%{http_code}' --resolve "$h:443:127.0.0.1" --max-time 15 "https://$h/" 2>/dev/null || echo 000)
  case "$code" in 200|301|302) pass "$h → $code" ;; *) fail "$h → $code" ;; esac
done

echo "-- nactor broker health --"
HJ=$(curl -sk --resolve nact.nave.pub:443:127.0.0.1 --max-time 15 https://nact.nave.pub/api/health 2>/dev/null)
echo "$HJ" | grep -q '"ok":true' && pass "nactor ok:true" || fail "nactor health not ok"
echo "$HJ" | grep -qE '"credentials":[1-9]' && pass "credentials loaded" || fail "credentials = 0 (broker holds no creds)"
for id in luke brain nave nactjaf; do echo "$HJ" | grep -q "\"$id\"" && pass "identity $id" || warn "identity $id absent from health"; done

echo "-- luke telegram webhook --"
# Poll: luke registers its webhook on boot with a retry loop (up to ~30s to
# catch the broker after a co-deploy), so check for up to ~48s before failing —
# otherwise we'd race luke's own startup and false-alarm right after a deploy.
wh=""
for _ in $(seq 1 24); do
  L=$(docker logs deploy-luke-1 2>&1 | grep -E 'webhook: (registered|skipped)' | tail -1)
  case "$L" in *registered*) wh=ok; break ;; *skipped*) wh=skip; break ;; esac
  sleep 2
done
case "$wh" in
  ok)   pass "approval webhook registered" ;;
  skip) warn "webhook skipped (telegram not configured)" ;;
  *)    fail "webhook NOT registered after ~48s — approval taps will drop" ;;
esac

if [ "${VERIFY_BRAIN:-1}" = 1 ]; then
  echo "-- brain dry-run (import + broker + model + parse) --"
  OUT=$(bash "$D/ops/run-brain.sh" --dry-run 2>&1)
  echo "$OUT" | grep -qE 'drafted [0-9]+ candidate|no candidates|HEARTBEAT' && pass "brain drafted/ran" || fail "brain did not complete a draft cycle"
  if echo "$OUT" | grep -qiE 'Error:|Cannot find module|did not return JSON|no LLM path'; then
    fail "brain error: $(echo "$OUT" | grep -iE 'Error:|Cannot find module|did not return JSON|no LLM path' | head -1)"
  else pass "brain output clean (no import/broker/parse error)"; fi
else warn "brain dry-run skipped (VERIFY_BRAIN=0)"; fi

echo
[ "$FAIL" = 0 ] && echo "✅ VERIFY PASS" || echo "❌ VERIFY FAIL — see ✗ lines above"
exit $FAIL
