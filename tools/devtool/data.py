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
    Kind("archetype_parts", "Archetype parts", ARCHETYPES + "preset_*.tres", None,
         "The parts the archetypes are fitted with (frozen).", exclude=("preset_ship_archetype_",)),
    Kind("ships", "Stock ships", "database/registry/assets/ships/*.tres", DEFINITIONS + "asset_ship_template.gd",
         "Hand-made hulls (law genes: tools/dev.py apply_laws)."),
    Kind("modules", "Modules", "database/registry/assets/modules/*.tres", DEFINITIONS + "asset_module_template.gd"),
    Kind("tools", "Weapons and tools", "database/registry/tools/*.tres", DEFINITIONS + "utility_tool_template.gd"),
    Kind("commodities", "Commodities", "database/registry/assets/commodities/*.tres", DEFINITIONS + "asset_commodity_template.gd"),
    Kind("game_starts", "Game starts", "database/registry/game_starts/*.tres", DEFINITIONS + "game_start_template.gd"),
    Kind("locations", "Locations", "database/registry/locations/*.tres", DEFINITIONS + "location_template.gd",
         "The sector graph."),
    Kind("agents", "Agents", "database/registry/agents/*.tres", DEFINITIONS + "agent_template.gd",
         "The player's and NPCs' base templates."),
    Kind("materials", "Material library", "assets/art/materials_generic/mat_*.tres", None,
         "Models take these by name (a model's material mat_x becomes mat_x.tres). New: a copy of the one picked;"
         " then rebuild the starters (Tasks: starters).", copies=True, prefix="mat_"),
    Kind("sounds", "Sound bank", "database/sounds/sound_bank.tres", None,
         "One slot per game event; an empty slot is silent."),
]
KINDS_BY_KEY = {kind.key: kind for kind in KINDS}


def kind_of(res):
    for kind in KINDS:
        if res in kind.files():
            return kind
    return None
