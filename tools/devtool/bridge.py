"""
The development tool's line to Godot: starts tools/devtool/bridge.gd (headless Godot with the
project's autoloads) once and asks it things, one JSON line each way (BridgeCommands in
bridge_commands.gd lists the commands). Godot reads and writes every data file, so what the tool
saves is what the Godot editor would save.

    bridge = Bridge(); bridge.call("read", path="res://database/factions/verdant.tres"); bridge.close()

Values with no JSON form come as {"$": type, "text": ...} (Colors also with "v": [r, g, b, a];
resources as {"$": "Resource", "path": ...}); send them back the same way.
"""

import json
import os
import subprocess
import threading

from .tasks import GODOT, ROOT

REPLY = "@@BRIDGE "
START_TIMEOUT = 120.0  # s for Godot to start and load the project


class BridgeError(RuntimeError):
    pass


class Bridge:
    def __init__(self, godot=GODOT, root=ROOT):
        self._process = subprocess.Popen(
            [godot, "--no-window", "-s", "tools/devtool/bridge.gd"], cwd=root,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        self._lock = threading.Lock()
        self._next_id = 0
        self.log = []  # Godot's own output (warnings, errors), newest last
        ready = self._reply_for(0)
        if not ready.get("ok"):
            raise BridgeError("The bridge did not start: %s" % "\n".join(self.log[-20:]))

    def call(self, command, **args):
        """The result of `command`; raises BridgeError with Godot's message when it fails."""
        with self._lock:
            if self._process.poll() is not None:
                raise BridgeError("Godot has quit: %s" % "\n".join(self.log[-20:]))
            self._next_id += 1
            request_id = self._next_id
            self._process.stdin.write(json.dumps({"id": request_id, "cmd": command, "args": args}) + "\n")
            self._process.stdin.flush()
            reply = self._reply_for(request_id)
        if not reply.get("ok"):
            raise BridgeError(reply.get("error", "failed"))
        return reply.get("result")

    def _reply_for(self, request_id):
        while True:
            line = self._process.stdout.readline()
            if line == "":
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
