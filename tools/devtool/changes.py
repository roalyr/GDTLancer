"""
What changed in the project since the last commit, and committing it: the Tools tab's review screen
(g). Everything git does not ignore is listed; the files picked (all, by default) are committed
together, and one file can be put back as the last commit had it. Nothing is ever pushed.
"""

import os
import subprocess

from .tasks import ROOT

# Where content and code live: a change elsewhere (a screenshot dropped in the project, a scratch
# folder) is marked on the review screen, so it is not committed by accident.
USUAL_PLACES = ("database/", "assets/", "scenes/", "src/", "docs/", "tools/", "addons/", "README.md",
                "project.godot", "export_presets.cfg", "default_env.tres", ".gitignore")


def unusual(path):
    """True for a change outside the usual places (USUAL_PLACES)."""
    return not any(path == place or path.startswith(place) for place in USUAL_PLACES)


STATES = {"M": "changed", "A": "added", "D": "deleted", "R": "renamed", "??": "new", "U": "conflict"}


def _git(*args, root=ROOT):
    done = subprocess.run(["git"] + list(args), cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return done.returncode, done.stdout


def status(root=ROOT):
    """[(state word, path)] of every change git sees, sorted by path."""
    code, text = _git("status", "--porcelain", "--untracked-files=all", root=root)
    if code != 0:
        raise RuntimeError(text.strip() or "git status failed")
    out = []
    for line in text.splitlines():
        if len(line) < 4:
            continue
        code, path = line[:2], line[3:]
        if " -> " in path:  # A rename: the new name
            path = path.split(" -> ", 1)[1]
        word = STATES.get(code.strip(), None) or STATES.get(code.strip()[:1], "changed")
        out.append((word, path.strip('"')))
    return sorted(out, key=lambda item: item[1])


def diff(path, root=ROOT, limit=400):
    """The change to one file as diff lines (a new file: its first lines, all added)."""
    code, text = _git("diff", "HEAD", "--", path, root=root)
    if code == 0 and text.strip():
        lines = text.splitlines()
    else:
        full = os.path.join(root, path)
        try:
            with open(full, errors="replace") as handle:
                lines = ["(a new file)"] + ["+" + line.rstrip("\n") for line in handle.readlines()[:limit]]
        except (OSError, UnicodeDecodeError):
            lines = ["(a new file)" if os.path.exists(full) else "(deleted)"]
    return lines[:limit] + (["... (%d more lines)" % (len(lines) - limit)] if len(lines) > limit else [])


def commit(message, root=ROOT, paths=None):
    """Stages and commits `paths` (None: every change) with `message`; returns (ok, git's words).
    Only those paths go in, whatever else is staged."""
    if not message.strip():
        return False, "A commit needs a message"
    if paths is not None and not paths:
        return False, "No file picked to commit"
    pathspec = ["--"] + list(paths) if paths is not None else []
    code, text = _git("add", "-A", *pathspec, root=root)
    if code != 0:
        return False, text.strip()
    code, text = _git("commit", "-q", "-m", message.strip(), *pathspec, root=root)
    if code != 0:
        return False, text.strip() or "git commit failed"
    code, text = _git("log", "-1", "--format=%h %s", root=root)
    return True, text.strip()


def put_back(path, root=ROOT):
    """`path` as the last commit has it: a changed or deleted file comes back from it, a new one is
    removed (unstaged first). Returns (ok, what was done)."""
    known, _ = _git("cat-file", "-e", "HEAD:" + path, root=root)
    if known == 0:
        code, text = _git("checkout", "HEAD", "--", path, root=root)
        return (True, "put back: " + path) if code == 0 else (False, text.strip())
    _git("rm", "-q", "--cached", "--ignore-unmatch", "--", path, root=root)
    full = os.path.join(root, path)
    try:
        if os.path.isdir(full) and not os.path.islink(full):
            return False, "%s is a folder: remove it by hand" % path
        if os.path.exists(full) or os.path.islink(full):
            os.remove(full)
    except OSError as error:
        return False, str(error)
    return True, "removed (it was new): " + path
