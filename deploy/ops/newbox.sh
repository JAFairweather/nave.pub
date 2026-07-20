#!/bin/sh
# Nave NEW-BOX bring-up — run as root ON A FRESH BOX (provider console/first SSH).
# Installs the single management key + baseline hardening in one shot, so every
# new server is born to the same standard. See deploy/ops/ssh-standard.md.
#
#   curl -fsSL https://raw.githubusercontent.com/JAFairweather/nave.pub/main/deploy/ops/newbox.sh | sh
#   # or scp it over:  sh newbox.sh
#
# Distro-aware (dnf/apt, firewalld/ufw). Idempotent. Deliberately does NOT
# disable passwords — that's the one guided manual step (rekey.sh --lock from
# your Mac, once you've CONFIRMED key login), so a fresh box can never lock you
# out before the key is proven.
set -eu
RAW="${MGMT_PUB_URL:-https://raw.githubusercontent.com/JAFairweather/nave.pub/main/deploy/ops/nave_mgmt.pub}"
echo "== nave newbox bring-up on $(hostname) =="

# 1) Management key ---------------------------------------------------------
echo "-- management key --"
PUB="${MGMT_PUB:-}"
if [ -z "$PUB" ]; then
  PUB="$(curl -fsSL "$RAW" 2>/dev/null | grep -E '^(ssh-ed25519|ssh-rsa|ecdsa-)' | head -1 || true)"
fi
case "$PUB" in
  ssh-ed25519*|ssh-rsa*|ecdsa-*) : ;;
  *) echo "  ✗ no valid pubkey (set MGMT_PUB='ssh-ed25519 …' or commit deploy/ops/nave_mgmt.pub first)"; exit 1 ;;
esac
mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
grep -qxF "$PUB" ~/.ssh/authorized_keys || printf '%s\n' "$PUB" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
command -v restorecon >/dev/null 2>&1 && restorecon -Rv ~/.ssh >/dev/null 2>&1 || true
echo "  installed (append; nothing overwritten)"

# 2) Pick package + firewall tooling for this distro ------------------------
if command -v dnf >/dev/null 2>&1; then PKG="dnf install -y"; FW=firewalld
elif command -v apt-get >/dev/null 2>&1; then export DEBIAN_FRONTEND=noninteractive; apt-get update -y >/dev/null 2>&1 || true; PKG="apt-get install -y"; FW=ufw
else echo "  (unknown package manager — install firewall/fail2ban by hand)"; PKG=""; FW=""; fi

# 3) Host firewall: 22/80/443 only ------------------------------------------
echo "-- host firewall ($FW) --"
if [ "$FW" = firewalld ]; then
  $PKG firewalld >/dev/null 2>&1 || true
  systemctl enable --now firewalld >/dev/null 2>&1 || true
  firewall-cmd --permanent --add-service=ssh --add-service=http --add-service=https >/dev/null 2>&1 || true
  firewall-cmd --reload >/dev/null 2>&1 || true
  echo "  allowed: $(firewall-cmd --list-services 2>/dev/null)"
elif [ "$FW" = ufw ]; then
  $PKG ufw >/dev/null 2>&1 || true
  ufw allow 22/tcp >/dev/null 2>&1 || true
  ufw allow 80/tcp >/dev/null 2>&1 || true
  ufw allow 443/tcp >/dev/null 2>&1 || true
  ufw --force enable >/dev/null 2>&1 || true
  echo "  ufw: 22/80/443 allowed"
fi
echo "  NOTE: Docker publishes ports past the host firewall. Seal extras (e.g. :8080)"
echo "        at the PROVIDER edge firewall (22/80/443 only). See ssh-standard.md."

# 4) fail2ban ----------------------------------------------------------------
echo "-- fail2ban --"
if [ "$PKG" != "" ]; then
  command -v dnf >/dev/null 2>&1 && $PKG epel-release >/dev/null 2>&1 || true
  if $PKG fail2ban >/dev/null 2>&1; then
    mkdir -p /etc/fail2ban/jail.d
    cat > /etc/fail2ban/jail.d/sshd.local <<'EOF'
[sshd]
enabled  = true
maxretry = 6
findtime = 10m
bantime  = 1h
EOF
    systemctl enable --now fail2ban >/dev/null 2>&1 || true
    echo "  sshd jail active (maxretry=6)"
  else echo "  (fail2ban unavailable — firewall is the main guard)"; fi
fi

# 5) Automatic security updates ---------------------------------------------
echo "-- auto security updates --"
if command -v dnf >/dev/null 2>&1; then
  $PKG dnf-automatic >/dev/null 2>&1 && {
    sed -i 's/^upgrade_type.*/upgrade_type = security/' /etc/dnf/automatic.conf 2>/dev/null || true
    sed -i 's/^apply_updates.*/apply_updates = yes/'    /etc/dnf/automatic.conf 2>/dev/null || true
    systemctl enable --now dnf-automatic.timer >/dev/null 2>&1 || true
    echo "  dnf-automatic: security updates on"
  } || echo "  (dnf-automatic unavailable)"
elif command -v apt-get >/dev/null 2>&1; then
  $PKG unattended-upgrades >/dev/null 2>&1 && {
    dpkg-reconfigure -f noninteractive unattended-upgrades >/dev/null 2>&1 || true
    echo "  unattended-upgrades: on"
  } || echo "  (unattended-upgrades unavailable)"
fi

echo
echo "== DONE: mgmt key + firewall + fail2ban + auto-updates =="
echo "NEXT (from your Mac, with a console open as a lifeline):"
echo "  1) ssh -i ~/.ssh/nave_mgmt root@$(hostname -I 2>/dev/null | awk '{print $1}')   # confirm KEY login"
echo "  2) sh deploy/ops/rekey.sh root@<ip> --lock                                      # then disable passwords"
echo "  3) Provider edge firewall → allow only 22/80/443."
