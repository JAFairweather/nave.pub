#!/usr/bin/env bash
# Mint Nactor's own keypair ON THE BOX and wire it into luke.env, so Nactor
# becomes a grantee (Directors encrypt credential-scopes to its npub).
#
# SAFE FOR CI LOGS: the nsec is written straight into luke.env and NEVER
# printed — only the public npub is echoed. Idempotent: if NACTOR_NSEC is
# already set, it does nothing but print the existing npub.
#
# Run via: Ops → run-script → gen-nactor-key.sh   (then redeploy)
set -u
cd /root/nave.pub/deploy 2>/dev/null || cd /root/noir/deploy || { echo "no deploy dir"; exit 1; }
ENVF=./luke.env
touch "$ENVF"

if grep -q '^NACTOR_NSEC=' "$ENVF"; then
  echo "NACTOR_NSEC already present — leaving it."
else
  # Generate inside the nactor image (has nostr-tools); print ONLY nsec on stdout,
  # capture it, append to luke.env. The value never reaches this script's stdout.
  NSEC=$(docker compose run --rm --no-deps --entrypoint node nactor -e \
    'import("nostr-tools").then(t=>process.stdout.write(t.nip19.nsecEncode(t.generateSecretKey())))' 2>/dev/null)
  if [ -z "$NSEC" ]; then echo "key generation failed (is the nactor image built?)"; exit 1; fi
  printf '\n# Nactor grantee key — minted on the box, credential-scopes encrypt to its npub\nNACTOR_NSEC=%s\n' "$NSEC" >> "$ENVF"
  unset NSEC
  echo "NACTOR_NSEC minted and appended to luke.env."
fi

# Print the PUBLIC npub only, so the Director knows where to grant.
echo -n "nactor npub: "
docker compose run --rm --no-deps --entrypoint node nactor -e \
  'import("nostr-tools").then(t=>{const v=(process.env.NACTOR_NSEC||"").trim();if(!v)return process.stdout.write("(unset)");const sk=v.startsWith("nsec1")?t.nip19.decode(v).data:Uint8Array.from(v.match(/.{1,2}/g).map(b=>parseInt(b,16)));process.stdout.write(t.nip19.npubEncode(t.getPublicKey(sk)))})' \
  2>/dev/null
echo
echo "── next: redeploy so the nactor container picks up NACTOR_NSEC, then issue"
echo "   role-key credential-scopes to the npub above with nactor/issue-credential.mjs ──"
