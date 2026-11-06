"""
Sound loop settings: a sound in a "loop" slot of the sound bank must loop, one in any other slot
must not (ContentValidator's sounds rule). Whether a sound loops is an import setting, kept in its
.import file; this sets it there and has Godot import the sound again.

    tools/dev.py run fix_loops        (or the Overview tab's l key)
"""

import os
import re
import subprocess
import sys

if __package__ in (None, ""):  # Run as a file: tools/devtool/sounds.py
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    __package__ = "devtool"

from .bridge import Bridge, file_path  # noqa: E402
from .tasks import GODOT, ROOT  # noqa: E402

LOOP_KEYS = {".wav": ("edit/loop_mode", "1", "0"), ".ogg": ("loop", "true", "false"), ".mp3": ("loop", "true", "false")}


def set_loop(import_text, extension, loop):
    """`import_text` (a .import file) with its loop setting for a sound of `extension` set to `loop`."""
    key, on, off = LOOP_KEYS[extension.lower()]
    line = "%s=%s" % (key, on if loop else off)
    pattern = re.compile(r"^%s=.*$" % re.escape(key), re.M)
    if pattern.search(import_text):
        return pattern.sub(line, import_text, count=1)
    if "[params]" not in import_text:
        return import_text.rstrip("\n") + "\n\n[params]\n\n" + line + "\n"
    head, params = import_text.split("[params]", 1)
    return head + "[params]\n\n" + line + "\n" + params.lstrip("\n")


def imported_md5(import_text):
    """The .md5 file Godot keeps for the imported sound (removing it makes Godot import it again)."""
    found = re.search(r'^path="(res://\.import/[^"]+)\.\w+"', import_text, re.M)
    return file_path(found.group(1) + ".md5") if found else None


def wrong_slots(slots):
    """The bridge's sound_slots entries whose sound loops when it should not, or the other way."""
    return [slot for slot in slots if slot["path"] and slot["loops"] != (slot["kind"] == "loop")]


def fix(slots, reimport=True, godot=GODOT):
    """Sets the loop setting of every wrong slot's sound; returns the res:// paths changed."""
    changed = []
    for slot in wrong_slots(slots):
        path = slot["path"]
        extension = os.path.splitext(path)[1].lower()
        import_file = file_path(path) + ".import"
        if extension not in LOOP_KEYS or not os.path.exists(import_file):
            continue
        with open(import_file) as handle:
            text = handle.read()
        new_text = set_loop(text, extension, slot["kind"] == "loop")
        if new_text != text:
            with open(import_file, "w") as handle:
                handle.write(new_text)
            md5 = imported_md5(new_text)
            if md5 and os.path.exists(md5):
                os.remove(md5)
            if path not in changed:
                changed.append(path)
    if changed and reimport:
        subprocess.run([godot, "--no-window", "--editor", "--quit"], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return changed


def main():
    with Bridge() as bridge:
        slots = bridge.call("sound_slots")
    wrong = wrong_slots(slots)
    if not wrong:
        print("Every sound loops as its slot asks.")
        return 0
    for path in fix(slots):
        print("Set the loop of %s" % path)
    with Bridge() as bridge:
        left = wrong_slots(bridge.call("sound_slots"))
    for slot in left:
        print("Still wrong: slot %s (%s); set Loop in the Import dock" % (slot["slot"], slot["path"]))
    return 1 if left else 0


if __name__ == "__main__":
    sys.exit(main())
