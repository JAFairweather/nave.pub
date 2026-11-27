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
# written 91 days ago or longer (a rolled file was last written when it rolled, so its oldest line
# can be a day or two older than that). Caddy deletes its own rolled files after 90 days, but only once its
# daily timer is running; this covers a quiet spell after a restart, and the earlier bomba.log.
set -u
here=$(cd "$(dirname "$0")" && pwd)
vol=${PAGESTATS_VOL:-/var/lib/docker/volumes/deploy_caddy_data/_data}   # tests point this at a scratch directory
visits=$vol/visits
outdir=$vol/pagestats
mark='# pagestats-schedule'
line="*/5 * * * * bash $here/pagestats-cron.sh run >/dev/null 2>>/var/log/pagestats.log $mark"

# Root's crontab without our line, on stdout. Fails, printing nothing, unless the crontab was read
# or there is none yet: any other error must not end in a crontab that holds only our line.
others() {
	local cur err rc
	err=$(mktemp) || return 1
	cur=$(crontab -l 2>"$err"); rc=$?
	if [ "$rc" != 0 ] && ! grep -qi 'no crontab for' "$err"; then
		echo "could not read the crontab (exit $rc): $(head -c 200 "$err")" >&2; rm -f "$err"; return 1
	fi
	rm -f "$err"
	[ -z "$cur" ] || printf '%s\n' "$cur" | grep -vF "$mark"
	return 0
}

case "${1:-install}" in
run)
	[ -d "$vol" ] || { echo "$(date -u +%FT%TZ) no caddy data volume at $vol" >&2; exit 1; }
	umask 022
	mkdir -p "$outdir" && chmod 755 "$outdir"
	if [ -d "$visits" ]; then find "$visits" -maxdepth 1 -type f ! -name pages.log -mtime +90 -delete; fi
	VISITS_DIR="$visits" bash "$here/page-visits.sh" --html "$outdir/index.html" || { echo "$(date -u +%FT%TZ) page-visits.sh failed" >&2; exit 1; }
	;;
install)
	[ "$(id -u)" = 0 ] || { echo "run as root on the box"; exit 1; }
	command -v python3 >/dev/null || { echo "python3 is not installed"; exit 1; }
	# The line goes first, above any CRON_TZ another job set for itself; every other line is kept.
	t=$(mktemp) || exit 1
	rest=$(others) || { rm -f "$t"; echo "crontab left as it was"; exit 1; }
	{ echo "$line"; [ -z "$rest" ] || printf '%s\n' "$rest"; } > "$t"
	crontab "$t"; rc=$?; rm -f "$t"
	[ "$rc" = 0 ] || { echo "could not install the cron line"; exit 1; }
	crontab -l | grep -F "$mark"
	bash "$here/pagestats-cron.sh" run && ls -l "$outdir/index.html"
	;;
remove)
	[ "$(id -u)" = 0 ] || { echo "run as root on the box"; exit 1; }
	t=$(mktemp) || exit 1
	rest=$(others) || { rm -f "$t"; echo "crontab left as it was"; exit 1; }
	[ -z "$rest" ] || printf '%s\n' "$rest" > "$t"
	crontab "$t"; rm -f "$t"
	rm -f "$outdir/index.html"; rmdir "$outdir" 2>/dev/null
	echo "removed"
	;;
*) echo "usage: pagestats-cron.sh [install|run|remove]"; exit 1 ;;
esac
