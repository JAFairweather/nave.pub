#!/usr/bin/env bash
# esterones.test.sh — the ASADA Esterones mockup must stay unmistakably SAMPLE DATA and out of search.
#
#   bin/esterones.test.sh            # the page and the Caddyfile in this checkout
#   bin/esterones.test.sh --live     # also the served page at https://nave.pub/asada/esterones/
#
# The page is a design mockup with invented readings for a real community water board. If a label is
# lost (an edit, a minifier, a template), someone could read invented alerts as real ones. So every
# label the brief names is checked here, with the robots rules and the "no outside requests" promise.
set -u
cd "$(dirname "$0")/.."
page=asada/esterones/index.html
caddy=deploy/caddy/Caddyfile
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }
has() { if grep -qF -- "$2" "$1"; then ok "$3"; else bad "$3"; fi; }
hasnt() { if grep -qiE -- "$2" "$1"; then bad "$3"; else ok "$3"; fi; }

check_page() {   # check_page FILE
	has "$1" 'DATOS DE EJEMPLO - NO SON LECTURAS REALES' 'banner says the data is not real'
	has "$1" 'Sample data only' 'banner says so in English'
	if grep -qE '<title>[^<]*\(DATOS DE EJEMPLO\)[^<]*</title>' "$1"; then ok 'title carries (DATOS DE EJEMPLO)'; else bad 'title carries (DATOS DE EJEMPLO)'; fi
	has "$1" 'valores de ejemplo' 'heading line says valores de ejemplo'
	if grep -qiE '<footer' "$1" && sed -n '/<footer/,$p' "$1" | grep -qiE 'ejemplo|sample'; then ok 'footer says the values are sample data'; else bad 'footer says the values are sample data'; fi
	has "$1" '<meta name="robots" content="noindex, nofollow">' 'robots meta is noindex, nofollow'
	hasnt "$1" '<script|<form|<iframe|<link[^>]+href=|(src|href|action)="(https?:)?//|url\((https?:)?//|@import' 'no script, form, frame or outside request'
}

echo "page: $page"
[ -f "$page" ] || { bad "$page exists"; exit 1; }
check_page "$page"

echo "server: $caddy"
has "$caddy" '@esterones path /asada/esterones /asada/esterones/*' 'matcher covers /asada/esterones and below'
has "$caddy" 'header @esterones X-Robots-Tag "noindex, nofollow"' 'X-Robots-Tag header is set'

echo "hub: nothing links to the mockup"
if grep -rIl --exclude-dir=.git --exclude-dir=asada --exclude=esterones.test.sh --exclude=Caddyfile -e 'asada/esterones' . | grep -q .; then
	bad 'no other file in the hub names asada/esterones'
else
	ok 'no other file in the hub names asada/esterones'
fi

if [ "${1:-}" = --live ]; then
	url=https://nave.pub/asada/esterones
	echo "live: $url/"
	t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
	code=$(curl -s -m 20 -o "$t/body" -D "$t/head" -w '%{http_code}' "$url/")
	if [ "$code" = 200 ]; then ok '/asada/esterones/ answers 200'; else bad "/asada/esterones/ answers 200 (got $code)"; fi
	if grep -qiE '^content-type: *text/html' "$t/head"; then ok 'content-type is text/html'; else bad 'content-type is text/html'; fi
	if grep -qiE '^x-robots-tag: *noindex' "$t/head"; then ok 'X-Robots-Tag: noindex is sent'; else bad 'X-Robots-Tag: noindex is sent'; fi
	if cmp -s "$t/body" "$page"; then ok 'served page is byte-identical to this checkout'; else bad 'served page is byte-identical to this checkout'; fi
	check_page "$t/body"
	redir=$(curl -s -m 20 -o /dev/null -w '%{http_code} %{redirect_url}' "$url")
	case $redir in 30[1278]\ "$url/") ok "/asada/esterones redirects to the slash form (${redir%% *})" ;; *) bad "/asada/esterones redirects to the slash form (got $redir)" ;; esac
fi

if [ "$fail" = 0 ]; then echo "esterones: ok"; else echo "esterones: FAILED"; exit 1; fi
