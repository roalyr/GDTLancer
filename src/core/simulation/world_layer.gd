#
# PROJECT: GDTLancer
# MODULE: world_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_6
# LOG_REF: 2026-02-21 (TASK_6)
#

extends Reference

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

	for location_id in TemplateDatabase.locations:
		var loc: Resource = TemplateDatabase.locations[location_id]
		if not is_instance_valid(loc):
			continue

		# --- Topology ---
		var connections: Array = []
		if loc.get("connections") != null:
			for conn_id in loc.connections:
				connections.append(conn_id)

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
