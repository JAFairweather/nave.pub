#!/usr/bin/env bash
# sistema.test.sh — the /sistema page is served exactly as its author wrote it.
#
#   bin/sistema.test.sh            # the page in this checkout
#   bin/sistema.test.sh --live     # also the served page at https://nave.pub/sistema/
#
# The page is one HTML file (inline CSS and JS) copied unchanged from the asada-tech repo, branch
# add-bomba-page, commit 91596a8, sistema/index.html. It is not edited here: a change is made there and
# copied again, and the hash below moves with it. The root file_server serves it; there is no route for it
# in the Caddyfile, and it is not in the /bomba visit log.
set -u
cd "$(dirname "$0")/.."
page=sistema/index.html
sum=13e4879d1c1a74b6d79c78fd6213f8105bbd3d4c2cdf0f02320613237fe2286c
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }

echo "page: $page"
[ -f "$page" ] || { bad "$page exists"; exit 1; }
if [ "$(sha256sum < "$page" | cut -d' ' -f1)" = "$sum" ]; then ok 'unchanged from the source commit'; else bad 'unchanged from the source commit'; fi
# Spanish is the default: the script picks English only for #en. All text is filled in by the script.
if grep -qF '<html lang="es">' "$page" && grep -qF "let L=location.hash==='#en'?'en':'es'" "$page"; then ok 'opens in Spanish unless the address ends in #en'; else bad 'opens in Spanish unless the address ends in #en'; fi
if grep -qF 'es:{h1:"Por qué la presión del agua cambia de una casa a otra"' "$page" && grep -qF 'en:{h1:"Why water pressure is different from house to house"' "$page"; then ok 'Spanish and English headings are in the page'; else bad 'Spanish and English headings are in the page'; fi
# The page says its houses and numbers are examples, in both languages.
if grep -qF 'Las casas A a G son ejemplos, no casas reales.' "$page" && grep -qF 'Houses A to G are examples, not real houses.' "$page"; then ok 'says the houses and numbers are examples'; else bad 'says the houses and numbers are examples'; fi
# The only request to another site is the Google Fonts stylesheet.
out=$(grep -oE '(src|href|action)="(https?:)?//[^"]*"|url\((https?:)?//[^)]*\)|@import[^;]*|fetch\(|XMLHttpRequest|sendBeacon|WebSocket' "$page" | grep -vE '^href="https://fonts\.googleapis\.com/css2\?' || true)
if [ -z "$out" ]; then ok 'no outside request but Google Fonts'; else bad "no outside request but Google Fonts (found: $out)"; fi
# Served by the root file_server alone: no route, header or log names it.
if grep -v '^[[:space:]]*#' deploy/caddy/Caddyfile | grep -q 'sistema'; then bad 'no Caddyfile line names /sistema'; else ok 'no Caddyfile line names /sistema'; fi

if [ "${1:-}" = --live ]; then
	url=https://nave.pub/sistema
	echo "live: $url/"
	t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
	code=$(curl -s -m 20 -o "$t/body" -D "$t/head" -w '%{http_code}' "$url/")
	if [ "$code" = 200 ]; then ok '/sistema/ answers 200'; else bad "/sistema/ answers 200 (got $code)"; fi
	if grep -qiE '^content-type: *text/html' "$t/head"; then ok 'content-type is text/html'; else bad 'content-type is text/html'; fi
	if cmp -s "$t/body" "$page"; then ok 'served page is byte-identical to this checkout'; else bad 'served page is byte-identical to this checkout'; fi
	redir=$(curl -s -m 20 -o /dev/null -w '%{http_code} %{redirect_url}' "$url")
	case $redir in 30[1278]\ "$url/") ok "/sistema redirects to the slash form (${redir%% *})" ;; *) bad "/sistema redirects to the slash form (got $redir)" ;; esac
	code=$(curl -s -m 20 -L -o "$t/followed" -w '%{http_code}' "$url")
	if [ "$code" = 200 ] && cmp -s "$t/followed" "$page"; then ok '/sistema, followed, is the page (200)'; else bad "/sistema, followed, is the page (got $code)"; fi
fi

if [ "$fail" = 0 ]; then echo "sistema: ok"; else echo "sistema: FAILED"; exit 1; fi
