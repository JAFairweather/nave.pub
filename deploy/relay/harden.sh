#!/bin/sh
# DEPRECATED in place — this used to install firewalld, which BROKE Docker on the
# relay/bunker box (firewalld manages the `docker` zone + flushes Docker's
# iptables chains; on 2026-07-20 it took the box fully offline). The hardening
# standard is now Docker-safe and firewalld-free, and lives in one place:
#
#     deploy/ops/harden.sh
#
# This wrapper just calls it, so `sh deploy/relay/harden.sh` still works and can
# never re-install firewalld. Run as root ON THE BOX:
#     cd /root/nave.pub && git pull && sh deploy/relay/harden.sh
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../ops" && pwd)
exec sh "$DIR/harden.sh"
