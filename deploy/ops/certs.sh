#!/usr/bin/env bash
# Cert expiry inventory for every nave vhost, probed against the local Caddy.
# Read-only. Run via: Ops → run-script → certs.sh
set -u
hosts="nave.pub www.nave.pub noir.nave.pub director.nave.pub \
nvelope.nave.pub nontact.nave.pub notegate.nave.pub ntrigue.nave.pub \
nvoy.nave.pub nherit.nave.pub nscope.nave.pub nact.nave.pub luke.nave.pub"
now=$(date +%s)
printf '%-24s %-10s %s\n' HOST LEFT NOT_AFTER
for h in $hosts; do
  end=$(echo | openssl s_client -servername "$h" -connect 127.0.0.1:443 2>/dev/null \
        | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//')
  if [ -n "$end" ]; then
    exp=$(date -d "$end" +%s 2>/dev/null || echo 0)
    days=$(( (exp - now) / 86400 ))
    printf '%-24s %-10s %s\n' "$h" "${days}d" "$end"
  else
    printf '%-24s %-10s %s\n' "$h" "?" "(no cert served)"
  fi
done
echo "── done ── (Caddy auto-renews ~30d before expiry; anything under ~20d with no renewal is worth a look)"
