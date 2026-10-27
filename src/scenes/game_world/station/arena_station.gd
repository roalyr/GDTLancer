# ArenaStation: a faction's station in an arena (see Arena). Its NPCs spawn docked here, and dock
# here to sell salvage, repair and escape a fight. Painted in its faction's colour; the player can
# dock too (a safe seat to watch from, unless its standing is hostile): it buys the hold at its cargo
# price (Market), but only the home station sells.

extends "res://src/scenes/game_world/station/dockable_station.gd"

export var faction: String = ""
export var zone_id: String = ""
const PAINTED_PARTS = ["panels outer", "panels fuel"]  # Cargo ship model parts that take the faction colour


func _ready():
	add_to_group("arena_station")
	var material_path: String = Constants.ARENA_FACTION_MATERIALS.get(faction, "")
	if material_path == "":
		return
	var material = load(material_path)
	var stack: Array = [self]
	while not stack.empty():
		var node = stack.pop_back()
		stack += node.get_children()
		if node is GeometryInstance and node.name in PAINTED_PARTS:
			node.material_override = material
