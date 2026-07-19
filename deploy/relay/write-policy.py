#!/usr/bin/env python3
# strfry write-policy plugin — restrict this relay to the Nave fleet.
#
# strfry streams one JSON object per line on stdin for each incoming event and
# expects one decision object per line on stdout:
#   in : {"type":"new","event":{...},"sourceType":...,"sourceInfo":...}
#   out: {"id":"<event id>","action":"accept"|"reject","msg":"..."}
#
# Policy: accept events authored by a fleet pubkey (allowlist.json), plus the
# NIP-46 transport kind (24133) from anyone — those are end-to-end encrypted, so
# an open transport kind leaks nothing but timing and lets the bunker's ephemeral
# client keys through. Everything else is rejected. Read-only to the allowlist
# file; reload is a plugin restart (strfry respawns it).
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CONF = os.environ.get("ALLOWLIST_PATH", os.path.join(HERE, "allowlist.json"))


def load():
    with open(CONF) as f:
        c = json.load(f)
    allow = {v.lower() for k, v in (c.get("allow") or {}).items()
             if isinstance(v, str) and not v.startswith("REPLACE_")}
    kinds = set(c.get("allowKinds") or [])
    return allow, kinds


ALLOW, ALLOW_KINDS = load()


def decide(ev):
    pk = (ev.get("pubkey") or "").lower()
    if pk in ALLOW:
        return "accept", ""
    if ev.get("kind") in ALLOW_KINDS:
        return "accept", ""
    return "reject", "restricted relay: author not in the Nave fleet allow-list"


for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        req = json.loads(line)
    except Exception:
        continue
    if req.get("type") != "new":
        # non-event messages (e.g. lookback) — accept to be safe; only "new" gates writes
        continue
    ev = req.get("event", {})
    action, msg = decide(ev)
    sys.stdout.write(json.dumps({"id": ev.get("id", ""), "action": action, "msg": msg}) + "\n")
    sys.stdout.flush()
