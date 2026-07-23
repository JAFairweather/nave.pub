#!/usr/bin/env bash
# Mint the Quill BOX-DEVICE key (nact#26 / quill.md §9) — the identity the
# jaf-scribe signs draft:post scopes and wraps with, so drafting-for-the-
# Director is Quill's job and luke's key never touches it again.
#
# One persona, per-device keys: the Mac holds its own key in the Keychain
# (canonical-quill); the box holds THIS one. No key is ever copied between
# devices — that property is the whole point (AD-10, quill.md §9).
#
# Writes $DEPLOY/quill.env (box-local, gitignored, 0600) with QUILL_NSEC.
# Prints ONLY the npub. Idempotent: an existing quill.env is never overwritten.
#
#   bash deploy/ops/gen-quill-key.sh
#
# Afterward, the Director's two clicks in Ngage (ngage.nave.pub → Settings):
#   1. add the printed npub under Trusted agents;
#   2. re-save Steering so a steer:draft grant reaches the new key.
# (Optionally remove luke from Trusted agents once pending drafts are cleared —
# that is the actual severing of the old path.)
set -euo pipefail
if [ -f /root/nave.pub/deploy/.flipped ]; then DEPLOY=/root/nave.pub/deploy; else DEPLOY=/root/noir/deploy; fi
OUT="$DEPLOY/quill.env"

if [ -f "$OUT" ]; then
  echo "quill.env already exists — not overwriting (rotate by deleting it first, deliberately)."
  docker run --rm --env-file "$OUT" luke:latest node -e '
    const { nip19, getPublicKey } = await import("nostr-tools");
    const raw = process.env.QUILL_NSEC.trim();
    const sk = raw.startsWith("nsec1") ? nip19.decode(raw).data : Uint8Array.from(raw.match(/.{2}/g).map(b=>parseInt(b,16)));
    console.log("existing quill (box device) npub:", nip19.npubEncode(getPublicKey(sk)));' --input-type=module
  exit 0
fi

# Generate INSIDE the luke image (nostr-tools already there); the nsec goes
# straight into the env file — never echoed, never in shell history.
docker run --rm luke:latest node --input-type=module -e '
  import { generateSecretKey, getPublicKey, nip19 } from "nostr-tools";
  const sk = generateSecretKey();
  console.log(JSON.stringify({ nsec: nip19.nsecEncode(sk), npub: nip19.npubEncode(getPublicKey(sk)) }));
' > /tmp/quill-mint.$$
NSEC=$(node -e 'console.log(JSON.parse(require("fs").readFileSync("/tmp/quill-mint.'"$$"'","utf8")).nsec)' 2>/dev/null \
  || python3 -c 'import json;print(json.load(open("/tmp/quill-mint.'"$$"'"))["nsec"])')
NPUB=$(python3 -c 'import json;print(json.load(open("/tmp/quill-mint.'"$$"'"))["npub"])')
rm -f /tmp/quill-mint.$$

umask 077
printf 'QUILL_NSEC=%s\n' "$NSEC" > "$OUT"
chmod 600 "$OUT"
unset NSEC

echo "quill.env written (0600, box-local, gitignored) — the nsec was not printed."
echo
echo "quill (box device) npub: $NPUB"
echo
echo "Next (the Director, in Ngage → Settings):"
echo "  1. Trusted agents → add the npub above."
echo "  2. Steering → Save & publish (re-issues the steer:draft grant to it)."
echo "  3. When pending luke-signed drafts are cleared, remove luke from"
echo "     Trusted agents — that severs the old ghostwriting path for good."
