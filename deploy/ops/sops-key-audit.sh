#!/usr/bin/env bash
# Audit the box's SOPS age key — the master recovery key for ALL Nave secrets.
# Reports WHERE it lives, whether it exists, and its PUBLIC recipient (safe).
# NEVER prints the private key. Read-only; changes nothing.
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi

echo "=== SOPS age key discovery ==="
echo "  SOPS_AGE_KEY_FILE = ${SOPS_AGE_KEY_FILE:-<unset>}"
echo "  SOPS_AGE_KEY env  = $([ -n "${SOPS_AGE_KEY:-}" ] && echo '<set>' || echo '<unset>')"
CANDS=( "${SOPS_AGE_KEY_FILE:-}" "/root/.config/sops/age/keys.txt" "${HOME:-/root}/.config/sops/age/keys.txt" "/root/.sops/age/keys.txt" )
FOUND=""
for f in "${CANDS[@]}"; do
  [ -n "$f" ] || continue
  if [ -f "$f" ]; then
    echo "  ✓ key file: $f   (perms $(stat -c '%a' "$f" 2>/dev/null), $(wc -l < "$f") lines)"
    [ -z "$FOUND" ] && FOUND="$f"
  fi
done
[ -z "$FOUND" ] && echo "  ✗ no age key file at the usual paths"
echo

echo "=== box key PUBLIC recipient (safe to show; derived, no secret leaked) ==="
if [ -n "$FOUND" ]; then
  if command -v age-keygen >/dev/null 2>&1; then
    age-keygen -y "$FOUND" 2>/dev/null | sed 's/^/  box recipient: /' || echo "  (could not derive public key)"
  else
    grep -i '# public key:' "$FOUND" | sed 's/^/  (from comment) /' || echo "  (age-keygen absent; no public-key comment)"
  fi
else
  echo "  (no key file to derive from)"
fi
echo

echo "=== recipients that secrets.enc.env is encrypted TO ==="
ENC="$D/sites/luke/secrets.enc.env"
if [ -f "$ENC" ]; then
  grep -oiE 'age1[0-9a-z]{55,}' "$ENC" | sort -u | sed 's/^/  enc-to: /' || echo "  (no age recipients parsed)"
  echo "  (if 'box recipient' above appears in this list, the box key CAN decrypt your secrets)"
else
  echo "  ✗ no secrets.enc.env at $ENC"
fi
echo

echo "=== can the box actually decrypt right now? (proves the key works; value hidden) ==="
if [ -f "$ENC" ] && command -v sops >/dev/null 2>&1; then
  if sops --input-type dotenv --output-type dotenv -d "$ENC" >/dev/null 2>&1; then
    echo "  ✓ sops -d succeeded — the box key decrypts secrets.enc.env"
  else
    echo "  ✗ sops -d FAILED — key mismatch or missing"
  fi
else
  echo "  (sops or enc file not present)"
fi
echo "== sops-key-audit done =="
