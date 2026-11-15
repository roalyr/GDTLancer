"""The bridge's deadline: a Godot that starts and then never answers is stopped, and the call says so
(a stand-in program plays Godot; no Godot is started)."""

import os
import stat
import sys
import tempfile
import time
import unittest

from devtool import bridge

# Answers the start, then reads requests and answers none of them ("hang") or only pings ("ping").
STAND_IN = """#!%s
import json, sys
print(%r + json.dumps({"id": 0, "ok": True}), flush=True)
for line in sys.stdin:
    if not line.strip():
        break  # The bridge's goodbye, as bridge.gd takes it
    request = json.loads(line)
    if request and request["cmd"] == "ping":
        print("a warning first", flush=True)
        print(%r + json.dumps({"id": request["id"], "ok": True, "result": {"godot": "stand-in"}}), flush=True)
""" % (sys.executable, bridge.REPLY, bridge.REPLY)


class BridgeTimeoutTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.mkdtemp()
        self.godot = os.path.join(self.folder, "godot")
        with open(self.godot, "w") as handle:
            handle.write(STAND_IN)
        os.chmod(self.godot, os.stat(self.godot).st_mode | stat.S_IEXEC)

    def test_an_answer_comes_back_and_godots_own_lines_go_to_the_log(self):
        with bridge.Bridge(godot=self.godot, root=self.folder) as line:
            self.assertEqual(line.call("ping"), {"godot": "stand-in"})
            self.assertIn("a warning first", line.log)
            self.assertTrue(line.alive())

    def test_a_command_that_never_answers_is_stopped_at_its_deadline(self):
        line = bridge.Bridge(godot=self.godot, root=self.folder)
        started = time.monotonic()
        with self.assertRaises(bridge.BridgeError) as caught:
            line.call("read", _timeout=1.0, path="res://x.tres")
        self.assertLess(time.monotonic() - started, 10.0, "Not waiting for good")
        self.assertIn("did not answer read in 1 s", str(caught.exception))
        time.sleep(0.2)
        self.assertFalse(line.alive(), "Godot stopped")
        with self.assertRaises(bridge.BridgeError):
            line.call("ping")
        line.close()

    def test_long_commands_get_longer(self):
        self.assertGreater(bridge.LONG_TIMEOUTS["validate"], bridge.TIMEOUT)


if __name__ == "__main__":
    unittest.main()
