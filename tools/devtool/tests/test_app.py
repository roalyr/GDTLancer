"""The menu, driven by Textual's test pilot against a stand-in for Godot (no files are written)."""

import os
import shutil
import unittest

from textual.widgets import DataTable, Input, TextArea

from devtool import app as devapp
from devtool import constants, tasks

FILE = "res://database/factions/verdant.tres"
LAYOUT = "res://scenes/levels/sectors/sector_elace/sector_elace_layout.tscn"
MARKER = devapp.MARKERS + "haven_marker.gd"
HAVEN_FIELDS = [{"name": "translation", "type": "Vector3", "hint_name": "", "hint_string": "", "comment": "Its place"},
                {"name": "haven_id", "type": "String", "hint_name": "", "hint_string": "", "comment": ""},
                {"name": "repair", "type": "bool", "hint_name": "", "hint_string": "", "comment": ""}]


class FakeBridge:
    def __init__(self):
        self.writes = []
        self.checked = []
        self.log = []

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
        if command in ("write", "scene_write", "scene_add", "scene_remove"):
            self.writes.append(dict(args, command=command))
            result = {"path": args["path"], "problems": [], "new": []}
            if command == "scene_add":
                result["node"] = args["parent"] + "/" + args["name"] + "2"
            return result
        if command == "scene_nodes":
            return [
                {"node": ".", "name": "Layout", "parent": "", "type": "Spatial", "script": "res://layout.gd",
                 "fields": [{"name": "sector_id", "type": "String", "hint_name": "", "hint_string": "", "comment": ""}],
                 "values": {"sector_id": "sector_elace"}},
                {"node": "Havens", "name": "Havens", "parent": ".", "type": "Spatial", "script": "",
                 "fields": [HAVEN_FIELDS[0]], "values": {"translation": {"$": "Vector3", "v": [0.0, 0.0, 0.0]}}},
                {"node": "Havens/Port", "name": "Port", "parent": "Havens", "type": "Position3D", "script": MARKER,
                 "fields": HAVEN_FIELDS, "values": {"translation": {"$": "Vector3", "text": "", "v": [1000.0, 0.0, 2000.0]},
                                                    "haven_id": "port", "repair": True}}]
        if command == "sector_map":
            return [{"name": "Star", "kind": "star", "x": 0.0, "z": 0.0, "radius": 0.0, "node": ""},
                    {"name": "Port", "kind": "haven_marker", "x": 1000.0, "z": 2000.0, "radius": 0.0, "node": "Havens/Port"}]
        if command == "archetypes":
            design = {"pilot": "res://p.tres", "ship": "res://s.tres", "role": "r", "temperament": "measured", "traits": [], "lives": 10,
                      "fitness": 0.5, "skill": 0.5, "behavior": {"engage": 2.0}, "scene": "res://h.tscn", "length": 14.0, "value": 500,
                      "hull": 70.0, "cargo": 10.0, "slots": [2, 0, 0, 1], "mass": 4000.0, "top_speed": 150.0, "burst_speed": 150.0,
                      "accel": 90.0, "power": 50.0, "regen": 5.0, "signature": 1200.0, "gun_dps": 12.0, "parts": [], "flown_by": []}
            return {"ranges": {"engage": [0.3, 4.0, 1.0], "mercy": [0.0, 1.0, 0.5]},
                    "archetypes": [dict(design, name="raider_light"), dict(design, name="fighter_heavy"), dict(design, name="fighter_light")]}
        if command == "factions":
            return {"archetypes": ["fighter_light", "fighter_heavy", "raider_light"], "factions": [
                {"id": "blue", "path": "res://database/factions/verdant.tres", "display_name": "Blue", "enemies": ["red"], "at_war": ["red"],
                 "roster": ["fighter_light"], "havens": [{"sector": "sector_elace", "layout": LAYOUT, "node": "Havens/Port", "id": "port",
                                                          "name": "Port", "ships": {"blue": 4}}]},
                {"id": "green", "path": "res://database/factions/xenohive.tres", "display_name": "Green", "enemies": [], "at_war": [], "roster": [], "havens": []},
                {"id": "red", "path": "res://database/factions/violet.tres", "display_name": "Red", "enemies": ["blue"], "at_war": ["blue"], "roster": [], "havens": []}]}
        if command == "check_script":
            self.checked.append(args["source"])
            return {"ok": "BROKEN" not in args["source"]}
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


    async def _open_sector(self, pilot, app):
        await self._started(pilot, app)
        app.load_sector("sector_elace", LAYOUT, "Havens/Port")
        await self._started(pilot, app)

    async def test_a_marker_saves_only_what_changed(self):
        fake = FakeBridge()
        app = devapp.DevApp(bridge_factory=lambda: fake)
        async with app.run_test(size=(160, 60)) as pilot:
            await self._open_sector(pilot, app)
            form = app.query_one("#world-form", devapp.Form)
            self.assertEqual([f.field["name"] for f in form.fields], ["translation", "haven_id", "repair"])
            self.assertEqual(form.changes(), {}, "Unchanged as loaded")
            self.assertIn("[reverse bold]H[/]", str(app.query_one("#world-map").content), "The picked marker on the map")
            by_name = {f.field["name"]: f for f in form.fields}
            by_name["translation"].editor.value = "1500, 0, 2000"
            app.action_save_node()
            await self._started(pilot, app)
            self.assertEqual(fake.writes[0]["command"], "scene_write")
            self.assertEqual(fake.writes[0]["node"], "Havens/Port")
            self.assertEqual(fake.writes[0]["values"], {"translation": {"$": "Vector3", "v": [1500.0, 0.0, 2000.0]}})

    async def test_markers_are_added_copied_and_removed(self):
        fake = FakeBridge()
        app = devapp.DevApp(bridge_factory=lambda: fake)
        async with app.run_test(size=(160, 60)) as pilot:
            await self._open_sector(pilot, app)
            app.action_copy_marker()
            await self._started(pilot, app)
            copy = fake.writes[-1]
            self.assertEqual((copy["command"], copy["parent"], copy["script"]), ("scene_add", "Havens", MARKER))
            self.assertEqual(copy["values"]["translation"]["v"], [1000.0 + devapp.COPY_OFFSET, 0.0, 2000.0])
            app._show_node("Havens")
            app.action_new_marker()
            await pilot.pause()
            app.screen.query_one(Input).value = "NewPort"
            await pilot.press("enter")
            await self._started(pilot, app)
            self.assertEqual((fake.writes[-1]["parent"], fake.writes[-1]["name"], fake.writes[-1]["script"]), ("Havens", "NewPort", MARKER))
            app._show_node("Havens/Port")
            app.action_remove_marker()
            await pilot.pause()
            await pilot.press("y")
            await self._started(pilot, app)
            self.assertEqual((fake.writes[-1]["command"], fake.writes[-1]["node"]), ("scene_remove", "Havens/Port"))

    async def test_a_constant_is_checked_then_saved_in_place(self):
        fake = FakeBridge()
        scratch = os.path.join(tasks.ROOT, ".dev", "test_constants.gd")
        shutil.copy(os.path.join(tasks.ROOT, constants.PATH), scratch)
        app = devapp.DevApp(bridge_factory=lambda: fake, constants_path=".dev/test_constants.gd")
        try:
            async with app.run_test(size=(160, 60)) as pilot:
                await self._started(pilot, app)
                app._show_constant("LINEAR_DRAG")
                value = app.query_one("#const-value", Input)
                self.assertEqual(value.value, "0.5")
                value.value = "[1]"
                app.action_save_constant()
                await self._started(pilot, app)
                self.assertEqual(fake.checked, [], "Not a number: refused before Godot is asked")
                value.value = "BROKEN"
                app.action_save_constant()
                await self._started(pilot, app)
                with open(scratch) as handle:
                    self.assertNotIn("BROKEN", handle.read(), "Godot said no: not saved")
                value.value = "0.75"
                app.action_save_constant()
                await self._started(pilot, app)
                with open(scratch) as handle:
                    text = handle.read()
                self.assertIn("const LINEAR_DRAG = 0.75  # Velocity damping", text)
                app.action_undo_save()
                await self._started(pilot, app)
                app._show_constant("MEGASTRUCTURE_LAYERS")
                self.assertTrue(app.query_one("#const-text", TextArea).display, "A long value in a text box")
            with open(scratch) as handle, open(os.path.join(tasks.ROOT, constants.PATH)) as real:
                self.assertEqual(handle.read(), real.read(), "Undone")
        finally:
            os.remove(scratch)

    async def test_constants_are_found_and_grouped(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(160, 60)) as pilot:
            await self._started(pilot, app)
            app.query_one("#const-filter", Input).value = "linear drag"
            await pilot.pause()
            tree = app.query_one("#const-tree")
            leaves = [leaf.data for group in tree.root.children for leaf in group.children]
            self.assertIn("LINEAR_DRAG", leaves)
            app.action_group_constants()
            groups = [str(group.label).split(" (")[0] for group in tree.root.children]
            self.assertEqual(groups, ["float"])

    async def test_archetypes_are_listed_in_family_and_weight_order(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(200, 60)) as pilot:
            await self._started(pilot, app)
            self.assertEqual([d["name"] for d in app.archetype_view["archetypes"]], ["fighter_light", "fighter_heavy", "raider_light"])
            detail = str(app.query_one("#archetype-detail").content)
            self.assertIn("engage", detail)
            self.assertIn("not set", detail, "mercy has no value")
        self.assertEqual(devapp.gene_bar(1.0, 0.0, 1.0, 0.5).count("="), devapp.GENE_BAR - 1)
        self.assertEqual(devapp.gene_bar(0.0, 0.0, 1.0, 0.5)[0], "=")

    async def test_war_and_peace_and_rosters(self):
        fake = FakeBridge()
        app = devapp.DevApp(bridge_factory=lambda: fake)
        async with app.run_test(size=(200, 60)) as pilot:
            await self._started(pilot, app)
            wars = app.query_one("#wars", DataTable)
            wars.move_cursor(row=0, column=3)  # blue x red: at war, both lists
            app.action_toggle_war()
            await self._started(pilot, app)
            self.assertEqual(sorted((w["path"], tuple(w["values"]["enemies"])) for w in fake.writes),
                             [("res://database/factions/verdant.tres", ()), ("res://database/factions/violet.tres", ())], "Peace takes both lists")
            fake.writes.clear()
            wars.move_cursor(row=1, column=1)  # green x blue
            app.action_toggle_war()
            await self._started(pilot, app)
            self.assertEqual(fake.writes, [dict(command="write", path="res://database/factions/xenohive.tres", values={"enemies": ["blue"]})])
            fake.writes.clear()
            app._pick_faction("blue")
            roster = app.query_one("#roster")
            roster.select("raider_light")
            app.action_save_roster()
            await self._started(pilot, app)
            self.assertEqual(fake.writes[0]["values"], {"roster": ["fighter_light", "raider_light"]})

    async def test_every_tab_shows_the_shared_keys_and_help(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(160, 50)) as pilot:
            await self._started(pilot, app)
            for index in range(len(devapp.TABS)):
                await pilot.press(str(index + 1))
                await pilot.pause()
                self.assertEqual(app.query_one("TabbedContent").active, devapp.TABS[index])
                keys = {binding.key for _, binding, enabled, _ in app.active_bindings.values() if binding.show}
                self.assertIn("question_mark", keys, devapp.TABS[index])
            await pilot.press("1")
            keys = {binding.description for _, binding, _, _ in app.active_bindings.values() if binding.show}
            self.assertIn("Open", keys, "Enter opens a problem")
            await pilot.press("question_mark")
            await pilot.pause()
            self.assertIsInstance(app.screen, devapp.HelpScreen)
            await pilot.press("escape")
            await pilot.pause()
            self.assertNotIsInstance(app.screen, devapp.HelpScreen)

    async def test_a_problem_opens_where_it_is_edited(self):
        fake = FakeBridge()
        app = devapp.DevApp(bridge_factory=lambda: fake)
        async with app.run_test(size=(160, 50)) as pilot:
            await self._started(pilot, app)
            app._show_problems([("sectors", LAYOUT, "Broken haven")], [])
            app.action_open_problem()
            await self._started(pilot, app)
            self.assertEqual(app.query_one("TabbedContent").active, "world")
            self.assertEqual(app.world["sector"], "sector_elace")
            app._show_problems([("factions", FILE, "Broken")], [])
            app.action_open_problem()
            await self._started(pilot, app)
            self.assertEqual(app.query_one("TabbedContent").active, "data")
            self.assertEqual(app.open_file, FILE)

    async def test_typing_q_in_a_field_types_it(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(160, 60)) as pilot:
            await self._started(pilot, app)
            await pilot.press("7")
            await pilot.pause()
            self.assertEqual(app.query_one("TabbedContent").active, "constants")
            await pilot.press("ctrl+f")
            await pilot.press("q", "3")
            self.assertEqual(app.query_one("#const-filter", Input).value, "q3")
            self.assertTrue(app.is_running)


if __name__ == "__main__":
    unittest.main()
