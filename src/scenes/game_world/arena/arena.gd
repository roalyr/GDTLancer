# Arena: the evolution arenas of the Elace system (Constants ARENA_ZONES). Sits where the home
# station used to be (it now stands in the 4v4 arena, on the side away from both factions) and builds,
# for each zone, a beacon at its middle and its factions' stations (Constants ARENA_STATION_PLACES):
# Verdant and Violet two each on their own side, across the line from the home station so both sides
# are as far from home; the raiders an outpost out along the zone's line, the xenohive a hive back
# toward the Arena. Each zone has its own terrain (Constants ARENA_ZONES, ARENA_ROCK_FIELDS): open
# space, a rock belt across the middle, rocks scattered over the field or a wide field of them, built
# from the zone's seed.
# AgentSystem keeps each zone's NPCs topped up from Evolution.

extends Spatial

const StationScene = preload("res://scenes/prefabs/station/arena_station.tscn")
const BeaconScene = preload("res://scenes/prefabs/station/arena_beacon.tscn")

var zones: Array = []  # [{"id", "factions": {faction: ships}, "beacon", "stations": {faction: [ArenaStation]}}]


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
		if not zone.factions.has(faction):
			continue
		stations[faction] = []
		var place: String = Constants.ARENA_STATION_PLACES.get(faction, "sides")
		var spots: Array = []
		if place == "sides":
			for index in range(2):
				spots.append(offset + across * side * Constants.ARENA_STATION_DISTANCE + radial * Constants.ARENA_STATION_SPREAD * (index - 0.5))
			side = -side
		else:
			spots.append(offset + radial * (1.0 if place == "outpost" else -1.0) * Constants.ARENA_OUTPOST_DISTANCE)
		for index in range(spots.size()):
			var station = StationScene.instance()
			var faction_name: String = Constants.FACTIONS.get(faction, {}).get("name", faction)
			var letter: String = ["A", "B"][index]
			station.name = "%s_%s_%s" % [faction_name, zone.id, letter]
			station.faction = faction
			station.zone_id = zone.id
			station.location_id = "arena_%s_%s_%s" % [zone.id, faction, letter.to_lower()]
			station.station_name = ("%s Post %s %s" % [faction_name, zone.id, letter]) if place == "sides" else ("%s %s" % [faction_name, "Outpost" if place == "outpost" else "Hive"])
			station.transform.origin = spots[index]
			add_child(station)
			stations[faction].append(station)
	_build_rocks(zone, offset, radial, across, stations)
	return {"id": zone.id, "factions": zone.factions.duplicate(), "beacon": beacon, "stations": stations}


# The zone's rock field (Constants ARENA_ROCK_FIELDS), the same on every load: clear of the beacon,
# the stations and each other.
func _build_rocks(zone: Dictionary, offset: Vector3, radial: Vector3, across: Vector3, stations: Dictionary) -> void:
	var terrain: String = zone.get("terrain", "open")
	var count: int = int(Constants.ARENA_ROCK_FIELDS.get(terrain, 0))
	if count <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(zone.id)
	var keep_clear: Array = [[offset, Constants.ARENA_ROCK_CLEARANCE]]
	for faction in stations:
		for station in stations[faction]:
			keep_clear.append([station.transform.origin, Constants.ARENA_ROCK_CLEARANCE])
	var scene: PackedScene = load(Constants.ARENA_ROCK_SCENE)
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 20:
		tries += 1
		var big: bool = rng.randf() < Constants.ARENA_ROCK_BIG_CHANCE
		var bounds: Array = Constants.ARENA_ROCK_BIG_SCALE if big else Constants.ARENA_ROCK_SCALE
		var scale: float = rng.randf_range(bounds[0], bounds[1])
		var height: float = rng.randf_range(-Constants.ARENA_ROCK_HEIGHT, Constants.ARENA_ROCK_HEIGHT)
		var point: Vector3
		if terrain == "belt":
			point = offset + across * rng.randf_range(-0.5, 0.5) * Constants.ARENA_ROCK_BELT_WIDTH + radial * rng.randf_range(-1.0, 1.0) * Constants.ARENA_ROCK_FIELD_RADIUS
		else:
			var angle: float = rng.randf() * TAU
			var reach: float = sqrt(rng.randf()) * Constants.ARENA_ROCK_FIELD_RADIUS
			point = offset + (radial * cos(angle) + across * sin(angle)) * reach
		point += Vector3.UP * height
		var spacing: float = scale * 1.5
		var clear := true
		for zone_clear in keep_clear:
			if point.distance_to(zone_clear[0]) < zone_clear[1] + spacing:
				clear = false
				break
		if not clear:
			continue
		var rock = scene.instance()
		rock.name = "Rock_%s_%02d" % [zone.id, placed]
		rock.model = load(Constants.ARENA_ROCK_MODELS[rng.randi() % Constants.ARENA_ROCK_MODELS.size()])
		var basis := Basis(Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5).normalized(), rng.randf() * TAU)
		rock.transform = Transform(basis.scaled(Vector3.ONE * scale), point)
		add_child(rock)
		keep_clear.append([point, spacing])
		placed += 1


func get_zone(zone_id: String) -> Dictionary:
	for zone in zones:
		if zone.id == zone_id:
			return zone
	return {}
