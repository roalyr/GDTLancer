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


if __name__ == "__main__":
    unittest.main()
