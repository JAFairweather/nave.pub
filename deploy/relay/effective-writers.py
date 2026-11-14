#!/usr/bin/env python3
"""Publish the relay's enforced writer set under its dedicated signing key.

Run once from a reviewed timer. The key remains on the host; only a signed
event crosses into strfry. A failed read, import, or post-import check exits
nonzero so the caller can alert. This command never mints a key.
"""

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
# herd-infra's reviewed provision-relay-signer installs the dedicated key here.
KEY_PATH = Path("/etc/nave-relay/relay-signer/relay-signing-key")
EFFECTIVE_D = "nave-relay-writers-effective"
KIND = 30000
LIFETIME = 180  # readers must reject a missing or expired publication
MAX_OUTPUT = 256_000

spec = importlib.util.spec_from_file_location("relay_write_policy", HERE / "write-policy.py")
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


def relay_exec(args, input_text=None):
    command = ["docker", "compose", "-f", str(HERE / "docker-compose.yml"),
               "exec", "-T", "strfry", *args]
    result = subprocess.run(command, input=input_text, text=True,
                            capture_output=True, timeout=30, cwd=HERE)
    if result.returncode:
        raise RuntimeError(f"relay command failed (exit {result.returncode}): "
                           f"{result.stderr[:1000]}")
    if len(result.stdout) > MAX_OUTPUT:
        raise RuntimeError("relay command returned too much data")
    return result.stdout


def snapshot():
    raw = relay_exec(["python3", "/app/write-policy.py", "--effective-snapshot"])
    try:
        value = json.loads(raw)
    except ValueError as exc:
        raise RuntimeError("invalid effective snapshot JSON") from exc
    fields = {"keys", "owner_list", "delegate_list", "delegate_lists",
              "deny_list", "freeze_revocation"}
    if not isinstance(value, dict) or set(value) != fields:
        raise RuntimeError("invalid effective snapshot fields")
    keys = value["keys"]
    if (not isinstance(keys, list) or len(keys) > policy.MAX_WRITERS * 3
            or any(not isinstance(key, str) or not policy.HEX64.fullmatch(key)
                   for key in keys)
            or keys != sorted(set(keys))):
        raise RuntimeError("invalid effective snapshot keys")
    for field in fields - {"keys", "delegate_lists"}:
        item = value[field]
        if item is not None and (not isinstance(item, str) or
                                 not policy.HEX64.fullmatch(item)):
            raise RuntimeError(f"invalid effective snapshot {field}")
    lists = value["delegate_lists"]
    if (not isinstance(lists, list) or
            any(not isinstance(item, str) or not policy.HEX64.fullmatch(item)
                for item in lists) or lists != sorted(set(lists))):
        raise RuntimeError("invalid effective snapshot delegate_lists")
    return value


def read_key(path=KEY_PATH):
    path = Path(path)
    directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        parent = os.fstat(directory)
        if (not stat.S_ISDIR(parent.st_mode) or parent.st_uid != os.geteuid()
                or parent.st_mode & 0o022):
            raise RuntimeError("signing key directory must be owned by this user and not writable by others")
        fd = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC,
                     dir_fd=directory)
    finally:
        os.close(directory)
    try:
        st = os.fstat(fd)
        if (not stat.S_ISREG(st.st_mode) or st.st_nlink != 1 or
                st.st_uid != os.geteuid() or st.st_mode & 0o077):
            raise RuntimeError("signing key file must be private and owned by this user")
        if st.st_size not in (64, 65):
            raise RuntimeError("signing key file has invalid format")
        raw = os.read(fd, st.st_size)
        if st.st_size == 65 and raw[-1:] != b"\n":
            raise RuntimeError("signing key file has invalid format")
        raw = raw.removesuffix(b"\n")
        if len(raw) != 64:
            raise RuntimeError("signing key file has invalid format")
        try:
            scalar = int(raw, 16)
        except ValueError as exc:
            raise RuntimeError("signing key file has invalid format") from exc
        if not 0 < scalar < policy._N:
            raise RuntimeError("signing key file has invalid scalar")
        return scalar
    finally:
        os.close(fd)


def sign_event(secret, effective, now):
    point = policy._mul(policy._G, secret)
    pubkey = point[0].to_bytes(32, "big")
    adjusted = secret if point[1] % 2 == 0 else policy._N - secret
    tags = [["d", EFFECTIVE_D], ["expiration", str(now + LIFETIME)]]
    tags += [["p", key] for key in effective["keys"]]
    content = json.dumps({key: value for key, value in effective.items() if key != "keys"},
                         sort_keys=True, separators=(",", ":"))
    event = {"pubkey": pubkey.hex(), "created_at": now, "kind": KIND,
             "tags": tags, "content": content}
    serial = json.dumps([0, event["pubkey"], now, KIND, tags, content],
                        separators=(",", ":"), ensure_ascii=False)
    event_id = hashlib.sha256(serial.encode()).digest()
    mask = int.from_bytes(policy._tagged("BIP0340/aux", os.urandom(32)), "big")
    t = (adjusted ^ mask).to_bytes(32, "big")
    nonce = int.from_bytes(policy._tagged("BIP0340/nonce", t + pubkey + event_id), "big") % policy._N
    if nonce == 0:
        raise RuntimeError("signing nonce is zero")
    nonce_point = policy._mul(policy._G, nonce)
    k = nonce if nonce_point[1] % 2 == 0 else policy._N - nonce
    rx = nonce_point[0].to_bytes(32, "big")
    challenge = int.from_bytes(policy._tagged("BIP0340/challenge", rx + pubkey + event_id), "big") % policy._N
    signature = rx + ((k + challenge * adjusted) % policy._N).to_bytes(32, "big")
    event["id"] = event_id.hex()
    event["sig"] = signature.hex()
    if not policy.event_ok(event):
        raise RuntimeError("signed event failed verification")
    return event


def stored_events(pubkey):
    flt = {"kinds": [KIND], "authors": [pubkey], "#d": [EFFECTIVE_D]}
    raw = relay_exec(["/app/strfry", "--config=/etc/strfry.conf", "scan",
                      json.dumps(flt, separators=(",", ":"))])
    events = []
    for line in raw.splitlines():
        try:
            event = json.loads(line)
        except ValueError as exc:
            raise RuntimeError("invalid relay scan JSON") from exc
        if (not isinstance(event, dict) or event.get("pubkey") != pubkey or
                event.get("kind") != KIND or not policy.event_ok(event) or
                policy.only_tag(event, "d") != EFFECTIVE_D):
            raise RuntimeError("invalid effective event in relay scan")
        events.append(event)
    return events


def publish(key_path=KEY_PATH, now=None):
    secret = read_key(key_path)
    pubkey = policy._mul(policy._G, secret)[0].to_bytes(32, "big").hex()
    before = snapshot()
    prior = policy.newest(stored_events(pubkey))
    now = int(time.time()) if now is None else now
    if prior and prior["created_at"] >= now:
        raise RuntimeError("prior effective event is not older than current UTC second")
    event = sign_event(secret, before, now)
    # Recheck immediately before writing; the final read below catches a race.
    if snapshot() != before:
        raise RuntimeError("effective snapshot changed before publication")
    relay_exec(["/app/strfry", "--config=/etc/strfry.conf", "import"],
               json.dumps(event, separators=(",", ":")) + "\n")
    after_events = stored_events(pubkey)
    if not any(item == event for item in after_events):
        raise RuntimeError("exact signed event was not stored by relay")
    if policy.newest(after_events)["id"] != event["id"]:
        raise RuntimeError("signed event is not the relay's current effective list")
    if snapshot() != before:
        raise RuntimeError("effective snapshot changed during publication")
    return {"event_id": event["id"], "pubkey": pubkey, "expires_at": now + LIFETIME}


if __name__ == "__main__":
    if sys.argv[1:] != ["--publish"]:
        sys.exit("usage: effective-writers.py --publish")
    try:
        print(json.dumps(publish(), sort_keys=True))
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        sys.exit(f"effective-writers: {exc}")
