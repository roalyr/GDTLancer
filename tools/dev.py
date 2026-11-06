#!/usr/bin/env python3
"""
GDTLancer development tool: the project's content (models, data, sounds) and every tool and check
in one place. Code is edited elsewhere; everything else goes through here.

    tools/dev.py                      the menu (Overview, Models, Data, Tasks; keys in its footer)
    tools/dev.py list                 the tasks
    tools/dev.py <task> [key=value]   one task, no menu (questions not given take their defaults)
    tools/dev.py <task> --dry         only print its command
    tools/dev.py selftest             the tool's own tests

The menu needs Textual (tools/devtool/requirements.txt): on first use it is installed into .dev/venv,
which only this tool uses. Settings from the environment: GODOT (the Godot 3.6 binary, default
"godot"), GDTLANCER_APK (where the debug APK goes). Output files go to .dev/out/, which Godot and git
ignore. Parts: tools/devtool/ (tasks.py, bridge.py and bridge.gd, data.py, models.py, app.py).
"""

import os
import subprocess
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)

from devtool import tasks  # noqa: E402

VENV = os.path.join(tasks.DEV_DIR, "venv")
VENV_PYTHON = os.path.join(VENV, "bin", "python")
REQUIREMENTS = os.path.join(TOOLS, "devtool", "requirements.txt")


def with_textual(argv):
    """Runs this script again in .dev/venv (made and filled on first use) unless Textual is here."""
    try:
        import textual  # noqa: F401
        return False
    except ImportError:
        pass
    if os.path.abspath(sys.executable) == os.path.abspath(VENV_PYTHON):
        print("Textual is missing from %s: rm -r %s and run again" % (VENV, VENV))
        sys.exit(1)
    if not os.path.exists(VENV_PYTHON):
        print("First run: installing the menu's packages into %s ..." % os.path.relpath(VENV, tasks.ROOT), flush=True)
        tasks.dev_dir()
        subprocess.check_call([sys.executable, "-m", "venv", VENV])
        subprocess.check_call([VENV_PYTHON, "-m", "pip", "install", "-q", "-r", REQUIREMENTS])
    os.execv(VENV_PYTHON, [VENV_PYTHON, os.path.abspath(__file__)] + argv)
    return True


def selftest():
    with_textual(["selftest"])
    import unittest
    suite = unittest.defaultTestLoader.discover(os.path.join(TOOLS, "devtool", "tests"), top_level_dir=TOOLS)
    return 0 if unittest.TextTestRunner(verbosity=1).run(suite).wasSuccessful() else 1


def main(argv):
    if not argv:
        if not sys.stdout.isatty():
            print(__doc__)
            return 0
        with_textual([])
        from devtool.app import main as app_main
        app_main()
        return 0
    if argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0
    if argv[0] == "selftest":
        return selftest()
    if argv[0] == "list":
        group = None
        for task in tasks.TASKS:
            if task.group != group:
                group = task.group
                print("\n" + group)
            asks = " ".join("%s=%s" % (ask.key, ask.default or ("" if ask.optional else "?")) for ask in task.asks)
            print("  %-18s %s%s" % (task.key, task.title, ("   [" + asks + "]") if asks else ""))
        return 0
    task = tasks.TASKS_BY_KEY.get(argv[0])
    if task is None:
        print("No task '%s'. tools/dev.py list" % argv[0])
        return 2
    values = task.defaults(tasks.load_last())
    dry = False
    for arg in argv[1:]:
        if arg == "--dry":
            dry = True
        elif "=" in arg:
            key, value = arg.split("=", 1)
            if key not in values:
                print("%s asks: %s" % (task.key, ", ".join(values) or "nothing"))
                return 2
            values[key] = value
        else:
            print("Not key=value: %s" % arg)
            return 2
    return tasks.run(task, values, dry)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
