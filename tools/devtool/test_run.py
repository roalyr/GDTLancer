"""
The GUT tests as the tests task and the release run them:

    python3 tools/devtool/test_run.py [dir=res://src/tests/...] [file=test_x.gd]

1. Godot compiles every test script under the folder first (one bridge, a few seconds): a script
   that does not parse stops the run with its name. GUT 7.4.3 hangs on such a file instead of
   failing, so without this a run (or a release) would wait for good.
2. GUT runs under coreutils `timeout` (TIMEOUT s): whatever else hangs, the run ends with code 124.
"""

import os
import sys

if __package__ in (None, ""):
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from devtool.tasks import ROOT, environment, godot_script  # noqa: E402
    from devtool.bridge import Bridge  # noqa: E402
else:
    from .tasks import ROOT, environment, godot_script
    from .bridge import Bridge

TESTS = "res://src/tests"
TIMEOUT = 2700  # s for the whole GUT run (it takes ~10 minutes on a laptop)


def scripts(folder=TESTS, root=ROOT):
    """res:// paths of the test scripts under `folder` (res://)."""
    base = os.path.join(root, folder[len("res://"):])
    found = []
    for here, _dirs, files in os.walk(base):
        for name in sorted(files):
            if name.endswith(".gd"):
                found.append("res://" + os.path.relpath(os.path.join(here, name), root))
    return sorted(found)


def unparsable(folder=TESTS, bridge=None, root=ROOT):
    """The test scripts under `folder` that Godot cannot compile (BridgeCommands check_script), each as
    "res://path" or "res://path: Godot's parse error"."""
    if bridge is None:
        with Bridge() as line:
            return unparsable(folder, line, root)
    bad = []
    for path in scripts(folder, root):
        with open(os.path.join(root, path[len("res://"):])) as handle:
            source = handle.read()
        log = getattr(bridge, "log", [])
        seen = len(log)
        if not bridge.call("check_script", source=source).get("ok"):
            new = log[seen:]
            errors = [line.strip().replace("SCRIPT ERROR: ", "") for line in new if "error" in line.lower() and "at:" not in line]
            where = [line.rsplit("built-in:", 1)[1].rstrip(")") for line in new if "built-in:" in line]
            if errors:
                path += ":%s" % where[0] if where else ""
                path += ": " + errors[0]
            bad.append(path)
    return bad


def gut_command(folder="", file=""):
    """GUT over every test (or `folder`'s, or one file's: -gselect), under `timeout` TIMEOUT."""
    return ["timeout", str(TIMEOUT)] + godot_script("addons/gut/gut_cmdln.gd", "-gexit", *(["-gdir=" + folder] if folder else []),
                                                     *(["-gselect=" + file] if file else []))


def main(argv):
    import subprocess
    values = dict(arg.split("=", 1) for arg in argv if "=" in arg)
    folder = values.get("dir", "")
    print("Compiling the test scripts first (a test that does not parse hangs GUT)...", flush=True)
    bad = unparsable(folder or TESTS)
    if bad:
        print("These test scripts do not parse; fix them first:")
        for path in bad:
            print("  " + path)
        return 1
    code = subprocess.call(gut_command(folder, values.get("file", "")), cwd=ROOT, env=environment())
    if code == 124:
        print("GUT did not finish in %d s and was stopped." % TIMEOUT)
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
