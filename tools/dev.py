#!/usr/bin/env python3
"""
GDTLancer developer menu: every tool in tools/ (and the tests, the APK export, the editor) from one
place. Pick a task, answer its questions (Enter keeps the shown default; the last answers are
remembered), and it runs in the terminal; press Enter afterwards to come back.

    tools/dev.py                      the menu (arrows or j/k, Enter, / to filter by words, q to quit)
    tools/dev.py list                 the tasks
    tools/dev.py <task> [key=value]   one task, no menu (questions not given take their defaults)
    tools/dev.py <task> --dry         only print its command

Settings from the environment: GODOT (the Godot 3.6 binary, default "godot"), GDTLANCER_APK (where
the debug APK goes). Output files (sheets, shots) go to .dev/out/, which Godot and git ignore.
To add a tool: a Task in TASKS below.
"""

import curses
import glob
import json
import os
import shlex
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DEV_DIR = os.path.join(ROOT, ".dev")
OUT_DIR = os.path.join(DEV_DIR, "out")
LAST_FILE = os.path.join(DEV_DIR, "last.json")
GODOT = os.environ.get("GODOT", "godot")
BLENDER = os.path.join("tools", "blender")
APK = os.path.expanduser(os.environ.get("GDTLANCER_APK", "~/Dropbox/Dump/GDTLancer-rev.apk"))
TYPE_A_PATH = "(type a path)"


# --- Questions --------------------------------------------------------------------------------

class Ask:
    """One question a task asks. kind: "text", "choice" (from `choices`), "file" (from `globs`,
    relative to the project) or "flag" (yes/no)."""

    def __init__(self, key, label, kind="text", default="", choices=None, globs=None, optional=False):
        self.key, self.label, self.kind = key, label, kind
        self.default, self.choices, self.globs, self.optional = default, choices, globs, optional

    def options(self):
        if self.kind == "flag":
            return ["no", "yes"]
        if self.kind == "choice":
            return list(self.choices() if callable(self.choices) else self.choices)
        if self.kind == "file":
            found = []
            for pattern in self.globs:
                found += sorted(glob.glob(os.path.join(ROOT, pattern), recursive=True))
            return [os.path.relpath(path, ROOT) for path in found] + [TYPE_A_PATH]
        return []


class Task:
    def __init__(self, key, group, title, about, build, asks=(), before=None):
        self.key, self.group, self.title, self.about = key, group, title, about
        self.build, self.asks, self.before = build, list(asks), before

    def defaults(self, last):
        values = {}
        for ask in self.asks:
            values[ask.key] = last.get(self.key, {}).get(ask.key, ask.default)
        return values


def godot(*args):
    return [GODOT] + list(args)


def godot_script(script, *args):
    return godot("--no-window", "-s", script, *args)


def blender(*args):
    return [BLENDER] + list(args)


def yes(value):
    return str(value).lower() in ("yes", "y", "true", "1")


def res(path):
    return path if path.startswith("res://") else "res://" + path


def dev_dir():
    """.dev/, made with a .gdignore so Godot never imports what lands there."""
    os.makedirs(OUT_DIR, exist_ok=True)
    ignore = os.path.join(DEV_DIR, ".gdignore")
    if not os.path.exists(ignore):
        open(ignore, "w").close()
    return DEV_DIR


def out_file(name):
    dev_dir()
    return os.path.join(OUT_DIR, name)


def stem(path):
    return os.path.splitext(os.path.basename(path))[0]


def factions():
    return sorted(stem(path) for path in glob.glob(os.path.join(ROOT, "database/factions/*.tres")))


PERF_MODES = ["base", "base_full", "no_3d", "no_hud", "no_lights", "no_particles", "no_rocks",
              "no_ships_3d", "lod_low", "physics_30", "no_ai"]
MODEL_SOURCES = ["assets/models/ships/*/*.blend", "assets/models/ships/*/*.glb",
                 "assets/models/stations/*/*.blend", "assets/models/stations/*/*.glb"]
MODEL_SCENES = ["scenes/prefabs/ships/*.tscn", "scenes/prefabs/ships/placeholders/*.tscn",
                "scenes/prefabs/station/*.tscn", "scenes/prefabs/station/placeholders/*.tscn"]


def _is_station(path):
    return "/stations/" in path or "/station/" in path


def _import_model(v):
    command = ["tools/import_model.sh"]
    if v["kind"] == "station" or (v["kind"] == "auto" and _is_station(v["model"])):
        command.append("--station")
    return command + ["--ratio", v["ratio"], "--levels", v["levels"], v["model"]]


def _new_model(v):
    """Copies a starter into place (never over an existing model); the menu then opens it."""
    kind = "station" if v["kind"] == "station" else "ship"
    folder = os.path.join(ROOT, "assets/models/%ss" % kind, v["name"])
    target = os.path.join(folder, v["name"] + ".blend")
    if os.path.exists(target):
        print("Already there: %s (left as it is)" % os.path.relpath(target, ROOT))
    else:
        os.makedirs(folder, exist_ok=True)
        shutil.copyfile(os.path.join(ROOT, "assets/models/starters/%s_starter.blend" % kind), target)
        print("New model: %s" % os.path.relpath(target, ROOT))
    print("Import it with: tools/dev.py import_model model=%s" % os.path.relpath(target, ROOT))
    return blender(target) if yes(v["open"]) else None


def _check_model(v):
    command = godot_script("tools/check_model.gd", "--", res(v["scene"]))
    return command + (["--station"] if _is_station(v["scene"]) else [])


def _model_sheet(v):
    return godot("res://tools/hull_sheet.tscn", "out=" + out_file(stem(v["scene"]) + "_sheet.png"),
                 "scene=" + res(v["scene"])[:-len(".tscn")])


def _evolution(v):
    command = godot_script("tools/evolution_sim.gd", "--", "--hours=" + v["hours"], "--speed=" + v["speed"])
    if yes(v["new"]):
        command.append("--new")
    if yes(v["new_era"]):
        command.append("--new-era")
    return command


def _lance_duel(v):
    command = godot_script("tools/lance_duel.gd", "--", "--duels=" + v["duels"], "--speed=" + v["speed"])
    if v["match"]:
        command.append("--match=" + v["match"])
    if yes(v["weapons"]):
        command.append("--weapons")
    return command


def _export_presets(v):
    command = godot_script("tools/export_presets.gd", "--", "--top=" + v["top"], "--min-lives=" + v["min_lives"])
    return command + (["--clean"] if yes(v["clean"]) else [])


def _render_preview(v):
    return godot("-s", "tools/render_preview.gd", "scene=" + res(v["scene"])[:-len(".tscn")],
                 "out=" + out_file(stem(v["scene"]) + "_preview.png"), "radius=" + v["radius"], "distances=" + v["distances"])


TASKS = [
    # Checks
    Task("tests", "Checks", "Run the tests", "Every GUT test (content rules and models included).",
         lambda v: godot_script("addons/gut/gut_cmdln.gd", "-gexit", *(["-gdir=" + res(v["dir"])] if v["dir"] else [])),
         [Ask("dir", "Only this test folder (empty: all)", default="", optional=True)]),
    Task("check_model", "Checks", "Check a model scene", "A ship or station scene against the model rules (CONTENT.md, Models).",
         _check_model, [Ask("scene", "Scene", "file", globs=MODEL_SCENES)]),
    Task("shaders_check", "Checks", "Check shader blocks", "Lists shaders whose shared blocks are out of date.",
         lambda v: ["python3", "tools/sync_shader_blocks.py", "--check"]),
    Task("shaders_sync", "Checks", "Sync shader blocks", "Copies assets/art/shaders/shader_common.glsl's blocks into every shader.",
         lambda v: ["python3", "tools/sync_shader_blocks.py"]),
    # Models
    Task("new_model", "Models", "New model from a starter", "Copies the ship or station starter to assets/models/<kind>s/<name>/ and opens it in Blender.",
         _new_model, [Ask("kind", "Kind", "choice", "ship", ["ship", "station"]), Ask("name", "Name (lower_case)"),
                      Ask("open", "Open in Blender", "flag", "yes")]),
    Task("import_model", "Models", "Import a model", "Export (.blend), fit to 17 m (ships), LODs, import, hit surface, scene, check.",
         _import_model, [Ask("model", "Model", "file", globs=MODEL_SOURCES),
                         Ask("kind", "Ship or station", "choice", "auto", ["auto", "ship", "station"]),
                         Ask("ratio", "LOD ratio", default="0.7"), Ask("levels", "LOD levels", default="3")]),
    Task("open_blender", "Models", "Open a model in Blender", "Blender 3.6 (tools/blender) with the file.",
         lambda v: blender(v["model"]), [Ask("model", "Model", "file", globs=["assets/models/**/*.blend"])]),
    Task("model_sheet", "Models", "Model review sheet", "One model in every faction's paint (across) at every LOD (down), to .dev/out/.",
         _model_sheet, [Ask("scene", "Scene", "file", globs=MODEL_SCENES)]),
    Task("placeholder_sheet", "Models", "Placeholder hull sheet", "Every placeholder hull in a faction's paint, to .dev/out/.",
         lambda v: godot("res://tools/hull_sheet.tscn", "out=" + out_file("placeholders_%s.png" % v["faction"]), "faction=" + v["faction"]),
         [Ask("faction", "Faction", "choice", "verdant", factions)]),
    Task("starters", "Models", "Rebuild the starter .blends", "After adding a library material (assets/art/materials_generic/).",
         lambda v: blender("-b", "-P", "tools/make_starters.py")),
    Task("bake_hits", "Models", "Bake every hit surface", "For every ship model in use (after changing LOD settings).",
         lambda v: godot_script("tools/bake_hit_shapes.gd")),
    Task("lods", "Models", "Make LODs for a .glb", "Levels of detail only (import_model does this for ships).",
         lambda v: blender("-b", "-P", "tools/generate_lods.py", "--", "--levels", v["levels"], "--ratio", v["ratio"], v["model"]),
         [Ask("model", "Model", "file", globs=["assets/models/**/*.glb"]), Ask("ratio", "Ratio", default="0.5"), Ask("levels", "Levels", default="3")]),
    Task("paint_patterns", "Models", "Paint pattern library", "Regenerates the faction paint patterns and their contact sheet.",
         lambda v: ["python3", "tools/generate_paint_patterns.py", "--library"]),
    # Content
    Task("classify_presets", "Content", "Classify presets + CATALOG.md", "Labels every preset and rewrites database/presets/CATALOG.md.",
         lambda v: godot_script("tools/classify_presets.gd")),
    Task("export_presets", "Content", "Export presets from evolution", "The fittest designs of evolution's save as preset files.",
         _export_presets, [Ask("top", "Archetypes", default="60"), Ask("min_lives", "Minimum lives", default="10"),
                           Ask("clean", "Remove the old presets first", "flag", "no")]),
    Task("apply_laws", "Content", "Apply the ship laws", "Rewrites hand-made ships and parts from their law genes (after changing a law).",
         lambda v: godot_script("tools/apply_laws.gd")),
    # Evolution
    Task("evolution", "Evolution", "Run evolution (headless)", "Back up the save and export drafts before a new era.",
         _evolution, [Ask("hours", "Simulated hours (0: until stopped)", default="1"), Ask("speed", "Speed", default="6"),
                      Ask("new", "Start a new evolution", "flag", "no"), Ask("new_era", "New era (rules changed)", "flag", "no")]),
    Task("evolution_report", "Evolution", "Evolution report", "Summary of the newest evolution life log.",
         lambda v: ["python3", "tools/evolution_report.py"] + (["--last-hours", v["hours"]] if v["hours"] else []),
         [Ask("hours", "Only the last hours (empty: all)", default="", optional=True)]),
    # Balance and performance
    Task("balance_sim", "Balance", "Battle balance sim", "A headless faction battle by the home station: kills, fight times, damage.",
         lambda v: godot_script("tools/balance_sim.gd")),
    Task("lance_duel", "Balance", "Lance duels", "Designs fight one on one; what the lance did.",
         _lance_duel, [Ask("duels", "Duels per match", default="8"), Ask("speed", "Speed", default="6"),
                       Ask("match", "Only this match (e.g. lancer,laser; empty: all)", default="", optional=True),
                       Ask("weapons", "Missile and cannon designs", "flag", "no")]),
    Task("perf", "Balance", "Performance ablation", "Frame times with one system switched off.",
         lambda v: godot_script("tools/perf_ablation.gd", "mode=" + v["mode"]),
         [Ask("mode", "Mode", "choice", "base", PERF_MODES)]),
    # Look
    Task("ui_shots", "Look", "UI screenshots", "Every store tab and prompt, with control dumps, to .dev/out/ui/.",
         lambda v: godot("res://tools/ui_shots.tscn", "out=" + out_file("ui"))),
    Task("render_preview", "Look", "Render preview", "A scene from a few distances, side by side, to .dev/out/.",
         _render_preview, [Ask("scene", "Scene", "file", globs=["scenes/**/*.tscn"]), Ask("radius", "Object size (m)", default="100"),
                           Ask("distances", "Distances (in sizes)", default="3,10,40")]),
    # Game
    Task("play", "Game", "Play", "Runs the game in a window.", lambda v: godot()),
    Task("editor", "Game", "Open the Godot editor", "", lambda v: godot("-e")),
    Task("apk", "Game", "Export the debug APK", "Android debug build to $GDTLANCER_APK (" + APK + ").",
         lambda v: godot("--no-window", "--export-debug", "Android", APK)),
]
TASKS_BY_KEY = {task.key: task for task in TASKS}


# --- Running ----------------------------------------------------------------------------------

def load_last():
    try:
        with open(LAST_FILE) as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


def save_last(last):
    dev_dir()
    with open(LAST_FILE, "w") as handle:
        json.dump(last, handle, indent=1, sort_keys=True)


def missing(task, values):
    return [ask.label for ask in task.asks if not ask.optional and str(values.get(ask.key, "")).strip() == ""]


def run(task, values, dry=False):
    """Builds and runs `task`'s command from the project folder; returns its exit code."""
    lacking = missing(task, values)
    if lacking:
        print("Missing: " + ", ".join(lacking))
        return 2
    command = task.build(values) if not dry or task.key != "new_model" else ["(copies a starter, then)", BLENDER]
    if command is None:
        return 0
    print("$ " + " ".join(shlex.quote(str(part)) for part in command), flush=True)
    if dry:
        return 0
    try:
        return subprocess.call([str(part) for part in command], cwd=ROOT)
    except FileNotFoundError as error:
        print("Not found: %s" % error.filename)
        return 127
    except KeyboardInterrupt:
        return 130


# --- The menu ---------------------------------------------------------------------------------

def _rows(filter_text):
    """[(task or group title, is_header)] for the menu: tasks whose title, key or group hold every
    word of the filter."""
    rows, group = [], None
    words = filter_text.lower().split()
    for task in TASKS:
        haystack = (task.title + " " + task.key + " " + task.group).lower()
        if not all(word in haystack for word in words):
            continue
        if task.group != group:
            group = task.group
            rows.append((group, True))
        rows.append((task, False))
    return rows


def _put(screen, y, x, text, attr=0):
    height, width = screen.getmaxyx()
    if 0 <= y < height and x < width:
        screen.addnstr(y, x, text, max(0, width - x - 1), attr)


def _pick(screen, title, options, current):
    """A list to choose from; returns the choice, or None (Esc)."""
    index = options.index(current) if current in options else 0
    top = 0
    while True:
        screen.erase()
        height, _ = screen.getmaxyx()
        _put(screen, 0, 1, title, curses.A_BOLD)
        _put(screen, 1, 1, "Enter: choose   Esc: back", curses.A_DIM)
        view = max(1, height - 3)
        top = min(max(top, index - view + 1), index)
        for row, option in enumerate(options[top:top + view]):
            _put(screen, 2 + row, 2, option, curses.A_REVERSE if top + row == index else 0)
        key = screen.getch()
        if key in (curses.KEY_UP, ord("k")):
            index = (index - 1) % len(options)
        elif key in (curses.KEY_DOWN, ord("j")):
            index = (index + 1) % len(options)
        elif key == curses.KEY_NPAGE:
            index = min(len(options) - 1, index + view)
        elif key == curses.KEY_PPAGE:
            index = max(0, index - view)
        elif key in (10, 13, curses.KEY_ENTER):
            return options[index]
        elif key == 27:
            return None


def _type(screen, title, current):
    """A line to type; returns the text, or None (Esc)."""
    text = str(current)
    curses.curs_set(1)
    try:
        while True:
            screen.erase()
            _put(screen, 0, 1, title, curses.A_BOLD)
            _put(screen, 1, 1, "Enter: keep   Esc: back", curses.A_DIM)
            _put(screen, 3, 2, "> " + text)
            screen.move(3, min(4 + len(text), screen.getmaxyx()[1] - 2))
            key = screen.get_wch()
            if key in ("\n", "\r", curses.KEY_ENTER):
                return text
            if key == "\x1b":
                return None
            if key in (curses.KEY_BACKSPACE, "\x7f", "\b"):
                text = text[:-1]
            elif isinstance(key, str) and key.isprintable():
                text += key
    finally:
        curses.curs_set(0)


def _ask_all(screen, task, values):
    """Asks `task`'s questions in turn; returns the answers, or None if backed out of."""
    values = dict(values)
    for ask in task.asks:
        title = "%s: %s" % (task.title, ask.label)
        if ask.kind in ("choice", "flag", "file"):
            answer = _pick(screen, title, ask.options(), str(values.get(ask.key, "")))
            if answer == TYPE_A_PATH:
                answer = _type(screen, title + " (from the project folder)", "")
        else:
            answer = _type(screen, title, values.get(ask.key, ""))
        if answer is None:
            return None
        values[ask.key] = answer
    return values


def menu(screen):
    curses.curs_set(0)
    curses.use_default_colors()
    index, filter_text = 1, ""
    while True:
        rows = _rows(filter_text)
        choosable = [i for i, row in enumerate(rows) if not row[1]]
        if choosable and index not in choosable:
            index = choosable[0]
        screen.erase()
        height, width = screen.getmaxyx()
        _put(screen, 0, 1, "GDTLancer tools", curses.A_BOLD)
        _put(screen, 0, 18, ("filter: " + filter_text) if filter_text else "Enter: run   /: filter   q: quit", curses.A_DIM)
        view = max(1, height - 5)
        top = max(0, index - view + 1)
        for row_index in range(top, min(len(rows), top + view)):
            item, header = rows[row_index]
            y = 1 + row_index - top
            if header:
                _put(screen, y, 1, item, curses.A_BOLD | curses.A_UNDERLINE)
            else:
                _put(screen, y, 3, "%-34s %s" % (item.title, item.key), curses.A_REVERSE if row_index == index else 0)
        if not choosable:
            _put(screen, 2, 3, "No task matches. Esc: clear the filter", curses.A_DIM)
        if choosable:
            task = rows[index][0]
            _put(screen, height - 3, 1, task.about, curses.A_DIM)
            try:
                preview = task.build(task.defaults(load_last())) if task.key != "new_model" and not missing(task, task.defaults(load_last())) else None
            except Exception:
                preview = None
            if preview:
                _put(screen, height - 2, 1, "$ " + " ".join(shlex.quote(str(p)) for p in preview), curses.A_DIM)
        screen.refresh()
        key = screen.getch()
        position = choosable.index(index) if index in choosable else 0
        if key == ord("q") or (key == 27 and not filter_text):
            return
        if key == 27:
            filter_text = ""
        elif key in (curses.KEY_UP, ord("k")) and choosable:
            index = choosable[(position - 1) % len(choosable)]
        elif key in (curses.KEY_DOWN, ord("j")) and choosable:
            index = choosable[(position + 1) % len(choosable)]
        elif key == ord("/"):
            typed = _type(screen, "Filter tasks", filter_text)
            filter_text = typed if typed is not None else filter_text
        elif key in (10, 13, curses.KEY_ENTER) and choosable:
            task = rows[index][0]
            last = load_last()
            values = _ask_all(screen, task, task.defaults(last))
            if values is None:
                continue
            last[task.key] = values
            save_last(last)
            curses.def_prog_mode()
            curses.endwin()
            code = run(task, values)
            print("\n[%s] exit %d. Enter: back to the menu" % (task.key, code), end="", flush=True)
            try:
                input()
            except EOFError:
                pass
            curses.reset_prog_mode()
            screen.refresh()


# --- Command line -----------------------------------------------------------------------------

def main(argv):
    if not argv:
        if not sys.stdout.isatty():
            print(__doc__)
            return 0
        curses.wrapper(menu)
        return 0
    if argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0
    if argv[0] == "list":
        group = None
        for task in TASKS:
            if task.group != group:
                group = task.group
                print("\n" + group)
            asks = " ".join("%s=%s" % (ask.key, ask.default or ("" if ask.optional else "?")) for ask in task.asks)
            print("  %-18s %s%s" % (task.key, task.title, ("   [" + asks + "]") if asks else ""))
        return 0
    task = TASKS_BY_KEY.get(argv[0])
    if task is None:
        print("No task '%s'. tools/dev.py list" % argv[0])
        return 2
    values = task.defaults(load_last())
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
    return run(task, values, dry)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
