# HavenMarker: a station NPCs live from, and the one place it is set: SectorLayout builds the
# station here from `model` (stations are never placed in a sector scene apart from their haven),
# a beacon too; NPCs dock where they are welcome (Havens.welcome):
# their own faction's havens, and neutral ones unless they are raiders or the xenohive.

tool
extends "res://src/scenes/game_world/sector_layout/markers/layout_marker.gd"

export var haven_id: String = ""  # Its location id (docking, prices, saves): unique across sectors
export var display_name: String = ""
export var faction: String = ""  # Its owner's faction id (database/factions/); "" neutral
export(PackedScene) var model: PackedScene = null  # Its station: a StationModel scene (scenes/prefabs/station/)
export var seen_anywhere: bool = false  # It runs a beacon: on every sensor at any range (the home port), not by its size
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
	if seen_anywhere:
		spec["seen_anywhere"] = true
	if model != null:
		spec["model"] = model.resource_path
	if prefer_role != "":
		spec["prefer_role"] = prefer_role
		spec["prefer_share"] = prefer_share
	return spec
