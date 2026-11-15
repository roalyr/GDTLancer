"""
The development tool's line to Godot: starts tools/devtool/bridge.gd (headless Godot with the
project's autoloads) once and asks it things, one JSON line each way (BridgeCommands in
bridge_commands.gd lists the commands). Godot reads and writes every data file, so what the tool
saves is what the Godot editor would save.

    bridge = Bridge(); bridge.call("read", path="res://database/factions/verdant.tres"); bridge.close()

Every call has a deadline (TIMEOUT, LONG_TIMEOUTS for the whole-project ones): a Godot that hangs is
killed and the call raises BridgeError, rather than the caller waiting for good. alive() says whether
Godot is still running; the menu starts a new one when it is not.

Values with no JSON form come as {"$": type, "text": ...} (Colors also with "v": [r, g, b, a];
resources as {"$": "Resource", "path": ...}); send them back the same way.
"""

import json
import os
import queue
import subprocess
import threading
import time

from .tasks import GODOT, ROOT, environment

REPLY = "@@BRIDGE "
START_TIMEOUT = 120.0  # s for Godot to start and load the project
TIMEOUT = 120.0  # s for a command's answer
LONG_TIMEOUTS = {"validate": 900.0, "models": 900.0, "economy": 600.0, "parts": 600.0, "archetypes": 600.0, "look": 600.0}


class BridgeError(RuntimeError):
    pass


class Bridge:
    def __init__(self, godot=GODOT, root=ROOT):
        self._process = subprocess.Popen(
            [godot, "--no-window", "-s", "tools/devtool/bridge.gd"], cwd=root, env=environment(),
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        self._lock = threading.Lock()
        self._next_id = 0
        self.log = []  # Godot's own output (warnings, errors), newest last
        self._lines = queue.Queue()  # Godot's output lines, read by _read (None: it ended)
        threading.Thread(target=self._read, daemon=True).start()
        ready = self._reply_for(0, START_TIMEOUT, "start")
        if not ready.get("ok"):
            raise BridgeError("The bridge did not start: %s" % "\n".join(self.log[-20:]))

    def _read(self):
        for line in self._process.stdout:
            self._lines.put(line)
        self._lines.put(None)

    def alive(self):
        return self._process.poll() is None

    def call(self, command, _timeout=None, **args):
        """The result of `command`; raises BridgeError with Godot's message when it fails, or when it
        does not answer within `_timeout` s (TIMEOUT, or the command's LONG_TIMEOUTS; Godot is then
        killed: alive() is false)."""
        with self._lock:
            if self._process.poll() is not None:
                raise BridgeError("Godot has quit: %s" % "\n".join(self.log[-20:]))
            self._next_id += 1
            request_id = self._next_id
            self._process.stdin.write(json.dumps({"id": request_id, "cmd": command, "args": args}) + "\n")
            self._process.stdin.flush()
            reply = self._reply_for(request_id, _timeout or LONG_TIMEOUTS.get(command, TIMEOUT), command)
        if not reply.get("ok"):
            raise BridgeError(reply.get("error", "failed"))
        return reply.get("result")

    def _reply_for(self, request_id, timeout, what):
        deadline = time.monotonic() + timeout
        while True:
            try:
                line = self._lines.get(timeout=max(0.0, deadline - time.monotonic()))
            except queue.Empty:
                self._process.kill()
                raise BridgeError("Godot did not answer %s in %d s and was stopped: %s"
                                  % (what, timeout, "\n".join(self.log[-5:]) or "no output"))
            if line is None:
                raise BridgeError("Godot ended: %s" % "\n".join(self.log[-20:]))
            line = line.rstrip("\n")
            if not line.startswith(REPLY):
                self.log.append(line)
                del self.log[:-500]
                continue
            reply = json.loads(line[len(REPLY):])
            if reply.get("id") in (request_id, -1):
                return reply

    def close(self):
        if self._process.poll() is None:
            try:
                self._process.stdin.write("\n")
                self._process.stdin.flush()
                self._process.wait(timeout=10)
            except (OSError, subprocess.TimeoutExpired):
                self._process.kill()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()


def res_path(path):
    """A project path as res:// (relative paths are from the project folder)."""
    if path.startswith("res://"):
        return path
    return "res://" + os.path.relpath(os.path.abspath(os.path.join(ROOT, path)), ROOT)


def file_path(res):
    """A res:// path as a path on disk."""
    return os.path.join(ROOT, res[len("res://"):]) if res.startswith("res://") else res
