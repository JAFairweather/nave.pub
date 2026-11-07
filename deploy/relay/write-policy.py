#!/usr/bin/env python3
# strfry write-policy plugin — restrict this relay to the Nave fleet.
#
# strfry streams one JSON object per line on stdin for each incoming event and
# expects one decision object per line on stdout:
#   in : {"type":"new","event":{...},"sourceType":...,"sourceInfo":...}
#   out: {"id":"<event id>","action":"accept"|"reject","msg":"..."}
#
# Policy, in order:
#   0. an owner's writer list (allowlist.json `owners`; kind 30000, d =
#      nave-relay-writers) is checked at the door — id, BIP-340 signature, p
#      tags, size, date — and rejected whole if any fails (nave.pub#157).
#      Passing the door changes nobody's admission: strfry may still refuse the
#      event after this plugin accepts it (an expiry, a deletion, a newer stored
#      list). The extra writers are read back from what the relay has STORED
#      (`strfry scan`, at most every WRITERS_SCAN_TTL seconds): the newest
#      unexpired owner list held by the relay. So a list the relay refused,
#      deleted or expired admits nobody, and a restart needs no state of its
#      own. A failed read admits no extra writers until a read succeeds. A kind
#      30000 from anyone else is judged by the rules below;
#   1. accept events AUTHORED by a fleet pubkey: allowlist.json `allow`, which
#      always stays, plus the extra writers in the relay's stored owner list;
#   2. accept `allowKinds` from anyone (NIP-46 transport 24133 — end-to-end
#      encrypted, leaks nothing but timing; lets the bunker's ephemeral client
#      keys through);
#   3. accept `recipientKinds` (NIP-59 gift wraps, 1059) when ADDRESSED to a
#      fleet pubkey — any `p` tag naming one. Wraps are authored by single-use
#      ephemeral keys BY DESIGN, so author-based admission can never pass them;
#      recipient-based admission is what matches the protocol's semantics. This
#      is what lets the grant plane — draft grants, steering grants, credential
#      grants — ride the fleet's own relay (nave.pub#37). Spam control is
#      preserved: a wrap to a stranger is still rejected, and rate/size limits
#      stay strfry's job (strfry.conf).
#
# Everything else is rejected. allowlist.json is read once; a change to it is a
# plugin restart (strfry respawns it). The owner's list needs no restart.
import hashlib
import json
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
CONF = os.environ.get("ALLOWLIST_PATH", os.path.join(HERE, "allowlist.json"))
# How to read the relay's own store; tests point this at a fake. The filter JSON is appended.
SCAN_CMD = json.loads(os.environ.get("WRITERS_SCAN_CMD") or
                      '["/app/strfry", "--config=/etc/strfry.conf", "scan"]')
SCAN_TTL = float(os.environ.get("WRITERS_SCAN_TTL", "2"))
SCAN_TIMEOUT = 10

WRITERS_KIND = 30000
WRITERS_D = "nave-relay-writers"
MAX_WRITERS = 1000
MAX_FUTURE_SEC = 600  # a list dated further ahead would freeze every later one
HEX64 = re.compile(r"^[0-9a-f]{64}$")


def keys(section):
    # `allow` and `owners` are {label: hex}; a REPLACE_ placeholder is skipped.
    return {v.lower() for v in (section or {}).values()
            if isinstance(v, str) and not v.startswith("REPLACE_")}


def load():
    with open(CONF) as f:
        c = json.load(f)
    owners = {k for k in keys(c.get("owners")) if HEX64.match(k)}
    return keys(c.get("allow")), set(c.get("allowKinds") or []), set(c.get("recipientKinds") or []), owners


ALLOW, ALLOW_KINDS, RECIPIENT_KINDS, OWNERS = load()


# --- BIP-340 verification, pure Python (the image has no secp256k1 module). ---
_P = 2**256 - 2**32 - 977
_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
_G = (0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
      0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8)


def _add(a, b):
    if a is None:
        return b
    if b is None:
        return a
    if a[0] == b[0] and a[1] != b[1]:
        return None
    if a == b:
        lam = 3 * a[0] * a[0] * pow(2 * a[1], -1, _P) % _P
    else:
        lam = (b[1] - a[1]) * pow(b[0] - a[0], -1, _P) % _P
    x = (lam * lam - a[0] - b[0]) % _P
    return x, (lam * (a[0] - x) - a[1]) % _P


def _mul(pt, n):
    r = None
    while n:
        if n & 1:
            r = _add(r, pt)
        pt = _add(pt, pt)
        n >>= 1
    return r


def _lift_x(x):
    if x >= _P:
        return None
    y_sq = (pow(x, 3, _P) + 7) % _P
    y = pow(y_sq, (_P + 1) // 4, _P)
    if pow(y, 2, _P) != y_sq:
        return None
    return x, y if y % 2 == 0 else _P - y


def _tagged(tag, msg):
    t = hashlib.sha256(tag.encode()).digest()
    return hashlib.sha256(t + t + msg).digest()


def schnorr_verify(msg, pubkey, sig):
    if len(msg) != 32 or len(pubkey) != 32 or len(sig) != 64:
        return False
    pt = _lift_x(int.from_bytes(pubkey, "big"))
    r, s = int.from_bytes(sig[:32], "big"), int.from_bytes(sig[32:], "big")
    if pt is None or r >= _P or s >= _N:
        return False
    e = int.from_bytes(_tagged("BIP0340/challenge", sig[:32] + pubkey + msg), "big") % _N
    R = _add(_mul(_G, s), _mul(pt, _N - e))
    return R is not None and R[1] % 2 == 0 and R[0] == r


def event_ok(ev):
    # NIP-01: the id is sha256 of the serialised event, and sig signs the id.
    try:
        ser = json.dumps([0, ev["pubkey"], ev["created_at"], ev["kind"], ev["tags"], ev["content"]],
                         separators=(",", ":"), ensure_ascii=False)
        eid = hashlib.sha256(ser.encode()).hexdigest()
        return eid == ev["id"] and schnorr_verify(bytes.fromhex(eid), bytes.fromhex(ev["pubkey"]), bytes.fromhex(ev["sig"]))
    except Exception:
        return False


# --- The owner's writer list: checked at the door, admitted from the store. ---
def is_writer_list(ev):
    return ev.get("kind") == WRITERS_KIND and \
        [t[1] for t in ev.get("tags") or [] if isinstance(t, list) and len(t) >= 2 and t[0] == "d"] == [WRITERS_D]


def list_fault(ev):
    # Why an owner's writer list is unacceptable, or "" when it is sound.
    if not event_ok(ev):
        return "invalid: writer list id or signature does not verify"
    ps = [t[1] for t in ev.get("tags") or [] if isinstance(t, list) and len(t) >= 2 and t[0] == "p"]
    if any(not isinstance(p, str) or not HEX64.match(p) for p in ps):
        return "invalid: every p tag in a writer list must be a lowercase 64-hex key"
    if len(set(ps)) > MAX_WRITERS:
        return f"invalid: a writer list holds at most {MAX_WRITERS} keys"
    if ev["created_at"] > time.time() + MAX_FUTURE_SEC:
        return "invalid: writer list is dated in the future"
    return ""


def expired(ev, now):
    # NIP-40: the relay stops serving an event once its expiration has passed.
    for t in ev.get("tags") or []:
        if isinstance(t, list) and len(t) >= 2 and t[0] == "expiration":
            try:
                if int(t[1]) <= now:
                    return True
            except (TypeError, ValueError):
                return True
    return False


def stored_writers():
    # The newest sound, unexpired owner list the relay holds; NIP-01 order (later
    # created_at, then lower id). strfry keeps one per owner, so this picks between owners.
    flt = {"kinds": [WRITERS_KIND], "authors": sorted(OWNERS), "#d": [WRITERS_D]}
    out = subprocess.run(SCAN_CMD + [json.dumps(flt)], capture_output=True, text=True,
                         timeout=SCAN_TIMEOUT, check=True).stdout
    now, best = time.time(), None
    for line in out.splitlines():
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if not isinstance(ev, dict) or ev.get("pubkey") not in OWNERS or not is_writer_list(ev) \
                or list_fault(ev) or expired(ev, now):
            continue
        if best is None or (ev["created_at"], -int(ev["id"], 16)) > (best["created_at"], -int(best["id"], 16)):
            best = ev
    return {t[1] for t in best["tags"] if t[0] == "p"} if best else set()


CACHE = {"at": None, "writers": set()}


def writers():
    if not OWNERS:
        return set()
    now = time.monotonic()
    if CACHE["at"] is None or now - CACHE["at"] >= SCAN_TTL:
        try:
            CACHE["writers"] = stored_writers()
        except Exception as e:
            # Fail closed: a list deleted or expired during the outage must not keep
            # admitting. The static allow-list is unaffected.
            CACHE["writers"] = set()
            sys.stderr.write(f"write-policy: cannot read the stored writer list, admitting no extra writers: {e}\n")
        CACHE["at"] = now
    return CACHE["writers"]


def fleet(pk):
    return pk in ALLOW or pk in writers()


def addressed_to_fleet(ev):
    for tag in ev.get("tags") or []:
        if isinstance(tag, list) and len(tag) >= 2 and tag[0] == "p" \
                and isinstance(tag[1], str) and fleet(tag[1].lower()):
            return True
    return False


def decide(ev):
    pk = (ev.get("pubkey") or "").lower()
    if pk in OWNERS and is_writer_list(ev):
        fault = list_fault(ev)
        return ("reject", fault) if fault else ("accept", "")
    if fleet(pk):
        return "accept", ""
    if ev.get("kind") in ALLOW_KINDS:
        return "accept", ""
    if ev.get("kind") in RECIPIENT_KINDS and addressed_to_fleet(ev):
        return "accept", ""
    return "reject", "restricted relay: author not in the Nave fleet allow-list (and not a wrap addressed to it)"


if __name__ == "__main__":
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
