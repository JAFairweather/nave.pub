#!/usr/bin/env bash
# Turn ON luke-brain's credential broker, durably.
#
# Mints a DEDICATED `brain` identity key and sets NACT_BROKER_URL so the brain
# routes its Anthropic calls THROUGH Nactor (which injects the key from memory)
# instead of reading ANTHROPIC_API_KEY itself. `brain` is NOT a posting key — it
# can't post as luke/nave; posting stays behind the propose → Telegram-approve
# flow. See nact/docs/migration.md (Phase 2).
#
# Durability: sites.sh does `git reset --hard origin/main` on the luke checkout
# every deploy, so a box-local edit is wiped. This writes BRAIN_NSEC +
# NACT_BROKER_URL into the SOPS source (secrets.enc.env) and COMMITS + PUSHES it.
#
# SAFE FOR CI LOGS: the nsec is generated straight into the SOPS plaintext and
# NEVER printed — only the public brain npub is echoed. Idempotent.
#
# Run via: Ops → run-script → gen-brain-key.sh
set -u
# Flip-aware live dir, same rule as deploy.yml / sites.sh.
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
cd "$D/sites/luke" || { echo "luke site dir missing"; exit 1; }
command -v sops >/dev/null 2>&1 || { echo "sops not installed"; exit 1; }
[ -f secrets.enc.env ] || { echo "secrets.enc.env missing — do luke SECRETS.md setup first"; exit 1; }

sops -d --input-type dotenv --output-type dotenv secrets.enc.env > secrets.env \
  || { echo "decrypt failed (age key missing?)"; rm -f secrets.env; exit 1; }
chmod 600 secrets.env
CHANGED=0

if ! grep -q '^BRAIN_NSEC=' secrets.env; then
  # Generate inside the nactor image (has nostr-tools). Only the nsec reaches
  # this var; it goes straight into the SOPS plaintext, never to a log.
  NSEC=$(cd "$D" && docker compose run --rm --no-deps --entrypoint node nactor -e \
    'import("nostr-tools").then(t=>process.stdout.write(t.nip19.nsecEncode(t.generateSecretKey())))' 2>/dev/null)
  [ -n "$NSEC" ] || { echo "key generation failed (is the nactor image built?)"; shred -u secrets.env 2>/dev/null || rm -f secrets.env; exit 1; }
  printf '# brain: dedicated identity for broker auth only — NOT a posting key (minted on box)\nBRAIN_NSEC=%s\n' "$NSEC" >> secrets.env
  unset NSEC; CHANGED=1
fi
if ! grep -q '^NACT_BROKER_URL=' secrets.env; then
  printf 'NACT_BROKER_URL=http://nactor:8791/api\n' >> secrets.env; CHANGED=1
fi

if [ "$CHANGED" = 1 ]; then
  sops --input-type dotenv --output-type dotenv -e secrets.env > secrets.enc.env
  if git add secrets.enc.env && git commit -q -m "luke: brain broker key + NACT_BROKER_URL" && git push -q origin main; then
    echo "committed + pushed secrets.enc.env (survives sites.sh reset --hard)."
  else
    echo "⚠ commit/push failed — the box edit will be WIPED on the next deploy."
    echo "  Commit & push sites/luke/secrets.enc.env to origin/main from a machine that can."
  fi
else
  echo "BRAIN_NSEC + NACT_BROKER_URL already present — nothing to change."
fi

# Refresh luke.env + recreate nactor so it registers the `brain` identity now.
sops -d --input-type dotenv --output-type dotenv secrets.enc.env > "$D/luke.env" && chmod 600 "$D/luke.env"
(cd "$D" && docker compose up -d --force-recreate --no-deps nactor >/dev/null 2>&1) && echo "nactor recreated."

# Print the PUBLIC brain npub only — read from the recreated nactor's env
# (env_file includes luke.env), never from argv/plaintext.
echo -n "brain npub: "
(cd "$D" && docker compose run --rm --no-deps --entrypoint node nactor -e \
  'import("nostr-tools").then(t=>{const v=(process.env.BRAIN_NSEC||"").trim();if(!v)return process.stdout.write("(unset)");const sk=v.startsWith("nsec1")?t.nip19.decode(v).data:Uint8Array.from(v.match(/.{1,2}/g).map(b=>parseInt(b,16)));process.stdout.write(t.nip19.npubEncode(t.getPublicKey(sk)))})' 2>/dev/null)
echo
shred -u secrets.env 2>/dev/null || rm -f secrets.env
echo "── next: activate 'brain' in the Nact app (Agent Identities → ✍ Activate), then run the brain --dry-run ──"
