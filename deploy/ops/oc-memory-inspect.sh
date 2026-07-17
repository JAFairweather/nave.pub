#!/usr/bin/env bash
# Step 1 of the canonical-wins memory repair: inspect Luke's Memory Core storage
# to design the reconciliation precisely. Prints SQLite file list, table names,
# ROW COUNTS, and table SCHEMA (CREATE statements) — never any row contents, so
# no personal memory is exposed. Fresh throwaway copy from live; nothing live or
# staged is touched, and the copy is removed at the end.
set -u
SRC=/docker/openclaw-kajk/data/.openclaw
TESTROOT=/root/nave.pub/deploy/openclaw-memtest
TEST="$TESTROOT/.openclaw"
[ -d "$SRC" ] || { echo "no live state at $SRC"; exit 1; }

echo "== fresh throwaway copy from live =="
rm -rf "$TESTROOT"; mkdir -p "$TEST"
rsync -a --exclude 'npm/' --exclude 'browser/' --exclude 'browsers/' --exclude 'logs/' --exclude '*.log' "$SRC/" "$TEST/"

echo
echo "== SQLite files under the state =="
find "$TEST" \( -name '*.sqlite' -o -name '*.db' -o -name '*.sqlite3' \) 2>/dev/null | sed "s#$TEST/##"

echo
echo "== schema + row counts (SCHEMA ONLY — no row contents) =="
docker run --rm -i -v "$TEST:/s:ro" python:3-alpine python3 - <<'PY'
import sqlite3, glob
dbs = sorted(set(glob.glob('/s/**/*.sqlite', recursive=True)
                 + glob.glob('/s/**/*.db', recursive=True)
                 + glob.glob('/s/**/*.sqlite3', recursive=True)))
KEYS = ('memory','meta','index','embed','cache','legacy','sidecar')
for db in dbs:
    rel = db.replace('/s/','')
    try:
        c = sqlite3.connect(f'file:{db}?mode=ro', uri=True)
        tabs = [r[0] for r in c.execute(
            "select name from sqlite_master where type='table' order by name")]
    except Exception as e:
        print(f"\n## {rel}: open/read error: {e}"); continue
    print(f"\n## {rel}  ({len(tabs)} tables)")
    for t in tabs:
        try: n = c.execute(f'select count(*) from "{t}"').fetchone()[0]
        except Exception as e: n = f'?({e})'
        flag = '   <<< memory-related' if any(k in t.lower() for k in KEYS) else ''
        print(f"   {t}: {n} rows{flag}")
    for t in tabs:
        if any(k in t.lower() for k in KEYS):
            row = c.execute("select sql from sqlite_master where name=?", (t,)).fetchone()
            ddl = (row[0] if row and row[0] else '').replace('\n',' ')
            print(f"   -- schema[{t}]: {ddl}")
    c.close()
PY
rm -rf "$TESTROOT"
echo
echo "== done (throwaway copy removed) =="
