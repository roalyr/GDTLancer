# PROJECT: GDTLancer
# MODULE: agent_routing.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: GDD-REVISION-LEDGER.md REV_007; GDD-REVISION-LEDGER.md REV_008; TRUTH_SIMULATION-GRAPH.md §2.2.1; TRUTH_PROJECT.md § Agent Parity Principle
# LOG_REF: 2026-06-12 23:12:22

extends Reference

var _agent_layer: Reference

func initialize(agent_layer_ref: Reference) -> void:
	_agent_layer = agent_layer_ref

func _build_sector_route(start_sector_id: String, target_sector_id: String) -> Array:
	if start_sector_id == "" or target_sector_id == "" or start_sector_id == target_sector_id:
		return []
	var frontier: Array = [start_sector_id]
	var visited: Dictionary = {start_sector_id: true}
	var parents: Dictionary = {}

	while not frontier.empty():
		var sector_id: String = str(frontier[0])
		frontier.remove(0)
		var neighbors: Array = Array(GameState.world_topology.get(sector_id, {}).get("connections", []))
		neighbors.sort()
		for neighbor_id in neighbors:
			if visited.has(neighbor_id):
				continue
			visited[neighbor_id] = true
			parents[neighbor_id] = sector_id
			if neighbor_id == target_sector_id:
				return _reconstruct_sector_route(parents, start_sector_id, target_sector_id)
			frontier.append(neighbor_id)

	return []

func _reconstruct_sector_route(parents: Dictionary, start_sector_id: String, target_sector_id: String) -> Array:
	var route: Array = [target_sector_id]
	var cursor: String = target_sector_id
	while parents.has(cursor):
		cursor = str(parents[cursor])
		route.insert(0, cursor)
	if route.empty() or route[0] != start_sector_id:
		return []
	route.remove(0)
	return route

func _sector_hops_between(start_sector_id: String, target_sector_id: String) -> int:
	if start_sector_id == "" or target_sector_id == "":
		return -1
	if start_sector_id == target_sector_id:
		return 0
	var route: Array = _build_sector_route(start_sector_id, target_sector_id)
	return -1 if route.empty() else route.size()

func _graph_degree(sector_id: String) -> int:
	return GameState.world_topology.get(sector_id, {}).get("connections", []).size()

func _sort_by_degree(a: String, b: String) -> bool:
	var da: int = _graph_degree(a)
	var db: int = _graph_degree(b)
	if da != db:
		return da < db
	return a < b

func _action_move_toward(agent_id: String, agent: Dictionary, target_sector_id: String) -> void:
	var current: String = agent.get("current_sector_id", "")
	var connections: Array = GameState.world_topology.get(current, {}).get("connections", [])
	if target_sector_id in connections:
		agent["current_sector_id"] = target_sector_id
		_agent_layer._log_event(agent_id, "move", target_sector_id, {"from": current})

func _action_move_toward_sector(agent_id: String, agent: Dictionary, target_sector_id: String) -> void:
	var current_sector_id: String = str(agent.get("current_sector_id", ""))
	if current_sector_id == "" or current_sector_id == target_sector_id:
		return
	var route: Array = _build_sector_route(current_sector_id, target_sector_id)
	if route.empty():
		return
	_action_move_toward(agent_id, agent, str(route[0]))

func _action_move_random(agent_id: String, agent: Dictionary) -> void:
	var current: String = agent.get("current_sector_id", "")
	var neighbors: Array = GameState.world_topology.get(current, {}).get("connections", [])
	if neighbors.empty():
		return
	var target: String = neighbors[_agent_layer._rng.randi() % neighbors.size()]
	_action_move_toward(agent_id, agent, target)

func _action_move_toward_role_target(agent_id: String, agent: Dictionary) -> void:
	var role: String = agent.get("agent_role", "idle")
	if role == "surveyor":
		_agent_layer._action_move_toward_exploration_target(agent_id, agent)
		return
	var current: String = agent.get("current_sector_id", "")
	var neighbors: Array = GameState.world_topology.get(current, {}).get("connections", [])
	if neighbors.empty():
		return

	var target_preferences: Dictionary = {
		"trader": ["CURRENCY_POOR", "MANUFACTURED_POOR", "STATION"],
		"hauler": ["RAW_RICH", "MANUFACTURED_RICH"],
		"prospector": ["FRONTIER", "HAS_SALVAGE", "RAW_RICH"],
		"surveyor": ["FRONTIER", "HARSH", "EXTREME"],
		"pirate": ["LAWLESS", "HOSTILE_INFESTED", "HAS_SALVAGE"],
		"patrol": ["CONTESTED", "LAWLESS", "HOSTILE_INFESTED", "HOSTILE_THREATENED"],
	}
	var preferred_tags: Array = target_preferences.get(role, [])

	var best_sector: String = ""
	var best_score: int = -1
	for neighbor_id in neighbors:
		var n_tags: Array = GameState.sector_tags.get(neighbor_id, [])
		var s: int = 0
		for tag in preferred_tags:
			if tag in n_tags:
				s += 1
		if s > best_score:
			best_score = s
			best_sector = neighbor_id

	if best_sector != "" and best_score > 0:
		_action_move_toward(agent_id, agent, best_sector)
	else:
		_action_move_random(agent_id, agent)

func _post_combat_dispersal(agent_id: String, agent: Dictionary) -> void:
	var current: String = agent.get("current_sector_id", "")
	var neighbors: Array = GameState.world_topology.get(current, {}).get("connections", [])
	if neighbors.empty():
		return

	# Prefer least-crowded neighbor
	var best_sector: String = neighbors[0]
	var best_count: int = _active_agent_count_in_sector(neighbors[0])
	for i in range(1, neighbors.size()):
		var count: int = _active_agent_count_in_sector(neighbors[i])
		if count < best_count:
			best_count = count
			best_sector = neighbors[i]
	_action_move_toward(agent_id, agent, best_sector)

func _active_agent_count_in_sector(sector_id: String) -> int:
	var count: int = 0
	for agent_id in GameState.agents:
		var agent: Dictionary = GameState.agents[agent_id]
		if agent.get("is_disabled", false):
			continue
		if agent.get("current_sector_id", "") == sector_id:
			count += 1
	return count