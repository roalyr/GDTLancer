"""Every task builds a command from its defaults (with a value for each required question)."""

import os
import unittest

from devtool import data, models, tasks, test_run


class TasksTest(unittest.TestCase):
    def test_every_task_builds_a_command(self):
        for task in tasks.TASKS:
            if task.key == "new_model":
                continue  # Copies a file when built
            values = task.defaults({})
            for ask in task.asks:
                if not values[ask.key] and not ask.optional:
                    options = [o for o in ask.options() if o != tasks.TYPE_A_PATH]
                    values[ask.key] = options[0] if options else "x"
            self.assertEqual(tasks.missing(task, values), [], task.key)
            command = task.build(values)
            self.assertTrue(command and all(isinstance(part, str) for part in command), task.key)

    def test_task_keys_are_unique_and_named(self):
        keys = [task.key for task in tasks.TASKS]
        self.assertEqual(len(keys), len(set(keys)))
        for task in tasks.TASKS:
            self.assertTrue(task.title and task.group, task.key)

    def test_groups_are_together_and_maintainer_tasks_last(self):
        groups = [task.group for task in tasks.TASKS]
        seen = []
        for group in groups:
            if not seen or seen[-1] != group:
                self.assertNotIn(group, seen, "%s's tasks are listed together" % group)
                seen.append(group)
        self.assertEqual(seen[-1], tasks.MAINTAINER)
        for key in ("new_era", "evolution", "release", "export_presets", "pick_archetypes"):
            self.assertTrue(tasks.TASKS_BY_KEY[key].maintainer, key)
        for key in ("tests", "validate", "import_model", "apply_laws", "classify_presets", "play", "apk"):
            self.assertFalse(tasks.TASKS_BY_KEY[key].maintainer, key)
        self.assertTrue(all(task.about for task in tasks.TASKS), "Every task says what it does")

    def test_programs_missing_or_of_the_wrong_version_are_named_with_what_to_do(self):
        godot, blender = tasks.GODOT, tasks.BLENDER
        try:
            tasks.GODOT = "no-such-godot-here"
            tasks.godot_problem.cache_clear()
            problem = tasks.godot_problem()
            self.assertIn("Godot not found", problem)
            self.assertIn("GODOT=", problem)
            self.assertEqual(tasks.program_problem(["no-such-godot-here", "-e"]), problem)
            self.assertEqual(tasks.program_problem(["python3", "x.py"]), "")
            tasks.BLENDER = "/bin/echo"  # Runs, but says no Blender version
            tasks.blender_problem.cache_clear()
            self.assertIn("of an unknown version; the models need Blender 3.6", tasks.blender_problem())
            self.assertIn("BLENDER=", tasks.blender_problem())
        finally:
            tasks.GODOT, tasks.BLENDER = godot, blender
            tasks.godot_problem.cache_clear()
            tasks.blender_problem.cache_clear()

    def test_godot_gets_a_display_from_a_bare_terminal(self):
        saved = os.environ.pop("DISPLAY", None)
        try:
            self.assertEqual(tasks.environment()["DISPLAY"], ":0", "None set: the desktop's")
            os.environ["DISPLAY"] = ":7"
            self.assertEqual(tasks.environment()["DISPLAY"], ":7", "One set: kept")
            self.assertIn("No display :987", tasks.display_problem({"DISPLAY": ":987"}))
            self.assertIn("set DISPLAY", tasks.display_problem({"DISPLAY": ":987"}))
            self.assertEqual(tasks.display_problem({"DISPLAY": "otherhost:0"}), "", "Remote: Godot will say")
        finally:
            os.environ.pop("DISPLAY", None)
            if saved is not None:
                os.environ["DISPLAY"] = saved

    def test_one_user_folder_for_the_whole_tool(self):
        from devtool import data, evolution
        saved = {key: os.environ.pop(key, None) for key in ("GODOT_USER_DIR", "XDG_DATA_HOME")}
        try:
            name = tasks.project_setting("config/name")
            self.assertEqual(tasks.user_dir(), os.path.expanduser("~/.local/share/godot/app_userdata/" + name))
            os.environ["XDG_DATA_HOME"] = "/tmp/xdg"
            self.assertEqual(tasks.user_dir(), "/tmp/xdg/godot/app_userdata/" + name, "Godot's rule: XDG_DATA_HOME")
            os.environ["GODOT_USER_DIR"] = "/tmp/given"
            self.assertEqual(tasks.user_dir(), "/tmp/given")
            tasks.set_user_dir("/tmp/from-godot")
            self.assertEqual(tasks.user_dir(), "/tmp/from-godot", "Godot's own answer wins")
            for env in ({}, {"XDG_DATA_HOME": "/tmp/xdg"}, {"GODOT_USER_DIR": "/tmp/given"}):
                tasks.set_user_dir(None)
                for key in ("GODOT_USER_DIR", "XDG_DATA_HOME"):
                    os.environ.pop(key, None)
                os.environ.update(env)
                self.assertEqual(data.user_dir(), evolution.user_dir(), env)
                self.assertEqual(data.user_dir(), tasks.user_dir(), env)
        finally:
            tasks.set_user_dir(None)
            for key, value in saved.items():
                os.environ.pop(key, None)
                if value is not None:
                    os.environ[key] = value

    def test_numbers_and_typed_files_are_checked_before_running(self):
        task = tasks.TASKS_BY_KEY["fight_bench"]
        values = task.defaults({})
        self.assertEqual(tasks.invalid(task, values), [])
        values["n"] = "8x"
        self.assertEqual(tasks.invalid(task, values), ["Ships a side: a whole number (got '8x')"])
        self.assertEqual(tasks.run(task, values, dry=True), 2, "Not run")
        evolution_task = tasks.TASKS_BY_KEY["evolution"]
        self.assertEqual(tasks.invalid(evolution_task, dict(evolution_task.defaults({}), hours="0.5")), [], "Decimals are numbers")
        self.assertIn("a number", tasks.invalid(evolution_task, dict(evolution_task.defaults({}), speed="fast"))[0])
        preview = tasks.TASKS_BY_KEY["render_preview"]
        self.assertIn("no such file", tasks.invalid(preview, dict(preview.defaults({}), scene="scenes/none.tscn"))[0])
        self.assertEqual(tasks.invalid(preview, dict(preview.defaults({}), scene="res://scenes/prefabs/celestial/asteroid.tscn")), [])

    def test_the_tools_own_options_reach_their_commands(self):
        def command(key, **answers):
            task = tasks.TASKS_BY_KEY[key]
            values = dict(task.defaults({}), **answers)
            self.assertEqual(tasks.invalid(task, values), [], key)
            return task.build(values)
        self.assertIn("probe=yes", command("evolution", probe="yes"))
        self.assertIn("--probe", command("evolution", probe="yes", follow="yes"))
        frozen = command("evolution", frozen="yes", save_dir="user://frozen/", follow="yes")
        self.assertTrue({"--frozen", "--new", "--save-dir=user://frozen/"} <= set(frozen), "A frozen run is new, in its own folder")
        evolution_task = tasks.TASKS_BY_KEY["evolution"]
        self.assertTrue(tasks.invalid(evolution_task, dict(evolution_task.defaults({}), frozen="yes")), "Never the default save")
        self.assertIn("-gselect=test_lance.gd", test_run.gut_command(file="test_lance.gd"))
        self.assertIn("file=test_lance.gd", command("tests", file="src/tests/core/agents/components/test_lance.gd"))
        self.assertEqual(command("validate", section="parts")[-2:], ["--", "parts"])
        self.assertIn("parts", tasks.validate_sections())
        self.assertNotIn("--", command("validate"), "All sections")
        self.assertEqual(command("classify_presets", check="yes")[-1], "--check")
        self.assertIn("--rate=60", command("lance_duel", rate="60"))
        self.assertIn("lance=40", command("harpoon_probe", lance="40"))
        self.assertIn("near=violet", command("sound_probe", near="violet"))
        self.assertIn("every=10", command("soak", every="10"))
        self.assertIn("--save=user://x.sav", command("export_presets", save="user://x.sav"))
        self.assertIn("tile=200", command("render_preview", scene="scenes/prefabs/celestial/asteroid.tscn", tile="200"))

    def test_missing_answers_are_named(self):
        task = tasks.TASKS_BY_KEY["check_model"]
        self.assertEqual(tasks.missing(task, {"scene": ""}), ["Scene"])
        self.assertEqual(tasks.run(task, {"scene": ""}), 2, "Does not run without them")

    def test_stations_import_as_stations(self):
        task = tasks.TASKS_BY_KEY["import_model"]
        values = {"model": "assets/models/stations/x/x.blend", "kind": "auto", "ratio": "0.7", "levels": "3"}
        self.assertIn("--station", task.build(values))
        values["model"] = "assets/models/ships/x/x.blend"
        self.assertNotIn("--station", task.build(values))


class DataKindsTest(unittest.TestCase):
    def test_every_kind_finds_its_files(self):
        for kind in data.KINDS:
            files = kind.files()
            self.assertTrue(files, kind.key)
            for path in files:
                self.assertTrue(os.path.exists(os.path.join(tasks.ROOT, path[len("res://"):])), path)
            if kind.script:
                self.assertTrue(os.path.exists(os.path.join(tasks.ROOT, kind.script[len("res://"):])), kind.script)

    def test_archetype_kinds_do_not_overlap(self):
        parts = set(data.KINDS_BY_KEY["parts"].files())
        self.assertEqual(len(parts), 40, "Three of every kind, and the harpoon")
        self.assertFalse(parts & set(data.KINDS_BY_KEY["archetype_ships"].files()))
        self.assertFalse(parts & set(data.KINDS_BY_KEY["archetype_pilots"].files()))


class ModelRowsTest(unittest.TestCase):
    def test_rows_read_their_files(self):
        report = {"ships": {"res://src/tests/fixtures/models/test_hull/test_hull.tscn": {"users": ["u"], "problems": []},
                            "res://scenes/prefabs/ships/placeholders/fighter_light.tscn": {"users": [], "problems": ["bad"]}},
                  "stations": {}}
        rows = {row.name: row for row in models.rows(report)}
        hull = rows["test_hull"]
        self.assertEqual(hull.glb, "res://src/tests/fixtures/models/test_hull/test_hull.glb")
        self.assertEqual(hull.lods, 2)
        self.assertTrue(hull.hit)
        self.assertEqual(hull.status, "OK")
        placeholder = rows["fighter_light"]
        self.assertTrue(placeholder.placeholder)
        self.assertEqual(placeholder.source, "primitives")
        self.assertEqual(placeholder.status, "1 problem")
        self.assertIsNone(placeholder.import_target())


if __name__ == "__main__":
    unittest.main()
