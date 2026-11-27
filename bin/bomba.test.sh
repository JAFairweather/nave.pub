#!/usr/bin/env bash
# bomba.test.sh — the /bomba page is served exactly as its author wrote it.
#
#   bin/bomba.test.sh            # the page in this checkout
#   bin/bomba.test.sh --live     # also the served page at https://nave.pub/bomba/
#
# The page is one HTML file (inline CSS and JS) copied unchanged from the asada-tech repo, branch
# add-bomba-page, commit 42e70dc, bomba/index.html. It is not edited here: a change is made there and
# copied again, and the hash below moves with it. The root file_server serves it; there is no route for it
# in the Caddyfile.
set -u
cd "$(dirname "$0")/.."
page=bomba/index.html
sum=e057b6ed4ac7ecfb465395f2cdab9b62f210fbe560386abf9ae4f2e4cba88fe5
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }

echo "page: $page"
[ -f "$page" ] || { bad "$page exists"; exit 1; }
if [ "$(sha256sum < "$page" | cut -d' ' -f1)" = "$sum" ]; then ok 'unchanged from the source commit'; else bad 'unchanged from the source commit'; fi
if grep -qF '<h1 data-t="h1">Our water system, and what could be wearing out the pumps</h1>' "$page"; then ok 'heading is the English title'; else bad 'heading is the English title'; fi
if grep -qF 'h1:"Nuestro sistema de agua, y qué puede estar dañando las bombas"' "$page"; then ok 'Spanish heading is in the page'; else bad 'Spanish heading is in the page'; fi
# The only request to another site is the Google Fonts stylesheet.
out=$(grep -oE '(src|href|action)="(https?:)?//[^"]*"|url\((https?:)?//[^)]*\)|@import[^;]*|fetch\(|XMLHttpRequest|sendBeacon|WebSocket' "$page" | grep -vE '^href="https://fonts\.googleapis\.com/css2\?' || true)
if [ -z "$out" ]; then ok 'no outside request but Google Fonts'; else bad "no outside request but Google Fonts (found: $out)"; fi

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
fi

if [ "$fail" = 0 ]; then echo "bomba: ok"; else echo "bomba: FAILED"; exit 1; fi
