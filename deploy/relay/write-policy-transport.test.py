#!/usr/bin/env python3
# Offline tests for write-policy-transport.py — same harness style as
# write-policy.test.py: drive the plugin exactly as strfry does, one JSON
# request per line on stdin, one decision per line on stdout. No relay, no
# network.
#
#   python3 write-policy-transport.test.py
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ALICE = "aa" * 32
BOB = "bb" * 32


def run(requests, env_extra=None):
    proc = subprocess.run(
        [sys.executable, os.path.join(HERE, "write-policy-transport.py")],
        input="\n".join(json.dumps(r) for r in requests) + "\n",
        capture_output=True, text=True, timeout=15,
        env={**os.environ, **(env_extra or {})},
    )
    assert proc.returncode == 0, proc.stderr
    return [json.loads(l) for l in proc.stdout.strip().splitlines() if l.strip()]


def new(ev):
    return {"type": "new", "event": ev, "sourceType": "IP4", "sourceInfo": "127.0.0.1"}


def transport_ev(id_, pubkey=ALICE, kind=24133):
    return {"id": id_, "pubkey": pubkey, "kind": kind, "tags": [], "content": "encrypted-payload"}


n = pass_ = 0
def t(name, got, want):
    global n, pass_
    n += 1
    if got == want:
        pass_ += 1
        print(f"ok - {name}")
    else:
        print(f"FAIL - {name}\n   got {got!r}, want {want!r}")


out = run([new(transport_ev("t1"))])
t("kind 24133 accepted from any pubkey (no allow-list)", out[0]["action"], "accept")

out = run([new(transport_ev("t2", pubkey=BOB))])
t("kind 24133 accepted from a second, unrelated pubkey", out[0]["action"], "accept")

out = run([new(transport_ev("t3", kind=1))])
t("kind 1 rejected — this relay carries only transport traffic", out[0]["action"], "reject")

out = run([new(transport_ev("t4", kind=1059))])
t("kind 1059 (gift wrap) rejected — grant plane does not ride this relay", out[0]["action"], "reject")

out = run([new(transport_ev("t5", kind=0))])
t("kind 0 (profile) rejected", out[0]["action"], "reject")

# ---- rate limiting ---------------------------------------------------------
env = {"TRANSPORT_RATE_LIMIT_COUNT": "3", "TRANSPORT_RATE_LIMIT_WINDOW_S": "60"}
reqs = [new(transport_ev(f"r{i}")) for i in range(5)]
out = run(reqs, env_extra=env)
t("rate limit: first N (=count) accepted, rest rejected",
  [o["action"] for o in out], ["accept", "accept", "accept", "reject", "reject"])
t("rate limit: rejection message names the limit", "rate limit exceeded" in out[3]["msg"], True)

out = run([new(transport_ev("r0")), new(transport_ev("r1", pubkey=BOB)),
           new(transport_ev("r2")), new(transport_ev("r3", pubkey=BOB))],
          env_extra={"TRANSPORT_RATE_LIMIT_COUNT": "1", "TRANSPORT_RATE_LIMIT_WINDOW_S": "60"})
t("rate limit is per-author — ALICE's 2nd is rejected, BOB's 1st still accepted",
  [o["action"] for o in out], ["accept", "accept", "reject", "reject"])

out = run([
    {"type": "lookback", "event": {"id": "ig", "pubkey": ALICE, "kind": 1}},
    new(transport_ev("t6")),
])
t("non-'new' requests are ignored; stream continues", [o["id"] for o in out], ["t6"])

print(f"\n{pass_}/{n} passed")
sys.exit(0 if pass_ == n else 1)
