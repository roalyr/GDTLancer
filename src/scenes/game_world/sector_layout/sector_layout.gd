# SectorLayout: builds a sector's layout on load (its layout scene's markers): its havens
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
const Havens = preload("res://src/core/systems/havens.gd")

export var sector_id: String = "sector_elace"

var network: Node = null
var entry: Dictionary = {}  # The entry beacon: {"at" (sector space), "radius"}; empty: the layout has none
var havens: Array = []  # [{"id", "faction", "factions": {faction: ships}, "station", "stations": {faction: [station]}, "beacon"}]


func _ready():
	add_to_group("sector_layout")
	var layout: Dictionary = TemplateDatabase.sector_layouts.get(sector_id, {})
	network = BeaconNetworkScript.new()
	network.name = "BeaconNetwork"
	network.play_radius = float(layout.get("play_radius", INF))
	add_child(network)
	for spec in layout.get("hazards", []):
		spec = _placed(spec)
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
		var haven: Dictionary = _build_haven(_placed(spec))
		if haven.empty():
			continue
		havens.append(haven)
		keep_clear.append([haven.station.global_transform.origin, Constants.FIELD_ROCK_CLEARANCE])
	call_deferred("_add_landmarks")  # The scene's planets and moons are ready by then
	for spec in layout.get("beacons", []):
		spec = _placed(spec)
		if spec.kind == "entry":  # Not a beacon ships fly by: where they arrive
			entry = {"at": spec.at, "radius": float(spec.get("radius", 0.0))}
			continue
		var beacon = _add_beacon(spec.kind, str(spec.get("owner", "")), spec.name, spec.at, float(spec.get("radius", Constants.BEACON_TRAFFIC_RADIUS)))
		beacon.player_visible = spec.kind == "field" or bool(spec.get("player_visible", false))  # Fields always: a ring of rocks has no one name
		if spec.kind == "patrol" and TemplateDatabase.factions.get(beacon.faction, {}).get("patrol_wages", false):
			beacon.player_visible = true  # Where the player earns that faction's patrol wage (Wages)
		if spec.kind == "field":
			_build_rocks(spec, keep_clear)


# `spec` with its place from its body when it is attached to one: the body's position in the layout's
# space, plus the marker's own as an offset.
func _placed(spec: Dictionary) -> Dictionary:
	if str(spec.get("attached_to", "")) == "":
		return spec
	var body = _body(spec.attached_to)
	if body == null:
		printerr("SectorLayout: %s is attached to %s, which the sector scene does not have" % [spec.get("name", spec.get("id", spec.get("kind", ""))), spec.attached_to])
		return spec
	var placed: Dictionary = spec.duplicate()
	placed.at = (to_local(body.global_transform.origin) if is_inside_tree() else body.transform.origin) + spec.at
	return placed


# The sector scene's node at `path` (from the scene's root), or null.
func _body(path: String) -> Spatial:
	var node: Node = self
	while node.get_parent() != null and not node.get_parent() is Viewport:
		node = node.get_parent()
		var found = node.get_node_or_null(path)
		if found is Spatial:
			return found
	return null


# Where ships arrive in the sector loaded now: {"at" (global), "radius"} of its layout's entry
# beacon; else its scene's EntryPoint node (sectors with no layout yet), radius 0; else the origin.
static func entry_of(zone: Node) -> Dictionary:
	var tree = Engine.get_main_loop()
	for layout in (tree.get_nodes_in_group("sector_layout") if tree is SceneTree else []):
		if not layout.entry.empty() and (not is_instance_valid(zone) or zone.is_a_parent_of(layout)):
			return {"at": layout.to_global(layout.entry.at), "radius": layout.entry.radius}
	var node = zone.find_node("EntryPoint", true, false) if is_instance_valid(zone) else null
	if node is Spatial:
		return {"at": node.global_transform.origin, "radius": 0.0}
	return {"at": Vector3.ZERO, "radius": 0.0}


func _build_haven(spec: Dictionary) -> Dictionary:
	var station: Spatial = StationScene.instance()
	station.name = spec.id
	station.faction = str(spec.get("faction", ""))
	station.haven_id = spec.id
	station.location_id = spec.id
	station.station_name = spec.name
	station.has_beacon = bool(spec.get("seen_anywhere", false))
	station.transform.origin = spec.at
	var model_path: String = str(spec.get("model", Constants.STATION_DEFAULT_MODEL))
	var model = load(model_path) if ResourceLoader.exists(model_path) else null
	if model is PackedScene:
		station.get_node("Model").add_child(model.instance())  # The station fits itself to it as it enters (DockableStation)
	else:
		printerr("SectorLayout: no station model %s for %s" % [model_path, spec.id])
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
		network.register_solid(at, body.get_apparent_radius())
		var inside := false
		for hazard in network.hazards:
			inside = inside or at.distance_to(hazard.global_transform.origin) < hazard.radius
		if inside:
			continue
		var display: String = body.get_display_name() if body.has_method("get_display_name") else str(body.name)
		_add_beacon("landmark", "", display, at + Vector3.UP * (body.get_apparent_radius() + 2000.0), Constants.BEACON_TRAFFIC_RADIUS)


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
