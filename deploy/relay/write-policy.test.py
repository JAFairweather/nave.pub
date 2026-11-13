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
from pathlib import Path
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


# The relay's store, as `strfry scan` would print it: one event per line. The fake ignores the
# filter, so the plugin's own checks on what it reads back are exercised too.
FAKE_SCAN = "import sys; sys.stdout.write(open(sys.argv[1]).read())"


def store_file(events=()):
    path = os.path.join(tempfile.mkdtemp(), "store.jsonl")
    with open(path, "w") as f:
        f.writelines(json.dumps(e) + "\n" for e in events)
    return path


def plugin_env(conf_path, store, ttl="2", freeze=None, policy="v1"):
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump({"policy": {"version": policy, "terms_markdown": "Current terms"}}, f)
        policy_url = Path(f.name).as_uri()
    return {**os.environ, "ALLOWLIST_PATH": conf_path, "WRITERS_SCAN_TTL": ttl,
            "DELEGATE_FREEZE_PATH": freeze or os.path.join(tempfile.mkdtemp(), "freeze.json"),
            "JOIN_POLICY_URL": policy_url,
            "WRITERS_SCAN_CMD": json.dumps([sys.executable, "-c", FAKE_SCAN, store])}


def run(requests, conf=ALLOWLIST, store=None, freeze=None, policy="v1"):
    # Each call is a fresh plugin process over a store; by default an empty one.
    store = store or store_file()
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(conf, f)
        path = f.name
    try:
        proc = subprocess.run(
            [sys.executable, os.path.join(HERE, "write-policy.py")],
            input="\n".join(json.dumps(r) for r in requests) + "\n",
            capture_output=True, text=True, timeout=15,
            env=plugin_env(path, store, freeze=freeze, policy=policy),
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


def writer_list(sk, keys, created_at=NOW, d="nave-relay-writers", tags=()):
    return signed(sk, 30000, [["d", d]] + [["p", k] for k in keys] + list(tags), created_at)


def post(pk, i="p1"):
    return {"id": i, "pubkey": pk, "kind": 1, "tags": [], "content": "hello"}


# Interop anchor: an event signed by nostr-tools (throwaway key), with non-ASCII and escaped content.
NOSTR_TOOLS_EVENT = {"kind": 30000, "created_at": 1794000000, "tags": [["d", "nave-relay-writers"], ["p", "abababababababababababababababababababababababababababababababab"], ["p", "cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd"]], "content": "h\u00e9llo \"q\" \\ \u2713", "pubkey": "f2eb47f004fbc3ecaa362e075db3d30b0b8bae365be6d9e96e68a615e9004d14", "id": "de8f3e304c45ca8491cc2d29ad6145476367ae8ea04023a24b3f70e771103116", "sig": "3b6af85fa4d0434057424f37ad2b8989cb99a7657e8a729c470e047bad550479e93cfd105ef8a8968ee12d41506fac3e6ea3329b2adce148b62554659328e579"}
t("interop: an event signed by nostr-tools verifies", wp.event_ok(NOSTR_TOOLS_EVENT), True)
t("interop: the same event with one content byte changed does not", wp.event_ok({**NOSTR_TOOLS_EVENT, "content": "x"}), False)

# -- the door: what the plugin says about an incoming owner list --
out = run([new(writer_list(OWNER_SK, [NEW_A]))], conf=OWNED)
t("a sound owner list passes the door", out[0]["action"], "accept")

out = run([new(writer_list(STRANGER_SK, [NEW_A]))], conf=OWNED)
t("a stranger's writer list is rejected", out[0]["action"], "reject")

bad = writer_list(OWNER_SK, [NEW_A])
bad["sig"] = bad["sig"][:-1] + ("0" if bad["sig"][-1] != "0" else "1")
out = run([new(bad)], conf=OWNED)
t("an owner list with a bad signature is rejected", out[0]["action"], "reject")
t("  ...and says why", out[0]["msg"].startswith("invalid:"), True)

forged = writer_list(OWNER_SK, [NEW_A])
forged["tags"] = forged["tags"] + [["p", NEW_B]]
t("an owner list with tags changed after signing is rejected", run([new(forged)], conf=OWNED)[0]["action"], "reject")

out = run([new(writer_list(OWNER_SK, [NEW_A], NOW + 3600))], conf=OWNED)
t("a list dated an hour ahead is rejected", out[0]["action"], "reject")

for label, k in [("uppercase", NEW_A.upper()), ("short", "ab" * 31)]:
    out = run([new(writer_list(OWNER_SK, [NEW_B, k]))], conf=OWNED)
    t(f"a list with a {label} p tag is rejected whole", out[0]["action"], "reject")

out = run([new(writer_list(OWNER_SK, [NEW_A], d="something-else"))], conf=OWNED)
t("an owner's kind 30000 with another d is judged as before (owner not in allow: rejected)", out[0]["action"], "reject")

# -- admission: only what the relay has stored counts (mydude's review of a52cae9) --
out = run([new(post(NEW_A))], conf=OWNED)
t("negative control: a key on no list is rejected", out[0]["action"], "reject")

out = run([new(writer_list(OWNER_SK, [NEW_A])), new(post(NEW_A)), new(wrap(NEW_A))], conf=OWNED)
t("a list the plugin passed but the relay did not store admits nobody (expired, deleted, replaced)",
  [o["action"] for o in out], ["accept", "reject", "reject"])

st = store_file([writer_list(OWNER_SK, [NEW_A])])
out = run([new(post(NEW_A)), new(wrap(NEW_A)), new(post(NEW_B, "p2"))], conf=OWNED, store=st)
t("a list the relay holds admits its keys as authors and as wrap recipients, nobody else",
  [o["action"] for o in out], ["accept", "accept", "reject"])

out = run([new(post(NEW_A))], conf=OWNED, store=st)
t("a fresh plugin process reads the same store: a restart keeps it", out[0]["action"], "accept")

st = store_file([writer_list(OWNER_SK, [NEW_A], tags=[["expiration", str(NOW - 1)]])])
t("a stored list past its expiration admits nobody", run([new(post(NEW_A))], conf=OWNED, store=st)[0]["action"], "reject")
st = store_file([writer_list(OWNER_SK, [NEW_A], tags=[["expiration", str(NOW + 3600)]])])
t("  ...and admits its keys until then", run([new(post(NEW_A))], conf=OWNED, store=st)[0]["action"], "accept")

OWNER2_SK = 0x44 * 19 + 7
TWO = {**OWNED, "owners": {"james": OWNER, "other": pubkey(OWNER2_SK)}}
st = store_file([writer_list(OWNER_SK, [NEW_A], NOW - 100), writer_list(OWNER2_SK, [NEW_B], NOW - 50)])
out = run([new(post(NEW_A)), new(post(NEW_B, "p2"))], conf=TWO, store=st)
t("between owners, the newer stored list replaces the older, never adds to it", [o["action"] for o in out], ["reject", "accept"])

x, y = writer_list(OWNER_SK, [NEW_A], NOW - 10), writer_list(OWNER2_SK, [NEW_B], NOW - 10)
low_key = NEW_A if x["id"] < y["id"] else NEW_B
for order in ([x, y], [y, x]):
    out = run([new(post(low_key))], conf=TWO, store=store_file(order))
    t("same second: the lower id wins (NIP-01), whatever the store order", out[0]["action"], "accept")

st = store_file([writer_list(STRANGER_SK, [NEW_A]), writer_list(FLEET_SK, [NEW_A])])
out = run([new(post(NEW_A))], conf=OWNED, store=st)
t("stored lists from a stranger or a non-owner fleet key admit nobody", out[0]["action"], "reject")

bad_stored = writer_list(OWNER_SK, [NEW_A])
bad_stored["tags"] = bad_stored["tags"] + [["p", NEW_B]]
t("a stored owner list that no longer verifies admits nobody",
  run([new(post(NEW_A))], conf=OWNED, store=store_file([bad_stored]))[0]["action"], "reject")

out = run([new(writer_list(OWNER_SK, [])), new(post(FLEET)), new(post(NEW_A, "p2"))], conf=OWNED,
          store=store_file([writer_list(OWNER_SK, [])]))
t("an empty owner list never removes the static allow-list", [o["action"] for o in out], ["accept", "accept", "reject"])

broken = json.dumps([sys.executable, "-c", "import sys; sys.exit(3)"])
with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
    json.dump(OWNED, f)
proc = subprocess.run([sys.executable, os.path.join(HERE, "write-policy.py")],
                      input=json.dumps(new(post(FLEET))) + "\n" + json.dumps(new(post(NEW_A, "p2"))) + "\n",
                      capture_output=True, text=True, timeout=15,
                      env={**os.environ, "ALLOWLIST_PATH": f.name, "WRITERS_SCAN_CMD": broken})
os.unlink(f.name)
out = [json.loads(l) for l in proc.stdout.split("\n") if l.strip()]
t("a store that cannot be read: unknown deny state admits nobody",
  [o["action"] for o in out], ["reject", "reject"])

out = run([new(writer_list(OWNER_SK, [NEW_A])), new(post(NEW_A))], conf=ALLOWLIST,
          store=store_file([writer_list(OWNER_SK, [NEW_A])]))
t("a config with no owners: an owner-shaped list changes nothing", [o["action"] for o in out], ["reject", "reject"])

# -- the store changes under a running plugin: admission follows it --
with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
    json.dump(OWNED, f)
st = store_file()
proc = subprocess.Popen([sys.executable, os.path.join(HERE, "write-policy.py")], stdin=subprocess.PIPE,
                        stdout=subprocess.PIPE, text=True, env=plugin_env(f.name, st, ttl="0"))


def ask(ev):
    proc.stdin.write(json.dumps(new(ev)) + "\n")
    proc.stdin.flush()
    return json.loads(proc.stdout.readline())["action"]


seen = [ask(post(NEW_A))]
with open(st, "w") as g:
    g.write(json.dumps(writer_list(OWNER_SK, [NEW_A])) + "\n")
seen.append(ask(post(NEW_A, "p2")))
open(st, "w").close()
seen.append(ask(post(NEW_A, "p3")))
proc.stdin.close()
proc.wait(timeout=15)
os.unlink(f.name)
t("live: rejected before the relay stores the list, admitted once it does, rejected once it is gone",
  seen, ["reject", "accept", "reject"])

# -- the store becomes unreadable after a key was admitted: that key is refused --
with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
    json.dump(OWNED, f)
st = store_file([writer_list(OWNER_SK, [NEW_A])])
proc = subprocess.Popen([sys.executable, os.path.join(HERE, "write-policy.py")], stdin=subprocess.PIPE,
                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
                        env=plugin_env(f.name, st, ttl="0"))
seen = [ask(post(NEW_A, "q1"))]
os.unlink(st)  # the fake scan now exits non-zero, as a failing `strfry scan` would
seen += [ask(post(NEW_A, "q2")), ask(post(FLEET, "q3"))]
with open(st, "w") as g:
    g.write(json.dumps(writer_list(OWNER_SK, [NEW_A])) + "\n")
seen.append(ask(post(NEW_A, "q4")))
proc.stdin.close()
proc.wait(timeout=15)
os.unlink(f.name)
t("live: a failed read drops all keys until a good read restores them",
  seen, ["accept", "reject", "reject", "accept"])

# -- delegated writer list: stored grant/request, deny, and durable 441 freeze --
DELEGATE_SK, RUNNER_SK = 0x55 * 23 + 9, 0x66 * 29 + 11
DELEGATE, RUNNER = pubkey(DELEGATE_SK), pubkey(RUNNER_SK)
DELEGATED = {**OWNED, "onboardRunner": RUNNER, "onboardPolicy": "v1"}
GRANT = signed(OWNER_SK, 440, [
    ["p", DELEGATE], ["da-cap", "onboard"],
    ["da-scope", wp.scope_hash(OWNER, "11" * 16), "11" * 16],
    ["policy", "v1"], ["age", "confirmed"]], NOW)


def request(target=NEW_A, consent=GRANT["id"]):
    return signed(DELEGATE_SK, 30078, [
        ["d", "nvoy-onboard/new-agent/add_agent"], ["p", target],
        ["op", "add_agent"], ["consent", consent]], NOW)


def terminal(req):
    return signed(RUNNER_SK, 30078, [
        ["d", f"nvoy-onboard:{req['id']}:terminal"], ["e", req["id"]]], NOW)


def accepted(req):
    return signed(RUNNER_SK, 30078, [
        ["d", f"nvoy-onboard:{req['id']}:accepted"], ["e", req["id"]],
        ["p", next(tag[1] for tag in req["tags"] if tag[0] == "p")],
        ["consent", next(tag[1] for tag in req["tags"] if tag[0] == "consent")]], NOW)


delegate_list = writer_list(DELEGATE_SK, [NEW_A], d="nave-relay-writers-delegate")
req = request()
base = [GRANT, req]
t("delegate cannot list a key before its live request is stored",
  run([new(delegate_list)], conf=DELEGATED, store=store_file([GRANT]))[0]["action"], "reject")
t("delegate-signed request alone cannot authorize a writer",
  run([new(delegate_list)], conf=DELEGATED, store=store_file(base))[0]["action"], "reject")
t("delegate list passes only after runner acceptance is stored",
  run([new(delegate_list)], conf=DELEGATED, store=store_file(base + [accepted(req)]))[0]["action"], "accept")
t("a forged runner acceptance has no authority",
  run([new(delegate_list)], conf=DELEGATED, store=store_file(base + [
      signed(STRANGER_SK, 30078, accepted(req)["tags"], NOW)]))[0]["action"], "reject")
t("runner acceptance for another target cannot authorize this writer",
  run([new(delegate_list)], conf=DELEGATED, store=store_file(base + [
      signed(RUNNER_SK, 30078, accepted(req)["tags"][:2] + [["p", NEW_B], ["consent", GRANT["id"]]], NOW)]))[0]["action"], "reject")
t("runner acceptance for another grant cannot authorize this writer",
  run([new(delegate_list)], conf=DELEGATED, store=store_file(base + [
      signed(RUNNER_SK, 30078, accepted(req)["tags"][:3] + [["consent", "aa" * 32]], NOW)]))[0]["action"], "reject")
t("runner acceptance with extra tags is not the exact proof",
  run([new(delegate_list)], conf=DELEGATED, store=store_file(base + [
      signed(RUNNER_SK, 30078, accepted(req)["tags"] + [["extra", "1"]], NOW)]))[0]["action"], "reject")
t("a terminal marker does not prove runner acceptance",
  run([new(delegate_list)], conf=DELEGATED, store=store_file(base + [terminal(req)]))[0]["action"], "reject")
five_targets = [f"{i:064x}" for i in range(101, 106)]
five_requests = [request(target=target) for target in five_targets]
t("five self-signed requests cannot bypass the runner's quota and template checks",
  run([new(writer_list(DELEGATE_SK, five_targets, d="nave-relay-writers-delegate"))],
      conf=DELEGATED, store=store_file([GRANT] + five_requests))[0]["action"], "reject")
t("one accepted request cannot authorize five delegate writers",
  run([new(writer_list(DELEGATE_SK, five_targets, d="nave-relay-writers-delegate"))],
      conf=DELEGATED, store=store_file([GRANT] + five_requests + [accepted(five_requests[0])]))[0]["action"], "reject")
t("a stale terms version cannot authorize a delegate addition",
  run([new(delegate_list)], conf={**DELEGATED, "onboardPolicy": "v2"},
      store=store_file(base + [accepted(req)]))[0]["action"], "reject")
t("an unset terms version cannot authorize a delegate addition",
  run([new(delegate_list)], conf={**DELEGATED, "onboardPolicy": None},
      store=store_file(base))[0]["action"], "reject")
t("the untrusted delegate cannot replace James's list",
  run([new(writer_list(DELEGATE_SK, [NEW_A]))], conf=DELEGATED, store=store_file(base))[0]["action"], "reject")
t("terminal marker closes the addition gate",
  run([new(delegate_list)], conf=DELEGATED, store=store_file(base + [accepted(req), terminal(req)]))[0]["action"], "reject")
t("a forged terminal marker has no authority",
  run([new(delegate_list)], conf=DELEGATED, store=store_file(base + [
      accepted(req), signed(STRANGER_SK, 30078, terminal(req)["tags"], NOW)]))[0]["action"], "accept")
t("a runner event with extra terminal content does not close the request",
  run([new(delegate_list)], conf=DELEGATED, store=store_file(base + [
      accepted(req), signed(RUNNER_SK, 30078, terminal(req)["tags"], NOW, "incomplete")]))[0]["action"], "accept")

stored_delegate = base + [accepted(req), delegate_list]
t("stored delegate list admits the added agent after the request completes",
  run([new(post(NEW_A))], conf=DELEGATED, store=store_file(stored_delegate + [terminal(req)]))[0]["action"], "accept")

# Terms changes and expiry end authority to add keys, not admission already
# recorded in the durable delegate list.
terms_store = store_file(stored_delegate + [terminal(req)])
t("terms bump preserves an existing delegate writer",
  run([new(post(NEW_A))], conf={**DELEGATED, "onboardPolicy": "v2"},
      store=terms_store, policy="v2")[0]["action"], "accept")
t("terms bump rejects a new delegate writer even with an accepted old request",
  run([new(writer_list(DELEGATE_SK, [NEW_A, NEW_B], NOW + 1, d="nave-relay-writers-delegate"))],
      conf={**DELEGATED, "onboardPolicy": "v2"},
      store=store_file(stored_delegate + [request(NEW_B), accepted(request(NEW_B))]),
      policy="v2")[0]["action"], "reject")
t("terms bump permits a delegate list with no additions",
  run([new(writer_list(DELEGATE_SK, [], NOW + 1, d="nave-relay-writers-delegate"))],
      conf={**DELEGATED, "onboardPolicy": "v2"}, store=terms_store, policy="v2")[0]["action"], "accept")

expired_grant = signed(OWNER_SK, 440, GRANT["tags"] + [["expiration", str(NOW - 1)]], NOW - 100)
expired_store = store_file([expired_grant, delegate_list])
t("expired grant preserves an existing delegate writer",
  run([new(post(NEW_A))], conf=DELEGATED, store=expired_store)[0]["action"], "accept")
t("expired grant rejects a new delegate writer even with an accepted request",
  run([new(writer_list(DELEGATE_SK, [NEW_A, NEW_B], NOW + 1, d="nave-relay-writers-delegate"))],
      conf=DELEGATED,
      store=store_file([expired_grant, delegate_list, request(NEW_B, expired_grant["id"]),
                        accepted(request(NEW_B, expired_grant["id"]))]))[0]["action"], "reject")
t("expired grant permits a delegate list with no additions",
  run([new(writer_list(DELEGATE_SK, [], NOW + 1, d="nave-relay-writers-delegate"))],
      conf=DELEGATED, store=expired_store)[0]["action"], "accept")

deny = writer_list(OWNER_SK, [NEW_A], d="nave-relay-writers-deny")
t("James's deny overrides the stored delegate list",
  run([new(post(NEW_A))], conf=DELEGATED, store=store_file(stored_delegate + [deny]))[0]["action"], "reject")
t("lifting the deny restores the stored delegate writer",
  run([new(post(NEW_A))], conf=DELEGATED,
      store=store_file(stored_delegate + [writer_list(OWNER_SK, [], NOW + 1, d="nave-relay-writers-deny")]))[0]["action"], "accept")
t("deny also overrides a static key",
  run([new(post(FLEET))], conf=DELEGATED,
      store=store_file(stored_delegate + [writer_list(OWNER_SK, [FLEET], d="nave-relay-writers-deny")]))[0]["action"], "reject")

with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
    json.dump(DELEGATED, f)
    snapshot_conf = f.name
snapshot_store = store_file(stored_delegate + [deny])
snapshot = subprocess.run([sys.executable, os.path.join(HERE, "write-policy.py"), "--effective-snapshot"],
                          capture_output=True, text=True, timeout=15,
                          env=plugin_env(snapshot_conf, snapshot_store))
os.unlink(snapshot_conf)
t("publisher snapshot returns the enforced set with James's deny applied",
  snapshot.returncode == 0 and NEW_A not in json.loads(snapshot.stdout)["keys"] and
  json.loads(snapshot.stdout)["deny_list"] == deny["id"], True)

revoke = signed(OWNER_SK, 441, [["e", GRANT["id"]]], NOW + 1)
freeze = os.path.join(tempfile.mkdtemp(), "freeze.json")
revoked_store = store_file(stored_delegate + [revoke])
t("the first relay-observed 441 rejects a new delegate list",
  run([new(delegate_list)], conf=DELEGATED, store=revoked_store, freeze=freeze)[0]["action"], "reject")
with open(freeze) as f:
    pinned = json.load(f)
t("the freeze pins the last stored delegate list by event ID", pinned["list_id"], delegate_list["id"])
t("a restart preserves existing delegate writers after revocation",
  run([new(post(NEW_A))], conf=DELEGATED, store=revoked_store, freeze=freeze)[0]["action"], "accept")
rotated_grant = signed(OWNER_SK, 440, [
    ["p", NEW_B], ["da-cap", "onboard"],
    ["da-scope", wp.scope_hash(OWNER, "22" * 16), "22" * 16],
    ["policy", "v1"], ["age", "confirmed"]], NOW + 2)
rotated_store = store_file(stored_delegate + [revoke, rotated_grant])
t("a revoked old grant and a live replacement do not block static writers",
  run([new(post(FLEET))], conf=DELEGATED, store=rotated_store, freeze=freeze)[0]["action"], "accept")
t("a revoked old grant and a live replacement preserve frozen writers",
  run([new(post(NEW_A))], conf=DELEGATED, store=rotated_store, freeze=freeze)[0]["action"], "accept")
t("a backdated replacement cannot change the pinned writer set",
  run([new(post(NEW_B))], conf=DELEGATED,
      store=store_file(stored_delegate + [revoke, writer_list(DELEGATE_SK, [NEW_B], NOW - 10,
                                      d="nave-relay-writers-delegate")]), freeze=freeze)[0]["action"], "reject")
with open(freeze, "w") as f:
    f.write("corrupt")
t("corrupt freeze state fails closed",
  run([new(post(NEW_A))], conf=DELEGATED, store=revoked_store, freeze=freeze)[0]["action"], "reject")
with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
    json.dump(DELEGATED, f)
    snapshot_conf = f.name
bad_snapshot = subprocess.run([sys.executable, os.path.join(HERE, "write-policy.py"), "--effective-snapshot"],
                              capture_output=True, text=True, timeout=15,
                              env=plugin_env(snapshot_conf, revoked_store, freeze=freeze))
os.unlink(snapshot_conf)
t("publisher snapshot refuses corrupt freeze state", bad_snapshot.returncode != 0, True)

print(f"\n{pass_}/{n} passed")
sys.exit(0 if pass_ == n else 1)
