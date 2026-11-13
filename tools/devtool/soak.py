"""
The soak check: the real game left running a few minutes (tools/soak.gd), judged.

    python3 tools/devtool/soak.py [minutes=5] [every=30]

tools/soak.gd starts a new game in Elace, the player docked at home, and prints a SOAK line of
counts every `every` s (real time, 1x). judge() reads the output and lists the problems:
  - a script error, or an engine error (any "SCRIPT ERROR" / "ERROR:" line);
  - no "SOAK done" (it crashed or hung) or too few samples;
  - wrecks or loose lances over their caps (WRECK_MAX, LANCE_LOOSE_MAX) in any sample;
  - after the warm-up (WARM_MINUTES; the sector fills up first), nodes left orphaned growing
    by more than ORPHAN_SLACK, memory by more than MEMORY_SLACK (MB or share, the larger), or a
    table of bookkeeping (sound, threat notices, travellers, markups, evolution) more than doubling.
Frame rates are printed, not judged (they depend on the machine). Exit code 0 when nothing is wrong.
Godot needs a display: DISPLAY is set to :0 when there is none.
"""

import json
import os
import re
import subprocess
import sys
import time

if __package__ in (None, ""):
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from devtool.tasks import ROOT, godot_script  # noqa: E402
else:
    from .tasks import ROOT, godot_script

WARM_MINUTES = 2.0
ORPHAN_SLACK = 10
MEMORY_SLACK_MB = 8.0
MEMORY_SLACK_SHARE = 0.1
TABLE_SLACK = 50  # A table may grow this much even past double (small tables double easily)
ERROR = re.compile(r"^\s*(SCRIPT ERROR|ERROR):")


def command(minutes=5, every=30):
    return godot_script("tools/soak.gd", "minutes=%s" % minutes, "every=%s" % every)


def environment():
    env = dict(os.environ)
    env.setdefault("DISPLAY", ":0")
    return env


def samples(text):
    found = []
    for line in text.splitlines():
        if line.startswith("SOAK {"):
            try:
                found.append(json.loads(line[len("SOAK "):]))
            except ValueError:
                pass
    return found


def judge(text, minutes=None):
    """The problems the soak's output shows (empty: it passed)."""
    problems = []
    errors = [line.strip() for line in text.splitlines() if ERROR.match(line)]
    if errors:
        shown = sorted(set(errors))
        problems.append("%d error line%s: %s" % (len(errors), "" if len(errors) == 1 else "s", "; ".join(shown[:5])
                                                + (" (and %d more kinds)" % (len(shown) - 5) if len(shown) > 5 else "")))
    found = samples(text)
    if "SOAK done" not in text:
        problems.append("it did not finish (no 'SOAK done': a crash or a hang)")
    if len(found) < 2:
        problems.append("too few samples (%d) to judge growth" % len(found))
        return problems
    for sample in found:
        for over in sample.get("over", []):
            problems.append("at %.1f min: %s" % (sample["t"], over))
    warm_at = min(WARM_MINUTES, found[-1]["t"] / 2.0)
    warm = next(sample for sample in found if sample["t"] >= warm_at)
    last = found[-1]
    if last["orphans"] - warm["orphans"] > ORPHAN_SLACK:
        problems.append("orphaned nodes grew %d -> %d after the warm-up" % (warm["orphans"], last["orphans"]))
    slack = max(MEMORY_SLACK_MB, warm["mem"] * MEMORY_SLACK_SHARE)
    if last["mem"] - warm["mem"] > slack:
        problems.append("memory grew %.1f -> %.1f MB after the warm-up (more than %.1f)" % (warm["mem"], last["mem"], slack))
    for name, size in sorted(last.get("tables", {}).items()):
        before = warm.get("tables", {}).get(name, 0)
        if size > 2 * before and size > before + TABLE_SLACK:
            problems.append("table %s grew %d -> %d after the warm-up" % (name, before, size))
    return problems


def summary(text):
    """A few lines on the run: frame rates, bodies, memory."""
    found = samples(text)
    if not found:
        return []
    fps = sorted(sample["fps"] for sample in found)
    return ["%d samples over %.1f min (%d s of game time)" % (len(found), found[-1]["t"], found[-1]["game"] - found[0]["game"]),
            "frames a second: first %d, last %d, lowest %d (this machine; not judged)" % (found[0]["fps"], found[-1]["fps"], fps[0]),
            "bodies %d -> %d (wrecks %d, loose lances %d at the end); memory %.1f -> %.1f MB; orphans %d -> %d" % (
                found[0]["bodies"], found[-1]["bodies"], found[-1]["wrecks"], found[-1]["lances"],
                found[0]["mem"], found[-1]["mem"], found[0]["orphans"], found[-1]["orphans"]),
            "deaths: %d" % sum(1 for line in text.splitlines() if line.startswith("DEATH "))]


def run(minutes=5, every=30, say=print):
    """Runs the soak (its output passes through) and judges it; 0 passed, 1 failed."""
    lines = []
    deadline = time.time() + float(minutes) * 60 + 300
    process = subprocess.Popen(command(minutes, every), cwd=ROOT, env=environment(), stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, errors="replace")
    try:
        for line in process.stdout:
            lines.append(line)
            say(line.rstrip("\n"))
            if time.time() > deadline:
                process.kill()
                lines.append("(stopped: past the time it should take)\n")
                break
        process.wait()
    except KeyboardInterrupt:
        process.kill()
        return 130
    return report("".join(lines), say)


def report(text, say=print):
    for line in summary(text):
        say(line)
    problems = judge(text)
    if problems:
        say("Soak FAILED:")
        for problem in problems:
            say("  - " + problem)
        return 1
    say("Soak passed.")
    return 0


def main(argv):
    values = dict(arg.split("=", 1) for arg in argv if "=" in arg)
    return run(values.get("minutes", "5"), values.get("every", "30"))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
