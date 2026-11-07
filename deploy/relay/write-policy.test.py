#!/usr/bin/env python3
# Offline tests for write-policy.py — drives the plugin exactly as strfry does:
# a subprocess fed one JSON request per line on stdin, one decision per line
# expected on stdout. No relay, no network.
#
#   python3 write-policy.test.py
#
# The recipient-admission cases (kind 1059) pin nave.pub#37: gift wraps have
# ephemeral authors BY DESIGN, so the fleet relay must admit them by who they
# are addressed TO — and only the fleet; a wrap to a stranger stays rejected.
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
FLEET = "aa" * 32                      # an allowlisted key
FLEET2 = "bb" * 32                     # a second allowlisted key
STRANGER = "cc" * 32                   # not allowlisted
EPHEMERAL = "dd" * 32                  # a wrap's single-use author

ALLOWLIST = {
    "allow": {"one": FLEET, "two": FLEET2.upper(),   # exercise case-insensitivity
              "pending": "REPLACE_WITH_SOVEREIGN"},  # placeholder must be skipped
    "allowKinds": [24133],
    "recipientKinds": [1059],
}


def run(requests, conf=ALLOWLIST, state=None):
    # Each call is a fresh plugin process. `state` is the writer-list file; by default a new,
    # empty one per call, so earlier tests can't leak writers into later ones.
    state = state or os.path.join(tempfile.mkdtemp(), "writers.json")
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(conf, f)
        path = f.name
    try:
        proc = subprocess.run(
            [sys.executable, os.path.join(HERE, "write-policy.py")],
            input="\n".join(json.dumps(r) for r in requests) + "\n",
            capture_output=True, text=True, timeout=15,
            env={**os.environ, "ALLOWLIST_PATH": path, "WRITERS_STATE_PATH": state},
        )
        assert proc.returncode == 0, proc.stderr
        return [json.loads(l) for l in proc.stdout.strip().splitlines() if l.strip()]
    finally:
        os.unlink(path)


def new(ev):
    return {"type": "new", "event": ev, "sourceType": "IP4", "sourceInfo": "127.0.0.1"}


def wrap(to, extra_tags=None, kind=1059):
    return {"id": "w1", "pubkey": EPHEMERAL, "kind": kind,
            "tags": [["p", to]] + (extra_tags or []), "content": "sealed"}


n = pass_ = 0
def t(name, got, want):
    global n, pass_
    n += 1
    if got == want:
        pass_ += 1
        print(f"ok - {name}")
    else:
        print(f"FAIL - {name}\n   got {got!r}, want {want!r}")


out = run([new({"id": "a1", "pubkey": FLEET, "kind": 1, "tags": [], "content": "hi"})])
t("fleet author accepted", out[0]["action"], "accept")

out = run([new({"id": "a2", "pubkey": FLEET2, "kind": 30440, "tags": [], "content": "x"})])
t("fleet author accepted case-insensitively (allowlist stored uppercase)", out[0]["action"], "accept")

out = run([new({"id": "a3", "pubkey": STRANGER, "kind": 1, "tags": [], "content": "spam"})])
t("stranger author rejected", out[0]["action"], "reject")

out = run([new({"id": "a4", "pubkey": STRANGER, "kind": 24133, "tags": [], "content": "enc"})])
t("open transport kind (24133) accepted from anyone", out[0]["action"], "accept")

# ---- nave.pub#37: recipient-based admission for gift wraps ----------------
out = run([new(wrap(FLEET))])
t("1059 wrap ADDRESSED to fleet accepted (ephemeral author)", out[0]["action"], "accept")

out = run([new(wrap(FLEET.upper()))])
t("1059 recipient match is case-insensitive", out[0]["action"], "accept")

out = run([new(wrap(STRANGER))])
t("1059 wrap to a stranger rejected — spam control intact", out[0]["action"], "reject")

out = run([new(wrap(STRANGER, extra_tags=[["p", FLEET]]))])
t("1059 with ANY fleet p-tag accepted (multi-tag wrap)", out[0]["action"], "accept")

out = run([new({"id": "w2", "pubkey": EPHEMERAL, "kind": 1059, "tags": [], "content": "x"})])
t("1059 with no p tag rejected", out[0]["action"], "reject")

out = run([new({"id": "w3", "pubkey": EPHEMERAL, "kind": 1059,
                "tags": [["e", FLEET], ["p"], "notalist", ["p", 42]], "content": "x"})])
t("1059 with malformed/non-p tags rejected, not crashed", out[0]["action"], "reject")

out = run([new(wrap(FLEET, kind=1))])
t("recipient admission applies ONLY to recipientKinds — kind 1 to fleet still rejected",
  out[0]["action"], "reject")

out = run([new(wrap("REPLACE_WITH_SOVEREIGN"))])
t("placeholder allowlist entries never admit anything", out[0]["action"], "reject")

conf_no_rk = {k: v for k, v in ALLOWLIST.items() if k != "recipientKinds"}
out = run([new(wrap(FLEET))], conf=conf_no_rk)
t("config without recipientKinds = old behavior exactly (wrap rejected)", out[0]["action"], "reject")

out = run([
    {"type": "lookback", "event": {"id": "ig", "pubkey": STRANGER, "kind": 1}},
    new({"id": "a5", "pubkey": FLEET, "kind": 7, "tags": [], "content": "+"}),
])
t("non-'new' requests are ignored; stream continues", [o["id"] for o in out], ["a5"])

out = run([new(wrap(FLEET)), new(wrap(STRANGER)), new(wrap(FLEET2))])
t("decisions stay line-aligned across a stream",
  [o["action"] for o in out], ["accept", "reject", "accept"])

# ---- nave.pub#157: the owner's writer list --------------------------------
# Real signatures: the plugin checks the id and BIP-340 signature of a writer list itself.
import hashlib
import importlib.util
import time

os.environ.setdefault("ALLOWLIST_PATH", os.path.join(HERE, "allowlist.json"))
_spec = importlib.util.spec_from_file_location("wp", os.path.join(HERE, "write-policy.py"))
wp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(wp)


def pubkey(sk):
    return wp._mul(wp._G, sk)[0].to_bytes(32, "big").hex()


def schnorr_sign(msg, sk):
    pt = wp._mul(wp._G, sk)
    d = sk if pt[1] % 2 == 0 else wp._N - sk
    px = pt[0].to_bytes(32, "big")
    t = (d ^ int.from_bytes(wp._tagged("BIP0340/aux", bytes(32)), "big")).to_bytes(32, "big")
    k0 = int.from_bytes(wp._tagged("BIP0340/nonce", t + px + msg), "big") % wp._N
    R = wp._mul(wp._G, k0)
    k = k0 if R[1] % 2 == 0 else wp._N - k0
    e = int.from_bytes(wp._tagged("BIP0340/challenge", R[0].to_bytes(32, "big") + px + msg), "big") % wp._N
    return R[0].to_bytes(32, "big") + ((k + e * d) % wp._N).to_bytes(32, "big")


def signed(sk, kind, tags, created_at, content=""):
    ev = {"pubkey": pubkey(sk), "created_at": created_at, "kind": kind, "tags": tags, "content": content}
    ser = json.dumps([0, ev["pubkey"], created_at, kind, tags, content], separators=(",", ":"), ensure_ascii=False)
    ev["id"] = hashlib.sha256(ser.encode()).hexdigest()
    ev["sig"] = schnorr_sign(bytes.fromhex(ev["id"]), sk).hex()
    return ev


OWNER_SK, STRANGER_SK, FLEET_SK = 0x11 * 7 + 1, 0x22 * 13 + 5, 0x33 * 17 + 3
OWNER, STRANGER_SIGNER, FLEET_SIGNER = pubkey(OWNER_SK), pubkey(STRANGER_SK), pubkey(FLEET_SK)
NEW_A, NEW_B = "a1" * 32, "b2" * 32
NOW = int(time.time())
OWNED = {**ALLOWLIST, "allow": {**ALLOWLIST["allow"], "fleet_signer": FLEET_SIGNER},
         "owners": {"james": OWNER, "pending": "REPLACE_WITH_OWNER"}}


def writer_list(sk, keys, created_at=NOW, d="nave-relay-writers"):
    return signed(sk, 30000, [["d", d]] + [["p", k] for k in keys], created_at)


def post(pk, i="p1"):
    return {"id": i, "pubkey": pk, "kind": 1, "tags": [], "content": "hello"}


def fresh_state():
    return os.path.join(tempfile.mkdtemp(), "writers.json")


# Interop anchor: an event signed by nostr-tools (throwaway key), with non-ASCII and escaped content.
NOSTR_TOOLS_EVENT = {"kind": 30000, "created_at": 1794000000, "tags": [["d", "nave-relay-writers"], ["p", "abababababababababababababababababababababababababababababababab"], ["p", "cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd"]], "content": "h\u00e9llo \"q\" \\ \u2713", "pubkey": "f2eb47f004fbc3ecaa362e075db3d30b0b8bae365be6d9e96e68a615e9004d14", "id": "de8f3e304c45ca8491cc2d29ad6145476367ae8ea04023a24b3f70e771103116", "sig": "3b6af85fa4d0434057424f37ad2b8989cb99a7657e8a729c470e047bad550479e93cfd105ef8a8968ee12d41506fac3e6ea3329b2adce148b62554659328e579"}
t("interop: an event signed by nostr-tools verifies", wp.event_ok(NOSTR_TOOLS_EVENT), True)
t("interop: the same event with one content byte changed does not", wp.event_ok({**NOSTR_TOOLS_EVENT, "content": "x"}), False)

out = run([new(post(NEW_A))], conf=OWNED)
t("negative control: a key on no list is rejected", out[0]["action"], "reject")

st = fresh_state()
out = run([new(writer_list(OWNER_SK, [NEW_A])), new(post(NEW_A)), new(wrap(NEW_A))], conf=OWNED, state=st)
t("owner's writer list accepted, then its key may write in the same stream (no restart)",
  [o["action"] for o in out], ["accept", "accept", "accept"])

out = run([new(post(NEW_A, "p2"))], conf=OWNED, state=st)
t("the owner's list survives a plugin restart", out[0]["action"], "accept")

out = run([new(writer_list(STRANGER_SK, [NEW_A])), new(post(NEW_A))], conf=OWNED)
t("a stranger's writer list is rejected and admits nobody", [o["action"] for o in out], ["reject", "reject"])

out = run([new(writer_list(FLEET_SK, [NEW_A])), new(post(NEW_A))], conf=OWNED)
t("a fleet key that is not an owner: its list is stored as a fleet post, but admits nobody",
  [o["action"] for o in out], ["accept", "reject"])

bad = writer_list(OWNER_SK, [NEW_A])
bad["sig"] = bad["sig"][:-1] + ("0" if bad["sig"][-1] != "0" else "1")
out = run([new(bad), new(post(NEW_A))], conf=OWNED)
t("an owner list with a bad signature is rejected and admits nobody", [o["action"] for o in out], ["reject", "reject"])
t("  ...and says why", out[0]["msg"].startswith("invalid:"), True)

forged = writer_list(OWNER_SK, [NEW_A])
forged["tags"] = forged["tags"] + [["p", NEW_B]]
out = run([new(forged), new(post(NEW_B))], conf=OWNED)
t("an owner list with tags changed after signing is rejected", [o["action"] for o in out], ["reject", "reject"])

st = fresh_state()
out = run([new(writer_list(OWNER_SK, [NEW_A], NOW - 100)), new(writer_list(OWNER_SK, [NEW_B], NOW - 50)),
           new(post(NEW_A)), new(post(NEW_B, "p2"))], conf=OWNED, state=st)
t("a newer list replaces the held set, never adds to it", [o["action"] for o in out], ["accept", "accept", "reject", "accept"])

out = run([new(writer_list(OWNER_SK, [NEW_A], NOW - 200)), new(post(NEW_A)), new(post(NEW_B, "p2"))], conf=OWNED, state=st)
t("an older list changes nothing", [o["action"] for o in out], ["accept", "reject", "accept"])

x, y = writer_list(OWNER_SK, [NEW_A], NOW - 10), writer_list(OWNER_SK, [NEW_B], NOW - 10)
low, high = (x, y) if x["id"] < y["id"] else (y, x)
low_key = NEW_A if low is x else NEW_B
out = run([new(high), new(low), new(post(low_key))], conf=OWNED)
t("same second: the lower id wins (NIP-01), whatever the arrival order", out[2]["action"], "accept")
out = run([new(low), new(high), new(post(low_key))], conf=OWNED)
t("same second, other order: the lower id still holds", out[2]["action"], "accept")

out = run([new(writer_list(OWNER_SK, [NEW_A], NOW + 3600)), new(post(NEW_A))], conf=OWNED)
t("a list dated an hour ahead is rejected", [o["action"] for o in out], ["reject", "reject"])

for label, k in [("uppercase", NEW_A.upper()), ("short", "ab" * 31)]:
    out = run([new(writer_list(OWNER_SK, [NEW_B, k])), new(post(NEW_B))], conf=OWNED)
    t(f"a list with a {label} p tag is rejected whole", [o["action"] for o in out], ["reject", "reject"])

out = run([new(writer_list(OWNER_SK, [])), new(post(FLEET)), new(post(NEW_A, "p2"))], conf=OWNED)
t("an empty owner list never removes the static allow-list", [o["action"] for o in out], ["accept", "accept", "reject"])

out = run([new(writer_list(OWNER_SK, [NEW_A], d="something-else")), new(post(NEW_A))], conf=OWNED)
t("an owner's kind 30000 with another d is judged as before (owner not in allow: rejected)",
  [o["action"] for o in out], ["reject", "reject"])

st = fresh_state()
with open(st, "w") as f:
    f.write('{"id": "x", "created_at": 1, "writers": ["not-a-key"]}')
out = run([new(post(FLEET)), new(post(NEW_A, "p2"))], conf=OWNED, state=st)
t("a malformed state file is ignored: the static list works, nobody extra", [o["action"] for o in out], ["accept", "reject"])

blocked = os.path.join(tempfile.mkdtemp(), "file-not-dir")
open(blocked, "w").close()
out = run([new(writer_list(OWNER_SK, [NEW_A])), new(post(NEW_A))], conf=OWNED, state=os.path.join(blocked, "writers.json"))
t("a list that cannot be saved is rejected, and admits nobody", [o["action"] for o in out], ["reject", "reject"])
t("  ...and says nothing changed", "nothing changed" in out[0]["msg"], True)

out = run([new(writer_list(OWNER_SK, [NEW_A])), new(post(NEW_A))], conf=ALLOWLIST)
t("a config with no owners: an owner-shaped list changes nothing", [o["action"] for o in out], ["reject", "reject"])

print(f"\n{pass_}/{n} passed")
sys.exit(0 if pass_ == n else 1)
