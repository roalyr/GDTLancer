# PROJECT: GDTLancer
# MODULE: agent_explorer.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: STRATEGICAL-TODO.md §3; GDD-REVISION-LEDGER.md REV_013
# LOG_REF: 2026-06-20 20:31:00

extends Reference

const LocationTemplateScript = preload("res://database/definitions/location_template.gd")

var _agent_layer: Reference

func initialize(agent_layer_ref: Reference) -> void:
	_agent_layer = agent_layer_ref

func _try_exploration(agent_id: String, agent: Dictionary, sector_id: String) -> void:
	_agent_layer._last_exploration_outcome = "stubbed"
	_agent_layer._log_event(agent_id, "exploration_attempt", sector_id, {"outcome": "stubbed"})

func _should_attempt_exploration(agent: Dictionary, sector_id: String, sector_tags: Array) -> bool:
	if agent.get("wealth_tag") == "BROKE":
		return false
	if _is_exploration_cooldown_active(agent):
		return false
	if not _is_exploration_anchor_sector(sector_id, sector_tags):
		return false
	return _has_local_exploration_outlet(sector_id)

func _is_exploration_cooldown_active(agent: Dictionary) -> bool:
	var last_discovery: int = int(agent.get("last_discovery_tick", -999))
	return GameState.sim_tick_count - last_discovery < Constants.EXPLORATION_COOLDOWN_TICKS

func _is_exploration_anchor_sector(sector_id: String, sector_tags: Array) -> bool:
	if "FRONTIER" in sector_tags:
		return true
	if _has_frontier_pressure(sector_tags):
		return true
	if _is_discovered_sector_id(sector_id):
		return true
	var sector_type: String = _agent_layer._get_sector_type(sector_id)
	return sector_type in ["frontier", "deep_space", "hazard_zone"]

func _has_local_exploration_outlet(sector_id: String) -> bool:
	if _agent_layer._graph_degree(sector_id) < Constants.MAX_CONNECTIONS_PER_SECTOR:
		return true
	var neighbors: Array = Array(GameState.world_topology.get(sector_id, {}).get("connections", []))
	for neighbor_id in neighbors:
		if _agent_layer._graph_degree(str(neighbor_id)) < Constants.MAX_CONNECTIONS_PER_SECTOR:
			return true
	return false

func _handle_explorer_non_exploration_turn(agent_id: String, agent: Dictionary, sector_id: String, sector_tags: Array, at_station: bool) -> void:
	if agent.get("wealth_tag") == "BROKE":
		if at_station:
			return
		_action_move_toward_exploration_target(agent_id, agent)
		return

	if _is_exploration_cooldown_active(agent) and _is_exploration_anchor_sector(sector_id, sector_tags) and _has_local_exploration_outlet(sector_id):
		return

	_action_move_toward_exploration_target(agent_id, agent)

func _action_move_toward_exploration_target(agent_id: String, agent: Dictionary) -> void:
	var current: String = agent.get("current_sector_id", "")
	var neighbors: Array = Array(GameState.world_topology.get(current, {}).get("connections", []))
	if neighbors.empty():
		return

	var best_sector: String = ""
	var best_score: float = -1000000.0
	for neighbor_id in neighbors:
		var neighbor_key: String = str(neighbor_id)
		var n_tags: Array = Array(GameState.sector_tags.get(neighbor_key, []))
		var score: float = 0.0
		if _is_exploration_anchor_sector(neighbor_key, n_tags):
			score += 4.0
		if _has_frontier_pressure(n_tags):
			score += 1.5
		if "FRONTIER" in n_tags:
			score += 1.5
		if _is_discovered_sector_id(neighbor_key):
			score += 1.0

		var degree: int = _agent_layer._graph_degree(neighbor_key)
		if degree < Constants.MAX_CONNECTIONS_PER_SECTOR:
			score += 1.25
		if degree <= 2:
			score += 0.75

		if agent.get("wealth_tag") == "BROKE":
			score += 2.5
		if agent.get("condition_tag") == "DAMAGED":
			score += 1.0

		score -= float(_agent_layer._active_agent_count_in_sector(neighbor_key)) * 0.25

		if score > best_score or (is_equal_approx(score, best_score) and (best_sector == "" or neighbor_key < best_sector)):
			best_score = score
			best_sector = neighbor_key

	if best_sector != "":
		_agent_layer._action_move_toward(agent_id, agent, best_sector)
	else:
		_agent_layer._action_move_random(agent_id, agent)

func _get_exploration_success_modifier(sector_id: String, sector_tags: Array) -> float:
	var dev_level: String = GameState.colony_levels.get(sector_id, "frontier")
	var sector_type: String = _agent_layer._get_sector_type(sector_id)
	var modifier: float = 0.75
	match dev_level:
		"hub":
			modifier = 0.4
		"colony":
			modifier = 0.6
		"outpost":
			modifier = 0.82
		"frontier":
			modifier = 1.0
	if sector_type in ["deep_space", "hazard_zone"]:
		modifier *= 0.9
	elif sector_type == "star":
		modifier *= 1.2
	elif sector_type == "planet":
		modifier *= 1.0
	elif sector_type == "moon":
		modifier *= 0.8

	if _has_frontier_pressure(sector_tags):
		modifier = min(1.0, modifier + 0.15)
		
	return modifier

func _has_frontier_pressure(sector_tags: Array) -> bool:
	return (
		"HARSH" in sector_tags
		or "EXTREME" in sector_tags
		or "LAWLESS" in sector_tags
		or "CONTESTED" in sector_tags
	)

func _is_discovered_sector_id(sector_id: String) -> bool:
	if sector_id.begins_with("discovered_"):
		return true
	var sector_template = TemplateDatabase.locations.get(sector_id)
	var hints = _get_template_value(sector_template, "procedural_hints", {})
	return hints is Dictionary and bool(hints.get("low_visibility", false))

func _get_template_value(template, key: String, default_value = null):
	if template == null:
		return default_value
	if template is Dictionary:
		return template.get(key, default_value)
	var value = template.get(key)
	return value if value != null else default_value
