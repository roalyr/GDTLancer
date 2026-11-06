"""
The material library (assets/art/materials_generic/mat_*.tres) as the starter .blends see it: each
material's name, albedo and emission. Standard library only (tools/make_starters.py runs it inside
Blender; the development tool compares it with the starters' manifest to tell when they are stale).
"""

import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
LIBRARY = os.path.join(ROOT, "assets", "art", "materials_generic")
MANIFEST = os.path.join(ROOT, "assets", "models", "starters", "materials.txt")
SKIPPED_PREFIXES = ("hull_faction_",)  # Faction colours: a model takes its owner's through "Paint"


def library_materials():
    """[(display name, albedo, emission)] from the material library, sorted by name."""
    out = []
    for file_name in sorted(os.listdir(LIBRARY)):
        match = re.match(r"mat_(.+)\.tres$", file_name)
        if not match or match.group(1).startswith(SKIPPED_PREFIXES):
            continue
        with open(os.path.join(LIBRARY, file_name)) as handle:
            text = handle.read()
        out.append((match.group(1).replace("_", " ").title(), color_param(text, "albedo"), color_param(text, "emission")))
    return out


def color_param(text, name):
    match = re.search(r"shader_param/%s = Color\( ([^)]*) \)" % name, text)
    if not match:
        return (0.0, 0.0, 0.0, 1.0)
    return tuple(float(value) for value in match.group(1).split(","))


def manifest():
    """The text of the manifest the starters are built from: one material a line."""
    return "".join("%s | albedo %s | emission %s\n" % (name, ", ".join("%g" % c for c in albedo), ", ".join("%g" % c for c in emission))
                   for name, albedo, emission in library_materials())


def starters_stale():
    """Whether the library changed since the starters were last built (their manifest differs)."""
    if not os.path.exists(MANIFEST):
        return True
    with open(MANIFEST) as handle:
        return handle.read() != manifest()
