"""The soak judge (soak.judge) on made-up runs: what passes, what each problem looks like."""

import json
import unittest

from devtool import soak


def line(t, orphans=0, mem=90.0, wrecks=3, over=(), tables=None):
    sample = {"t": t, "game": int(t * 60), "fps": 40, "nodes": 900, "orphans": orphans, "objects": 9000, "resources": 900,
              "mem": mem, "bodies": 60, "wrecks": wrecks, "lances": 0, "over": list(over),
              "tables": tables if tables is not None else {"sound_last_played": 5, "threat_noticed": 0}}
    return "SOAK " + json.dumps(sample)


def run(*lines, done=True):
    return "\n".join(["Godot Engine v3.6.2", *lines] + (["SOAK done"] if done else [])) + "\n"


class JudgeTest(unittest.TestCase):
    def healthy(self, **changes):
        steps = [line(t * 0.5) for t in range(11)]
        return run(*steps, **changes)

    def test_a_healthy_run_passes(self):
        self.assertEqual(soak.judge(self.healthy()), [])
        self.assertEqual(soak.report(self.healthy(), say=lambda text: None), 0)

    def test_memory_rising_in_warm_up_is_allowed_after_it_not(self):
        warming = run(line(0.0, mem=80), line(1.0, mem=95), line(2.0, mem=96), line(5.0, mem=99))
        self.assertEqual(soak.judge(warming), [])
        leaking = run(line(0.0, mem=80), line(2.0, mem=90), line(5.0, mem=110))
        self.assertIn("memory grew", soak.judge(leaking)[0])

    def test_errors_orphans_caps_and_tables(self):
        text = run(line(0, tables={"threat_noticed": 0}), line(2, orphans=3, tables={"threat_noticed": 10}),
                   line(5, orphans=40, over=["wrecks 20 > 16"], tables={"threat_noticed": 300}),
                   "SCRIPT ERROR: Invalid get index 'x' (on base: 'Nil').", "ERROR: something", "   At: res://a.gd:3")
        problems = "\n".join(soak.judge(text))
        self.assertIn("2 error lines", problems)
        self.assertIn("orphaned nodes grew 3 -> 40", problems)
        self.assertIn("wrecks 20 > 16", problems)
        self.assertIn("table threat_noticed grew 10 -> 300", problems)

    def test_a_crash_or_hang_fails(self):
        self.assertIn("did not finish", soak.judge(self.healthy(done=False))[0])
        self.assertTrue(any("too few samples" in problem for problem in soak.judge(run(line(0)))))

    def test_the_command_runs_the_script_at_real_time(self):
        command = soak.command(3)
        self.assertIn("tools/soak.gd", command)
        self.assertIn("minutes=3", command)
        self.assertFalse(any("scale" in str(part) for part in command), "Never sped up: it would change how ships fly")


if __name__ == "__main__":
    unittest.main()
