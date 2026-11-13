"""Data kinds: what names a file before it may be deleted."""

import os
import tempfile
import unittest
from unittest import mock

from devtool import data


class ReferencesTest(unittest.TestCase):
    def test_a_file_is_named_by_its_path_its_id_or_as_a_material_by_its_name(self):
        with tempfile.TemporaryDirectory() as root:
            def put(rel, text):
                os.makedirs(os.path.dirname(os.path.join(root, rel)), exist_ok=True)
                with open(os.path.join(root, rel), "w") as handle:
                    handle.write(text)
            put("database/tools/tool_x.tres", 'template_id = "tool_x"\n')
            put("database/tools/tool_y.tres", 'template_id = "tool_y"\n')
            put("database/ships/ship.tres", 'equipped_tools = [ "tool_x" ]\n')
            put("scenes/a.tscn", '[ext_resource path="res://mat/mat_rock.tres" type="Material" id=1]\n')
            put("mat/mat_rock.tres", "")
            put("mat/mat_sand.tres", "")
            put("models/rock.glb", "glTF ... \"name\":\"mat_sand\"")
            put(".git/HEAD", 'tool_y "tool_y"')
            with mock.patch.object(data, "ROOT", root):
                self.assertEqual(data.template_id_of("res://database/tools/tool_x.tres"), "tool_x")
                self.assertEqual(data.references("res://database/tools/tool_x.tres"), ["res://database/ships/ship.tres"])
                self.assertEqual(data.references("res://database/tools/tool_y.tres"), [], "Unnamed (git's files are not the project's)")
                self.assertEqual(data.references("res://mat/mat_rock.tres"), ["res://scenes/a.tscn"])
                self.assertEqual(data.references("res://mat/mat_sand.tres"), [], "A model's material name is not a path")
                self.assertEqual(data.references("res://mat/mat_sand.tres", by_name=True), ["res://models/rock.glb"])


class SavesNamingTest(unittest.TestCase):
    def test_a_save_names_an_id_whole_as_godot_stores_strings(self):
        import struct
        with tempfile.TemporaryDirectory() as root, tempfile.TemporaryDirectory() as user:
            os.makedirs(os.path.join(root, "database"))
            for name in ("tool_x", "tool_x_heavy", "tool_y"):
                with open(os.path.join(root, "database", name + ".tres"), "w") as handle:
                    handle.write('template_id = "%s"\n' % name)
            os.makedirs(os.path.join(user, "savegames"))
            with open(os.path.join(user, "savegames", "save_0.sav"), "wb") as handle:
                word = "tool_x_heavy".encode()
                handle.write(struct.pack("<II", 4, len(word)) + word)
            with mock.patch.object(data, "ROOT", root), mock.patch.dict(os.environ, {"GODOT_USER_DIR": user}):
                self.assertEqual(data.saves_naming("res://database/tool_x_heavy.tres"), ["savegames/save_0.sav"])
                self.assertEqual(data.saves_naming("res://database/tool_x.tres"), [], "Only the whole id")
                self.assertEqual(data.saves_naming("res://database/tool_y.tres"), [])


if __name__ == "__main__":
    unittest.main()
