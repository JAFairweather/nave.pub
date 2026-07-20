#!/bin/sh
# Nave baseline hardening — Docker-safe. Run as root ON ANY box:
#   cd /root/nave.pub && git pull && sh deploy/ops/harden.sh
# Idempotent / safe to re-run. Does NOT touch SSH password/root-login settings
# (that's rekey.sh --lock, which verifies key login first) and deliberately does
# NOT install firewalld — firewalld breaks Docker on these hosts (it manages the
# `docker` zone and flushes Docker's iptables chains; on 2026-07-20 it took the
# relay/bunker box fully offline). Port control is the PROVIDER EDGE FIREWALL.
set -u
echo "== nave baseline hardening on $(hostname) =="

# 0) Pick package manager.
if command -v dnf >/dev/null 2>&1; then PKG="dnf install -y"; DEB=0
elif command -v apt-get >/dev/null 2>&1; then export DEBIAN_FRONTEND=noninteractive; apt-get update -y >/dev/null 2>&1 || true; PKG="apt-get install -y"; DEB=1
else echo "  (unknown package manager — install fail2ban + auto-updates by hand)"; PKG=""; DEB=0; fi

# 1) REMOVE firewalld if present. This is the whole point — it must not run.
echo "-- firewalld (must be OFF) --"
if systemctl list-unit-files 2>/dev/null | grep -q '^firewalld'; then
  systemctl disable --now firewalld >/dev/null 2>&1 || true
  echo "  firewalld stopped + disabled (Docker manages its own iptables)"
else
  echo "  firewalld not present — good"
fi

# 1b) On-box firewall — Docker-safe port control WITHOUT the provider panel
#     (nftables INPUT + DOCKER-USER). The edge firewall stays as belt-and-suspenders.
echo "-- on-box firewall --"
FW="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)/firewall.sh"
if [ -f "$FW" ]; then sh "$FW"
else curl -fsSL https://raw.githubusercontent.com/JAFairweather/nave.pub/main/deploy/ops/firewall.sh | sh; fi

# 2) fail2ban — SSH brute-force throttle. With firewalld gone it uses nftables/
#    iptables directly (separate from Docker's chains, so it can't break Docker).
#    Tuned gently: SSH is key-only after rekey, so brute force can't succeed;
#    this is just noise reduction, and we don't want to self-ban during ops.
echo "-- fail2ban --"
if [ -n "$PKG" ]; then
  [ "$DEB" = 0 ] && ($PKG epel-release >/dev/null 2>&1 || true)
  if $PKG fail2ban >/dev/null 2>&1; then
    mkdir -p /etc/fail2ban/jail.d
    cat > /etc/fail2ban/jail.d/sshd.local <<'EOF'
[sshd]
enabled  = true
maxretry = 10
findtime = 10m
bantime  = 15m
EOF
    systemctl enable --now fail2ban >/dev/null 2>&1 || true
    echo "  sshd jail active (maxretry=10, bantime=15m — gentle, key-only SSH anyway)"
  else echo "  (fail2ban unavailable — key-only SSH is the real guard)"; fi
fi

# 3) Automatic security updates.
echo "-- auto security updates --"
if [ "$DEB" = 0 ] && command -v dnf >/dev/null 2>&1; then
  $PKG dnf-automatic >/dev/null 2>&1 && {
    sed -i 's/^upgrade_type.*/upgrade_type = security/' /etc/dnf/automatic.conf 2>/dev/null || true
    sed -i 's/^apply_updates.*/apply_updates = yes/'    /etc/dnf/automatic.conf 2>/dev/null || true
    systemctl enable --now dnf-automatic.timer >/dev/null 2>&1 || true
    echo "  dnf-automatic: security updates on"
  } || echo "  (dnf-automatic unavailable)"
elif [ "$DEB" = 1 ]; then
  $PKG unattended-upgrades >/dev/null 2>&1 && {
    dpkg-reconfigure -f noninteractive unattended-upgrades >/dev/null 2>&1 || true
    echo "  unattended-upgrades: on"
  } || echo "  (unattended-upgrades unavailable)"
fi

# 4) Reboot survival: Docker enabled on boot; every container restart:unless-stopped.
echo "-- reboot survival --"
if command -v docker >/dev/null 2>&1; then
  systemctl enable docker >/dev/null 2>&1 || true
  echo "  docker enabled on boot"
  bad=$(docker ps -a --filter 'label=com.docker.compose.project' --format '{{.Names}} {{.Labels}}' 2>/dev/null | grep -v 'restart' | wc -l 2>/dev/null || echo 0)
  echo "  (compose services should be restart: unless-stopped — check your compose files)"
else echo "  (docker not installed here)"; fi

# 5) Lock down any secret env files.
echo "-- secret file perms --"
for f in /root/bunker46/.env /root/nave.pub/*/.env; do
  [ -f "$f" ] && { chmod 600 "$f"; echo "  $f -> 600"; }
done

echo
echo "== DONE: firewalld removed + fail2ban + auto-updates + reboot survival + perms =="
echo "REMAINING (manual, once): provider edge firewall -> 22/80/443 only."
