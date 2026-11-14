"""
The model inventory: every ship and station model scene, and every rock model, with its files on disk (source .blend or
.glb, levels of detail, hit surface) and, from the bridge, who uses it and its model check. The
Models tab shows these rows.
"""

import glob
import os
import re

from .bridge import file_path
from .tasks import ROOT

GLB_IN_SCENE = re.compile(r'\[ext_resource path="(res://[^"]+\.glb)"')


NOZZLE_DIRECTIONS = ("rear", "front", "top", "bottom", "left", "right")  # ShipModel.NOZZLE_DIRECTIONS, in this order


class ModelRow:
    def __init__(self, scene, kind, users, problems, carries=None):
        self.scene, self.kind, self.users, self.problems = scene, kind, users, problems
        self.carries = carries or {}  # A ship's {"nozzles": {direction: n}, "weapons": n, "modules": n} (ModelCheck.ship_summary)
        self.name = os.path.splitext(os.path.basename(scene))[0]
        self.placeholder = "/placeholders/" in scene
        self.glb = scene if scene.endswith(".glb") else _glb_of(scene)  # A rock is its .glb
        base = os.path.splitext(file_path(self.glb))[0] if self.glb else None
        self.blend = base + ".blend" if base and os.path.exists(base + ".blend") else None
        folder = os.path.dirname(file_path(self.glb)) if self.glb else None
        self.lods = len(glob.glob(os.path.join(folder, "lod", self.name + "_LOD*.glb"))) if folder else 0
        self.hit = bool(folder) and os.path.exists(os.path.join(folder, "hit", self.name + "_hit.res"))

    @property
    def source(self):
        if self.placeholder:
            return "primitives"
        if self.blend:
            return ".blend"
        return ".glb" if self.glb else "code"

    @property
    def stale(self):
        """The .blend changed since the last import (re-run the import)."""
        return bool(self.blend and self.glb) and os.path.getmtime(self.blend) > os.path.getmtime(file_path(self.glb))

    @property
    def status(self):
        if self.problems:
            return "%d problem%s" % (len(self.problems), "" if len(self.problems) == 1 else "s")
        return "re-import" if self.stale else "OK"

    def carries_line(self):
        """A ship's nozzles by direction and its hardpoints, for the detail; "" for others."""
        if not self.carries:
            return ""
        nozzles = self.carries.get("nozzles", {})
        ways = ", ".join("%s %d" % (way, nozzles[way]) for way in NOZZLE_DIRECTIONS if nozzles.get(way))
        return "Nozzles: %s  ·  Hardpoints: %d weapon, %d module" % (ways or "none", self.carries.get("weapons", 0), self.carries.get("modules", 0))

    def import_target(self):
        """What to give tools/import_model.sh: the .blend if there is one, else the .glb."""
        source = self.blend or (file_path(self.glb) if self.glb else None)
        return os.path.relpath(source, ROOT) if source else None


def _glb_of(scene):
    try:
        with open(file_path(scene)) as handle:
            found = GLB_IN_SCENE.search(handle.read())
    except OSError:
        return None
    return found.group(1) if found else None


def rows(report):
    """ModelRows from the bridge's `models` report, ships first, each kind by name."""
    out = []
    for kind, key in (("ship", "ships"), ("station", "stations"), ("rock", "rocks")):
        for scene in sorted(report.get(key, {}), key=lambda path: os.path.basename(path)):
            entry = report[key][scene]
            out.append(ModelRow(scene, kind, entry.get("users", []), entry.get("problems", []), entry.get("carries")))
    return out
