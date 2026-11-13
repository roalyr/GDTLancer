"""changes.py on a scratch git repository: what it lists, the diff of a changed and a new file, and
a commit of everything."""

import os
import subprocess
import tempfile
import unittest

from devtool import changes


class ChangesTest(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.root = self.scratch.name
        for args in (["init", "-q"], ["config", "user.email", "t@example.com"], ["config", "user.name", "Test"]):
            subprocess.run(["git"] + args, cwd=self.root, check=True)
        self.write("a.tres", "roster = [ ]\n")
        subprocess.run(["git", "add", "-A"], cwd=self.root, check=True)
        subprocess.run(["git", "commit", "-q", "-m", "start"], cwd=self.root, check=True)

    def tearDown(self):
        self.scratch.cleanup()

    def write(self, name, text):
        with open(os.path.join(self.root, name), "w") as handle:
            handle.write(text)

    def test_lists_diffs_and_commits(self):
        self.assertEqual(changes.status(self.root), [])
        self.write("a.tres", "roster = [ \"fighter_light\" ]\n")
        self.write("b.tres", "new\n")
        self.assertEqual(changes.status(self.root), [("changed", "a.tres"), ("new", "b.tres")])
        self.assertIn('+roster = [ "fighter_light" ]', changes.diff("a.tres", self.root))
        self.assertEqual(changes.diff("b.tres", self.root), ["(a new file)", "+new"])
        self.assertEqual(changes.commit("  ", self.root)[0], False)
        ok, line = changes.commit("Roster", self.root)
        self.assertTrue(ok)
        self.assertTrue(line.endswith("Roster"))
        self.assertEqual(changes.status(self.root), [])
