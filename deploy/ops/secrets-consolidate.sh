#!/usr/bin/env bash
# Re-align secret custody with the design: secrets.enc.env (SOPS, luke repo) is
# the SOURCE OF TRUTH; box-local env files are runtime copies, not roots.
#
# This script runs ON THE BOX (which holds the age key). It sweeps the stray
# box-local secrets accumulated during recent builds INTO the SOPS file:
#   GOOGLE_OAUTH_CLIENT_ID / _CLIENT_SECRET / _REFRESH_TOKEN   (nactor.env)
#   TELEGRAM_LUKE_BOT_TOKEN                                    (nactor.env)
#   OPENCLAW_GATEWAY_PASSWORD                                  (openclaw.env)
#   GMAIL_ADDRESS / GMAIL_APP_PASSWORD                         (luke-mail.env)
# then re-encrypts and prints ONLY the encrypted file (safe by design — that is
# exactly what the repo hosts) between BEGIN/END markers so the operator (or the
# pipeline) can commit it back to the luke repo. Box envs are left in place
# until the next deploy proves luke.env carries everything.
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
cd "$D"
ENC="sites/luke/secrets.enc.env"
command -v sops >/dev/null || { echo "sops required"; exit 1; }
[ -f "$ENC" ] || { echo "no $ENC (run a deploy first so sites/ is synced)"; exit 1; }

TMP="$(mktemp)"; trap 'rm -f "$TMP" "$TMP.new"' EXIT
sops --input-type dotenv --output-type dotenv -d "$ENC" > "$TMP" || { echo "decrypt failed"; exit 1; }

# get VAR file  → appends/replaces VAR in TMP from the named box env file
merged=0; missing=0
get() {
  local var="$1" src="$2" line
  line="$(grep -E "^${var}=" "$src" 2>/dev/null | head -1)"
  if [ -z "$line" ]; then echo "  ⚠ $var not found in $src (skipped)"; missing=$((missing+1)); return; fi
  grep -vE "^${var}=" "$TMP" > "$TMP.f" && mv "$TMP.f" "$TMP"
  printf '%s\n' "$line" >> "$TMP"
  echo "  ✓ $var ← $(basename "$src")"; merged=$((merged+1))
}
echo "── merging strays into the SOPS root ──"
get GOOGLE_OAUTH_CLIENT_ID     nactor.env
get GOOGLE_OAUTH_CLIENT_SECRET nactor.env
get GOOGLE_OAUTH_REFRESH_TOKEN nactor.env
get TELEGRAM_LUKE_BOT_TOKEN    nactor.env
get OPENCLAW_GATEWAY_PASSWORD  openclaw.env
get GMAIL_ADDRESS              luke-mail.env
get GMAIL_APP_PASSWORD         luke-mail.env

echo
echo "── re-encrypting ($merged merged, $missing skipped) ──"
# Reuse the file's existing recipient (the box age key's public half).
REC="$(grep -oE 'age1[a-z0-9]+' "$ENC" | head -1)"
[ -n "$REC" ] || { echo "could not find age recipient in $ENC"; exit 1; }
sops --input-type dotenv --output-type dotenv --encrypt --age "$REC" "$TMP" > "$TMP.new" || { echo "encrypt failed"; exit 1; }
mv "$TMP.new" "$ENC"
echo "re-encrypted → $ENC (recipient ${REC:0:12}…)"

echo
echo "───BEGIN-ENCRYPTED-SECRETS-ENV─── (SOPS ciphertext — safe to publish, values unreadable)"
cat "$ENC"
echo "───END-ENCRYPTED-SECRETS-ENV───"
