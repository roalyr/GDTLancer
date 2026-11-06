"""
The kinds of data the tool edits: where each kind's files are, what script makes a new one, and
how to name it. The Data tab lists these; forms come from each file's script (the bridge's schema),
so a field added to a template script shows up without a change here. A new kind of data: a Kind.
"""

import glob
import os

from .tasks import ROOT

DEFINITIONS = "res://database/definitions/"


class Kind:
    """`script` makes a new file; or, with `copies`, a new file is a copy of the one picked (its
    name then starts with `prefix`)."""

    def __init__(self, key, title, pattern, script=None, about="", exclude=(), copies=False, prefix=""):
        self.key, self.title, self.pattern, self.script, self.about = key, title, pattern, script, about
        self.exclude, self.copies, self.prefix = exclude, copies, prefix

    def files(self):
        """res:// paths of this kind's files, sorted."""
        out = []
        for path in sorted(glob.glob(os.path.join(ROOT, self.pattern))):
            name = os.path.basename(path)
            if any(name.startswith(prefix) for prefix in self.exclude):
                continue
            out.append("res://" + os.path.relpath(path, ROOT))
        return out

    def folder(self):
        return "res://" + os.path.dirname(self.pattern)

    def can_create(self):
        return (self.script is not None or self.copies) and "*" in os.path.basename(self.pattern)

    def new_path(self, name):
        name = name if name.startswith(self.prefix) else self.prefix + name
        return self.folder() + "/" + name + ".tres"


ARCHETYPES = "database/presets/archetypes/"
KINDS = [
    Kind("factions", "Factions", "database/factions/*.tres", DEFINITIONS + "faction_template.gd",
         "Who flies where, their paints, enemies and roster."),
    Kind("archetype_ships", "Archetype ships", ARCHETYPES + "preset_ship_archetype_*.tres", None,
         "The fifteen designs' hulls and fits (frozen: the presets were evolved on them)."),
    Kind("archetype_pilots", "Archetype pilots", ARCHETYPES + "agent_archetype_*.tres", None,
         "The fifteen designs' behaviour and genome (frozen)."),
    Kind("parts", "Parts", "database/presets/parts/*.tres", None,
         "The part catalogue: three of every kind (light, medium, heavy) and the harpoon; the only parts there are."
         " Tune a part's law genes, then tools/dev.py apply_laws."),
    Kind("ships", "Stock ships", "database/registry/assets/ships/*.tres", DEFINITIONS + "asset_ship_template.gd",
         "Hand-made hulls (law genes: tools/dev.py apply_laws)."),
    Kind("commodities", "Commodities", "database/registry/assets/commodities/*.tres", DEFINITIONS + "asset_commodity_template.gd"),
    Kind("game_starts", "Game starts", "database/registry/game_starts/*.tres", DEFINITIONS + "game_start_template.gd"),
    Kind("locations", "Locations", "database/registry/locations/*.tres", DEFINITIONS + "location_template.gd",
         "The sector graph."),
    Kind("agents", "Agents", "database/registry/agents/*.tres", DEFINITIONS + "agent_template.gd",
         "The player's and NPCs' base templates."),
    Kind("materials", "Material library", "assets/art/materials_generic/mat_*.tres", None,
         "Models take these by name (a model's material mat_x becomes mat_x.tres). New: a copy of the one picked;"
         " then rebuild the starters (Tools: starters).", copies=True, prefix="mat_"),
    Kind("sounds", "Sound bank", "database/sounds/sound_bank.tres", None,
         "One slot per game event; an empty slot is silent."),
]
KINDS_BY_KEY = {kind.key: kind for kind in KINDS}


# Fields (and screens) for what the game does not do yet: they are kept, and the tool can edit
# them, but nothing in the game reads them, so changing one changes nothing in play. The tool
# shows each with this notice; tests/test_not_in_game.py fails when an unread field has no
# notice, or when the game starts reading one that still has it.
NOT_IN_GAME = {
    ("location_template.gd", "is_procedural"): "Procedural sectors are not in the game yet (every sector is a scene).",
    ("location_template.gd", "procedural_type"): "Procedural sectors are not in the game yet.",
    ("location_template.gd", "procedural_hints"): "Procedural sectors are not in the game yet.",
    ("location_template.gd", "sector_description"): "No screen shows a sector's description yet.",
    ("location_template.gd", "radiation_level"): "Sector-wide radiation is not in the game yet (hazards are markers: World, Hazards).",
    ("location_template.gd", "thermal_background_k"): "Sector temperature is not in the game yet.",
    ("location_template.gd", "gravity_well_penalty"): "Gravity wells are not in the game yet.",
    ("location_template.gd", "mineral_density"): "Sector mineral density is not in the game yet (rocks come from beacons' fields).",
    ("location_template.gd", "propellant_sources"): "Propellant sources are not in the game yet.",
    ("location_template.gd", "danger_level"): "Sector danger levels are not in the game yet.",
}
NOT_IN_GAME_TITLE = "Not in the game yet"


def not_in_game(script, field):
    """The notice for `field` of the script at `script` (a path or file name), or ""."""
    return NOT_IN_GAME.get((os.path.basename(script or ""), field), "")


SEARCHED = (".tres", ".tscn", ".gd", ".cfg", ".godot", ".glb")  # .glb: models name their materials
SKIPPED_DIRS = {".git", ".dev", ".import", "addons", "__pycache__", "renders"}


def template_id_of(res):
    """The template_id a data file sets ("" none)."""
    try:
        with open(os.path.join(ROOT, res.replace("res://", ""))) as handle:
            for line in handle:
                if line.startswith("template_id = "):
                    return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return ""


def references(res, by_name=False):
    """res:// paths of the project files that name `res` (by path or by its template_id; with
    `by_name`, as models take materials, by its bare name too), sorted: a file still named
    somewhere is not deleted."""
    own = os.path.join(ROOT, res.replace("res://", ""))
    template_id = template_id_of(res)
    needles = [res] + (['"%s"' % template_id] if template_id else [])
    if by_name:
        needles.append(os.path.basename(res).rsplit(".", 1)[0])
    out = []
    for folder, dirs, names in os.walk(ROOT):
        dirs[:] = [name for name in dirs if name not in SKIPPED_DIRS]
        for name in names:
            path = os.path.join(folder, name)
            if not name.endswith(SEARCHED) or path == own:
                continue
            try:
                with open(path, errors="ignore") as handle:  # A .glb's names are plain text in its JSON chunk
                    text = handle.read()
            except OSError:
                continue
            if any(needle in text for needle in needles):
                out.append("res://" + os.path.relpath(path, ROOT))
    return sorted(out)


def kind_of(res):
    for kind in KINDS:
        if res in kind.files():
            return kind
    return None
