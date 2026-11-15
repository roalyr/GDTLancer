"""tools/dev.py's first run: when the venv or the install fails, it says why and what to do, exits 1,
and leaves no half-made venv behind (so the next run tries again)."""

import contextlib
import importlib.util
import io
import os
import shutil
import tempfile
import unittest

DEV = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "dev.py")


class FirstRunTest(unittest.TestCase):
    def test_a_failed_install_says_what_to_do_and_cleans_up(self):
        spec = importlib.util.spec_from_file_location("dev_entry", DEV)
        dev = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(dev)
        folder = tempfile.mkdtemp()
        try:
            dev.VENV = os.path.join(folder, "venv")
            dev.VENV_PYTHON = os.path.join(dev.VENV, "bin", "python")
            dev.REQUIREMENTS = os.path.join(folder, "no-such-requirements.txt")  # pip fails at once, no network needed
            out = io.StringIO()
            with contextlib.redirect_stdout(out), self.assertRaises(SystemExit) as caught:
                dev.install()
            self.assertEqual(caught.exception.code, 1)
            self.assertIn("Could not install Textual", out.getvalue())
            self.assertIn("python3-venv", out.getvalue())
            self.assertIn("tools/dev.py list", out.getvalue())
            self.assertFalse(os.path.exists(dev.VENV), "No half-made venv left")
        finally:
            shutil.rmtree(folder, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
