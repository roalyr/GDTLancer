# FactionStation: a haven built by SectorLayout (the sector's layout scene): a faction's, or a neutral
# one. NPCs living from it spawn docked here, and dock at havens that welcome them to sell, repair
# and escape a fight, as far as the haven's services go (Havens). Painted in its faction's colour;
# the player can dock too (unless its standing is hostile): it buys the hold at its own prices
# (Market), but only the home station sells.

extends "res://src/scenes/game_world/station/dockable_station.gd"

export var faction: String = ""
export var haven_id: String = ""  # Its HavenMarker's haven_id in the sector's layout scene (Havens)


func _ready():
	add_to_group("faction_station")
	var material_path: String = TemplateDatabase.factions.get(faction, {}).get("station_material", "")
	if material_path != "":
		paint(load(material_path))
