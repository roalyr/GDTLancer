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

		var char_data: Dictionary = _lookup_character_data(agent)

		var has_cargo: bool = false
		var initial_tags: Array = agent.get("initial_tags", [])
		if "LOADED" in initial_tags or agent.get("cargo_tag", "") == "LOADED":
			has_cargo = true

		var tag_context: Dictionary = _build_agent_tag_context(agent_id, agent)
		var tags: Array = affinity_matrix.derive_agent_tags(char_data, tag_context, has_cargo)
		GameState.agent_tags[agent_id] = tags
		agent["sentiment_tags"] = tags


func _lookup_character_data(agent: Dictionary) -> Dictionary:
	var character_id_value = agent.get("character_id", "")
	if GameState.characters.has(character_id_value):
		var direct_match = GameState.characters.get(character_id_value, {})
		if direct_match is Dictionary:
			return direct_match

	var character_id: String = str(character_id_value)
	if GameState.characters.has(character_id):
		var string_match = GameState.characters.get(character_id, {})
		if string_match is Dictionary:
			return string_match

	if character_id.is_valid_integer():
		var numeric_character_id: int = int(character_id)
		if GameState.characters.has(numeric_character_id):
			var numeric_match = GameState.characters.get(numeric_character_id, {})
			if numeric_match is Dictionary:
				return numeric_match

	return {}


func _build_agent_tag_context(agent_id: String, agent: Dictionary) -> Dictionary:
	var context: Dictionary = agent.duplicate(true)
	var current_sector_id: String = str(agent.get("current_sector_id", ""))
	var current_sector_tags: Array = Array(GameState.sector_tags.get(current_sector_id, []))
	context["current_sector_tags"] = current_sector_tags.duplicate()
	context["sector_legality_tag"] = affinity_matrix.derive_sector_legality_tag(current_sector_tags)
	context["sector_faction_tag"] = affinity_matrix.derive_sector_faction_tag(current_sector_tags)
	context["has_active_contract_claim"] = _agent_has_active_contract_claim(agent_id)
	return context


func _agent_has_active_contract_claim(agent_id: String) -> bool:
	for occurrence_id in GameState.runtime_contract_occurrences.keys():
		var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
		if occurrence.empty():
			continue
		if str(occurrence.get("claimant_agent_id", "")) != agent_id:
			continue
		if str(occurrence.get("status", "")) == "completed":
			continue
		return true
	return false


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
