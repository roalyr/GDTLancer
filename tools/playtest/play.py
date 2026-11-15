#!/usr/bin/env python3
"""Drive the real game as a player would, one command per call (for agent playtests).

    tools/playtest/play.py [--slot S] start [--keep] [--window]   launch a fresh game, wait for the menu
    tools/playtest/play.py [--slot S] look [--shot]       buttons (id, text, centre) and text on screen
    tools/playtest/play.py [--slot S] click <id>|--text T|--at X Y [--double]
    tools/playtest/play.py [--slot S] drag X1 Y1 X2 Y2    turn the camera, move a slider
    tools/playtest/play.py [--slot S] key <action> [secs] hold a keyboard action (see: actions)
    tools/playtest/play.py [--slot S] wait <seconds>      let the game run (real time)
    tools/playtest/play.py [--slot S] state               what the game knows: sector, dock, bank, hull, speed
    tools/playtest/play.py [--slot S] shot [name]         screenshot to .playtest/<slot>/<name>.png (Read it)
    tools/playtest/play.py [--slot S] errors              every Godot error so far
    tools/playtest/play.py [--slot S] stop
    tools/playtest/play.py slots                          every slot, and which are running
    tools/playtest/play.py push                           the project and Godot to the island hosts
    tools/playtest/play.py stop-all

Slots are the evolution islands' machines (.dev/islands.json, docs/ISLANDS.md): l1..lN here (N = its
"local", at least 1) and <host's last number>-1.. on each host (e.g. 104-1, 104-2), one per island.
The default slot is l1. A host's slots run this same script there over SSH, in the copy `push` sends
(the islands' own push); their shots are copied back here, so the paths printed are local. Push after
changing the game, before starting remote slots.

Every reply ends with the Godot errors and warnings printed since the last command, so a click that
breaks a script shows at once. Each slot's run lives in .playtest/<slot>/ (git-ignored): log, shots.
Each slot saves in its own user://playtest_saves/<slot>/, emptied by start (unless --keep); the
player's saves and options are never touched.
"""
import json
import os
import shlex
import signal
import socket
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools"))
BASE_PORT = 47321
GODOT = os.environ.get("GODOT", "godot")
HERE = os.environ.get("PLAYTEST_HERE") == "1"  # Set when a host runs this for the master: never forward again
ERROR_MARKS = ("ERROR", "SCRIPT ERROR", "WARNING", "Invalid call", "Invalid get", "Invalid set", "Assertion failed", "Parse Error")
NOISE = ("[Physics interpolation]", "audio_driver_alsa", "All audio drivers failed")  # Godot's own "possibly benign" warnings: not findings


def islands():
    from devtool import islands as isl
    return isl


def slot_table():
    """{name: (dest or None, port)}: l1..lN here, <last number>-k on each island host."""
    config = islands().load_config()
    table = {}
    for k in range(1, max(1, int(config.get("local", 0))) + 1):
        table["l%d" % k] = (None, BASE_PORT + k - 1)
    for host in config.get("hosts", []):
        dest = "%s@%s" % (host["user"], host["host"]) if host.get("user") else host["host"]
        short = host["host"].split(".")[-1]
        for k in range(1, int(host.get("islands", 1)) + 1):
            table["%s-%d" % (short, k)] = (dest, BASE_PORT + k - 1)
    return table


class Slot:
    def __init__(self, name, port):
        self.name, self.port = name, port
        self.run = os.path.join(ROOT, ".playtest", name)
        self.log = os.path.join(self.run, "godot.log")
        self.pid = os.path.join(self.run, "godot.pid")
        self.offset = os.path.join(self.run, "log.offset")

    def request(self, cmd, args=None, timeout=360):
        with socket.create_connection(("127.0.0.1", self.port), timeout=timeout) as s:
            s.sendall((json.dumps({"cmd": cmd, "args": args or {}}) + "\n").encode())
            data = b""
            while not data.endswith(b"\n"):
                chunk = s.recv(65536)
                if not chunk:
                    break
                data += chunk
        return json.loads(data.decode())

    def running(self):
        if not os.path.exists(self.pid):
            return False
        try:
            os.kill(int(open(self.pid).read()), 0)
            return True
        except (OSError, ValueError):
            return False

    def new_log_lines(self, all_lines=False):
        if not os.path.exists(self.log):
            return []
        start = 0
        if not all_lines and os.path.exists(self.offset):
            start = int(open(self.offset).read() or 0)
        with open(self.log, "rb") as f:
            f.seek(start)
            text = f.read().decode(errors="replace")
            end = f.tell()
        if not all_lines:
            open(self.offset, "w").write(str(end))
        lines = text.splitlines()
        out = []
        for i, line in enumerate(lines):
            following = lines[i + 1] if i + 1 < len(lines) and lines[i + 1].strip().startswith("at:") else ""
            if any(m in line for m in ERROR_MARKS) and not any(n in line or n in following for n in NOISE):
                out.append(line)
                if i + 1 < len(lines) and lines[i + 1].strip().startswith("at:"):
                    out.append(lines[i + 1])
        return out

    def report_errors(self):
        lines = self.new_log_lines()
        if lines:
            print("--- new Godot errors/warnings ---")
            print("\n".join(lines[:60]))
            if len(lines) > 60:
                print("... %d more (play.py errors)" % (len(lines) - 60))

    def start(self, keep=False, window=False):
        if self.running():
            print("Slot %s already running (stop it first)" % self.name)
            return 1
        os.makedirs(self.run, exist_ok=True)
        env = dict(os.environ)
        env.setdefault("DISPLAY", ":0")
        argv = [GODOT, "--resolution", "1920x1080", "res://tools/playtest/play_server.tscn", "test_start=start_default",
                "port=%d" % self.port, "slot=%s" % self.name] + ([] if keep else ["fresh"])
        if not window:
            argv.insert(1, "--no-window")
        proc = subprocess.Popen(argv, cwd=ROOT, env=env, stdout=open(self.log, "w"), stderr=subprocess.STDOUT,
                                stdin=subprocess.DEVNULL, start_new_session=True)
        open(self.pid, "w").write(str(proc.pid))
        open(self.offset, "w").write("0")
        for _ in range(180):
            time.sleep(1)
            if proc.poll() is not None:
                print("Godot exited (%s); log tail:" % proc.returncode)
                print("\n".join(open(self.log).read().splitlines()[-30:]))
                return 1
            try:
                if self.request("ping", timeout=2).get("ok"):
                    print("Slot %s running (pid %d). Main menu up; next: look" % (self.name, proc.pid))
                    self.report_errors()
                    return 0
            except OSError:
                pass
        print("No answer in 180 s; see .playtest/%s/godot.log" % self.name)
        return 1

    def stop(self):
        if not self.running():
            print("Slot %s not running" % self.name)
            return 0
        pid = int(open(self.pid).read())
        try:
            self.request("quit", timeout=3)
            time.sleep(2)
        except OSError:
            pass
        if self.running():
            os.killpg(pid, signal.SIGTERM)
        os.remove(self.pid)
        print("Slot %s stopped" % self.name)
        self.report_errors()
        return 0


def show_look(result):
    if result.get("modal"):
        print("MODAL:", ", ".join(result["modal"]))
    print("BUTTONS (id text @x,y):")
    for b in result["buttons"]:
        flags = [f for f in ("disabled", "world", "selected") if b.get(f)]
        if "on" in b:
            flags.append("on" if b["on"] else "off")
        print("  #%d %s @%d,%d%s" % (b["id"], b["text"], b["at"][0], b["at"][1], (" [" + ",".join(flags) + "]") if flags else ""))
    print("TEXT:")
    for t in result["texts"]:
        print("  " + t)
    if result.get("shot"):
        print("SHOT:", result["shot"])


def command(slot, cmd, rest):
    """One game command on a slot of this machine."""
    if cmd == "start":
        return slot.start("--keep" in rest, "--window" in rest)
    if cmd == "stop":
        return slot.stop()
    if cmd == "errors":
        print("\n".join(slot.new_log_lines(all_lines=True)) or "No errors")
        return 0
    if not slot.running():
        print("Slot %s is not running: play.py --slot %s start" % (slot.name, slot.name))
        return 1
    args = {}
    if cmd == "look":
        if "--shot" in rest:
            os.makedirs(slot.run, exist_ok=True)
            args = {"shot": True, "path": os.path.join(slot.run, "look.png")}
    elif cmd == "shot":
        args = {"path": os.path.join(slot.run, (rest[0] if rest else "shot") + ".png")}
    elif cmd == "click":
        if "--text" in rest:
            args = {"text": " ".join(r for r in rest[rest.index("--text") + 1:] if r != "--double")}
        elif "--at" in rest:
            i = rest.index("--at")
            args = {"x": float(rest[i + 1]), "y": float(rest[i + 2])}
        elif rest and rest[0].lstrip("-").isdigit():
            args = {"id": int(rest[0])}
        if "--double" in rest:
            args["count"] = 2
    elif cmd == "drag":
        x1, y1, x2, y2 = (float(v) for v in rest[:4])
        args = {"x1": x1, "y1": y1, "x2": x2, "y2": y2}
    elif cmd == "key":
        args = {"action": rest[0], "seconds": float(rest[1]) if len(rest) > 1 else 0.1}
    elif cmd == "wait":
        args = {"seconds": float(rest[0]) if rest else 1.0}
    try:
        reply = slot.request(cmd, args)
    except OSError as e:
        print("No answer from the game (%s). Crashed? See play.py errors / .playtest/%s/godot.log" % (e, slot.name))
        slot.report_errors()
        return 1
    if not reply.get("ok"):
        print("ERROR:", reply.get("error"))
    elif cmd == "look":
        show_look(reply["result"])
    else:
        r = reply["result"]
        print(json.dumps(r, indent=None if not isinstance(r, dict) else 1))
    if reply.get("events"):
        print("--- events since the last command (game time) ---")
        print("\n".join(reply["events"]))
    slot.report_errors()
    return 0 if reply.get("ok") else 1


def forward(dest, name, cmd, rest):
    """The command on its host (its copy of this script), then any shot copied back here."""
    isl = islands()
    remote = "~/%s" % isl.REMOTE
    line = "cd %s/project && PLAYTEST_HERE=1 GODOT=%s/godot DISPLAY=:0 XAUTHORITY=$HOME/.Xauthority python3 tools/playtest/play.py --slot %s %s" % (
        remote, remote, shlex.quote(name), " ".join(shlex.quote(a) for a in [cmd] + rest))
    code, out = isl.ssh(dest, line, timeout=420)
    local_run = os.path.join(ROOT, ".playtest", name)
    for text_line in out.splitlines():
        if text_line.startswith("SHOT:") or (cmd == "shot" and text_line.strip().strip('"').endswith(".png")):
            path = text_line.split("SHOT:")[-1].strip().strip('"')
            os.makedirs(local_run, exist_ok=True)
            here = os.path.join(local_run, os.path.basename(path))
            isl.run(["rsync", "-az", "-e", isl.rsh(dest), "%s:%s" % (dest, path), here], timeout=120)
            out = out.replace(path, here)
    print(out.rstrip())
    return code


def main(argv):
    name = "l1"
    if "--slot" in argv:
        i = argv.index("--slot")
        name = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0
    cmd, rest = argv[0], argv[1:]
    if HERE:  # On a host, for the master: the slot is this machine's, on the port its number gives
        return command(Slot(name, BASE_PORT + int(name.rsplit("-", 1)[-1]) - 1), cmd, rest)
    table = slot_table()
    if cmd == "push":
        reached = islands().push(islands().load_config())
        return 0 if reached else 1
    if cmd == "slots":
        for slot_name, (dest, port) in table.items():
            if dest is None:
                state = "running" if Slot(slot_name, port).running() else "free"
            else:
                code, out = islands().ssh(dest, "cd ~/%s/project 2>/dev/null && test -f .playtest/%s/godot.pid && kill -0 $(cat .playtest/%s/godot.pid) 2>/dev/null && echo running || echo free" % (
                    islands().REMOTE, slot_name, slot_name), timeout=20)
                state = out.strip() if code == 0 else "unreachable"
            print("%-8s %-24s %s" % (slot_name, dest or "here", state))
        return 0
    if cmd == "stop-all":
        for slot_name, (dest, port) in table.items():
            if dest is None:
                Slot(slot_name, port).stop()
            else:
                forward(dest, slot_name, "stop", [])
        return 0
    if name not in table:
        print("No slot %s; slots: %s" % (name, ", ".join(table)))
        return 1
    dest, port = table[name]
    if dest is not None:
        return forward(dest, name, cmd, rest)
    return command(Slot(name, port), cmd, rest)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
