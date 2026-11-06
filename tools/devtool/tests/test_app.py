"""The menu, driven by Textual's test pilot against a stand-in for Godot (no files are written)."""

import unittest

from textual.widgets import DataTable, Input

from devtool import app as devapp
from devtool import tasks

FILE = "res://database/factions/verdant.tres"


class FakeBridge:
    def __init__(self):
        self.writes = []

    def call(self, command, **args):
        if command == "ping":
            return {"godot": "fake"}
        if command == "validate":
            return [{"file": "res://x.tres", "problem": "Broken"}] if args.get("section") == "factions" else []
        if command == "models":
            return {"ships": {"res://scenes/prefabs/ships/placeholders/fighter_light.tscn": {"users": ["a"], "problems": []}},
                    "stations": {"res://scenes/prefabs/station/placeholders/haven.tscn": {"users": [], "problems": ["Too big"]}}}
        if command == "schema":
            fields = [("name", "String", ""), ("count", "int", ""), ("share", "float", ""), ("on", "bool", ""),
                      ("color", "Color", ""), ("list", "Array", ""), ("paint", "String", "file")]
            return {"class": "FakeTemplate", "fields": [
                {"name": n, "type": t, "hint_name": h, "hint_string": "*.tres" if h else "", "default": None, "comment": "about " + n}
                for n, t, h in fields]}
        if command == "read":
            return {"path": args["path"], "class": "FakeTemplate", "values": {
                "name": "Verdant", "count": 3, "share": 0.25, "on": True, "color": {"$": "Color", "v": [0.5, 1.0, 0.25, 1.0]},
                "list": ["a", "b"], "paint": ""}}
        if command == "write":
            self.writes.append(args)
            return {"path": args["path"], "problems": [], "new": []}
        raise AssertionError("unexpected " + command)

    def close(self):
        pass


class AppTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        import asyncio
        asyncio.get_running_loop().set_debug(False)  # The test runner's debug mode reports slow steps

    async def _started(self, pilot, app):
        await pilot.pause()
        await app.workers.wait_for_complete()
        await pilot.pause()

    async def test_overview_models_and_tasks_fill(self):
        fake = FakeBridge()
        app = devapp.DevApp(bridge_factory=lambda: fake)
        async with app.run_test(size=(160, 50)) as pilot:
            await self._started(pilot, app)
            self.assertEqual(app.query_one("#problems", DataTable).row_count, 1, "One problem")
            self.assertEqual(app.query_one("#models", DataTable).row_count, 2)
            self.assertEqual(app.model_rows[1].status, "1 problem")
            self.assertEqual(app.query_one("#tasks", DataTable).row_count, len(tasks.TASKS))

    async def test_a_form_saves_only_what_changed(self):
        fake = FakeBridge()
        app = devapp.DevApp(bridge_factory=lambda: fake)
        async with app.run_test(size=(160, 60)) as pilot:
            await self._started(pilot, app)
            app.load_file(FILE)
            await self._started(pilot, app)
            self.assertEqual([f.field["name"] for f in app.fields], ["name", "count", "share", "on", "color", "list", "paint"])
            self.assertFalse(any(f.changed() for f in app.fields), "Unchanged as loaded")
            by_name = {f.field["name"]: f for f in app.fields}
            by_name["count"].editor.value = "5"
            by_name["color"].editor.value = "0.1, 0.2, 0.3"
            app.action_save_file()
            await self._started(pilot, app)
            self.assertEqual(len(fake.writes), 1)
            self.assertEqual(fake.writes[0]["values"], {"count": 5, "color": {"$": "Color", "v": [0.1, 0.2, 0.3, 1.0]}})

    async def test_a_bad_value_is_not_saved(self):
        fake = FakeBridge()
        app = devapp.DevApp(bridge_factory=lambda: fake)
        async with app.run_test(size=(160, 60)) as pilot:
            await self._started(pilot, app)
            app.load_file(FILE)
            await self._started(pilot, app)
            by_name = {f.field["name"]: f for f in app.fields}
            by_name["color"].editor.value = "red"
            app.action_save_file()
            await self._started(pilot, app)
            self.assertEqual(fake.writes, [])

    async def test_a_task_asks_its_questions(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        answers = []
        async with app.run_test(size=(160, 50)) as pilot:
            await self._started(pilot, app)
            task = tasks.TASKS_BY_KEY["lance_duel"]
            app.push_screen(devapp.AskScreen(task, task.defaults({})), answers.append)
            await pilot.pause()
            app.screen.widgets["duels"].value = "3"
            await pilot.click("#run")
            await pilot.pause()
        self.assertEqual(answers[0]["duels"], "3")
        self.assertEqual(answers[0]["weapons"], "no")


if __name__ == "__main__":
    unittest.main()
