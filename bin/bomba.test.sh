#!/usr/bin/env bash
# bomba.test.sh — the /bomba page is served exactly as its author wrote it.
#
#   bin/bomba.test.sh            # the page in this checkout
#   bin/bomba.test.sh --live     # also the served page at https://nave.pub/bomba/, and on the box its visit log
#
# The page is one HTML file (inline CSS and JS) copied unchanged from the asada-tech repo, branch
# add-bomba-page, commit 5321a50, bomba/index.html. It is not edited here: a change is made there and
# copied again, and the hash below moves with it. The root file_server serves it; there is no route for it
# in the Caddyfile.
set -u
cd "$(dirname "$0")/.."
page=bomba/index.html
sum=6de3ed14b302310a99d53316bdc3bc101f915a78bd0524f06d2174decaa87b9f
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }

echo "page: $page"
[ -f "$page" ] || { bad "$page exists"; exit 1; }
if [ "$(sha256sum < "$page" | cut -d' ' -f1)" = "$sum" ]; then ok 'unchanged from the source commit'; else bad 'unchanged from the source commit'; fi
# Spanish is the default: it is the text in the HTML, and the script picks English only for #en.
if grep -qF '<h1 data-t="h1">Nuestro sistema de agua, y qué puede estar dañando las bombas</h1>' "$page"; then ok 'heading in the HTML is Spanish'; else bad 'heading in the HTML is Spanish'; fi
if grep -qF "let L=location.hash==='#en'?'en':'es'" "$page"; then ok 'opens in Spanish unless the address ends in #en'; else bad 'opens in Spanish unless the address ends in #en'; fi
if grep -qF 'en:{h1:"Our water system, and what could be wearing out the pumps"' "$page"; then ok 'English heading is in the page'; else bad 'English heading is in the page'; fi
# The only request to another site is the Google Fonts stylesheet.
out=$(grep -oE '(src|href|action)="(https?:)?//[^"]*"|url\((https?:)?//[^)]*\)|@import[^;]*|fetch\(|XMLHttpRequest|sendBeacon|WebSocket' "$page" | grep -vE '^href="https://fonts\.googleapis\.com/css2\?' || true)
if [ -z "$out" ]; then ok 'no outside request but Google Fonts'; else bad "no outside request but Google Fonts (found: $out)"; fi

# The visit log: /bomba is logged and nothing else on the hub is.
cf=deploy/caddy/Caddyfile
hub=$(awk '/^nave\.pub \{/{p=1} p{print} p&&/^\}/{exit}' "$cf")
has() { printf '%s\n' "$hub" | grep -qF -- "$1"; }
if has '@notbomba not path /bomba /bomba/*' && has 'log_skip @notbomba'; then ok 'visit log skips every path but /bomba'; else bad 'visit log skips every path but /bomba'; fi
if has 'output file /data/visits/bomba.log' && has 'roll_interval 720h' && has 'roll_keep_for 1440h'; then ok 'visit log is in the caddy data volume, rolls every 30 days and keeps rolled files 60 days'; else bad 'visit log is in the caddy data volume, rolls every 30 days and keeps rolled files 60 days'; fi
if has 'request>headers delete' && has 'request>tls delete' && has 'resp_headers delete'; then ok 'visit log drops request headers, TLS detail and response headers'; else bad 'visit log drops request headers, TLS detail and response headers'; fi
if [ "$(grep -cE '^[[:space:]]*log( [a-z0-9_]+)? \{' "$cf")" = 2 ] && has 'log {' && [ "$(grep -cE '^[[:space:]]*log_skip ' "$cf")" = 1 ]; then ok 'no other site block logs visits'; else bad 'no other site block logs visits'; fi

# Two lines outside the block that the log needs: without the first, plain-HTTP requests to every path
# on the hub are logged; without the second, requests to unknown hosts go to the container log.
if [ "$(awk '/^http:\/\/nave\.pub \{/{p=1;next} p&&/^\}/{exit} p' "$cf" | tr -d '\t')" = 'redir https://nave.pub{uri} 308' ]; then ok 'plain HTTP to the hub redirects from its own block, which has no log'; else bad 'plain HTTP to the hub redirects from its own block, which has no log'; fi
if awk '/^\{/{p=1} p{print} p&&/^\}/{exit}' "$cf" | tr -d '\t' | grep -A1 -x 'log default {' | grep -qx 'exclude http.log.access'; then ok 'no access lines go to the container log'; else bad 'no access lines go to the container log'; fi

if [ "${1:-}" = --live ]; then
	url=https://nave.pub/bomba
	echo "live: $url/"
	t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
	code=$(curl -s -m 20 -o "$t/body" -D "$t/head" -w '%{http_code}' "$url/")
	if [ "$code" = 200 ]; then ok '/bomba/ answers 200'; else bad "/bomba/ answers 200 (got $code)"; fi
	if grep -qiE '^content-type: *text/html' "$t/head"; then ok 'content-type is text/html'; else bad 'content-type is text/html'; fi
	if cmp -s "$t/body" "$page"; then ok 'served page is byte-identical to this checkout'; else bad 'served page is byte-identical to this checkout'; fi
	redir=$(curl -s -m 20 -o /dev/null -w '%{http_code} %{redirect_url}' "$url")
	case $redir in 30[1278]\ "$url/") ok "/bomba redirects to the slash form (${redir%% *})" ;; *) bad "/bomba redirects to the slash form (got $redir)" ;; esac
	code=$(curl -s -m 20 -L -o "$t/followed" -w '%{http_code}' "$url")
	if [ "$code" = 200 ] && cmp -s "$t/followed" "$page"; then ok '/bomba, followed, is the page (200)'; else bad "/bomba, followed, is the page (got $code)"; fi
	# On the box, as root: the request above is in the visit log, and a request elsewhere is not.
	vlog=/var/lib/docker/volumes/deploy_caddy_data/_data/visits/bomba.log
	if [ -r "$vlog" ]; then
		mark="visit-log-check-$$-$RANDOM"
		curl -s -m 20 -o /dev/null -A "$mark" "$url/"; curl -s -m 20 -o /dev/null -A "$mark" https://nave.pub/
		sleep 1
		if [ "$(grep -F "$mark" "$vlog" | grep -cF '"uri":"/bomba/"')" = 1 ] && [ "$(grep -cF "$mark" "$vlog")" = 1 ]; then ok 'visit log has the /bomba/ request and not the home page request'; else bad 'visit log has the /bomba/ request and not the home page request'; fi
	elif [ "$(id -u)" = 0 ] && [ -d /var/lib/docker/volumes ]; then
		bad "visit log exists on the box ($vlog)"
	else
		echo "  skip visit log (not on the box as root: $vlog)"
	fi
fi

if [ "$fail" = 0 ]; then echo "bomba: ok"; else echo "bomba: FAILED"; exit 1; fi
