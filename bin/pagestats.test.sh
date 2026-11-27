#!/usr/bin/env bash
# pagestats.test.sh — the page visit log and the /pagestats page.
#
#   bin/pagestats.test.sh            # the Caddyfile and the scripts in this checkout
#   bin/pagestats.test.sh --live     # also https://nave.pub/pagestats/, and on the box the log and the job
#
# Three pages are logged (/bomba, /sistema, /asada/esterones) and nothing else on the hub. The log
# holds visitor addresses, so it stays on the box; /pagestats is public and shows counts only.
set -u
cd "$(dirname "$0")/.."
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }
chk() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

cf=deploy/caddy/Caddyfile
hub=$(awk '/^nave\.pub \{/{p=1} p{print} p&&/^\}/{exit}' "$cf")
has() { printf '%s\n' "$hub" | grep -qF -- "$1"; }
list='/bomba /bomba/* /sistema /sistema/* /asada/esterones /asada/esterones/*'
echo "Caddyfile: $cf"
chk 'the log takes the three pages and skips every other path' 'has "@pages path $list" && has "@notpages not path $list" && has "log_skip @notpages"'
chk 'the log is in the caddy data volume, rolls daily and keeps rolled files 90 days' 'has "output file /data/visits/pages.log" && has "roll_at 00:00" && has "roll_keep 100" && has "roll_keep_for 2160h"'
chk 'the log drops request headers, query strings, TLS detail and response headers' 'has "request>headers delete" && has "request>tls delete" && has "resp_headers delete" && has "request>uri regexp \"\\?.*\" \"\"" && has "referer regexp \"\\?.*\" \"\""'
chk 'no other site block logs visits' '[ "$(grep -cE "^[[:space:]]*log( [a-z0-9_]+)? \{" "$cf")" = 2 ] && has "log {" && [ "$(grep -cE "^[[:space:]]*log_skip " "$cf")" = 1 ]'
# Two lines outside the block that the log needs: without the first, plain-HTTP requests to every path
# on the hub are logged; without the second, requests to unknown hosts go to the container log.
chk 'plain HTTP to the hub redirects from its own block, which has no log' '[ "$(awk "/^http:\/\/nave\.pub \{/{p=1;next} p&&/^\}/{exit} p" "$cf" | tr -d "\t")" = "redir https://nave.pub{uri} 308" ]'
chk 'no access lines go to the container log' 'awk "/^\{/{p=1} p{print} p&&/^\}/{exit}" "$cf" | tr -d "\t" | sed -n "/^log default {\$/,/^}\$/p" | grep -qx "exclude http.log.access"'
# /pagestats is served from its own directory in the volume, kept out of search, and not logged.
ps=$(printf '%s\n' "$hub" | awk '/^\thandle_path \/pagestats\/\* \{/{p=1} p{print} p&&/^\t\}/{exit}' | tr -d '\t')
chk '/pagestats is served from /data/pagestats only, with noindex' 'printf "%s\n" "$ps" | grep -qx "root \* /data/pagestats" && printf "%s\n" "$ps" | grep -qx "header X-Robots-Tag \"noindex, nofollow\"" && has "redir /pagestats /pagestats/ 308"'
chk '/pagestats is not itself logged' '! printf "%s\n" "$list" | grep -q pagestats'
# The script that reads the log knows the same pages.
want=$(printf '%s\n' $list | grep -v '\*$' | sed 's#$#/#' | sort | tr '\n' ' ')
got=$(sed -n "/^PAGES = \[/,/\]\$/p" deploy/ops/page-visits.sh | grep -oE "\('/[a-z/]+/'" | tr -d "('" | sort | tr '\n' ' ')
chk "page-visits.sh lists the same pages ($got)" '[ -n "$got" ] && [ "$got" = "$want" ]'

echo "scripts: sample log"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/vol/visits"
now=1795737600                       # 2026-11-27 00:00 UTC = 26 Nov 18:00 in Costa Rica
ln() { printf '{"ts":%s,"request":{"client_ip":"%s","method":"%s","uri":"%s"},"status":%s,"ua":"%s","referer":"%s"}\n' "$@"; }
B='Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Safari/604.1'
{
	ln $((now-600))    8.8.8.8  GET /bomba/ 200 "$B" 'https://referring.example/x'      # person, today
	ln $((now-500))    8.8.8.8  GET /bomba/ 304 "$B" ''                                 # same person again
	ln $((now-400))    1.1.1.1  GET /bomba/ 200 "$B" ''                                 # second person
	ln $((now-300))    9.9.9.9  GET /bomba/ 200 'WhatsApp/2.23 A' ''                    # link preview
	ln $((now-200))    10.0.0.5 GET /bomba/ 200 "$B" ''                                 # private address: ours
	ln $((now-100))    8.8.8.8  GET /bomba 308 "$B" ''                                  # redirect: not a view
	ln $((now-90))     8.8.8.8  GET /bomba/missing.html 404 "$B" ''                     # not served: not a view
	ln $((now-80))     8.8.8.8  POST /bomba/ 405 "$B" ''                                # not a GET
	ln $((now-86400*3)) 8.8.4.4 GET /sistema/ 200 "$B" ''                               # three days ago
	ln $((now-70))     8.8.4.4  GET /asada/esterones/admin/ 200 "$B" ''                 # a page under the mockup
	ln $((now-60))     8.8.4.4  GET /asada/esterones/assets/app.css 200 "$B" ''         # not an HTML page
	echo 'not json'
} > "$t/vol/visits/pages.log"
ln $((now-86400*10)) 208.67.222.222 GET /bomba/ 200 "$B" '' | gzip > "$t/vol/visits/pages-2026-11-17T00-00-00.000-time.log.gz"
touch -d '100 days ago' "$t/vol/visits/bomba.log" "$t/vol/visits/pages-old-time.log.gz"; touch -d '100 days ago' "$t/keep-check"
txt=$(VISITS_DIR="$t/vol/visits" bash deploy/ops/page-visits.sh 2>&1)
chk 'text summary: 4 views of /bomba by 3 people, 1 preview, 1 of our own' 'printf "%s\n" "$txt" | grep -A3 "^/bomba/" | tr "\n" " " | grep -q "people (browsers): 4 views from 3 addresses.*scripts: 1 views from 1 addresses.*own checks: 1 views from 1 addresses"'
chk 'text summary: names the visitor addresses (it stays on the box)' 'printf "%s\n" "$txt" | grep -q "person 8.8.8.8 "'
PAGESTATS_VOL="$t/vol" PAGESTATS_NOW=$now bash deploy/ops/pagestats-cron.sh run
out=$t/vol/pagestats/index.html
chk 'the job writes the page, readable by the web server' '[ -s "$out" ] && [ "$(stat -c %a "$out")" = 644 ] && [ ! -e "$out.tmp" ]'
card() { awk -v h="nave.pub$1<" 'index($0,h){p=1} p{print} p&&/<\/section>/{exit}' "$out" | tr -d '\n'; }
chk 'page: /bomba has 4 views by people, 3 today, 3 in 7 days, 3 visitors, 1 preview' 'card /bomba/ | grep -q "<b>4</b>.*Today</dt><dd>3</dd>.*Last 7 days</dt><dd>3</dd>.*Visitors</dt><dd>3</dd>.*robots</dt><dd>1</dd>"'
chk 'page: /sistema has 1 view, none today' 'card /sistema/ | grep -q "<b>1</b> <span>view by people so far.*Today</dt><dd>0</dd>.*Last 7 days</dt><dd>1</dd>"'
chk 'page: the mockup counts its admin page and not its stylesheet' 'card /asada/esterones/ | grep -q "<b>1</b>"'
chk 'page: no address, browser or referring page is in it' '! grep -qE "8\.8\.8\.8|1\.1\.1\.1|9\.9\.9\.9|8\.8\.4\.4|208\.67|10\.0\.0\.5|iPhone|WhatsApp/|referring\.example" "$out"'
chk 'page: asks search engines to stay away, and loads nothing from another site' 'grep -q "<meta name=\"robots\" content=\"noindex, nofollow\">" "$out" && ! grep -qE "(src|href)=\"(https?:)?//" "$out"'
chk 'job: deletes log files last written over 91 days ago, keeps the rest' '[ ! -e "$t/vol/visits/bomba.log" ] && [ ! -e "$t/vol/visits/pages-old-time.log.gz" ] && [ -s "$t/vol/visits/pages.log" ] && [ -e "$t/vol/visits/pages-2026-11-17T00-00-00.000-time.log.gz" ] && [ -e "$t/keep-check" ]'
touch -d '100 days ago' "$t/vol/visits/pages.log"; PAGESTATS_VOL="$t/vol" bash deploy/ops/pagestats-cron.sh run
chk 'job: never deletes the live log' '[ -s "$t/vol/visits/pages.log" ]'
rm -rf "$t/vol/visits" "$t/vol/pagestats"; PAGESTATS_VOL="$t/vol" bash deploy/ops/pagestats-cron.sh run
chk 'job: with no log yet, writes a page of zeros' 'grep -q "<b>0</b> <span>views by people so far" "$t/vol/pagestats/index.html"'

if [ "${1:-}" = --live ]; then
	url=https://nave.pub/pagestats
	echo "live: $url/"
	code=$(curl -s -m 20 -o "$t/body" -D "$t/head" -w '%{http_code}' "$url/")
	chk "/pagestats/ answers 200 (got $code)" '[ "$code" = 200 ]'
	chk 'it is HTML, marked noindex and not cached' 'grep -qiE "^content-type: *text/html" "$t/head" && grep -qiE "^x-robots-tag: *noindex" "$t/head" && grep -qiE "^cache-control: *no-store" "$t/head"'
	chk 'it lists the three pages' 'grep -q "nave.pub/bomba/<" "$t/body" && grep -q "nave.pub/sistema/<" "$t/body" && grep -q "nave.pub/asada/esterones/<" "$t/body"'
	redir=$(curl -s -m 20 -o /dev/null -w '%{http_code} %{redirect_url}' "$url")
	chk "/pagestats redirects to the slash form ($redir)" '[ "$redir" = "308 $url/" ]'
	chk 'nothing else in the volume is served' '[ "$(curl -s -m 20 -o /dev/null -w "%{http_code}" "$url/../caddy/")" != 200 ] && [ "$(curl -s -m 20 -o /dev/null -w "%{http_code}" --path-as-is "$url/../visits/pages.log")" != 200 ]'
	# On the box, as root: each page is logged without its query string, the home page and
	# /pagestats are not, the job is installed and the page is fresh.
	vol=/var/lib/docker/volumes/deploy_caddy_data/_data
	vlog=$vol/visits/pages.log
	if [ "$(id -u)" = 0 ] && [ -d /var/lib/docker/volumes ]; then
		mark="visit-log-check-$$-$RANDOM"
		for p in /bomba/ /sistema/ /asada/esterones/ / /pagestats/; do curl -s -m 20 -o /dev/null -A "$mark" "https://nave.pub$p?probe=1"; done
		sleep 1
		got=$(grep -F "$mark" "$vlog" 2>/dev/null | grep -oE '"uri":"[^"]*"' | sort | tr '\n' ' ')
		chk "visit log has the three page requests, without query strings, and no other ($got)" '[ "$got" = "\"uri\":\"/asada/esterones/\" \"uri\":\"/bomba/\" \"uri\":\"/sistema/\" " ]'
		chk 'the job is in root'"'"'s crontab' 'crontab -l 2>/dev/null | grep -qF "pagestats-cron.sh run"'
		chk 'the page was written in the last 10 minutes' '[ -n "$(find "$vol/pagestats/index.html" -mmin -10 2>/dev/null)" ]'
	else
		echo "  skip the log and the job (not on the box as root)"
	fi
fi

if [ "$fail" = 0 ]; then echo "pagestats: ok"; else echo "pagestats: FAILED"; exit 1; fi
