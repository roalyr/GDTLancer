# PROJECT: GDTLancer
# MODULE: sector_loader.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: sector_loader.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: GDD-REVISION-LEDGER.md REV_005; universe_topology_architecture.md
# LOG_REF: 2026-06-07 16:56:00
#

extends Reference

## SectorLoader: Stateless builder that loads a sector's .tscn preset
## and offsets the nebula starsphere to simulate galactic position.

const GlobalNebulasScene = preload("res://scenes/starspheres/global_nebulas_starsphere/global_nebulas.tscn")
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

	_offset_nebula(zone_root, template)
	return zone_root





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
