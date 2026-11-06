"""
Evolution's data (user://evolution/) as the tool sees it, and the new-era flow: what has to happen
before the rules change under evolution, in order, each step checked before the next.

    tools/dev.py new_era label=freeze next=fuel hours=20      (or the Tools tab's n key)

1. Evolution must be stopped (its status.json says "running" and its process lives: stop it first).
2. The save is copied to backups/era<N>_<label>_t<hours>h_<date>.sav and the copy compared byte
   for byte: everything after this works from that copy.
3. Preset drafts are exported from the copy, one folder per minimum of lives:
   database/presets/drafts_era<N>_min<k>/ (an earlier export of that era is replaced).
4. tools/classify_presets.gd rewrites database/presets/CATALOG.md for them.
5. The drafts and the catalog are committed (database/presets/ only, nothing else).
6. era.json records the new era (number, label, when it started, at what simulated time).
7. Evolution starts the new era (--new-era: genomes stay, their records start over; or --new: from
   scratch), detached, its console going to era<N+1>_<label>.log. The Tools tab shows it running.

The era number: era.json's, else the highest era<N> among the backups and drafts (a guess the flow
asks to confirm). Nothing is ever deleted: a backup name that exists gets a number.
"""

import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time

if __package__ in (None, ""):  # Run as a file: tools/devtool/evolution.py
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    __package__ = "devtool"

from .tasks import GODOT, ROOT  # noqa: E402

PRESETS_DIR = os.path.join(ROOT, "database", "presets")
ERA_FILE = "era.json"
ERA_NAME = re.compile(r"^(?:drafts_)?era(\d+)_")
MIN_LIVES = (10, 5)
LABEL = re.compile(r"^[a-z0-9_]+$")


def user_dir():
    """Godot's user:// for this project (Linux: ~/.local/share/godot/app_userdata/<config/name>)."""
    name = "GDTLancer"
    with open(os.path.join(ROOT, "project.godot")) as handle:
        for line in handle:
            if line.startswith("config/name="):
                name = line.split("=", 1)[1].strip().strip('"')
    data = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return os.path.join(data, "godot", "app_userdata", name)


def evolution_dir():
    return os.path.join(user_dir(), "evolution")


def read_json(path):
    try:
        with open(path) as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def alive(pid):
    try:
        os.kill(int(pid), 0)
    except (OSError, ValueError, TypeError):
        return False
    return True


def status(folder):
    """status.json of the run, with "running": its state says so and its process still lives."""
    info = read_json(os.path.join(folder, "status.json"))
    if not isinstance(info, dict):
        return None
    info["running"] = info.get("state") == "running" and alive(info.get("pid"))
    return info


def era(folder, presets_dir=PRESETS_DIR):
    """(number, label, guessed): era.json's, else the highest era<N> in the backups' and drafts' names."""
    info = read_json(os.path.join(folder, ERA_FILE))
    if isinstance(info, dict) and "era" in info:
        return int(info["era"]), str(info.get("label", "")), False
    names = [os.path.basename(p) for p in glob.glob(os.path.join(folder, "backups", "*.sav")) + glob.glob(os.path.join(presets_dir, "drafts_*"))]
    found = [(int(m.group(1)), name) for name in names for m in [ERA_NAME.match(name)] if m]
    if not found:
        return 0, "", True
    number = max(n for n, _ in found)
    labels = [m.group(1) for n, name in found if n == number for m in [re.match(r"^(?:drafts_)?era\d+_([a-z]+)", name)]
              if m and m.group(1) not in ("auto", "min")]
    return number, (labels[0] if labels else ""), True


def backup_name(number, label, game_time, today=None):
    hours = "_t%.1fh" % (game_time / 3600.0) if game_time else ""
    return "era%d_%s%s_%s.sav" % (number, label, hours, today or time.strftime("%Y%m%d"))


def free_path(path):
    """`path`, or path with _2, _3... before its extension if it exists: nothing is overwritten."""
    if not os.path.exists(path):
        return path
    stem, extension = os.path.splitext(path)
    number = 2
    while os.path.exists("%s_%d%s" % (stem, number, extension)):
        number += 1
    return "%s_%d%s" % (stem, number, extension)


def same_bytes(a, b):
    digests = []
    for path in (a, b):
        with open(path, "rb") as handle:
            digests.append(hashlib.sha256(handle.read()).hexdigest())
    return digests[0] == digests[1]


def godot_script(script, *args):
    return [GODOT, "--no-window", "-s", script] + list(args)


class Step(Exception):
    """A step failed: the flow stops there, and says what is already done."""


class NewEra:
    """The flow, step by step. `run(command)` runs a command and returns its exit code; `start(command,
    log)` starts the sim detached and returns its pid (both stand-ins in the tests)."""

    def __init__(self, folder, label, next_label, hours="20", speed="8", min_lives=MIN_LIVES, fresh=False,
                 commit=True, start=True, number=None, run=None, start_process=None, presets_dir=PRESETS_DIR, say=print):
        self.folder, self.label, self.next_label = folder, label, next_label
        self.hours, self.speed, self.min_lives, self.fresh = str(hours), str(speed), list(min_lives), fresh
        self.commit, self.start, self.number, self.presets_dir = commit, start, number, presets_dir
        self.run = run or (lambda command: subprocess.call(command, cwd=ROOT))
        self.start_process = start_process or start_detached
        self.say = say
        self.done = []

    def step(self, text):
        self.say("\n== %s" % text)

    def finish(self, text):
        self.done.append(text)
        self.say("   " + text)

    def go(self):
        try:
            return self._go()
        except Step as problem:
            self.say("\nStopped: %s" % problem)
            if self.done:
                self.say("Already done:\n" + "\n".join("  - " + text for text in self.done))
            return 1

    def _go(self):
        for name, label in (("label", self.label), ("next", self.next_label)):
            if not LABEL.match(label or ""):
                raise Step("%s %r: lower case letters, digits and _ only" % (name, label))
        save = os.path.join(self.folder, "save_0.sav")
        self.step("1. Is evolution stopped?")
        info = status(self.folder) or {}
        if info.get("running"):
            raise Step("evolution is running (pid %s): stop it first (Tools: x), wait for 'done', then run this again" % info.get("pid"))
        if not os.path.exists(save) or os.path.getsize(save) == 0:
            raise Step("no save at %s" % save)
        self.finish("stopped; the save is %d KB" % (os.path.getsize(save) // 1024))
        number, _label, guessed = era(self.folder, self.presets_dir)
        if self.number is not None:
            number = int(self.number)
        if number <= 0:
            raise Step("no era number known: give one (era=N)")
        self.say("   this era: %d%s" % (number, " (from the backups' names)" if guessed and self.number is None else ""))

        self.step("2. Back up the save")
        game_time = float(info.get("game_time") or 0.0)
        backups = os.path.join(self.folder, "backups")
        os.makedirs(backups, exist_ok=True)
        backup = free_path(os.path.join(backups, backup_name(number, self.label, game_time)))
        shutil.copyfile(save, backup)
        if not same_bytes(save, backup):
            raise Step("the copy %s differs from the save" % backup)
        self.finish("backup %s (checked byte for byte)" % os.path.relpath(backup, self.folder))

        self.step("3. Export preset drafts from the backup")
        folders = []
        for lives in self.min_lives:
            out = "res://database/presets/drafts_era%d_min%d/" % (number, lives)
            code = self.run(godot_script("tools/export_presets.gd", "--", "--save=" + backup, "--min-lives=%d" % lives,
                                         "--out=" + out, "--clean"))
            if code != 0:
                raise Step("export_presets (min %d lives) ended with %d" % (lives, code))
            drafts = glob.glob(os.path.join(self.presets_dir, "drafts_era%d_min%d" % (number, lives), "**", "*.tres"), recursive=True)
            if not drafts:
                raise Step("export_presets (min %d lives) wrote no drafts: no genome has flown that many lives?" % lives)
            folders.append(out.replace("res://", ""))
            self.finish("%d drafts in %s" % (len(drafts), out.replace("res://", "")))

        self.step("4. Rewrite the catalog")
        if self.run(godot_script("tools/classify_presets.gd")) != 0:
            raise Step("classify_presets failed")
        self.finish("database/presets/CATALOG.md rewritten")

        if self.commit:
            self.step("5. Commit the drafts and the catalog")
            self.run(["git", "add", "--", "database/presets"])
            if self.run(["git", "diff", "--cached", "--quiet", "--", "database/presets"]) == 0:
                self.finish("nothing changed in database/presets: no commit")
            else:
                message = "Era %d preset drafts (%s) and catalog" % (number, self.label)
                if self.run(["git", "commit", "-q", "-m", message, "--", "database/presets"]) != 0:
                    raise Step("git commit failed")
                self.finish("committed: " + message)
        else:
            self.say("\n== 5. (not committing: commit database/presets yourself)")

        self.step("6. Record the new era")
        new_number = number + 1
        with open(os.path.join(self.folder, ERA_FILE), "w") as handle:
            json.dump({"era": new_number, "label": self.next_label, "started": int(time.time()), "fresh": self.fresh,
                       "game_time": 0.0 if self.fresh else game_time, "after": os.path.basename(backup)}, handle, indent=1)
        self.finish("era %d (%s)" % (new_number, self.next_label))

        if not self.start:
            self.say("\n== 7. (not started: run evolution yourself with --%s)" % ("new" if self.fresh else "new-era"))
            return 0
        self.step("7. Start era %d" % new_number)
        log = free_path(os.path.join(self.folder, "era%d_%s.log" % (new_number, self.next_label)))
        command = godot_script("tools/evolution_sim.gd", "--", "--hours=" + self.hours, "--speed=" + self.speed,
                               "--new" if self.fresh else "--new-era")
        pid = self.start_process(command, log)
        self.finish("running, pid %d; its console: %s (the Tools tab shows it; x stops it)" % (pid, os.path.basename(log)))
        return 0


def start_detached(command, log):
    """Starts `command` in its own session (it outlives the tool and the terminal), output to `log`."""
    handle = open(log, "a")
    process = subprocess.Popen(command, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, start_new_session=True)
    return process.pid


def main(argv):
    values = dict(arg.split("=", 1) for arg in argv if "=" in arg)
    yes = lambda key, default: str(values.get(key, default)).lower() in ("yes", "y", "true", "1")
    flow = NewEra(evolution_dir(), values.get("label", ""), values.get("next", ""), values.get("hours", "20"), values.get("speed", "8"),
                  [int(n) for n in values.get("min_lives", "10,5").split(",") if n.strip()], fresh=values.get("kind") == "fresh",
                  commit=yes("commit", "yes"), start=yes("start", "yes"), number=values.get("era") or None)
    return flow.go()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
