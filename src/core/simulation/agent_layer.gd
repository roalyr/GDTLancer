#
# PROJECT: GDTLancer
# MODULE: agent_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §2.1, §3.3 + TACTICAL_TODO.md TASK_10
# LOG_REF: 2026-02-21 (TASK_10)
#

extends Reference

## AgentLayer: Qualitative agent layer using affinity-driven tag transitions.
##
## Agents carry condition/wealth/cargo tags instead of numeric values.
## All decisions are driven by AffinityMatrix.compute_affinity() scores.
##
## Python reference: python_sandbox/core/simulation/agent_layer.py


## Injected by SimulationEngine — the ChronicleLayer for event logging.
var _chronicle: Reference = null

## Injected by SimulationEngine — the AffinityMatrix for affinity scoring.
var affinity_matrix: Reference = null

## Per-tick seeded RNG for determinism.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Name-generation pools for discovered sectors.
var _FRONTIER_PREFIXES: Array = [
	"Void", "Drift", "Nebula", "Rim", "Edge", "Shadow", "Iron",
	"Crimson", "Amber", "Frozen", "Ashen", "Silent", "Storm",
	"Obsidian", "Crystal", "Pale", "Dark",
]
var _FRONTIER_SUFFIXES: Array = [
	"Reach", "Expanse", "Passage", "Crossing", "Haven", "Point",
	"Drift", "Hollow", "Gate", "Threshold", "Frontier", "Shelf",
	"Anchorage", "Waypoint", "Depot",
]


# =============================================================================
# === PUBLIC API ==============================================================
# =============================================================================

func set_chronicle(chronicle: Reference) -> void:
	_chronicle = chronicle


## Initializes all agents + characters from TemplateDatabase into GameState.
func initialize_agents() -> void:
	GameState.agents.clear()
	GameState.characters.clear()
	GameState.agent_tags.clear()

	_initialize_player()

	for agent_id in TemplateDatabase.agents:
		var template: Resource = TemplateDatabase.agents[agent_id]
		if not is_instance_valid(template):
			continue
		if template.get("agent_type") == "player":
			continue
		_initialize_agent_from_template(agent_id, template)

	print("AgentLayer: Initialized %d agents." % GameState.agents.size())


## Processes all Agent-layer logic for one tick.
func process_tick(config: Dictionary) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = hash(str(GameState.world_seed) + ":" + str(GameState.sim_tick_count))

	_apply_upkeep()

	# Iterate over a snapshot of keys to allow mutation
	var agent_ids: Array = GameState.agents.keys()
	for agent_id in agent_ids:
		if agent_id == "player":
			continue
		if not GameState.agents.has(agent_id):
			continue

		var agent: Dictionary = GameState.agents[agent_id]

		if agent.get("is_disabled", false):
			_check_respawn(agent_id, agent)
			continue

		_evaluate_goals(agent)
		_execute_action(agent_id, agent)

	_check_catastrophe()
	_spawn_mortal_agents()
	_cleanup_dead_mortals()


# =============================================================================
# === PRIVATE — INITIALIZATION ================================================
# =============================================================================

func _initialize_player() -> void:
	var character_id: String = "character_default"
	GameState.player_character_uid = character_id

	# Load character data from TemplateDatabase
	if TemplateDatabase.characters.has(character_id):
		var char_res: Resource = TemplateDatabase.characters[character_id]
		var char_data: Dictionary = _resource_to_dict(char_res)
		GameState.characters[character_id] = char_data
	else:
		GameState.characters[character_id] = {}

	var start_sector: String = ""
	if not GameState.world_topology.empty():
		start_sector = GameState.world_topology.keys()[0]

	GameState.agents["player"] = {
		"character_id": character_id,
		"agent_role": "idle",
		"current_sector_id": start_sector,
		"home_location_id": start_sector,
		"goal_archetype": "idle",
		"goal_queue": [{"type": "idle"}],
		"is_disabled": false,
		"disabled_at_tick": -1,
		"is_persistent": true,
		"condition_tag": "HEALTHY",
		"wealth_tag": "COMFORTABLE",
		"cargo_tag": "EMPTY",
		"dynamic_tags": [],
	}


func _initialize_agent_from_template(agent_id: String, template: Resource) -> void:
	var character_id: String = template.get("character_template_id") if template.get("character_template_id") else "character_default"

	# Load character data from TemplateDatabase
	if not GameState.characters.has(character_id):
		if TemplateDatabase.characters.has(character_id):
			var char_res: Resource = TemplateDatabase.characters[character_id]
			GameState.characters[character_id] = _resource_to_dict(char_res)
		else:
			GameState.characters[character_id] = {}

	var home: String = template.get("home_location_id") if template.get("home_location_id") else ""
	var start_sector: String = home if GameState.world_topology.has(home) else ""
	if start_sector == "" and not GameState.world_topology.empty():
		start_sector = GameState.world_topology.keys()[0]

	var initial_tags: Array = []
	if template.get("initial_tags") != null:
		for tag in template.initial_tags:
			initial_tags.append(tag)
	if initial_tags.empty():
		initial_tags = ["HEALTHY", "COMFORTABLE", "EMPTY"]

	var is_persistent: bool = template.get("is_persistent") if template.get("is_persistent") != null else false

	GameState.agents[agent_id] = {
		"character_id": character_id,
		"agent_role": template.get("agent_role") if template.get("agent_role") else "idle",
		"current_sector_id": start_sector,
		"home_location_id": home,
		"goal_archetype": "affinity_scan",
		"goal_queue": [{"type": "affinity_scan"}],
		"is_disabled": false,
		"disabled_at_tick": -1,
		"is_persistent": is_persistent,
		"condition_tag": _pick_tag(initial_tags, ["HEALTHY", "DAMAGED", "DESTROYED"], "HEALTHY"),
		"wealth_tag": _pick_tag(initial_tags, ["WEALTHY", "COMFORTABLE", "BROKE"], "COMFORTABLE"),
		"cargo_tag": _pick_tag(initial_tags, ["LOADED", "EMPTY"], "EMPTY"),
		"dynamic_tags": [],
	}


# =============================================================================
# === PRIVATE — GOAL EVALUATION ===============================================
# =============================================================================

func _evaluate_goals(agent: Dictionary) -> void:
	var tags: Array = agent.get("sentiment_tags", [])
	if "DESPERATE" in tags:
		agent["goal_archetype"] = "flee_to_safety"
		agent["goal_queue"] = [{"type": "flee_to_safety"}]
		return
	agent["goal_archetype"] = "affinity_scan"
	agent["goal_queue"] = [{"type": "affinity_scan"}]


# =============================================================================
# === PRIVATE — ACTION EXECUTION ==============================================
# =============================================================================

func _execute_action(agent_id: String, agent: Dictionary) -> void:
	var goal_queue: Array = agent.get("goal_queue", [{"type": "idle"}])
	var goal: String = goal_queue[0].get("type", "idle") if not goal_queue.empty() else "idle"

	if goal == "flee_to_safety":
		_action_flee_to_safety(agent_id, agent)
		return
	if goal == "affinity_scan":
		_action_affinity_scan(agent_id, agent)


func _action_flee_to_safety(agent_id: String, agent: Dictionary) -> void:
	var current: String = agent.get("current_sector_id", "")
	var options: Array = [current]
	var connections: Array = GameState.world_topology.get(current, {}).get("connections", [])
	for conn in connections:
		options.append(conn)

	var best: String = current
	for sector_id in options:
		var tags: Array = GameState.sector_tags.get(sector_id, [])
		if "SECURE" in tags:
			best = sector_id
			break

	if best != current:
		_action_move_toward(agent_id, agent, best)


func _action_affinity_scan(agent_id: String, agent: Dictionary) -> void:
	if affinity_matrix == null:
		return

	var actor_tags: Array = agent.get("sentiment_tags", [])
	if actor_tags.empty():
		return

	var current_sector: String = agent.get("current_sector_id", "")
	var can_attack: bool = not _is_combat_cooldown_active(agent)

	var best_result: Array = _best_agent_target(agent_id, actor_tags, current_sector, can_attack)
	var best_agent_id = best_result[0]
	var best_agent_score: float = best_result[1]

	if best_agent_id != null:
		var handled: bool = _resolve_agent_interaction(agent_id, best_agent_id, best_agent_score)
		if handled:
			return

	var sector_tags: Array = GameState.sector_tags.get(current_sector, [])
	var sector_score: float = affinity_matrix.compute_affinity(actor_tags, sector_tags)
	_resolve_sector_interaction(agent_id, sector_score, sector_tags)


# =============================================================================
# === PRIVATE — AGENT INTERACTION =============================================
# =============================================================================

func _resolve_agent_interaction(actor_id: String, target_id: String, score: float) -> bool:
	var actor: Dictionary = GameState.agents.get(actor_id, {})
	var target: Dictionary = GameState.agents.get(target_id, {})
	if actor.empty() or target.empty():
		return false

	var current_sector: String = actor.get("current_sector_id", "")

	if score >= Constants.ATTACK_THRESHOLD:
		var new_target_condition: String = "DESTROYED" if target.get("condition_tag") == "DAMAGED" else "DAMAGED"
		target["condition_tag"] = new_target_condition
		actor["last_attack_tick"] = GameState.sim_tick_count

		if new_target_condition == "DESTROYED":
			target["is_disabled"] = true
			target["disabled_at_tick"] = GameState.sim_tick_count
			GameState.sector_tags[current_sector] = _add_tag(GameState.sector_tags.get(current_sector, []), "HAS_SALVAGE")
			actor["cargo_tag"] = "LOADED"

		_log_event(actor_id, "attack", current_sector, {"target": target_id})
		_post_combat_dispersal(actor_id, actor)
		return true

	if score >= Constants.TRADE_THRESHOLD:
		_bilateral_trade(actor, target)
		_log_event(actor_id, "agent_trade", current_sector, {"target": target_id})
		return true

	if score <= Constants.FLEE_THRESHOLD:
		_action_move_random(actor_id, actor)
		_log_event(actor_id, "flee", current_sector, {"target": target_id})
		return true

	return false


# =============================================================================
# === PRIVATE — SECTOR INTERACTION ============================================
# =============================================================================

func _resolve_sector_interaction(agent_id: String, score: float, sector_tags: Array) -> void:
	var agent: Dictionary = GameState.agents.get(agent_id, {})
	var sector_id: String = agent.get("current_sector_id", "")

	# Explorers prioritise exploration
	if "FRONTIER" in sector_tags and agent.get("agent_role") == "explorer":
		_try_exploration(agent_id, agent, sector_id)
		return

	if score >= Constants.ATTACK_THRESHOLD and "HAS_SALVAGE" in sector_tags:
		_action_harvest(agent_id, agent, sector_id)
		return

	var needs_dock: bool = (
		agent.get("condition_tag") == "DAMAGED"
		or agent.get("cargo_tag") == "LOADED"
	)
	var at_station: bool = "STATION" in sector_tags or "FRONTIER" in sector_tags

	if needs_dock and at_station:
		_try_dock(agent_id, agent, sector_id)
		return

	if agent.get("cargo_tag") == "EMPTY":
		var loaded: bool = _try_load_cargo(agent_id, agent, sector_id)
		if loaded:
			return

	if score <= Constants.FLEE_THRESHOLD:
		_action_move_random(agent_id, agent)
		_log_event(agent_id, "flee", sector_id, {"reason": "sector_affinity"})
		return

	_action_move_toward_role_target(agent_id, agent)


# =============================================================================
# === PRIVATE — DOCK / HARVEST / CARGO ========================================
# =============================================================================

func _try_dock(agent_id: String, agent: Dictionary, sector_id: String) -> void:
	var s_tags: Array = GameState.sector_tags.get(sector_id, [])
	if not ("STATION" in s_tags or "FRONTIER" in s_tags):
		return

	var sold_cargo: bool = false
	if agent.get("cargo_tag") == "LOADED":
		agent["cargo_tag"] = "EMPTY"
		_wealth_step_up(agent)
		sold_cargo = true

	if agent.get("condition_tag") == "DAMAGED":
		agent["condition_tag"] = "HEALTHY"
		if not sold_cargo:
			_wealth_step_down(agent)

	_log_event(agent_id, "dock", sector_id, {})


func _action_harvest(agent_id: String, agent: Dictionary, sector_id: String) -> void:
	var tags: Array = GameState.sector_tags.get(sector_id, [])
	if not ("HAS_SALVAGE" in tags):
		return
	agent["cargo_tag"] = "LOADED"
	var new_tags: Array = []
	for tag in tags:
		if tag != "HAS_SALVAGE":
			new_tags.append(tag)
	GameState.sector_tags[sector_id] = new_tags
	_log_event(agent_id, "harvest", sector_id, {})


func _try_load_cargo(agent_id: String, agent: Dictionary, sector_id: String) -> bool:
	if agent.get("cargo_tag") != "EMPTY":
		return false

	var sector_tags: Array = GameState.sector_tags.get(sector_id, [])
	var role: String = agent.get("agent_role", "idle")
	var can_load: bool = false

	if role in ["hauler", "prospector"]:
		can_load = "RAW_RICH" in sector_tags or "MANUFACTURED_RICH" in sector_tags
	elif role == "trader":
		can_load = ("STATION" in sector_tags or "FRONTIER" in sector_tags) and agent.get("wealth_tag") != "BROKE"
	elif role == "pirate":
		can_load = "HAS_SALVAGE" in sector_tags

	if can_load:
		agent["cargo_tag"] = "LOADED"
		if role == "trader":
			_wealth_step_down(agent)
		if role == "pirate" and "HAS_SALVAGE" in sector_tags:
			var new_tags: Array = []
			for t in GameState.sector_tags.get(sector_id, []):
				if t != "HAS_SALVAGE":
					new_tags.append(t)
			GameState.sector_tags[sector_id] = new_tags
		_log_event(agent_id, "load_cargo", sector_id, {})
		return true
	return false


# =============================================================================
# === PRIVATE — MOVEMENT ======================================================
# =============================================================================

func _action_move_toward(agent_id: String, agent: Dictionary, target_sector_id: String) -> void:
	var current: String = agent.get("current_sector_id", "")
	var connections: Array = GameState.world_topology.get(current, {}).get("connections", [])
	if target_sector_id in connections:
		agent["current_sector_id"] = target_sector_id
		_log_event(agent_id, "move", target_sector_id, {"from": current})


func _action_move_random(agent_id: String, agent: Dictionary) -> void:
	var current: String = agent.get("current_sector_id", "")
	var neighbors: Array = GameState.world_topology.get(current, {}).get("connections", [])
	if neighbors.empty():
		return
	var target: String = neighbors[_rng.randi() % neighbors.size()]
	_action_move_toward(agent_id, agent, target)


func _action_move_toward_role_target(agent_id: String, agent: Dictionary) -> void:
	var role: String = agent.get("agent_role", "idle")
	var current: String = agent.get("current_sector_id", "")
	var neighbors: Array = GameState.world_topology.get(current, {}).get("connections", [])
	if neighbors.empty():
		return

	var target_preferences: Dictionary = {
		"trader": ["CURRENCY_POOR", "MANUFACTURED_POOR", "STATION"],
		"hauler": ["RAW_RICH", "MANUFACTURED_RICH"],
		"prospector": ["FRONTIER", "HAS_SALVAGE", "RAW_RICH"],
		"explorer": ["FRONTIER", "HARSH", "EXTREME"],
		"pirate": ["LAWLESS", "HOSTILE_INFESTED", "HAS_SALVAGE"],
		"military": ["CONTESTED", "LAWLESS", "HOSTILE_INFESTED", "HOSTILE_THREATENED"],
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


# =============================================================================
# === PRIVATE — EXPLORATION ===================================================
# =============================================================================

func _try_exploration(agent_id: String, agent: Dictionary, sector_id: String) -> void:
	# Cap check
	if GameState.world_topology.size() >= Constants.MAX_SECTOR_COUNT:
		_log_event(agent_id, "expedition_failed", sector_id, {})
		return

	if agent.get("wealth_tag") == "BROKE":
		_log_event(agent_id, "expedition_failed", sector_id, {"reason": "broke"})
		return

	# Per-agent cooldown
	var last_discovery: int = int(agent.get("last_discovery_tick", -999))
	if GameState.sim_tick_count - last_discovery < Constants.EXPLORATION_COOLDOWN_TICKS:
		_log_event(agent_id, "expedition_failed", sector_id, {"reason": "cooldown"})
		return

	# Probability gate — diminishing returns
	var sector_count: int = GameState.world_topology.size()
	var saturation: float = float(sector_count) / float(Constants.MAX_SECTOR_COUNT)
	var effective_chance: float = Constants.EXPLORATION_SUCCESS_CHANCE * (1.0 - saturation)
	if _rng.randf() > effective_chance:
		_log_event(agent_id, "expedition_failed", sector_id, {"reason": "nothing_found"})
		return

	agent["last_discovery_tick"] = GameState.sim_tick_count
	GameState.discovered_sector_count += 1
	var new_id: String = "discovered_" + str(GameState.discovered_sector_count)
	var new_name: String = _generate_sector_name()

	# Determine connections (filament topology)
	var source_id: String = sector_id
	if _graph_degree(source_id) >= Constants.MAX_CONNECTIONS_PER_SECTOR:
		var fallback_candidates: Array = []
		var source_connections: Array = GameState.world_topology.get(source_id, {}).get("connections", [])
		for neighbor_id in source_connections:
			if _graph_degree(neighbor_id) < Constants.MAX_CONNECTIONS_PER_SECTOR:
				fallback_candidates.append(neighbor_id)

		if fallback_candidates.empty():
			_log_event(agent_id, "expedition_failed", sector_id, {"reason": "region_saturated"})
			return

		# Sort by degree (ascending), then by name for determinism
		fallback_candidates.sort_custom(self, "_sort_by_degree")
		source_id = fallback_candidates[0]

	var connections: Array = [source_id]

	var extra_one_added: bool = false
	if _rng.randf() < Constants.EXTRA_CONNECTION_1_CHANCE:
		var nearby: Array = _nearby_candidates(source_id, connections)
		if not nearby.empty():
			nearby.sort()
			var extra_one: String = nearby[_rng.randi() % nearby.size()]
			if not (extra_one in connections):
				connections.append(extra_one)
				extra_one_added = true

	if extra_one_added and _rng.randf() < Constants.EXTRA_CONNECTION_2_CHANCE:
		var loop_candidate = _distant_loop_candidate(source_id, connections)
		if loop_candidate != null and not (loop_candidate in connections):
			connections.append(loop_candidate)

	# Pick initial tags (frontier bias: harsh, poor, contested)
	var sec_roll: float = _rng.randf()
	var security: String = "LAWLESS" if sec_roll < 0.45 else ("CONTESTED" if sec_roll < 0.85 else "SECURE")
	var env_roll: float = _rng.randf()
	var environment: String = "EXTREME" if env_roll < 0.3 else ("HARSH" if env_roll < 0.75 else "MILD")

	var econ_tags: Array = []
	var econ_options: Array = ["POOR", "POOR", "ADEQUATE", "ADEQUATE", "RICH"]
	for prefix in ["RAW", "MANUFACTURED", "CURRENCY"]:
		var level: String = econ_options[_rng.randi() % econ_options.size()]
		econ_tags.append(prefix + "_" + level)

	var initial_tags: Array = ["FRONTIER", security, environment] + econ_tags

	# Wire into the world graph (bidirectional)
	GameState.world_topology[new_id] = {
		"connections": Array(connections),
		"station_ids": [new_id],
		"sector_type": "frontier",
	}
	for conn_id in connections:
		var conn_data: Dictionary = GameState.world_topology.get(conn_id, {})
		var existing_conns: Array = conn_data.get("connections", [])
		if not (new_id in existing_conns):
			existing_conns.append(new_id)

	# Initialize all required state dicts
	GameState.sector_tags[new_id] = Array(initial_tags)
	GameState.world_hazards[new_id] = {"environment": environment}
	GameState.colony_levels[new_id] = "frontier"
	GameState.colony_upgrade_progress[new_id] = 0
	GameState.colony_downgrade_progress[new_id] = 0
	GameState.security_upgrade_progress[new_id] = 0
	GameState.security_downgrade_progress[new_id] = 0

	var thresh_rng := RandomNumberGenerator.new()
	thresh_rng.seed = hash(str(GameState.world_seed) + ":sec_thresh:" + new_id)
	GameState.security_change_threshold[new_id] = thresh_rng.randi_range(
		Constants.SECURITY_CHANGE_TICKS_MIN,
		Constants.SECURITY_CHANGE_TICKS_MAX
	)
	GameState.grid_dominion[new_id] = {
		"controlling_faction_id": "",
		"security_tag": security,
	}
	GameState.economy_upgrade_progress[new_id] = {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0}
	GameState.economy_downgrade_progress[new_id] = {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0}
	GameState.economy_change_threshold[new_id] = {}
	for category in ["RAW", "MANUFACTURED", "CURRENCY"]:
		var econ_thresh_rng := RandomNumberGenerator.new()
		econ_thresh_rng.seed = hash(str(GameState.world_seed) + ":econ_thresh:" + new_id + ":" + category)
		GameState.economy_change_threshold[new_id][category] = econ_thresh_rng.randi_range(
			Constants.ECONOMY_CHANGE_TICKS_MIN,
			Constants.ECONOMY_CHANGE_TICKS_MAX
		)
	GameState.hostile_infestation_progress[new_id] = 0

	# Record
	GameState.sector_names[new_id] = new_name
	GameState.discovery_log.append({
		"tick": GameState.sim_tick_count,
		"discoverer": agent_id,
		"from": sector_id,
		"new_sector": new_id,
		"name": new_name,
	})
	_log_event(agent_id, "sector_discovered", sector_id, {
		"new_sector": new_id,
		"name": new_name,
		"connections": connections,
	})


func _generate_sector_name() -> String:
	var name_rng := RandomNumberGenerator.new()
	name_rng.seed = hash(str(GameState.world_seed) + ":discovery:" + str(GameState.discovered_sector_count))
	var prefix: String = _FRONTIER_PREFIXES[name_rng.randi() % _FRONTIER_PREFIXES.size()]
	var suffix: String = _FRONTIER_SUFFIXES[name_rng.randi() % _FRONTIER_SUFFIXES.size()]
	return prefix + " " + suffix


func _graph_degree(sector_id: String) -> int:
	return GameState.world_topology.get(sector_id, {}).get("connections", []).size()


func _sort_by_degree(a: String, b: String) -> bool:
	var da: int = _graph_degree(a)
	var db: int = _graph_degree(b)
	if da != db:
		return da < db
	return a < b


func _nearby_candidates(source_id: String, exclude: Array) -> Array:
	var candidates: Array = []
	var neighbors: Array = GameState.world_topology.get(source_id, {}).get("connections", [])
	for sid in neighbors:
		if sid in exclude:
			continue
		if _graph_degree(sid) >= Constants.MAX_CONNECTIONS_PER_SECTOR:
			continue
		candidates.append(sid)
	return candidates


func _distant_loop_candidate(source_id: String, exclude: Array):
	if not GameState.world_topology.has(source_id):
		return null

	# BFS to find sectors at >= LOOP_MIN_HOPS distance
	var queue: Array = [[source_id, 0]]
	var visited: Dictionary = {source_id: true}
	var distant: Array = []

	while not queue.empty():
		var item: Array = queue.pop_front()
		var current_id: String = item[0]
		var depth: int = item[1]

		if depth >= Constants.LOOP_MIN_HOPS and not (current_id in exclude) and _graph_degree(current_id) < Constants.MAX_CONNECTIONS_PER_SECTOR:
			distant.append(current_id)

		var conns: Array = GameState.world_topology.get(current_id, {}).get("connections", [])
		for neighbor_id in conns:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append([neighbor_id, depth + 1])

	if distant.empty():
		return null

	distant.sort()
	var loop_rng := RandomNumberGenerator.new()
	loop_rng.seed = hash(str(GameState.world_seed) + ":loop:" + source_id + ":" + str(GameState.discovered_sector_count) + ":" + str(GameState.sim_tick_count))
	return distant[loop_rng.randi() % distant.size()]


# =============================================================================
# === PRIVATE — TARGET SELECTION ==============================================
# =============================================================================

func _best_agent_target(actor_id: String, actor_tags: Array, sector_id: String, can_attack: bool) -> Array:
	var best_id = null
	var best_score: float = 0.0

	for target_id in GameState.agents:
		if target_id == actor_id:
			continue
		var target: Dictionary = GameState.agents[target_id]
		if target.get("is_disabled", false):
			continue
		if target.get("current_sector_id", "") != sector_id:
			continue

		var target_tags: Array = target.get("sentiment_tags", [])
		var score: float = affinity_matrix.compute_affinity(actor_tags, target_tags)

		if not can_attack and score >= Constants.ATTACK_THRESHOLD:
			continue
		if abs(score) > abs(best_score):
			best_score = score
			best_id = target_id

	return [best_id, best_score]


func _is_combat_cooldown_active(agent: Dictionary) -> bool:
	var last_attack_tick = agent.get("last_attack_tick", null)
	if last_attack_tick == null:
		return false
	return (GameState.sim_tick_count - int(last_attack_tick)) < Constants.COMBAT_COOLDOWN_TICKS


func _bilateral_trade(actor: Dictionary, target: Dictionary) -> void:
	var actor_loaded: bool = actor.get("cargo_tag") == "LOADED"
	var target_loaded: bool = target.get("cargo_tag") == "LOADED"
	if actor_loaded and not target_loaded:
		actor["cargo_tag"] = "EMPTY"
		target["cargo_tag"] = "LOADED"
	elif target_loaded and not actor_loaded:
		target["cargo_tag"] = "EMPTY"
		actor["cargo_tag"] = "LOADED"


# =============================================================================
# === PRIVATE — RESPAWN & LIFECYCLE ===========================================
# =============================================================================

func _check_respawn(agent_id: String, agent: Dictionary) -> void:
	if not agent.get("is_persistent", false):
		return
	var disabled_at_tick = agent.get("disabled_at_tick", -1)
	if disabled_at_tick == null or disabled_at_tick < 0:
		return
	if GameState.sim_tick_count - int(disabled_at_tick) < Constants.RESPAWN_COOLDOWN_TICKS:
		return

	agent["is_disabled"] = false
	agent["current_sector_id"] = agent.get("home_location_id", agent.get("current_sector_id", ""))
	agent["condition_tag"] = "HEALTHY"
	agent["wealth_tag"] = "COMFORTABLE"
	agent["cargo_tag"] = "EMPTY"
	_log_event(agent_id, "respawn", agent.get("current_sector_id", ""), {})


func _check_catastrophe() -> void:
	if _rng.randf() > Constants.CATASTROPHE_CHANCE_PER_TICK:
		return
	var sector_ids: Array = GameState.world_topology.keys()
	if sector_ids.empty():
		return
	var sector_id: String = sector_ids[_rng.randi() % sector_ids.size()]

	GameState.sector_tags[sector_id] = _add_tag(GameState.sector_tags.get(sector_id, []), "DISABLED")
	GameState.sector_tags[sector_id] = _replace_one(GameState.sector_tags[sector_id], ["MILD", "HARSH", "EXTREME"], "EXTREME")
	GameState.sector_disabled_until[sector_id] = GameState.sim_tick_count + Constants.CATASTROPHE_DISABLE_DURATION
	GameState.catastrophe_log.append({"tick": GameState.sim_tick_count, "sector_id": sector_id})
	_log_event("system", "catastrophe", sector_id, {})

	# Kill mortals caught in the catastrophe sector
	var to_kill: Array = []
	for agent_id in GameState.agents:
		var agent: Dictionary = GameState.agents[agent_id]
		if agent.get("is_persistent", false) or agent.get("is_disabled", false):
			continue
		if agent.get("current_sector_id", "") != sector_id:
			continue
		if _rng.randf() < Constants.CATASTROPHE_MORTAL_KILL_CHANCE:
			to_kill.append(agent_id)

	for agent_id in to_kill:
		GameState.mortal_agent_deaths.append({"tick": GameState.sim_tick_count, "agent_id": agent_id})
		_log_event(agent_id, "catastrophe_death", sector_id, {})
		GameState.agents.erase(agent_id)


func _spawn_mortal_agents() -> void:
	if GameState.agents.size() >= Constants.MORTAL_GLOBAL_CAP:
		return

	var eligible: Array = []
	for sector_id in GameState.sector_tags:
		var tags: Array = GameState.sector_tags[sector_id]
		var has_security: bool = false
		for sec_tag in Constants.MORTAL_SPAWN_REQUIRED_SECURITY:
			if sec_tag in tags:
				has_security = true
				break
		var has_blocked: bool = false
		for blocked_tag in Constants.MORTAL_SPAWN_BLOCKED_SECTOR_TAGS:
			if blocked_tag in tags:
				has_blocked = true
				break
		var has_economy: bool = false
		for econ_tag in Constants.MORTAL_SPAWN_MIN_ECONOMY_TAGS:
			if econ_tag in tags:
				has_economy = true
				break
		if has_security and not has_blocked and has_economy:
			eligible.append(sector_id)

	if eligible.empty():
		return

	# Diminishing returns: more agents → lower spawn chance
	var agent_count: int = GameState.agents.size()
	var saturation: float = float(agent_count) / float(Constants.MORTAL_GLOBAL_CAP)
	var effective_chance: float = Constants.MORTAL_SPAWN_CHANCE * (1.0 - saturation)
	if _rng.randf() > effective_chance:
		return

	var spawn_sector: String = eligible[_rng.randi() % eligible.size()]
	GameState.mortal_agent_counter += 1
	var agent_id: String = "mortal_" + str(GameState.mortal_agent_counter)
	var role: String = Constants.MORTAL_ROLES[_rng.randi() % Constants.MORTAL_ROLES.size()]

	GameState.agents[agent_id] = {
		"character_id": "",
		"agent_role": role,
		"current_sector_id": spawn_sector,
		"home_location_id": spawn_sector,
		"goal_archetype": "affinity_scan",
		"goal_queue": [{"type": "affinity_scan"}],
		"is_disabled": false,
		"disabled_at_tick": -1,
		"is_persistent": false,
		"condition_tag": "HEALTHY",
		"wealth_tag": "BROKE",
		"cargo_tag": "EMPTY",
		"dynamic_tags": [],
	}
	_log_event(agent_id, "spawn", spawn_sector, {})


func _cleanup_dead_mortals() -> void:
	var to_remove: Array = []
	var to_survive: Array = []

	for agent_id in GameState.agents:
		var agent: Dictionary = GameState.agents[agent_id]
		if agent.get("is_persistent", false):
			continue
		if agent.get("is_disabled", false):
			if _rng.randf() < Constants.MORTAL_SURVIVAL_CHANCE:
				to_survive.append(agent_id)
			else:
				to_remove.append(agent_id)

	# Survivors: reset at home with minimal resources
	for agent_id in to_survive:
		var agent: Dictionary = GameState.agents[agent_id]
		agent["is_disabled"] = false
		agent["current_sector_id"] = agent.get("home_location_id", agent.get("current_sector_id", ""))
		agent["condition_tag"] = "DAMAGED"
		agent["wealth_tag"] = "BROKE"
		agent["cargo_tag"] = "EMPTY"
		_log_event(agent_id, "survived", agent.get("current_sector_id", ""), {})

	# Permanent deaths
	for agent_id in to_remove:
		GameState.mortal_agent_deaths.append({"tick": GameState.sim_tick_count, "agent_id": agent_id})
		_log_event(agent_id, "perma_death", GameState.agents[agent_id].get("current_sector_id", ""), {})
		GameState.agents.erase(agent_id)


# =============================================================================
# === PRIVATE — UPKEEP ========================================================
# =============================================================================

func _apply_upkeep() -> void:
	for agent_id in GameState.agents:
		var agent: Dictionary = GameState.agents[agent_id]
		if agent_id == "player" or agent.get("is_disabled", false):
			continue

		# Disruption mortal attrition
		if GameState.world_age == "DISRUPTION" and not agent.get("is_persistent", false):
			var s_tags: Array = GameState.sector_tags.get(agent.get("current_sector_id", ""), [])
			if ("HARSH" in s_tags or "EXTREME" in s_tags) and _rng.randf() < Constants.DISRUPTION_MORTAL_ATTRITION_CHANCE:
				agent["is_disabled"] = true
				agent["disabled_at_tick"] = GameState.sim_tick_count
				continue

		# Random degradation
		if _rng.randf() < Constants.AGENT_UPKEEP_CHANCE:
			if agent.get("condition_tag") == "HEALTHY":
				agent["condition_tag"] = "DAMAGED"
		if _rng.randf() < Constants.AGENT_UPKEEP_CHANCE:
			_wealth_step_down(agent)
		if agent.get("wealth_tag") == "WEALTHY" and _rng.randf() < Constants.WEALTHY_DRAIN_CHANCE:
			agent["wealth_tag"] = "COMFORTABLE"

		# Subsistence recovery: broke agents at station can slowly recover
		if agent.get("wealth_tag") == "BROKE":
			var s_tags: Array = GameState.sector_tags.get(agent.get("current_sector_id", ""), [])
			if "STATION" in s_tags or "FRONTIER" in s_tags:
				if _rng.randf() < Constants.BROKE_RECOVERY_CHANCE:
					agent["wealth_tag"] = "COMFORTABLE"


# =============================================================================
# === PRIVATE — TAG HELPERS ===================================================
# =============================================================================

func _wealth_step_up(agent: Dictionary) -> void:
	var w: String = agent.get("wealth_tag", "COMFORTABLE")
	if w == "BROKE":
		agent["wealth_tag"] = "COMFORTABLE"
	elif w == "COMFORTABLE":
		agent["wealth_tag"] = "WEALTHY"


func _wealth_step_down(agent: Dictionary) -> void:
	var w: String = agent.get("wealth_tag", "COMFORTABLE")
	if w == "WEALTHY":
		agent["wealth_tag"] = "COMFORTABLE"
	elif w == "COMFORTABLE":
		agent["wealth_tag"] = "BROKE"


func _pick_tag(values: Array, options: Array, default: String) -> String:
	for value in values:
		if value in options:
			return value
	return default


func _replace_one(tags: Array, options: Array, replacement: String) -> Array:
	var result: Array = []
	for tag in tags:
		if not (tag in options):
			result.append(tag)
	result.append(replacement)
	return result


func _add_tag(tags: Array, tag: String) -> Array:
	if tag in tags:
		return tags
	var result: Array = Array(tags)
	result.append(tag)
	return result


func _active_agent_count_in_sector(sector_id: String) -> int:
	var count: int = 0
	for agent_id in GameState.agents:
		var agent: Dictionary = GameState.agents[agent_id]
		if agent.get("is_disabled", false):
			continue
		if agent.get("current_sector_id", "") == sector_id:
			count += 1
	return count


func _resource_to_dict(res: Resource) -> Dictionary:
	var data: Dictionary = {}
	if res == null:
		return data
	for prop in res.get_property_list():
		var name: String = prop["name"]
		if name == "script" or name == "resource_path" or name == "resource_name" or name.begins_with("_"):
			continue
		data[name] = res.get(name)
	return data


# =============================================================================
# === PRIVATE — EVENT LOGGING =================================================
# =============================================================================

func _log_event(actor_id: String, action: String, sector_id: String, metadata: Dictionary) -> void:
	var event: Dictionary = {
		"tick": GameState.sim_tick_count,
		"actor_id": actor_id,
		"action": action,
		"sector_id": sector_id,
		"metadata": metadata,
	}
	if _chronicle != null:
		_chronicle.log_event(event)
	else:
		GameState.chronicle_events.append(event)
