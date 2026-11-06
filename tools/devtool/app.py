"""
The development tool's menu (Textual): the project's content and its checks in one place.

    Overview  every content rule (ContentValidator), models to re-import, data changed in git
    Models    every ship and station model: its files, who uses it, its check; import, open, review
    Data      every data file by kind, edited in a form made from its script; each save is checked
    Tasks     every tool (tasks.py), with its questions

Godot does the reading, writing and checking (bridge.py), so the files stay as Godot writes them.
Keys are listed in the footer; 1-4 switch tabs, q quits.
"""

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

from . import data, models, tasks
from .bridge import Bridge, BridgeError, file_path

RESOURCE_FILES = {  # Resource type -> the files a field of it can point at
    "PackedScene": ("*.tscn",), "AudioStream": ("*.wav", "*.ogg", "*.mp3"), "Material": ("*.tres",),
    "ShaderMaterial": ("*.tres",), "Texture": ("*.png",), "Resource": ("*.tres",),
}
SKIPPED_DIRS = (".git", ".import", ".dev", "addons")


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


# --- Form fields ----------------------------------------------------------------------------------

class FieldEditor(Vertical):
    """One field of a data file: its name, type and comment, and an editor fit for its type."""

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
        yield Label("%s  [dim]%s[/dim]" % (field["name"], self._type_label()), classes="field-name")
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
        elif kind == "Color":
            rgba = (value or {}).get("v", [1, 1, 1, 1])
            self.editor = Input(value=", ".join(self._number_text(c) for c in rgba), placeholder="r, g, b, a (0..1)")
        elif kind == "Object":
            patterns = RESOURCE_FILES.get(field.get("hint_string", ""), ("*.tres", "*.tscn"))
            path = value.get("path", "") if isinstance(value, dict) else ""
            self.editor = Input(value=path, suggester=SuggestFromList(project_files(patterns), case_sensitive=False),
                                placeholder="(none) a res:// path to a %s" % (field.get("hint_string") or "resource"))
        elif kind in ("Array", "Dictionary") or kind.startswith("Pool"):
            self.editor = TextArea(json.dumps(value, indent=1), language="json")
        else:
            text = value.get("text", "") if isinstance(value, dict) else json.dumps(value)
            self.editor = Input(value=text, placeholder="Godot text, e.g. Vector3( 0, 0, 0 )")
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
            r, g, b = self._color()[:3]
            self.query_one(".swatch", Static).styles.background = "rgb(%d,%d,%d)" % (r * 255, g * 255, b * 255)
        except (ValueError, IndexError):
            pass

    def _type_label(self):
        hint = self.field.get("hint_string", "")
        return self.field["type"] + (" " + hint if hint and self.field["type"] == "Object" else "")

    @staticmethod
    def _number_text(value):
        return repr(value) if isinstance(value, float) else str(value if value is not None else 0)

    def _color(self):
        parts = [float(part) for part in self.editor.value.replace("(", " ").replace(")", " ").split(",") if part.strip()]
        if len(parts) == 3:
            parts.append(1.0)
        if len(parts) != 4:
            raise ValueError("a colour is r, g, b, a")
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
            return {"$": "Color", "v": self._color()}
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
        return not same(self.value(), self.original)


# --- Questions for a task -------------------------------------------------------------------------

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
    """Asks for one line (a new file's name); dismisses with it, or None."""

    DEFAULT_CSS = """
    NameScreen { align: center middle; }
    NameScreen > Vertical { width: 70; height: auto; border: thick $accent; background: $surface; padding: 1 2; }
    """
    BINDINGS = [Binding("escape", "cancel", "Cancel")]

    def __init__(self, title):
        super().__init__()
        self.title_ = title

    def compose(self) -> ComposeResult:
        with Vertical():
            yield Label(self.title_)
            yield Input(placeholder="lower_case_name")

    @on(Input.Submitted)
    def _done(self, event):
        self.dismiss(event.value.strip() or None)

    def action_cancel(self):
        self.dismiss(None)


# --- Tabs -----------------------------------------------------------------------------------------

class OverviewPane(Vertical):
    BINDINGS = [Binding("c", "app.check_all", "Check all")]

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
    DataPane #form-side { width: 1fr; }
    DataPane #form-status { height: auto; min-height: 1; }
    """

    def compose(self) -> ComposeResult:
        tree = Tree("Data", id="data-tree")
        tree.show_root = False
        yield tree
        with Vertical(id="form-side"):
            yield Static("Pick a file on the left.", id="form-title")
            yield Static("", id="form-status")
            yield VerticalScroll(id="form")


class TasksPane(Vertical):
    def compose(self) -> ComposeResult:
        table = DataTable(id="tasks", cursor_type="row", zebra_stripes=True)
        table.add_columns("Group", "Task", "Name")
        yield table
        yield Static("", id="task-detail")


# --- The app --------------------------------------------------------------------------------------

class DevApp(App):
    TITLE = "GDTLancer"
    SUB_TITLE = "development tool"
    BINDINGS = [
        Binding("q", "quit", "Quit"), Binding("1", "tab('overview')", "Overview", show=False),
        Binding("2", "tab('models')", "Models", show=False), Binding("3", "tab('data')", "Data", show=False),
        Binding("4", "tab('tasks')", "Tasks", show=False),
    ]
    CSS = """
    #summary, #model-detail, #task-detail { height: auto; padding: 0 1; }
    #problems, #models, #tasks { height: 1fr; }
    """

    def __init__(self, bridge_factory=Bridge):
        super().__init__()
        self.bridge_factory, self.bridge = bridge_factory, None
        self.model_rows = []
        self.fields = []
        self.open_file = None
        self.open_text = None  # The open file's text as loaded (Reload)
        self.saved_text = None  # Its text before the last save (Undo last save)

    def compose(self) -> ComposeResult:
        yield Header()
        with TabbedContent(initial="overview"):
            with TabPane("Overview", id="overview"):
                yield OverviewPane()
            with TabPane("Models", id="models-tab"):
                yield ModelsPane()
            with TabPane("Data", id="data"):
                yield DataPane()
            with TabPane("Tasks", id="tasks-tab"):
                yield TasksPane()
        yield Footer()

    def on_mount(self):
        self._fill_tasks()
        self._fill_data_tree()
        self.start_bridge()

    def action_tab(self, name):
        self.query_one(TabbedContent).active = {"models": "models-tab", "tasks": "tasks-tab"}.get(name, name)

    @on(TabbedContent.TabActivated)
    def _focus_tab(self, event):
        """Focus moves into the tab, so its keys show in the footer."""
        target = {"overview": "#problems", "models-tab": "#models", "data": "#data-tree", "tasks-tab": "#tasks"}.get(event.pane.id)
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

    def ask(self, command, **args):
        if self.bridge is None:
            raise BridgeError("Godot is still starting")
        return self.bridge.call(command, **args)

    def on_unmount(self):
        if self.bridge is not None:
            self.bridge.close()

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
        for section in ("factions", "sectors", "archetypes", "sounds", "models"):
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
            out = subprocess.run(["git", "status", "--porcelain", "--", "database", "assets", "scenes"], cwd=tasks.ROOT,
                                 capture_output=True, text=True, timeout=20).stdout
        except (OSError, subprocess.TimeoutExpired):
            return []
        return [line[3:] for line in out.splitlines() if line.strip()]

    def _show_problems(self, problems, changed):
        table = self.query_one("#problems", DataTable)
        table.clear()
        for row in problems:
            table.add_row(*row)
        stale = [row.name for row in self.model_rows if row.stale]
        lines = ["[green]Every content rule holds.[/green]" if not problems else "[red]%d problem%s[/red] (below)." % (len(problems), "" if len(problems) == 1 else "s")]
        if stale:
            lines.append("[yellow]Changed in Blender since the last import:[/yellow] %s (Models tab: i)" % ", ".join(stale))
        lines.append("Data changed since the last commit: %d file%s%s" % (len(changed), "" if len(changed) == 1 else "s",
                                                                          (": " + ", ".join(changed[:6]) + (" ..." if len(changed) > 6 else "")) if changed else ""))
        self._set_summary("\n".join(lines))

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
            self.query_one("#form-title", Static).update("[b]%s[/b]  %s\n%s" % (kind.title, kind.folder(), kind.about))

    @work(thread=True, exclusive=True, group="form")
    def load_file(self, path):
        try:
            schema = self.ask("schema", path=path)
            read = self.ask("read", path=path)
        except BridgeError as error:
            self.call_from_thread(self.notify, "%s: %s" % (path, error), severity="error")
            return
        with open(file_path(path)) as handle:
            text = handle.read()
        self.call_from_thread(self._show_form, path, schema, read, text)

    def _show_form(self, path, schema, read, text):
        self.open_file, self.open_text = path, text
        form = self.query_one("#form", VerticalScroll)
        form.remove_children()
        self.fields = [FieldEditor(field, read["values"].get(field["name"], field["default"])) for field in schema["fields"]]
        form.mount_all(self.fields)
        kind = data.kind_of(path)
        self.query_one("#form-title", Static).update("[b]%s[/b] · %s  [dim](%s%s)[/dim]" % (
            os.path.basename(path), path, schema["class"], (", " + kind.title) if kind else ""))
        self._show_file_problems(None)

    def _show_file_problems(self, result):
        status = self.query_one("#form-status", Static)
        if result is None:
            status.update("")
            return
        if result["problems"]:
            status.update("[red]Saved, but the rules find:[/red]\n" + "\n".join("- %s" % p["problem"] for p in result["problems"])
                          + "\n[dim]ctrl+u puts back the file as it was before this save.[/dim]")
        else:
            status.update("[green]Saved; every rule holds.[/green]")

    def action_save_file(self):
        if self.open_file is None:
            return
        try:
            values = {editor.field["name"]: editor.value() for editor in self.fields if editor.changed()}
        except ValueError as error:
            self.notify("Not saved: %s" % error, severity="error")
            return
        if not values:
            self.notify("Nothing changed")
            return
        self.save_worker(self.open_file, values)

    @work(thread=True, exclusive=True, group="form")
    def save_worker(self, path, values):
        with open(file_path(path)) as handle:
            before = handle.read()
        try:
            result = self.ask("write", path=path, values=values)
        except BridgeError as error:
            self.call_from_thread(self.notify, "Not saved: %s" % error, severity="error")
            return
        self.saved_text = (path, before)
        self.call_from_thread(self.notify, "Saved %s (%s)" % (os.path.basename(path), ", ".join(sorted(values))))
        read = self.ask("read", path=path)
        schema = self.ask("schema", path=path)
        with open(file_path(path)) as handle:
            text = handle.read()
        self.call_from_thread(self._after_save, path, schema, read, text, result)

    def _after_save(self, path, schema, read, text, result):
        self._show_form(path, schema, read, text)
        self._show_file_problems(result)

    def action_reload_file(self):
        if self.open_file is not None:
            self.load_file(self.open_file)

    def action_undo_save(self):
        if self.saved_text is None:
            self.notify("No save to undo")
            return
        path, text = self.saved_text
        with open(file_path(path), "w") as handle:
            handle.write(text)
        self.saved_text = None
        self.notify("Put back %s as it was" % os.path.basename(path))
        self.load_file(path)

    def action_new_file(self):
        node = self.query_one("#data-tree", Tree).cursor_node
        info = (node.data or {}) if node is not None else {}
        kind = data.KINDS_BY_KEY.get(info.get("kind", ""))
        if kind is None or not kind.can_create():
            self.notify("Pick a kind (or a file of it) that takes new files", severity="warning")
            return

        def made(name):
            if name:
                self.create_worker(kind, name)
        self.push_screen(NameScreen("New %s: its file name (and template_id)" % kind.title), made)

    @work(thread=True, group="form")
    def create_worker(self, kind, name):
        path = kind.folder() + "/" + name + ".tres"
        try:
            result = self.ask("create", path=path, script=kind.script, values={"template_id": name})
        except BridgeError as error:
            self.call_from_thread(self.notify, "Not made: %s" % error, severity="error")
            return
        self.call_from_thread(self._fill_data_tree)
        self.call_from_thread(self.notify, "Made %s" % path)
        self.load_file(path)
        self.call_from_thread(self._show_file_problems, result)

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
        if task.group in ("Models", "Content"):
            self._fill_data_tree()
            self.refresh_models_worker()


def main():
    DevApp().run()
