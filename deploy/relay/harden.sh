#!/usr/bin/env bash
# Harden the relay/bunker VPS (AlmaLinux 10). Run as root ON THE BOX:
#   cd /root/nave.pub && git pull && sh deploy/relay/harden.sh
# Idempotent / safe to re-run. Deliberately does NOT change SSH password or
# root-login settings — that carries a lockout risk and is a guided manual step
# printed at the end. Nothing here can drop your SSH session.
set -u
echo "== nave bunker hardening =="

# 1) Firewall: allow only SSH + HTTP + HTTPS inbound. firewalld's default zone
#    already permits ssh, so this can't cut your session; http/https keep Caddy
#    (relay + bunker) reachable.
echo "-- firewalld --"
dnf install -y firewalld >/dev/null 2>&1 || echo "  (firewalld install issue — check dnf)"
systemctl enable --now firewalld
firewall-cmd --permanent --add-service=ssh --add-service=http --add-service=https >/dev/null

# 2) Seal port 8080 (the bunker web/API). Docker publishes ports straight into
#    iptables, BYPASSING firewalld zones, so :8080 stays world-reachable unless
#    we filter Docker's own chain (DOCKER-USER). Allow only docker-internal
#    sources (that's how Caddy reaches it) + localhost; drop everything else.
firewall-cmd --reload >/dev/null
echo "  inbound allowed: $(firewall-cmd --list-services)"

# 2) Seal port 8080 (the bunker web/API). Docker publishes ports straight into
#    iptables, BYPASSING firewalld zones (and firewalld --direct fails on
#    AlmaLinux 10's nft backend), so apply the rule at runtime into Docker's own
#    DOCKER-USER chain and persist it with a boot unit. Allow docker-internal +
#    localhost (Caddy's path); drop everyone else.
echo "-- seal :8080 (bunker app — force it through Caddy TLS) --"
cat > /usr/local/sbin/nave-seal-8080.sh <<'SEAL'
#!/bin/sh
# Idempotent: clear any prior copies, then insert in the order:
#   RETURN docker-net · RETURN localhost · DROP  (above Docker's default RETURN)
while iptables -D DOCKER-USER -p tcp --dport 8080 -s 172.16.0.0/12 -j RETURN 2>/dev/null; do :; done
while iptables -D DOCKER-USER -p tcp --dport 8080 -s 127.0.0.1 -j RETURN 2>/dev/null; do :; done
while iptables -D DOCKER-USER -p tcp --dport 8080 -j DROP 2>/dev/null; do :; done
iptables -I DOCKER-USER 1 -p tcp --dport 8080 -j DROP
iptables -I DOCKER-USER 1 -p tcp --dport 8080 -s 127.0.0.1 -j RETURN
iptables -I DOCKER-USER 1 -p tcp --dport 8080 -s 172.16.0.0/12 -j RETURN
SEAL
chmod +x /usr/local/sbin/nave-seal-8080.sh
if /usr/local/sbin/nave-seal-8080.sh 2>/dev/null; then echo "  :8080 sealed (docker+localhost allowed, external dropped)"
else echo "  (on-box seal failed — use the Hostinger panel firewall; see notes below)"; fi
cat > /etc/systemd/system/nave-seal-8080.service <<'UNIT'
[Unit]
Description=Seal bunker :8080 to docker-internal only
After=docker.service
Requires=docker.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/nave-seal-8080.sh
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload >/dev/null 2>&1; systemctl enable nave-seal-8080.service >/dev/null 2>&1

# 3) fail2ban — throttle/ban SSH brute force.
echo "-- fail2ban --"
dnf install -y epel-release >/dev/null 2>&1
if dnf install -y fail2ban >/dev/null 2>&1; then
  cat > /etc/fail2ban/jail.d/sshd.local <<'EOF'
[sshd]
enabled  = true
maxretry = 4
findtime = 10m
bantime  = 1h
EOF
  systemctl enable --now fail2ban >/dev/null 2>&1
  echo "  fail2ban: sshd jail active"
else echo "  (fail2ban not installed — EPEL may be unavailable; firewall is the main guard)"; fi

# 4) Automatic security updates.
echo "-- auto security updates --"
if dnf install -y dnf-automatic >/dev/null 2>&1; then
  sed -i 's/^upgrade_type.*/upgrade_type = security/' /etc/dnf/automatic.conf 2>/dev/null || true
  sed -i 's/^apply_updates.*/apply_updates = yes/' /etc/dnf/automatic.conf 2>/dev/null || true
  systemctl enable --now dnf-automatic.timer >/dev/null 2>&1
  echo "  dnf-automatic: security updates enabled"
else echo "  (dnf-automatic not installed)"; fi

# 5) Lock the bunker env file (holds ENCRYPTION_KEY that decrypts your nsec).
echo "-- secrets perms --"
if [ -f /root/bunker46/.env ]; then chmod 600 /root/bunker46/.env; echo "  /root/bunker46/.env → 600"; else echo "  (no /root/bunker46/.env found)"; fi

echo
echo "== DONE: firewall + :8080 sealed + fail2ban + auto-updates + perms =="
echo
echo "!! STILL TO DO BY HAND — SSH key-only (lockout risk, do it carefully):"
echo "   SSH currently allows passwords + root login. To lock to key-only:"
echo "   1) In a SEPARATE terminal, confirm 'ssh root@145.79.6.80' logs in with your KEY"
echo "      (no password prompt). Do NOT skip this."
echo "   2) Only then, on the box:"
echo "        sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config"
echo "        sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config"
echo "        sshd -t && systemctl reload sshd"
echo "   3) Keep THIS session open and test a fresh 'ssh' login before closing it."
echo
echo "   Also back up /root/bunker46/.env to your Mac vault — its ENCRYPTION_KEY"
echo "   is what decrypts your sovereign nsec; losing it means re-importing the key."
