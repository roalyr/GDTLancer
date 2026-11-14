"""The menu, driven by Textual's test pilot against a stand-in for Godot (no files are written)."""

import os
import shutil
import tempfile
import unittest

from devtool.tests.test_worldmap import plain as worldmap_plain

from textual.widgets import DataTable, Input, Label, TextArea

from devtool import app as devapp
from devtool import constants, tasks
from devtool.tests.test_economy import ECONOMY

FILE = "res://database/factions/verdant.tres"
LAYOUT = "res://scenes/levels/sectors/sector_elace/sector_elace_layout.tscn"
MARKER = devapp.MARKERS + "haven_marker.gd"
ROTATION_FIELD = {"name": "rotation_degrees", "type": "Vector3", "hint": 0, "hint_name": "", "hint_string": "",
                  "default": {"$": "Vector3", "v": [0.0, 0.0, 0.0]}, "comment": "Its turn, degrees"}
HAVEN_FIELDS = [{"name": "translation", "type": "Vector3", "hint_name": "", "hint_string": "", "comment": "Its place"},
                {"name": "haven_id", "type": "String", "hint_name": "", "hint_string": "", "comment": ""},
                {"name": "repair", "type": "bool", "hint_name": "", "hint_string": "", "comment": ""}]


def read_location(sector):
    path = devapp.file_path("res://database/registry/locations/%s.tres" % sector)
    return devapp.read_text("res://database/registry/locations/%s.tres" % sector) if os.path.exists(path) else None


TRADE_ROUTE = {"commodity": "commodity_ore", "name": "Ore", "mass": 50.0, "sector": "sector_elace", "from": "port", "from_name": "Port",
               "to": "mill", "to_name": "Mill", "layout": "res://l.tscn", "node": "Havens/Port", "buy": 40, "sale": 55, "worst": 35,
               "best": 75, "km": 12.5, "factions": ["blue"]}


class FakeBridge:
    def __init__(self, user_dir=""):
        self.user_dir = user_dir
        self.writes = []
        self.checked = []
        self.log = []

    def call(self, command, **args):
        if command == "ping":
            return {"godot": "fake"}
        if command == "validate" and args.get("sections"):
            return ["factions", "locations", "sectors", "models"]
        if command == "validate":
            return [{"file": "res://x.tres", "problem": "Broken"}] if args.get("section") == "factions" else []
        if command == "models":
            return {"ships": {"res://scenes/prefabs/ships/placeholders/fighter_light.tscn": {"users": ["a"], "problems": []}},
                    "stations": {"res://scenes/prefabs/station/placeholders/haven.tscn": {"users": [], "problems": ["Too big"]}},
                    "rocks": {"res://assets/models/rocks/rock_01_6k.glb": {"users": ["asteroid fields"], "problems": []},
                              "res://assets/models/rocks/rock_02_3k.glb": {"users": [], "problems": []}}}
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
        if command in ("body_new", "body_remove", "sector_new", "sector_clone"):
            self.writes.append(dict(args, command=command))
            result = {"path": "res://x.tscn", "problems": [], "new": [], "files": ["res://scenes/levels/sectors/sector_elace/planet_elace_d/planet_elace_d.tscn"]}
            if command == "body_new":
                result["node"] = "SceneAssets/Planet Elace D"
            return result
        if command == "layout_new":
            self.writes.append(dict(args, command=command))
            return {"path": "res://scenes/levels/sectors/%s/%s_layout.tscn" % (args["sector"], args["sector"]), "problems": [], "new": []}
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
                    "starts": [{"path": FILE, "id": "start_default", "ship": "s", "location": "home", "bank": 3000, "storage": {"tool_laser": 1}}],
                    "trade": [dict(TRADE_ROUTE), dict(TRADE_ROUTE, to="den", to_name="Den", sale=30, worst=-20, best=-5, factions=[])]}
        if command == "economy":
            self.log.append(("economy", args["sector"]))
            return ECONOMY
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


class FakeGit:
    def __init__(self):
        self.committed = []

    def status(self):
        return [("changed", "database/factions/verdant.tres"), ("new", "database/registry/game_starts/start_test.tres")]

    def diff(self, path):
        return ["@@ -1 +1 @@", "-roster = [ ]", "+roster = [ \"fighter_light\" ]"] if path.endswith("verdant.tres") else ["(a new file)", "+[gd_resource]"]

    def commit(self, message):
        if not message:
            return False, "A commit needs a message"
        self.committed.append(message)
        return True, "abc123 " + message


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
            self.assertEqual(app.query_one("#models", DataTable).row_count, 4, "Ships, stations and rocks")
            self.assertEqual(app.model_rows[1].status, "1 problem")
            shown = [task for task in tasks.TASKS if not task.maintainer]
            self.assertEqual(app.query_one("#tasks", DataTable).row_count, len(shown), "The maintainer tasks hidden")
            self.assertFalse(app.check_action("new_era", ()), "Evolution's keys too")
            app.action_toggle_maintainer()
            await pilot.pause()
            self.assertEqual(app.query_one("#tasks", DataTable).row_count, len(tasks.TASKS), "m shows them")
            self.assertTrue(app.check_action("new_era", ()))

    async def test_the_overview_says_what_is_out_of_date_and_missing(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(160, 50)) as pilot:
            await self._started(pilot, app)
            self.assertFalse(app.outside_checks, "A stand-in bridge runs no programs of its own")
            app.setup = ["Blender not found (blender). Install Blender 3.6"]
            app.catalog = ["database/presets/CATALOG.md: its text"]
            app._show_problems([("parts", "res://database/presets/parts/preset_laser_light.tres",
                                 "damage not what its law_genes give: change law_genes, not the stats, then run apply_laws (Tools)")], [])
            summary = str(app.query_one("#summary").content)
            self.assertIn("a runs apply_laws", summary)
            self.assertIn("CATALOG.md is out of date", summary)
            self.assertIn("Blender not found", summary)
            self.assertNotIn("refit_archetypes", summary)

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
            self.assertEqual((copy["command"], copy["kind"], copy["from"], copy["sector"]),
                             ("body_new", "planet", "res://scenes/levels/sectors/sector_elace/planet_elace_a/planet_elace_a.tscn", "sector_elace"),
                             "A copy of a body is a new body, named by the rules")
            self.assertEqual(copy["values"]["translation"]["v"][0], 6000.0 + devapp.COPY_OFFSET * 5)
            self.assertEqual(copy["values"]["rotation_degrees"]["v"], [0.0, 30.0, 0.0], "A copy is turned as the original")
            self.assertIn(("res://scenes/levels/sectors/sector_elace/planet_elace_d/planet_elace_d.tscn", None), app.saved_text[0],
                          "ctrl+u takes the new body's files away")
            app._show_node("@")
            app.action_new_marker()
            await pilot.pause()
            self.assertIsInstance(app.screen, devapp.BodyScreen)
            app.screen.query_one("#body-kind").value = "moon"
            await pilot.pause()
            self.assertEqual(app.screen.query_one("#body-of").value, "a", "Its planets to pick from")
            app.screen.query_one("#body-ok").press()
            await self._started(pilot, app)
            self.assertEqual((fake.writes[-1]["command"], fake.writes[-1]["kind"], fake.writes[-1]["of"]), ("body_new", "moon", "a"))
            app._show_node("@")
            app.action_new_marker()
            await pilot.pause()
            app.screen.query_one("#body-kind").value = "prefab"
            await pilot.pause()
            app.screen.query_one("#body-ok").press()
            await self._started(pilot, app)
            self.assertEqual((fake.writes[-1]["command"], fake.writes[-1]["path"], fake.writes[-1]["name"]), ("scene_instance", scene, "Asteroid"))
            app._show_node("@SceneAssets/Planet A")
            app.action_remove_marker()
            await pilot.pause()
            self.assertIn("Port", str(app.screen.query_one(Label).content), "It says what rides with it")
            self.assertIn("planet_elace_a) goes too", str(app.screen.query_one(Label).content))
            app.screen.dismiss(True)
            await self._started(pilot, app)
            self.assertEqual((fake.writes[-1]["command"], fake.writes[-1]["node"]), ("body_remove", "SceneAssets/Planet A"))
            self.assertIn("res://scenes/levels/sectors/sector_elace/planet_elace_a/planet_elace_a.tscn", [path for path, _ in app.saved_text[0]],
                          "ctrl+u brings its folder back")

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

    async def test_fields_that_do_not_apply_are_hidden_and_not_saved(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(160, 60)) as pilot:
            await self._open_sector(pilot, app)
            field = lambda name, kind, **more: dict({"name": name, "type": kind, "hint": 0, "hint_name": "", "hint_string": "",
                                                     "default": None, "comment": ""}, **more)
            fields = [field("kind", "String", hint_name="enum", hint_string="patrol,field,landmark"),
                      field("owner_faction", "String", when={"kind": ["patrol"]}),
                      field("rocks", "int", when={"kind": ["field"]}),
                      field("prefer_share", "float", when={"owner_faction": {"not": [""]}})]
            form = app.query_one("#world-form", devapp.Form)
            form.show("Beacon", fields, {"kind": "field", "owner_faction": "", "rocks": 4, "prefer_share": 0.0})
            await pilot.pause()
            await pilot.pause()
            shown = lambda: [editor.field["name"] for editor in form.fields if editor.display]
            self.assertEqual(shown(), ["kind", "rocks"])
            rocks = form.fields[2]
            rocks.editor.value = "9"
            form.fields[0].editor.value = "patrol"
            await pilot.pause()
            self.assertEqual(shown(), ["kind", "owner_faction"], "Live, as the kind changes")
            self.assertEqual(form.changes(), {"kind": "patrol"}, "A hidden field's edit is not saved")
            form.fields[1].editor.value = "verdant"
            await pilot.pause()
            self.assertIn("prefer_share", shown(), "{not: [...]}: anything but those")

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

    async def test_a_sector_without_a_layout_is_listed_and_gets_one(self):
        fake = FakeBridge()
        app = devapp.DevApp(bridge_factory=lambda: fake)
        async with app.run_test(size=(160, 60)) as pilot:
            await self._started(pilot, app)
            app.query_one("TabbedContent").active = "world"
            await self._started(pilot, app)
            tree = app.query_one("#world-tree")
            sectors = [child.data["sector"] for child in tree.root.children if "sector" in child.data]
            self.assertTrue({"sector_cob", "sector_elace", "sector_lywin"} <= set(sectors), sectors)
            self.assertEqual(app.world["sector"], "sector_elace", "A sector with a layout opens first")
            locations = [child.data["location"] for child in tree.root.children if "location" in child.data]
            self.assertIn("res://database/registry/locations/sector_vidr.tres", locations, "A Location with no scene is listed too")
            self.assertNotIn("sector_vidr", sectors)
            cob = "res://scenes/levels/sectors/sector_cob/sector_cob_layout.tscn"
            app.load_sector("sector_cob", cob, ".")
            await self._started(pilot, app)
            self.assertTrue(app.world["nodes"]["."].get("missing"))
            self.assertIn("no layout yet", str(app.query_one("#world-form .form-title").content))
            self.assertIn(devapp.SCENE, app.world["nodes"], "Its scene's bodies are still there to move")
            app.action_new_marker()
            await pilot.pause()
            await pilot.press("y")
            await self._started(pilot, app)
            self.assertEqual((fake.writes[-1]["command"], fake.writes[-1]["sector"]), ("layout_new", "sector_cob"))
            files, _reload = app.saved_text
            self.assertEqual([(os.path.basename(path), text is None) for path, text in files],
                             [("sector_cob.tscn", False), ("sector_cob_layout.tscn", True)], "ctrl+u puts the scene back and takes the layout away")

    async def test_sectors_are_made_and_copied_from_the_world_tab(self):
        fake = FakeBridge()
        app = devapp.DevApp(bridge_factory=lambda: fake)
        async with app.run_test(size=(160, 60)) as pilot:
            await self._open_sector(pilot, app)
            app.query_one("#sector-new").press()
            await pilot.pause()
            app.screen.query_one(Input).value = "vidr"
            await pilot.press("enter")
            await self._started(pilot, app)
            self.assertEqual((fake.writes[-1]["command"], fake.writes[-1]["sector"]), ("sector_new", "sector_vidr"))
            self.assertIn(("res://database/registry/locations/sector_vidr.tres", read_location("sector_vidr")), app.saved_text[0],
                          "ctrl+u puts its location back as it was")
            app.load_sector("sector_elace", LAYOUT, ".")
            await self._started(pilot, app)
            app.query_one("#sector-clone").press()
            await pilot.pause()
            app.screen.query_one(Input).value = "sector_proving"
            await pilot.press("enter")
            await self._started(pilot, app)
            self.assertEqual((fake.writes[-1]["command"], fake.writes[-1]["sector"], fake.writes[-1]["to"]), ("sector_clone", "sector_elace", "sector_proving"))

    async def test_a_data_file_still_named_somewhere_is_not_deleted(self):
        fake = FakeBridge()
        app = devapp.DevApp(bridge_factory=lambda: fake)
        async with app.run_test(size=(160, 60)) as pilot:
            await self._started(pilot, app)
            tree = app.query_one("#data-tree")
            factions = next(node for node in tree.root.children if node.data["kind"] == "factions")
            factions.expand()
            await pilot.pause()
            tree.move_cursor(next(leaf for leaf in factions.children if leaf.data["path"] == FILE))
            self.assertEqual(tree.cursor_node.data.get("path"), FILE)
            app.action_delete_file()
            await pilot.pause()
            self.assertTrue(os.path.exists(devapp.file_path(FILE)), "Verdant is named by havens and starts")
            self.assertNotIsInstance(app.screen, devapp.ConfirmScreen, "Refused before asking")
            sounds = next(node for node in tree.root.children if node.data["kind"] == "sounds")
            sounds.expand()
            await pilot.pause()
            tree.move_cursor(sounds.children[0])
            self.assertEqual(tree.cursor_node.data.get("kind"), "sounds")
            app.action_delete_file()
            await pilot.pause()
            self.assertNotIsInstance(app.screen, devapp.ConfirmScreen, "The sound bank is one fixed file")

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

    async def test_a_rock_goes_into_the_fields_and_out(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(200, 60)) as pilot:
            await self._started(pilot, app)
            saved = []
            app.constant_worker = lambda name, value: saved.append((name, value))
            rocks = [row for row in app.model_rows if row.kind == "rock"]
            self.assertEqual(len(rocks), 2)
            self.assertGreater(rocks[0].lods, 0, "Its levels of detail from assets/models/rocks/lod/")
            table = app.query_one("#models", DataTable)
            table.move_cursor(row=app.model_rows.index(rocks[1]))
            app.action_toggle_field_rock()
            self.assertEqual(saved[-1][0], "FIELD_ROCK_MODELS")
            self.assertIn("rock_01_6k.glb", saved[-1][1])
            self.assertIn("rock_02_3k.glb", saved[-1][1])
            table.move_cursor(row=app.model_rows.index(rocks[0]))
            app.action_toggle_field_rock()
            self.assertEqual(len(saved), 1, "The last rock in the fields stays")

    async def test_a_placeholder_opens_its_shape_in_constants(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(200, 60)) as pilot:
            await self._started(pilot, app)
            table = app.query_one("#models", DataTable)
            table.move_cursor(row=[row.name for row in app.model_rows].index("fighter_light"))
            app.action_model("form")
            await pilot.pause()
            self.assertEqual(app.query_one("TabbedContent").active, "constants")
            self.assertEqual(app.constant_picked, "HULL_FORMS")
            text = app.query_one("#const-text", devapp.TextArea)
            self.assertIn('"fighter":', text.document.get_line(text.cursor_location[0]))

    async def test_changes_are_reviewed_and_committed(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        git = FakeGit()
        app.changes_source = git
        async with app.run_test(size=(180, 50)) as pilot:
            await self._started(pilot, app)
            await pilot.press("0")
            await pilot.pause()
            await pilot.press("g")
            await pilot.pause()
            screen = app.screen
            self.assertIsInstance(screen, devapp.ChangesScreen)
            self.assertEqual(screen.query_one("#change-list", DataTable).row_count, 2)
            self.assertIn("fighter_light", str(screen.query_one("#change-text").content))
            screen.query_one("#change-commit").press()
            await pilot.pause()
            self.assertEqual(git.committed, [], "No message, no commit")
            screen.query_one("#change-message", Input).value = "Roster: fighters"
            screen.query_one("#change-commit").press()
            await pilot.pause()
            self.assertEqual(git.committed, ["Roster: fighters"])
            self.assertNotIsInstance(app.screen, devapp.ChangesScreen)

    async def test_undo_steps_back_save_by_save(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(180, 50)) as pilot:
            await self._started(pilot, app)
            reloads = []
            with tempfile.TemporaryDirectory() as folder:
                path = os.path.join(folder, "x.txt")
                for text in ("one", "two"):
                    app._undo_point([(path, text)], lambda: reloads.append(1))
                app.action_undo_save()
                with open(path) as handle:
                    self.assertEqual(handle.read(), "two")
                app.action_undo_save()
                with open(path) as handle:
                    self.assertEqual(handle.read(), "one", "The save before")
                self.assertIsNone(app.saved_text)
                self.assertEqual(len(reloads), 2)

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

    async def test_two_archetypes_are_picked_for_a_duel(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(200, 60)) as pilot:
            await self._started(pilot, app)
            ran = []
            app.run_task = lambda task, values, wait=True: ran.append((task.key, values["a"], values["b"]))
            table = app.query_one("#archetypes", DataTable)
            app.action_archetype("duel")
            self.assertEqual(app.duel_first, "fighter_light")
            table.move_cursor(row=2)
            app.action_archetype("duel")
            self.assertEqual(ran, [("duel", "fighter_light", "raider_light")])
            self.assertIsNone(app.duel_first)
            app.action_archetype("duel")
            app.action_archetype("duel")
            self.assertIsNone(app.duel_first, "d twice on one cancels")
            self.assertEqual(len(ran), 1)

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

    async def test_parts_switch_kinds_and_open_in_data(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(180, 50)) as pilot:
            await self._started(pilot, app)
            await pilot.press("6")
            await pilot.pause()
            table = app.query_one("#parts", DataTable)
            self.assertEqual(table.row_count, 2, "Every part")
            await pilot.press("m")
            self.assertEqual(str(table.columns[list(table.columns)[0]].label), "Module")
            await pilot.press("k")
            self.assertEqual(app.parts_rows[0]["id"], "start_default")
            await pilot.press("enter")
            await self._started(pilot, app)
            self.assertEqual(app.query_one("TabbedContent").active, "data")

    async def test_trade_routes_rank_by_margin_and_open_the_seller(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(200, 50)) as pilot:
            await self._started(pilot, app)
            await pilot.press("6")
            await pilot.pause()
            await pilot.press("t")
            await pilot.pause()
            table = app.query_one("#parts", DataTable)
            self.assertEqual(table.row_count, 2)
            self.assertEqual(app.parts_rows[0]["to"], "mill", "A route NPCs fly, best margin first")
            self.assertIn("+15", str(table.get_row_at(0)[6]))
            self.assertIn("300", str(table.get_row_at(0)[9]), "15 WP a 50 kg unit: 300 WP a tonne")
            self.assertIn("sold at Port and bought at Den, Mill", str(app.query_one("#part-detail").content))
            loaded = []
            app.load_sector = lambda *args: loaded.append(args)
            await pilot.press("enter")
            await pilot.pause()
            self.assertEqual(loaded[0], ("sector_elace", "res://l.tscn", "Havens/Port"))
            self.assertEqual(app.query_one("TabbedContent").active, "world")

    async def test_a_sector_s_economy_opens_from_a_route_and_opens_a_haven(self):
        fake = FakeBridge()
        app = devapp.DevApp(bridge_factory=lambda: fake)
        async with app.run_test(size=(200, 50)) as pilot:
            await self._started(pilot, app)
            await pilot.press("6")
            await pilot.pause()
            await pilot.press("t")
            await pilot.pause()
            await pilot.press("e")
            await self._started(pilot, app)
            screen = app.screen
            self.assertIsInstance(screen, devapp.EconomyScreen)
            self.assertIn(("economy", "sector_elace"), fake.log, "The highlighted route's sector")
            self.assertEqual(screen.kind, "routes", "No problems: the routes first")
            self.assertEqual(screen.ship["id"], "trader_medium")
            table = screen.query_one("#economy-table", DataTable)
            self.assertEqual(table.row_count, 2)
            self.assertIn("Mill", str(table.get_row_at(0)[3]), "Most WP an hour first")
            await pilot.press("right_square_bracket")
            await pilot.pause()
            self.assertEqual(screen.ship["id"], "shuttle", "The next ship")
            self.assertIn("+0[", str(screen.query_one("#economy-table", DataTable).get_row_at(0)[10]), "No hold: no WP an hour")
            await pilot.click("#economy-ships")
            await pilot.pause()
            self.assertEqual(screen.kind, "ships")
            self.assertEqual(str(screen.query_one("#economy-table", DataTable).get_row_at(0)[0]), "hauler")
            await pilot.press("o")
            await pilot.pause()
            self.assertIn("after 0.x", " ".join(str(cell) for row in range(screen.query_one("#economy-table", DataTable).row_count)
                                               for cell in screen.query_one("#economy-table", DataTable).get_row_at(row)))
            await pilot.press("m")
            await pilot.pause()
            self.assertIn("[b]40[/b] / -", str(screen.query_one("#economy-table", DataTable).get_row_at(0)[2]), "It sells ore for 40")
            loaded = []
            app.load_sector = lambda *args: loaded.append(args)
            await pilot.press("down", "enter")
            await pilot.pause()
            self.assertNotIsInstance(app.screen, devapp.EconomyScreen)
            self.assertIn(("sector_x", "res://l.tscn", "Havens/Mill"), loaded, "The haven picked, in its sector")
            self.assertEqual(app.query_one("TabbedContent").active, "world")
            self.assertEqual(app.economy_ship, "shuttle", "The ship picked is kept for next time")

    async def test_problems_come_first_and_the_world_tab_opens_its_sector_s_economy(self):
        fake = FakeBridge()
        app = devapp.DevApp(bridge_factory=lambda: fake)
        problem = {"kind": "loop", "haven": "port", "commodity": "commodity_ore", "hard": True, "text": "Port sells Ore and buys it back"}
        ECONOMY["problems"].append(problem)
        try:
            async with app.run_test(size=(200, 50)) as pilot:
                await self._started(pilot, app)
                await pilot.press("5")
                await self._started(pilot, app)
                sector = app.world["sector"]
                await pilot.click("#sector-economy")
                await self._started(pilot, app)
                screen = app.screen
                self.assertIn(("economy", sector), fake.log, "The open sector")
                self.assertEqual(screen.kind, "problems")
                self.assertIn("1 problem", str(screen.query_one("#economy-title", Label).content))
                self.assertIn("buys it back", str(screen.query_one("#economy-detail").content))
                await pilot.press("escape")
                await pilot.pause()
                self.assertNotIsInstance(app.screen, devapp.EconomyScreen)
        finally:
            ECONOMY["problems"].remove(problem)

    async def test_a_sell_list_shows_what_it_charges(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(180, 50)) as pilot:
            await self._started(pilot, app)
            fields = [{"name": "sells", "type": "Dictionary", "hint_name": "", "hint_string": "", "comment": ""}]
            form = await self._form_with(pilot, app, fields, {"sells": {"commodity_ore": 0.5}}, MARKER)
            sells = form.fields[0].editor
            self.assertIsInstance(sells, devapp.PairsEditor)
            self.assertIn("charges 10 WP a unit", str(sells.rows()[0].query_one(".pair-about").content))

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
            form.fields[0].editor.value = "res://assets/audio/music/ambient/placeholder_ambient.ogg"
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
                self.assertNotIn("running", str(app.query_one("#tools-status").content), "Evolution shows with the maintainer tasks")
                await pilot.press("0")
                await pilot.press("x")
                self.assertFalse(os.path.exists(os.path.join(user_dir, "evolution", "stop")), "x is not there yet")
                await pilot.press("m")
                await pilot.pause()
                status = str(app.query_one("#tools-status").content)
                self.assertIn("running", status)
                self.assertIn("era 52", status)
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

    async def test_a_start_plays_from_the_parts_tab_and_sets_standings(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(180, 50)) as pilot:
            await self._started(pilot, app)
            ran = []
            app.run_task = lambda task, values, wait=True: ran.append((task.key, values["start"]))
            await pilot.press("6")
            await pilot.pause()
            await pilot.press("p")
            self.assertEqual(ran, [], "Only on a game start")
            await pilot.press("k")
            await pilot.press("p")
            self.assertEqual(ran, [("test_start", "start_default")])
            fields = [{"name": "starting_standing", "type": "Dictionary", "hint_name": "", "hint_string": "", "comment": ""}]
            form = await self._form_with(pilot, app, fields, {"starting_standing": {"blue": -0.7}},
                                         devapp.data.DEFINITIONS + "game_start_template.gd")
            standing = form.fields[0].editor
            self.assertIsInstance(standing, devapp.PairsEditor)
            self.assertIn("hostile", str(standing.rows()[0].query_one(".pair-about").content))

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

    async def test_traffic_is_edited_by_family(self):
        app = devapp.DevApp(bridge_factory=lambda: FakeBridge())
        async with app.run_test(size=(180, 50)) as pilot:
            await self._started(pilot, app)
            fields = [{"name": "traffic", "type": "Dictionary", "hint_name": "", "hint_string": "", "comment": ""}]
            form = await self._form_with(pilot, app, fields, {"traffic": {"": 4}}, devapp.data.DEFINITIONS + "faction_template.gd")
            traffic = form.fields[0].editor
            self.assertIsInstance(traffic, devapp.PairsEditor)
            self.assertIn("4 travellers", str(traffic.query_one(".pairs-total").content))
            traffic.add_row()
            await pilot.pause()
            self.assertEqual(form.changes(), {"traffic": {"": {"$": "int", "v": 4}, "fighter": {"$": "int", "v": 1}}},
                             "Families from the archetypes; \"\" is any")
            self.assertEqual(devapp.traffic_count({"traffic": {"": 4, "fighter": 1}}), 5)

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
