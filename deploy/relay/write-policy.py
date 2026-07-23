#!/usr/bin/env python3
# strfry write-policy plugin — restrict this relay to the Nave fleet.
#
# strfry streams one JSON object per line on stdin for each incoming event and
# expects one decision object per line on stdout:
#   in : {"type":"new","event":{...},"sourceType":...,"sourceInfo":...}
#   out: {"id":"<event id>","action":"accept"|"reject","msg":"..."}
#
# Policy, in order:
#   1. accept events AUTHORED by a fleet pubkey (allowlist.json `allow`);
#   2. accept `allowKinds` from anyone (NIP-46 transport 24133 — end-to-end
#      encrypted, leaks nothing but timing; lets the bunker's ephemeral client
#      keys through);
#   3. accept `recipientKinds` (NIP-59 gift wraps, 1059) when ADDRESSED to a
#      fleet pubkey — any `p` tag naming an allowlisted key. Wraps are authored
#      by single-use ephemeral keys BY DESIGN, so author-based admission can
#      never pass them; recipient-based admission is what matches the
#      protocol's semantics. This is what lets the grant plane — draft grants,
#      steering grants, credential grants — ride the fleet's own relay
#      (nave.pub#37). Spam control is preserved: a wrap to a stranger is still
#      rejected, and rate/size limits stay strfry's job (strfry.conf).
#
# Everything else is rejected. Read-only to the allowlist file; reload is a
# plugin restart (strfry respawns it).
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
    rkinds = set(c.get("recipientKinds") or [])
    return allow, kinds, rkinds


ALLOW, ALLOW_KINDS, RECIPIENT_KINDS = load()


def addressed_to_fleet(ev):
    for tag in ev.get("tags") or []:
        if isinstance(tag, list) and len(tag) >= 2 and tag[0] == "p" \
                and isinstance(tag[1], str) and tag[1].lower() in ALLOW:
            return True
    return False


def decide(ev):
    pk = (ev.get("pubkey") or "").lower()
    if pk in ALLOW:
        return "accept", ""
    if ev.get("kind") in ALLOW_KINDS:
        return "accept", ""
    if ev.get("kind") in RECIPIENT_KINDS and addressed_to_fleet(ev):
        return "accept", ""
    return "reject", "restricted relay: author not in the Nave fleet allow-list (and not a wrap addressed to it)"


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
