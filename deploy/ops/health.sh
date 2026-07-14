#!/usr/bin/env bash
# Full stack + box health snapshot. Read-only. Run via: Ops → run-script → health.sh
set -u
echo "── containers ──"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo
echo "── disk ──";   df -h / | tail -2
echo
echo "── docker space (RECLAIMABLE = prunable) ──"; docker system df
echo
echo "── memory ──"; free -h | head -2
echo
echo "── load ──";   uptime
echo
echo "── brain schedule ──"; crontab -l 2>/dev/null | grep -A1 CRON_TZ || echo "(no crontab)"
echo "── done ──"
