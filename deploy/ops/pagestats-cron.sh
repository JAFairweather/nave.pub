#!/usr/bin/env bash
# pagestats-cron.sh — keep https://nave.pub/pagestats/ fresh. Run on the box as root.
#
#   deploy/ops/pagestats-cron.sh          # install: add the cron line (every 5 minutes), then run once
#   deploy/ops/pagestats-cron.sh run      # what cron runs: tidy old log files, write the page
#   deploy/ops/pagestats-cron.sh remove   # take the cron line out and delete the page
#
# Install it with the Ops workflow (task run-script, script pagestats-cron.sh). The page is written
# by page-visits.sh --html into the caddy_data volume, where the nave.pub block serves it from
# /data/pagestats. It holds counts only.
# `run` also deletes every file in the visits directory, except the live pages.log, that was last
# written more than 91 days ago. Caddy deletes its own rolled files after 90 days, but only once its
# daily timer is running; this covers a quiet spell after a restart, and the earlier bomba.log.
set -u
here=$(cd "$(dirname "$0")" && pwd)
vol=${PAGESTATS_VOL:-/var/lib/docker/volumes/deploy_caddy_data/_data}   # tests point this at a scratch directory
visits=$vol/visits
outdir=$vol/pagestats
mark='# pagestats-schedule'
line="*/5 * * * * bash $here/pagestats-cron.sh run >/dev/null 2>>/var/log/pagestats.log $mark"

case "${1:-install}" in
run)
	[ -d "$vol" ] || { echo "$(date -u +%FT%TZ) no caddy data volume at $vol" >&2; exit 1; }
	umask 022
	mkdir -p "$outdir" && chmod 755 "$outdir"
	if [ -d "$visits" ]; then find "$visits" -maxdepth 1 -type f ! -name pages.log -mtime +91 -delete; fi
	VISITS_DIR="$visits" bash "$here/page-visits.sh" --html "$outdir/index.html" || { echo "$(date -u +%FT%TZ) page-visits.sh failed" >&2; exit 1; }
	;;
install)
	[ "$(id -u)" = 0 ] || { echo "run as root on the box"; exit 1; }
	command -v python3 >/dev/null || { echo "python3 is not installed"; exit 1; }
	# The line goes first, above any CRON_TZ another job set for itself; every other line is kept.
	t=$(mktemp) || exit 1
	{ echo "$line"; crontab -l 2>/dev/null | grep -vF "$mark"; } > "$t"
	crontab "$t"; rc=$?; rm -f "$t"
	[ "$rc" = 0 ] || { echo "could not install the cron line"; exit 1; }
	crontab -l | grep -F "$mark"
	bash "$here/pagestats-cron.sh" run && ls -l "$outdir/index.html"
	;;
remove)
	[ "$(id -u)" = 0 ] || { echo "run as root on the box"; exit 1; }
	t=$(mktemp) || exit 1
	crontab -l 2>/dev/null | grep -vF "$mark" > "$t"; crontab "$t"; rm -f "$t"
	rm -f "$outdir/index.html"; rmdir "$outdir" 2>/dev/null
	echo "removed"
	;;
*) echo "usage: pagestats-cron.sh [install|run|remove]"; exit 1 ;;
esac
