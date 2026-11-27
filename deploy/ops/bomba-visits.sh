#!/usr/bin/env bash
# bomba-visits.sh — who has opened https://nave.pub/bomba, from Caddy's visit log.
#
#   deploy/ops/bomba-visits.sh                 # on the box, as root
#   deploy/ops/bomba-visits.sh FILE...         # other log files (plain or .gz)
#   OURS="addr addr" deploy/ops/bomba-visits.sh   # more of our own addresses to leave out
#
# The log is written by the `log` lines in the nave.pub block of deploy/caddy/Caddyfile: one JSON
# line per request to /bomba, kept about 90 days. A "view" is a GET of the page itself that was
# served (200) or was already in the visitor's cache (304); the redirect from /bomba to /bomba/ is
# not counted twice. Link previews, crawlers and scripts (by user agent, curl included) are listed
# apart from people. Requests from private addresses and from the addresses in OURS (give the box's
# and our other servers' public addresses) are our own checks. A shared link's preview is fetched
# by the sender's phone or the chat service, so it is not a reader.
# Prints counts first, then one line per visitor address. Read-only.
set -u
dir=/var/lib/docker/volumes/deploy_caddy_data/_data/visits
if [ $# -gt 0 ]; then files=("$@"); else files=("$dir"/bomba*.log*); fi
[ -e "${files[0]}" ] || { echo "no visit log yet at $dir (it starts at the first request to /bomba)"; exit 0; }
OURS="${OURS:-}" exec python3 - "${files[@]}" <<'PY'
import sys, os, json, gzip, re, ipaddress, datetime, collections
# Link previews and crawlers name themselves; an in-app browser (Facebook, Instagram, X) is a person.
BOT = re.compile(r'bot|crawl|spider|preview|facebookexternalhit|^whatsapp/|curl|wget|python|go-http|okhttp|java/|'
                 r'headless|scan|monitor|feed|fetch|axios|node-|libwww|visit-log-check|^$', re.I)
ours = set(os.environ.get('OURS', '').split())
rows, bad = [], 0
for f in sys.argv[1:]:
    with (gzip.open(f, 'rt', encoding='utf-8', errors='replace') if f.endswith('.gz') else open(f, encoding='utf-8', errors='replace')) as h:
        for line in h:
            try:
                j = json.loads(line); r = j['request']
                rows.append((float(j['ts']), r.get('client_ip') or r.get('remote_ip') or '?', r.get('method', ''),
                             r.get('uri', ''), int(j.get('status', 0)), str(j.get('ua', '')), str(j.get('referer', ''))))
            except Exception:
                bad += 1
def kind(ip, ua):
    try:
        a = ipaddress.ip_address(ip)
        if a.is_private or a.is_loopback or a.is_link_local: return 'ours'
    except ValueError:
        pass
    if ip in ours: return 'ours'
    return 'robot' if BOT.search(ua) else 'person'
def day(ts): return datetime.datetime.fromtimestamp(ts, datetime.timezone.utc).strftime('%Y-%m-%d')
def when(ts): return datetime.datetime.fromtimestamp(ts, datetime.timezone.utc).strftime('%Y-%m-%d %H:%MZ')
views = [x for x in rows if x[2] == 'GET' and x[3].split('?')[0] in ('/bomba/', '/bomba/index.html') and x[4] in (200, 304)]
by = collections.defaultdict(list)
for x in views: by[(kind(x[1], x[5]), x[1])].append(x)
print(f'requests logged: {len(rows)}   page views: {len(views)}' + (f'   unreadable lines: {bad}' if bad else ''))
if rows: print(f'log covers: {when(min(x[0] for x in rows))} to {when(max(x[0] for x in rows))}')
for k, label in (('person', 'people (browsers)'), ('robot', 'link previews, crawlers and scripts'), ('ours', 'our own checks')):
    ips = {ip for (kk, ip) in by if kk == k}
    print(f'{label}: {sum(len(by[(k, ip)]) for ip in ips)} views from {len(ips)} addresses')
days = collections.Counter(day(x[0]) for x in views if kind(x[1], x[5]) == 'person')
for d in sorted(days): print(f'  {d}: {days[d]} views by people, {len({x[1] for x in views if day(x[0]) == d and kind(x[1], x[5]) == "person"})} addresses')
for k in ('person', 'robot'):
    for (kk, ip), v in sorted(by.items(), key=lambda e: -max(x[0] for x in e[1])):
        if kk != k: continue
        ref = next((x[6] for x in v if x[6]), '')
        print(f'{k:6} {ip:39} views {len(v):3}  first {when(min(x[0] for x in v))}  last {when(max(x[0] for x in v))}  {v[-1][5][:70]}' + (f'  from {ref[:60]}' if ref else ''))
PY
