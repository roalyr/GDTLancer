# Arena: the three evolution arenas of the Elace system (Constants ARENA_ZONES). Sits at the home
# station and builds, for each zone, a beacon at its middle and each faction's two stations on its
# own side, across the line from the home station so both sides are as far from home.
# AgentSystem keeps each zone's NPCs topped up from Evolution.

extends Spatial

const StationScene = preload("res://scenes/prefabs/station/arena_station.tscn")
const BeaconScene = preload("res://scenes/prefabs/station/arena_beacon.tscn")

var zones: Array = []  # [{"id", "per_faction", "beacon", "stations": {faction: [ArenaStation]}}]


func _ready():
	add_to_group("arena")
	for zone in Constants.ARENA_ZONES:
		zones.append(_build_zone(zone))


func _build_zone(zone: Dictionary) -> Dictionary:
	var offset: Vector3 = zone.offset
	var radial: Vector3 = offset.normalized()
	var across: Vector3 = radial.cross(Vector3.UP).normalized()
	var beacon = BeaconScene.instance()
	beacon.name = "Beacon_" + zone.id
	beacon.zone_id = zone.id
	beacon.transform.origin = offset
	add_child(beacon)
	var stations := {}
	var side := 1.0
	for faction in Constants.ARENA_FACTIONS:
		stations[faction] = []
		for index in range(2):
			var station = StationScene.instance()
			var faction_name: String = Constants.FACTIONS.get(faction, {}).get("name", faction)
			var letter: String = ["A", "B"][index]
			station.name = "%s_%s_%s" % [faction_name, zone.id, letter]
			station.faction = faction
			station.zone_id = zone.id
			station.location_id = "arena_%s_%s_%s" % [zone.id, faction, letter.to_lower()]
			station.station_name = "%s Post %s %s" % [faction_name, zone.id, letter]
			var spread: float = Constants.ARENA_STATION_SPREAD * (index - 0.5)
			station.transform.origin = offset + across * side * Constants.ARENA_STATION_DISTANCE + radial * spread
			add_child(station)
			stations[faction].append(station)
		side = -side
	return {"id": zone.id, "per_faction": int(zone.per_faction), "beacon": beacon, "stations": stations}


func get_zone(zone_id: String) -> Dictionary:
	for zone in zones:
		if zone.id == zone_id:
			return zone
	return {}
