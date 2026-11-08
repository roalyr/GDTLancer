"""
Evolution on several processes and machines at once: islands. Each segment, every island flies the
same save (the master's user://evolution/save_0.sav) for the same simulated hours, each with its own
random seed; then their saves are merged into one (tools/merge_islands.gd, IslandMerge: genome
records add up, each niche keeps the fittest), their life logs appended to the era's log, the merged
save backed up, and the next segment starts from it. A Godot process steps the whole simulation on
one core, so islands are how evolution uses more than one.

    python3 tools/devtool/islands.py check            hosts reachable, their cores, what is there
    python3 tools/devtool/islands.py push             Godot and the project to every host
    python3 tools/devtool/islands.py segment          one segment (push first, then run, merge)
    python3 tools/devtool/islands.py run 6            six segments, one after another
    python3 tools/devtool/islands.py stop             every island saves and ends; the run stops after the merge
    python3 tools/devtool/islands.py usb-kit DIR      a worker setup kit for a USB stick (MX live sessions)

Configuration: .dev/islands.json (this machine's, not committed):
    {"local": 2,                       islands on this machine
     "hosts": [{"host": "laptop2.local", "user": "me", "islands": 2}],
     "hours": 1.2, "speed": 8,          per segment (simulated hours), reread before every segment
     "battery_hours": 0.4,              per segment while this machine's charger is off (a blackout)
     "godot": "<this machine's Godot 3.6.2, the x11 build>"}   (default: godot on the PATH)
Godot runs with --no-window but still needs an X display: on a host, the desktop of its logged-in user
(DISPLAY=:0, the user the islands log in as). The headless server build is no use here: its dummy
renderer crashes (a segfault some 100 s into a run, after texture_set_flags errors).
Every host gets ~/gdtl-island/: that Godot binary, the project (without .git) and islands/islandK/,
each island's save folder; it needs nothing but an SSH server and this machine's key (docs/ISLANDS.md).
Hosts run the exact files sent: no git, no editor, no import there (the .import cache goes with them).

A host that cannot be reached, or an island that does not finish, is left out of that segment's
merge: a blackout on one machine loses that island's segment, nothing else. While a segment runs,
evolution's status.json says "running" (this process), so the new-era flow waits; the overlay's
STOP (evolution/stop) ends the run after the segment, as the stop command does.
"""

import glob
import json
import os
import shlex
import shutil
import subprocess
import sys
import time

if __package__ in (None, ""):  # Run as a file: tools/devtool/islands.py
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    __package__ = "devtool"

from .tasks import DEV_DIR, ROOT  # noqa: E402
from . import evolution  # noqa: E402

CONFIG = os.environ.get("ISLANDS_CONFIG") or os.path.join(DEV_DIR, "islands.json")
REMOTE = "gdtl-island"  # Folder under the host's home
RSYNC_EXCLUDES = [".git", ".dev", "GDTLancer-legacy", "__pycache__", "*.apk", "*.idsig", "tools/renders"]
POLL = 20  # s between looks at the islands
STALE = 600  # s without a status update after which an island counts as lost
BACKUPS_KEPT = 3
SSH = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", "-o", "ServerAliveInterval=15", "-o", "StrictHostKeyChecking=accept-new"]
LIVE_SSH = ["-o", "UserKnownHostsFile=/dev/null", "-o", "StrictHostKeyChecking=no", "-o", "LogLevel=ERROR"]
LIVE_DESTS = set()  # Hosts marked "live": their host keys change every boot (a live session that could not keep them)
KIT_PACKAGES = ["openssh-server", "openssh-sftp-server", "openssh-client", "runit-helper", "ucf", "libwrap0"]


def say(text):
    print("[islands %s] %s" % (time.strftime("%H:%M:%S"), text), flush=True)


def load_config(path=CONFIG):
    config = {"local": 2, "hosts": [], "hours": 1.2, "speed": 8,
              "godot": os.path.realpath(shutil.which("godot") or "godot")}  # The binary itself, not a link (it is copied to hosts)
    if os.path.exists(path):
        with open(path) as handle:
            config.update(json.load(handle))
    return config


def usb_kit(folder):
    """The worker kit for a USB stick: the setup script, this machine's public key, and the SSH server's
    packages (apt-get download: no root) for a live session without internet."""
    os.makedirs(os.path.join(folder, "debs"), exist_ok=True)
    os.makedirs(os.path.join(folder, "workers"), exist_ok=True)
    shutil.copyfile(os.path.join(ROOT, "tools", "islands_worker_setup.sh"), os.path.join(folder, "islands_worker_setup.sh"))
    key = next((k for k in (os.path.expanduser("~/.ssh/id_ed25519.pub"), os.path.expanduser("~/.ssh/id_rsa.pub")) if os.path.exists(k)), None)
    if key is None:
        say("no public key in ~/.ssh: make one first (ssh-keygen -t ed25519)")
        return False
    shutil.copyfile(key, os.path.join(folder, "master_key.pub"))
    done = subprocess.run(["apt-get", "download"] + KIT_PACKAGES, cwd=os.path.join(folder, "debs"), capture_output=True, text=True)
    debs = sorted(os.listdir(os.path.join(folder, "debs")))
    say("kit in %s: islands_worker_setup.sh, master_key.pub (%s), %d packages%s" % (
        folder, os.path.basename(key), len(debs), "" if done.returncode == 0 else " (apt-get download failed: %s)" % done.stderr.strip()[-200:]))
    for name in debs:
        say("  debs/" + name)
    return done.returncode == 0


def islands_of(config):
    """[{"k", "host" (None: here), "user"}], numbered from 1: this machine's first."""
    out = [{"k": k, "host": None, "user": None} for k in range(1, int(config.get("local", 0)) + 1)]
    for host in config.get("hosts", []):
        for _ in range(int(host.get("islands", 1))):
            out.append({"k": len(out) + 1, "host": host["host"], "user": host.get("user")})
    return out


def target(island):
    return "%s@%s" % (island["user"], island["host"]) if island.get("user") else island["host"]


def ssh_cmd(dest):
    return SSH + (LIVE_SSH if dest in LIVE_DESTS else [])


def rsh(dest):
    return " ".join(ssh_cmd(dest))


def ssh(dest, command, timeout=60):
    try:
        done = subprocess.run(ssh_cmd(dest) + [dest, command], capture_output=True, text=True, timeout=timeout)
        return done.returncode, done.stdout + done.stderr
    except subprocess.TimeoutExpired:
        return 255, "timed out"


def run(command, timeout=None):
    try:
        done = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
        return done.returncode, done.stdout + done.stderr
    except subprocess.TimeoutExpired:
        return 255, "timed out"


def hosts(config):
    """Each host once: [(dest, islands on it)]."""
    seen = {}
    for island in islands_of(config):
        if island["host"]:
            seen[target(island)] = seen.get(target(island), 0) + 1
    return list(seen.items())


def local_dir(k):
    return os.path.join(evolution.evolution_dir(), "islands", "island%d" % k)


def remote_dir(k):
    return "$HOME/%s/islands/island%d" % (REMOTE, k)


# --- check / push ---

def check(config):
    ok = True
    say("this machine: %d islands, Godot %s" % (int(config.get("local", 0)), config["godot"]))
    if not os.access(config["godot"], os.X_OK):
        say("  NO GODOT at %s" % config["godot"])
        ok = False
    for dest, count in hosts(config):
        code, out = ssh(dest, "nproc; free -m | awk '/Mem/{print $2\" MB\"}'; ls ~/%s/godot >/dev/null 2>&1 && echo godot-there || echo no-godot-yet; "
                              "[ -e /tmp/.X11-unix/X0 ] && echo display-ok || echo NO-DISPLAY" % REMOTE)
        if code != 0:
            say("  %s: UNREACHABLE (%s)" % (dest, out.strip().splitlines()[-1] if out.strip() else code))
            ok = False
            continue
        lines = out.split()
        say("  %s: %s cores, %s %s, %d islands, %s, %s" % (dest, lines[0], lines[1], lines[2], count, lines[3], lines[4]))
        if lines[4] != "display-ok":
            say("    no desktop on :0: log in to the desktop there (Godot needs a display)")
            ok = False
    return ok


def push(config):
    """Godot and the project to every host (rsync: only what changed). Returns the hosts it reached."""
    reached = []
    for dest, _count in hosts(config):
        code, out = ssh(dest, "mkdir -p ~/%s/project ~/%s/islands" % (REMOTE, REMOTE))
        if code != 0:
            say("push: %s unreachable, left out" % dest)
            continue
        steps = [
            ["rsync", "-az", "-e", rsh(dest), config["godot"], "%s:%s/godot" % (dest, REMOTE)],
            ["rsync", "-az", "--delete", "-e", rsh(dest)] + ["--exclude=" + e for e in RSYNC_EXCLUDES]
            + [ROOT + "/", "%s:%s/project/" % (dest, REMOTE)],
        ]
        failed = False
        for step in steps:
            code, out = run(step, timeout=1800)
            if code != 0:
                say("push: %s failed: %s" % (dest, out.strip()[-300:]))
                failed = True
                break
        if not failed:
            reached.append(dest)
            say("push: %s up to date" % dest)
    return reached


# --- a segment ---

def _sim_args(config, save_dir, k):
    return ["--no-window", "-s", "tools/evolution_sim.gd", "--", "--hours=%s" % segment_hours(config), "--speed=%s" % config["speed"],
            "--save-dir=" + save_dir, "--island=%d" % k, "--backup-every=1000", "--save-every=10"]


def on_battery():
    """True if this machine's charger is off (a blackout): then segments are battery_hours long."""
    for path in glob.glob("/sys/class/power_supply/A*/online"):
        try:
            with open(path) as handle:
                if handle.read().strip() == "0":
                    return True
        except OSError:
            pass
    return False


def segment_hours(config):
    return float(config.get("battery_hours", config["hours"])) if on_battery() else float(config["hours"])


def start(config, island, base):
    k = island["k"]
    if island["host"] is None:
        folder = local_dir(k)
        shutil.rmtree(folder, ignore_errors=True)
        os.makedirs(folder)
        shutil.copyfile(base, os.path.join(folder, "save_0.sav"))
        log = open(os.path.join(folder, "console.log"), "w")
        island["process"] = subprocess.Popen([config["godot"]] + _sim_args(config, folder, k), cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                             stdin=subprocess.DEVNULL, start_new_session=True)
        return True
    shutil.rmtree(local_dir(k), ignore_errors=True)  # Last segment's copy here must never pass for this one's
    dest, folder = target(island), remote_dir(k)
    code, out = ssh(dest, "rm -rf %s && mkdir -p %s" % (folder, folder))
    if code == 0:
        code, out = run(["rsync", "-az", "-e", rsh(dest), base, "%s:%s/islands/island%d/save_0.sav" % (dest, REMOTE, k)], timeout=600)
    if code == 0:
        args = " ".join(shlex.quote(a) for a in _sim_args(config, "REMOTEDIR", k)).replace("REMOTEDIR", folder)
        # Only Godot goes to the background, all its streams away from the SSH channel: a backgrounded
        # "cd && godot" list would be a subshell holding the channel open until Godot ends.
        code, out = ssh(dest, "cd ~/%s/project || exit 1; DISPLAY=:0 XAUTHORITY=$HOME/.Xauthority setsid nohup ~/%s/godot %s > %s/console.log 2>&1 < /dev/null & echo started"
                        % (REMOTE, REMOTE, args, folder), timeout=30)
    if code != 0:
        say("island %d on %s did not start: %s" % (k, dest, out.strip()[-200:]))
        return False
    return True


def status(island):
    """The island's status.json ({} if none or unreachable)."""
    if island["host"] is None:
        return evolution.read_json(os.path.join(local_dir(island["k"]), "status.json")) or {}
    code, out = ssh(target(island), "cat %s/status.json 2>/dev/null" % remote_dir(island["k"]), timeout=30)
    try:
        return json.loads(out) if code == 0 and out.strip() else {}
    except ValueError:
        return {}


def gone(island, info):
    """True if the island's process has ended (it may have saved: its state then says "done")."""
    if island["host"] is None:
        process = island.get("process")
        return process is not None and process.poll() is not None
    pid = int(info.get("pid", 0) or 0)
    if pid <= 0:
        return False
    code, out = ssh(target(island), "kill -0 %d 2>/dev/null && echo alive || echo gone" % pid, timeout=30)
    return code == 0 and out.strip().endswith("gone")


def ask_stop(island):
    if island["host"] is None:
        open(os.path.join(local_dir(island["k"]), "stop"), "w").close()
    else:
        ssh(target(island), "touch %s/stop" % remote_dir(island["k"]))


def collect(island):
    """The island's save and life log brought here (a remote one); True if its segment finished."""
    folder = local_dir(island["k"])
    if island["host"] is not None:
        os.makedirs(folder, exist_ok=True)
        for name in ("status.json", "console.log", "save_0.sav", "logs/"):
            run(["rsync", "-az", "-e", rsh(target(island)), "%s:%s/islands/island%d/%s" % (target(island), REMOTE, island["k"], name),
                 os.path.join(folder, name.rstrip("/")) + ("/" if name.endswith("/") else "")], timeout=600)
    info = evolution.read_json(os.path.join(folder, "status.json")) or {}
    return info.get("state") == "done" and os.path.exists(os.path.join(folder, "save_0.sav"))


def write_master_status(state, game_time, extra=None):
    info = {"pid": os.getpid(), "state": state, "updated": int(time.time()), "game_time": game_time, "islands": True}
    info.update(extra or {})
    path = os.path.join(evolution.evolution_dir(), "status.json")
    with open(path + ".tmp", "w") as handle:
        json.dump(info, handle)
    os.replace(path + ".tmp", path)


def merge(config, base, finished):
    out = os.path.join(evolution.evolution_dir(), "save_0.sav")
    saves = [os.path.join(local_dir(i["k"]), "save_0.sav") for i in finished]
    code, text = run([config["godot"], "--no-window", "-s", "tools/merge_islands.gd", "--", "--base=" + base, "--out=" + out] + saves, timeout=900)
    line = next((l for l in text.splitlines() if l.startswith("MERGE")), "MERGE FAILED (no word from the tool)")
    say(line)
    return code == 0 and line.startswith("MERGE ok")


def append_logs(finished, run_id):
    """Every island's life log onto the era's (logs/run_<id>.jsonl), as one run's."""
    main = os.path.join(evolution.evolution_dir(), "logs", "run_%s.jsonl" % run_id)
    os.makedirs(os.path.dirname(main), exist_ok=True)
    lines = 0
    with open(main, "a") as into:
        for island in finished:
            for path in sorted(glob.glob(os.path.join(local_dir(island["k"]), "logs", "*.jsonl"))):
                with open(path) as source:
                    for line in source:
                        if line.strip():
                            into.write(line if line.endswith("\n") else line + "\n")
                            lines += 1
    return lines


def backup(game_time):
    folder = os.path.join(evolution.evolution_dir(), "backups")
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, "islands_t%06.2fh.sav" % (game_time / 3600.0))
    shutil.copyfile(os.path.join(evolution.evolution_dir(), "save_0.sav"), path)
    autos = sorted(glob.glob(os.path.join(folder, "islands_t*.sav")))
    for old in autos[:-BACKUPS_KEPT]:
        os.remove(old)
    return path


def segment(config):
    """One segment on every island. Returns "ok", "stopped" (asked to stop: the merge still ran) or "failed"."""
    folder = evolution.evolution_dir()
    info = evolution.status(folder) or {}
    if info.get("running") and int(info.get("pid", 0)) != os.getpid():
        say("evolution is running (pid %s): stop it first" % info.get("pid"))
        return "failed"
    master = os.path.join(folder, "save_0.sav")
    base = os.path.join(folder, "islands", "base.sav")
    os.makedirs(os.path.dirname(base), exist_ok=True)
    shutil.copyfile(master, base)
    game_time = float(info.get("game_time") or 0.0)
    reached = set(push(config)) if hosts(config) else set()
    islands = [i for i in islands_of(config) if i["host"] is None or target(i) in reached]
    started = [i for i in islands if start(config, i, base)]
    if not started:
        say("no island started")
        return "failed"
    say("segment from t=%.1fh: islands %s" % (game_time / 3600.0, ", ".join("%d%s" % (i["k"], "@" + i["host"] if i["host"] else "") for i in started)))
    write_master_status("running", game_time)
    stop_file = os.path.join(folder, "stop")
    stopped = False
    pending = {i["k"]: i for i in started}
    done_ks = set()  # Islands seen finishing this segment: only they are merged
    last_seen = {k: time.time() for k in pending}
    time.sleep(POLL)
    while pending:
        if os.path.exists(stop_file) and not stopped:
            os.remove(stop_file)
            stopped = True
            say("asked to stop: every island saves and ends")
            for island in pending.values():
                ask_stop(island)
        for k in list(pending):
            info_k = status(pending[k])
            if info_k.get("state") == "done":
                say("island %d done: t=%.1fh, %s lives ended, pace x%.2f" % (k, float(info_k.get("game_time", 0)) / 3600.0, info_k.get("lives"), float(info_k.get("pace", 0))))
                done_ks.add(k)
                del pending[k]
                continue
            if info_k:
                last_seen[k] = max(last_seen[k], float(info_k.get("updated", 0)))  # The island's own clock: hosts' clocks should roughly agree
            if gone(pending[k], info_k):
                status_again = status(pending[k])  # It may have written "done" as it ended
                if status_again.get("state") == "done":
                    continue  # Seen as done on the next pass
                say("island %d ended without finishing its segment (see its console.log): left out" % k)
                del pending[k]
            elif time.time() - last_seen[k] > STALE:
                say("island %d: no word for %d s, left out" % (k, STALE))
                ask_stop(pending[k])
                del pending[k]
        write_master_status("running", game_time, {"waiting": sorted(pending)})
        if pending:
            time.sleep(POLL)
    finished = [i for i in started if i["k"] in done_ks and collect(i)]
    if not finished:
        say("no island finished: the save is as it was")
        write_master_status("done", game_time)
        return "failed"
    run_id = str((evolution.read_json(os.path.join(local_dir(finished[0]["k"]), "status.json")) or {}).get("run_id", "")).split("_i")[0]
    if not merge(config, base, finished):
        write_master_status("done", game_time)
        return "failed"
    say("%d lives appended to logs/run_%s.jsonl" % (append_logs(finished, run_id), run_id))
    game_time = float((evolution.read_json(os.path.join(local_dir(finished[0]["k"]), "status.json")) or {}).get("game_time", game_time))
    say("backup %s" % os.path.basename(backup(game_time)))
    write_master_status("done", game_time)
    return "stopped" if stopped else "ok"


def main(argv):
    config = load_config()
    LIVE_DESTS.update(target({"host": h["host"], "user": h.get("user")}) for h in config.get("hosts", []) if h.get("live"))
    command = argv[0] if argv else "check"
    if command == "usb-kit":
        return 0 if usb_kit(os.path.abspath(argv[1] if len(argv) > 1 else os.path.join(DEV_DIR, "islands_usb"))) else 1
    if command == "check":
        return 0 if check(config) else 1
    if command == "push":
        push(config)
        return 0
    if command == "stop":
        open(os.path.join(evolution.evolution_dir(), "stop"), "w").close()
        say("stop asked: the segment running ends, merges and the run stops")
        return 0
    if command in ("segment", "run"):
        count = int(argv[1]) if command == "run" and len(argv) > 1 else 1
        for number in range(count):
            say("== segment %d of %d" % (number + 1, count))
            config = load_config()  # Settings may change between segments (.dev/islands.json)
            LIVE_DESTS.update(target({"host": h["host"], "user": h.get("user")}) for h in config.get("hosts", []) if h.get("live"))
            say("segments of %.2f h%s" % (segment_hours(config), " (on battery)" if on_battery() else ""))
            result = segment(config)
            if result != "ok":
                return 0 if result == "stopped" else 1
        return 0
    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
