#!/bin/bash
# m7-cutover.sh — M7: flip Nactor's credential-grant reads onto the nvoy-mcp
# transport and MOVE NACTOR_NSEC CUSTODY to the nvoy-mcp service
# (nact docs/migration-status-2026-07.md §5 M7, nact#6).
#
# Before: Nactor holds NACTOR_NSEC (via nave.env, possibly a stale copy in
#         nactor.env) and reads its credential grants from the relays
#         directly. nvoy-mcp runs as a warm standby with the SAME key
#         (NVOY_NSEC in sites.sh-generated nvoy-mcp.env) — deliberate overlap.
# After:  Nactor's env has NO nsec at all — only public NACTOR_NPUB plus
#         NACT_GRANT_TRANSPORT=mcp + NACT_MCP_URL — and reads the same grants
#         through nvoy-mcp over the private nave network (no token gate on
#         that server; network isolation is the boundary — it is expose-only,
#         never published, unrouted by Caddy). The per-identity entitlement /
#         A2 sweeps stay direct-relay (Director-approved M7 scope cut — the
#         role keys don't move until v2). NACTOR_NSEC's DURABLE home is
#         unchanged: the SOPS bundle (+ Bitwarden). M7 moves which process
#         reads it, not where it lives.
#
# What this script does, in order:
#   0. preflight — abort with NOTHING changed unless ALL of:
#        · not already cut over (.m7-mcp-transport absent)
#        · nactor + nvoy-mcp containers running, nvoy-mcp healthy
#        · nvoy-mcp.env exists and carries NVOY_NSEC
#        · IDENTITY MATCH: the npub nvoy-mcp logs ("agent npub1…") equals
#          nactor's /api/health nactorNpub — same key on both sides
#        · nactor's relay reader is currently serving (a recent
#          "credential-grants: loaded" line) — never cut over a broken baseline
#   1. back up nave.env, luke.env, nactor.env (.bak-<stamp>, chmod 600)
#   2. nactor.env: drop any stale NACTOR_NSEC + old M7 lines, append
#        NACT_GRANT_TRANSPORT=mcp
#        NACT_MCP_URL=http://nvoy-mcp:8799/mcp
#        NACTOR_NPUB=<the verified npub>          (public — safe in plaintext)
#   3. strip NACTOR_NSEC from nave.env + luke.env (the custody move)
#   4. touch .m7-mcp-transport — sites.sh keeps future regenerations stripped
#      (without the marker, the next deploy would resurrect the key)
#   5. recreate nactor and VERIFY (polling ~2 min):
#        · container env holds no NACTOR_NSEC
#        · logs show "credential-grants: transport mcp" (the switch loaded)
#        · a "credential-grants: loaded [" sweep lands (grants served via MCP)
#        · /api/health: ok:true, credentials ≥ 1, nactorNpub unchanged
#   6. on ANY failed check: restore all three env backups, remove the marker,
#      recreate nactor again — back to the relay transport, nothing moved.
#
# During step 5 the broker/proxy briefly 503s while the fresh Nactor's boot
# sweep fills CREDS — the same window every nactor recreate has (see
# retire-brokered-env.sh's lesson); the verify polls instead of racing it.
#
# ROLLBACK (after a SUCCESSFUL cutover — the reversible custody move):
#   1. rm .m7-mcp-transport
#   2. restore NACTOR_NSEC into nactor's env — either restore the
#      .bak-<stamp> files this script kept, or simply re-run `bash sites.sh`
#      (with the marker gone it regenerates nave.env WITH the key from SOPS)
#   3. remove the three M7 lines from nactor.env (grep -v the
#      NACT_GRANT_TRANSPORT/NACT_MCP_URL/NACTOR_NPUB lines)
#   4. docker compose up -d --force-recreate --no-deps nactor
#   5. verify: logs show the relay reader ("credential-grants: loaded" without
#      the "transport mcp" line) and /api/health credentials ≥ 1.
#   nvoy-mcp may keep running throughout (same key, read-only standby — the
#   pre-cutover overlap posture) or be stopped; either is safe.
#
# The nsec value is never printed, never echoed, never in CI logs — it moves
# between files via grep, and the only thing this script prints is the PUBLIC
# npub. Run via: Ops → run-script → m7-cutover.sh (dispatch is a deliberate,
# separate act — merging the PR that ships this script changes nothing).
set -eu
# Live deploy dir (flip-aware), same rule as deploy.yml / gen-nactor-key.sh.
if [ -f /root/nave.pub/deploy/.flipped ]; then cd /root/nave.pub/deploy; else cd /root/noir/deploy; fi
STAMP=$(date +%Y%m%d-%H%M%S)
MCP_URL="http://nvoy-mcp:8799/mcp"

# --- 0. preflight — abort with nothing changed ------------------------------
[ ! -f .m7-mcp-transport ] || { echo "✗ .m7-mcp-transport marker already present — cutover already done. To re-verify run ops/verify.sh; to roll back see this script's header."; exit 1; }
N=$(docker ps -qf name=nactor | head -1)
[ -n "$N" ] || { echo "✗ no nactor container running"; exit 1; }
M=$(docker ps -qf name=nvoy-mcp | head -1)
[ -n "$M" ] || { echo "✗ no nvoy-mcp container running — deploy the compose service first"; exit 1; }
MH=$(docker inspect -f '{{.State.Health.Status}}' "$M" 2>/dev/null || echo none)
[ "$MH" = healthy ] || { echo "✗ nvoy-mcp is not healthy (status: $MH)"; exit 1; }
[ -f nvoy-mcp.env ] && grep -q '^NVOY_NSEC=' nvoy-mcp.env || { echo "✗ nvoy-mcp.env missing or without NVOY_NSEC — run sites.sh first"; exit 1; }

# Identity match: the key nvoy-mcp actually loaded vs the key nactor holds.
MCP_NPUB=$(docker logs "$M" 2>&1 | grep -o 'agent npub1[0-9a-z]*' | tail -1 | awk '{print $2}')
NACT_NPUB=$(docker exec "$N" node -e 'fetch("http://127.0.0.1:8791/api/health").then(r=>r.json()).then(j=>process.stdout.write(j.nactorNpub||"")).catch(()=>process.exit(1))' 2>/dev/null || true)
echo "nvoy-mcp agent npub : ${MCP_NPUB:-<none>}"
echo "nactor grantee npub : ${NACT_NPUB:-<none>}"
[ -n "$MCP_NPUB" ] && [ "$MCP_NPUB" = "$NACT_NPUB" ] || { echo "✗ IDENTITY MISMATCH (or unreadable) — nvoy-mcp must hold the same key Nactor grants are addressed to; aborting with nothing changed"; exit 1; }

# Baseline: the current (relay) reader must actually be serving grants.
LOADED=$(docker logs --tail 400 "$N" 2>&1 | grep 'credential-grants: loaded' | tail -1 || true)
echo "relay reader last sweep: ${LOADED:-<none>}"
[ -n "$LOADED" ] || { echo "✗ preflight FAILED — nactor's relay reader shows no recent grant sweep; fix the baseline before moving custody"; exit 1; }
echo "✓ preflight: identity match, nvoy-mcp healthy, relay baseline serving"

# --- 1. backups --------------------------------------------------------------
for f in nave.env luke.env nactor.env; do
  [ -f "$f" ] || continue
  cp "$f" "$f.bak-$STAMP"; chmod 600 "$f.bak-$STAMP"
  echo "· backup: $f.bak-$STAMP"
done

restore() {
  echo "✗ VERIFICATION FAILED — restoring env files and the relay transport"
  for f in nave.env luke.env nactor.env; do
    [ -f "$f.bak-$STAMP" ] && cp "$f.bak-$STAMP" "$f" && chmod 600 "$f"
  done
  rm -f .m7-mcp-transport
  docker compose up -d --force-recreate --no-deps nactor
  echo "restored. Nothing moved — Nactor is back on the relay transport with its key."
}

# --- 2. nactor.env: the transport flip (+ drop any stale key copy) -----------
touch nactor.env; chmod 600 nactor.env
grep -vE '^(NACTOR_NSEC|NACT_GRANT_TRANSPORT|NACT_MCP_URL|NACTOR_NPUB)=' nactor.env > nactor.env.tmp || true
{ cat nactor.env.tmp
  printf '# M7 — grant reads via nvoy-mcp (ops/m7-cutover.sh %s); rollback: see the script header\n' "$STAMP"
  printf 'NACT_GRANT_TRANSPORT=mcp\n'
  printf 'NACT_MCP_URL=%s\n' "$MCP_URL"
  printf 'NACTOR_NPUB=%s\n' "$NACT_NPUB"
} > nactor.env.new
chmod 600 nactor.env.new
mv nactor.env.new nactor.env; rm -f nactor.env.tmp
echo "✓ nactor.env: transport=mcp, url=$MCP_URL, public npub kept (any stale nsec copy dropped)"

# --- 3. the custody move: strip the nsec from what Nactor reads --------------
for f in nave.env luke.env; do
  [ -f "$f" ] || continue
  grep -vE '^NACTOR_NSEC=' "$f" > "$f.tmp"; chmod 600 "$f.tmp"; mv "$f.tmp" "$f"
  echo "✓ $f: NACTOR_NSEC stripped"
done

# --- 4. the durable marker (sites.sh honors it on every future deploy) -------
touch .m7-mcp-transport
echo "✓ .m7-mcp-transport marker set — regenerations stay stripped"

# --- 5. recreate + verify ----------------------------------------------------
docker compose up -d --force-recreate --no-deps nactor
N=$(docker ps -qf name=nactor | head -1)

echo "verifying container env…"
if docker exec "$N" sh -c "env | cut -d= -f1 | grep -qx NACTOR_NSEC"; then
  echo "✗ NACTOR_NSEC still present in the nactor container"
  restore; exit 1
fi
echo "✓ nactor env holds no nsec"

echo "waiting for the mcp boot sweep (up to ~2 min)…"
SWEEP=""; TRANSPORT=""
for i in $(seq 1 12); do
  sleep 10
  L=$(docker logs "$N" 2>&1)
  TRANSPORT=$(echo "$L" | grep 'credential-grants: transport mcp' | tail -1 || true)
  SWEEP=$(echo "$L" | grep 'credential-grants: loaded' | tail -1 || true)
  [ -n "$TRANSPORT" ] && [ -n "$SWEEP" ] && break
done
echo "  transport line: ${TRANSPORT:-<none>}"
echo "  sweep line    : ${SWEEP:-<none>}"
if [ -z "$TRANSPORT" ] || [ -z "$SWEEP" ]; then restore; exit 1; fi

HJ=$(docker exec "$N" node -e 'fetch("http://127.0.0.1:8791/api/health").then(r=>r.json()).then(j=>process.stdout.write(JSON.stringify(j))).catch(()=>process.exit(1))' 2>/dev/null || true)
echo "$HJ" | grep -q '"ok":true' || { echo "✗ health not ok"; restore; exit 1; }
echo "$HJ" | grep -qE '"credentials":[1-9]' || { echo "✗ credentials = 0 — the mcp sweep did not fill CREDS"; restore; exit 1; }
echo "$HJ" | grep -q "\"nactorNpub\":\"$NACT_NPUB\"" || { echo "✗ nactorNpub changed — public-identity wiring broken"; restore; exit 1; }
echo "✓ health: ok, credentials loaded via mcp, grantee npub unchanged ($NACT_NPUB)"

echo
echo "✓ M7 CUTOVER COMPLETE — Nactor reads its credential grants through nvoy-mcp"
echo "  and holds no nsec. Custody: nvoy-mcp.env (regenerated from SOPS each"
echo "  deploy). Backups (*.bak-$STAMP) are box-local; remove after a quiet week."
echo "  Rollback any time: see this script's header."
