#
# PROJECT: GDTLancer
# MODULE: sector_loader.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §2, §6.1; TRUTH_SIMULATION-GRAPH.md §6.4; TACTICAL_TODO.md TASK_4
# LOG_REF: 2026-05-26 16:38:00
#

extends Reference

## SectorLoader: Stateless builder that loads a sector's .tscn preset,
## injects JumpPoints based on current topology, and offsets the nebula
## starsphere to simulate galactic position.

const JumpPointScene = preload("res://scenes/prefabs/navigation/JumpPoint.tscn")
const GlobalNebulasScene = preload("res://scenes/starspheres/global_nebulas_starsphere/global_nebulas.tscn")
const DockableStationScene = preload("res://scenes/prefabs/station/DockableStation.tscn")
const StarsphereSlotScript = preload("res://src/scenes/game_world/starsphere_slot.gd")

var _reported_invalid_scene_paths: Dictionary = {}


func load_sector(sector_id: String) -> Spatial:
	var template = TemplateDatabase.locations.get(sector_id)
	if template == null:
		printerr("SectorLoader: No LocationTemplate for sector_id: ", sector_id)
		return null
	if not GameState.world_topology.has(sector_id):
		printerr("SectorLoader: sector_id not in world_topology: ", sector_id)
		return null

	var zone_root: Spatial = _load_zone_root(template, sector_id)

	_inject_generated_station(zone_root, sector_id)
	_inject_jump_points(zone_root, sector_id, template)
	_offset_nebula(zone_root, template)
	return zone_root


func _inject_generated_station(zone_root: Spatial, sector_id: String) -> void:
	if not is_instance_valid(zone_root):
		return
	if zone_root.find_node("Station", true, false) != null:
		return

	var station_ids: Array = Array(GameState.world_topology.get(sector_id, {}).get("station_ids", []))
	if station_ids.empty():
		return

	var station_id: String = str(station_ids[0])
	var station_data: Dictionary = GameState.station_by_id.get(station_id, {})
	var station_name: String = str(station_data.get("display_name", station_id))
	var docking_point: Vector3 = station_data.get("docking_point", Vector3.ZERO)

	var station_instance = DockableStationScene.instance()
	station_instance.name = "Station"
	station_instance.location_id = station_id
	station_instance.station_name = station_name
	station_instance.transform.origin = docking_point
	zone_root.add_child(station_instance)
	station_instance.owner = zone_root


func _load_zone_root(template, sector_id: String) -> Spatial:
	var scene_path = str(template.sector_scene_path)
	if scene_path != "":
		var scene = _load_handcrafted_scene(scene_path)
		if scene != null:
			var zone_root = scene.instance()
			if zone_root is Spatial:
				return zone_root
			if is_instance_valid(zone_root):
				zone_root.free()
		_report_invalid_scene_path(sector_id, scene_path)
	return _build_procedural_fallback(sector_id)


func _load_handcrafted_scene(scene_path: String) -> PackedScene:
	if scene_path == "":
		return null
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return null
	var scene = load(scene_path)
	return scene if scene is PackedScene else null


func _report_invalid_scene_path(sector_id: String, scene_path: String) -> void:
	var report_key = "%s:%s" % [sector_id, scene_path]
	if _reported_invalid_scene_paths.has(report_key):
		return
	_reported_invalid_scene_paths[report_key] = true
	printerr(
		"SectorLoader: Failed to load handcrafted scene for %s at %s. Using procedural fallback." % [
			sector_id,
			scene_path,
		]
	)


func _inject_jump_points(zone_root: Spatial, sector_id: String, template) -> void:
	var topo_data = GameState.world_topology.get(sector_id, {})
	var connections = topo_data.get("connections", [])

	# Place jump points near the station when available, else fall back to ring from center
	var station = zone_root.find_node("Station", true, false)
	var base_position = station.transform.origin if station else Vector3.ZERO
	var offset_radius = Constants.JUMP_POINT_STATION_OFFSET if station else Constants.JUMP_POINT_RING_RADIUS

	for target_id in connections:
		var target_template = TemplateDatabase.locations.get(target_id)
		if target_template == null:
			continue

		var direction = (target_template.global_position - template.global_position).normalized()
		if direction.length_squared() < 0.001:
			direction = Vector3(1, 0, 0)

		var jump_pos = base_position + direction * offset_radius

		var jp = JumpPointScene.instance()
		jp.target_sector_id = target_id
		jp.target_sector_name = target_template.location_name
		jp.transform.origin = jump_pos
		zone_root.add_child(jp)


func _offset_nebula(zone_root: Spatial, template) -> void:
	var slot = zone_root.find_node("StarsphereSlot", true, false)
	if slot == null:
		return
	var nebulas = slot.find_node("Globalnebulas", true, false)
	if nebulas == null:
		return
	var offset = Constants.get_reference_origin_offset(template.global_position)
	nebulas.transform.origin = offset


func _build_procedural_fallback(sector_id: String) -> Spatial:
	var root = Spatial.new()
	root.name = "SectorRoot"

	var agent_container = Spatial.new()
	agent_container.name = "AgentContainer"
	root.add_child(agent_container)
	agent_container.owner = root

	var starsphere_slot = Spatial.new()
	starsphere_slot.name = "StarsphereSlot"
	starsphere_slot.set_script(StarsphereSlotScript)
	root.add_child(starsphere_slot)
	starsphere_slot.owner = root

	var nebulas = GlobalNebulasScene.instance()
	starsphere_slot.add_child(nebulas)
	nebulas.owner = root

	return root
