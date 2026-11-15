"""
The project's import, headless: Godot converts the art, models and sounds into .import/, which git
does not keep (a fresh clone has none). `godot --editor --quit` is not enough for that: it quits
before the editor's first scan ends ("Scan thread aborted") and imports nothing on a fresh clone.
An export always scans and imports everything first, so this exports a throwaway pack (the Android
preset, into a temporary folder, deleted after) and then checks .import/ (tasks.import_problem).
Measured on a fresh clone: 273 assets in 23 s, none missing.

    python3 tools/devtool/import_project.py
"""

import os
import subprocess
import sys
import tempfile

if __package__ in (None, ""):  # Run as a file: tools/devtool/import_project.py
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    __package__ = "devtool"

from .tasks import GODOT, ROOT, environment, import_problem  # noqa: E402

PRESET = "Android"  # Any preset exports; this is the project's only one


def command(pack):
    return [GODOT, "--no-window", "--export-pack", PRESET, pack]


def main(root=ROOT, run=subprocess.call, say=print):
    with tempfile.TemporaryDirectory(prefix="gdtl_import_") as folder:
        say("Importing (Godot scans and converts every asset; GUT's icon errors before that are expected) ...")
        code = run(command(os.path.join(folder, "import.pck")), cwd=root, env=environment(),
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    problem = import_problem(root)
    if code != 0 or problem:
        say("The import did not finish (Godot exit %d). %s" % (code, problem or "Open the project once in the Godot editor instead."))
        return 1
    say("Imported: %d files in .import/" % len(os.listdir(os.path.join(root, ".import"))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
