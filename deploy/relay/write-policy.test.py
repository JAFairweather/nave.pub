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


def run(requests, conf=ALLOWLIST):
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(conf, f)
        path = f.name
    try:
        proc = subprocess.run(
            [sys.executable, os.path.join(HERE, "write-policy.py")],
            input="\n".join(json.dumps(r) for r in requests) + "\n",
            capture_output=True, text=True, timeout=15,
            env={**os.environ, "ALLOWLIST_PATH": path},
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

print(f"\n{pass_}/{n} passed")
sys.exit(0 if pass_ == n else 1)
