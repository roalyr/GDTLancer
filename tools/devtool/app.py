"""
The development tool's menu (Textual): the project's content and its checks in one place.

    Overview   every content rule (ContentValidator), models to re-import, stale starters, sound
               loops, data changed in git
    Models     every ship and station model: its files, who uses it, its check; import, open, review
    Data       every data file by kind (the material library too), edited in a form made from its
               script or shader; each save is checked
    World      each sector's layout (havens, beacons, hazards) on a map from above, each marker in
               a form; add, copy, remove; each save is checked
    Constants  src/autoload/Constants.gd by section or by kind of value; values changed in place,
               Godot checks the script before it is saved
    Tasks      every tool (tasks.py), with its questions

Godot does the reading, writing and checking (bridge.py), so the files stay as Godot writes them.
Keys are listed in the footer; 1-6 switch tabs, q quits (not while typing).
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
from textual.widgets import (Button, DataTable, Footer, Header, Input, Label, Select, Static, Switch,
                             TabbedContent, TabPane, TextArea, Tree)

from . import constants, data, models, tasks, worldmap
from .bridge import Bridge, BridgeError, file_path

RESOURCE_FILES = {  # Resource type -> the files a field of it can point at
    "PackedScene": ("*.tscn",), "AudioStream": ("*.wav", "*.ogg", "*.mp3"), "Material": ("*.tres",),
    "ShaderMaterial": ("*.tres",), "Texture": ("*.png",), "Resource": ("*.tres",), "Shader": ("*.gdshader",),
}
SKIPPED_DIRS = (".git", ".import", ".dev", "addons")
LAYOUTS = "scenes/levels/sectors/*/*_layout.tscn"
MARKERS = "res://src/scenes/game_world/sector_layout/markers/"
GROUP_MARKERS = {"Havens": "haven_marker.gd", "Beacons": "beacon_marker.gd", "Hazards": "hazard_marker.gd"}
COPY_OFFSET = 2000.0  # m along x between a marker and its copy


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


# --- Form fields ----------------------------------------------------------------------------------

class FieldEditor(Vertical):
    """One field of a data file or scene node: its name, type and comment, and an editor fit for
    its type."""

    DEFAULT_CSS = """
    FieldEditor { height: auto; margin: 0 0 1 0; }
    FieldEditor .field-name { text-style: bold; }
    FieldEditor .field-about { color: $text-muted; }
    FieldEditor TextArea { height: 8; }
    FieldEditor .color-row { height: auto; }
    FieldEditor .color-row Input { width: 1fr; }
    FieldEditor .swatch { width: 8; height: 3; }
    """

    def __init__(self, field, value):
        super().__init__()
        self.field, self.original = field, value
        self.editor = None

    def compose(self) -> ComposeResult:
        field, value = self.field, self.original
        yield Label("%s  [dim]%s[/dim]" % (field["name"].replace("shader_param/", ""), self._type_label()), classes="field-name")
        if field.get("comment"):
            yield Label(field["comment"], classes="field-about")
        kind = field["type"]
        hint = field.get("hint_name", "")
        if kind == "bool":
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

    def changed(self):
        value = self.value()
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

    def show(self, title, fields, values):
        scroll = self.query_one(".form-fields", VerticalScroll)
        scroll.remove_children()
        self.fields = [FieldEditor(field, values.get(field["name"], field.get("default"))) for field in fields]
        scroll.mount_all(self.fields)
        self.title(title)
        self.result(None)

    def clear(self, title):
        self.query_one(".form-fields", VerticalScroll).remove_children()
        self.fields = []
        self.title(title)
        self.result(None)

    def changes(self):
        """{field: value} of the fields changed; ValueError if one does not parse."""
        return {editor.field["name"]: editor.value() for editor in self.fields if editor.changed()}

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


# --- Tabs -----------------------------------------------------------------------------------------

class OverviewPane(Vertical):
    BINDINGS = [Binding("c", "app.check_all", "Check all"), Binding("l", "app.fix_loops", "Fix sound loops")]

    def compose(self) -> ComposeResult:
        yield Static("Starting Godot...", id="summary")
        table = DataTable(id="problems", cursor_type="row", zebra_stripes=True)
        table.add_columns("Section", "File", "Problem")
        yield table


class ModelsPane(Vertical):
    BINDINGS = [
        Binding("i", "app.model('import')", "Import"), Binding("o", "app.model('open')", "Open in Blender"),
        Binding("s", "app.model('sheet')", "Review sheet"), Binding("n", "app.new_model", "New model"),
        Binding("r", "app.refresh_models", "Refresh"),
    ]

    def compose(self) -> ComposeResult:
        table = DataTable(id="models", cursor_type="row", zebra_stripes=True)
        table.add_columns("Model", "Kind", "Source", "LODs", "Hit", "Used by", "Status")
        yield table
        yield Static("", id="model-detail")


class DataPane(Horizontal):
    BINDINGS = [
        Binding("ctrl+s", "app.save_file", "Save"), Binding("ctrl+r", "app.reload_file", "Reload"),
        Binding("ctrl+u", "app.undo_save", "Undo last save"), Binding("ctrl+n", "app.new_file", "New file"),
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


class WorldPane(Horizontal):
    BINDINGS = [
        Binding("ctrl+s", "app.save_node", "Save"), Binding("ctrl+r", "app.reload_sector", "Reload"),
        Binding("ctrl+u", "app.undo_save", "Undo last save"), Binding("ctrl+n", "app.new_marker", "New marker"),
        Binding("ctrl+d", "app.copy_marker", "Copy marker"), Binding("delete", "app.remove_marker", "Remove marker"),
    ]
    DEFAULT_CSS = """
    WorldPane #world-tree { width: 42; }
    WorldPane #world-side { width: 1fr; }
    WorldPane #world-map { height: auto; }
    WorldPane #world-form { height: 1fr; }
    """

    def compose(self) -> ComposeResult:
        tree = Tree("Sectors", id="world-tree")
        tree.show_root = False
        yield tree
        with Vertical(id="world-side"):
            yield Static("", id="world-map")
            yield Form("Pick a sector on the left (Enter opens it).", id="world-form")


class ConstantsPane(Horizontal):
    BINDINGS = [
        Binding("ctrl+s", "app.save_constant", "Save"), Binding("ctrl+u", "app.undo_save", "Undo last save"),
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
            yield Static("Pick a constant on the left.", id="const-detail")
            yield Input(id="const-value", placeholder="Its value, as GDScript")
            yield TextArea(id="const-text")
            yield Static("", id="const-status")


class TasksPane(Vertical):
    def compose(self) -> ComposeResult:
        table = DataTable(id="tasks", cursor_type="row", zebra_stripes=True)
        table.add_columns("Group", "Task", "Name")
        yield table
        yield Static("", id="task-detail")


# --- The app --------------------------------------------------------------------------------------

TABS = ["overview", "models-tab", "data", "world", "constants", "tasks-tab"]
TAB_FOCUS = {"overview": "#problems", "models-tab": "#models", "data": "#data-tree", "world": "#world-tree",
             "constants": "#const-tree", "tasks-tab": "#tasks"}


class DevApp(App):
    TITLE = "GDTLancer"
    SUB_TITLE = "development tool"
    BINDINGS = [Binding("q", "quit", "Quit")] + [
        Binding(str(index + 1), "tab(%d)" % index, tab, show=False) for index, tab in enumerate(TABS)]
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
        self.saved_text = None  # (path, its text before the last save, what to reload after an undo)
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
            with TabPane("Overview", id="overview"):
                yield OverviewPane()
            with TabPane("Models", id="models-tab"):
                yield ModelsPane()
            with TabPane("Data", id="data"):
                yield DataPane()
            with TabPane("World", id="world"):
                yield WorldPane()
            with TabPane("Constants", id="constants"):
                yield ConstantsPane()
            with TabPane("Tasks", id="tasks-tab"):
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
        """Typing a digit or q into a field types it."""
        if action in ("tab", "quit") and isinstance(self.focused, (Input, TextArea)):
            return False
        return True

    @on(TabbedContent.TabActivated)
    def _focus_tab(self, event):
        """Focus moves into the tab, so its keys show in the footer."""
        target = TAB_FOCUS.get(event.pane.id)
        if target:
            self.query_one(target).focus()

    # --- Godot ---

    @work(thread=True, exclusive=True, group="bridge")
    def start_bridge(self):
        try:
            self.bridge = self.bridge_factory()
            version = self.bridge.call("ping")["godot"]
        except (BridgeError, OSError) as error:
            self.call_from_thread(self._set_summary, "[red]Godot did not start:[/red] %s" % error)
            return
        self.call_from_thread(self.notify, "Godot %s ready" % version)
        self._check_all()
        self._refresh_models()

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

    def _undo_point(self, path, before, reload):
        self.saved_text = (path, before, reload)

    def action_undo_save(self):
        if self.saved_text is None:
            self.notify("No save to undo")
            return
        path, text, reload = self.saved_text
        write_text(path, text)
        self.saved_text = None
        self.notify("Put back %s as it was" % os.path.basename(path))
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
        for section in ("factions", "sectors", "archetypes", "materials", "sounds", "models"):
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
            lines.append("[yellow]The material library changed since the starter .blends were built:[/yellow] Tasks: starters")
        lines.append("Content changed since the last commit: %s%s" % (plural(len(changed), "file"),
                                                                    (": " + ", ".join(changed[:6]) + (" ..." if len(changed) > 6 else "")) if changed else ""))
        self._set_summary("\n".join(lines))

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
            table.add_row(row.name + (" (placeholder)" if row.placeholder else ""), row.kind, row.source,
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
                  schema["fields"], read["values"])
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
        self._undo_point(path, before, lambda: self.load_file(path))
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

    # --- World ---

    def _fill_world_tree(self):
        tree = self.query_one("#world-tree", Tree)
        tree.clear()
        for layout in sorted(glob.glob(os.path.join(tasks.ROOT, LAYOUTS))):
            sector = os.path.basename(os.path.dirname(layout))
            path = "res://" + os.path.relpath(layout, tasks.ROOT)
            tree.root.add(sector, data={"sector": sector, "path": path, "node": "."}, expand=False, allow_expand=True)

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
            nodes = self.ask("scene_nodes", path=path)
            items = self.ask("sector_map", sector=sector)
        except BridgeError as error:
            self.call_from_thread(self.notify, "%s: %s" % (sector, error), severity="error")
            return
        self.call_from_thread(self._show_sector, sector, path, nodes, items, picked, result)

    def _show_sector(self, sector, path, nodes, items, picked, result):
        self.world = {"sector": sector, "path": path, "nodes": {node["node"]: node for node in nodes}, "map": items, "picked": "."}
        tree = self.query_one("#world-tree", Tree)
        sector_node = next(child for child in tree.root.children if child.data["sector"] == sector)
        sector_node.remove_children()
        parents = {node["parent"] for node in nodes}
        tree_nodes = {".": sector_node}
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
        if node["fields"] and (node["script"] or node_path == "."):
            form.show("[b]%s[/b]  %s" % (node["name"], where), node["fields"], node["values"])
        else:
            form.clear("[b]%s[/b]  %s\n[dim]A group; ctrl+n adds a marker to it.[/dim]" % (node["name"], where))
        form.result(result)
        self.query_one("#world-map", Static).update(worldmap.render(self.world["map"], node_path))

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
        self.world_worker("scene_write", "Saved %s (%s)" % (self.world["picked"], ", ".join(sorted(values))),
                          node=self.world["picked"], values=values)

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

        def answered(yes):
            if yes:
                self.world_worker("scene_remove", "Removed %s" % picked, node=picked)
        self.push_screen(ConfirmScreen("Remove %s from %s?" % (picked, self.world["sector"])), answered)

    @work(thread=True, exclusive=True, group="world")
    def world_worker(self, command, done, **args):
        sector, path = self.world["sector"], self.world["path"]
        before = read_text(path)
        try:
            result = self.ask(command, path=path, **args)
        except BridgeError as error:
            self.call_from_thread(self.notify, "Not saved: %s" % error, severity="error")
            return
        self._undo_point(path, before, lambda: self.load_sector(sector, path, self.world.get("picked", ".")))
        self.call_from_thread(self.notify, done)
        picked = result.get("node", args.get("node", "."))
        if command == "scene_remove":
            picked = self.world["nodes"].get(picked, {}).get("parent", ".")
        self.load_sector(sector, path, picked, result)

    # --- Constants ---

    def _load_constants(self):
        self.constant_entries = constants.parse(read_text(self.constants_path))
        self._fill_constants_tree()

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
        self._undo_point(self.constants_path, before, self._constants_undone)
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
        if task.group in ("Models", "Content", "Checks"):
            self._fill_data_tree()
            self.refresh_models_worker()
            self.check_all_worker()


def main():
    DevApp().run()
