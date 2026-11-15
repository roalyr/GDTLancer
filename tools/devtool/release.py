"""
A release: a versioned build of the game, committed and tagged.

    python3 tools/devtool/release.py version=0.1.0 [tests=yes] [soak=3] [out=<folder>] [tag=yes]

1. stops unless the working tree is clean and the version is new (no tag v<version> yet);
2. runs every GUT test (tests=yes; test_run.py: a test script that does not parse stops it by name,
   and GUT is stopped after test_run.TIMEOUT) and stops on a failure; then the soak check (soak.py: the real
   game left running `soak` minutes; 0 skips it) and stops on any problem it finds;
3. sets the Android preset's version/name to the version and counts version/code up by one
   (export_presets.cfg: only those two lines change, never its name or export path);
4. exports the debug APK (the release export has no keystore) to <out>/GDTLancer-<version>.apk;
5. commits export_presets.cfg ("Release <version>") and tags it v<version> (tag=yes).
Nothing is pushed: push the commit and the tag yourself when the build is good.
"""

import os
import re
import subprocess
import sys

if __package__ in (None, ""):
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from devtool.tasks import APK, ROOT, godot  # noqa: E402
    from devtool import soak as soak_check  # noqa: E402
    from devtool import test_run  # noqa: E402
else:
    from .tasks import APK, ROOT, godot
    from . import soak as soak_check
    from . import test_run

PRESETS = "export_presets.cfg"
VERSION = re.compile(r"^\d+(\.\d+){1,3}$")
CODE_LINE = re.compile(r"^version/code=(\d+)$", re.M)
NAME_LINE = re.compile(r'^version/name=".*"$', re.M)


def bump(text, version):
    """export_presets.cfg's text with version/name set and version/code one higher; (text, code)."""
    found = CODE_LINE.search(text)
    if not found or not NAME_LINE.search(text):
        raise ValueError("no version/code or version/name in " + PRESETS)
    code = int(found.group(1)) + 1
    text = CODE_LINE.sub("version/code=%d" % code, text, count=1)
    return NAME_LINE.sub('version/name="%s"' % version, text, count=1), code


def _output(command):
    done = subprocess.run(command, cwd=ROOT, env=soak_check.environment(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, errors="replace")
    return done.returncode, done.stdout


class Release:
    def __init__(self, version, root=ROOT, tests=True, out=None, tag=True, output=_output, say=print, soak=0,
                 unparsable=test_run.unparsable):
        self.version, self.root, self.tests, self.tag, self.soak = version, root, tests, tag, float(soak or 0)
        self.out = out or os.path.dirname(APK)
        self.output, self.say, self.unparsable = output, say, unparsable

    def apk(self):
        return os.path.join(self.out, "GDTLancer-%s.apk" % self.version)

    def go(self):
        """Runs the steps; returns 0, or the step's failure (1)."""
        if not VERSION.match(self.version):
            return self._stop("A version is numbers and dots, e.g. 0.1.0 (got %r)" % self.version)
        code, text = self.output(["git", "status", "--porcelain"])
        if code != 0 or text.strip():
            return self._stop("Commit or put away your changes first: a release builds what is committed.\n" + text.strip())
        code, text = self.output(["git", "tag", "--list", "v" + self.version])
        if text.strip():
            return self._stop("v%s is tagged already" % self.version)
        if self.tests:
            self.say("Running the tests...")
            bad = self.unparsable()
            if bad:
                return self._stop("These test scripts do not parse:\n" + "\n".join("  " + path for path in bad))
            code, text = self.output(test_run.gut_command())
            if code == 124:
                return self._stop("The tests did not finish in %d s (GUT stopped)" % test_run.TIMEOUT)
            failing = re.search(r"Failing tests\s+(\d+)", text)
            if failing is None or int(failing.group(1)) > 0:
                return self._stop("The tests did not pass:\n" + "\n".join(line for line in text.splitlines() if "Failed" in line or "Failing" in line))
        if self.soak > 0:
            self.say("Running the game for %g minutes (soak)..." % self.soak)
            code, text = self.output(soak_check.command(self.soak))
            problems = soak_check.judge(text)
            if problems:
                return self._stop("The soak found problems:\n" + "\n".join("  - " + problem for problem in problems))
            for line in soak_check.summary(text):
                self.say("  " + line)
        path = os.path.join(self.root, PRESETS)
        with open(path) as handle:
            before = handle.read()
        try:
            after, number = bump(before, self.version)
        except ValueError as error:
            return self._stop(str(error))
        with open(path, "w") as handle:
            handle.write(after)
        os.makedirs(self.out, exist_ok=True)
        self.say("Exporting %s (version code %d)..." % (self.apk(), number))
        code, text = self.output(godot("--no-window", "--export-debug", "Android", self.apk()))
        if not os.path.exists(self.apk()):
            with open(path, "w") as handle:
                handle.write(before)
            return self._stop("The export made no APK; " + PRESETS + " is put back.\n" + text[-2000:])
        message = "Release %s\n\nAndroid version code %d; debug APK %s." % (self.version, number, os.path.basename(self.apk()))
        if self.output(["git", "commit", "-q", "-m", message, "--", PRESETS])[0] != 0:
            return self._stop("The commit failed")
        if self.tag and self.output(["git", "tag", "-a", "v" + self.version, "-m", "GDTLancer " + self.version])[0] != 0:
            return self._stop("The tag failed")
        self.say("Released %s: %s%s. Push the commit%s when it is good." % (
            self.version, self.apk(), ", tagged v" + self.version if self.tag else "", " and the tag (git push --follow-tags)" if self.tag else ""))
        return 0

    def _stop(self, why):
        self.say("Release stopped: " + why)
        return 1


def main(argv):
    values = dict(arg.split("=", 1) for arg in argv if "=" in arg)
    yes = lambda key: str(values.get(key, "yes")).lower() in ("yes", "y", "true", "1")
    return Release(values.get("version", ""), tests=yes("tests"), out=values.get("out") or None, tag=yes("tag"),
                   soak=values.get("soak", "0")).go()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
