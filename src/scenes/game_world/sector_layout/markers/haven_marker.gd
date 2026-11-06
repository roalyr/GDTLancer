# HavenMarker: a station NPCs live from. Built by SectorLayout here (unless `station` names one
# already in the sector scene), a beacon too; NPCs dock where they are welcome (Havens.welcome):
# their own faction's havens, and neutral ones unless they are raiders or the xenohive.

tool
extends "res://src/scenes/game_world/sector_layout/markers/layout_marker.gd"

export var haven_id: String = ""  # Its location id (docking, prices, saves): unique across sectors
export var display_name: String = ""
export var faction: String = ""  # Its owner's faction id (database/factions/); "" neutral
export var station: String = ""  # A station already in the sector scene (by node name), moved here; "" builds one here
export(PackedScene) var model: PackedScene = null  # Its look (a StationModel scene: scenes/prefabs/station/); none: Constants.STATION_DEFAULT_MODEL
export var ships: Dictionary = {}  # Faction id -> ships living from it (each haven's are a group, with ranks and a leader)
export var prefer_role: String = ""  # A family its ships are more often (Evolution), prefer_share of the time
export var prefer_share: float = 0.0
export var repair: bool = false  # Services: repairs hulls
export var rearm: bool = false  # refills lances, rounds and decoys
export var buys: Dictionary = {}  # Commodity id (or "*" for any) -> price factor on its cargo price; it buys nothing else


func _ring_radius() -> float:
	return Defaults.HAVEN_BEACON_RADIUS


func _ring_color() -> Color:
	return Color(0.4, 0.9, 1.0, 0.8)


func to_spec(at: Vector3) -> Dictionary:
	var spec := {
		"id": haven_id, "name": display_name, "faction": faction, "at": at, "ships": ships.duplicate(),
		"services": {"repair": repair, "rearm": rearm, "buys": buys.duplicate()},
	}
	if station != "":
		spec["station"] = station
	if model != null:
		spec["model"] = model.resource_path
	if prefer_role != "":
		spec["prefer_role"] = prefer_role
		spec["prefer_share"] = prefer_share
	return spec
