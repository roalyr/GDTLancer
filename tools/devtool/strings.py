"""The game's words (database/strings/strings.json, read by the Strings autoload): every key with its
text in each language. The Strings tab lists, edits, adds and removes them and shows what is wrong:
a language left empty, placeholders (%d, %s...) that differ between languages, keys the code asks
for that the file lacks. The file is written sorted, one key a block, so a diff shows what changed."""

import json
import os
import re

from . import tasks

PATH = "database/strings/strings.json"
LANGUAGES = ["en", "uk"]  # As Strings.LANGUAGES; the first is the fallback every key needs
LANGUAGE_NAMES = {"en": "English", "uk": "Ukrainian"}
PLACEHOLDER = re.compile(r"%[-+ 0#]*\d*(?:\.\d+)?[sdifcxXo%]")
# Where the code names a key outright (Strings.t("key"), a scene's "str" meta, a msg. key kept in a
# constant); keys built at run time ("options.%s.name", "word.", "name.") are not checked this way.
KEY_USES = [re.compile(r'Strings\.t\("([a-z0-9_.]+)"'), re.compile(r'"str": "([a-z0-9_.]+)"'),
            re.compile(r'"((?:msg|radio|chunk)\.[a-z0-9_.]+)"')]


def full_path():
    return os.path.join(tasks.ROOT, PATH)


def load(path=None):
    with open(path or full_path(), encoding="utf-8") as handle:
        return json.load(handle)


def dumps(table):
    return json.dumps(dict(sorted(table.items())), ensure_ascii=False, indent=1) + "\n"


def save(table, path=None):
    with open(path or full_path(), "w", encoding="utf-8") as handle:
        handle.write(dumps(table))


def placeholders(text):
    return sorted(match for match in PLACEHOLDER.findall(text or "") if match != "%%")


def entry_problems(entry):
    """What is wrong with one key's texts: ["no uk", "placeholders differ in uk"]."""
    out = []
    for language in LANGUAGES:
        if not str(entry.get(language, "")).strip():
            out.append("no " + language)
    base = placeholders(entry.get(LANGUAGES[0], ""))
    for language in LANGUAGES[1:]:
        text = entry.get(language, "")
        if text and placeholders(text) != base:
            out.append("placeholders differ in " + language)
    return out


def used_keys(root=None):
    """{key: first file naming it} over src/ and scenes/ (tests and the autoload itself left out)."""
    root = root or tasks.ROOT
    found = {}
    for folder in ("src", "scenes"):
        for directory, _, names in os.walk(os.path.join(root, folder)):
            if os.sep + "tests" in directory:
                continue
            for name in names:
                if not name.endswith((".gd", ".tscn")) or name == "Strings.gd":
                    continue
                path = os.path.join(directory, name)
                with open(path, encoding="utf-8", errors="replace") as handle:
                    text = handle.read()
                for pattern in KEY_USES:
                    for key in pattern.findall(text):
                        if not key.endswith("."):
                            found.setdefault(key, os.path.relpath(path, root))
    return found


def problems(table, used=None):
    """[(key, problem)]: each key's own, then the keys the code asks for that the file lacks."""
    out = [(key, problem) for key in sorted(table) for problem in entry_problems(table[key])]
    for key, where in sorted((used or {}).items()):
        if key not in table:
            out.append((key, "missing: used in " + where))
    return out


def valid_key(key):
    return re.fullmatch(r"[a-z0-9_]+(\.[a-z0-9_]+)+", key or "") is not None
