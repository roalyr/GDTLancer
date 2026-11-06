"""The menu, driven by Textual's test pilot against a stand-in for Godot (no files are written)."""

import os
import shutil
import unittest

from devtool.tests.test_worldmap import plain as worldmap_plain

from textual.widgets import DataTable, Input, Label, TextArea

from devtool import app as devapp
from devtool import constants, tasks

FILE = "res://database/factions/verdant.tres"
LAYOUT = "res://scenes/levels/sectors/sector_elace/sector_elace_layout.tscn"
MARKER = devapp.MARKERS + "haven_marker.gd"
ROTATION_FIELD = {"name": "rotation_degrees", "type": "Vector3", "hint": 0, "hint_name": "", "hint_string": "",
                  "default": {"$": "Vector3", "v": [0.0, 0.0, 0.0]}, "comment": "Its turn, degrees"}
HAVEN_FIELDS = [{"name": "translation", "type": "Vector3", "hint_name": "", "hint_string": "", "comment": "Its place"},
                {"name": "haven_id", "type": "String", "hint_name": "", "hint_string": "", "comment": ""},
                {"name": "repair", "type": "bool", "hint_name": "", "hint_string": "", "comment": ""}]


class FakeBridge:
    def __init__(self, user_dir=""):
        self.user_dir = user_dir
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
        if command in ("write", "scene_write", "scene_add", "scene_remove", "scene_instance"):
            self.writes.append(dict(args, command=command))
            result = {"path": args["path"], "problems": [], "new": []}
            if command == "scene_add":
                result["node"] = args["parent"] + "/" + args["name"] + "2"
            if command == "scene_instance":
                result["node"] = "SceneAssets/" + args["name"] + "2"
            return result
        if command == "world_scene":
            return [{"node": "SceneAssets/Planet A", "name": "Planet A", "parent": "SceneAssets", "kind": "planet",
                     "scene": "res://scenes/levels/sectors/sector_elace/planet_elace_a/planet_elace_a.tscn",
                     "x": 6000.0, "y": 0.0, "z": 22000.0, "radius": 1000.0, "fields": [HAVEN_FIELDS[0], ROTATION_FIELD],
                     "values": {"translation": {"$": "Vector3", "v": [6000.0, 0.0, 22000.0]},
                                "rotation_degrees": {"$": "Vector3", "v": [0.0, 30.0, 0.0]}}}]
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
            return [{"name": "Star", "kind": "star", "x": 0.0, "y": 0.0, "z": 0.0, "radius": 0.0, "node": ""},
                    {"name": "Planet A", "kind": "planet", "x": 6000.0, "y": 500.0, "z": 22000.0, "radius": 1000.0, "node": "@SceneAssets/Planet A"},
                    {"name": "Port", "kind": "haven_marker", "x": 1000.0, "y": 0.0, "z": 2000.0, "radius": 0.0, "node": "Havens/Port",
                     "attached_to": "SceneAssets/Planet A"}]
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
        if command == "user_dir":
            return {"path": self.user_dir}
        if command == "parts":
            weapon = {"id": "tool_laser", "path": FILE, "name": "Laser", "origin": "stock", "value": 100, "used_by": ["start x"], "type": "laser",
                      "mount": "small", "mass": 300.0, "damage": 6.0, "cycle": 1.0, "dps": 6.0, "range": 1000.0, "ammo": 0, "power": 1.0}
            return {"weapons": [weapon, dict(weapon, id="preset_laser", origin="archetype", used_by=[])],
                    "modules": [{"id": "module_ab", "path": FILE, "name": "Afterburner", "origin": "stock", "value": 100, "used_by": [],
                                 "kind": "afterburner", "mass": 400.0, "effects": {"afterburner_thrust": 5e5}, "lance": False}],
                    "commodities": [{"id": "commodity_ore", "path": FILE, "name": "Ore", "origin": "stock", "value": 20, "used_by": [], "mass": 50.0}],
                    "starts": [{"path": FILE, "id": "start_default", "ship": "s", "location": "home", "bank": 3000, "storage": {"tool_laser": 1}}]}
        if command == "look":
            music_field = {"name": "stream", "type": "Object", "hint_name": "resource", "hint_string": "AudioStream", "comment": ""}
            return {"shaders": [{"path": "res://assets/art/shaders/solid.gdshader", "materials": ["res://m.tres"], "scenes": []}],
                    "paints": [{"faction": "verdant", "kind": "hull", "material": FILE, "albedo": {"$": "Color", "v": [0.2, 0.4, 0.2, 1.0]},
                                "pattern": "", "strength": 0.0}],
                    "patterns": [{"path": "res://p.png", "used_by": []}],
                    "music": {"scene": LAYOUT, "node": "AmbientMusic", "stream": "res://a.mp3", "fields": [music_field],
                              "values": {"stream": {"$": "Resource", "path": "res://a.mp3"}}}}
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
        for _ in range(3):  # Workers start workers (a save reloads its file), and forms mount after them
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
            self.assertIn("reverse]H", str(app.query_one("#world-map").content), "The picked marker on the map")
            app.query_one("#map-toggle").press()
            await pilot.pause()
            self.assertFalse(app.query_one("#world-map").display, "Hidden: the form gets the room")
            self.assertEqual(str(app.query_one("#map-toggle").label), "Show map")
            app.query_one("#map-toggle").press()
            await pilot.pause()
            self.assertTrue(app.query_one("#world-map").display)
            by_name = {f.field["name"]: f for f in form.fields}
            by_name["translation"].editor.value = "1500, 0, 2000"
            app.action_save_node()
            await self._started(pilot, app)
            self.assertEqual(fake.writes[0]["command"], "scene_write")
            self.assertEqual(fake.writes[0]["node"], "Havens/Port")
            self.assertEqual(fake.writes[0]["values"], {"translation": {"$": "Vector3", "v": [1500.0, 0.0, 2000.0]}})

    async def test_bodies_are_moved_placed_copied_and_removed_in_the_sector_scene(self):
        fake = FakeBridge()
        app = devapp.DevApp(bridge_factory=lambda: fake)
        async with app.run_test(size=(160, 60)) as pilot:
            await self._open_sector(pilot, app)
            scene = "res://scenes/levels/sectors/sector_elace/sector_elace.tscn"
            app._show_node("@SceneAssets/Planet A")
            await pilot.pause()
            self.assertIn("carries Port with it", str(app.query_one("#world-form .form-title").content))
            form = app.query_one("#world-form", devapp.Form)
            form.fields[0].editor.value = "7000, 0, 22000"
            app.action_save_node()
            await self._started(pilot, app)
            move = fake.writes[-1]
            self.assertEqual((move["command"], move["path"], move["node"]), ("scene_write", scene, "SceneAssets/Planet A"))
            self.assertEqual(app.world["picked"], "@SceneAssets/Planet A", "Still picked after the reload")
            app.action_copy_marker()
            await self._started(pilot, app)
            copy = fake.writes[-1]
            self.assertEqual((copy["command"], copy["scene"]), ("scene_instance", "res://scenes/levels/sectors/sector_elace/planet_elace_a/planet_elace_a.tscn"))
            self.assertEqual(copy["values"]["translation"]["v"][0], 6000.0 + devapp.COPY_OFFSET * 5)
            self.assertEqual(copy["values"]["rotation_degrees"]["v"], [0.0, 30.0, 0.0], "A copy is turned as the original")
            app._show_node("@")
            app.action_new_marker()
            await pilot.pause()
            self.assertIsInstance(app.screen, devapp.PlaceScreen)
            app.screen.query_one("#place-ok").press()
            await self._started(pilot, app)
            self.assertEqual(fake.writes[-1]["command"], "scene_instance")
            self.assertEqual(fake.writes[-1]["path"], scene)
            app._show_node("@SceneAssets/Planet A")
            app.action_remove_marker()
            await pilot.pause()
            self.assertIn("Port", str(app.screen.query_one(Label).content), "It says what rides with it")
            app.screen.dismiss(True)
            await self._started(pilot, app)
            self.assertEqual((fake.writes[-1]["command"], fake.writes[-1]["path"], fake.writes[-1]["node"]), ("scene_remove", scene, "SceneAssets/Planet A"))

    async def test_a_body_is_turned_in_the_form(self):
        fake = FakeBridge()
        app = devapp.DevApp(bridge_factory=lambda: fake)
        async with app.run_test(size=(160, 60)) as pilot:
            await self._open_sector(pilot, app)
            app._show_node("@SceneAssets/Planet A")
            await pilot.pause()
            form = app.query_one("#world-form", devapp.Form)
            self.assertEqual([f.field["name"] for f in form.fields], ["translation", "rotation_degrees"])
            form.fields[1].editor.value = "0, 45, 0"
            app.action_save_node()
            await self._started(pilot, app)
            self.assertEqual(fake.writes[-1]["values"], {"rotation_degrees": {"$": "Vector3", "v": [0.0, 45.0, 0.0]}}, "Only the turn")

    async def test_the_map_turns_to_the_side_and_filters(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(160, 60)) as pilot:
            await self._open_sector(pilot, app)
            app.query_one("#map-side").press()
            await pilot.pause()
            self.assertIn("from the side", str(app.query_one("#world-map").content))
            app.query_one("#filter-planet").press()
            await pilot.pause()
            self.assertNotIn("O", worldmap_plain(str(app.query_one("#world-map").content)).split("from the side")[0].replace("Port", ""))
            self.assertTrue(app.query_one("#filter-planet").has_class("off"))

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
                await pilot.press(devapp.TAB_KEYS[index])
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

    async def test_parts_switch_kinds_and_hide_archetype_parts(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(180, 50)) as pilot:
            await self._started(pilot, app)
            await pilot.press("6")
            await pilot.pause()
            table = app.query_one("#parts", DataTable)
            self.assertEqual(table.row_count, 2)
            await pilot.press("a")
            self.assertEqual(table.row_count, 1, "Stock only")
            await pilot.press("m")
            self.assertEqual(str(table.columns[list(table.columns)[0]].label), "Module")
            await pilot.press("k")
            self.assertEqual(app.parts_rows[0]["id"], "start_default")
            await pilot.press("enter")
            await self._started(pilot, app)
            self.assertEqual(app.query_one("TabbedContent").active, "data")

    async def test_look_shows_shaders_paints_and_saves_music(self):
        fake = FakeBridge()
        app = devapp.DevApp(bridge_factory=lambda: fake)
        async with app.run_test(size=(180, 50)) as pilot:
            await self._started(pilot, app)
            labels = [str(node.label) for node in app.query_one("#look-tree").root.children]
            self.assertEqual([label.split(" (")[0] for label in labels], ["Shaders", "Faction paints", "Paint patterns", "Music"])
            app._show_look_item({"look": "music"})
            await pilot.pause()
            form = app.query_one("#music-form", devapp.Form)
            form.fields[0].editor.value = "res://assets/audio/music/ambient/GDTLancer ambient 1.mp3"
            app.action_save_music()
            await self._started(pilot, app)
            self.assertEqual(fake.writes[-1]["command"], "scene_write")
            self.assertEqual(fake.writes[-1]["node"], "AmbientMusic")

    async def test_tools_show_evolution_running_and_ask_it_to_stop(self):
        import tempfile
        with tempfile.TemporaryDirectory() as user_dir:
            os.makedirs(os.path.join(user_dir, "evolution"))
            with open(os.path.join(user_dir, "evolution", "status.json"), "w") as handle:
                handle.write('{"state": "running", "pid": %d, "game_time": 7200, "lives": 40, "genomes": 90}' % os.getpid())
            with open(os.path.join(user_dir, "evolution", "era.json"), "w") as handle:
                handle.write('{"era": 52, "label": "fuel"}')
            app = devapp.DevApp(bridge_factory=lambda: FakeBridge(user_dir))
            async with app.run_test(size=(180, 50)) as pilot:
                await self._started(pilot, app)
                status = str(app.query_one("#tools-status").content)
                self.assertIn("running", status)
                self.assertIn("era 52", status)
                await pilot.press("0")
                await pilot.press("x")
                self.assertTrue(os.path.exists(os.path.join(user_dir, "evolution", "stop")))

    async def _form_with(self, pilot, app, fields, values, script):
        await pilot.press("8")
        form = app.query_one("#data-form", devapp.Form)
        form.show("test", fields, values, script)
        await self._started(pilot, app)
        return form

    async def test_the_starting_kit_is_edited_row_by_row(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(180, 50)) as pilot:
            await self._started(pilot, app)
            fields = [{"name": "starting_storage", "type": "Dictionary", "hint_name": "", "hint_string": "", "comment": ""},
                      {"name": "player_starting_location", "type": "String", "hint_name": "", "hint_string": "", "comment": ""}]
            form = await self._form_with(pilot, app, fields, {"starting_storage": {"tool_laser": 2}, "player_starting_location": "port"},
                                         devapp.data.DEFINITIONS + "game_start_template.gd")
            kit = form.fields[0].editor
            self.assertIsInstance(kit, devapp.PairsEditor)
            self.assertIn("worth 200 WP", str(kit.query_one(".pairs-total").content))
            self.assertIsInstance(form.fields[1].editor, devapp.Select, "Havens are picked from a list")
            self.assertEqual(form.changes(), {})
            kit.add_row()
            await pilot.pause()
            self.assertEqual(form.changes(), {"starting_storage": {"tool_laser": {"$": "int", "v": 2}, "module_ab": {"$": "int", "v": 1}}})

    async def test_a_buy_list_shows_prices_and_a_bad_row_is_not_saved(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(180, 50)) as pilot:
            await self._started(pilot, app)
            fields = [{"name": "buys", "type": "Dictionary", "hint_name": "", "hint_string": "", "comment": ""}]
            form = await self._form_with(pilot, app, fields, {"buys": {"commodity_ore": 1.5}}, MARKER)
            buys = form.fields[0].editor
            row = buys.rows()[0]
            self.assertIn("pays 30 WP a unit", str(row.query_one(".pair-about").content))
            self.assertIn("Buys only these 1", str(buys.query_one(".pairs-total").content))
            row.query_one(devapp.Input).value = ""
            await pilot.pause()
            with self.assertRaises(ValueError):
                form.changes()

    async def test_a_field_the_game_does_not_read_says_so(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(180, 50)) as pilot:
            await self._started(pilot, app)
            fields = [{"name": "danger_level", "type": "int", "hint_name": "", "hint_string": "", "comment": ""},
                      {"name": "connections", "type": "PoolStringArray", "hint_name": "", "hint_string": "", "comment": ""}]
            form = await self._form_with(pilot, app, fields, {"danger_level": 0, "connections": []},
                                         devapp.data.DEFINITIONS + "location_template.gd")
            self.assertEqual(len(form.fields[0].query(".not-in-game")), 1)
            self.assertEqual(len(form.fields[1].query(".not-in-game")), 0)

    async def test_typing_q_in_a_field_types_it(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(160, 60)) as pilot:
            await self._started(pilot, app)
            await pilot.press("9")
            await pilot.pause()
            self.assertEqual(app.query_one("TabbedContent").active, "constants")
            await pilot.press("ctrl+f")
            await pilot.press("q", "3")
            self.assertEqual(app.query_one("#const-filter", Input).value, "q3")
            self.assertTrue(app.is_running)


if __name__ == "__main__":
    unittest.main()
