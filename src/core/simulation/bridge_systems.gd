#
# PROJECT: GDTLancer
# MODULE: bridge_systems.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_8
# LOG_REF: 2026-02-21 (TASK_8)
#

extends Reference

## BridgeSystems: Cross-layer tag refresh only (agent, sector, world).
##
## Derives and refreshes qualitative tags across layers each tick.
## Runs after Grid Layer, before Agent Layer in the tick sequence.
##
## Python reference: python_sandbox/core/simulation/bridge_systems.py


## Injected by SimulationEngine — an AffinityMatrix instance.
var affinity_matrix: Reference = null


# =============================================================================
# === TICK PROCESSING =========================================================
# =============================================================================

## Processes all Bridge Systems steps for one tick.
##
## @param config  Dictionary — tuning constants (unused, kept for API compatibility).
func process_tick(config: Dictionary) -> void:
	_refresh_sector_tags()
	_refresh_agent_tags()
	_refresh_world_tags()


# =============================================================================
# === PRIVATE — SECTOR TAG REFRESH ============================================
# =============================================================================

func _refresh_sector_tags() -> void:
	if affinity_matrix == null:
		return
	for sector_id in GameState.world_topology:
		GameState.sector_tags[sector_id] = affinity_matrix.derive_sector_tags(sector_id, GameState)


# =============================================================================
# === PRIVATE — AGENT TAG REFRESH =============================================
# =============================================================================

func _refresh_agent_tags() -> void:
	if affinity_matrix == null:
		return
	if GameState.agent_tags.empty():
		GameState.agent_tags = {}
	for agent_id in GameState.agents:
		var agent: Dictionary = GameState.agents[agent_id]
		if agent.get("is_disabled", false):
			continue

		var character_id: String = agent.get("character_id", "")
		var char_data: Dictionary = GameState.characters.get(character_id, {})

		var has_cargo: bool = false
		var initial_tags: Array = agent.get("initial_tags", [])
		if "LOADED" in initial_tags or agent.get("cargo_tag", "") == "LOADED":
			has_cargo = true

		var tags: Array = affinity_matrix.derive_agent_tags(char_data, agent, has_cargo)
		GameState.agent_tags[agent_id] = tags
		agent["sentiment_tags"] = tags


# =============================================================================
# === PRIVATE — WORLD TAG REFRESH =============================================
# =============================================================================

func _refresh_world_tags() -> void:
	var age: String = GameState.world_age if GameState.world_age else "PROSPERITY"
	match age:
		"PROSPERITY":
			GameState.world_tags = ["ABUNDANT", "STABLE"]
		"DISRUPTION":
			GameState.world_tags = ["SCARCE", "VOLATILE"]
		"RECOVERY":
			GameState.world_tags = ["RECOVERING"]
		_:
			GameState.world_tags = ["STABLE"]
