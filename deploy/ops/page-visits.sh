#!/usr/bin/env bash
# page-visits.sh — who has opened the logged pages on nave.pub, from Caddy's visit log.
#
#   deploy/ops/page-visits.sh                    # on the box, as root: text summary, with addresses
#   deploy/ops/page-visits.sh FILE...            # other log files (plain or .gz)
#   deploy/ops/page-visits.sh --html OUT [FILE...]   # write the /pagestats page: counts only, no addresses
#   OURS="addr addr" deploy/ops/page-visits.sh   # more of our own addresses to leave out
#
# The log is written by the `log` lines in the nave.pub block of deploy/caddy/Caddyfile: one JSON
# line per request to a logged page, kept about 91 days. The pages are listed in PAGES below and in
# the Caddyfile's @pages matcher; bin/pagestats.test.sh checks the two lists agree.
# A "view" is a GET of an HTML page under that address that was served (200) or was already in the
# visitor's cache (304); the redirect to the slash form is not counted twice. Link previews,
# crawlers and scripts (by user agent, curl included) are counted apart from people. Requests from
# private addresses and from the addresses in OURS are our own checks. A shared link's preview is
# fetched by the sender's phone or the chat service, so it is not a reader.
# The text summary prints counts, then one line per visitor address. The --html page has counts and
# times only: no address, user agent or referring page is written to it, because it is public.
set -u
dir=${VISITS_DIR:-/var/lib/docker/volumes/deploy_caddy_data/_data/visits}
html=
if [ "${1:-}" = --html ]; then html=${2:?--html needs an output file}; shift 2; fi
if [ $# -gt 0 ]; then files=("$@"); else files=("$dir"/*.log*); fi
[ -e "${files[0]}" ] || files=()
[ ${#files[@]} -gt 0 ] || [ -n "$html" ] || { echo "no visit log yet at $dir (it starts at the first request to a logged page)"; exit 0; }
OURS="${OURS:-}" HTML_OUT="$html" exec python3 - ${files[@]+"${files[@]}"} <<'PY'
import sys, os, json, gzip, re, ipaddress, datetime, collections, html
# The logged pages: address prefix, name on the stats page, short name for its table.
# Keep in step with @pages in the Caddyfile.
PAGES = [('/bomba/', 'Bomba: the water system and the pumps', 'Bomba'),
         ('/sistema/', 'Sistema: water pressure by house', 'Sistema'),
         ('/asada/esterones/', 'ASADA Esterones mockup', 'Mockup'),
         ('/nuestra-agua/', 'Nuestra agua: how the water gets to the house', 'Agua')]
# Link previews and crawlers name themselves; an in-app browser (Facebook, Instagram, X) is a person.
BOT = re.compile(r'bot|crawl|spider|preview|facebookexternalhit|^whatsapp/|curl|wget|python|go-http|okhttp|java/|'
                 r'headless|scan|monitor|feed|fetch|axios|node-|libwww|visit-log-check|^$', re.I)
ours = set(os.environ.get('OURS', '').split())
out = os.environ.get('HTML_OUT', '')
rows, bad = [], 0
for f in sys.argv[1:]:
    try:
        with (gzip.open(f, 'rt', encoding='utf-8', errors='replace') if f.endswith('.gz') else open(f, encoding='utf-8', errors='replace')) as h:
            for line in h:
                try:
                    j = json.loads(line); r = j['request']
                    rows.append((float(j['ts']), r.get('client_ip') or r.get('remote_ip') or '?', r.get('method', ''),
                                 r.get('uri', ''), int(j.get('status', 0)), str(j.get('ua', '')), str(j.get('referer', ''))))
                except Exception:
                    bad += 1
    except (OSError, EOFError):
        bad += 1      # a file rolled away or half-written while we read: skip it
rows = list(dict.fromkeys(rows))   # a rolled file read both plain and compressed, mid-roll, counts once
def kind(ip, ua):
    try:
        a = ipaddress.ip_address(ip)
        if a.is_private or a.is_loopback or a.is_link_local: return 'ours'
    except ValueError:
        pass
    if ip in ours or 'visit-log-check' in ua: return 'ours'      # bin/pagestats.test.sh --live sends that name
    return 'robot' if BOT.search(ua) else 'person'
def page_of(uri):
    p = uri.split('?')[0]
    for base, _, _ in PAGES:
        if p.startswith(base) and (p.endswith('/') or p.endswith('.html')): return base
    return None
UTC = datetime.timezone.utc
def when(ts): return datetime.datetime.fromtimestamp(ts, UTC).strftime('%Y-%m-%d %H:%MZ')
# x: (ts, ip, method, uri, status, ua, referer, page, kind)
views = [x + (page_of(x[3]), kind(x[1], x[5])) for x in rows if x[2] == 'GET' and x[4] in (200, 304) and page_of(x[3])]

if not out:
    def day(ts): return datetime.datetime.fromtimestamp(ts, UTC).strftime('%Y-%m-%d')
    print(f'requests logged: {len(rows)}   page views: {len(views)}' + (f'   unreadable lines or files: {bad}' if bad else ''))
    if rows: print(f'log covers: {when(min(x[0] for x in rows))} to {when(max(x[0] for x in rows))}')
    for base, name, _ in PAGES:
        pv = [x for x in views if x[7] == base]
        print(f'\n{base}  ({name})')
        by = collections.defaultdict(list)
        for x in pv: by[(x[8], x[1])].append(x)
        for k, label in (('person', 'people (browsers)'), ('robot', 'link previews, crawlers and scripts'), ('ours', 'our own checks')):
            ips = {ip for (kk, ip) in by if kk == k}
            print(f'  {label}: {sum(len(by[(k, ip)]) for ip in ips)} views from {len(ips)} addresses')
        days = collections.Counter(day(x[0]) for x in pv if x[8] == 'person')
        for d in sorted(days): print(f'    {d}: {days[d]} views by people, {len({x[1] for x in pv if day(x[0]) == d and x[8] == "person"})} addresses')
        for k in ('person', 'robot'):
            for (kk, ip), v in sorted(by.items(), key=lambda e: -max(x[0] for x in e[1])):
                if kk != k: continue
                ref = next((x[6] for x in v if x[6]), '')
                print(f'  {k:6} {ip:39} views {len(v):3}  first {when(min(x[0] for x in v))}  last {when(max(x[0] for x in v))}  {v[-1][5][:70]}' + (f'  from {ref[:60]}' if ref else ''))
    sys.exit(0)

# --html: the public page. Days are Costa Rica days (UTC-6, no summer time): the pages are about Esterones.
CR = datetime.timezone(datetime.timedelta(hours=-6))
now = datetime.datetime.now(UTC)
env_now = os.environ.get('PAGESTATS_NOW')          # tests fix the clock
if env_now: now = datetime.datetime.fromtimestamp(float(env_now), UTC)
today = now.astimezone(CR).date()
def crday(ts): return datetime.datetime.fromtimestamp(ts, CR).date()
def iso(ts): return datetime.datetime.fromtimestamp(ts, UTC).strftime('%Y-%m-%dT%H:%M:%SZ')
def crtext(ts): return datetime.datetime.fromtimestamp(ts, CR).strftime('%-d %b %Y, %H:%M') + ' Costa Rica time'
def tm(ts): return f'<time datetime="{iso(ts)}">{html.escape(crtext(ts))}</time>'
e = html.escape
ndays = 14
dlist = [today - datetime.timedelta(days=i) for i in range(ndays)]
cards, cols = [], []
for base, name, _ in PAGES:
    pv = [x for x in views if x[7] == base]
    ppl = [x for x in pv if x[8] == 'person']
    rob = [x for x in pv if x[8] == 'robot']
    d7 = today - datetime.timedelta(days=6)
    n_today = sum(1 for x in ppl if crday(x[0]) == today)
    n_7 = sum(1 for x in ppl if crday(x[0]) >= d7)
    last = max((x[0] for x in ppl), default=None)
    perday = collections.Counter(crday(x[0]) for x in ppl)
    cols.append(perday)
    cards.append(f'''<section class="card">
 <h2><a href="{e(base)}">nave.pub{e(base)}</a></h2>
 <p class="name">{e(name)}</p>
 <p class="big"><b>{len(ppl)}</b> <span>{'view' if len(ppl) == 1 else 'views'} by people so far</span></p>
 <dl>
  <div><dt>Today</dt><dd>{n_today}</dd></div>
  <div><dt>Last 7 days</dt><dd>{n_7}</dd></div>
  <div><dt>Visitors</dt><dd>{len({x[1] for x in ppl})}</dd></div>
  <div><dt>Previews and robots</dt><dd>{len(rob)}</dd></div>
 </dl>
 <p class="last">Last visit by a person: {tm(last) if last else 'none yet'}</p>
</section>''')
head = ''.join(f'<th>{e(short)}</th>' for _, _, short in PAGES)
body = ''.join(f'<tr><td>{d.strftime("%-d %b")}</td>' + ''.join(f'<td class="{"z" if not c[d] else ""}">{c[d]}</td>' for c in cols) + '</tr>' for d in dlist)
first = min((x[0] for x in rows), default=None)
doc = f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Page visits</title>
<style>
:root{{color-scheme:light;--bg:#f4f6fa;--card:#ffffff;--ink:#141a23;--mut:#5a6475;--line:#d8deea;--acc:#1240e0}}
@media (prefers-color-scheme:dark){{:root{{color-scheme:dark;--bg:#0d1118;--card:#161c26;--ink:#e8ecf3;--mut:#9aa5b8;--line:#283142;--acc:#7ea2ff}}}}
*{{box-sizing:border-box;min-width:0}}
body{{margin:0;background:var(--bg);color:var(--ink);font:16px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}}
main{{max-width:44rem;margin:0 auto;padding:1.25rem max(16px,env(safe-area-inset-right,0px)) 2.5rem max(16px,env(safe-area-inset-left,0px));display:flex;flex-direction:column;gap:1rem}}
h1{{font-size:1.6rem;line-height:1.2;margin:0}}
.sub,.name,.last,.note{{color:var(--mut);margin:0;font-size:.92rem}}
.card{{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:1rem;display:flex;flex-direction:column;gap:.5rem}}
h2{{font-size:1.05rem;margin:0;overflow-wrap:anywhere}}
a{{color:var(--acc)}}
.big{{margin:0}}.big b{{font-size:2.2rem;line-height:1.1;font-variant-numeric:tabular-nums}}.big span{{color:var(--mut)}}
dl{{display:grid;grid-template-columns:repeat(auto-fit,minmax(7.5rem,1fr));gap:.5rem;margin:0}}
dl div{{border-top:1px solid var(--line);padding-top:.4rem}}
dt{{color:var(--mut);font-size:.82rem}}dd{{margin:0;font-size:1.2rem;font-weight:600;font-variant-numeric:tabular-nums}}
.scroll{{overflow-x:auto}}
table{{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums;font-size:.94rem}}
th,td{{padding:.4rem .35rem;border-bottom:1px solid var(--line);text-align:right;white-space:nowrap}}
th:first-child,td:first-child{{text-align:left}}
th{{font-size:.85rem;color:var(--mut);font-weight:600}}
td.z{{color:var(--mut)}}
</style>
</head>
<body>
<main>
 <h1>Page visits</h1>
 <p class="sub">Updated {tm(now.timestamp())}. Refreshed every 5 minutes. Counting since {tm(first) if first else 'the first visit'}.</p>
 {''.join(cards)}
 <section class="card">
  <h2>Views by people, last {ndays} days</h2>
  <div class="scroll"><table><tr><th>Day</th>{head}</tr>{body}</table></div>
  <p class="note">Days are Costa Rica days.</p>
 </section>
 <p class="note">A view is one opening of the page in a browser. Visitors is the number of different internet addresses, so one phone on Wi-Fi and on mobile data counts twice. Link previews (WhatsApp and the like), search crawlers and scripts are counted apart as previews and robots. Your own visits count as people. Visits older than about 91 days drop off. This page shows counts only: no address is shown here.</p>
</main>
<script>
for (const t of document.querySelectorAll('time')) {{ const d = new Date(t.dateTime); if (!isNaN(d)) t.textContent = d.toLocaleString([], {{ dateStyle: 'medium', timeStyle: 'short' }}); }}
</script>
</body>
</html>
'''
import tempfile
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(out)), prefix='.index.', suffix='.tmp')   # own name: two runs at once cannot share it
with os.fdopen(fd, 'w', encoding='utf-8') as h: h.write(doc)
os.chmod(tmp, 0o644)
os.replace(tmp, out)
PY
