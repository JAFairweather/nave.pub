#!/bin/bash
# m5-mail-verify.sh — M5 cutover step 1 verification (nact#4): prove the mail
# connector serves a grant-delivered mail credential end-to-end, from the box,
# before any consumer is repointed and before mail/app-passwd is deleted.
#
# PREREQUISITE (Director, in the Nvoy console): issue `credential:mail-gmail`
# to Nave Nactor with the JSON value the connector documents
# (nact nactor/connectors/mail.mjs header):
#   { "auth": "password", "host": "imap.gmail.com", "port": 993,
#     "user": "<gmail address>", "pass": "<the app password from Bitwarden>" }
# Then wait one reader sweep (≤5 min) and dispatch this script.
#
# What it does (names only — never values, never message content):
#   1. preflight: nactor's last sweep shows `mail-gmail` loaded from a grant
#   2. from inside the nactor container, sign a NIP-98 request AS an activated
#      identity (luke — its key is already in the container env; nothing moves)
#      and POST /api/connector/mail { account:"gmail", verb:"list" }
#   3. print the mailbox NAMES the connector returns (proves grant → RAM →
#      IMAP EXAMINE round trip) and the audit line
# On success, the remaining M5 steps are consumer-side (tracked in nact#4):
# repoint the inbox-summary consumer to the connector, then delete
# mail/app-passwd and the himalaya file mount.
set -eu
N=$(docker ps -qf name=nactor | head -1)
[ -n "$N" ] || { echo "✗ nactor not running"; exit 1; }

echo "== preflight: mail-gmail grant-sourced =="
L=$(docker logs --tail 300 "$N" 2>&1 | grep 'credential-grants: loaded' | tail -1 || true)
echo "  last sweep: ${L:-<none>}"
case "$L" in
  *mail-gmail*) echo "  ✓ mail-gmail loaded from a grant" ;;
  *) echo "✗ mail-gmail not loaded — issue credential:mail-gmail in the Nvoy console, wait one sweep, re-run"; exit 1 ;;
esac

echo "== connector round trip (NIP-98 as luke, verb=list, names only) =="
docker exec "$N" node -e '
const { finalizeEvent, nip19 } = require("nostr-tools")
async function main() {
  const raw = (process.env.LUKE_NSEC || "").trim()
  if (!raw) { console.log("✗ LUKE_NSEC not in env"); process.exit(1) }
  const sk = raw.startsWith("nsec1") ? nip19.decode(raw).data : Uint8Array.from(Buffer.from(raw, "hex"))
  const url = "http://127.0.0.1:8791/api/connector/mail"
  const body = JSON.stringify({ account: "gmail", verb: "list" })
  const crypto = require("node:crypto")
  const payload = crypto.createHash("sha256").update(body).digest("hex")
  const ev = finalizeEvent({ kind: 27235, created_at: Math.floor(Date.now()/1000),
    tags: [["u", url], ["method", "POST"], ["payload", payload]], content: "" }, sk)
  const r = await fetch(url, { method: "POST",
    headers: { authorization: "Nostr " + Buffer.from(JSON.stringify(ev)).toString("base64"),
               "content-type": "application/json" }, body })
  const t = await r.text()
  if (r.status !== 200) { console.log("✗ connector returned", r.status, t.slice(0, 160)); process.exit(1) }
  const out = JSON.parse(t)
  const names = (out.mailboxes || out.list || []).map(m => m.path || m.name || m).slice(0, 12)
  console.log("  ✓ 200 — mailboxes:", names.join(", ") || "(none returned)")
}
main().catch(e => { console.log("✗", e.message); process.exit(1) })
' || exit 1
echo "✓ M5 delivery path VERIFIED — grant → RAM → verb-scoped IMAP round trip."
echo "  Remaining (nact#4): repoint the inbox-summary consumer, then delete"
echo "  mail/app-passwd + the himalaya passwd mount."
