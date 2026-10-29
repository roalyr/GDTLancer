# SectorLayout: builds a sector's layout on load (Constants SECTOR_LAYOUTS[sector_id]): its havens
# (stations NPCs live from; one already in the scene is used as it is), a beacon at each haven, at
# each planet and moon (a landmark above it) and at each beacon the layout lists, the rock fields
# round the field beacons (from their names' seeds, the same on every load), its hazards, and the
# BeaconNetwork that keeps the beacons' numbers. Sits at the sector's middle, unrotated, so layout
# positions are sector positions. AgentSystem keeps each populated haven's NPCs topped up from
# Evolution.

extends Spatial

const StationScene = preload("res://scenes/prefabs/station/faction_station.tscn")
const BeaconScript = preload("res://src/scenes/game_world/sector_layout/beacon.gd")
const BeaconNetworkScript = preload("res://src/scenes/game_world/sector_layout/beacon_network.gd")
const HazardScript = preload("res://src/scenes/game_world/sector_layout/hazard.gd")
const XenoForm = preload("res://src/scenes/game_world/xeno_form.gd")
const CollisionHull = preload("res://src/core/agents/components/collision_hull.gd")
const Havens = preload("res://src/core/systems/havens.gd")

export var sector_id: String = "sector_elace"

var network: Node = null
var havens: Array = []  # [{"id", "faction", "factions": {faction: ships}, "station", "stations": {faction: [station]}, "beacon"}]


func _ready():
	add_to_group("sector_layout")
	var layout: Dictionary = Constants.SECTOR_LAYOUTS.get(sector_id, {})
	network = BeaconNetworkScript.new()
	network.name = "BeaconNetwork"
	network.play_radius = float(layout.get("play_radius", INF))
	add_child(network)
	for spec in layout.get("hazards", []):
		var hazard = HazardScript.new()
		hazard.name = "Hazard_%s" % spec.kind
		hazard.kind = spec.kind
		hazard.core = float(spec.core)
		hazard.radius = float(spec.radius)
		hazard.transform.origin = spec.at
		add_child(hazard)
		network.register_hazard(hazard)
	var keep_clear: Array = []
	for spec in layout.get("havens", []):
		var haven: Dictionary = _build_haven(spec)
		if haven.empty():
			continue
		havens.append(haven)
		keep_clear.append([haven.station.global_transform.origin, Constants.FIELD_ROCK_CLEARANCE])
	call_deferred("_add_landmarks")  # The scene's planets and moons are ready by then
	for spec in layout.get("beacons", []):
		var beacon = _add_beacon(spec.kind, str(spec.get("owner", "")), spec.name, spec.at, float(spec.get("radius", Constants.BEACON_TRAFFIC_RADIUS)))
		if spec.kind == "field":
			_build_rocks(spec, keep_clear)


func _build_haven(spec: Dictionary) -> Dictionary:
	var station: Spatial = null
	if spec.has("station"):
		station = get_parent().get_node_or_null(spec.station) if get_parent() != null else null
		if station == null:
			printerr("SectorLayout: no station %s in the scene" % spec.station)
			return {}
	else:
		station = StationScene.instance()
		station.name = spec.id
		station.faction = str(spec.get("faction", ""))
		station.haven_id = spec.id
		station.location_id = spec.id
		station.station_name = spec.name
		station.transform.origin = spec.at
		if station.faction == "xenohive":
			_dress_as_hive(station)
		add_child(station)
	var faction: String = str(spec.get("faction", ""))
	var beacon = _add_beacon("haven", faction, spec.name, station.global_transform.origin, Constants.HAVEN_BEACON_RADIUS)
	beacon.haven = station
	var stations := {}
	for ship_faction in spec.get("ships", {}):
		stations[ship_faction] = [station]
	return {"id": spec.id, "faction": faction, "factions": spec.get("ships", {}).duplicate(), "station": station, "stations": stations, "beacon": beacon}


func _add_beacon(kind: String, beacon_faction: String, beacon_name: String, at: Vector3, radius: float) -> Node:
	var beacon = BeaconScript.new()
	beacon.name = "Beacon_" + beacon_name.replace(" ", "_")
	beacon.kind = kind
	beacon.faction = beacon_faction
	beacon.beacon_name = beacon_name
	beacon.radius = radius
	beacon.transform.origin = at
	add_child(beacon)
	network.register(beacon)
	return beacon


# A landmark over every planet and moon (not the star, nor anything inside a hazard).
func _add_landmarks() -> void:
	for body in get_tree().get_nodes_in_group("celestial"):
		if not (get_parent() != null and get_parent().is_a_parent_of(body)) or not body.has_method("get_apparent_radius"):
			continue
		var at: Vector3 = body.global_transform.origin
		var inside := false
		for hazard in network.hazards:
			inside = inside or at.distance_to(hazard.global_transform.origin) < hazard.radius
		if inside:
			continue
		var display: String = body.get_display_name() if body.has_method("get_display_name") else str(body.name)
		_add_beacon("landmark", "", display, at + Vector3.UP * (body.get_apparent_radius() + 2000.0), Constants.BEACON_TRAFFIC_RADIUS)


# The xenohive's station is grown, not built: a XenoForm in place of the cargo ship, its convex hull
# for collision.
func _dress_as_hive(station: Node) -> void:
	var old: Node = station.get_node("Model")
	station.remove_child(old)
	old.free()
	var model := Spatial.new()
	model.name = "Model"
	model.add_child(XenoForm.build(Constants.XENO_FORMS.hive, Constants.XENO_HIVE_LENGTH, Constants.XENO_HIVE_SEED))
	station.add_child(model)
	var shape: Shape = CollisionHull.shape_for(model, Transform.IDENTITY)
	if shape != null:
		station.get_node("CollisionShape").shape = shape


# A field's rocks, the same on every load: within its radius (a ring: only past `ring` of it), clear
# of the stations and each other.
func _build_rocks(spec: Dictionary, keep_clear: Array) -> void:
	var count: int = int(spec.get("rocks", 0))
	if count <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(spec.name)
	var centre: Vector3 = spec.at
	var radius: float = float(spec.get("radius", Constants.BEACON_TRAFFIC_RADIUS))
	var inner: float = float(spec.get("ring", 0.0))
	var scene: PackedScene = load(Constants.FIELD_ROCK_SCENE)
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 20:
		tries += 1
		var big: bool = rng.randf() < Constants.FIELD_ROCK_BIG_CHANCE
		var bounds: Array = Constants.FIELD_ROCK_BIG_SCALE if big else Constants.FIELD_ROCK_SCALE
		var scale: float = rng.randf_range(bounds[0], bounds[1])
		var angle: float = rng.randf() * TAU
		var reach: float = sqrt(rng.randf_range(inner * inner, 1.0)) * radius
		var point: Vector3 = centre + Vector3(cos(angle), 0.0, sin(angle)) * reach
		point += Vector3.UP * rng.randf_range(-Constants.FIELD_ROCK_HEIGHT, Constants.FIELD_ROCK_HEIGHT)
		var spacing: float = scale * 1.5
		var clear := true
		for other in keep_clear:
			if point.distance_to(other[0]) < other[1] + spacing:
				clear = false
				break
		if not clear:
			continue
		var rock = scene.instance()
		rock.name = "Rock_%s_%02d" % [spec.name.replace(" ", "_"), placed]
		rock.model = load(Constants.FIELD_ROCK_MODELS[rng.randi() % Constants.FIELD_ROCK_MODELS.size()])
		var basis := Basis(Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5).normalized(), rng.randf() * TAU)
		rock.transform = Transform(basis.scaled(Vector3.ONE * scale), point)
		add_child(rock)
		keep_clear.append([point, spacing])
		placed += 1


func get_haven(haven_id: String) -> Dictionary:
	for haven in havens:
		if haven.id == haven_id:
			return haven
	return {}


# The stations an NPC of `faction` is welcome at (Havens.welcome).
func refuges_for(faction: String) -> Array:
	var found: Array = []
	for haven in havens:
		if Havens.welcome(faction, haven.id):
			found.append(haven.station)
	return found
