"""The release flow (release.Release) on a scratch project folder, with stand-in commands: where it
stops, what it changes in export_presets.cfg, and the commit and tag it makes."""

import os
import tempfile
import unittest

from devtool import release

PRESETS = """[preset.0]

name="Android"
export_path="../../../Dropbox/Dump/GDTLancer-rev.apk"

[preset.0.options]

version/code=4
version/name="1.0"
"""


class Commands:
    def __init__(self, dirty="", tags="", failing=0, export=True, soak="SOAK done\n"):
        self.dirty, self.tags, self.failing, self.export, self.soak = dirty, tags, failing, export, soak
        self.commands = []

    def output(self, command):
        self.commands.append(command)
        if command[:2] == ["git", "status"]:
            return 0, self.dirty
        if command[:3] == ["git", "tag", "--list"]:
            return 0, self.tags
        if "addons/gut/gut_cmdln.gd" in command:
            return 0, "Passing tests     9\nFailing tests     %d\n" % self.failing
        if "tools/soak.gd" in command:
            return 0, self.soak
        if "--export-debug" in command and self.export:
            open(command[-1], "w").close()
        return 0, ""


class ReleaseTest(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.root = self.scratch.name
        with open(os.path.join(self.root, "export_presets.cfg"), "w") as handle:
            handle.write(PRESETS)

    def tearDown(self):
        self.scratch.cleanup()

    def release(self, commands, version="0.2.0", **options):
        return release.Release(version, root=self.root, out=os.path.join(self.root, "out"), output=commands.output,
                               say=lambda text: None, **options)

    def presets(self):
        with open(os.path.join(self.root, "export_presets.cfg")) as handle:
            return handle.read()

    def test_a_release_versions_exports_commits_and_tags(self):
        commands = Commands()
        self.assertEqual(self.release(commands).go(), 0)
        self.assertIn('version/name="0.2.0"', self.presets())
        self.assertIn("version/code=5", self.presets())
        self.assertIn('name="Android"', self.presets(), "The preset's name and path stay")
        self.assertIn('export_path="../../../Dropbox/Dump/GDTLancer-rev.apk"', self.presets())
        self.assertTrue(os.path.exists(os.path.join(self.root, "out", "GDTLancer-0.2.0.apk")))
        git = [c for c in commands.commands if c[0] == "git" and c[1] in ("commit", "tag") and "--list" not in c]
        self.assertEqual([c[1] for c in git], ["commit", "tag"])
        self.assertEqual(git[0][-2:], ["--", "export_presets.cfg"], "Only the presets file")
        self.assertIn("v0.2.0", git[1])
        self.assertFalse(any("push" in c for c in commands.commands), "Never pushed")

    def test_it_stops_before_changing_anything(self):
        for commands, version in [(Commands(dirty=" M src/x.gd"), "0.2.0"), (Commands(tags="v0.2.0"), "0.2.0"),
                                  (Commands(failing=2), "0.2.0"), (Commands(), "v0.2")]:
            self.assertEqual(self.release(commands, version).go(), 1)
            self.assertEqual(self.presets(), PRESETS)

    def test_a_failed_export_puts_the_presets_back(self):
        self.assertEqual(self.release(Commands(export=False)).go(), 1)
        self.assertEqual(self.presets(), PRESETS)

    def test_bump(self):
        text, code = release.bump(PRESETS, "1.2.3")
        self.assertEqual(code, 5)
        self.assertEqual(text.count("version/"), 2)

    def test_a_soak_runs_before_the_export_and_stops_it_on_a_problem(self):
        good = "".join('SOAK {"t": %d, "game": %d, "fps": 40, "nodes": 1, "orphans": 0, "objects": 1, "resources": 1, '
                       '"mem": 90.0, "bodies": 1, "wrecks": 0, "lances": 0, "over": [], "tables": {}}\n' % (t, t * 60) for t in range(4))
        commands = Commands(soak=good + "SOAK done\n")
        self.assertEqual(self.release(commands, soak=3).go(), 0)
        ran = [i for i, c in enumerate(commands.commands) if "tools/soak.gd" in c or "--export-debug" in c]
        self.assertEqual(len(ran), 2)
        self.assertIn("tools/soak.gd", commands.commands[ran[0]], "The soak comes first")
        self.scratch.cleanup()
        self.setUp()
        commands = Commands(soak=good + "SCRIPT ERROR: boom\nSOAK done\n")
        self.assertEqual(self.release(commands, soak=3).go(), 1)
        self.assertEqual(self.presets(), PRESETS, "Nothing changed")
        self.assertFalse(any("--export-debug" in c for c in commands.commands))
        self.scratch.cleanup()
        self.setUp()
        commands = Commands()
        self.assertEqual(self.release(commands).go(), 0)
        self.assertFalse(any("tools/soak.gd" in c for c in commands.commands), "soak=0 (the default): none")
