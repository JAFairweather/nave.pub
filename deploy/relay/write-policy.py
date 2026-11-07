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
#      nave-relay-writers) is checked here — id and BIP-340 signature — and,
#      when newer than the list held, its `p` tags become the extra writers
#      (nave.pub#157). It replaces the held set, never adds to it, and is saved
#      to WRITERS_STATE_PATH so a restart keeps it. A kind 30000 from anyone
#      else is judged by the rules below, exactly as before;
#   1. accept events AUTHORED by a fleet pubkey: allowlist.json `allow`, which
#      always stays, plus the owner's extra writers;
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
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
CONF = os.environ.get("ALLOWLIST_PATH", os.path.join(HERE, "allowlist.json"))
STATE = os.environ.get("WRITERS_STATE_PATH", os.path.join(HERE, "state", "writers.json"))

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


# --- The owner's writer list, held in memory and on disk. ---
def read_state():
    try:
        with open(STATE) as f:
            s = json.load(f)
        writers = s["writers"]
        if not (isinstance(s["id"], str) and isinstance(s["created_at"], int) and isinstance(writers, list)
                and len(writers) <= MAX_WRITERS and all(isinstance(w, str) and HEX64.match(w) for w in writers)):
            raise ValueError("malformed")
        return {"id": s["id"], "created_at": s["created_at"], "writers": set(writers)}
    except FileNotFoundError:
        return None
    except Exception as e:
        sys.stderr.write(f"write-policy: ignoring writer list at {STATE}: {e}\n")
        return None


HELD = read_state()


def writers():
    return HELD["writers"] if HELD else set()


def fleet(pk):
    return pk in ALLOW or pk in writers()


def save(state):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump({"id": state["id"], "created_at": state["created_at"], "writers": sorted(state["writers"])}, f)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, STATE)


def take_writer_list(ev):
    global HELD
    if not event_ok(ev):
        return "reject", "invalid: writer list id or signature does not verify"
    ps = [t[1] for t in ev.get("tags") or [] if isinstance(t, list) and len(t) >= 2 and t[0] == "p"]
    if any(not isinstance(p, str) or not HEX64.match(p) for p in ps):
        return "reject", "invalid: every p tag in a writer list must be a lowercase 64-hex key"
    if len(set(ps)) > MAX_WRITERS:
        return "reject", f"invalid: a writer list holds at most {MAX_WRITERS} keys"
    if ev["created_at"] > time.time() + MAX_FUTURE_SEC:
        return "reject", "invalid: writer list is dated in the future"
    # NIP-01 replaceable order: the later created_at wins; in the same second, the lower id.
    # A list that loses is still stored by strfry's own rules, but changes nothing here.
    if HELD and not (ev["created_at"] > HELD["created_at"]
                     or (ev["created_at"] == HELD["created_at"] and ev["id"] < HELD["id"])):
        return "accept", ""
    state = {"id": ev["id"], "created_at": ev["created_at"], "writers": set(ps)}
    try:
        save(state)
    except Exception as e:
        sys.stderr.write(f"write-policy: cannot save writer list: {e}\n")
        return "reject", "error: the relay could not save this writer list; nothing changed"
    HELD = state
    return "accept", ""


def is_writer_list(ev):
    return ev.get("kind") == WRITERS_KIND and \
        [t[1] for t in ev.get("tags") or [] if isinstance(t, list) and len(t) >= 2 and t[0] == "d"] == [WRITERS_D]


def addressed_to_fleet(ev):
    for tag in ev.get("tags") or []:
        if isinstance(tag, list) and len(tag) >= 2 and tag[0] == "p" \
                and isinstance(tag[1], str) and fleet(tag[1].lower()):
            return True
    return False


def decide(ev):
    pk = (ev.get("pubkey") or "").lower()
    if pk in OWNERS and is_writer_list(ev):
        return take_writer_list(ev)
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
