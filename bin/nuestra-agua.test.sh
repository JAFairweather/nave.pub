#!/usr/bin/env bash
# nuestra-agua.test.sh — the /nuestra-agua page is served exactly as its author wrote it.
#
#   bin/nuestra-agua.test.sh            # the page in this checkout
#   bin/nuestra-agua.test.sh --live     # also the served page at https://nave.pub/nuestra-agua/
#
# The page is one HTML file (inline CSS and JS) copied unchanged from the asada-tech repo, branch
# add-bomba-page, commit 38a6573, nuestra-agua/index.html. It is not edited here: a change is made there
# and copied again, and the hash below moves with it. The root file_server serves it; there is no route
# for it in the Caddyfile. Its visits are logged: bin/pagestats.test.sh checks that.
set -u
cd "$(dirname "$0")/.."
page=nuestra-agua/index.html
sum=a2e3bfd94a446ab633b0423b98dcbf7e7e36f78c0ad10dc98bc7869dd2dc0386
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }

echo "page: $page"
[ -f "$page" ] || { bad "$page exists"; exit 1; }
if [ "$(sha256sum < "$page" | cut -d' ' -f1)" = "$sum" ]; then ok 'unchanged from the source commit'; else bad 'unchanged from the source commit'; fi
# Spanish is the default: the script picks English only for #en. All text is filled in by the script.
if grep -qF '<html lang="es">' "$page" && grep -qF "let L=location.hash==='#en'?'en':'es'" "$page"; then ok 'opens in Spanish unless the address ends in #en'; else bad 'opens in Spanish unless the address ends in #en'; fi
if grep -qF '<title>Nuestra agua de Esterones</title>' "$page" && grep -qF 'es:{h1:"Nuestra agua de Esterones"' "$page" && grep -qF 'en:{h1:"Our Esterones water"' "$page"; then ok 'Spanish title, and Spanish and English headings, are in the page'; else bad 'Spanish title, and Spanish and English headings, are in the page'; fi
# Seven steps in each language, and seven drawings.
n=$(grep -cE '^ \{t:"' "$page"); d=$(grep -cE '^\{svg:l=>' "$page")
if [ "$n" = 14 ] && [ "$d" = 7 ]; then ok 'seven steps in each language, seven drawings'; else bad "seven steps in each language, seven drawings (found $n step texts, $d drawings)"; fi
# The only request to another site is the Google Fonts stylesheet. The listen button uses the phone's own voice.
out=$(grep -oE '(src|href|action)="(https?:)?//[^"]*"|url\((https?:)?//[^)]*\)|@import[^;]*|fetch\(|XMLHttpRequest|sendBeacon|WebSocket|EventSource|import\(' "$page" | grep -vE '^href="https://fonts\.googleapis\.com/css2\?' || true)
if [ -z "$out" ]; then ok 'no outside request but Google Fonts'; else bad "no outside request but Google Fonts (found: $out)"; fi
# Served by the root file_server alone: no route or header names it.
# The visit log's two matcher lines name it (bin/pagestats.test.sh checks those); nothing else may.
if grep -v '^[[:space:]]*#' deploy/caddy/Caddyfile | grep -vE '^[[:space:]]*@(pages|notpages) (not )?path ' | grep -q 'nuestra-agua'; then bad 'no Caddyfile route names /nuestra-agua'; else ok 'no Caddyfile route names /nuestra-agua'; fi

if [ "${1:-}" = --live ]; then
	url=https://nave.pub/nuestra-agua
	echo "live: $url/"
	t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
	code=$(curl -s -m 20 -o "$t/body" -D "$t/head" -w '%{http_code}' "$url/")
	if [ "$code" = 200 ]; then ok '/nuestra-agua/ answers 200'; else bad "/nuestra-agua/ answers 200 (got $code)"; fi
	if grep -qiE '^content-type: *text/html' "$t/head"; then ok 'content-type is text/html'; else bad 'content-type is text/html'; fi
	if cmp -s "$t/body" "$page"; then ok 'served page is byte-identical to this checkout'; else bad 'served page is byte-identical to this checkout'; fi
	redir=$(curl -s -m 20 -o /dev/null -w '%{http_code} %{redirect_url}' "$url")
	case $redir in 30[1278]\ "$url/") ok "/nuestra-agua redirects to the slash form (${redir%% *})" ;; *) bad "/nuestra-agua redirects to the slash form (got $redir)" ;; esac
	code=$(curl -s -m 20 -L -o "$t/followed" -w '%{http_code}' "$url")
	if [ "$code" = 200 ] && cmp -s "$t/followed" "$page"; then ok '/nuestra-agua, followed, is the page (200)'; else bad "/nuestra-agua, followed, is the page (got $code)"; fi
fi

if [ "$fail" = 0 ]; then echo "nuestra-agua: ok"; else echo "nuestra-agua: FAILED"; exit 1; fi
