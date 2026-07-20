#!/bin/sh
# Nave NEW-BOX bring-up — run as root ON A FRESH BOX (provider console/first SSH).
# Installs the single management key, then the Docker-safe baseline hardening, so
# every new server is born to the fleet standard. See deploy/ops/ssh-standard.md.
#
#   MGMT_PUB='ssh-ed25519 AAAA...nave-mgmt' sh newbox.sh
#
# The mgmt public key is passed in (we don't commit it to this public repo).
# Deliberately does NOT disable passwords — that's rekey.sh --lock from your Mac,
# after you've CONFIRMED key login, so a fresh box can never lock you out. And
# deliberately does NOT install firewalld — it breaks Docker on these hosts.
set -eu
echo "== nave newbox bring-up on $(hostname) =="

# 1) Management key ---------------------------------------------------------
echo "-- management key --"
PUB="${MGMT_PUB:-}"
case "$PUB" in
  ssh-ed25519*|ssh-rsa*|ecdsa-*) : ;;
  *) echo "  ✗ set MGMT_PUB to your nave-mgmt public line, e.g.:"; echo "      MGMT_PUB='ssh-ed25519 AAAA... nave-mgmt' sh newbox.sh"; exit 1 ;;
esac
mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
grep -qxF "$PUB" ~/.ssh/authorized_keys || printf '%s\n' "$PUB" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
command -v restorecon >/dev/null 2>&1 && restorecon -Rv ~/.ssh >/dev/null 2>&1 || true
echo "  installed (append; nothing overwritten)"

# 2) Baseline hardening -----------------------------------------------------
# Reuse the canonical hardener so there's one source of truth.
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -f "$DIR/harden.sh" ]; then
  sh "$DIR/harden.sh"
else
  echo "  (harden.sh not found next to newbox.sh — run 'sh deploy/ops/harden.sh' after cloning the repo)"
fi

echo
echo "== newbox DONE =="
echo "NEXT (manual, from your Mac with the provider console open as a lifeline):"
echo "  1) Provider edge firewall -> allow only 22/80/443 inbound."
echo "  2) ssh -i ~/.ssh/nave_mgmt -o IdentitiesOnly=yes root@<ip> 'echo KEY_OK'   # confirm key login"
echo "  3) sh deploy/ops/rekey.sh root@<ip> --lock                                 # then disable passwords"
