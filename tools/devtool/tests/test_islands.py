"""The islands flow's own parts (islands.py), on scratch folders: its configuration, the islands it
numbers, segment length on battery, a local island's end, the life logs and console it keeps, its
backups and status, and the detached start (no SSH, no Godot)."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

from devtool import evolution, islands


class IslandsTest(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.evolution = os.path.join(self.scratch.name, "evolution")
        os.makedirs(os.path.join(self.evolution, "logs"))
        patch = mock.patch.object(evolution, "evolution_dir", lambda: self.evolution)
        patch.start()
        self.addCleanup(patch.stop)

    def tearDown(self):
        self.scratch.cleanup()

    def test_the_configuration_has_defaults_and_takes_the_file(self):
        path = os.path.join(self.scratch.name, "islands.json")
        config = islands.load_config(path)
        self.assertEqual((config["local"], config["hosts"], config["hours"]), (2, [], 1.2), "No file: two islands here")
        with open(path, "w") as handle:
            json.dump({"local": 1, "hosts": [{"host": "lenovo", "user": "me", "islands": 2}], "hours": 0.5}, handle)
        config = islands.load_config(path)
        self.assertEqual((config["local"], config["hours"], config["speed"]), (1, 0.5, 8), "The file's, the rest default")

    def test_islands_are_numbered_from_this_machine(self):
        found = islands.islands_of({"local": 2, "hosts": [{"host": "a", "user": "me", "islands": 2}, {"host": "b"}]})
        self.assertEqual([(i["k"], i["host"]) for i in found], [(1, None), (2, None), (3, "a"), (4, "a"), (5, "b")])
        self.assertEqual(islands.target(found[2]), "me@a")
        self.assertEqual(islands.target(found[4]), "b")

    def test_segments_are_shorter_on_battery(self):
        config = {"hours": 1.2, "battery_hours": 0.4}
        with mock.patch.object(islands, "on_battery", lambda: False):
            self.assertEqual(islands.segment_hours(config), 1.2)
        with mock.patch.object(islands, "on_battery", lambda: True):
            self.assertEqual(islands.segment_hours(config), 0.4)
            self.assertEqual(islands.segment_hours({"hours": 1.0}), 1.0, "No battery_hours: the same")

    def test_a_local_island_is_gone_once_its_process_ends(self):
        island = {"k": 1, "host": None, "process": subprocess.Popen([sys.executable, "-c", "pass"])}
        island["process"].wait()
        self.assertTrue(islands.gone(island, {}))
        self.assertFalse(islands.gone({"k": 2, "host": None}, {}), "Not started: not gone")

    def test_life_logs_and_console_are_kept(self):
        with mock.patch.object(islands, "local_dir", lambda k: os.path.join(self.evolution, "islands", "island%d" % k)):
            for k in (1, 2):
                logs = os.path.join(self.evolution, "islands", "island%d" % k, "logs")
                os.makedirs(logs)
                with open(os.path.join(logs, "run_x_i%d.jsonl" % k), "w") as handle:
                    handle.write('{"life": %d}\n\n{"life": %d}' % (k, k + 10))
            self.assertEqual(islands.append_logs([{"k": 1}, {"k": 2}], "x"), 4)
            with open(os.path.join(self.evolution, "logs", "run_x.jsonl")) as handle:
                self.assertEqual(handle.read().splitlines(), ['{"life": 1}', '{"life": 11}', '{"life": 2}', '{"life": 12}'])
            console = os.path.join(self.scratch.name, "console.log")
            with open(console, "w") as handle:
                handle.write("noise\n123 EVO born x\nEVOSIM t=1\nSCRIPT ERROR: y\nmore noise\n")
            islands.keep_console(1, console)
            with open(os.path.join(self.evolution, "logs", "islands_console.log")) as handle:
                kept = handle.read()
            self.assertIn("EVO born x", kept)
            self.assertIn("SCRIPT ERROR", kept)
            self.assertNotIn("noise", kept)

    def test_backups_keep_the_newest_and_status_says_islands(self):
        with open(os.path.join(self.evolution, "save_0.sav"), "w") as handle:
            handle.write("save")
        for hours in (1, 2, 3, 4):
            islands.backup(hours * 3600.0)
        names = sorted(os.listdir(os.path.join(self.evolution, "backups")))
        self.assertEqual(len(names), islands.BACKUPS_KEPT)
        self.assertEqual(names[-1], "islands_t004.00h.sav")
        islands.write_master_status("running", 7200.0, {"waiting": [2, 3]})
        info = evolution.status(self.evolution)
        self.assertTrue(info["running"] and info["islands"], "This process: running")
        self.assertEqual(info["waiting"], [2, 3])

    def test_long_actions_start_detached_and_not_twice(self):
        started = []
        start = lambda command, log: started.append((command, log)) or 77
        self.assertEqual(evolution.islands_detached("run", "6", self.evolution, start, lambda text: None), 0)
        command, log = started[0]
        self.assertEqual(command[-2:], ["run", "6"])
        self.assertTrue(os.path.basename(log).startswith("islands_"))
        islands.write_master_status("running", 0.0)
        self.assertEqual(evolution.islands_detached("segment", "1", self.evolution, start, lambda text: None), 1)
        self.assertEqual(len(started), 1)


if __name__ == "__main__":
    unittest.main()
