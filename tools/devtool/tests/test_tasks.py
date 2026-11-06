"""Every task builds a command from its defaults (with a value for each required question)."""

import os
import unittest

from devtool import data, models, tasks


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
