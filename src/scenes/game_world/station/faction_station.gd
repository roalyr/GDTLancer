# FactionStation: a haven built by SectorLayout (Constants SECTOR_LAYOUTS): a faction's, or a neutral
# one. NPCs living from it spawn docked here, and dock at havens that welcome them to sell, repair
# and escape a fight, as far as the haven's services go (Havens). Painted in its faction's colour;
# the player can dock too (unless its standing is hostile): it buys the hold at its own prices
# (Market), but only the home station sells.

extends "res://src/scenes/game_world/station/dockable_station.gd"

export var faction: String = ""
export var haven_id: String = ""  # Its entry in Constants SECTOR_LAYOUTS (Havens)
const PAINTED_PARTS = ["panels outer", "panels fuel"]  # Cargo ship model parts that take the faction colour


func _ready():
	add_to_group("faction_station")
	var material_path: String = Constants.FACTION_STATION_MATERIALS.get(faction, "")
	if material_path == "":
		return
	var material = load(material_path)
	var stack: Array = [self]
	while not stack.empty():
		var node = stack.pop_back()
		stack += node.get_children()
		if node is GeometryInstance and node.name in PAINTED_PARTS:
			node.material_override = material
