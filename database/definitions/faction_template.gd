# FactionTemplate: one faction (database/factions/<id>.tres): who it is at war with, how it treats
# the player, what it pays for, how its ships and stations look, and what its havens fly. Read as a
# Dictionary by its id (TemplateDatabase.factions; to_spec gives the keys).
# "player" is the player's faction (no file); NPCs treat the player by standing (Standing: the
# faction's starting_standing, 0 if none) or a grudge (the player shot them).

extends Template
class_name FactionTemplate

export var display_name: String = ""
export var color: Color = Color(1, 1, 1, 1)  # Its brackets and names on the HUD
export var enemies: Array = []  # Faction ids it is at war with (both ways: either side's list counts)
export var starting_standing: float = 0.0  # The player's standing with it in a new game, -1 to 1
export var no_standing: bool = false  # Aliens: no standing or bounties; they react on the spot
export var distress: bool = false  # Its ships call maydays its patrols answer (BeaconNetwork)
export var silent: bool = false  # Sends no radio (Radio)
export var territory: float = 0.0  # m round its haven where any ship is its enemy (0: none; Agent.is_enemy_of)
export var salvage_as: String = ""  # Its wrecks hold this commodity instead, all their salvage (aliens: biotech)
export var escorts: bool = false  # Its workers take escorts, who share their sales (Wages)
export var patrol_wages: bool = false  # Pays armed ships docking at its havens for their time out (Wages)
export(String, FILE, "*.tres") var hull_material: String = ""  # Paint on its ships' painted surfaces (ModelLooks)
export(String, FILE, "*.tres") var station_material: String = ""  # Paint on its stations' painted surfaces
export(String, FILE, "*.tscn") var ship_scene: String = ""  # A hull of its own its ships fly instead of their archetype's (aliens); "" none
export var roster: Array = []  # What its havens fly in a frozen world: archetype names (database/presets/archetypes/agent_archetype_<name>.tres)


# The faction as the code reads it (TemplateDatabase.factions): "territory" and "salvage_as" only
# when it has them, so `has("territory")` tells a territorial faction.
func to_spec() -> Dictionary:
	var spec := {
		"name": display_name, "color": color, "enemies": enemies.duplicate(), "standing": starting_standing,
		"no_standing": no_standing, "distress": distress, "silent": silent, "escorts": escorts,
		"patrol_wages": patrol_wages, "hull_material": hull_material,
		"station_material": station_material, "ship_scene": ship_scene, "roster": roster.duplicate(),
	}
	if territory > 0.0:
		spec["territory"] = territory
	if salvage_as != "":
		spec["salvage_as"] = salvage_as
	return spec
