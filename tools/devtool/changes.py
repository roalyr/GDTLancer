"""
What changed in the project since the last commit, and committing it: the Tools tab's review screen
(g). Everything git does not ignore is listed and committed together; nothing is ever pushed.
"""

import os
import subprocess

from .tasks import ROOT

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


def commit(message, root=ROOT):
    """Stages everything and commits it with `message`; returns (ok, git's words)."""
    if not message.strip():
        return False, "A commit needs a message"
    code, text = _git("add", "-A", root=root)
    if code != 0:
        return False, text.strip()
    code, text = _git("commit", "-q", "-m", message.strip(), root=root)
    if code != 0:
        return False, text.strip() or "git commit failed"
    code, text = _git("log", "-1", "--format=%h %s", root=root)
    return True, text.strip()
