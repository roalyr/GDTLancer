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

    def test_only_the_picked_files_are_committed_and_one_can_be_put_back(self):
        self.write("a.tres", "changed\n")
        self.write("b.tres", "new\n")
        self.write("c.png", "stray\n")
        ok, _ = changes.commit("Only a", self.root, paths=["a.tres"])
        self.assertTrue(ok)
        self.assertEqual(changes.status(self.root), [("new", "b.tres"), ("new", "c.png")], "The others wait")
        self.assertEqual(changes.commit("None", self.root, paths=[])[0], False)
        self.write("a.tres", "changed again\n")
        self.assertTrue(changes.put_back("a.tres", self.root)[0])
        with open(os.path.join(self.root, "a.tres")) as handle:
            self.assertEqual(handle.read(), "changed\n", "As the last commit has it")
        subprocess.run(["git", "add", "b.tres"], cwd=self.root, check=True)
        self.assertTrue(changes.put_back("b.tres", self.root)[0])
        self.assertFalse(os.path.exists(os.path.join(self.root, "b.tres")), "A new file goes, staged or not")
        os.remove(os.path.join(self.root, "a.tres"))
        self.assertTrue(changes.put_back("a.tres", self.root)[0])
        self.assertTrue(os.path.exists(os.path.join(self.root, "a.tres")), "A deleted one comes back")
        self.assertEqual(changes.status(self.root), [("new", "c.png")])
        self.assertTrue(changes.unusual("c.png"))
        self.assertFalse(changes.unusual("database/factions/verdant.tres"))
