"""The new-era flow (evolution.NewEra) on a scratch evolution folder, with stand-in commands: the
order of its steps, its backup, and where it stops."""

import json
import os
import tempfile
import unittest

from devtool import evolution


class Runs:
    """Stand-in for the commands: records them; export_presets writes a draft into its --out folder."""

    def __init__(self, presets_dir, fail=None, changed=True):
        self.presets_dir, self.fail, self.changed = presets_dir, fail, changed
        self.commands, self.started = [], []

    def run(self, command):
        self.commands.append(command)
        text = " ".join(command)
        if self.fail and self.fail in text:
            return 1
        if "export_presets.gd" in text:
            out = next(arg for arg in command if arg.startswith("--out=")).split("res://database/presets/", 1)[1]
            os.makedirs(os.path.join(self.presets_dir, out, "archetypes"), exist_ok=True)
            open(os.path.join(self.presets_dir, out, "archetypes", "preset_x.tres"), "w").close()
        if command[:3] == ["git", "diff", "--cached"]:
            return 1 if self.changed else 0
        return 0

    def start(self, command, log):
        self.started.append((command, log))
        return 4242


class NewEraTest(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.folder = os.path.join(self.scratch.name, "evolution")
        self.presets = os.path.join(self.scratch.name, "presets")
        os.makedirs(os.path.join(self.folder, "backups"))
        os.makedirs(os.path.join(self.presets, "drafts_era50_min10"))
        with open(os.path.join(self.folder, "save_0.sav"), "wb") as handle:
            handle.write(b"evolution" * 100)
        open(os.path.join(self.folder, "backups", "era51_freeze_h20_20261104.sav"), "w").close()
        open(os.path.join(self.folder, "backups", "auto_t228.00h.sav"), "w").close()

    def tearDown(self):
        self.scratch.cleanup()

    def flow(self, runs, **options):
        settings = dict(label="freeze", next_label="fuel", presets_dir=self.presets, run=runs.run, start_process=runs.start, say=lambda text: None)
        settings.update(options)
        return evolution.NewEra(self.folder, **settings)

    def status(self, **info):
        with open(os.path.join(self.folder, "status.json"), "w") as handle:
            json.dump(info, handle)

    def test_the_era_is_guessed_from_names_then_read_from_era_json(self):
        self.assertEqual(evolution.era(self.folder, self.presets), (51, "freeze", True))
        with open(os.path.join(self.folder, "era.json"), "w") as handle:
            json.dump({"era": 52, "label": "fuel"}, handle)
        self.assertEqual(evolution.era(self.folder, self.presets), (52, "fuel", False))

    def test_a_run_is_running_only_while_its_process_lives(self):
        self.status(state="running", pid=os.getpid())
        self.assertTrue(evolution.status(self.folder)["running"])
        self.status(state="done", pid=os.getpid())
        self.assertFalse(evolution.status(self.folder)["running"], "Left behind by a finished run")
        self.status(state="running", pid=2 ** 22 + 12345)
        self.assertFalse(evolution.status(self.folder)["running"], "Its process died (a blackout)")

    def test_the_whole_flow_in_order(self):
        self.status(state="done", pid=1, game_time=72000.0)
        runs = Runs(self.presets)
        self.assertEqual(self.flow(runs).go(), 0)
        backup = os.path.join(self.folder, "backups", evolution.backup_name(51, "freeze", 72000.0))
        self.assertTrue(os.path.exists(backup), "era51_freeze_t20.0h_<today>.sav")
        with open(backup, "rb") as handle:
            self.assertEqual(handle.read(), b"evolution" * 100)
        texts = [" ".join(command) for command in runs.commands]
        exports = [text for text in texts if "export_presets.gd" in text]
        self.assertEqual(len(exports), 2)
        self.assertIn("--save=" + backup, exports[0], "Drafts come from the checked copy, not the live save")
        self.assertIn("--out=res://database/presets/drafts_era51_min10/", exports[0])
        self.assertIn("--min-lives=5", exports[1])
        self.assertLess(texts.index(exports[1]), [i for i, t in enumerate(texts) if "classify_presets" in t][0])
        commit = next(command for command in runs.commands if command[:2] == ["git", "commit"])
        self.assertEqual(commit[-2:], ["--", "database/presets"], "Commits only the presets")
        self.assertIn("Era 51 preset drafts (freeze)", " ".join(commit))
        era = json.load(open(os.path.join(self.folder, "era.json")))
        self.assertEqual((era["era"], era["label"], era["game_time"]), (52, "fuel", 72000.0))
        command, log = runs.started[0]
        self.assertIn("--new-era", command)
        self.assertEqual(os.path.basename(log), "era52_fuel.log")

    def test_it_refuses_while_evolution_runs(self):
        self.status(state="running", pid=os.getpid())
        runs = Runs(self.presets)
        self.assertEqual(self.flow(runs).go(), 1)
        self.assertEqual(runs.commands, [])
        self.assertEqual(len(os.listdir(os.path.join(self.folder, "backups"))), 2, "No backup made")
        self.assertFalse(os.path.exists(os.path.join(self.folder, "era.json")))

    def test_a_failed_export_stops_before_the_new_era(self):
        runs = Runs(self.presets, fail="--min-lives=5")
        self.assertEqual(self.flow(runs).go(), 1)
        self.assertEqual(runs.started, [])
        self.assertFalse(os.path.exists(os.path.join(self.folder, "era.json")), "The era is not moved on")
        self.assertEqual(len(os.listdir(os.path.join(self.folder, "backups"))), 3, "but the backup stays")

    def test_backups_are_never_overwritten(self):
        runs = Runs(self.presets)
        self.flow(runs, start=False).go()
        os.remove(os.path.join(self.folder, "era.json"))
        self.flow(runs, start=False).go()
        names = sorted(os.listdir(os.path.join(self.folder, "backups")))
        self.assertEqual(len([n for n in names if n.startswith("era51_freeze_2")]), 2)
        self.assertTrue(any(n.endswith("_2.sav") for n in names))

    def test_drafts_already_there_are_left_unless_asked(self):
        os.makedirs(os.path.join(self.presets, "drafts_era51_min5"))
        os.makedirs(os.path.join(self.presets, "drafts_era51_min10"))
        open(os.path.join(self.presets, "drafts_era51_min5", "edited.tres"), "w").close()
        runs = Runs(self.presets)
        self.assertEqual(self.flow(runs, start=False).go(), 0)
        self.assertFalse(any("export_presets" in " ".join(c) for c in runs.commands), "Both folders exist: no export")
        self.assertTrue(any("classify_presets" in " ".join(c) for c in runs.commands))
        os.remove(os.path.join(self.folder, "era.json"))
        runs = Runs(self.presets)
        self.flow(runs, start=False, redo_drafts=True).go()
        self.assertEqual(len([c for c in runs.commands if "export_presets" in " ".join(c)]), 2)

    def test_a_fresh_start_and_no_commit(self):
        runs = Runs(self.presets)
        self.assertEqual(self.flow(runs, fresh=True, commit=False).go(), 0)
        self.assertFalse(any(command[0] == "git" for command in runs.commands))
        self.assertIn("--new", runs.started[0][0])
        self.assertNotIn("--new-era", runs.started[0][0])

    def test_bad_names_are_refused_first(self):
        runs = Runs(self.presets)
        self.assertEqual(self.flow(runs, next_label="Fuel Era").go(), 1)
        self.assertEqual(runs.commands, [])

    def test_the_run_starts_detached_with_its_console_in_the_log(self):
        log = os.path.join(self.folder, "era52_fuel.log")
        import time
        evolution.start_detached(["sh", "-c", "echo EVOSIM running"], log)
        text = ""
        for _ in range(50):
            with open(log) as handle:
                text = handle.read()
            if text:
                break
            time.sleep(0.1)
        self.assertIn("EVOSIM running", text)

    def test_user_dir_is_godots(self):
        self.assertTrue(evolution.user_dir().endswith(os.path.join("godot", "app_userdata", "GDTLancer-rev")))


if __name__ == "__main__":
    unittest.main()
