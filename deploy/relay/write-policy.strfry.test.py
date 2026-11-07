#!/usr/bin/env python3
# Live tests for the owner's writer list (nave.pub#157) against the real relay image: build it,
# run strfry with write-policy.py, and talk to it over a websocket as a client would. Each case
# checks the relay's own answer to a writer list, then whether that list's key may write.
#
#   python3 write-policy.strfry.test.py      (needs docker; about half a minute)
#
# Throwaway keys only. The container and image are removed at the end.
import base64
import hashlib
import importlib.util
import json
import os
import socket
import struct
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
IMAGE, NAME = "nave-relay-policytest", f"nave-relay-policytest-{os.getpid()}"

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
    t = (d ^ int.from_bytes(wp._tagged("BIP0340/aux", os.urandom(32)), "big")).to_bytes(32, "big")
    k0 = int.from_bytes(wp._tagged("BIP0340/nonce", t + px + msg), "big") % wp._N
    R = wp._mul(wp._G, k0)
    k = k0 if R[1] % 2 == 0 else wp._N - k0
    e = int.from_bytes(wp._tagged("BIP0340/challenge", R[0].to_bytes(32, "big") + px + msg), "big") % wp._N
    return R[0].to_bytes(32, "big") + ((k + e * d) % wp._N).to_bytes(32, "big")


def signed(sk, kind, tags, created_at=None, content=""):
    created_at = int(time.time()) if created_at is None else created_at
    ev = {"pubkey": pubkey(sk), "created_at": created_at, "kind": kind, "tags": tags, "content": content}
    ser = json.dumps([0, ev["pubkey"], created_at, kind, tags, content], separators=(",", ":"), ensure_ascii=False)
    ev["id"] = hashlib.sha256(ser.encode()).hexdigest()
    ev["sig"] = schnorr_sign(bytes.fromhex(ev["id"]), sk).hex()
    return ev


def rand_sk():
    return int.from_bytes(os.urandom(32), "big") % (wp._N - 1) + 1


OWNER_SK, W1_SK, W2_SK = rand_sk(), rand_sk(), rand_sk()
W1, W2 = pubkey(W1_SK), pubkey(W2_SK)


def writer_list(keys, created_at, tags=()):
    return signed(OWNER_SK, 30000, [["d", "nave-relay-writers"]] + [["p", k] for k in keys] + list(tags), created_at)


# --- a minimal websocket client (RFC 6455, text frames only) ---
class WS:
    def __init__(self, port):
        self.s = socket.create_connection(("127.0.0.1", port), timeout=10)
        key = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall((f"GET / HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                        f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
        head = b""
        while b"\r\n\r\n" not in head:
            chunk = self.s.recv(1)
            if not chunk:
                raise ConnectionError("relay closed during the handshake")
            head += chunk
        if b" 101 " not in head.split(b"\r\n")[0]:
            raise ConnectionError(head.split(b"\r\n")[0].decode())

    def _read(self, n):
        buf = b""
        while len(buf) < n:
            chunk = self.s.recv(n - len(buf))
            if not chunk:
                raise ConnectionError("relay closed the connection")
            buf += chunk
        return buf

    def send(self, obj):
        data, mask = json.dumps(obj).encode(), os.urandom(4)
        n = len(data)
        head = bytes([0x81]) + (bytes([0x80 | n]) if n < 126 else
                                bytes([0x80 | 126]) + struct.pack(">H", n) if n < 65536 else
                                bytes([0x80 | 127]) + struct.pack(">Q", n))
        self.s.sendall(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

    def recv(self):
        while True:
            b0, b1 = self._read(2)
            n = b1 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self._read(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self._read(8))[0]
            payload = self._read(n)
            if b0 & 0x0F == 0x1:
                return json.loads(payload)

    def publish(self, ev):
        # The relay's answer: (accepted, message).
        self.send(["EVENT", ev])
        while True:
            msg = self.recv()
            if msg[0] == "OK" and msg[1] == ev["id"]:
                return msg[2], msg[3]


def docker(*args, check=True):
    return subprocess.run(["docker", *args], capture_output=True, text=True, check=check).stdout.strip()


def port():
    return int(docker("port", NAME, "7777/tcp").splitlines()[0].rsplit(":", 1)[1])


def connect():
    for _ in range(50):
        try:
            return WS(port())
        except (OSError, ConnectionError, IndexError, subprocess.CalledProcessError):
            time.sleep(0.2)
    raise SystemExit("the test relay never came up:\n" + docker("logs", "--tail", "20", NAME, check=False))


n = pass_ = 0
def t(name, got, want):
    global n, pass_
    n += 1
    if got == want:
        pass_ += 1
        print(f"ok - {name}")
    else:
        print(f"FAIL - {name}\n   got {got!r}, want {want!r}")


SEQ = [0]
def may_write(ws, sk, settle=2.5):
    # Whether the relay takes a fresh post by this key, after the policy's re-read interval.
    time.sleep(settle)
    SEQ[0] += 1
    return ws.publish(signed(sk, 1, [], content=f"post {SEQ[0]}"))[0]


def main():
    subprocess.run(["docker", "build", "-q", "-t", IMAGE, HERE], check=True, stdout=subprocess.DEVNULL)
    conf = json.load(open(os.path.join(HERE, "allowlist.json")))
    # As on the live relay, the owner is also a static writer, so its deletions are stored.
    conf["allow"] = {**conf["allow"], "test_owner": pubkey(OWNER_SK)}
    conf["owners"] = {"test_owner": pubkey(OWNER_SK)}
    tmp = tempfile.mkdtemp()
    with open(os.path.join(tmp, "allowlist.json"), "w") as f:
        json.dump(conf, f)
    docker("create", "--name", NAME, "-p", "127.0.0.1::7777", "-v", "/app/strfry-db", IMAGE,
           "/app/strfry", "--config=/etc/strfry.conf", "relay")
    docker("cp", os.path.join(tmp, "allowlist.json"), f"{NAME}:/app/allowlist.json")
    docker("cp", os.path.join(HERE, "strfry.conf"), f"{NAME}:/etc/strfry.conf")
    docker("start", NAME)
    ws = connect()
    t0 = int(time.time())

    t("control: a key on no list may not write", may_write(ws, W1_SK, 0), False)

    ok, _ = ws.publish(writer_list([W1], t0))
    t("the relay stores a sound owner list", ok, True)
    t("  ...and its key may then write, with no restart", may_write(ws, W1_SK), True)

    ok, msg = ws.publish(writer_list([W2], t0 - 10))
    t("the relay refuses an older list", (ok, msg.split(":")[0]), (False, "replaced"))
    t("  ...whose key still may not write", may_write(ws, W2_SK), False)
    t("  ...and the stored list still holds", may_write(ws, W1_SK, 0), True)

    ok, msg = ws.publish(writer_list([W2], t0 + 1, [["expiration", str(t0 - 5)]]))
    t("the relay refuses an already expired list", ok, False)
    t("  ...whose key may not write", may_write(ws, W2_SK), False)

    soon = int(time.time()) + 6
    ok, _ = ws.publish(writer_list([W2], t0 + 2, [["expiration", str(soon)]]))
    t("the relay stores a list that expires shortly", ok, True)
    t("  ...its key may write until then", may_write(ws, W2_SK), True)
    t("  ...and it replaced the earlier list", may_write(ws, W1_SK, 0), False)
    time.sleep(max(0, soon - time.time()))
    t("  ...once it expires, its key may not write", may_write(ws, W2_SK), False)

    current = writer_list([W1], t0 + 3)
    t("the relay stores a newer list", ws.publish(current)[0], True)
    t("  ...its key may write", may_write(ws, W1_SK), True)
    ok, _ = ws.publish(signed(OWNER_SK, 5, [["e", current["id"]], ["k", "30000"]]))
    t("the owner deletes it (kind 5)", ok, True)
    t("  ...and its key may no longer write", may_write(ws, W1_SK), False)
    ok, _ = ws.publish(current)
    t("the relay refuses the deleted list sent again", ok, False)
    t("  ...whose key still may not write", may_write(ws, W1_SK), False)

    t("the relay stores a fresh list", ws.publish(writer_list([W1], t0 + 4))[0], True)
    t("  ...its key may write", may_write(ws, W1_SK), True)
    ws.s.close()
    docker("restart", NAME)
    ws = connect()
    t("after a relay restart, that key still may write", may_write(ws, W1_SK, 0.5), True)
    t("  ...and a key on no list still may not", may_write(ws, W2_SK, 0), False)
    ws.s.close()


try:
    main()
finally:
    docker("rm", "-f", "-v", NAME, check=False)
    docker("rmi", IMAGE, check=False)

print(f"\n{pass_}/{n} passed")
sys.exit(0 if pass_ == n else 1)
