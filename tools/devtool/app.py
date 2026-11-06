"""
The development tool's menu (Textual): the project's content and its checks in one place.

    Overview   every content rule (ContentValidator), models to re-import, stale starters, sound
               loops, data changed in git
    Models     every ship and station model: its files, who uses it, its check; import, open, review
    Archetypes the fifteen designs side by side as the game flies them (fitted mass, speed, guns),
               their pilots' genes against evolution's ranges, and who flies each
    Factions   who is at war with whom (toggled in a matrix), each faction's roster and havens
    Parts      weapons, modules, commodities and the starting kit side by side, with who uses each
    Look       shaders (shared blocks in date, who uses each), faction paints, paint patterns, music
    Data       every data file by kind (the material library too), edited in a form made from its
               script or shader; new, delete (only what nothing names); each save is checked
    World      each sector: its scene's bodies and belts and its layout's markers (havens, beacons,
               hazards) on a map, each in a form; add, copy, remove; new sectors, copies of one, new
               bodies, all named by the sector rules (SectorNames); each save is checked
    Constants  src/autoload/Constants.gd by section or by kind of value; values changed in place,
               Godot checks the script before it is saved
    Tools      evolution, the APK and the newest outputs at a glance; every tool (tasks.py) to run

Godot does the reading, writing and checking (bridge.py), so the files stay as Godot writes them.
Keys are listed in the footer and on the help screen (?).
"""

import glob
import json
import os
import subprocess

from textual import on, work
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.screen import ModalScreen
from textual.suggester import SuggestFromList
from textual.message import Message
from textual.widgets import (Button, DataTable, Footer, Header, Input, Label, Select, SelectionList, Static, Switch,
                             TabbedContent, TabPane, TextArea, Tree)

from . import constants, data, evolution, models, tasks, worldmap
from .bridge import Bridge, BridgeError, file_path

RESOURCE_FILES = {  # Resource type -> the files a field of it can point at
    "PackedScene": ("*.tscn",), "AudioStream": ("*.wav", "*.ogg", "*.mp3"), "Material": ("*.tres",),
    "ShaderMaterial": ("*.tres",), "Texture": ("*.png",), "Resource": ("*.tres",), "Shader": ("*.gdshader",),
}
SKIPPED_DIRS = (".git", ".import", ".dev", "addons")
SECTOR_SCENES = "scenes/levels/sectors/*/*.tscn"  # A sector is its folder's <folder>.tscn; its layout <folder>_layout.tscn
MARKERS = "res://src/scenes/game_world/sector_layout/markers/"
GROUP_MARKERS = {"Havens": "haven_marker.gd", "Beacons": "beacon_marker.gd", "Hazards": "hazard_marker.gd"}
COPY_OFFSET = 2000.0  # m along x between a marker and its copy
SCENE = "@"  # World keys of what the sector scene places: "@" + its node path; "@" alone: the group
BODY_SCENES = "scenes/levels/sectors/*/*/*.tscn"  # A body is its folder's <folder>.tscn (SectorNames)
PREFABS = "scenes/prefabs/celestial/*.tscn"  # Shared celestial scenes a sector places as often as it likes
BODY_KINDS = ("star", "planet", "moon", "belt")
SECTORS_DIR = "res://scenes/levels/sectors/"
LOCATIONS_DIR = "res://database/registry/locations/"


def home_sector():
    """The game's home sector (Constants INITIAL_SECTOR_ID)."""
    import re
    found = re.search(r'^const INITIAL_SECTOR_ID: String = "([^"]+)"', read_text("res://src/autoload/Constants.gd"), re.M)
    return found.group(1) if found else ""


def body_scenes():
    """[(res path, is a star)] of every sector's bodies (<folder>/<folder>.tscn), to make a new one like."""
    out = []
    for path in sorted(glob.glob(os.path.join(tasks.ROOT, BODY_SCENES))):
        if os.path.basename(path) != os.path.basename(os.path.dirname(path)) + ".tscn":
            continue  # A body's part (a star's sprite)
        with open(path, errors="ignore") as handle:
            out.append(("res://" + os.path.relpath(path, tasks.ROOT), "is_star = true" in handle.read()))
    return out


def prefab_scenes():
    return ["res://" + os.path.relpath(path, tasks.ROOT) for path in sorted(glob.glob(os.path.join(tasks.ROOT, PREFABS)))]


def own_body(scene, sector):
    """(kind, suffix) if `scene` is one of `sector`'s own bodies (by the naming rules), else None."""
    folder = SECTORS_DIR + sector + "/"
    if not scene.startswith(folder) or scene.count("/") != folder.count("/") + 1:
        return None
    stem = os.path.basename(scene)[:-len(".tscn")]
    word = sector[len("sector_"):]
    for kind in BODY_KINDS:
        head = "%s_%s" % (kind, word)
        if stem == head or stem.startswith(head + "_"):
            return kind, stem[len(head) + 1:]
    return None


def folder_texts(scene):
    """[(path, text)] of the files in a body scene's folder (for ctrl+u, before it goes)."""
    folder = os.path.dirname(file_path(scene))
    out = []
    for name in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
        if os.path.isfile(os.path.join(folder, name)):
            out.append((os.path.dirname(scene) + "/" + name, read_text(os.path.dirname(scene) + "/" + name)))
    return out


def sector_scenes():
    """Absolute paths of the sector scenes (scenes/levels/sectors/<sector>/<sector>.tscn), sorted."""
    return [path for path in sorted(glob.glob(os.path.join(tasks.ROOT, SECTOR_SCENES)))
            if os.path.basename(path) == os.path.basename(os.path.dirname(path)) + ".tscn"]


def title_of(scene):
    """A node name for a new instance of `scene`: "planet_elace_d.tscn" -> "Planet Elace D"."""
    return " ".join(word.capitalize() if len(word) > 1 else word.upper() for word in os.path.basename(scene)[:-5].split("_"))
FAMILIES = ["fighter", "lance", "raider", "prospector", "scavenger"]
WEIGHTS = ["light", "medium", "heavy"]
GENE_BAR = 30  # Characters of a gene's bar


def archetype_order(name):
    family, _, weight = name.rpartition("_")
    return (FAMILIES.index(family) if family in FAMILIES else len(FAMILIES), family,
            WEIGHTS.index(weight) if weight in WEIGHTS else len(WEIGHTS))


def gene_bar(value, low, high, default):
    """A gene's value on a bar from `low` to `high`: = up to it, | at the default."""
    def column(x):
        return min(GENE_BAR - 1, max(0, int(round((x - low) / max(high - low, 1e-9) * (GENE_BAR - 1)))))
    cells = ["=" if index <= column(value) else "-" for index in range(GENE_BAR)]
    cells[column(default)] = "|"
    return "".join(cells)


def swatch(color):
    """Two blocks in a colour ({"v": [r, g, b, a]}), as markup."""
    if not isinstance(color, dict) or "v" not in color:
        return "  "
    r, g, b = [max(0, min(255, int(c * 255))) for c in color["v"][:3]]
    return "[rgb(%d,%d,%d)]██[/]" % (r, g, b)


def project_files(patterns):
    """res:// paths of project files matching any of `patterns` (e.g. "*.tres")."""
    import fnmatch
    out = []
    for folder, dirs, names in os.walk(tasks.ROOT):
        dirs[:] = [d for d in dirs if d not in SKIPPED_DIRS]
        for name in names:
            if any(fnmatch.fnmatch(name, pattern) for pattern in patterns):
                out.append("res://" + os.path.relpath(os.path.join(folder, name), tasks.ROOT))
    return sorted(out)


def same(a, b):
    return json.dumps(a, sort_keys=True) == json.dumps(b, sort_keys=True)


def read_text(path):
    with open(file_path(path)) as handle:
        return handle.read()


def write_text(path, text):
    with open(file_path(path), "w") as handle:
        handle.write(text)


def plural(count, word):
    return "%d %s%s" % (count, word, "" if count == 1 else "s")


def open_file(path):
    """Opens a file in the desktop's program for it."""
    try:
        subprocess.Popen(["xdg-open", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


def newest_files(folder, count, skip=(".import",)):
    out = []
    for base, _dirs, names in os.walk(folder) if folder and os.path.isdir(folder) else []:
        out += [os.path.join(base, name) for name in names if not name.endswith(skip)]
    return sorted(out, key=os.path.getmtime, reverse=True)[:count]


def age(path):
    import time
    seconds = max(0, time.time() - os.path.getmtime(path))
    for unit, size in (("d", 86400), ("h", 3600), ("min", 60)):
        if seconds >= size:
            return "%d %s ago" % (seconds // size, unit)
    return "just now"


def tools_status(evolution_dir):
    """Evolution, the APK and the newest outputs, as markup lines."""
    lines = []
    if evolution_dir is None:
        lines.append("[b]Evolution[/b]: (waiting for Godot to say where user:// is)")
    else:
        status_file = os.path.join(evolution_dir, "status.json")
        info = evolution.status(evolution_dir)
        number, label, guessed = evolution.era(evolution_dir)
        era_text = ("era %d%s%s" % (number, " (%s)" % label if label else "", ", guessed from backup names" if guessed else "")) if number else "era unknown"
        if info and info["running"]:
            lines.append("[b]Evolution[/b]: [green]running[/green] %s, t=%.1f h, %s lives, %s genomes, pace x%.1f (updated %s) · x asks it to stop"
                         % (era_text, float(info.get("game_time", 0)) / 3600.0, info.get("lives", "?"), info.get("genomes", "?"),
                            float(info.get("pace", 0)), age(status_file)))
        else:
            ended = (", last run %s %s at t=%.1f h" % (info.get("state", "?"), age(status_file), float(info.get("game_time", 0)) / 3600.0)) if info else ""
            lines.append("[b]Evolution[/b]: stopped, %s%s · n starts a new era (backs up and exports first)" % (era_text, ended))
        save = os.path.join(evolution_dir, "save_0.sav")
        backups = newest_files(os.path.join(evolution_dir, "backups"), 1)
        logs = newest_files(os.path.join(evolution_dir, "logs"), 1)
        lines.append("  save %s · newest backup %s · newest life log %s" % (
            age(save) if os.path.exists(save) else "none", ("%s, %s" % (os.path.basename(backups[0]), age(backups[0]))) if backups else "none",
            age(logs[0]) if logs else "none"))
    if os.path.exists(tasks.APK):
        lines.append("[b]APK[/b]: %s, %.0f MB, exported %s" % (tasks.APK, os.path.getsize(tasks.APK) / 1e6, age(tasks.APK)))
    else:
        lines.append("[b]APK[/b]: none at %s (Tools: apk)" % tasks.APK)
    newest = newest_files(tasks.OUT_DIR, 3)
    lines.append("[b]Newest outputs[/b] (.dev/out/, o opens the first): " + (", ".join("%s (%s)" % (os.path.relpath(path, tasks.OUT_DIR), age(path))
                                                                                    for path in newest) if newest else "none yet"))
    return "\n".join(lines)


# --- Form fields ----------------------------------------------------------------------------------

class Special:
    """How one field gets an editor of its own instead of the generic one: `choices` for a text
    field picked from a list, or `pairs` for a {key: number} dictionary edited row by row."""

    def __init__(self, choices=None, pairs=None, integer=False, default=1, about=None, total=None, any_key=None):
        self.choices = choices or []  # [(value, label)]
        self.pairs = pairs  # [(key, label)] the rows' keys come from; None: not a pairs editor
        self.integer, self.default = integer, default
        self.about = about  # (key, number) -> what that row means, e.g. its price
        self.total = total  # {key: number} -> a line under the rows
        self.any_key = any_key  # (key, label) offered first, e.g. ("*", "anything else")


class PairRow(Horizontal):
    DEFAULT_CSS = """
    PairRow { height: auto; }
    PairRow Select { width: 44; }
    PairRow Input { width: 14; }
    PairRow .pair-about { width: 1fr; padding: 1 1; color: $text-muted; }
    PairRow Button { min-width: 5; width: 5; }
    """

    def __init__(self, options, key, number, integer):
        super().__init__()
        self.options, self.key, self.number, self.integer = options, key, number, integer

    def compose(self) -> ComposeResult:
        options = list(self.options)
        if self.key not in [value for value, _ in options]:
            options.insert(0, (self.key, "%s [red](unknown)[/red]" % self.key))
        yield Select([(label, value) for value, label in options], value=self.key, allow_blank=False)
        yield Input(value=str(self.number), type="integer" if self.integer else "number")
        yield Static("", classes="pair-about")
        yield Button("×", classes="pair-remove", tooltip="Remove this row")

    def pair(self):
        text = self.query_one(Input).value.strip()
        if text == "":
            raise ValueError("a row has no number")
        return self.query_one(Select).value, int(text) if self.integer else float(text)


class PairsEditor(Vertical):
    """A {key: number} field as rows: a key picked from a list, its number, what it means, and a
    button to remove it; "+ Add" adds a row, a line under them sums them up."""

    DEFAULT_CSS = """
    PairsEditor { height: auto; }
    PairsEditor .pairs-rows { height: auto; }
    PairsEditor .pairs-bottom { height: auto; }
    PairsEditor .pairs-total { padding: 1 1; width: 1fr; }
    """

    def __init__(self, special, value):
        super().__init__()
        self.special = special
        self.start = dict(value) if isinstance(value, dict) else {}
        self.options = ([special.any_key] if special.any_key else []) + list(special.pairs)

    def compose(self) -> ComposeResult:
        with Vertical(classes="pairs-rows"):
            for key, number in self.start.items():
                yield PairRow(self.options, key, number, self.special.integer)
        with Horizontal(classes="pairs-bottom"):
            yield Button("+ Add", classes="pair-add")
            yield Static("", classes="pairs-total")

    def on_mount(self):
        self.call_after_refresh(self.refresh_notes)

    def rows(self):
        return list(self.query(PairRow))

    def value(self):
        out = {}
        for row in self.rows():
            key, number = row.pair()
            if key in out:
                raise ValueError("%s is listed twice" % key)
            out[key] = number
        return out

    @on(Button.Pressed, ".pair-add")
    def add_row(self, event=None):
        if event is not None:
            event.stop()
        used = {row.query_one(Select).value for row in self.rows()}
        free = [key for key, _ in self.options if key not in used]
        if not free:
            self.app.notify("Every one is listed already", severity="warning")
            return
        self.query_one(".pairs-rows").mount(PairRow(self.options, free[0], self.special.default, self.special.integer))
        self.call_after_refresh(self.refresh_notes)

    @on(Button.Pressed, ".pair-remove")
    def remove_row(self, event):
        event.stop()
        event.button.parent.remove()
        self.call_after_refresh(self.refresh_notes)

    @on(Select.Changed)
    @on(Input.Changed)
    def _changed(self, event):
        event.stop()
        self.refresh_notes()

    def refresh_notes(self):
        pairs = {}
        for row in self.rows():
            try:
                key, number = row.pair()
            except ValueError:
                row.query_one(".pair-about", Static).update("[red]a number[/red]")
                continue
            pairs[key] = number
            row.query_one(".pair-about", Static).update(self.special.about(key, number) if self.special.about else "")
        total = self.query(".pairs-total")
        if total:
            total.first().update(self.special.total(pairs) if self.special.total else "")


def applies(value, rule):
    """Whether a SHOWN_WHEN rule holds for the other field's value: [values], or {"not": [values]}."""
    if isinstance(rule, dict):
        return value not in rule.get("not", [])
    return value in rule


class FieldEditor(Vertical):
    """One field of a data file or scene node: its name, type and comment, and an editor fit for
    its type (or a Special one), with a notice if the game does not read it yet."""

    DEFAULT_CSS = """
    FieldEditor { height: auto; margin: 0 0 1 0; }
    FieldEditor .field-name { text-style: bold; }
    FieldEditor .field-about { color: $text-muted; }
    FieldEditor TextArea { height: 8; }
    FieldEditor .color-row { height: auto; }
    FieldEditor .color-row Input { width: 1fr; }
    FieldEditor .swatch { width: 8; height: 3; }
    FieldEditor .not-in-game { color: $warning; }
    """

    def __init__(self, field, value, special=None, notice=""):
        super().__init__()
        self.field, self.original = field, value
        self.special, self.notice = special, notice
        self.editor = None

    def compose(self) -> ComposeResult:
        field, value = self.field, self.original
        yield Label("%s  [dim]%s[/dim]" % (field["name"].replace("shader_param/", ""), self._type_label()), classes="field-name")
        if field.get("comment"):
            yield Label(field["comment"], classes="field-about")
        if self.notice:
            yield Label("%s: %s" % (data.NOT_IN_GAME_TITLE, self.notice), classes="not-in-game")
        kind = field["type"]
        hint = field.get("hint_name", "")
        special = self.special
        if special is not None and special.pairs is not None and kind == "Dictionary":
            self.editor = PairsEditor(special, value)
        elif special is not None and special.choices and kind == "Object":
            path = value.get("path", "") if isinstance(value, dict) else ""
            choices = list(special.choices)
            if path not in [c for c, _ in choices]:
                choices.insert(0, (path, "%s [red](not a station model)[/red]" % path if path else "(none)"))
            self.editor = Select([(label, choice) for choice, label in choices], value=path, allow_blank=False)
        elif special is not None and special.choices and kind == "String":
            choices = list(special.choices)
            if value not in [c for c, _ in choices]:
                choices.insert(0, (value, "%s [red](unknown)[/red]" % value if value else "(none)"))
            self.editor = Select([(label, choice) for choice, label in choices], value=value, allow_blank=False)
        elif kind == "bool":
            self.editor = Switch(value=bool(value))
        elif hint == "enum" and kind in ("String", "int"):
            options = [option.split(":")[0] for option in field.get("hint_string", "").split(",") if option != ""]
            choices = [(option, option if kind == "String" else index) for index, option in enumerate(options)]
            self.editor = Select(choices, value=value if value in [c[1] for c in choices] else Select.BLANK, allow_blank=False)
        elif kind in ("int", "float"):
            self.editor = Input(value=self._number_text(value), type="integer" if kind == "int" else "number")
        elif kind == "String":
            suggester = None
            if hint == "file":
                suggester = SuggestFromList(project_files(field.get("hint_string", "*").split(",")), case_sensitive=False)
            if hint == "multiline":
                self.editor = TextArea(str(value or ""))
            else:
                self.editor = Input(value=str(value or ""), suggester=suggester, placeholder="(empty)")
        elif kind in ("Color", "Vector3"):
            numbers = (value or {}).get("v", [1, 1, 1, 1] if kind == "Color" else [0, 0, 0])
            self.editor = Input(value=", ".join(self._number_text(c) for c in numbers),
                                placeholder="r, g, b, a (0..1)" if kind == "Color" else "x, y, z")
        elif kind == "Object":
            patterns = RESOURCE_FILES.get(field.get("hint_string", ""), ("*.tres", "*.tscn"))
            path = value.get("path", "") if isinstance(value, dict) else ""
            self.editor = Input(value=path, suggester=SuggestFromList(project_files(patterns), case_sensitive=False),
                                placeholder="(none) a res:// path to a %s" % (field.get("hint_string") or "resource"))
        elif kind in ("Array", "Dictionary") or kind.startswith("Pool"):
            self.editor = TextArea(json.dumps(value, indent=1), language="json")
        else:
            text = value.get("text", "") if isinstance(value, dict) else json.dumps(value)
            self.editor = Input(value=text, placeholder="Godot text, e.g. Vector2( 0, 0 )")
        if kind == "Color":
            with Horizontal(classes="color-row"):
                yield self.editor
                yield Static("", classes="swatch")
        else:
            yield self.editor

    def on_mount(self):
        self._paint_swatch()

    @on(Input.Changed)
    def _color_changed(self, _event):
        self._paint_swatch()

    def _paint_swatch(self):
        if self.field["type"] != "Color":
            return
        try:
            r, g, b = self._numbers(4)[:3]
            self.query_one(".swatch", Static).styles.background = "rgb(%d,%d,%d)" % (r * 255, g * 255, b * 255)
        except (ValueError, IndexError):
            pass

    def _type_label(self):
        hint = self.field.get("hint_string", "")
        return self.field["type"] + (" " + hint if hint and self.field["type"] == "Object" else "")

    @staticmethod
    def _number_text(value):
        return repr(value) if isinstance(value, float) else str(value if value is not None else 0)

    def _numbers(self, count):
        parts = [float(part) for part in self.editor.value.replace("(", " ").replace(")", " ").split(",") if part.strip()]
        if count == 4 and len(parts) == 3:
            parts.append(1.0)
        if len(parts) != count:
            raise ValueError("%s is %s" % (self.field["name"], "r, g, b, a" if count == 4 else "x, y, z"))
        return parts

    def value(self):
        """The edited value, encoded the way the bridge reads it; ValueError when it does not parse."""
        kind, editor = self.field["type"], self.editor
        if isinstance(editor, PairsEditor):
            return editor.value()
        if kind == "Object" and isinstance(editor, Select):
            return {"$": "Resource", "path": editor.value} if editor.value else None
        if kind == "bool":
            return bool(editor.value)
        if isinstance(editor, Select):
            return editor.value
        if kind == "int":
            return int(editor.value or 0)
        if kind == "float":
            return float(editor.value or 0)
        if kind == "String":
            return editor.text if isinstance(editor, TextArea) else editor.value
        if kind == "Color":
            return {"$": "Color", "v": self._numbers(4)}
        if kind == "Vector3":
            return {"$": "Vector3", "v": self._numbers(3)}
        if kind == "Object":
            path = editor.value.strip()
            if path and not os.path.exists(file_path(path)):
                raise ValueError("no file %s" % path)
            return {"$": "Resource", "path": path} if path else None
        if isinstance(editor, TextArea):
            try:
                return json.loads(editor.text)
            except ValueError as error:
                raise ValueError("not JSON: %s" % error)
        if isinstance(self.original, dict) and "$" in self.original:
            return {"$": self.original["$"], "text": editor.value}
        return json.loads(editor.value)

    def current(self):
        """value(), or the value as loaded while the editor does not parse (or a list has no pick yet, as it mounts)."""
        if isinstance(self.editor, Select) and type(self.editor.value).__name__ == "NoSelection":
            return self.original.get("path", "") if isinstance(self.original, dict) and self.field["type"] == "String" else self.original
        try:
            return self.value()
        except Exception:  # Does not parse, or is still being built
            return self.original

    def encoded(self):
        """value() as sent to the bridge: whole counts marked int, since JSON numbers reach Godot as floats."""
        value = self.value()
        if isinstance(self.editor, PairsEditor) and self.editor.special.integer:
            return {key: {"$": "int", "v": number} for key, number in value.items()}
        return value

    def changed(self):
        value = self.value()
        if self.field["type"] == "Object":
            before = self.original.get("path", "") if isinstance(self.original, dict) else ""
            return (value or {}).get("path", "") != before
        if self.field["type"] in ("Color", "Vector3") and isinstance(self.original, dict):
            return value["v"] != [float(c) for c in self.original.get("v", [])]
        return not same(value, self.original)


class Form(Vertical):
    """A title, a status line (the rules' verdict on the last save) and fields."""

    DEFAULT_CSS = """
    Form .form-title, Form .form-status { height: auto; min-height: 1; }
    """

    def __init__(self, hint, **kwargs):
        super().__init__(**kwargs)
        self.hint, self.fields = hint, []

    def compose(self) -> ComposeResult:
        yield Static(self.hint, classes="form-title")
        yield Static("", classes="form-status")
        yield VerticalScroll(classes="form-fields")

    def title(self, text):
        self.query_one(".form-title", Static).update(text)

    def show(self, title, fields, values, script=""):
        """`script`: the file's or node's script, for its special editors and not-in-game notices."""
        scroll = self.query_one(".form-fields", VerticalScroll)
        scroll.remove_children()
        specials = self.app.specials(script) if hasattr(self.app, "specials") else {}
        self.fields = [FieldEditor(field, values.get(field["name"], field.get("default")), specials.get(field["name"]),
                                   data.not_in_game(script, field["name"])) for field in fields]
        scroll.mount_all(self.fields)
        self.title(title)
        self.result(None)
        self.call_after_refresh(self.apply_when)

    def apply_when(self):
        """Hides the fields that do not apply with the others' values (the script's SHOWN_WHEN); the
        game does not read them then either."""
        ruled = [editor for editor in self.fields if editor.field.get("when") and editor.editor is not None]
        others = {other for editor in ruled for other in editor.field["when"]}
        values = {editor.field["name"]: editor.current() for editor in self.fields if editor.field["name"] in others}
        for editor in ruled:
            editor.display = all(applies(values.get(other), rule) for other, rule in editor.field["when"].items())

    def on_input_changed(self, _event):
        self.apply_when()

    def on_select_changed(self, _event):
        self.apply_when()

    def on_switch_changed(self, _event):
        self.apply_when()

    def clear(self, title):
        self.query_one(".form-fields", VerticalScroll).remove_children()
        self.fields = []
        self.title(title)
        self.result(None)

    def changes(self):
        """{field: value} of the fields changed; ValueError if one does not parse. A hidden field's
        edit is dropped: it does not apply."""
        return {editor.field["name"]: editor.encoded() for editor in self.fields if editor.display and editor.changed()}

    def result(self, result):
        status = self.query_one(".form-status", Static)
        if result is None:
            status.update("")
        elif result["problems"]:
            status.update("[red]Saved, but the rules find:[/red]\n" + "\n".join("- %s" % p["problem"] for p in result["problems"])
                          + "\n[dim]ctrl+u puts the file back as it was before this save.[/dim]")
        else:
            status.update("[green]Saved; every rule holds.[/green]")


# --- Dialogs --------------------------------------------------------------------------------------

class AskScreen(ModalScreen):
    """A task's questions as a form; dismisses with the answers, or None."""

    DEFAULT_CSS = """
    AskScreen { align: center middle; }
    AskScreen > Vertical { width: 90; height: auto; max-height: 90%; border: thick $accent; background: $surface; padding: 1 2; }
    AskScreen Label { margin-top: 1; }
    AskScreen #ask-buttons { height: auto; margin-top: 1; }
    """
    BINDINGS = [Binding("escape", "cancel", "Cancel")]

    def __init__(self, task, values):
        super().__init__()
        self.task_, self.values = task, values
        self.widgets = {}

    def compose(self) -> ComposeResult:
        with Vertical():
            yield Static("[b]%s[/b]\n%s" % (self.task_.title, self.task_.about))
            with VerticalScroll():
                for ask in self.task_.asks:
                    yield Label(ask.label)
                    current = str(self.values.get(ask.key, ask.default))
                    if ask.kind in ("choice", "flag", "file"):
                        options = [option for option in ask.options() if option != tasks.TYPE_A_PATH]
                        if current and current not in options:
                            options.insert(0, current)
                        widget = Select([(option, option) for option in options], value=current if current in options else Select.BLANK,
                                        allow_blank=ask.optional or not options)
                    else:
                        widget = Input(value=current)
                    self.widgets[ask.key] = widget
                    yield widget
            with Horizontal(id="ask-buttons"):
                yield Button("Run", variant="primary", id="run")
                yield Button("Cancel", id="cancel")

    @on(Button.Pressed, "#run")
    def _run(self):
        answers = {}
        for key, widget in self.widgets.items():
            value = widget.value
            answers[key] = "" if value is Select.BLANK or value is None else str(value)
        self.dismiss(answers)

    @on(Button.Pressed, "#cancel")
    def action_cancel(self):
        self.dismiss(None)


class NameScreen(ModalScreen):
    """Asks for one line (a new file's or node's name); dismisses with it, or None."""

    DEFAULT_CSS = """
    NameScreen { align: center middle; }
    NameScreen > Vertical { width: 70; height: auto; border: thick $accent; background: $surface; padding: 1 2; }
    """
    BINDINGS = [Binding("escape", "cancel", "Cancel")]

    def __init__(self, title, placeholder="lower_case_name"):
        super().__init__()
        self.title_, self.placeholder = title, placeholder

    def compose(self) -> ComposeResult:
        with Vertical():
            yield Label(self.title_)
            yield Input(placeholder=self.placeholder)

    @on(Input.Submitted)
    def _done(self, event):
        self.dismiss(event.value.strip() or None)

    def action_cancel(self):
        self.dismiss(None)


class BodyScreen(ModalScreen):
    """A new body for a sector, named by the rules (SectorNames): its kind and the body it is made
    like (a copy of its scene), a moon's planet, a belt's word; or a shared prefab placed as it is.
    Dismisses with {"kind", "from", "of", "word"} or {"kind": "prefab", "from", "name"}, or None."""

    DEFAULT_CSS = """
    BodyScreen { align: center middle; }
    BodyScreen > Vertical { width: 96; height: auto; border: thick $accent; background: $surface; padding: 1 2; }
    BodyScreen Label { margin-top: 1; }
    BodyScreen #body-buttons { height: auto; margin-top: 1; }
    """
    BINDINGS = [Binding("escape", "cancel", "Cancel")]
    KINDS = [("A new star", "star"), ("A new planet", "planet"), ("A new moon", "moon"), ("A new belt", "belt"), ("A shared prefab", "prefab")]
    RULE = {"star": "Named star_<sector>, then star_<sector>_b, c ...: the next free one.",
            "planet": "Named planet_<sector>_<letter>: the next free letter.",
            "moon": "Named moon_<sector>_<its planet's letter><number>: the planet's next moon.",
            "belt": "Named belt_<sector>_<word>: give the word (lower_snake_case).",
            "prefab": "Placed as it is (no copy); its node is named after it."}

    def __init__(self, title, planets, bodies, prefabs):
        super().__init__()
        self.title_, self.planets, self.bodies, self.prefabs = title, planets, bodies, prefabs

    def _sources(self, kind):
        if kind == "prefab":
            return self.prefabs
        if kind == "star":
            return [path for path, star in self.bodies if star]
        others = [path for path, star in self.bodies if not star]
        return sorted(others, key=lambda path: (not os.path.basename(path).startswith(kind + "_"), path))  # Its kind first

    def compose(self) -> ComposeResult:
        with Vertical():
            yield Label(self.title_)
            yield Select(self.KINDS, id="body-kind", allow_blank=False, value="planet")
            yield Label("Made like (a copy of its scene, to change in the Godot editor)", id="body-from-label")
            yield Select([], id="body-from", allow_blank=True)
            yield Label("Its planet", id="body-of-label")
            yield Select([("Planet " + letter.upper(), letter) for letter in self.planets], id="body-of", allow_blank=not self.planets,
                         value=self.planets[0] if self.planets else Select.BLANK)
            yield Label("Its word", id="body-word-label")
            yield Input(placeholder="deep", id="body-word")
            yield Static("", id="body-rule")
            with Horizontal(id="body-buttons"):
                yield Button("Make", id="body-ok", variant="primary")
                yield Button("Cancel", id="body-cancel")

    def on_mount(self):
        self._kind_shown("planet")

    @on(Select.Changed, "#body-kind")
    def _kind_changed(self, event):
        if event.value is not Select.BLANK:
            self._kind_shown(event.value)

    def _kind_shown(self, kind):
        sources = self._sources(kind)
        chooser = self.query_one("#body-from", Select)
        chooser.set_options([(path.replace("res://scenes/", ""), path) for path in sources])
        if sources:
            chooser.value = sources[0]
        for widget in ("#body-of-label", "#body-of"):
            self.query_one(widget).display = kind == "moon"
        for widget in ("#body-word-label", "#body-word"):
            self.query_one(widget).display = kind in ("belt", "prefab")
        self.query_one("#body-word-label", Label).update("Its node name" if kind == "prefab" else "Its word")
        if kind == "prefab" and sources:
            self.query_one("#body-word", Input).value = title_of(sources[0])
        self.query_one("#body-rule", Static).update("[dim]%s[/dim]" % self.RULE[kind])

    @on(Button.Pressed, "#body-ok")
    @on(Input.Submitted, "#body-word")
    def _done(self, _event):
        kind = self.query_one("#body-kind", Select).value
        source = self.query_one("#body-from", Select).value
        if source is Select.BLANK or source is None:
            self.notify("Nothing to make it like", severity="warning")
            return
        word = self.query_one("#body-word", Input).value.strip()
        if kind == "prefab":
            self.dismiss({"kind": kind, "from": source, "name": word or title_of(source)})
            return
        of = self.query_one("#body-of", Select).value
        if kind == "moon" and (of is Select.BLANK or of is None):
            self.notify("A moon needs a planet: make one first", severity="warning")
            return
        self.dismiss({"kind": kind, "from": source, "of": of if kind == "moon" else "", "word": word if kind == "belt" else ""})

    @on(Button.Pressed, "#body-cancel")
    def action_cancel(self, _event=None):
        self.dismiss(None)


class ConfirmScreen(ModalScreen):
    """A yes/no question; dismisses with True or False."""

    DEFAULT_CSS = """
    ConfirmScreen { align: center middle; }
    ConfirmScreen > Vertical { width: 70; height: auto; border: thick $warning; background: $surface; padding: 1 2; }
    ConfirmScreen Horizontal { height: auto; margin-top: 1; }
    """
    BINDINGS = [Binding("escape", "no", "No"), Binding("y", "yes", "Yes")]

    def __init__(self, question):
        super().__init__()
        self.question = question

    def compose(self) -> ComposeResult:
        with Vertical():
            yield Label(self.question)
            with Horizontal():
                yield Button("Yes (y)", variant="error", id="yes")
                yield Button("No", id="no")

    @on(Button.Pressed, "#yes")
    def action_yes(self):
        self.dismiss(True)

    @on(Button.Pressed, "#no")
    def action_no(self):
        self.dismiss(False)


HELP = """\
[b]Keys, the same on every tab[/b]
  1-9, 0      switch tabs                    ?          this help
  tab         next box in a tab              shift+tab  the box before
  enter       open or run what is picked     q          quit (not while typing)
  ctrl+s      save                           ctrl+u     undo the last save (every file it wrote)
  ctrl+r      refresh: read the files again  ctrl+n     new (file, marker, model)
  Plain letters are a tab's own actions (only on tabs where nothing is typed); the footer lists them.

[b]Tabs[/b]
  1 Overview    every content rule, checked; enter opens a problem's file
  2 Models      every ship and station model: import (i), open in Blender (o), review sheet (s)
  3 Archetypes  the fifteen designs as the game flies them; pilot genes against evolution's ranges
  4 Factions    wars (pick a cell, w), rosters (space ticks, ctrl+s), havens (enter: World)
  5 World       a sector: its scene's bodies and belts, its layout's markers, on a map (top or side, filters);
                new and copied sectors and bodies are named by the rules; ctrl+n on a sector with no layout makes one
  6 Parts       weapons (w), modules (m), commodities (c), starting kit (k); a hides archetype parts
  7 Look        shaders, faction paints, paint patterns, music; y syncs shader blocks
  8 Data        every data file in a form made from its script; delete removes one nothing names
  9 Constants   Constants.gd by section (or by kind, ctrl+g); ctrl+f finds
  0 Tools       evolution, APK and outputs; every other tool (enter asks its questions and runs it)

[b]Saving[/b]
  Godot writes every file and checks the content rules on each save: green means every rule holds,
  red lists what broke (the file is saved; ctrl+u puts it back). Constants are checked before saving.
"""


class HelpScreen(ModalScreen):
    DEFAULT_CSS = """
    HelpScreen { align: center middle; }
    HelpScreen > VerticalScroll { width: 110; height: auto; max-height: 90%; border: thick $accent; background: $surface; padding: 1 2; }
    """
    BINDINGS = [Binding("escape,question_mark,q", "close", "Close")]

    def compose(self) -> ComposeResult:
        with VerticalScroll():
            yield Static(HELP)

    def action_close(self):
        self.dismiss(None)


# --- Tabs -----------------------------------------------------------------------------------------

class OpenTable(DataTable):
    """A table whose enter opens the picked row (shown in the footer)."""
    BINDINGS = [Binding("enter", "select_cursor", "Open")]


class RunTable(DataTable):
    """A table whose enter runs the picked row (shown in the footer)."""
    BINDINGS = [Binding("enter", "select_cursor", "Run")]


class OverviewPane(Vertical):
    BINDINGS = [Binding("ctrl+r", "app.check_all", "Check again"),
                Binding("l", "app.fix_loops", "Fix sound loops")]

    def compose(self) -> ComposeResult:
        yield Static("Starting Godot...", id="summary")
        table = OpenTable(id="problems", cursor_type="row", zebra_stripes=True)
        table.add_columns("Section", "File", "Problem")
        yield table


class ModelsPane(Vertical):
    BINDINGS = [
        Binding("i", "app.model('import')", "Import"), Binding("o", "app.model('open')", "Open in Blender"),
        Binding("s", "app.model('sheet')", "Review sheet"), Binding("ctrl+n", "app.new_model", "New model"),
        Binding("ctrl+r", "app.refresh_models", "Refresh"),
    ]

    def compose(self) -> ComposeResult:
        table = DataTable(id="models", cursor_type="row", zebra_stripes=True)
        table.add_columns("Model", "Kind", "Source", "LODs", "Hit", "Used by", "Status")
        yield table
        yield Static("", id="model-detail")


class DataPane(Horizontal):
    BINDINGS = [
        Binding("ctrl+s", "app.save_file", "Save"), Binding("ctrl+r", "app.reload_file", "Refresh"),
        Binding("ctrl+u", "app.undo_save", "Undo last save"), Binding("ctrl+n", "app.new_file", "New file"),
        Binding("delete", "app.delete_file", "Delete file"),
    ]
    DEFAULT_CSS = """
    DataPane #data-tree { width: 42; }
    DataPane #data-form { width: 1fr; }
    """

    def compose(self) -> ComposeResult:
        tree = Tree("Data", id="data-tree")
        tree.show_root = False
        yield tree
        yield Form("Pick a file on the left.", id="data-form")


class ArchetypesPane(Vertical):
    BINDINGS = [
        Binding("s", "app.archetype('sheet')", "Review sheet"), Binding("p", "app.archetype('pilot')", "Pilot in Data"),
        Binding("h", "app.archetype('ship')", "Ship in Data"), Binding("ctrl+r", "app.refresh_views", "Refresh"),
    ]
    DEFAULT_CSS = """
    ArchetypesPane #archetypes { height: auto; max-height: 60%; }
    ArchetypesPane #archetype-detail { height: auto; padding: 0 1; }
    ArchetypesPane .caption { height: auto; padding: 0 1; }
    """

    def compose(self) -> ComposeResult:
        table = DataTable(id="archetypes", cursor_type="row", zebra_stripes=True)
        table.add_columns("Archetype", "Role", "Temper", "Len m", "Mass t", "Hull", "Speed", "Acc", "DPS",
                          "Cargo", "Slots", "WP", "Lives", "Fit", "Flown by")
        yield table
        yield Static("[dim]Speed m/s (with afterburner) · Acc m/s² · DPS: guns, as the AI rates a fight · Slots: small/medium/large"
                     " + modules · WP: hull price · Fit: fitness when exported[/dim]", classes="caption")
        yield Static("Starting Godot...", id="archetype-detail")


class FactionsPane(Horizontal):
    BINDINGS = [
        Binding("w", "app.toggle_war", "War / peace"), Binding("ctrl+s", "app.save_roster", "Save roster"),
        Binding("e", "app.edit_faction", "Faction in Data"), Binding("ctrl+u", "app.undo_save", "Undo last save"),
        Binding("ctrl+r", "app.refresh_views", "Refresh"),
    ]
    DEFAULT_CSS = """
    FactionsPane #faction-left { width: 3fr; }
    FactionsPane #faction-right { width: 2fr; padding: 0 1; }
    FactionsPane #factions { height: auto; max-height: 12; }
    FactionsPane #wars { height: auto; max-height: 12; }
    FactionsPane #roster { height: auto; max-height: 20; }
    FactionsPane #havens { height: auto; max-height: 14; }
    FactionsPane .caption { height: auto; margin-top: 1; color: $text-muted; }
    FactionsPane #faction-detail { height: auto; }
    """

    def compose(self) -> ComposeResult:
        with Vertical(id="faction-left"):
            table = DataTable(id="factions", cursor_type="row", zebra_stripes=True, cursor_foreground_priority="renderable")
            table.add_columns("", "Faction", "Name", "Paint", "Standing", "Flags", "Roster", "Havens", "Ships")
            yield table
            yield Static("Wars (row against column). Either side's list makes a war; \"(theirs)\": only the column's list has it."
                         " Pick a cell, w makes war or peace.", classes="caption")
            yield DataTable(id="wars", cursor_type="cell")
            yield Static("", id="faction-detail")
        with Vertical(id="faction-right"):
            yield Static("Roster: the archetypes its havens fly (space ticks; ctrl+s saves).", classes="caption", id="roster-caption")
            yield SelectionList(id="roster")
            yield Static("Havens (Enter opens one in World).", classes="caption")
            table = OpenTable(id="havens", cursor_type="row", zebra_stripes=True)
            table.add_columns("Sector", "Haven", "Name", "Ships")
            yield table


PART_COLUMNS = {
    "weapons": ("Weapon", "Type", "Mount", "Mass kg", "Damage", "Cycle s", "DPS", "Range m", "Ammo", "Power", "WP", "Origin", "Used by"),
    "modules": ("Module", "Kind", "Mass kg", "Effects", "WP", "Origin", "Used by"),
    "commodities": ("Commodity", "WP", "kg/unit", "WP/t", "Used by"),
    "starts": ("Game start", "Ship", "Docked at", "Bank WP", "Storage"),
}
PART_TITLES = {"weapons": "Weapons and tools", "modules": "Modules", "commodities": "Commodities", "starts": "Starting kit"}


class PartsPane(Vertical):
    BINDINGS = [
        Binding("w", "app.parts('weapons')", "Weapons"), Binding("m", "app.parts('modules')", "Modules"),
        Binding("c", "app.parts('commodities')", "Commodities"), Binding("k", "app.parts('starts')", "Starting kit"),
        Binding("ctrl+r", "app.refresh_parts", "Refresh"),
    ]
    DEFAULT_CSS = """
    PartsPane #parts { height: 1fr; }
    PartsPane #parts-title, PartsPane #part-detail { height: auto; padding: 0 1; }
    """

    def compose(self) -> ComposeResult:
        yield Static("", id="parts-title")
        yield OpenTable(id="parts", cursor_type="row", zebra_stripes=True)
        yield Static("", id="part-detail")


class LookPane(Horizontal):
    BINDINGS = [
        Binding("ctrl+s", "app.save_music", "Save music"), Binding("ctrl+u", "app.undo_save", "Undo last save"),
        Binding("y", "app.look_task('shaders_sync')", "Sync shader blocks"), Binding("g", "app.look_task('paint_patterns')", "Remake patterns"),
        Binding("v", "app.view_pattern_sheet", "Pattern sheet"), Binding("ctrl+r", "app.refresh_look", "Refresh"),
    ]
    DEFAULT_CSS = """
    LookPane #look-tree { width: 42; }
    LookPane #look-side { width: 1fr; padding: 0 1; }
    LookPane #look-detail { height: auto; }
    LookPane #music-form { height: 1fr; }
    """

    def compose(self) -> ComposeResult:
        tree = Tree("Look", id="look-tree")
        tree.show_root = False
        yield tree
        with Vertical(id="look-side"):
            yield Static("Starting Godot...", id="look-detail")
            yield Form("", id="music-form")


class FilterChip(Static):
    """One line of the map's legend that is also its filter: a click (or enter) shows or hides that kind."""

    can_focus = True
    BINDINGS = [Binding("enter,space", "toggle", "Show/hide", show=False)]

    class Toggled(Message):
        def __init__(self, chip, key):
            super().__init__()
            self.chip, self.key = chip, key

    def __init__(self, text, key, **kwargs):
        super().__init__(text, **kwargs)
        self.key = key
        self.tooltip = "Show or hide them on the map"

    def on_click(self, _event):
        self.action_toggle()

    def action_toggle(self):
        self.post_message(self.Toggled(self, self.key))

    def press(self):
        self.action_toggle()


class WorldPane(Horizontal):
    BINDINGS = [
        Binding("ctrl+s", "app.save_node", "Save"), Binding("ctrl+r", "app.reload_sector", "Refresh"),
        Binding("ctrl+u", "app.undo_save", "Undo last save"), Binding("ctrl+n", "app.new_marker", "New"),
        Binding("ctrl+d", "app.copy_marker", "Copy"), Binding("delete", "app.remove_marker", "Remove"),
    ]
    DEFAULT_CSS = """
    WorldPane #world-left { width: 42; }
    WorldPane #sector-buttons { height: auto; }
    WorldPane #sector-buttons Button { min-width: 12; margin-right: 1; }
    WorldPane #world-side { width: 1fr; }
    WorldPane #world-map { height: auto; }
    WorldPane #map-buttons { height: auto; }
    WorldPane #map-buttons Button { min-width: 14; margin-right: 1; }
    WorldPane #map-filters { height: auto; }
    WorldPane #map-filters { height: auto; layout: grid; grid-size: 6; grid-gutter: 0 1; grid-rows: 1; }
    WorldPane .map-filter { width: 1fr; height: 1; background: $boost; padding: 0 1; }
    WorldPane .map-filter:hover { background: $accent 40%; }
    WorldPane .map-filter:focus { text-style: bold; }
    WorldPane .map-filter.off { text-style: strike; color: $text-disabled; background: transparent; }
    WorldPane #world-form { height: 1fr; }
    """

    def compose(self) -> ComposeResult:
        with Vertical(id="world-left"):
            with Horizontal(id="sector-buttons"):
                yield Button("New sector", id="sector-new", tooltip="A new sector: its folder, scene, layout and location, named by the rules")
                yield Button("Copy sector", id="sector-clone", tooltip="The open sector copied apart (no connections), its bodies and havens renamed")
            tree = Tree("Sectors", id="world-tree")
            tree.show_root = False
            yield tree
        with Vertical(id="world-side"):
            with Horizontal(id="map-buttons"):
                yield Button("Hide map", id="map-toggle", tooltip="Hide the map: the picked one's form gets the room")
                yield Button("Zoom in", id="map-in")
                yield Button("Zoom out", id="map-out")
                yield Button("Whole sector", id="map-fit")
                yield Button("Side view", id="map-side", tooltip="From the side (heights) or from above")
            yield Static("", id="world-map")
            with Horizontal(id="map-filters"):
                for key, symbol, label in worldmap.FILTERS:
                    yield FilterChip("%s %s" % (symbol, label), key, id="filter-" + key, classes="map-filter")
            yield Form("Opening the first sector...", id="world-form")


class ConstantsPane(Horizontal):
    BINDINGS = [
        Binding("ctrl+s", "app.save_constant", "Save"), Binding("ctrl+u", "app.undo_save", "Undo last save"),
        Binding("ctrl+r", "app.reload_constants", "Refresh"),
        Binding("ctrl+g", "app.group_constants", "By section / by kind"), Binding("ctrl+f", "app.find_constant", "Find"),
    ]
    DEFAULT_CSS = """
    ConstantsPane #const-left { width: 52; }
    ConstantsPane #const-tree { height: 1fr; }
    ConstantsPane #const-side { width: 1fr; padding: 0 1; }
    ConstantsPane #const-detail { height: auto; }
    ConstantsPane #const-text { height: 1fr; }
    ConstantsPane #const-status { height: auto; min-height: 1; }
    """

    def compose(self) -> ComposeResult:
        with Vertical(id="const-left"):
            yield Input(placeholder="Find: a name or a word of its comment", id="const-filter")
            tree = Tree("Constants", id="const-tree")
            tree.show_root = False
            yield tree
        with Vertical(id="const-side"):
            yield Static("Pick a constant on the left (open a section with enter), or find one: ctrl+f.\n"
                         "Change its value on the right, then ctrl+s: Godot checks the script before it is saved.", id="const-detail")
            yield Input(id="const-value", placeholder="Its value, as GDScript")
            yield TextArea(id="const-text")
            yield Static("", id="const-status")


class TasksPane(Vertical):
    BINDINGS = [Binding("x", "app.stop_evolution", "Stop evolution"), Binding("n", "app.new_era", "New era"),
                Binding("o", "app.open_output", "Open newest output"),
                Binding("ctrl+r", "app.refresh_status", "Refresh")]
    DEFAULT_CSS = """
    TasksPane #tools-status { height: auto; padding: 0 1; border-bottom: solid $panel; }
    """

    def compose(self) -> ComposeResult:
        yield Static("", id="tools-status")
        table = RunTable(id="tasks", cursor_type="row", zebra_stripes=True)
        table.add_columns("Group", "Task", "tools/dev.py ...")
        yield table
        yield Static("", id="task-detail")


# --- The app --------------------------------------------------------------------------------------

TABS = ["overview", "models-tab", "archetypes-tab", "factions-tab", "world", "parts-tab", "look-tab", "data", "constants", "tasks-tab"]
TAB_KEYS = "1234567890"
TAB_FOCUS = {"overview": "#problems", "models-tab": "#models", "archetypes-tab": "#archetypes", "factions-tab": "#factions",
             "world": "#world-tree", "parts-tab": "#parts", "look-tab": "#look-tree", "data": "#data-tree", "constants": "#const-tree",
             "tasks-tab": "#tasks"}


class DevApp(App):
    TITLE = "GDTLancer"
    SUB_TITLE = "development tool"
    BINDINGS = [Binding("q", "quit", "Quit"), Binding("question_mark,f1", "help", "Help"),
                Binding("tab", "app.focus_next", "Next box", show=False), Binding("shift+tab", "app.focus_previous", "Box before", show=False)] + [
        Binding(TAB_KEYS[index], "tab(%d)" % index, tab, show=False) for index, tab in enumerate(TABS)]
    CSS = """
    #summary, #model-detail, #task-detail { height: auto; padding: 0 1; }
    #problems, #models, #tasks { height: 1fr; }
    """

    def __init__(self, bridge_factory=Bridge, constants_path=constants.PATH):
        super().__init__()
        self.bridge_factory, self.bridge = bridge_factory, None
        self.model_rows = []
        self.problems = []
        self.open_file = None
        self.saved_text = None  # ([(path, its text before the last save)], what to reload after an undo)
        self.archetype_view = {"ranges": {}, "archetypes": []}
        self.faction_view = {"factions": [], "archetypes": []}
        self.faction_picked = None
        self.parts_view = {"weapons": [], "modules": [], "commodities": [], "starts": []}
        self.parts_kind = "weapons"
        self.parts_rows = []
        self.look_view = {}
        self.user_dir = None
        self.world = {}  # The open sector: sector, path, nodes, map, picked
        self.constants_path = "res://" + constants_path
        self.constant_entries = []
        self.constant_picked = None
        self.constants_by_kind = False

    @property
    def fields(self):
        return self.query_one("#data-form", Form).fields

    def compose(self) -> ComposeResult:
        yield Header()
        with TabbedContent(initial="overview"):
            with TabPane("1 Overview", id="overview"):
                yield OverviewPane()
            with TabPane("2 Models", id="models-tab"):
                yield ModelsPane()
            with TabPane("3 Archetypes", id="archetypes-tab"):
                yield ArchetypesPane()
            with TabPane("4 Factions", id="factions-tab"):
                yield FactionsPane()
            with TabPane("5 World", id="world"):
                yield WorldPane()
            with TabPane("6 Parts", id="parts-tab"):
                yield PartsPane()
            with TabPane("7 Look", id="look-tab"):
                yield LookPane()
            with TabPane("8 Data", id="data"):
                yield DataPane()
            with TabPane("9 Constants", id="constants"):
                yield ConstantsPane()
            with TabPane("0 Tools", id="tasks-tab"):
                yield TasksPane()
        yield Footer()

    def on_mount(self):
        self._fill_tasks()
        self._fill_data_tree()
        self._fill_world_tree()
        self._load_constants()
        self.start_bridge()

    def action_tab(self, index):
        self.query_one(TabbedContent).active = TABS[index]

    def check_action(self, action, parameters):
        """Typing a digit, q or ? into a field types it."""
        if action in ("tab", "quit", "help") and isinstance(self.focused, (Input, TextArea)):
            return False
        return True

    def action_help(self):
        self.push_screen(HelpScreen())

    @on(TabbedContent.TabActivated)
    def _focus_tab(self, event):
        """Focus moves into the tab, so its keys show in the footer."""
        target = TAB_FOCUS.get(event.pane.id)
        if target:
            self.query_one(target).focus()
        if event.pane.id == "world" and not self.world:
            self._open_first_sector()

    # --- Godot ---

    def _godot_status(self, text):
        self.sub_title = "development tool · " + text

    @work(thread=True, exclusive=True, group="bridge")
    def start_bridge(self):
        self.call_from_thread(self._godot_status, "starting Godot...")
        try:
            self.bridge = self.bridge_factory()
            version = self.bridge.call("ping")["godot"]
        except (BridgeError, OSError) as error:
            self.call_from_thread(self._set_summary, "[red]Godot did not start:[/red] %s" % error)
            self.call_from_thread(self._godot_status, "Godot did not start")
            return
        self.call_from_thread(self._godot_status, "Godot %s" % version)
        try:
            self.user_dir = self.bridge.call("user_dir")["path"]
        except BridgeError:
            pass
        self.call_from_thread(self._show_status)
        self._check_all()
        self._refresh_models()
        self._refresh_views()
        self._refresh_parts()
        self._refresh_look()

    def restart_bridge(self):
        """After Constants.gd changes: the autoload Godot runs has the old values."""
        old, self.bridge = self.bridge, None
        if old is not None:
            old.close()
        self.start_bridge()

    def ask(self, command, **args):
        if self.bridge is None:
            raise BridgeError("Godot is still starting")
        return self.bridge.call(command, **args)

    def on_unmount(self):
        if self.bridge is not None:
            self.bridge.close()

    def _undo_point(self, files, reload):
        """`files`: [(path, its text before the save, None: it was not there)], put back by ctrl+u."""
        self.saved_text = (files, reload)

    def action_undo_save(self):
        if self.saved_text is None:
            self.notify("No save to undo")
            return
        files, reload = self.saved_text
        for path, text in files:
            if text is None:  # It did not exist before the save
                if os.path.exists(file_path(path)):
                    os.remove(file_path(path))
                folder = os.path.dirname(file_path(path))
                while folder.startswith(tasks.ROOT + os.sep) and os.path.isdir(folder) and not os.listdir(folder):
                    os.rmdir(folder)  # A folder made with it
                    folder = os.path.dirname(folder)
            else:
                os.makedirs(os.path.dirname(file_path(path)), exist_ok=True)  # A deleted body's folder
                write_text(path, text)
        self.saved_text = None
        self.notify("Put back %s as %s" % (", ".join(os.path.basename(path) for path, _ in files), "it was" if len(files) == 1 else "they were"))
        reload()

    # --- Overview ---

    def _set_summary(self, text):
        self.query_one("#summary", Static).update(text)

    def action_check_all(self):
        self.check_all_worker()

    @work(thread=True, exclusive=True, group="check")
    def check_all_worker(self):
        self._check_all()

    def _check_all(self):
        problems = []
        try:
            sections = self.ask("validate", sections=True)  # Every rule the game's validator has
        except BridgeError as error:
            self.call_from_thread(self._show_problems, [("", "", "Check failed: %s" % error)], self._git_changes())
            return
        for section in sections:
            self.call_from_thread(self._set_summary, "Checking %s..." % section)
            try:
                for problem in self.ask("validate", section=section):
                    problems.append((section, problem["file"], problem["problem"]))
            except BridgeError as error:
                problems.append((section, "", "Check failed: %s" % error))
        changed = self._git_changes()
        self.call_from_thread(self._show_problems, problems, changed)

    @staticmethod
    def _git_changes():
        try:
            out = subprocess.run(["git", "status", "--porcelain", "--", "database", "assets", "scenes", "src/autoload/Constants.gd"],
                                 cwd=tasks.ROOT, capture_output=True, text=True, timeout=20).stdout
        except (OSError, subprocess.TimeoutExpired):
            return []
        return [line[3:] for line in out.splitlines() if line.strip()]

    @staticmethod
    def _starters_stale():
        import sys
        sys.path.insert(0, os.path.join(tasks.ROOT, "tools"))
        try:
            import material_library
            return material_library.starters_stale()
        except OSError:
            return False

    def _show_problems(self, problems, changed):
        self.problems = problems
        table = self.query_one("#problems", DataTable)
        table.clear()
        for row in problems:
            table.add_row(*row)
        stale = [row.name for row in self.model_rows if row.stale]
        lines = ["[green]Every content rule holds.[/green]" if not problems else "[red]%s[/red] (below)." % plural(len(problems), "problem")]
        if stale:
            lines.append("[yellow]Changed in Blender since the last import:[/yellow] %s (Models tab: i)" % ", ".join(stale))
        if any(section == "sounds" and "should" in problem and "loop" in problem for section, _, problem in problems):
            lines.append("[yellow]Sounds that loop wrong for their slot:[/yellow] l sets their import loop setting")
        if self._starters_stale():
            lines.append("[yellow]The material library changed since the starter .blends were built:[/yellow] Tools: starters")
        lines.append("Content changed since the last commit: %s%s" % (plural(len(changed), "file"),
                                                                    (": " + ", ".join(changed[:6]) + (" ..." if len(changed) > 6 else "")) if changed else ""))
        self._set_summary("\n".join(lines))

    def action_open_problem(self):
        """The picked problem's file, where it is edited: World for a layout, Models for a model, else Data."""
        table = self.query_one("#problems", DataTable)
        if not self.problems or table.cursor_row is None or table.cursor_row >= len(self.problems):
            return
        section, path, _ = self.problems[table.cursor_row]
        if not path:
            self.notify("This problem is not in one file", severity="warning")
            return
        tabs = self.query_one(TabbedContent)
        if path.endswith("_layout.tscn"):
            tabs.active = "world"
            self.load_sector(os.path.basename(os.path.dirname(path)), path, ".")
        elif section == "models" or path.endswith(".tscn"):
            tabs.active = "models-tab"
            for index, row in enumerate(self.model_rows):
                if row.scene == path:
                    self.query_one("#models", DataTable).move_cursor(row=index)
        else:
            self.open_in_data(path)

    @on(DataTable.RowSelected, "#problems")
    def _problem_selected(self, _event):
        self.action_open_problem()

    def action_fix_loops(self):
        self.run_task(tasks.TASKS_BY_KEY["fix_loops"], {})

    # --- Models ---

    def action_refresh_models(self):
        self.refresh_models_worker()

    @work(thread=True, exclusive=True, group="models")
    def refresh_models_worker(self):
        self._refresh_models()

    def _refresh_models(self):
        try:
            report = self.ask("models")
        except BridgeError as error:
            self.call_from_thread(self.notify, "Models: %s" % error, severity="error")
            return
        self.call_from_thread(self._show_models, models.rows(report))

    def _show_models(self, rows):
        self.model_rows = rows
        table = self.query_one("#models", DataTable)
        table.clear()
        for row in rows:
            table.add_row(row.name, row.kind, row.source,
                          str(row.lods) if row.glb else "-", "yes" if row.hit else "-", str(len(row.users)), row.status, key=row.scene)
        self._show_model_detail()

    def _current_model(self):
        table = self.query_one("#models", DataTable)
        if not self.model_rows or table.cursor_row is None or table.cursor_row >= len(self.model_rows):
            return None
        return self.model_rows[table.cursor_row]

    @on(DataTable.RowHighlighted, "#models")
    def _show_model_detail(self, _event=None):
        row = self._current_model()
        if row is None:
            return
        lines = ["[b]%s[/b]  %s" % (row.name, row.scene)]
        if row.glb:
            lines.append("Model: %s%s" % (row.glb, ("  (source %s)" % os.path.relpath(row.blend, tasks.ROOT)) if row.blend else ""))
        lines.append("Used by: " + (", ".join(user.replace("res://", "") for user in row.users) if row.users else "nothing"))
        for problem in row.problems:
            lines.append("[red]- %s[/red]" % problem)
        self.query_one("#model-detail", Static).update("\n".join(lines))

    def action_model(self, what):
        row = self._current_model()
        if row is None:
            return
        if what == "sheet":
            self.run_task(tasks.TASKS_BY_KEY["model_sheet"], {"scene": row.scene.replace("res://", "")})
            return
        target = row.import_target()
        if row.placeholder or target is None:
            self.notify("%s is built in code (%s): nothing to %s" % (row.name, row.source, what), severity="warning")
            return
        if what == "import":
            self.run_task(tasks.TASKS_BY_KEY["import_model"], {"model": target, "kind": row.kind, "ratio": "0.7", "levels": "3"})
        elif what == "open":
            if row.blend is None:
                self.notify("%s has no .blend beside its .glb" % row.name, severity="warning")
                return
            self.run_task(tasks.TASKS_BY_KEY["open_blender"], {"model": target}, wait=False)

    def action_new_model(self):
        self._ask_task(tasks.TASKS_BY_KEY["new_model"])

    # --- Data ---

    def _fill_data_tree(self):
        tree = self.query_one("#data-tree", Tree)
        tree.clear()
        for kind in data.KINDS:
            files = kind.files()
            node = tree.root.add("%s (%d)" % (kind.title, len(files)), data={"kind": kind.key}, expand=False)
            for path in files:
                node.add_leaf(os.path.basename(path)[:-len(".tres")], data={"kind": kind.key, "path": path})

    @on(Tree.NodeSelected, "#data-tree")
    def _file_picked(self, event):
        info = event.node.data or {}
        if "path" in info:
            self.load_file(info["path"])
        elif "kind" in info:
            kind = data.KINDS_BY_KEY[info["kind"]]
            self.query_one("#data-form", Form).title("[b]%s[/b]  %s\n%s" % (kind.title, kind.folder(), kind.about))

    @work(thread=True, exclusive=True, group="form")
    def load_file(self, path, result=None):
        try:
            schema = self.ask("schema", path=path)
            read = self.ask("read", path=path)
        except BridgeError as error:
            self.call_from_thread(self.notify, "%s: %s" % (path, error), severity="error")
            return
        self.call_from_thread(self._show_file, path, schema, read, result)

    def _show_file(self, path, schema, read, result):
        self.open_file = path
        kind = data.kind_of(path)
        form = self.query_one("#data-form", Form)
        form.show("[b]%s[/b] · %s  [dim](%s%s)[/dim]" % (os.path.basename(path), path, schema["class"], (", " + kind.title) if kind else ""),
                  schema["fields"], read["values"], schema.get("script", ""))
        form.result(result)

    def action_save_file(self):
        if self.open_file is None:
            return
        try:
            values = self.query_one("#data-form", Form).changes()
        except ValueError as error:
            self.notify("Not saved: %s" % error, severity="error")
            return
        if not values:
            self.notify("Nothing changed")
            return
        self.save_worker(self.open_file, values)

    @work(thread=True, exclusive=True, group="form")
    def save_worker(self, path, values):
        before = read_text(path)
        try:
            result = self.ask("write", path=path, values=values)
        except BridgeError as error:
            self.call_from_thread(self.notify, "Not saved: %s" % error, severity="error")
            return
        self._undo_point([(path, before)], lambda: self.load_file(path))
        self.call_from_thread(self.notify, "Saved %s (%s)" % (os.path.basename(path), ", ".join(sorted(values))))
        self.load_file(path, result)

    def action_reload_file(self):
        if self.open_file is not None:
            self.load_file(self.open_file)

    def action_new_file(self):
        node = self.query_one("#data-tree", Tree).cursor_node
        info = (node.data or {}) if node is not None else {}
        kind = data.KINDS_BY_KEY.get(info.get("kind", ""))
        if kind is None or not kind.can_create():
            self.notify("Pick a kind (or a file of it) that takes new files", severity="warning")
            return
        source = info.get("path") or (kind.files()[0] if kind.files() else None)
        if kind.copies and source is None:
            self.notify("Nothing of this kind to copy", severity="warning")
            return
        title = ("New %s: a copy of %s; its name" % (kind.title, os.path.basename(source))) if kind.copies \
            else "New %s: its file name (and template_id)" % kind.title

        def made(name):
            if name:
                self.create_worker(kind, name, source if kind.copies else None)
        self.push_screen(NameScreen(title, kind.prefix + "lower_case_name"), made)

    def action_delete_file(self):
        node = self.query_one("#data-tree", Tree).cursor_node
        info = (node.data or {}) if node is not None else {}
        kind, path = data.KINDS_BY_KEY.get(info.get("kind", "")), info.get("path")
        if kind is None or not path:
            self.notify("Pick a file to delete", severity="warning")
            return
        if not kind.can_create():
            self.notify("%s are not deleted here (%s)" % (kind.title, kind.about or "a fixed set"), severity="warning")
            return
        users = data.references(path, by_name=kind.copies)
        if users:
            self.notify("Not deleted: %s is still named in %s%s" % (os.path.basename(path), ", ".join(user.replace("res://", "") for user in users[:4]),
                                                                    " and %d more" % (len(users) - 4) if len(users) > 4 else ""), severity="error")
            return

        def answered(yes):
            if not yes:
                return
            before = read_text(path)
            os.remove(file_path(path))
            self._undo_point([(path, before)], self._fill_data_tree)
            self._fill_data_tree()
            self.query_one("#data-form", Form).clear("[b]Deleted[/b]  %s\n[dim]ctrl+u puts it back.[/dim]" % path)
            self.notify("Deleted %s; ctrl+u puts it back" % path)
        self.push_screen(ConfirmScreen("Delete %s? Nothing names it." % path.replace("res://", "")), answered)

    @work(thread=True, group="form")
    def create_worker(self, kind, name, copy_from=None):
        path = kind.new_path(name)
        try:
            if copy_from:
                result = self.ask("create", path=path, copy_from=copy_from)
            else:
                result = self.ask("create", path=path, script=kind.script, values={"template_id": name})
        except BridgeError as error:
            self.call_from_thread(self.notify, "Not made: %s" % error, severity="error")
            return
        self.call_from_thread(self._fill_data_tree)
        self.call_from_thread(self.notify, "Made %s" % path)
        self.load_file(path, result)

    # --- Archetypes and factions ---

    def action_refresh_views(self):
        self.refresh_views_worker()

    @work(thread=True, exclusive=True, group="views")
    def refresh_views_worker(self):
        self._refresh_views()

    def _refresh_views(self):
        try:
            archetypes = self.ask("archetypes")
            factions = self.ask("factions")
        except BridgeError as error:
            self.call_from_thread(self.notify, "Views: %s" % error, severity="error")
            return
        self.call_from_thread(self._show_views, archetypes, factions)

    def _show_views(self, archetypes, factions):
        archetypes["archetypes"].sort(key=lambda design: archetype_order(design["name"]))
        self.archetype_view, self.faction_view = archetypes, factions
        self._show_archetypes()
        self._show_factions()

    def _show_archetypes(self):
        table = self.query_one("#archetypes", DataTable)
        row = table.cursor_row
        table.clear()
        for design in self.archetype_view["archetypes"]:
            if "error" in design:
                table.add_row(design["name"], "[red]%s[/red]" % design["error"], *[""] * 13, key=design["name"])
                continue
            slots = design["slots"]
            table.add_row(
                design["name"], design["role"], design["temperament"], "%.1f" % design["length"], "%.1f" % (design["mass"] / 1000.0),
                "%d" % design["hull"],
                "%d" % design["top_speed"] + (" (%d)" % design["burst_speed"] if design["burst_speed"] > design["top_speed"] + 0.5 else ""),
                "%.0f" % design["accel"], "%.1f" % design["gun_dps"], "%d" % design["cargo"],
                "%d/%d/%d+%d" % tuple(slots), "%d" % design["value"], str(design["lives"]), "%+.2f" % design["fitness"],
                ", ".join(design["flown_by"]) or "[yellow]nobody[/yellow]", key=design["name"])
        if row is not None and row < table.row_count:
            table.move_cursor(row=row)
        self._show_archetype_detail()

    def _current_archetype(self):
        table = self.query_one("#archetypes", DataTable)
        designs = self.archetype_view["archetypes"]
        if not designs or table.cursor_row is None or table.cursor_row >= len(designs):
            return None
        return designs[table.cursor_row]

    @on(DataTable.RowHighlighted, "#archetypes")
    def _show_archetype_detail(self, _event=None):
        design = self._current_archetype()
        if design is None or "error" in design:
            return
        lines = ["[b]%s[/b]  %s, %s%s  ·  skill %.2f  ·  %s" % (
            design["name"], design["role"], design["temperament"], (" (" + ", ".join(design["traits"]) + ")") if design["traits"] else "",
            design["skill"], design["scene"].replace("res://", ""))]
        lines.append("Fit: " + ", ".join("%s [dim]%s[/dim]" % (part["name"], part["kind"]) for part in design["parts"]) if design["parts"] else "Fit: none")
        lines.append("Power %.0f, regen %.1f/s · signature %.0f m" % (design["power"], design["regen"], design["signature"]))
        lines.append("[dim]Genes (bar: evolution's range; | its starting value):[/dim]")
        ranges = self.archetype_view["ranges"]
        for gene in sorted(ranges):
            low, high, default = ranges[gene]
            value = design["behavior"].get(gene)
            if value is None:
                lines.append("  %-13s %s  [dim](not set: %s)[/dim]" % (gene, "." * GENE_BAR, default))
            else:
                lines.append("  %-13s %s  %.2f  [dim](%s .. %s)[/dim]" % (gene, gene_bar(value, low, high, default), value, low, high))
        self.query_one("#archetype-detail", Static).update("\n".join(lines))

    def action_archetype(self, what):
        design = self._current_archetype()
        if design is None:
            return
        if what == "sheet":
            self.run_task(tasks.TASKS_BY_KEY["model_sheet"], {"scene": design["scene"].replace("res://", "")})
        else:
            self.open_in_data(design["pilot" if what == "pilot" else "ship"])

    def open_in_data(self, path):
        self.query_one(TabbedContent).active = "data"
        self.load_file(path)

    def _faction(self, faction_id):
        return next((f for f in self.faction_view["factions"] if f["id"] == faction_id), None)

    def _show_factions(self):
        factions = self.faction_view["factions"]
        table = self.query_one("#factions", DataTable)
        table.clear()
        for faction in factions:
            flags = "".join(letter for letter, key in (("D", "distress"), ("E", "escorts"), ("W", "patrol_wages"), ("N", "no_standing"), ("S", "silent"))
                            if faction.get(key))
            ships = sum(sum(int(n) for n in haven["ships"].values()) for haven in faction["havens"] if isinstance(haven["ships"], dict))
            table.add_row(swatch(faction.get("color")), faction["id"], faction.get("display_name", ""), swatch(faction.get("paint")),
                          "%+.2f" % faction.get("starting_standing", 0.0), flags or "-", str(len(faction.get("roster", []))),
                          str(len(faction["havens"])), str(ships), key=faction["id"])
        wars = self.query_one("#wars", DataTable)
        wars.clear(columns=True)
        wars.add_column("", key="row")
        for faction in factions:
            wars.add_column(faction["id"], key=faction["id"])
        for faction in factions:
            cells = []
            for other in factions:
                if other["id"] == faction["id"]:
                    cells.append("[dim]—[/dim]")
                elif other["id"] in faction["at_war"]:
                    listed = other["id"] in faction.get("enemies", [])
                    cells.append("[red]WAR[/red]" + ("" if listed else " [dim](theirs)[/dim]"))
                else:
                    cells.append("[dim]·[/dim]")
            wars.add_row(faction["id"], *cells, key=faction["id"])
        ids = [f["id"] for f in factions]
        picked = self.faction_picked if self.faction_picked in ids else (ids[0] if ids else None)
        if picked:
            table.move_cursor(row=ids.index(picked))
        self._pick_faction(picked)

    @on(DataTable.RowHighlighted, "#factions")
    def _faction_highlighted(self, event):
        self._pick_faction(event.row_key.value)

    def _pick_faction(self, faction_id):
        faction = self._faction(faction_id) if faction_id else None
        self.faction_picked = faction_id
        roster = self.query_one("#roster", SelectionList)
        roster.clear_options()
        havens = self.query_one("#havens", DataTable)
        havens.clear()
        if faction is None:
            return
        flown = faction.get("roster", [])
        names = sorted(set(self.faction_view["archetypes"]) | set(flown), key=archetype_order)
        roster.add_options([(name if name in self.faction_view["archetypes"] else "%s [red](no such archetype)[/red]" % name, name, name in flown)
                            for name in names])
        self.query_one("#roster-caption", Static).update(
            "[b]%s[/b] roster: %d of %d archetypes its havens fly (space ticks or unticks; ctrl+s saves)." % (faction_id, len(flown), len(names)))
        for index, haven in enumerate(faction["havens"]):
            ships = ", ".join("%s %s" % (n, kind) for kind, n in haven["ships"].items()) if isinstance(haven["ships"], dict) else ""
            havens.add_row(haven["sector"], haven["id"], haven["name"], ships, key=str(index))
        notes = []
        if faction.get("ship_scene"):
            notes.append("Flies its own hull: %s" % faction["ship_scene"].replace("res://", ""))
        if faction.get("territory"):
            notes.append("Territory %d m round its havens" % faction["territory"])
        if faction.get("salvage_as"):
            notes.append("Wrecks hold %s" % faction["salvage_as"])
        notes.append("[dim]Flags: D distress, E escorts, W patrol wages, N no standing, S silent[/dim]")
        self.query_one("#faction-detail", Static).update("\n".join(notes))

    @on(DataTable.RowSelected, "#havens")
    def _haven_picked(self, event):
        self._open_haven(int(event.row_key.value))

    def _open_haven(self, index):
        faction = self._faction(self.faction_picked)
        if faction is None or index >= len(faction["havens"]):
            return
        haven = faction["havens"][index]
        self.query_one(TabbedContent).active = "world"
        self.load_sector(haven["sector"], haven["layout"], haven["node"])

    def action_edit_faction(self):
        faction = self._faction(self.faction_picked)
        if faction is not None:
            self.open_in_data(faction["path"])

    def action_toggle_war(self):
        wars = self.query_one("#wars", DataTable)
        factions = self.faction_view["factions"]
        row, column = wars.cursor_coordinate.row, wars.cursor_coordinate.column - 1
        if not (0 <= row < len(factions) and 0 <= column < len(factions)) or row == column:
            self.notify("Pick a cell of two factions", severity="warning")
            return
        a, b = factions[row], factions[column]
        if b["id"] in a["at_war"]:
            changes = {f["id"]: [e for e in f.get("enemies", []) if e != other["id"]]
                       for f, other in ((a, b), (b, a)) if other["id"] in f.get("enemies", [])}
            done = "Peace between %s and %s" % (a["id"], b["id"])
        else:
            changes = {a["id"]: list(a.get("enemies", [])) + [b["id"]]}
            done = "%s and %s are at war" % (a["id"], b["id"])
        self.factions_worker({self._faction(fid)["path"]: {"enemies": enemies} for fid, enemies in changes.items()}, done)

    def action_save_roster(self):
        faction = self._faction(self.faction_picked)
        if faction is None:
            return
        picked = list(self.query_one("#roster", SelectionList).selected)
        roster = [name for name in faction.get("roster", []) if name in picked] + [name for name in picked if name not in faction.get("roster", [])]
        if roster == faction.get("roster", []):
            self.notify("Nothing changed")
            return
        self.factions_worker({faction["path"]: {"roster": roster}}, "Saved %s's roster (%d)" % (faction["id"], len(roster)))

    @work(thread=True, exclusive=True, group="views")
    def factions_worker(self, writes, done):
        """`writes`: {path: values}; all are saved, then checked; one ctrl+u puts them all back."""
        befores = [(path, read_text(path)) for path in writes]
        problems = []
        try:
            for path, values in writes.items():
                problems += self.ask("write", path=path, values=values)["new"]
        except BridgeError as error:
            for path, text in befores:
                write_text(path, text)
            self.call_from_thread(self.notify, "Not saved: %s" % error, severity="error")
            return
        self._undo_point(befores, self.refresh_views_worker)
        if problems:
            self.call_from_thread(self.notify, "%s, but the rules find: %s (ctrl+u undoes)" % (done, "; ".join(p["problem"] for p in problems)),
                                  severity="warning", timeout=10)
        else:
            self.call_from_thread(self.notify, done)
        self._refresh_views()
        self._check_all()

    # --- Special editors ---

    def specials(self, script):
        """{field: Special} for the file or node with `script`: buy lists, the starting kit, and
        fields picked from a list (ships, havens, factions, the body a marker rides with)."""
        out = self._specials(script)
        if os.path.basename(script or "").endswith("_marker.gd") and self.world:
            out["attached_to"] = Special(choices=[("", "(none: its place is its own)")] + [
                (thing["node"], "%s (%s)" % (thing["name"], thing["kind"])) for thing in self.world.get("things", [])])
        return out

    def _specials(self, script):
        name = os.path.basename(script or "")
        parts = self.parts_view
        commodities = {row["id"]: row for row in parts.get("commodities", [])}
        stock = {row["id"]: row for kind in ("weapons", "modules") for row in parts.get(kind, [])}  # The catalogue: the only parts
        havens = sorted({haven["id"]: haven["name"] for faction in self.faction_view.get("factions", []) for haven in faction["havens"]}.items())
        havens += sorted((haven["id"], haven["name"]) for haven in self.faction_view.get("neutral_havens", []))
        factions = [(f["id"], f.get("display_name", f["id"])) for f in self.faction_view.get("factions", [])]
        if name == "haven_marker.gd":
            def sale(key, factor):
                if key == "*":
                    return "anything not listed: %g x its price" % factor
                row = commodities.get(key)
                return "pays %d WP a unit (%d x %g), before standing" % (round(row["value"] * factor), row["value"], factor) if row else ""

            def summary(pairs):
                if not pairs:
                    return "[yellow]Buys nothing: ships cannot sell their cargo here.[/yellow]"
                if "*" in pairs:
                    return "Buys every commodity (%s listed apart)." % (len(pairs) - 1)
                return "Buys only these %d; nothing else." % len(pairs)
            return {
                "buys": Special(pairs=[(key, "%s (%d WP)" % (row["name"], row["value"])) for key, row in sorted(commodities.items())],
                                default=1.0, about=sale, total=summary, any_key=("*", "* anything else")),
                "faction": Special(choices=[("", "(none: neutral)")] + factions),
                "model": Special(choices=[(row.scene, "%s  %s" % (os.path.basename(row.scene)[:-5], row.scene.replace("res://", "")))
                                          for row in getattr(self, "model_rows", []) if row.kind == "station"]),
            }
        if name == "game_start_template.gd":
            def part(key, count):
                row = stock.get(key)
                return "%d x %d WP, %d kg" % (count, row["value"], row["mass"] * count) if row else ""

            def kit(pairs):
                value = sum(stock[k]["value"] * n for k, n in pairs.items() if k in stock)
                mass = sum(stock[k]["mass"] * n for k, n in pairs.items() if k in stock)
                return "Kit: %d parts, worth %d WP (store price), %.1f t; it waits in home storage to refit from." % (sum(pairs.values()), value, mass / 1000.0)
            ships = [(design["ship"].rsplit("/", 1)[-1][:-5], "%s (%s, %d WP)" % (design["name"], design["role"], design["value"]))
                     for design in self.archetype_view.get("archetypes", []) if "ship" in design]
            ships += [(os.path.basename(path)[:-5], os.path.basename(path)[:-5] + " (stock)") for path in data.KINDS_BY_KEY["ships"].files()]
            return {
                "starting_storage": Special(pairs=[(key, "%s (%s, %d WP)" % (row["name"], row.get("type") or row.get("kind") or "module", row["value"]))
                                                   for key, row in sorted(stock.items())], integer=True, default=1, about=part, total=kit),
                "player_ship_template": Special(choices=ships),
                "player_starting_location": Special(choices=havens),
            }
        if name == "beacon_marker.gd":
            return {"owner_faction": Special(choices=[("", "(none)")] + factions)}
        return {}

    # --- Parts ---

    def action_refresh_parts(self):
        self.refresh_parts_worker()

    @work(thread=True, exclusive=True, group="parts")
    def refresh_parts_worker(self):
        self._refresh_parts()

    def _refresh_parts(self):
        try:
            view = self.ask("parts")
        except BridgeError as error:
            self.call_from_thread(self.notify, "Parts: %s" % error, severity="error")
            return
        self.call_from_thread(self._show_parts, view)

    def _show_parts(self, view=None):
        if view is not None:
            self.parts_view = view
        kind = self.parts_kind
        rows = self.parts_view.get(kind, [])
        rows = sorted(rows, key=lambda row: (row.get("type", row.get("kind", "")), row.get("value") or 0))
        self.parts_rows = rows
        table = self.query_one("#parts", DataTable)
        table.clear(columns=True)
        table.add_columns(*PART_COLUMNS[kind])
        for index, row in enumerate(rows):
            table.add_row(*self._part_cells(kind, row), key=str(index))
        shown = "" if kind in ("starts", "commodities") else "  ·  the catalogue: three of each kind, light, medium, heavy"
        self.query_one("#parts-title", Static).update("[b]%s[/b] (%d)%s  ·  enter opens one in Data" % (PART_TITLES[kind], len(rows), shown))
        self._show_part_detail()

    @staticmethod
    def _part_cells(kind, row):
        used = ", ".join(row.get("used_by", [])) or "[yellow]nothing[/yellow]"
        if kind == "weapons":
            return (row["name"], row["type"], row["mount"], "%.0f" % row["mass"], "%.1f" % row["damage"], "%.2f" % row["cycle"],
                    "%.1f" % row["dps"], "%.0f" % row["range"], str(row["ammo"]) if row["ammo"] else "-", "%.1f" % row["power"],
                    str(row["value"]), row["origin"], used)
        if kind == "modules":
            effects = ", ".join("%s %+g" % (key, value) for key, value in (row["effects"] or {}).items()) if isinstance(row["effects"], dict) else ""
            return (row["name"], row["kind"] or "-", "%.0f" % row["mass"], (effects + (" lance" if row["lance"] else "")).strip() or "-",
                    str(row["value"]), row["origin"], used)
        if kind == "commodities":
            per_tonne = row["value"] / row["mass"] * 1000.0 if row["mass"] else 0.0
            return (row["name"], str(row["value"]), "%g" % row["mass"], "%.0f" % per_tonne, used)
        storage = ", ".join("%s x%d" % (key, value) for key, value in row["storage"].items()) if isinstance(row["storage"], dict) else ""
        return (row["id"], row["ship"], row["location"], str(row["bank"]), storage)

    @on(DataTable.RowHighlighted, "#parts")
    def _show_part_detail(self, _event=None):
        table = self.query_one("#parts", DataTable)
        if not self.parts_rows or table.cursor_row is None or table.cursor_row >= len(self.parts_rows):
            self.query_one("#part-detail", Static).update("")
            return
        row = self.parts_rows[table.cursor_row]
        lines = ["[b]%s[/b]  %s" % (row.get("name", row["id"]), row["path"])]
        if row.get("used_by"):
            lines.append("Used by: " + ", ".join(row["used_by"]))
        self.query_one("#part-detail", Static).update("\n".join(lines))

    @on(DataTable.RowSelected, "#parts")
    def _part_picked(self, event):
        self.open_in_data(self.parts_rows[int(event.row_key.value)]["path"])

    def action_parts(self, kind):
        self.parts_kind = kind
        self._show_parts()

    # --- Look ---

    def action_refresh_look(self):
        self.refresh_look_worker()

    @work(thread=True, exclusive=True, group="look")
    def refresh_look_worker(self):
        self._refresh_look()

    def _refresh_look(self):
        try:
            view = self.ask("look")
        except BridgeError as error:
            self.call_from_thread(self.notify, "Look: %s" % error, severity="error")
            return
        view["stale_shaders"] = self._stale_shaders()
        self.call_from_thread(self._show_look, view)

    @staticmethod
    def _stale_shaders():
        try:
            out = subprocess.run(["python3", "tools/sync_shader_blocks.py", "--check"], cwd=tasks.ROOT, capture_output=True, text=True, timeout=30).stdout
        except (OSError, subprocess.TimeoutExpired):
            return []
        return [os.path.basename(line.split("out of date:", 1)[1].strip()) for line in out.splitlines() if "out of date:" in line]

    def _show_look(self, view):
        self.look_view = view
        tree = self.query_one("#look-tree", Tree)
        picked = (tree.cursor_node.data or {}) if tree.cursor_node is not None else {}
        tree.clear()
        stale = view.get("stale_shaders", [])
        shaders = tree.root.add("Shaders (%d%s)" % (len(view["shaders"]), ", %d out of date" % len(stale) if stale else ""), data={"look": "shaders"}, expand=True)
        for shader in view["shaders"]:
            name = os.path.basename(shader["path"])
            shaders.add_leaf(("[red]%s[/red]" % name) if name in stale else name, data={"look": "shader", "path": shader["path"]})
        paints = tree.root.add("Faction paints", data={"look": "paints"}, expand=True)
        for paint in view["paints"]:
            paints.add_leaf("%s %s %s" % (swatch(paint["albedo"]), paint["faction"], paint["kind"]), data={"look": "paint", "path": paint["material"]})
        unused = [p for p in view["patterns"] if not p["used_by"]]
        tree.root.add_leaf("Paint patterns (%d, %d in use)" % (len(view["patterns"]), len(view["patterns"]) - len(unused)), data={"look": "patterns"})
        tree.root.add_leaf("Music", data={"look": "music"})
        self._show_look_item(picked or {"look": "shaders"})

    @on(Tree.NodeHighlighted, "#look-tree")
    def _look_highlighted(self, event):
        if event.node.data:
            self._show_look_item(event.node.data)

    @on(Tree.NodeSelected, "#look-tree")
    def _look_selected(self, event):
        info = event.node.data or {}
        if info.get("look") == "paint" and info.get("path"):
            self.open_in_data(info["path"])

    def _show_look_item(self, info):
        view = self.look_view
        if not view:
            return
        detail = self.query_one("#look-detail", Static)
        form = self.query_one("#music-form", Form)
        form.display = info.get("look") == "music"
        what = info.get("look")
        lines = []
        if what in ("shaders", "shader"):
            stale = view.get("stale_shaders", [])
            lines.append("[b]Shaders[/b] (assets/art/shaders/). [red]Red[/red]: its shared blocks are older than shader_common.glsl; y syncs them.")
            for shader in view["shaders"]:
                if what == "shader" and shader["path"] != info.get("path"):
                    continue
                name = os.path.basename(shader["path"])
                lines.append("")
                lines.append("[b]%s[/b]%s: %s, %s" % (name, " [red](out of date)[/red]" if name in stale else "",
                                                    plural(len(shader["materials"]), "material"), plural(len(shader["scenes"]), "scene")))
                if what == "shader":
                    lines += ["  " + path.replace("res://", "") for path in shader["materials"] + shader["scenes"]]
        elif what in ("paints", "paint"):
            lines.append("[b]Faction paints[/b]: each faction's hull and station material (enter opens one in Data).")
            for paint in view["paints"]:
                if what == "paint" and paint["material"] != info.get("path"):
                    continue
                pattern = os.path.basename(paint["pattern"]) if paint["pattern"] else "no pattern"
                lines.append("%s %-10s %-8s %s  [dim]%s, strength %+.3f[/dim]" % (
                    swatch(paint["albedo"]), paint["faction"], paint["kind"], os.path.basename(paint["material"]), pattern, paint["strength"] or 0.0))
        elif what == "patterns":
            lines.append("[b]Paint patterns[/b] (assets/art/textures/paint_patterns/): g remakes the library, v opens its contact sheet.")
            for pattern in view["patterns"]:
                users = ", ".join(os.path.basename(u)[:-5] for u in pattern["used_by"])
                lines.append("  %-34s %s" % (os.path.basename(pattern["path"]), users or "[dim]unused[/dim]"))
        elif what == "music":
            music = view.get("music", {})
            lines.append("[b]Music[/b]: the ambient track (%s in %s). It fades in when the first sector loads and loops."
                         % (music.get("node"), music.get("scene", "").replace("res://", "")))
            lines.append("Volume and fade: Constants, SOUND (MUSIC_*). ctrl+s saves a new track; it must loop (its import settings).")
            if music.get("fields"):
                form.show("", music["fields"], music["values"])
        detail.update("\n".join(lines))

    def action_save_music(self):
        music = self.look_view.get("music", {})
        form = self.query_one("#music-form", Form)
        if not form.display or not music:
            self.notify("Pick Music on the left first", severity="warning")
            return
        try:
            values = form.changes()
        except ValueError as error:
            self.notify("Not saved: %s" % error, severity="error")
            return
        if not values:
            self.notify("Nothing changed")
            return
        self.music_worker(music["scene"], music["node"], values)

    @work(thread=True, exclusive=True, group="look")
    def music_worker(self, scene, node, values):
        before = read_text(scene)
        try:
            result = self.ask("scene_write", path=scene, node=node, values=values)
        except BridgeError as error:
            self.call_from_thread(self.notify, "Not saved: %s" % error, severity="error")
            return
        self._undo_point([(scene, before)], self.refresh_look_worker)
        self.call_from_thread(self.notify, "Saved the music")
        self._refresh_look()
        self.call_from_thread(self.query_one("#music-form", Form).result, result)

    def action_look_task(self, key):
        self.run_task(tasks.TASKS_BY_KEY[key], {})
        self.refresh_look_worker()

    def action_view_pattern_sheet(self):
        sheet = os.path.join(tasks.ROOT, "tools", "renders", "paint_patterns_sheet.png")
        if not os.path.exists(sheet):
            self.notify("No contact sheet yet: g makes it", severity="warning")
            return
        open_file(sheet)

    # --- World ---

    def _fill_world_tree(self):
        tree = self.query_one("#world-tree", Tree)
        tree.clear()
        for scene in sector_scenes():
            sector = os.path.basename(os.path.dirname(scene))
            path = "res://" + os.path.relpath(scene, tasks.ROOT)[:-len(".tscn")] + "_layout.tscn"
            label = sector if os.path.exists(file_path(path)) else "%s  [dim]no layout[/dim]" % sector
            tree.root.add(label, data={"sector": sector, "path": path, "node": "."}, expand=False, allow_expand=True)

    def _open_first_sector(self):
        tree = self.query_one("#world-tree", Tree)
        laid_out = [child for child in tree.root.children if os.path.exists(file_path(child.data["path"]))]
        home = [child for child in laid_out if child.data["sector"] == home_sector()]
        if tree.root.children:
            info = (home or laid_out or tree.root.children)[0].data  # The game's home, else a sector with a layout
            self.load_sector(info["sector"], info["path"], info["node"])

    @on(Tree.NodeExpanded, "#world-tree")
    def _world_expanded(self, event):
        info = event.node.data or {}
        if info and self.world.get("sector") != info["sector"]:
            self.load_sector(info["sector"], info["path"], ".")

    @on(Tree.NodeSelected, "#world-tree")
    def _world_picked(self, event):
        info = event.node.data or {}
        if not info:
            return
        if self.world.get("sector") != info["sector"]:
            self.load_sector(info["sector"], info["path"], info["node"])
        else:
            self._show_node(info["node"])

    @work(thread=True, exclusive=True, group="world")
    def load_sector(self, sector, path, picked=".", result=None):
        try:
            nodes = self.ask("scene_nodes", path=path) if os.path.exists(file_path(path)) else [
                {"node": ".", "name": sector, "parent": "", "script": "", "type": "Spatial", "fields": [], "values": {}, "missing": True}]
            items = self.ask("sector_map", sector=sector)
            things = self.ask("world_scene", path=self._sector_scene(path))
        except BridgeError as error:
            self.call_from_thread(self.notify, "%s: %s" % (sector, error), severity="error")
            return
        self.call_from_thread(self._show_sector, sector, path, nodes, items, picked, result, things)

    @staticmethod
    def _sector_scene(layout_path):
        return layout_path.replace("_layout.tscn", ".tscn")

    def _show_sector(self, sector, path, nodes, items, picked, result, things=()):
        self.world = {"sector": sector, "path": path, "nodes": {node["node"]: node for node in nodes}, "map": items, "picked": ".",
                      "scene": self._sector_scene(path), "things": list(things)}
        tree = self.query_one("#world-tree", Tree)
        sector_node = next((child for child in tree.root.children if child.data["sector"] == sector), None)
        if sector_node is None:  # Made after the tree was filled
            sector_node = tree.root.add(sector, data={"sector": sector, "path": path, "node": "."}, expand=False, allow_expand=True)
        sector_node.remove_children()
        group = {"node": SCENE, "name": "Scene", "parent": ".", "script": "", "type": "scene", "fields": [], "values": {}}
        self.world["nodes"][SCENE] = group
        scene_node = sector_node.add("Scene  [dim]what the sector scene places[/dim]", data={"sector": sector, "path": path, "node": SCENE},
                                     expand=True)
        for thing in things:
            key = SCENE + thing["node"]
            self.world["nodes"][key] = dict(thing, node=key, parent=SCENE, script="", type=thing["kind"])
            scene_node.add_leaf("%s  [dim]%s[/dim]" % (thing["name"], thing["kind"]), data={"sector": sector, "path": path, "node": key})
        parents = {node["parent"] for node in nodes}
        tree_nodes = {".": sector_node, SCENE: scene_node}
        for key in self.world["nodes"]:
            if key.startswith(SCENE + "SceneAssets"):
                tree_nodes[key] = next(child for child in scene_node.children if child.data["node"] == key)
        for node in nodes:
            if node["node"] == ".":
                continue
            kind = os.path.basename(node["script"]).replace("_marker.gd", "") if node["script"] else node["type"]
            label = "%s  [dim]%s[/dim]" % (node["name"], kind)
            parent = tree_nodes.get(node["parent"], sector_node)
            info = {"sector": sector, "path": path, "node": node["node"]}
            tree_nodes[node["node"]] = parent.add(label, data=info, expand=True) if node["node"] in parents else parent.add_leaf(label, data=info)
        sector_node.expand()
        self._show_node(picked if picked in self.world["nodes"] else ".", result)
        target = tree_nodes.get(self.world["picked"])
        if target is not None:
            tree.move_cursor(target)

    def _show_node(self, node_path, result=None):
        node = self.world.get("nodes", {}).get(node_path)
        if node is None:
            return
        self.world["picked"] = node_path
        form = self.query_one("#world-form", Form)
        where = self.world["path"] if node_path == "." else "%s · %s" % (node_path, self.world["path"])
        if node.get("missing"):
            form.clear("[b]%s[/b]  no layout yet\n[dim]Havens, beacons and hazards go in the sector's layout scene (%s). "
                       "ctrl+n (New) makes it, with an entry beacon where ships arrive, and places it in the sector scene.[/dim]"
                       % (self.world["sector"], self.world["path"]))
        elif node_path == SCENE:
            form.clear("[b]Scene[/b]  %s\n[dim]What the sector scene places: stars, planets, moons, belts. Move or turn one here; ctrl+n makes "
                       "a new body (a copy of one you pick, named by the rules: planet_<sector>_<letter>, moon_<sector>_<letter><n> ...) or "
                       "places a shared prefab, ctrl+d copies the picked body as a new one, delete removes it with its folder. What each is "
                       "made of is its own scene's: the Godot editor's.[/dim]" % self.world["scene"])
        elif node_path.startswith(SCENE):
            form.show("[b]%s[/b]  %s · %s\n[dim]%s, %s; made in %s (the Godot editor)%s[/dim]" % (
                node["name"], node_path[1:], self.world["scene"], node["kind"], "%.0f m across" % (2 * node["radius"]) if node["radius"] else "no size",
                node["scene"].replace("res://", "") or "this scene", self._riders(node_path)), node["fields"], node["values"], "")
        elif node["fields"] and (node["script"] or node_path == "."):
            form.show("[b]%s[/b]  %s" % (node["name"], where), node["fields"], node["values"], node["script"])
        else:
            form.clear("[b]%s[/b]  %s\n[dim]A group; ctrl+n adds a marker to it.[/dim]" % (node["name"], where))
        form.result(result)
        self.query_one("#world-map", Static).update(self._map_text(node_path))

    def _riders(self, key):
        riders = [item["name"] for item in self.world.get("map", []) if item.get("attached_to") and SCENE + item["attached_to"] == key]
        return "; carries %s with it" % ", ".join(riders) if riders else ""

    @on(Button.Pressed, "#sector-new")
    def _sector_new_pressed(self, _event):
        self.action_new_sector()

    @on(Button.Pressed, "#sector-clone")
    def _sector_clone_pressed(self, _event):
        self.action_clone_sector()

    @on(Button.Pressed, "#map-side")
    def _map_side(self, event):
        self.map_side = not getattr(self, "map_side", False)
        event.button.label = "Top view" if self.map_side else "Side view"
        self._redraw_map()

    @on(FilterChip.Toggled)
    def _map_filter(self, event):
        hidden = self.__dict__.setdefault("map_hidden", set())
        hidden.symmetric_difference_update({event.key})
        event.chip.set_class(event.key in hidden, "off")
        self._redraw_map()

    def _redraw_map(self):
        if self.world:
            self.query_one("#world-map", Static).update(self._map_text(self.world.get("picked", "")))

    @on(Button.Pressed, "#map-toggle")
    def _map_toggle(self, event):
        shown = not self.query_one("#world-map").display
        self.query_one("#world-map").display = shown
        self.query_one("#map-filters").display = shown
        for button_id in ("#map-in", "#map-out", "#map-fit", "#map-side"):
            self.query_one(button_id).display = shown
        event.button.label = "Hide map" if shown else "Show map"

    @on(Button.Pressed, "#map-in, #map-out, #map-fit")
    def _map_zoom(self, event):
        zoom = getattr(self, "map_zoom", 1)
        self.map_zoom = {"map-in": min(zoom * 2, 64), "map-out": max(zoom // 2, 1), "map-fit": 1}[event.button.id]
        self._redraw_map()

    def _map_text(self, node_path):
        colors = {}
        for faction in self.faction_view.get("factions", []):
            color = faction.get("color")
            if isinstance(color, dict) and "v" in color:
                colors[faction["id"]] = "rgb(%d,%d,%d)" % tuple(max(60, min(255, int(c * 255))) for c in color["v"][:3])
        width = self.query_one("#world-side").size.width or 96
        columns = max(16, min(60, (width - worldmap.LABEL_WIDTH - 3) // 2))
        return worldmap.render(self.world["map"], node_path, columns=columns, rows=None, max_rows=28, colors=colors,
                               zoom=getattr(self, "map_zoom", 1), side=getattr(self, "map_side", False),
                               hidden=getattr(self, "map_hidden", set()), legend=False)

    def action_reload_sector(self):
        if self.world:
            self.load_sector(self.world["sector"], self.world["path"], self.world["picked"])

    def action_save_node(self):
        if not self.world:
            return
        try:
            values = self.query_one("#world-form", Form).changes()
        except ValueError as error:
            self.notify("Not saved: %s" % error, severity="error")
            return
        if not values:
            self.notify("Nothing changed")
            return
        picked = self.world["picked"]
        if picked == SCENE:
            return
        if picked.startswith(SCENE):
            self.world_worker("scene_write", "Moved %s" % self.world["nodes"][picked]["name"], file=self.world["scene"],
                              node=picked[1:], values=values)
            return
        self.world_worker("scene_write", "Saved %s (%s)" % (picked, ", ".join(sorted(values))), node=picked, values=values)

    def _marker_script(self, node_path):
        """The marker script for a new marker beside or in `node_path`, and its parent."""
        node = self.world["nodes"][node_path]
        if node["script"].startswith(MARKERS) and node_path != ".":
            return node["script"], node["parent"]
        name = node["name"]
        if name in GROUP_MARKERS:
            return MARKERS + GROUP_MARKERS[name], node_path
        return None, None

    def action_new_marker(self):
        if not self.world:
            self.notify("Open a sector first", severity="warning")
            return
        picked = self.world["picked"]
        if picked.startswith(SCENE):
            here = self.world["nodes"].get(picked, {})
            at = [here.get("x", 0.0) + COPY_OFFSET * 5, here.get("y", 0.0), here.get("z", 0.0)] if picked != SCENE else [0.0, 0.0, 0.0]

            def made(answer):
                if not answer:
                    return
                where = {"translation": {"$": "Vector3", "v": at}}
                if answer["kind"] == "prefab":
                    self.world_worker("scene_instance", "Placed %s" % answer["name"], file=self.world["scene"], scene=answer["from"],
                                      name=answer["name"], values=where)
                else:
                    self.body_worker("body_new", "Made a new %s" % answer["kind"], [], kind=answer["kind"], values=where,
                                     **{key: answer[key] for key in ("from", "of", "word")})
            self.push_screen(BodyScreen("A new body in %s (it goes %s)" % (
                self.world["sector"], "beside %s; move it after" % here.get("name") if picked != SCENE else "at the middle; move it after"),
                self._planet_letters(), body_scenes(), prefab_scenes()), made)
            return
        if self.world["nodes"].get(".", {}).get("missing"):
            self.push_screen(ConfirmScreen("Make a layout for %s? %s, with an entry beacon, placed in %s." % (
                self.world["sector"], os.path.basename(self.world["path"]), os.path.basename(self.world["scene"]))), self._make_layout)
            return
        script, parent = self._marker_script(self.world["picked"])
        if script is None:
            self.notify("Pick a group (%s) or a marker" % ", ".join(GROUP_MARKERS), severity="warning")
            return

        def named(name):
            if name:
                self.world_worker("scene_add", "Added %s" % name, parent=parent, name=name, script=script)
        self.push_screen(NameScreen("New %s under %s: its node name" % (os.path.basename(script)[:-3], parent), "CamelCaseName"), named)

    def action_copy_marker(self):
        picked = self.world.get("picked", ".")
        node = self.world.get("nodes", {}).get(picked)
        if picked.startswith(SCENE) and picked != SCENE and node:
            if not node["scene"]:
                self.notify("%s is not an instance of a scene: copy it in the Godot editor" % node["name"], severity="warning")
                return
            body = own_body(node["scene"], self.world["sector"])
            if body is not None:  # A copy of a body is a body of its own, named by the rules
                kind, suffix = body
                where = dict(node["values"], translation={"$": "Vector3", "v": [node["x"] + COPY_OFFSET * 5, node["y"], node["z"]]})

                def copied(word=""):
                    if kind == "belt" and not word:
                        return
                    self.body_worker("body_new", "Copied %s as a new %s" % (node["name"], kind), [], kind=kind, values=where,
                                     **{"from": node["scene"], "of": suffix[:1] if kind == "moon" else "", "word": word})
                if kind == "belt":
                    self.push_screen(NameScreen("A copy of %s: the new belt's word (belt_%s_<word>)" % (node["name"], self.world["sector"][7:]), "word"), copied)
                else:
                    copied()
                return
            self.world_worker("scene_instance", "Copied %s (%d km along x)" % (node["name"], COPY_OFFSET * 5 / 1000), file=self.world["scene"],
                              scene=node["scene"], name=node["name"],
                              values=dict(node["values"], translation={"$": "Vector3", "v": [node["x"] + COPY_OFFSET * 5, node["y"], node["z"]]}))
            return
        if node is None or not node["script"].startswith(MARKERS) or picked == ".":
            self.notify("Pick a marker to copy", severity="warning")
            return
        values = dict(node["values"])
        place = values.get("translation", {}).get("v", [0.0, 0.0, 0.0])
        values["translation"] = {"$": "Vector3", "v": [place[0] + COPY_OFFSET, place[1], place[2]]}
        self.world_worker("scene_add", "Copied %s (%d m along x)" % (node["name"], COPY_OFFSET),
                          parent=node["parent"], name=node["name"], script=node["script"], values=values)

    def action_remove_marker(self):
        picked = self.world.get("picked", ".")
        if picked == "." or picked not in self.world.get("nodes", {}):
            self.notify("Pick a marker to remove", severity="warning")
            return

        if picked == SCENE:
            self.notify("Pick something the scene places to remove", severity="warning")
            return
        riders = [item["name"] for item in self.world.get("map", []) if item.get("attached_to") and SCENE + item["attached_to"] == picked]

        body = own_body(self.world["nodes"][picked].get("scene", ""), self.world["sector"]) if picked.startswith(SCENE) else None

        def answered(yes):
            if yes and body is not None:
                self.body_worker("body_remove", "Removed %s and its folder" % picked[1:], folder_texts(self.world["nodes"][picked]["scene"]),
                                 node=picked[1:])
            elif yes and picked.startswith(SCENE):
                self.world_worker("scene_remove", "Removed %s" % picked[1:], file=self.world["scene"], node=picked[1:])
            elif yes:
                self.world_worker("scene_remove", "Removed %s" % picked, node=picked)
        self.push_screen(ConfirmScreen("Remove %s from %s?%s%s" % (picked.lstrip(SCENE), self.world["sector"],
                                                                 " Its folder (%s) goes too." % os.path.dirname(self.world["nodes"][picked]["scene"]).replace("res://", "") if body else "",
                                                                 " Markers attached to it (%s) then fail the rules until moved or let go." % ", ".join(riders) if riders else "")), answered)

    def _planet_letters(self):
        letters = []
        for thing in self.world.get("things", []):
            body = own_body(thing.get("scene", ""), self.world["sector"])
            if body is not None and body[0] == "planet":
                letters.append(body[1])
        return sorted(letters)

    @work(thread=True, exclusive=True, group="world")
    def body_worker(self, command, done, before_files, **args):
        """A body made or removed (SectorMaker): ctrl+u puts the sector scene and every file back."""
        sector, path, scene = self.world["sector"], self.world["path"], self.world["scene"]
        before = [(scene, read_text(scene))] + list(before_files)
        try:
            result = self.ask(command, sector=sector, **args)
        except BridgeError as error:
            self.call_from_thread(self.notify, "Not done: %s" % error, severity="error")
            return
        made = [(file, None) for file in result.get("files", [])]
        self._undo_point(before + made, lambda: self.load_sector(sector, path, self.world.get("picked", ".")))
        self.call_from_thread(self.notify, "%s%s" % (done, " (%s)" % result["node"].split("/")[-1] if result.get("node") else ""))
        self.load_sector(sector, path, SCENE + result["node"] if result.get("node") else SCENE, result)

    def action_new_sector(self):
        def named(name):
            if not name:
                return
            sector = name if name.startswith("sector_") else "sector_" + name
            location = LOCATIONS_DIR + sector + ".tres"
            before = [(location, read_text(location) if os.path.exists(file_path(location)) else None)]
            self.sector_worker("sector_new", "Made %s" % sector, sector, before, sector=sector)
        self.push_screen(NameScreen("A new sector: its id (sector_<word>, lower_snake_case; its location is made too, or pointed at it)",
                                    "sector_word"), named)

    def action_clone_sector(self):
        if not self.world:
            self.notify("Open the sector to copy first", severity="warning")
            return
        source = self.world["sector"]

        def named(name):
            if not name:
                return
            sector = name if name.startswith("sector_") else "sector_" + name
            self.sector_worker("sector_clone", "Copied %s as %s" % (source, sector), sector, [], sector=source, to=sector)
        self.push_screen(NameScreen("A copy of %s, apart (no connections; its havens' ids its own): its id (sector_<word>)" % source,
                                    "sector_word"), named)

    @work(thread=True, exclusive=True, group="world")
    def sector_worker(self, command, done, opened, before, **args):
        sector = opened  # The sector made, opened after
        try:
            result = self.ask(command, **args)
        except BridgeError as error:
            self.call_from_thread(self.notify, "Not made: %s" % error, severity="error")
            return
        made = [(file, None) for file in result.get("files", []) if file not in dict(before)]
        layout = SECTORS_DIR + "%s/%s_layout.tscn" % (sector, sector)
        self._undo_point(made + before, lambda: (self._fill_world_tree(), self._open_first_sector()))
        self.call_from_thread(self.notify, "%s; ctrl+u takes it back" % done)
        self.call_from_thread(self._fill_world_tree)
        self.load_sector(sector, layout, ".", result)

    @work(thread=True, exclusive=True, group="world")
    def _make_layout(self, yes):
        if not yes:
            return
        sector, path, scene = self.world["sector"], self.world["path"], self.world["scene"]
        before = read_text(scene)
        try:
            result = self.ask("layout_new", sector=sector)
        except BridgeError as error:
            self.call_from_thread(self.notify, "No layout made: %s" % error, severity="error")
            return
        self._undo_point([(scene, before), (path, None)], lambda: (self._fill_world_tree(), self.load_sector(sector, path, ".")))
        self.call_from_thread(self.notify, "Made %s; ctrl+u takes it back" % os.path.basename(path))
        self.call_from_thread(self._fill_world_tree)
        self.load_sector(sector, path, "Beacons/Entry", result)

    @work(thread=True, exclusive=True, group="world")
    def world_worker(self, command, done, file=None, **args):
        sector, path = self.world["sector"], self.world["path"]
        target = file or path
        before = read_text(target)
        try:
            result = self.ask(command, path=target, **args)
        except BridgeError as error:
            self.call_from_thread(self.notify, "Not saved: %s" % error, severity="error")
            return
        self._undo_point([(target, before)], lambda: self.load_sector(sector, path, self.world.get("picked", ".")))
        self.call_from_thread(self.notify, done)
        picked = result.get("node", args.get("node", "."))
        if target != path:
            picked = SCENE + picked
        if command == "scene_remove":
            picked = SCENE if target != path else self.world["nodes"].get(picked, {}).get("parent", ".")
        self.load_sector(sector, path, picked, result)

    # --- Constants ---

    def _load_constants(self):
        self.constant_entries = constants.parse(read_text(self.constants_path))
        self._fill_constants_tree()
        if self.constant_picked is None:
            self.query_one("#const-value", Input).display = False
            self.query_one("#const-text", TextArea).display = False

    def action_reload_constants(self):
        self._load_constants()
        if self.constant_picked:
            self._show_constant(self.constant_picked)
        self.notify("Read Constants.gd again")

    def _fill_constants_tree(self):
        words = self.query_one("#const-filter", Input).value.lower().split()
        tree = self.query_one("#const-tree", Tree)
        tree.clear()
        groups = {}
        for entry in self.constant_entries:
            text = (entry.name + " " + entry.comment + " " + " ".join(entry.doc)).lower()
            if not all(word in text for word in words):
                continue
            group = entry.family if self.constants_by_kind else entry.section
            groups.setdefault(group, []).append(entry)
        order = [family for family in constants.FAMILIES if family in groups] if self.constants_by_kind else list(groups)
        for group in order:
            node = tree.root.add("%s (%d)" % (group, len(groups[group])), expand=bool(words))
            for entry in groups[group]:
                node.add_leaf(entry.name, data=entry.name)

    @on(Input.Changed, "#const-filter")
    def _constants_filtered(self, _event):
        self._fill_constants_tree()

    def action_group_constants(self):
        self.constants_by_kind = not self.constants_by_kind
        self._fill_constants_tree()
        self.notify("Constants by " + ("kind of value" if self.constants_by_kind else "section"))

    def action_find_constant(self):
        self.query_one("#const-filter", Input).focus()

    def _entry(self, name):
        return next((entry for entry in self.constant_entries if entry.name == name), None)

    @on(Tree.NodeHighlighted, "#const-tree")
    def _constant_picked(self, event):
        if event.node.data:
            self._show_constant(event.node.data)

    def _show_constant(self, name, status=""):
        entry = self._entry(name)
        if entry is None:
            return
        self.constant_picked = name
        lines = ["[b]%s[/b]  [dim]%s%s · %s · line %d[/dim]" % (
            name, entry.family, (" (declared %s)" % entry.annotation) if entry.annotation else "", entry.section, entry.first + 1)]
        if entry.comment:
            lines.append(entry.comment)
        if entry.doc:
            lines.append("[dim]%s[/dim]" % "\n".join(entry.doc))
        self.query_one("#const-detail", Static).update("\n".join(lines))
        value_input = self.query_one("#const-value", Input)
        text_area = self.query_one("#const-text", TextArea)
        value_input.display = not entry.multiline()
        text_area.display = entry.multiline()
        if entry.multiline():
            text_area.load_text(entry.value)
        else:
            value_input.value = entry.value
        self.query_one("#const-status", Static).update(status)

    def action_save_constant(self):
        entry = self._entry(self.constant_picked or "")
        if entry is None:
            return
        new_value = self.query_one("#const-text", TextArea).text if entry.multiline() else self.query_one("#const-value", Input).value
        if new_value == entry.value:
            self.notify("Nothing changed")
            return
        problem = constants.check_value(entry, new_value)
        if problem:
            self.notify("Not saved: %s" % problem, severity="error")
            return
        self.constant_worker(entry.name, new_value)

    @work(thread=True, exclusive=True, group="constants")
    def constant_worker(self, name, new_value):
        before = read_text(self.constants_path)
        entry = next((e for e in constants.parse(before) if e.name == name), None)
        if entry is None:
            self.call_from_thread(self.notify, "%s is no longer in the file" % name, severity="error")
            return
        new_text = constants.set_value(before, entry, new_value)
        try:
            parses = self.ask("check_script", source=new_text)["ok"]
        except BridgeError as error:
            self.call_from_thread(self.notify, "Not saved: %s" % error, severity="error")
            return
        if not parses:
            log = [line for line in getattr(self.bridge, "log", [])[-6:] if "rror" in line]
            self.call_from_thread(self._show_constant, name, "[red]Not saved: Godot cannot parse it.[/red]\n" + "\n".join(log))
            return
        write_text(self.constants_path, new_text)
        self._undo_point([(self.constants_path, before)], self._constants_undone)
        self.call_from_thread(self._constant_saved, name)

    def _constant_saved(self, name):
        self._load_constants()
        self._show_constant(name, "[green]Saved.[/green] Godot restarts to read it; the checks run again.")
        self.restart_bridge()

    def _constants_undone(self):
        self._load_constants()
        if self.constant_picked:
            self._show_constant(self.constant_picked, "Put back as it was.")
        self.restart_bridge()

    # --- Tools: status ---

    def _evolution_dir(self):
        return os.path.join(self.user_dir, "evolution") if self.user_dir else None

    def _show_status(self):
        self.query_one("#tools-status", Static).update(tools_status(self._evolution_dir()))

    def action_refresh_status(self):
        self._show_status()

    def action_stop_evolution(self):
        folder = self._evolution_dir()
        if folder is None or not (evolution.status(folder) or {}).get("running"):
            self.notify("Evolution is not running", severity="warning")
            return
        with open(os.path.join(folder, "stop"), "w"):
            pass
        self.notify("Asked evolution to save and stop (it does at its next check)")
        self._show_status()

    def action_new_era(self):
        folder = self._evolution_dir()
        if folder and (evolution.status(folder) or {}).get("running"):
            self.notify("Evolution is running: x stops it, then n again once it says stopped", severity="warning")
            return
        self._ask_task(tasks.TASKS_BY_KEY["new_era"])

    def action_open_output(self):
        newest = newest_files(tasks.OUT_DIR, 1)
        if not newest:
            self.notify("Nothing in .dev/out/ yet", severity="warning")
            return
        open_file(newest[0])

    # --- Tasks ---

    def _fill_tasks(self):
        table = self.query_one("#tasks", DataTable)
        for task in tasks.TASKS:
            table.add_row(task.group, task.title, task.key, key=task.key)

    @on(DataTable.RowHighlighted, "#tasks")
    def _show_task(self, event):
        task = tasks.TASKS_BY_KEY[event.row_key.value]
        values = task.defaults(tasks.load_last())
        preview = ""
        if task.key != "new_model" and not tasks.missing(task, values):
            try:
                preview = "$ " + " ".join(str(part) for part in task.build(values))
            except Exception:  # A preview only
                preview = ""
        self.query_one("#task-detail", Static).update("[b]%s[/b]  %s\n%s" % (task.title, task.about, preview))

    @on(DataTable.RowSelected, "#tasks")
    def _task_picked(self, event):
        self._ask_task(tasks.TASKS_BY_KEY[event.row_key.value])


    def _ask_task(self, task):
        last = tasks.load_last()
        values = task.defaults(last)
        if not task.asks:
            self.run_task(task, values)
            return

        def answered(answers):
            if answers is None:
                return
            last[task.key] = answers
            tasks.save_last(last)
            self.run_task(task, answers)
        self.push_screen(AskScreen(task, values), answered)

    def run_task(self, task, values, wait=True):
        """Runs `task` in the terminal (the menu steps aside), then comes back and refreshes."""
        lacking = tasks.missing(task, values)
        if lacking:
            self.notify("Missing: " + ", ".join(lacking), severity="error")
            return
        with self.suspend():
            code = tasks.run(task, values)
            if wait:
                print("\n[%s] exit %d. Enter: back to the menu" % (task.key, code), end="", flush=True)
                try:
                    input()
                except EOFError:
                    pass
        self._show_status()
        if task.group in ("Models", "Content", "Checks"):
            self._fill_data_tree()
            self.refresh_models_worker()
            self.check_all_worker()


def main():
    DevApp().run()
