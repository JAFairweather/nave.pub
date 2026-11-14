#!/usr/bin/env python3
"""Offline tests for the effective-writer publisher; no key or relay required."""

import importlib.util
import json
from pathlib import Path
import tempfile

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("effective_writers", HERE / "effective-writers.py")
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)

NOW = 1794646000
SK = 0x12345
KEY = "ab" * 32
BASE = {
    "keys": [KEY],
    "owner_list": "11" * 32,
    "delegate_list": None,
    "delegate_lists": [],
    "deny_list": None,
    "freeze_revocation": None,
}


class FakeRelay:
    def __init__(self):
        self.source = dict(BASE)
        self.events = []
        self.store_import = True
        self.change_after_import = False

    def run(self, args, input_text=None):
        if args == ["python3", "/app/write-policy.py", "--effective-snapshot"]:
            return json.dumps(self.source)
        if args[2] == "scan":
            return "".join(json.dumps(event) + "\n" for event in self.events)
        if args[2] == "import":
            if self.change_after_import:
                self.source = {**self.source, "deny_list": "22" * 32}
            if self.store_import:
                self.events = [json.loads(input_text)]
            return ""
        raise AssertionError(args)


def check(name, condition):
    if not condition:
        raise AssertionError(name)
    print("ok -", name)


with tempfile.TemporaryDirectory() as directory:
    key_path = Path(directory) / "key"
    key_path.write_text(f"{SK:064x}\n")
    key_path.chmod(0o600)
    check("key reads from private regular file", publisher.read_key(key_path) == SK)
    key_path.chmod(0o644)
    try:
        publisher.read_key(key_path)
    except RuntimeError:
        pass
    else:
        raise AssertionError("world-readable key accepted")
    print("ok - world-readable key refused")
    key_path.chmod(0o600)
    alias = Path(directory) / "alias"
    alias.symlink_to(key_path)
    try:
        publisher.read_key(alias)
    except OSError:
        pass
    else:
        raise AssertionError("symlink key accepted")
    print("ok - symlink key refused")

    event = publisher.sign_event(SK, BASE, NOW)
    check("event ID and BIP340 signature verify", publisher.policy.event_ok(event))
    check("complete sorted writer set and fixed address",
          event["tags"] == [["d", publisher.EFFECTIVE_D],
                            ["expiration", str(NOW + publisher.LIFETIME)],
                            ["p", KEY]])
    check("source IDs are in event content", json.loads(event["content"])["owner_list"] == "11" * 32)

    relay = FakeRelay()
    publisher.relay_exec = relay.run
    result = publisher.publish(key_path, NOW)
    check("exact event stored and returned", result["event_id"] == relay.events[0]["id"])
    check("key file never enters relay event", f"{SK:064x}" not in json.dumps(relay.events[0]))

    try:
        publisher.publish(key_path, NOW)
    except RuntimeError as exc:
        check("same-second replacement refused", "not older" in str(exc))
    else:
        raise AssertionError("same-second replacement accepted")

    relay = FakeRelay()
    relay.store_import = False
    publisher.relay_exec = relay.run
    try:
        publisher.publish(key_path, NOW)
    except RuntimeError as exc:
        check("non-stored import refused", "not stored" in str(exc))
    else:
        raise AssertionError("non-stored import reported success")

    relay = FakeRelay()
    relay.change_after_import = True
    publisher.relay_exec = relay.run
    try:
        publisher.publish(key_path, NOW)
    except RuntimeError as exc:
        check("changed source after import refused", "changed during" in str(exc))
    else:
        raise AssertionError("changed source reported success")

    relay = FakeRelay()
    relay.source = {**BASE, "keys": ["not-a-key"]}
    publisher.relay_exec = relay.run
    try:
        publisher.publish(key_path, NOW)
    except RuntimeError as exc:
        check("malformed snapshot refused", "invalid effective snapshot keys" in str(exc))
    else:
        raise AssertionError("malformed snapshot accepted")

print("effective-writers tests passed")
