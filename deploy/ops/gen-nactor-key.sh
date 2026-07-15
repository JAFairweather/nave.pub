#!/usr/bin/env bash
# Mint Nactor's own keypair ON THE BOX so it becomes a grantee (Directors
# encrypt credential-scopes to its npub). The key goes in ./nactor.env, which
# is box-local and gitignored — NOT luke.env, which sites.sh regenerates from
# SOPS on every deploy (an append there gets wiped).
#
# SAFE FOR CI LOGS: the nsec is written straight into nactor.env and NEVER
# printed — only the public npub is echoed. Idempotent.
#
# Run via: Ops → run-script → gen-nactor-key.sh
set -u
# Live deploy dir (flip-aware), same rule as deploy.yml / ops.yml.
if [ -f /root/nave.pub/deploy/.flipped ]; then cd /root/nave.pub/deploy; else cd /root/noir/deploy; fi
ENVF=./nactor.env
touch "$ENVF"; chmod 600 "$ENVF"

if grep -q '^NACTOR_NSEC=' "$ENVF"; then
  echo "NACTOR_NSEC already present in nactor.env — leaving it."
else
  # Generate inside the nactor image (has nostr-tools). Only the nsec reaches
  # this script's stdout (stderr suppressed); it goes straight into the file.
  NSEC=$(docker compose run --rm --no-deps --entrypoint node nactor -e \
    'import("nostr-tools").then(t=>process.stdout.write(t.nip19.nsecEncode(t.generateSecretKey())))' 2>/dev/null)
  if [ -z "$NSEC" ]; then echo "key generation failed (is the nactor image built?)"; exit 1; fi
  printf '# Nactor grantee key — minted on the box; credential-scopes encrypt to its npub\nNACTOR_NSEC=%s\n' "$NSEC" >> "$ENVF"
  unset NSEC
  echo "NACTOR_NSEC minted → nactor.env (survives sites.sh; not luke.env)."
fi

# Recreate nactor so it loads nactor.env now (env_file change needs a recreate).
docker compose up -d --force-recreate --no-deps nactor >/dev/null 2>&1 && echo "nactor recreated."

# Print the PUBLIC npub only (reads NACTOR_NSEC from nactor.env via env_file).
echo -n "nactor npub: "
docker compose run --rm --no-deps --entrypoint node nactor -e \
  'import("nostr-tools").then(t=>{const v=(process.env.NACTOR_NSEC||"").trim();if(!v)return process.stdout.write("(unset)");const sk=v.startsWith("nsec1")?t.nip19.decode(v).data:Uint8Array.from(v.match(/.{1,2}/g).map(b=>parseInt(b,16)));process.stdout.write(t.nip19.npubEncode(t.getPublicKey(sk)))})' \
  2>/dev/null
echo
echo "── issue role-key credential-scopes to the npub above with nactor/issue-credential.mjs ──"
