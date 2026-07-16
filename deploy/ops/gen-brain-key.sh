#!/usr/bin/env bash
# Turn ON luke-brain's credential broker, durably — box-local, no git push.
#
# Writes BRAIN_NSEC (a dedicated `brain` identity — broker-auth only, NOT a
# posting key) + NACT_BROKER_URL into ./brain.env, which is gitignored and
# survives sites.sh's `git reset --hard origin/main` (same durability rule as
# nactor.env). The brain then routes its Anthropic calls THROUGH Nactor, which
# injects the key from memory — the key never lives in the brain's env.
# See nact/docs/migration.md (Phase 2).
#
# SAFE FOR CI LOGS: the nsec is generated straight into brain.env and NEVER
# printed — only the public brain npub is echoed. Idempotent, and preserves an
# existing brain key so activation never has to be redone.
#
# Run via: Ops → run-script → gen-brain-key.sh
set -u
# Flip-aware live dir, same rule as deploy.yml / sites.sh.
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
cd "$D" || { echo "deploy dir missing"; exit 1; }
ENVF=./brain.env
BROKER_URL=http://nactor:8791/api

# Reuse an existing brain key so we never churn it (a new key would need
# re-activation): prefer brain.env, then a BRAIN_NSEC already in luke.env (e.g.
# left by an earlier run), else mint a fresh one in the nactor image.
NSEC=""
[ -f "$ENVF" ]     && NSEC=$(grep '^BRAIN_NSEC=' "$ENVF"     2>/dev/null | cut -d= -f2-)
[ -z "$NSEC" ] && [ -f ./luke.env ] && NSEC=$(grep '^BRAIN_NSEC=' ./luke.env 2>/dev/null | cut -d= -f2-)
if [ -z "$NSEC" ]; then
  NSEC=$(docker compose run --rm --no-deps --entrypoint node nactor -e \
    'import("nostr-tools").then(t=>process.stdout.write(t.nip19.nsecEncode(t.generateSecretKey())))' 2>/dev/null)
  [ -n "$NSEC" ] || { echo "key generation failed (is the nactor image built?)"; exit 1; }
  echo "minted a new brain key."
else
  echo "reusing existing brain key."
fi

umask 077
{
  echo '# brain: dedicated identity for broker auth only — NOT a posting key.'
  echo '# Box-local & gitignored; survives sites.sh reset --hard (like nactor.env).'
  echo "BRAIN_NSEC=$NSEC"
  echo "NACT_BROKER_URL=$BROKER_URL"
} > "$ENVF"
chmod 600 "$ENVF"
unset NSEC
echo "wrote brain.env (box-local — no commit/push needed)."

# Recreate nactor so it registers the `brain` identity + broker now.
docker compose up -d --force-recreate --no-deps nactor >/dev/null 2>&1 && echo "nactor recreated."

# Print the PUBLIC brain npub only — read from the recreated nactor's env
# (env_file now includes brain.env), never from argv/plaintext.
echo -n "brain npub: "
docker compose run --rm --no-deps --entrypoint node nactor -e \
  'import("nostr-tools").then(t=>{const v=(process.env.BRAIN_NSEC||"").trim();if(!v)return process.stdout.write("(unset)");const sk=v.startsWith("nsec1")?t.nip19.decode(v).data:Uint8Array.from(v.match(/.{1,2}/g).map(b=>parseInt(b,16)));process.stdout.write(t.nip19.npubEncode(t.getPublicKey(sk)))})' \
  2>/dev/null
echo
echo "── next: activate 'brain' in the Nact app (Agent Identities → ✍ Activate), then run the brain --dry-run ──"
