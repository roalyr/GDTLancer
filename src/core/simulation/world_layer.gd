#
# PROJECT: GDTLancer
# MODULE: world_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_CONTENT-CREATION-MANUAL.md §3.4, TRUTH_SIMULATION-GRAPH.md §2.1, §3.3
# LOG_REF: 2026-05-10 16:13:36
#

extends Reference

var _reported_invalid_connections: Dictionary = {}

## WorldLayer: Initializes Layer 1 (World) data in GameState from LocationTemplate resources.
##
## The World Layer is STATIC after initialization — it is read-only at runtime.
## It defines the physical foundation: topology (sector graph), hazards (environment
## tag derived from initial sector tags), and initial sector tag arrays.
##
## Called once at game start by the SimulationEngine. After init, the Grid Layer
## operates on sector_tags to drive tag-based CA transitions.
##
## Python reference: python_sandbox/core/simulation/world_layer.py


# =============================================================================
# === PUBLIC API ==============================================================
# =============================================================================

## Initializes all World Layer data in GameState from TemplateDatabase.locations.
##
## @param seed_string  String — world generation seed (stored in GameState.world_seed).
func initialize_world(seed_string: String) -> void:
	GameState.world_seed = seed_string
	GameState.world_topology.clear()
	GameState.world_hazards.clear()
	GameState.sector_tags.clear()
	_reported_invalid_connections.clear()

	var valid_location_ids: Dictionary = {}
	for location_id in TemplateDatabase.locations:
		var location_template: Resource = TemplateDatabase.locations[location_id]
		if is_instance_valid(location_template):
			valid_location_ids[location_id] = true

	for location_id in valid_location_ids:
		var loc: Resource = TemplateDatabase.locations[location_id]
		if not is_instance_valid(loc):
			continue

		# --- Topology ---
		var connections: Array = _filter_valid_connections(
			location_id,
			loc.get("connections"),
			valid_location_ids
		)

		GameState.world_topology[location_id] = {
			"connections": connections,
			"station_ids": [location_id],
			"sector_type": loc.get("sector_type") if loc.get("sector_type") else "frontier",
		}

		# --- Initial sector tags ---
		var initial_tags: Array = []
		if loc.get("initial_sector_tags") != null:
			for tag in loc.initial_sector_tags:
				initial_tags.append(tag)
		GameState.sector_tags[location_id] = initial_tags

		# --- Hazards (derived from sector tags) ---
		GameState.world_hazards[location_id] = {
			"environment": _derive_environment(initial_tags)
		}

	_validate_initial_sector_id()

	print("WorldLayer: Initialized %d sectors." % GameState.world_topology.size())


# =============================================================================
# === PUBLIC UTILITY ==========================================================
# =============================================================================

## Returns the list of connected sector IDs for a given sector.
##
## @param sector_id  String — the sector to query.
## @return           Array of String — connected sector IDs.
func get_neighbors(sector_id: String) -> Array:
	if GameState.world_topology.has(sector_id):
		return GameState.world_topology[sector_id].get("connections", [])
	return []


## Returns the hazard data for a given sector.
##
## @param sector_id  String — the sector to query.
## @return           Dictionary — {environment: String}
func get_hazards(sector_id: String) -> Dictionary:
	if GameState.world_hazards.has(sector_id):
		return GameState.world_hazards[sector_id]
	return {"environment": "MILD"}


# =============================================================================
# === PRIVATE =================================================================
# =============================================================================

## Derives the environment hazard tag from the sector's initial_sector_tags.
func _derive_environment(sector_tags: Array) -> String:
	if "EXTREME" in sector_tags:
		return "EXTREME"
	if "HARSH" in sector_tags:
		return "HARSH"
	return "MILD"


func _filter_valid_connections(source_sector_id: String, raw_connections, valid_location_ids: Dictionary) -> Array:
	var filtered_connections: Array = []
	if raw_connections == null:
		return filtered_connections

	for target_sector_id in raw_connections:
		if valid_location_ids.has(target_sector_id):
			filtered_connections.append(target_sector_id)
		else:
			_report_invalid_connection(source_sector_id, str(target_sector_id))

	return filtered_connections


func _report_invalid_connection(source_sector_id: String, target_sector_id: String) -> void:
	var report_key = "%s->%s" % [source_sector_id, target_sector_id]
	if _reported_invalid_connections.has(report_key):
		return
	_reported_invalid_connections[report_key] = true
	printerr(
		"WorldLayer: Skipping invalid connection from %s to missing sector_id %s" % [
			source_sector_id,
			target_sector_id,
		]
	)


func _validate_initial_sector_id() -> void:
	if Constants.INITIAL_SECTOR_ID == "":
		printerr("WorldLayer: Constants.INITIAL_SECTOR_ID is empty.")
		return
	if not GameState.world_topology.has(Constants.INITIAL_SECTOR_ID):
		printerr(
			"WorldLayer: INITIAL_SECTOR_ID not found in world_topology: %s" % Constants.INITIAL_SECTOR_ID
		)
