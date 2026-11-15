"""
The development tool's tasks: every tool in tools/ (and the tests, the APK export, the editor) as a
Task with its questions (Ask). Standard library only, so `tools/dev.py <task>` runs without the
menu's packages. The menu (app.py) shows them on its Tasks tab. To add a tool: a Task in TASKS.
"""

import functools
import glob
import json
import os
import re
import shlex
import shutil
import subprocess

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEV_DIR = os.path.join(ROOT, ".dev")
OUT_DIR = os.path.join(DEV_DIR, "out")
LAST_FILE = os.path.join(DEV_DIR, "last.json")
# The programs the tools run (CONTENT.md, Getting started): Linux, Godot 3.6 (the x11 build: the
# server build crashes on scenes) and, for models, Blender 3.6. Set GODOT and BLENDER to their paths
# when they are not on PATH; a link tools/blender (not committed) also does for Blender.
GODOT = os.environ.get("GODOT", "godot")
GODOT_WANTED = "3.6"  # Godot 4 cannot open this project
BLENDER_WANTED = "3.6"


def _blender_default():
    local = os.path.join("tools", "blender")
    return local if os.path.exists(os.path.join(ROOT, local)) else "blender"


BLENDER = os.environ.get("BLENDER") or _blender_default()
APK = os.path.expanduser(os.environ.get("GDTLANCER_APK", "~/Dropbox/Dump/GDTLancer-rev.apk"))
TYPE_A_PATH = "(type a path)"


# --- Questions --------------------------------------------------------------------------------

class Ask:
    """One question a task asks. kind: "text", "int" (a whole number), "float" (a number), "choice"
    (from `choices`), "file" (from `globs`, relative to the project, or any path typed) or "flag"
    (yes/no)."""

    def __init__(self, key, label, kind="text", default="", choices=None, globs=None, optional=False, fresh=False):
        """`default` may be a function; `fresh`: always the default, never the last answer."""
        self.fresh = fresh
        self.key, self.label, self.kind = key, label, kind
        self.default, self.choices, self.globs, self.optional = default, choices, globs, optional

    def problem(self, value):
        """What is wrong with `value` as an answer ("" when nothing): numbers must be numbers, a typed
        file must exist. Empty answers are missing()'s business."""
        value = str(value).strip()
        if value == "":
            return ""
        if self.kind == "int":
            try:
                int(value)
            except ValueError:
                return "%s: a whole number (got %r)" % (self.label, value)
        if self.kind == "float":
            try:
                float(value)
            except ValueError:
                return "%s: a number (got %r)" % (self.label, value)
        if self.kind == "file" and not os.path.exists(os.path.join(ROOT, value[len("res://"):] if value.startswith("res://") else value)):
            return "%s: no such file %s" % (self.label, value)
        return ""

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


MAINTAINER = "Maintainer"  # The group of tasks for whoever runs evolution and releases: the menu hides it until m


class Task:
    def __init__(self, key, group, title, about, build, asks=(), before=None, check=None):
        """`check(values)`: problems with the answers taken together (one answer needing another), [] if none."""
        self.key, self.group, self.title, self.about = key, group, title, about
        self.build, self.asks, self.before, self.check = build, list(asks), before, check

    @property
    def maintainer(self):
        return self.group == MAINTAINER

    def defaults(self, last):
        values = {}
        for ask in self.asks:
            default = ask.default() if callable(ask.default) else ask.default
            values[ask.key] = default if ask.fresh else last.get(self.key, {}).get(ask.key, default)
        return values


def godot(*args):
    return [GODOT] + list(args)


def _version(program, prefix=""):
    """`program --version`'s first line (without `prefix`), or None when it does not run."""
    path = program if os.path.isabs(program) or os.sep in program else shutil.which(program)
    if not path:
        return None
    try:
        out = subprocess.run([path, "--version"], cwd=ROOT, capture_output=True, text=True, timeout=60).stdout
    except (OSError, subprocess.TimeoutExpired):
        return None
    for line in out.splitlines():
        line = line.strip()
        if line.startswith(prefix):
            return line[len(prefix):].strip()
    return ""


@functools.lru_cache(maxsize=None)
def godot_problem():
    """What is wrong with the Godot the tools would run ("" when it is Godot 3.6), saying what to do."""
    found = _version(GODOT)
    if found is None:
        return ("Godot not found (%s). Install Godot %s (the Linux x11 build, from godotengine.org's 3.x downloads) "
                "and put it on PATH as godot, or set GODOT=/path/to/godot." % (GODOT, GODOT_WANTED))
    if not found.startswith(GODOT_WANTED):
        return ("%s is Godot %s; this project needs Godot %s (3.6.2 is the tested one). Set GODOT=/path/to/godot-3.6."
                % (GODOT, found or "of an unknown version", GODOT_WANTED))
    return ""


@functools.lru_cache(maxsize=None)
def blender_problem():
    """The same for Blender (needed for models only)."""
    found = _version(BLENDER, "Blender")
    if found is None:
        return ("Blender not found (%s). Install Blender %s (blender.org's long-term release) and put it on PATH as "
                "blender, set BLENDER=/path/to/blender, or link it as tools/blender." % (BLENDER, BLENDER_WANTED))
    if not found.startswith(BLENDER_WANTED):
        return ("%s is Blender %s; the models need Blender %s (the starters and exporter are made for it). Set BLENDER=/path/to/blender-3.6."
                % (BLENDER, found or "of an unknown version", BLENDER_WANTED))
    return ""


def display_problem(env=None):
    """"" when Godot has a display to open; else what to do. The x11 build needs one even with
    --no-window, and the tools use DISPLAY=:0 when none is set (environment())."""
    display = (env or environment()).get("DISPLAY", "")
    number = display.split(":")[-1].split(".")[0] if ":" in display else ""
    if display.split(":")[0] not in ("", "unix") or not number.isdigit():
        return ""  # A remote or unusual display: Godot will say if it cannot open it
    if os.path.exists("/tmp/.X11-unix/X%s" % number):
        return ""
    return ("No display %s: Godot (the x11 build) needs one even without a window. Log in to the desktop on this "
            "machine, or set DISPLAY to the display that is running." % display)


def setup_problems():
    """Everything missing to run the tools, each saying what to do."""
    return [problem for problem in (godot_problem(), display_problem(), blender_problem()) if problem]


_godot_user_dir = None  # user:// as Godot itself reported it (the menu's bridge), when known


def set_user_dir(path):
    """Godot's own answer for user:// (BridgeCommands user_dir): it wins over the guess below."""
    global _godot_user_dir
    _godot_user_dir = path or None


def project_setting(key, root=None):
    """A project.godot value (application section keys as written, e.g. "config/name"), unquoted; None if absent."""
    try:
        with open(os.path.join(root or ROOT, "project.godot")) as handle:
            for line in handle:
                if line.startswith(key + "="):
                    return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return None


def user_dir(root=None):
    """The game's user:// folder, the one answer every part of the tool uses: Godot's own (once the
    menu has asked it), else GODOT_USER_DIR, else Godot 3's rule on Linux: $XDG_DATA_HOME (or
    ~/.local/share), then godot/app_userdata/<config/name>, or <custom_user_dir_name> with
    use_custom_user_dir."""
    if _godot_user_dir and root is None:
        return _godot_user_dir
    if os.environ.get("GODOT_USER_DIR"):
        return os.environ["GODOT_USER_DIR"]
    data = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    if project_setting("config/use_custom_user_dir", root) == "true" and project_setting("config/custom_user_dir_name", root):
        return os.path.join(data, project_setting("config/custom_user_dir_name", root))
    return os.path.join(data, "godot", "app_userdata", project_setting("config/name", root) or "GDTLancer")


def environment():
    """The tools' environment: GODOT and BLENDER as found, for the shell scripts, and DISPLAY=:0
    when none is set (from a bare terminal or over SSH: the x11 Godot needs a display even with
    --no-window, and would fail every task with its own display error)."""
    env = dict(os.environ)
    env["GODOT"], env["BLENDER"] = GODOT, BLENDER
    env.setdefault("DISPLAY", ":0")
    return env


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


def archetypes():
    prefix = "agent_archetype_"
    return sorted(stem(path)[len(prefix):] for path in glob.glob(os.path.join(ROOT, "database/presets/archetypes", prefix + "*.tres")))


def sectors():
    """Sector ids that have a layout (scenes/levels/sectors/<id>/<id>_layout.tscn)."""
    return sorted(os.path.basename(os.path.dirname(path)) for path in glob.glob(os.path.join(ROOT, "scenes/levels/sectors/*/*_layout.tscn")))


def game_starts():
    return sorted(stem(path) for path in glob.glob(os.path.join(ROOT, "database/registry/game_starts/*.tres")) if stem(path) != "start_evolution")


def saves():
    """The saves of the game and of test starts, newest first, as paths under Godot's user://."""
    from . import evolution
    found = []
    for folder in ("savegames", "test_start_saves"):
        found += glob.glob(os.path.join(evolution.user_dir(), folder, "*.sav"))
    found.sort(key=os.path.getmtime, reverse=True)
    return ["newest"] + [os.path.relpath(path, evolution.user_dir()) for path in found]


def _test_start(v):
    return godot("test_start=" + v["start"], *(["test_fresh"] if yes(v["fresh"]) else []))


def _save_report(v):
    return godot_script("tools/save_report.gd", *([] if v["save"] == "newest" else ["save=user://" + v["save"]]))


def next_version():
    """The last release's version (git tags v<version>) with its last number one higher; 0.1.0 at first."""
    try:
        tags = subprocess.run(["git", "tag", "--list", "v*", "--sort=-v:refname"], cwd=ROOT, stdout=subprocess.PIPE,
                              stderr=subprocess.DEVNULL, text=True).stdout.split()
    except OSError:
        tags = []
    numbers = next((tag[1:].split(".") for tag in tags if all(part.isdigit() for part in tag[1:].split("."))), None)
    if not numbers:
        return "0.1.0"
    numbers[-1] = str(int(numbers[-1]) + 1)
    return ".".join(numbers)


def draft_folders():
    """Evolution's draft folders (database/drafts/era<N>_min<k>), by era."""
    return sorted(os.path.basename(path) for path in glob.glob(os.path.join(ROOT, "database/drafts/era*")) if os.path.isdir(path))


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


EVOLUTION_OPTIONS = ("probe", "frozen", "save_dir", "save_every", "backup_every")  # Passed on to evolution_sim.gd


def evolution_sim_args(v):
    """evolution_sim.gd's options for the evolution task's answers (--frozen starts a new run: --new)."""
    args = ["--hours=" + v["hours"], "--speed=" + v["speed"]]
    if yes(v.get("probe", "no")):
        args.append("--probe")
    if yes(v.get("frozen", "no")):
        args += ["--frozen", "--new"]
    for key in ("save_dir", "save_every", "backup_every"):
        if str(v.get(key, "")).strip():
            args.append("--%s=%s" % (key.replace("_", "-"), v[key].strip()))
    return args


def _evolution(v):
    """Goes on with the saved evolution; a new era or a new evolution goes through new_era (backups first).
    Detached (evolution.go_on) unless followed in the terminal, where ctrl+c kills it unsaved."""
    if yes(v["follow"]):
        return godot_script("tools/evolution_sim.gd", "--", *evolution_sim_args(v))
    return ["python3", "tools/devtool/evolution.py", "go_on"] + ["%s=%s" % (key, v[key]) for key in ("hours", "speed") + EVOLUTION_OPTIONS
                                                                  if str(v.get(key, "")).strip() not in ("", "no")]


def _evolution_check(v):
    if yes(v.get("frozen", "no")) and not str(v.get("save_dir", "")).strip():
        return ["A frozen run needs its own save folder (never the game's saves): give Save folder, e.g. user://frozen/"]
    return []


def validate_sections():
    """ContentValidator.SECTIONS, read from its script."""
    try:
        with open(os.path.join(ROOT, "src/core/validation/content_validator.gd")) as handle:
            for line in handle:
                if line.startswith("const SECTIONS"):
                    return re.findall(r'"([a-z_]+)"', line)
    except OSError:
        pass
    return []


def _era_default(part):
    def default():
        from . import evolution
        number, label, _ = evolution.era(evolution.evolution_dir())
        return {"era": str(number) if number else "", "label": label}[part]
    return default


def _new_era(v):
    return ["python3", "tools/devtool/evolution.py"] + ["%s=%s" % (key, v[key]) for key in
                                                       ("era", "label", "next", "kind", "hours", "speed", "min_lives", "redo_drafts", "commit", "start")]


def _lance_duel(v):
    command = godot_script("tools/lance_duel.gd", "--", "--duels=" + v["duels"], "--speed=" + v["speed"])
    if v["match"]:
        command.append("--match=" + v["match"])
    if yes(v["weapons"]):
        command.append("--weapons")
    if str(v.get("rate", "")).strip():
        command.append("--rate=" + v["rate"])
    return command


def _duel(v):
    return godot_script("tools/lance_duel.gd", "--", "--duels=" + v["duels"], "--speed=" + v["speed"],
                        "--archetypes=%s,%s" % (v["a"], v["b"]))


def _export_presets(v):
    command = godot_script("tools/export_presets.gd", "--", "--top=" + v["top"], "--min-lives=" + v["min_lives"])
    for key in ("save", "out"):
        if str(v.get(key, "")).strip():
            command.append("--%s=%s" % (key, v[key].strip()))
    return command + (["--clean"] if yes(v["clean"]) else [])


def _pick_archetypes(v):
    folder = v["folder"]
    era = folder[len("era"):].split("_")[0]
    command = godot_script("tools/pick_archetypes.gd", "--", "--from=res://database/drafts/%s/" % folder, "--era=" + era)
    return command + (["--add"] if yes(v["add"]) else [])


def _flight_shots(v):
    command = godot("res://tools/flight_shots.tscn", "out=" + out_file("flight"), "wait=" + v["wait"])
    if v["near"] != "none":
        command.append("near=" + v["near"])
    return command + (["nebula=1"] if yes(v["nebula"]) else [])


def _harpoon_probe(v):
    command = godot("res://tools/harpoon_probe.tscn", "seconds=" + v["seconds"], "dist=" + v["dist"])
    if v["target"] == "chunk":
        command.append("target=chunk")
    if str(v.get("lance", "")).strip():
        command.append("lance=" + v["lance"])
    return command + [flag for flag in ("approach", "full") if yes(v[flag])]


def _render_preview(v):
    return godot("-s", "tools/render_preview.gd", "scene=" + res(v["scene"])[:-len(".tscn")],
                 "out=" + out_file(stem(v["scene"]) + "_preview.png"), "radius=" + v["radius"], "distances=" + v["distances"],
                 "tile=" + v["tile"], "time=" + v["time"])


TASKS = [
    # Checks
    Task("tests", "Checks", "Run the tests", "Every GUT test (content rules and models included). Godot compiles each test"
         " script first and names any that does not parse (GUT would hang on it); about 10 minutes on a laptop.",
         lambda v: ["python3", "tools/devtool/test_run.py"] + (["dir=" + res(v["dir"])] if v["dir"] else [])
         + (["file=" + os.path.basename(v["file"])] if v.get("file") else []),
         [Ask("dir", "Only this test folder (empty: all)", default="", optional=True),
          Ask("file", "Only this test file (empty: all in the folder)", "file", "", globs=["src/tests/**/test_*.gd"], optional=True, fresh=True)]),
    Task("validate", "Checks", "Check the content rules", "Every content rule (ContentValidator) at once, problems listed.",
         lambda v: godot_script("tools/devtool/validate.gd", *(["--", v["section"]] if v.get("section", "all") != "all" else [])),
         [Ask("section", "Sections", "choice", "all", lambda: ["all"] + validate_sections())]),
    Task("check_model", "Checks", "Check a model scene", "A ship or station scene against the model rules (CONTENT.md, Models).",
         _check_model, [Ask("scene", "Scene", "file", globs=MODEL_SCENES)]),
    Task("fix_loops", "Checks", "Fix sound loops", "Sets each sound's import loop setting to what its sound bank slot asks, and imports it again.",
         lambda v: ["python3", "tools/devtool/sounds.py"]),
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
                         Ask("ratio", "LOD ratio", "float", default="0.7"), Ask("levels", "LOD levels", "int", default="3")]),
    Task("open_blender", "Models", "Open a model in Blender", "Blender 3.6 (BLENDER, else tools/blender, else blender on PATH) with the file.",
         lambda v: blender(v["model"]), [Ask("model", "Model", "file", globs=["assets/models/**/*.blend"])]),
    Task("model_sheet", "Models", "Model review sheet", "One model in every faction's paint (across) at every LOD (down), to .dev/out/.",
         _model_sheet, [Ask("scene", "Scene", "file", globs=MODEL_SCENES)]),
    Task("placeholder_sheet", "Models", "Placeholder hull sheet", "Every placeholder hull in a faction's paint, its archetype's parts at its hardpoints, to .dev/out/.",
         lambda v: godot("res://tools/hull_sheet.tscn", "out=" + out_file("placeholders_%s.png" % v["faction"]), "faction=" + v["faction"], "fits=1"),
         [Ask("faction", "Faction", "choice", "verdant", factions)]),
    Task("starters", "Models", "Rebuild the starter .blends", "After changing the material library (assets/art/materials_generic/); the Overview says when.",
         lambda v: blender("-b", "-P", "tools/make_starters.py")),
    Task("bake_hits", "Models", "Bake every hit surface", "For every ship model in use (after changing LOD settings).",
         lambda v: godot_script("tools/bake_hit_shapes.gd")),
    Task("lods", "Models", "Make LODs for a .glb", "Levels of detail only (import_model does this for ships).",
         lambda v: blender("-b", "-P", "tools/generate_lods.py", "--", "--levels", v["levels"], "--ratio", v["ratio"], v["model"]),
         [Ask("model", "Model", "file", globs=["assets/models/**/*.glb"]), Ask("ratio", "Ratio", "float", default="0.5"), Ask("levels", "Levels", "int", default="3")]),
    Task("paint_patterns", "Models", "Paint pattern library", "Regenerates the faction paint patterns and their contact sheet.",
         lambda v: ["python3", "tools/generate_paint_patterns.py", "--library"]),
    # Content (derived data: put right after a change; the Overview says when)
    Task("apply_laws", "Content", "Apply the ship laws", "Rewrites the part catalogue and hand-made ships from their law genes (after editing law_genes or a law; the Overview says when).",
         lambda v: godot_script("tools/apply_laws.gd")),
    Task("refit_archetypes", "Content", "Refit the archetypes", "The archetypes take the part catalogue and the laws as they are now (after changing either; the Overview says when).",
         lambda v: godot_script("tools/refit_archetypes.gd")),
    Task("classify_presets", "Content", "Classify presets + CATALOG.md", "Labels the archetypes and drafts and rewrites database/presets/CATALOG.md (after a draft export or a classifier change; the Overview says when).",
         lambda v: godot_script("tools/classify_presets.gd", *(["--", "--check"] if yes(v.get("check", "no")) else [])),
         [Ask("check", "Only say what is out of date (writes nothing)", "flag", "no", fresh=True)]),
    # Balance
    Task("duel", "Balance", "Duel two archetypes", "Two archetypes as the game flies them, one on one: wins, time, hull left, rounds.",
         _duel, [Ask("a", "First (Verdant)", "choice", "fighter_light", archetypes), Ask("b", "Second (Violet)", "choice", "raider_light", archetypes),
                 Ask("duels", "Duels", "int", default="6"), Ask("speed", "Speed", "float", default="6")]),
    Task("economy", "Balance", "Sector economy", "A sector's market, trade routes timed for a ship (WP an hour), every hull's trading,"
         " problems (stock that pays nowhere, buy-and-sell-back loops) and what 0.x has yet to estimate. Also World: Economy.",
         lambda v: ["python3", "tools/devtool/economy.py", "sector=" + v["sector"], "ship=" + v["ship"]],
         [Ask("sector", "Sector", "choice", "sector_elace", sectors), Ask("ship", "Ship to time routes for", "choice", "trader_medium", archetypes)]),
    # Look
    Task("render_preview", "Look", "Render preview", "A scene from a few distances, side by side, to .dev/out/.",
         _render_preview, [Ask("scene", "Scene", "file", globs=["scenes/**/*.tscn"]), Ask("radius", "Object size (m)", "float", default="100"),
                           Ask("distances", "Distances (in sizes)", default="3,10,40"),
                           Ask("tile", "Pixels a view", "int", default="400"),
                           Ask("time", "Seconds before the shot (TIME-driven shaders move)", "float", default="1")]),
    # Game
    Task("play", "Game", "Play", "Runs the game in a window.", lambda v: godot()),
    Task("test_start", "Game", "Play a test start", "The game from a game start of your choice (Data, Game starts: ship, haven, bank, kit,"
         " standings), saved apart from the real saves.",
         _test_start, [Ask("start", "Game start", "choice", "start_default", game_starts),
                       Ask("fresh", "Delete the test saves first (a new game)", "flag", "yes")]),
    Task("save_report", "Game", "Save report", "What a save holds, in words: ship, fit, hold, bank, storage, standings, travellers.",
         _save_report, [Ask("save", "Save", "choice", "newest", saves)]),
    Task("editor", "Game", "Open the Godot editor", "Godot 3.6's editor, to compose a scene's look (the tool places, creates and links: World, Data).",
         lambda v: godot("-e")),
    Task("apk", "Game", "Export the debug APK", "Android debug build to $GDTLANCER_APK (" + APK + ").",
         lambda v: godot("--no-window", "--export-debug", "Android", APK)),
    # Maintainer: evolution, releases, probes (docs/MAINTAINING.md); the menu hides these until m
    Task("selftest", "Maintainer", "Test the development tool", "The tool's own Python tests (its Godot side is in the GUT tests).",
         lambda v: ["python3", "tools/dev.py", "selftest"]),
    Task("soak", "Maintainer", "Soak the game", "The real game left running (a new game in Elace, docked at home, 1x): fails on errors,"
         " orphaned nodes or memory growing, wrecks over their caps, bookkeeping growing. Frame rates printed. Needs a display.",
         lambda v: ["python3", "tools/devtool/soak.py", "minutes=" + v["minutes"], "every=" + v["every"]],
         [Ask("minutes", "Minutes (real time)", "float", default="5"), Ask("every", "Seconds between report lines", "float", default="30")]),
    Task("export_presets", "Maintainer", "Export presets from evolution", "The fittest designs of evolution's save as drafts, in database/drafts/export/ (pick_archetypes takes archetypes from drafts).",
         _export_presets, [Ask("top", "Archetypes", "int", default="60"), Ask("min_lives", "Minimum lives", "int", default="10"),
                           Ask("clean", "Empty database/drafts/export/ first", "flag", "no"),
                           Ask("save", "From this save (empty: evolution's, user://evolution/save_0.sav)", default="", optional=True, fresh=True),
                           Ask("out", "To this folder (empty: res://database/drafts/export/)", default="", optional=True, fresh=True)]),
    Task("pick_archetypes", "Maintainer", "Pick archetypes from drafts", "Each archetype the drafts folder has a design for is replaced by it; then classify_presets.",
         _pick_archetypes, [Ask("folder", "Drafts folder", "choice", lambda: max(draft_folders(), key=lambda name: (int(name.split("_")[0][len("era"):]), name.endswith("min10")), default=""), draft_folders),
                            Ask("add", "Also make archetypes there are none of yet", "flag", "no")]),
    Task("evolution", "Maintainer", "Run evolution (headless)", "Goes on with the saved evolution, detached: the menu comes back, the Tools"
         " tab shows it and x stops it (it saves first). A new era: new_era.",
         _evolution, [Ask("hours", "Simulated hours (0: until stopped)", "float", default="1"), Ask("speed", "Speed", "float", default="6"),
                      Ask("follow", "Run it in this terminal instead (ctrl+c kills it, unsaved time lost)", "flag", "no", fresh=True),
                      Ask("probe", "List NPCs stuck in one activity (every 10 simulated minutes)", "flag", "no", fresh=True),
                      Ask("frozen", "Play mode instead: the game's presets, watched headless (a new run; needs a save folder)", "flag", "no", fresh=True),
                      Ask("save_dir", "Save folder (empty: evolution's; another keeps a run apart)", default="", optional=True, fresh=True),
                      Ask("save_every", "Simulated minutes between saves (empty: 15)", "float", default="", optional=True),
                      Ask("backup_every", "Simulated hours between backups (empty: 2)", "float", default="", optional=True)],
         check=_evolution_check),
    Task("new_era", "Maintainer", "New era (backs up first)",
         "Backs up the save, exports its drafts, rewrites the catalog and commits them, then starts the next era.",
         _new_era, [Ask("era", "This era's number", "int", default=_era_default("era"), fresh=True),
                    Ask("label", "This era's name (its backup and drafts)", default=_era_default("label"), fresh=True),
                    Ask("next", "The next era's name (what changed)"),
                    Ask("kind", "Next era: era (genomes stay, their records start over) or fresh (a new evolution)", "choice", "era", ["era", "fresh"]),
                    Ask("hours", "Simulated hours (0: until stopped)", "float", default="20"), Ask("speed", "Speed", "float", default="8"),
                    Ask("min_lives", "Drafts for these minimum lives", default="10,5"),
                    Ask("redo_drafts", "Export again over this era's drafts if they exist (they may be edited)", "flag", "no", fresh=True),
                    Ask("commit", "Commit the drafts and catalog", "flag", "yes"),
                    Ask("start", "Start the next era now", "flag", "yes")]),
    Task("evolution_report", "Maintainer", "Evolution report", "Summary of the newest evolution life log.",
         lambda v: ["python3", "tools/evolution_report.py"] + (["--last-hours", v["hours"]] if v["hours"] else []),
         [Ask("hours", "Only the last hours (empty: all)", "float", default="", optional=True)]),
    Task("balance_sim", "Maintainer", "Battle balance sim", "A headless faction battle by the home station: kills, fight times, damage.",
         lambda v: godot_script("tools/balance_sim.gd")),
    Task("lance_duel", "Maintainer", "Lance duels", "Designs fight one on one; what the lance did.",
         _lance_duel, [Ask("duels", "Duels per match", "int", default="8"), Ask("speed", "Speed", "float", default="6"),
                       Ask("match", "Only this match (e.g. lancer,laser; empty: all)", default="", optional=True),
                       Ask("weapons", "Missile and cannon designs", "flag", "no"),
                       Ask("rate", "Physics steps a game second (empty: the project's)", "int", default="", optional=True)]),
    Task("perf", "Maintainer", "Performance ablation", "Frame times with one system switched off.",
         lambda v: godot_script("tools/perf_ablation.gd", "mode=" + v["mode"]),
         [Ask("mode", "Mode", "choice", "base", PERF_MODES)]),
    Task("fight_bench", "Maintainer", "Fight bench", "Frame times and profiler sections in a staged fight by the home station.",
         lambda v: godot_script("tools/fight_bench.gd", "n=" + v["n"], "secs=" + v["secs"]),
         [Ask("n", "Ships a side", "int", default="8"), Ask("secs", "Seconds measured", "int", default="30")]),
    Task("ui_shots", "Maintainer", "UI screenshots", "Every store tab and prompt, the SHIP and PILOT windows, with control dumps, to .dev/out/ui/.",
         lambda v: godot("res://tools/ui_shots.tscn", "out=" + out_file("ui"))),
    Task("flight_shots", "Maintainer", "Flight screenshots", "The HUD in flight, plain and with the nearest ship selected, to .dev/out/flight/.",
         _flight_shots, [Ask("wait", "Seconds of flight first", "float", default="12"),
                         Ask("near", "Start near a ship of this faction", "choice", "none", lambda: ["none"] + factions()),
                         Ask("nebula", "A nebula ahead", "flag", "no")]),
    Task("sound_probe", "Maintainer", "Sound probe", "Undocks and prints every playing sound each second.",
         lambda v: godot("res://tools/sound_probe.tscn", "seconds=" + v["seconds"], "plan=" + v["plan"],
                         *(["near=" + v["near"]] if v.get("near", "none") != "none" else [])),
         [Ask("seconds", "Seconds", "float", default="20"), Ask("plan", "What the ship does", "choice", "line", ["line", "approach", "docked"]),
          Ask("near", "Start 2.5 km off the nearest ship of this faction", "choice", "none", lambda: ["none"] + factions())]),
    Task("harpoon_probe", "Maintainer", "Harpoon probe", "Fires the player's harpoon at a nearby target and prints the tether each second.",
         _harpoon_probe, [Ask("seconds", "Seconds", "float", default="30"), Ask("dist", "Start distance (m)", "float", default="150"),
                          Ask("target", "Target", "choice", "wreck", ["wreck", "chunk"]),
                          Ask("lance", "Lance strike damage: what it breaks off the biggest rock (empty: none)", "float", default="", optional=True),
                          Ask("approach", "Approach first", "flag", "no"), Ask("full", "Cargo hold full", "flag", "no")]),
    Task("release", "Maintainer", "Release a version", "Tests, a soak, versions the Android build, exports GDTLancer-<version>.apk, commits and tags"
         " (nothing is pushed). Needs a clean working tree.",
         lambda v: ["python3", "tools/devtool/release.py", "version=" + v["version"], "tests=" + v["tests"], "soak=" + v["soak"],
                    "tag=" + v["tag"], "out=" + os.path.dirname(APK)],
         [Ask("version", "Version", default=next_version, fresh=True), Ask("tests", "Run the tests first", "flag", "yes"),
          Ask("soak", "Soak minutes first (the game left running; 0: none)", "float", default="3"),
          Ask("tag", "Tag it v<version>", "flag", "yes")]),
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


def program_problem(command):
    """What stops `command` running: its Godot or Blender missing or of the wrong version ("" if none).
    import_model.sh runs both: Blender for a .blend or a ship (fitting, LODs), Godot for the rest."""
    parts = [str(part) for part in command]
    first = parts[0] if parts else ""
    importing = any(part.endswith("import_model.sh") for part in parts)
    if (first == GODOT or importing) and godot_problem():
        return godot_problem()
    needs_blender = importing and (any(part.endswith(".blend") for part in parts) or "--station" not in parts)
    if (first == BLENDER or needs_blender) and blender_problem():
        return blender_problem()
    return ""


def missing(task, values):
    return [ask.label for ask in task.asks if not ask.optional and str(values.get(ask.key, "")).strip() == ""]


def invalid(task, values):
    """What is wrong with the answers given (Ask.problem), one line each."""
    wrong = [problem for ask in task.asks for problem in [ask.problem(values.get(ask.key, ""))] if problem]
    return wrong + (list(task.check(values)) if task.check else [])


def run(task, values, dry=False):
    """Builds and runs `task`'s command from the project folder; returns its exit code."""
    lacking = missing(task, values)
    if lacking:
        print("Missing: " + ", ".join(lacking))
        return 2
    wrong = invalid(task, values)
    if wrong:
        print("\n".join(wrong))
        return 2
    command = task.build(values) if not dry or task.key != "new_model" else ["(copies a starter, then)", BLENDER]
    if command is None:
        return 0
    print("$ " + " ".join(shlex.quote(str(part)) for part in command), flush=True)
    if dry:
        return 0
    problem = program_problem(command)
    if problem:
        print(problem)
        return 127
    try:
        return subprocess.call([str(part) for part in command], cwd=ROOT, env=environment())
    except FileNotFoundError as error:
        print("Not found: %s" % error.filename)
        return 127
    except KeyboardInterrupt:
        return 130
