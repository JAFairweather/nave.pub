#!/usr/bin/env python3
# strfry write-policy plugin for transport.nave.pub — the NIP-46 transport-only
# relay (nave.pub#130 split). This relay carries NOTHING but kind 24133: no
# fleet allow-list, no gift wraps, no grant plane. It exists so relay.nave.pub
# (which DOES carry the grant plane) can stop being an open write channel and
# an anonymous metadata firehose for signer round-trips.
#
# strfry streams one JSON object per line on stdin for each incoming event and
# expects one decision object per line on stdout:
#   in : {"type":"new","event":{...},"sourceType":...,"sourceInfo":...}
#   out: {"id":"<event id>","action":"accept"|"reject","msg":"..."}
#
# Policy:
#   1. accept kind 24133 from ANYONE — it's how a NIP-46 client with a fresh,
#      unknowable ephemeral key reaches the bunker; the bunker itself is the
#      real authorization boundary, and the payload is end-to-end encrypted
#      (this relay leaks timing and pubkeys, not content — see nave.pub#130).
#   2. rate-limit (1) per author, since there is no allow-list backstopping
#      it here. docs/sovereign-signing.md always specced this as
#      "accept, rate-limited" for the carve-out; the original write-policy.py
#      never implemented the limit because the fleet allow-list was doing the
#      real gating there. This relay has no such backstop, so the limit is
#      load-bearing here, not decorative.
#   3. reject everything else. This relay stores only transport traffic.
#
# Tunables via env (defaults are generous for the fleet's actual NIP-46
# volume — dozens/day per docs/sovereign-signing.md):
#   TRANSPORT_RATE_LIMIT_COUNT     events per author per window (default 120)
#   TRANSPORT_RATE_LIMIT_WINDOW_S  window size in seconds       (default 60)
import json
import os
import sys
import time

TRANSPORT_KIND = 24133
RATE_LIMIT_COUNT = int(os.environ.get("TRANSPORT_RATE_LIMIT_COUNT", "120"))
RATE_LIMIT_WINDOW_S = float(os.environ.get("TRANSPORT_RATE_LIMIT_WINDOW_S", "60"))

# author (lowercased hex) -> list of accept timestamps within the window.
# In-process state — valid because strfry keeps this plugin running as a
# long-lived subprocess and streams one line per event, not one process per
# event (see write-policy.py's identical assumption).
_seen = {}


def rate_limited(pubkey, now):
    times = [t for t in _seen.get(pubkey, ()) if now - t < RATE_LIMIT_WINDOW_S]
    _seen[pubkey] = times
    if len(times) >= RATE_LIMIT_COUNT:
        return True
    times.append(now)
    return False


def decide(ev, now):
    if ev.get("kind") != TRANSPORT_KIND:
        return "reject", "transport relay: only kind 24133 (NIP-46) is accepted here"
    pk = (ev.get("pubkey") or "").lower()
    if rate_limited(pk, now):
        return "reject", f"transport relay: rate limit exceeded ({RATE_LIMIT_COUNT}/{RATE_LIMIT_WINDOW_S:g}s per author)"
    return "accept", ""


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
    action, msg = decide(ev, time.time())
    sys.stdout.write(json.dumps({"id": ev.get("id", ""), "action": action, "msg": msg}) + "\n")
    sys.stdout.flush()
