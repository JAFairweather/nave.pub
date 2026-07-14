#!/usr/bin/env bash
# Disk / space report. Read-only — shows what's using space and what's prunable,
# but reclaims nothing. Run via: Ops → run-script → disk.sh
set -u
echo "── filesystem ──"; df -h / | tail -2
echo
echo "── docker space (RECLAIMABLE column = safe to prune) ──"; docker system df
echo
echo "── largest dirs under /root (top 12) ──"
du -h -d2 /root 2>/dev/null | sort -rh | head -12
echo
echo "── dangling images ──"; docker images -f dangling=true
echo
echo "to actually reclaim, use Ops → custom:"
echo "  docker system prune -f          # dangling images, stopped containers, unused networks"
echo "  docker system prune -af          # ALSO unused images (heavier, rebuilds next deploy)"
echo "── done ──"
