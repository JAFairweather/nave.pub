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
import tempfile
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CONF = os.environ.get("ALLOWLIST_PATH", os.path.join(HERE, "allowlist.json"))
# How to read the relay's own store; tests point this at a fake. The filter JSON is appended.
SCAN_CMD = json.loads(os.environ.get("WRITERS_SCAN_CMD") or
                      '["/app/strfry", "--config=/etc/strfry.conf", "scan"]')
SCAN_TTL = float(os.environ.get("WRITERS_SCAN_TTL", "2"))
SCAN_TIMEOUT = 10
FREEZE_PATH = os.environ.get("DELEGATE_FREEZE_PATH", "/app/policy-state/delegate-freeze.json")
JOIN_POLICY_URL = os.environ.get("JOIN_POLICY_URL", "https://nave.communities.buzz.xyz/api/join-policy")

WRITERS_KIND = 30000
WRITERS_D = "nave-relay-writers"
DELEGATE_D = "nave-relay-writers-delegate"
DENY_D = "nave-relay-writers-deny"
REQUEST_RE = re.compile(r"^nvoy-onboard/([a-z0-9][a-z0-9._-]{1,63})/add_agent$")
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
    runner = c.get("onboardRunner")
    if runner is not None and (not isinstance(runner, str) or not HEX64.match(runner)):
        raise ValueError("onboardRunner must be a lowercase 64-hex key")
    policy = c.get("onboardPolicy")
    if policy is not None and (not isinstance(policy, str) or not policy.strip()):
        raise ValueError("onboardPolicy must be a nonempty version string")
    return keys(c.get("allow")), set(c.get("allowKinds") or []), set(c.get("recipientKinds") or []), owners, runner, policy


ALLOW, ALLOW_KINDS, RECIPIENT_KINDS, OWNERS, RUNNER, ONBOARD_POLICY = load()


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


def tags(ev, name):
    return [t[1] for t in (ev or {}).get("tags") or [] if isinstance(t, list) and len(t) >= 2 and t[0] == name]


def only_tag(ev, name):
    values = tags(ev, name)
    return values[0] if len(values) == 1 and isinstance(values[0], str) else None


def scan_events(flt):
    out = subprocess.run(SCAN_CMD + [json.dumps(flt)], capture_output=True, text=True,
                         timeout=SCAN_TIMEOUT, check=True).stdout
    events = []
    for line in out.splitlines():
        try:
            ev = json.loads(line)
        except ValueError as e:
            raise ValueError("malformed relay scan output") from e
        if not isinstance(ev, dict):
            raise ValueError("malformed relay scan output")
        events.append(ev)
    return events


def newest(events):
    return max(events, key=lambda e: (e["created_at"], -int(e["id"], 16)), default=None)


def scope_hash(subject, salt):
    if not isinstance(salt, str) or not re.fullmatch(r"[0-9a-f]{32}", salt):
        return None
    data = b"waggle/da-scope/v1\0" + subject.encode() + bytes.fromhex(salt)
    return hashlib.sha256(data).hexdigest()


def current_terms_version():
    """An unreadable live policy cannot authorize a new delegate effect."""
    request = urllib.request.Request(JOIN_POLICY_URL, headers={"Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=3) as response:
        if response.status not in (200, None):
            raise ValueError("join policy read was not 200")
        body = response.read(65537)
    if len(body) > 65536:
        raise ValueError("join policy response is too large")
    data = json.loads(body)
    if not isinstance(data, dict):
        raise ValueError("join policy response is not an object")
    if not data or data == {"policy": None}:
        return "none"
    policy = data.get("policy")
    if not isinstance(policy, dict) or policy.get("version") is None or not (
            policy.get("terms_markdown") or policy.get("privacy_markdown")):
        raise ValueError("join policy response has no versioned terms")
    return str(policy["version"])


def onboard_grants():
    """Fresh relay-store read. A scan failure never leaves a cached delegate authority."""
    if not OWNERS or not RUNNER:
        return {}, {}, {}
    grants = {}
    for ev in scan_events({"kinds": [440], "authors": sorted(OWNERS)}):
        if ev.get("kind") != 440 or ev.get("pubkey") not in OWNERS or not event_ok(ev):
            continue
        grantee, cap, scope = only_tag(ev, "p"), only_tag(ev, "da-cap"), tags(ev, "da-scope")
        if not grantee or not HEX64.match(grantee) or cap != "onboard" or len(scope) != 1:
            continue
        raw_scope = [t for t in ev["tags"] if isinstance(t, list) and len(t) >= 3 and t[0] == "da-scope"]
        if len(raw_scope) != 1 or scope_hash(ev["pubkey"], raw_scope[0][2]) != raw_scope[0][1]:
            continue
        if only_tag(ev, "age") != "confirmed" or not only_tag(ev, "policy"):
            continue
        grants[ev["id"]] = ev
    revoked = {}
    if grants:
        for ev in scan_events({"kinds": [441], "authors": sorted(OWNERS), "#e": sorted(grants)}):
            if ev.get("kind") != 441 or ev.get("pubkey") not in OWNERS or not event_ok(ev):
                continue
            for grant_id in tags(ev, "e"):
                if grant_id in grants and grants[grant_id]["pubkey"] == ev["pubkey"]:
                    revoked[grant_id] = ev
    live = {gid: ev for gid, ev in grants.items() if gid not in revoked and
            not expired(ev, time.time()) and only_tag(ev, "policy") == ONBOARD_POLICY}
    return grants, live, revoked


def stored_list(author, d):
    if not author:
        return None
    valid = []
    for ev in scan_events({"kinds": [30000], "authors": [author], "#d": [d]}):
        if ev.get("kind") == 30000 and ev.get("pubkey") == author and is_list(ev, d) and not list_fault(ev) and not expired(ev, time.time()):
            valid.append(ev)
    return newest(valid)


def freeze_state():
    try:
        with open(FREEZE_PATH) as f:
            state = json.load(f)
        if isinstance(state, dict) and HEX64.match(state.get("revocation", "")) and \
                (state.get("list_id") is None or HEX64.match(state["list_id"])) and \
                isinstance(state.get("keys"), list) and all(HEX64.match(k) for k in state["keys"]):
            return state
    except FileNotFoundError:
        return None
    raise ValueError("delegate freeze state is unreadable or invalid")


def pin_freeze(revocation, delegate_list):
    """Persistent relay-observed 441 fence, independent of signer's timestamps."""
    directory = os.path.dirname(FREEZE_PATH)
    os.makedirs(directory, mode=0o700, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix=".delegate-freeze-", dir=directory)
    try:
        with os.fdopen(fd, "w") as f:
            json.dump({"revocation": revocation,
                       "list_id": delegate_list["id"] if delegate_list else None,
                       "keys": sorted(set(tags(delegate_list, "p"))) if delegate_list else []}, f)
            f.flush()
            os.fsync(f.fileno())
        os.replace(temp, FREEZE_PATH)
        dir_fd = os.open(directory, os.O_DIRECTORY)
        try:
            os.fsync(dir_fd)
        finally:
            os.close(dir_fd)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def is_list(ev, d):
    return ev.get("kind") == WRITERS_KIND and tags(ev, "d") == [d]


def delegate_snapshot():
    """Read the stored grants/lists; first observed 441 pins the last delegate set."""
    grants, live, revocations = onboard_grants()
    delegates = {only_tag(ev, "p") for ev in grants.values()}
    if len(delegates) > 1:
        raise ValueError("more than one onboarding delegate is configured")
    delegate = next(iter(delegates), None)
    current = stored_list(delegate, DELEGATE_D) if delegate else None
    freeze = freeze_state()
    if revocations and not freeze:
        pin_freeze(min(ev["id"] for ev in revocations.values()), current)
        freeze = freeze_state()
    if freeze and freeze["list_id"] and current and current["id"] != freeze["list_id"]:
        sys.stderr.write("write-policy: stored delegate list differs from pinned 441 freeze; using pinned keys\n")
    delegate_keys = set(freeze["keys"]) if freeze else set(tags(current, "p")) if current else set()
    owner_lists = [stored_list(owner, WRITERS_D) for owner in OWNERS]
    owner_lists = [ev for ev in owner_lists if ev]
    owner_list = newest(owner_lists)
    owner_keys = set(tags(owner_list, "p")) if owner_list else set()
    deny_lists = [stored_list(owner, DENY_D) for owner in OWNERS]
    deny_lists = [ev for ev in deny_lists if ev]
    deny = newest(deny_lists)
    denied = set(tags(deny, "p")) if deny else set()
    effective = (ALLOW | owner_keys | delegate_keys) - denied
    return {"delegate": delegate, "grants": grants, "live": live, "revocations": revocations,
            "current": current, "freeze": freeze, "owner": owner_list, "deny": deny,
            "effective": effective}


def valid_delegate_request(ev, target, delegate, live_grants, now):
    if ev.get("kind") != 30078 or ev.get("pubkey") != delegate or not event_ok(ev) or \
            only_tag(ev, "p") != target or only_tag(ev, "op") != "add_agent" or ev.get("content") != "":
        return False
    if ev.get("created_at", 0) > now + MAX_FUTURE_SEC or now - ev["created_at"] > 7 * 86400 or expired(ev, now):
        return False
    if not REQUEST_RE.match(only_tag(ev, "d") or "") or tags(ev, "giver"):
        return False
    grant = live_grants.get(only_tag(ev, "consent"))
    return bool(grant and only_tag(grant, "p") == delegate)


def request_authorizes(target, delegate, live_grants):
    if not target or not HEX64.match(target):
        return False
    now = time.time()
    requests = scan_events({"kinds": [30078], "authors": [delegate], "#p": [target]})
    for ev in requests:
        if not valid_delegate_request(ev, target, delegate, live_grants, now):
            continue
        terminal_d = f"nvoy-onboard:{ev['id']}:terminal"
        markers = scan_events({"kinds": [30078], "authors": [RUNNER], "#d": [terminal_d], "#e": [ev["id"]]})
        terminal = any(m.get("kind") == 30078 and m.get("pubkey") == RUNNER and event_ok(m) and
                       m.get("content") == "" and m.get("tags") == [["d", terminal_d], ["e", ev["id"]]]
                       for m in markers)
        if not terminal:
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


CACHE = {"at": None, "effective": set()}


def writers():
    if not OWNERS:
        return ALLOW
    now = time.monotonic()
    if CACHE["at"] is None or now - CACHE["at"] >= SCAN_TTL:
        try:
            CACHE["effective"] = delegate_snapshot()["effective"]
        except Exception as e:
            # If the deny list is unknown, even a static key may have been denied.
            CACHE["effective"] = set()
            sys.stderr.write(f"write-policy: cannot read stored writer policy, admitting no writers: {e}\n")
        CACHE["at"] = now
    return CACHE["effective"]


def fleet(pk):
    return pk in writers()


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
    if pk in OWNERS and is_list(ev, DENY_D):
        fault = list_fault(ev)
        return ("reject", fault) if fault else ("accept", "")
    # The delegate key is not a general fleet writer. Only these two event
    # shapes can pass it, and only with a fresh stored grant and no 441 freeze.
    if RUNNER and (is_list(ev, DELEGATE_D) or
                   (ev.get("kind") == 30078 and REQUEST_RE.match(only_tag(ev, "d") or ""))):
        try:
            state = delegate_snapshot()
            if pk == state["delegate"]:
                if not ONBOARD_POLICY or current_terms_version() != ONBOARD_POLICY:
                    return "reject", "onboard grant policy is not the current hive terms version"
                if is_list(ev, DELEGATE_D):
                    fault = list_fault(ev)
                    if fault:
                        return "reject", fault
                    if state["freeze"]:
                        return "reject", "delegate writer list frozen by stored 441"
                    if not any(only_tag(g, "p") == pk for g in state["live"].values()):
                        return "reject", "no live onboard grant for delegate"
                    if tags(ev, "expiration"):
                        return "reject", "delegate writer list must be durable"
                    old = set(tags(state["current"], "p")) if state["current"] else set()
                    for target in set(tags(ev, "p")) - old:
                        if not request_authorizes(target, pk, state["live"]):
                            return "reject", f"no live unfinished delegate request for {target}"
                    return "accept", ""
                if ev.get("kind") == 30078 and \
                        valid_delegate_request(ev, only_tag(ev, "p"), pk, state["live"], time.time()):
                    return "accept", ""
                return "reject", "delegate may only submit its scoped onboarding request or writer list"
        except Exception as e:
            sys.stderr.write(f"write-policy: delegate policy read failed: {e}\n")
            return "reject", "delegate policy unavailable"
    if fleet(pk):
        return "accept", ""
    if ev.get("kind") in ALLOW_KINDS:
        return "accept", ""
    if ev.get("kind") in RECIPIENT_KINDS and addressed_to_fleet(ev):
        return "accept", ""
    return "reject", "restricted relay: author not in the Nave fleet allow-list (and not a wrap addressed to it)"


if __name__ == "__main__":
    if sys.argv[1:] == ["--effective-snapshot"]:
        # A publisher may sign this exact set after the operator provisions a
        # relay identity. This command never signs or publishes by itself.
        state = delegate_snapshot()
        sys.stdout.write(json.dumps({
            "keys": sorted(state["effective"]),
            "owner_list": state["owner"]["id"] if state["owner"] else None,
            "delegate_list": state["freeze"]["list_id"] if state["freeze"] else
                             state["current"]["id"] if state["current"] else None,
            "deny_list": state["deny"]["id"] if state["deny"] else None,
            "freeze_revocation": state["freeze"]["revocation"] if state["freeze"] else None,
        }, sort_keys=True) + "\n")
        sys.exit(0)
    if len(sys.argv) > 1:
        sys.exit("usage: write-policy.py [--effective-snapshot]")
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
