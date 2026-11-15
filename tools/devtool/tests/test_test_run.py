"""test_run: every test script is compiled before GUT starts, and one that does not parse is named
(a stand-in bridge plays Godot's compiler here; test_bridge_live has the real check_script)."""

import os
import tempfile
import unittest

from devtool import test_run


class StandInCompiler:
    def call(self, command, **args):
        assert command == "check_script"
        return {"ok": "BROKEN" not in args["source"]}


class TestRunTest(unittest.TestCase):
    def test_scripts_that_do_not_parse_are_named(self):
        with tempfile.TemporaryDirectory() as root:
            folder = os.path.join(root, "src", "tests", "core")
            os.makedirs(folder)
            for name, text in [("test_a.gd", "extends GutTest\n"), ("test_b.gd", "extends GutTest\nBROKEN(\n"),
                               ("notes.txt", "BROKEN")]:
                with open(os.path.join(folder, name), "w") as handle:
                    handle.write(text)
            self.assertEqual(test_run.scripts(root=root), ["res://src/tests/core/test_a.gd", "res://src/tests/core/test_b.gd"])
            self.assertEqual(test_run.unparsable(bridge=StandInCompiler(), root=root), ["res://src/tests/core/test_b.gd"])

    def test_gut_runs_under_a_timeout(self):
        command = test_run.gut_command("res://src/tests/core")
        self.assertEqual(command[:2], ["timeout", str(test_run.TIMEOUT)])
        self.assertIn("addons/gut/gut_cmdln.gd", command)
        self.assertIn("-gdir=res://src/tests/core", command)

    def test_the_projects_test_scripts_are_found(self):
        self.assertGreater(len(test_run.scripts()), 50, "The project's tests are found")


if __name__ == "__main__":
    unittest.main()
