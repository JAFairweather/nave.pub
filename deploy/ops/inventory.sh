#!/bin/sh
# Read-only box inventory — OS, Docker, firewall, containers, restart policies,
# SSH posture. Changes nothing. Run on any box:
#   sh deploy/ops/inventory.sh
# or on a box without the repo:
#   curl -fsSL https://raw.githubusercontent.com/JAFairweather/nave.pub/main/deploy/ops/inventory.sh | sh
echo "================ NAVE BOX INVENTORY: $(hostname) ================"

echo "### OS / KERNEL"
grep -E '^(NAME|VERSION|ID)=' /etc/os-release 2>/dev/null
uname -sr

echo "### VIRT / RESOURCES"
command -v systemd-detect-virt >/dev/null 2>&1 && echo "virt: $(systemd-detect-virt 2>/dev/null)"
echo "cpus: $(nproc 2>/dev/null)"; free -h 2>/dev/null | awk 'NR==1||/Mem/'
df -h / 2>/dev/null | tail -1

echo "### DOCKER"
if command -v docker >/dev/null 2>&1; then
  docker --version
  echo "enabled-on-boot: $(systemctl is-enabled docker 2>/dev/null)  active: $(systemctl is-active docker 2>/dev/null)"
else echo "docker: NOT INSTALLED"; fi

echo "### FIREWALL STATE"
echo "firewalld: $(systemctl is-active firewalld 2>/dev/null || echo inactive) / $(systemctl is-enabled firewalld 2>/dev/null || echo not-enabled)"
command -v ufw >/dev/null 2>&1 && echo "ufw: $(ufw status 2>/dev/null | head -1)" || echo "ufw: not installed"
echo "nft tables present:"; nft list tables 2>/dev/null | sed 's/^/  /' || echo "  (nft not available)"
echo "DOCKER iptables chain present: $(iptables -L DOCKER-FORWARD -n >/dev/null 2>&1 && echo yes || echo 'no/na')"

echo "### CONTAINERS (running + stopped)"
if command -v docker >/dev/null 2>&1; then
  docker ps -a --format '{{.Names}} | {{.Status}} | {{.Ports}}' 2>/dev/null
  echo "-- restart policies --"
  for c in $(docker ps -aq 2>/dev/null); do docker inspect -f '{{.Name}}  restart={{.HostConfig.RestartPolicy.Name}}' "$c" 2>/dev/null; done
  echo "-- compose projects --"
  docker ps -a --format '{{.Label "com.docker.compose.project"}} {{.Label "com.docker.compose.project.working_dir"}}' 2>/dev/null | sort -u
fi

echo "### HARDENING BASELINE"
echo "fail2ban: $(systemctl is-active fail2ban 2>/dev/null || echo none)"
echo "auto-updates: $(systemctl is-enabled unattended-upgrades 2>/dev/null || systemctl is-enabled dnf-automatic.timer 2>/dev/null || echo none)"

echo "### SSH POSTURE"
sshd -T 2>/dev/null | grep -Ei 'passwordauthentication|permitrootlogin|pubkeyauthentication' | sed 's/^/  /'
echo "authorized_keys (type + comment):"; awk '{print "  " $1, $NF}' ~/.ssh/authorized_keys 2>/dev/null

echo "### LISTENING PORTS (host)"
(ss -ltnp 2>/dev/null || netstat -ltnp 2>/dev/null) | awk 'NR==1 || /LISTEN/' | sed 's/^/  /' | head -25

echo "================ END INVENTORY: $(hostname) ================"
