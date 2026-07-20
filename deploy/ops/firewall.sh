#!/bin/sh
# Docker-safe on-box firewall — replaces the provider-panel dependency for basic
# port control. Two layers, because a Docker host has two traffic paths:
#
#  1) HOST-BOUND traffic (things the host itself listens on: sshd:22, native
#     Caddy:80/443, warm.contact's node:8484) goes through the INPUT hook. We add
#     our OWN nftables table `nave_fw` with an input drop-policy that allows lo,
#     established, ICMP, the Docker bridge subnet (so containers can still reach
#     the host, e.g. host.docker.internal), and inbound 22/80/443 — everything
#     else host-bound is dropped. We manage ONLY our table (idempotent
#     delete+recreate) and NEVER `flush ruleset`, so Docker's own nftables rules
#     are untouched (that's the mistake firewalld made).
#
#  2) DOCKER-PUBLISHED ports (a container published with -p on 0.0.0.0, e.g. the
#     bunker's :8080) BYPASS the INPUT chain via DNAT/FORWARD, so INPUT can't
#     filter them. Docker's `DOCKER-USER` chain is the sanctioned hook that runs
#     BEFORE Docker's own rules. We seal all published ports to the world EXCEPT
#     80/443. DOCKER-USER is wiped when the daemon restarts, so we make it durable
#     with a systemd unit (After=docker.service) + a docker.service drop-in
#     (ExecStartPost) that re-applies it on every daemon start.
#
# SSH (:22) is a HOST service, never in DOCKER-USER, and is explicitly allowed in
# the INPUT table — so nothing here can lock out SSH, and the established CI/SSH
# connection survives the apply (established,related is the first accept).
set -u
echo "== nave firewall (Docker-safe) =="

# Ensure nft + iptables present.
if ! command -v nft >/dev/null 2>&1; then
  command -v dnf >/dev/null 2>&1 && dnf install -y nftables >/dev/null 2>&1
  command -v apt-get >/dev/null 2>&1 && { apt-get update -y >/dev/null 2>&1; apt-get install -y nftables >/dev/null 2>&1; }
fi
NFT=$(command -v nft || echo /usr/sbin/nft)

# ---- Layer 1: nftables INPUT (host-bound ports) --------------------------
echo "-- nftables INPUT filter --"
install -d /etc/nftables.d
cat > /etc/nftables.d/nave-fw.nft <<'NFT'
# Manage only 'nave_fw'. The empty declaration ensures the table exists so the
# delete never errors on first run; then we recreate it. We do NOT flush the
# whole ruleset — Docker's tables must stay intact.
table inet nave_fw
delete table inet nave_fw
table inet nave_fw {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    ct state invalid drop
    iif lo accept
    ip saddr 172.16.0.0/12 accept          # Docker bridge subnets: container -> host (host.docker.internal, etc.)
    meta l4proto { icmp, ipv6-icmp } accept
    tcp dport { 22, 80, 443 } accept
  }
}
NFT
if "$NFT" -f /etc/nftables.d/nave-fw.nft; then
  echo "  loaded: allow lo/established/docker-subnet/icmp + tcp 22,80,443; drop other host-bound"
else
  echo "  !! nft load FAILED — leaving firewall unset (no change)"; exit 1
fi

# Persist on boot.
cat > /etc/systemd/system/nave-fw.service <<UNIT
[Unit]
Description=Nave nftables input firewall
After=network-pre.target
Wants=network-pre.target
[Service]
Type=oneshot
ExecStart=$NFT -f /etc/nftables.d/nave-fw.nft
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl enable --now nave-fw.service >/dev/null 2>&1 && echo "  nave-fw.service enabled (survives reboot)"

# ---- Layer 2: DOCKER-USER (published ports) — docker hosts only ----------
if command -v docker >/dev/null 2>&1; then
  echo "-- DOCKER-USER seal (published ports except 80/443) --"
  cat > /usr/local/sbin/nave-docker-fw.sh <<'DFW'
#!/bin/sh
# Seal Docker-PUBLISHED ports to the world except 80/443. Runs on every docker
# start (DOCKER-USER is recreated empty each time). Never touches host INPUT, so
# it cannot affect SSH.
set -u
command -v iptables >/dev/null 2>&1 || exit 0
EXT=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
[ -n "$EXT" ] || exit 0
iptables -C DOCKER-USER -j RETURN 2>/dev/null || exit 0   # chain must exist (docker up)
iptables -F DOCKER-USER
iptables -A DOCKER-USER -i "$EXT" -p tcp -m conntrack --ctstate NEW -m multiport --dports 80,443 -j RETURN
iptables -A DOCKER-USER -i "$EXT" -p tcp -m conntrack --ctstate NEW -j DROP
iptables -A DOCKER-USER -j RETURN
DFW
  chmod +x /usr/local/sbin/nave-docker-fw.sh
  cat > /etc/systemd/system/nave-docker-fw.service <<'UNIT'
[Unit]
Description=Nave DOCKER-USER firewall (seal published ports)
After=docker.service
Requires=docker.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/nave-docker-fw.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
UNIT
  install -d /etc/systemd/system/docker.service.d
  cat > /etc/systemd/system/docker.service.d/nave-fw.conf <<'DROP'
[Service]
ExecStartPost=/usr/local/sbin/nave-docker-fw.sh
DROP
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl enable nave-docker-fw.service >/dev/null 2>&1 || true
  if /usr/local/sbin/nave-docker-fw.sh; then
    echo "  DOCKER-USER: world reaches only 80/443; other published ports (e.g. :8080) sealed"
  else
    echo "  (DOCKER-USER not applied — is docker up? re-run after 'systemctl start docker')"
  fi
else
  echo "-- no docker here — published-port seal not needed --"
fi
echo "== firewall done =="
