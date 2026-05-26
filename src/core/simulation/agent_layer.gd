#
# PROJECT: GDTLancer
# MODULE: agent_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §0, §2.3; TACTICAL_TODO.md TASK_7
# LOG_REF: 2026-05-26 18:08:00
#

extends Reference

const LocationTemplateScript = preload("res://database/definitions/location_template.gd")
const LegacySystemNameGeneratorScript = preload("res://src/core/utils/legacy_system_name_generator.gd")

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
var _legacy_system_name_generator: Reference = LegacySystemNameGeneratorScript.new()

## Per-tick seeded RNG for determinism.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _reported_invalid_sectors: Dictionary = {}
var _last_exploration_outcome: String = ""
var _CONTRACT_CATEGORIES: Array = ["RAW", "MANUFACTURED", "CURRENCY"]
var _LOW_VISIBILITY_DISCOVERY_PROFILES: Array = [
	{
		"procedural_type": "asteroid_field",
		"location_type": "asteroid_field",
		"sector_type": "deep_space",
		"description": "A sparse asteroid field with faint returns and narrow survey lanes.",
	},
	{
		"procedural_type": "comet_shoal",
		"location_type": "debris_field",
		"sector_type": "deep_space",
		"description": "A loose comet shoal whose volatile traces only surface under deliberate scans.",
	},
	{
		"procedural_type": "rogue_planet",
		"location_type": "debris_field",
		"sector_type": "deep_space",
		"description": "A cold rogue planet drifting in deep dark with almost no ambient signature.",
	},
	{
		"procedural_type": "dark_nebula",
		"location_type": "debris_field",
		"sector_type": "hazard_zone",
		"description": "A dark nebula pocket that hides weak contacts behind dense interference.",
	},
	{
		"procedural_type": "remnant_field",
		"location_type": "debris_field",
		"sector_type": "deep_space",
		"description": "A dim remnant field of cold wreckage and ancient stellar ash.",
	},
]


# =============================================================================
# === PUBLIC API ==============================================================
# =============================================================================

func set_chronicle(chronicle: Reference) -> void:
	_chronicle = chronicle


## Initializes all agents + characters from TemplateDatabase into GameState.
## NOTE: Does NOT clear GameState.characters — WorldGenerator populates it with
## int-keyed CharacterTemplate Resources used by the physical game (ships, inventory).
## Simulation stores String-keyed character dicts alongside them without conflict.
func initialize_agents() -> void:
	GameState.agents.clear()
	GameState.agent_tags.clear()
	_reported_invalid_sectors.clear()

	_initialize_player()

	for agent_id in TemplateDatabase.agents:
		var template: Resource = TemplateDatabase.agents[agent_id]
		if not is_instance_valid(template):
			continue
		if template.get("agent_type") == "player":
			continue
		_initialize_agent_from_template(agent_id, template)

	if Constants.VERBOSE_RUNTIME_LOGS:
		print("AgentLayer: Initialized %d agents." % GameState.agents.size())


## Processes all Agent-layer logic for one tick.
func process_tick(config: Dictionary) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = hash(str(GameState.world_seed) + ":" + str(GameState.sim_tick_count))

	_apply_upkeep()

	# Iterate over a snapshot of keys to allow mutation
	var agent_ids: Array = GameState.agents.keys()
	for agent_id in agent_ids:
		if not GameState.agents.has(agent_id):
			continue

		var agent: Dictionary = GameState.agents[agent_id]

		if agent.get("is_disabled", false):
			_check_respawn(agent_id, agent)
			continue

		_evaluate_goals(agent, agent_id)
		_execute_action(agent_id, agent)

	_check_catastrophe()
	_spawn_mortal_agents()
	_cleanup_dead_mortals()


# =============================================================================
# === PRIVATE — INITIALIZATION ================================================
# =============================================================================

func _initialize_player() -> void:
	var character_id: String = "character_default"
	# NOTE: Do NOT overwrite GameState.player_character_uid here.
	# WorldGenerator already set it to the int UID used by the physical game
	# (ship lookups, inventory, etc.). The simulation identifies the player
	# via GameState.agents["player"]["character_id"] = "character_default".

	# Store simulation-level character data under String key (coexists with
	# WorldGenerator's int-keyed CharacterTemplate Resources).
	if TemplateDatabase.characters.has(character_id):
		var char_res: Resource = TemplateDatabase.characters[character_id]
		var char_data: Dictionary = _resource_to_dict(char_res)
		GameState.characters[character_id] = char_data
	else:
		GameState.characters[character_id] = {}

	var start_sector: String = _resolve_known_sector_id(Constants.INITIAL_SECTOR_ID, "player.start_sector")

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
	GameState.player_claimed_occurrence_id = ""
	GameState.player_cargo_tag = "EMPTY"


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
	var start_sector: String = _resolve_known_sector_id(home, "%s.home_location_id" % agent_id)

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
		"home_location_id": start_sector,
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

func _evaluate_goals(agent: Dictionary, agent_id: String = "") -> void:
	# Keep player inert unless the UI explicitly selected a contract while docked.
	if agent_id == "player" and not _player_can_service_contract(agent):
		agent["goal_archetype"] = "idle"
		agent["goal_queue"] = [{"type": "idle"}]
		return

	var tags: Array = agent.get("sentiment_tags", [])
	if "DESPERATE" in tags:
		agent["goal_archetype"] = "flee_to_safety"
		agent["goal_queue"] = [{"type": "flee_to_safety"}]
		return
	var runtime_contract_id: String = _best_runtime_contract_occurrence_id(agent_id, agent, tags)
	if runtime_contract_id != "":
		agent["goal_archetype"] = "service_contract"
		agent["goal_queue"] = [{"type": "service_contract", "occurrence_id": runtime_contract_id}]
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
	if goal == "service_contract":
		_action_service_contract(agent_id, agent, str(goal_queue[0].get("occurrence_id", "")))
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
	var explorer_waiting: bool = false
	var at_station: bool = "STATION" in sector_tags or "FRONTIER" in sector_tags

	# Explorers prioritise exploration
	if agent.get("agent_role") == "explorer":
		if _should_attempt_exploration(agent, sector_id, sector_tags):
			_try_exploration(agent_id, agent, sector_id)
			if _last_exploration_outcome == "discovered":
				return
		else:
			explorer_waiting = true

	if score >= Constants.ATTACK_THRESHOLD and "HAS_SALVAGE" in sector_tags:
		_action_harvest(agent_id, agent, sector_id)
		return

	var needs_dock: bool = (
		agent.get("condition_tag") == "DAMAGED"
		or agent.get("cargo_tag") == "LOADED"
	)

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

	if explorer_waiting:
		_handle_explorer_non_exploration_turn(agent_id, agent, sector_id, sector_tags, at_station)
		return

	_action_move_toward_role_target(agent_id, agent)


func _get_sector_type(sector_id: String) -> String:
	var topology: Dictionary = GameState.world_topology.get(sector_id, {})
	var topology_sector_type = topology.get("sector_type", null)
	if topology_sector_type != null and str(topology_sector_type) != "":
		return str(topology_sector_type)

	var sector_template = TemplateDatabase.locations.get(sector_id)
	var template_sector_type = _get_template_value(sector_template, "sector_type", "")
	return "" if template_sector_type == null else str(template_sector_type)


func _get_exploration_success_modifier(sector_id: String, sector_tags: Array) -> float:
	var sector_type: String = _get_sector_type(sector_id)
	var modifier: float = 0.75
	match sector_type:
		"hub":
			modifier = 0.4
		"colony":
			modifier = 0.6
		"outpost":
			modifier = 0.82
		"frontier":
			modifier = 1.0
		"deep_space", "hazard_zone":
			modifier = 0.9
		_:
			modifier = 0.75

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


func _is_exploration_cooldown_active(agent: Dictionary) -> bool:
	var last_discovery: int = int(agent.get("last_discovery_tick", -999))
	return GameState.sim_tick_count - last_discovery < Constants.EXPLORATION_COOLDOWN_TICKS


func _should_attempt_exploration(agent: Dictionary, sector_id: String, sector_tags: Array) -> bool:
	if agent.get("wealth_tag") == "BROKE":
		return false
	if _is_exploration_cooldown_active(agent):
		return false
	if not _is_exploration_anchor_sector(sector_id, sector_tags):
		return false
	return _has_local_exploration_outlet(sector_id)


func _handle_explorer_non_exploration_turn(agent_id: String, agent: Dictionary, sector_id: String, sector_tags: Array, at_station: bool) -> void:
	if agent.get("wealth_tag") == "BROKE":
		if at_station:
			return
		_action_move_toward_exploration_target(agent_id, agent)
		return

	if _is_exploration_cooldown_active(agent) and _is_exploration_anchor_sector(sector_id, sector_tags) and _has_local_exploration_outlet(sector_id):
		return

	_action_move_toward_exploration_target(agent_id, agent)


func _is_exploration_anchor_sector(sector_id: String, sector_tags: Array) -> bool:
	if "FRONTIER" in sector_tags:
		return true
	if _has_frontier_pressure(sector_tags):
		return true
	if _is_discovered_sector_id(sector_id):
		return true
	var sector_type: String = _get_sector_type(sector_id)
	return sector_type in ["frontier", "deep_space", "hazard_zone"]


func _has_local_exploration_outlet(sector_id: String) -> bool:
	if _graph_degree(sector_id) < Constants.MAX_CONNECTIONS_PER_SECTOR:
		return true
	var neighbors: Array = Array(GameState.world_topology.get(sector_id, {}).get("connections", []))
	for neighbor_id in neighbors:
		if _graph_degree(str(neighbor_id)) < Constants.MAX_CONNECTIONS_PER_SECTOR:
			return true
	return false


# =============================================================================
# === PRIVATE — RUNTIME CONTRACTS =============================================
# =============================================================================

func _best_runtime_contract_occurrence_id(agent_id: String, agent: Dictionary, actor_tags: Array) -> String:
	if agent_id == "player":
		if not _player_can_service_contract(agent):
			return ""
		var player_occurrence_id: String = str(GameState.player_claimed_occurrence_id)
		if player_occurrence_id == "":
			return ""
		if not GameState.runtime_contract_occurrences.has(player_occurrence_id):
			return ""
		return player_occurrence_id

	var role: String = str(agent.get("agent_role", "idle"))
	if not (role in ["trader", "hauler"]):
		return ""
	if actor_tags.empty() or affinity_matrix == null:
		return ""

	var current_sector_id: String = str(agent.get("current_sector_id", ""))
	var cargo_loaded: bool = agent.get("cargo_tag", "EMPTY") == "LOADED"
	var occurrence_ids: Array = GameState.runtime_contract_occurrences.keys()
	occurrence_ids.sort()
	var best_occurrence_id: String = ""
	var best_score: float = -1000000.0

	for occurrence_id in occurrence_ids:
		var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
		if occurrence.empty():
			continue
		var required_roles: Array = Array(occurrence.get("required_roles", []))
		if not (role in required_roles):
			continue
		var claimant_agent_id: String = str(occurrence.get("claimant_agent_id", ""))
		if claimant_agent_id != "" and claimant_agent_id != agent_id:
			continue
		if cargo_loaded and claimant_agent_id != agent_id:
			continue

		var source_sector_id: String = str(occurrence.get("source_sector_id", ""))
		var target_sector_id: String = str(occurrence.get("target_sector_id", ""))
		var route_goal_sector_id: String = target_sector_id if cargo_loaded else source_sector_id
		var hops_to_goal: int = _sector_hops_between(current_sector_id, route_goal_sector_id)
		if hops_to_goal < 0:
			continue

		var score: float = affinity_matrix.compute_affinity(actor_tags, Array(occurrence.get("priority_tags", [])))
		if claimant_agent_id == agent_id:
			score += 6.0
		if current_sector_id == route_goal_sector_id:
			score += 1.5
		score -= float(hops_to_goal)

		if score > best_score or (is_equal_approx(score, best_score) and (best_occurrence_id == "" or occurrence_id < best_occurrence_id)):
			best_score = score
			best_occurrence_id = occurrence_id

	return best_occurrence_id


func _action_service_contract(agent_id: String, agent: Dictionary, occurrence_id: String) -> void:
	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	if occurrence.empty():
		if agent_id == "player":
			return
		_action_move_toward_role_target(agent_id, agent)
		return
	if not _claim_runtime_contract_occurrence(agent_id, agent, occurrence_id):
		if agent_id == "player":
			return
		_action_move_toward_role_target(agent_id, agent)
		return

	occurrence = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	var source_sector_id: String = str(occurrence.get("source_sector_id", ""))
	var target_sector_id: String = str(occurrence.get("target_sector_id", ""))
	var current_sector_id: String = str(agent.get("current_sector_id", ""))

	if source_sector_id == "" or target_sector_id == "" or current_sector_id == "":
		_release_runtime_contract_claim(agent_id, occurrence_id)
		if agent_id == "player":
			return
		_action_move_toward_role_target(agent_id, agent)
		return

	if agent.get("cargo_tag", "EMPTY") == "EMPTY":
		if current_sector_id != source_sector_id:
			if agent_id == "player":
				return
			_action_move_toward_sector(agent_id, agent, source_sector_id)
			return
		if _load_runtime_contract_cargo(agent_id, agent, occurrence_id, source_sector_id):
			return
	else:
		if current_sector_id != target_sector_id:
			if agent_id == "player":
				return
			_action_move_toward_sector(agent_id, agent, target_sector_id)
			return
		if agent_id == "player":
			if _complete_player_contract_delivery(agent, occurrence_id, target_sector_id):
				return
		elif _complete_runtime_contract_occurrence(agent_id, agent, occurrence_id, target_sector_id):
			return

	if agent_id == "player":
		return
	_action_move_toward_role_target(agent_id, agent)


func _claim_runtime_contract_occurrence(agent_id: String, agent: Dictionary, occurrence_id: String) -> bool:
	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	if occurrence.empty():
		return false
	if agent_id == "player":
		if not _player_can_service_contract(agent):
			return false
		if str(GameState.player_claimed_occurrence_id) != occurrence_id:
			return false
	else:
		var required_roles: Array = Array(occurrence.get("required_roles", []))
		if not (str(agent.get("agent_role", "idle")) in required_roles):
			return false
	var claimant_agent_id: String = str(occurrence.get("claimant_agent_id", ""))
	if claimant_agent_id != "" and claimant_agent_id != agent_id:
		return false

	if claimant_agent_id == "":
		occurrence["claimant_agent_id"] = agent_id
		occurrence["status"] = "claimed"
		occurrence["claimed_at_tick"] = GameState.sim_tick_count
		_log_event(agent_id, "contract_claimed", str(agent.get("current_sector_id", "")), {
			"occurrence_id": occurrence_id,
			"target_sector_id": str(occurrence.get("target_sector_id", "")),
		})
	else:
		occurrence["status"] = str(occurrence.get("status", "claimed"))

	occurrence["last_refreshed_tick"] = GameState.sim_tick_count
	GameState.runtime_contract_occurrences[occurrence_id] = occurrence
	return true


func _release_runtime_contract_claim(agent_id: String, occurrence_id: String) -> void:
	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	if occurrence.empty():
		return
	if str(occurrence.get("claimant_agent_id", "")) != agent_id:
		return
	occurrence["claimant_agent_id"] = ""
	occurrence["status"] = "open"
	if occurrence.has("claimed_at_tick"):
		occurrence.erase("claimed_at_tick")
	GameState.runtime_contract_occurrences[occurrence_id] = occurrence
	if agent_id == "player":
		GameState.player_claimed_occurrence_id = ""
		GameState.player_cargo_tag = "EMPTY"


func _load_runtime_contract_cargo(agent_id: String, agent: Dictionary, occurrence_id: String, sector_id: String) -> bool:
	if agent.get("cargo_tag", "EMPTY") != "EMPTY":
		return false
	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	if occurrence.empty():
		return false
	if sector_id != str(occurrence.get("source_sector_id", "")):
		return false
	var sector_tags: Array = GameState.sector_tags.get(sector_id, [])
	if not ("STATION" in sector_tags or "FRONTIER" in sector_tags):
		return false

	agent["cargo_tag"] = "LOADED"
	if agent_id == "player":
		GameState.player_cargo_tag = "LOADED"
		agent["contract_cargo_tag"] = str(occurrence.get("required_cargo_tag", ""))
	if str(agent.get("agent_role", "idle")) == "trader":
		_wealth_step_down(agent)
	occurrence["status"] = "in_transit"
	occurrence["last_refreshed_tick"] = GameState.sim_tick_count
	GameState.runtime_contract_occurrences[occurrence_id] = occurrence
	_log_event(agent_id, "contract_loaded", sector_id, {
		"occurrence_id": occurrence_id,
		"target_sector_id": str(occurrence.get("target_sector_id", "")),
	})
	return true


func _complete_runtime_contract_occurrence(agent_id: String, agent: Dictionary, occurrence_id: String, sector_id: String) -> bool:
	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	if occurrence.empty():
		return false
	if agent.get("cargo_tag", "EMPTY") != "LOADED":
		return false
	if sector_id != str(occurrence.get("target_sector_id", "")):
		return false
	var sector_tags: Array = GameState.sector_tags.get(sector_id, [])
	if not ("STATION" in sector_tags or "FRONTIER" in sector_tags):
		return false

	_try_dock(agent_id, agent, sector_id)
	_apply_contract_completion_sector_impact(occurrence, sector_id)
	_log_event(agent_id, "contract_completed", sector_id, {
		"occurrence_id": occurrence_id,
		"source_sector_id": str(occurrence.get("source_sector_id", "")),
	})
	_remove_runtime_contract_occurrence(occurrence_id)
	return true


func _complete_player_contract_delivery(agent: Dictionary, occurrence_id: String, sector_id: String) -> bool:
	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	if occurrence.empty():
		return false
	if str(GameState.player_claimed_occurrence_id) != occurrence_id:
		return false
	if str(occurrence.get("claimant_agent_id", "")) != "player":
		return false
	if str(occurrence.get("target_sector_id", "")) != sector_id:
		return false
	if str(agent.get("cargo_tag", "EMPTY")) != "LOADED":
		return false
	if str(GameState.player_cargo_tag) != "LOADED":
		return false

	var sector_tags: Array = Array(GameState.sector_tags.get(sector_id, []))
	if not ("STATION" in sector_tags or "FRONTIER" in sector_tags):
		return false

	var required_cargo_tag: String = str(occurrence.get("required_cargo_tag", ""))
	if required_cargo_tag != "":
		var loaded_cargo_tag: String = str(agent.get("contract_cargo_tag", required_cargo_tag))
		if loaded_cargo_tag != required_cargo_tag:
			return false

	agent["cargo_tag"] = "EMPTY"
	if agent.has("contract_cargo_tag"):
		agent.erase("contract_cargo_tag")
	GameState.player_cargo_tag = "EMPTY"

	var reward_credits: int = int(occurrence.get("reward_credits", 0))
	if reward_credits > 0 and GlobalRefs.character_system != null and GlobalRefs.character_system.has_method("add_credits"):
		var player_character_uid = GameState.player_character_uid
		if player_character_uid != "":
			GlobalRefs.character_system.add_credits(player_character_uid, reward_credits)

	_apply_contract_completion_sector_impact(occurrence, sector_id)

	occurrence["status"] = "completed"
	occurrence["claimant_agent_id"] = ""
	if occurrence.has("claimed_at_tick"):
		occurrence.erase("claimed_at_tick")
	occurrence["completed_at_tick"] = GameState.sim_tick_count
	occurrence["last_refreshed_tick"] = GameState.sim_tick_count
	GameState.runtime_contract_occurrences[occurrence_id] = occurrence

	GameState.player_claimed_occurrence_id = ""
	_log_event("player", "contract_completed", sector_id, {
		"occurrence_id": occurrence_id,
		"source_sector_id": str(occurrence.get("source_sector_id", "")),
		"reward_credits": reward_credits,
	})
	return true


func _apply_contract_completion_sector_impact(occurrence: Dictionary, target_sector_id: String) -> void:
	if target_sector_id == "":
		return
	if not GameState.contract_generation_pressure.has(target_sector_id):
		return

	var category: String = str(occurrence.get("commodity_category", ""))
	if not (category in _CONTRACT_CATEGORIES):
		return

	var sector_pressure: Dictionary = GameState.contract_generation_pressure.get(target_sector_id, {})
	var previous_pressure: int = int(sector_pressure.get(category, 0))
	var completion_relief_decay: int = max(1, int(Constants.CONTRACT_RELIEF_DECAY_PER_TICK) + 1)
	sector_pressure[category] = max(0, previous_pressure - completion_relief_decay)
	GameState.contract_generation_pressure[target_sector_id] = sector_pressure

	_refresh_contract_demand_tags_for_sector(target_sector_id)


func _refresh_contract_demand_tags_for_sector(sector_id: String) -> void:
	if sector_id == "":
		return
	if not GameState.sector_tags.has(sector_id):
		return

	var tags: Array = Array(GameState.sector_tags.get(sector_id, []))
	var serviceable: bool = "STATION" in tags or "FRONTIER" in tags
	var sector_disabled: bool = _sector_recently_disabled(sector_id)
	var sector_pressure: Dictionary = GameState.contract_generation_pressure.get(sector_id, {})
	var sector_thresholds: Dictionary = GameState.contract_generation_threshold.get(sector_id, {})
	var demand_count: int = 0

	for category in _CONTRACT_CATEGORIES:
		var demand_tag: String = _contract_demand_tag(category)
		var poor_tag: String = "%s_POOR" % category
		var threshold: int = int(sector_thresholds.get(category, Constants.CONTRACT_PRESSURE_TICKS_MIN))
		var pressure: int = int(sector_pressure.get(category, 0))
		var can_generate: bool = serviceable and (poor_tag in tags) and not sector_disabled

		if can_generate and pressure >= threshold:
			tags = _add_tag(tags, demand_tag)
		else:
			tags = _remove_tag(tags, demand_tag)

		if demand_tag in tags:
			demand_count += 1

	tags = _remove_tag(tags, "TRADE_LANE_ACTIVE")

	var needs_relief: bool = demand_count >= 2
	if demand_count > 0 and (_security_tag(tags) != "SECURE" or GameState.world_age == "DISRUPTION"):
		needs_relief = true

	if needs_relief:
		tags = _add_tag(tags, "RELIEF_NEEDED")
	else:
		tags = _remove_tag(tags, "RELIEF_NEEDED")

	GameState.sector_tags[sector_id] = tags


func _contract_demand_tag(category: String) -> String:
	return "CONTRACT_DEMAND_%s" % category


func _player_can_service_contract(agent: Dictionary) -> bool:
	if str(GameState.player_docked_at) == "":
		return false
	if str(GameState.player_claimed_occurrence_id) == "":
		return false
	if str(agent.get("agent_role", "idle")) != "idle":
		return false
	return true


func _remove_runtime_contract_occurrence(occurrence_id: String) -> void:
	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	if occurrence.empty():
		return
	var target_sector_id: String = str(occurrence.get("target_sector_id", ""))
	var source_sector_id: String = str(occurrence.get("source_sector_id", ""))
	GameState.runtime_contract_occurrences.erase(occurrence_id)
	_remove_runtime_contract_index_entry(GameState.runtime_contract_occurrences_by_target_sector, target_sector_id, occurrence_id)
	_remove_runtime_contract_index_entry(GameState.runtime_contract_occurrences_by_source_sector, source_sector_id, occurrence_id)


func _remove_runtime_contract_index_entry(index: Dictionary, sector_id: String, occurrence_id: String) -> void:
	if not index.has(sector_id):
		return
	var updated_ids: Array = []
	for existing_id in Array(index.get(sector_id, [])):
		if existing_id != occurrence_id:
			updated_ids.append(existing_id)
	if updated_ids.empty():
		index.erase(sector_id)
	else:
		index[sector_id] = updated_ids


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
	var target: String = neighbors[_rng.randi() % neighbors.size()]
	_action_move_toward(agent_id, agent, target)


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

		var degree: int = _graph_degree(neighbor_key)
		if degree < Constants.MAX_CONNECTIONS_PER_SECTOR:
			score += 1.25
		if degree <= 2:
			score += 0.75

		if agent.get("wealth_tag") == "BROKE" and ("STATION" in n_tags or "FRONTIER" in n_tags):
			score += 2.5
		if agent.get("condition_tag") == "DAMAGED" and ("STATION" in n_tags or "FRONTIER" in n_tags):
			score += 1.0

		score -= float(_active_agent_count_in_sector(neighbor_key)) * 0.25

		if score > best_score or (is_equal_approx(score, best_score) and (best_sector == "" or neighbor_key < best_sector)):
			best_score = score
			best_sector = neighbor_key

	if best_sector != "":
		_action_move_toward(agent_id, agent, best_sector)
	else:
		_action_move_random(agent_id, agent)


func _action_move_toward_role_target(agent_id: String, agent: Dictionary) -> void:
	var role: String = agent.get("agent_role", "idle")
	if role == "explorer":
		_action_move_toward_exploration_target(agent_id, agent)
		return
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


# =============================================================================
# === PRIVATE — EXPLORATION ===================================================
# =============================================================================

func _try_exploration(agent_id: String, agent: Dictionary, sector_id: String) -> void:
	_last_exploration_outcome = "blocked"

	# Cap check
	if GameState.world_topology.size() >= Constants.MAX_SECTOR_COUNT:
		_last_exploration_outcome = "cap"
		_log_event(agent_id, "expedition_failed", sector_id, {})
		return

	if agent.get("wealth_tag") == "BROKE":
		_last_exploration_outcome = "broke"
		_log_event(agent_id, "expedition_failed", sector_id, {"reason": "broke"})
		return

	# Per-agent cooldown
	var last_discovery: int = int(agent.get("last_discovery_tick", -999))
	if GameState.sim_tick_count - last_discovery < Constants.EXPLORATION_COOLDOWN_TICKS:
		_last_exploration_outcome = "cooldown"
		_log_event(agent_id, "expedition_failed", sector_id, {"reason": "cooldown"})
		return

	# Probability gate — diminishing returns
	var sector_count: int = GameState.world_topology.size()
	var saturation: float = float(sector_count) / float(Constants.MAX_SECTOR_COUNT)
	var sector_tags: Array = GameState.sector_tags.get(sector_id, [])
	var sector_modifier: float = _get_exploration_success_modifier(sector_id, sector_tags)
	var effective_chance: float = Constants.EXPLORATION_SUCCESS_CHANCE * (1.0 - saturation) * sector_modifier
	if _rng.randf() > effective_chance:
		_last_exploration_outcome = "nothing_found"
		_log_event(agent_id, "expedition_failed", sector_id, {"reason": "nothing_found"})
		return

	agent["last_discovery_tick"] = GameState.sim_tick_count
	var next_discovery_count: int = GameState.discovered_sector_count + 1
	var new_id: String = "discovered_" + str(next_discovery_count)

	# Determine connections (filament topology)
	var source_id: String = sector_id
	if _graph_degree(source_id) >= Constants.MAX_CONNECTIONS_PER_SECTOR:
		var fallback_candidates: Array = []
		var source_connections: Array = GameState.world_topology.get(source_id, {}).get("connections", [])
		for neighbor_id in source_connections:
			if _graph_degree(neighbor_id) < Constants.MAX_CONNECTIONS_PER_SECTOR:
				fallback_candidates.append(neighbor_id)

		if fallback_candidates.empty():
			_last_exploration_outcome = "region_saturated"
			_log_event(agent_id, "expedition_failed", sector_id, {"reason": "region_saturated"})
			return

		# Sort by degree (ascending), then by name for determinism
		fallback_candidates.sort_custom(self, "_sort_by_degree")
		source_id = fallback_candidates[0]

	var source_tags: Array = Array(GameState.sector_tags.get(source_id, sector_tags))
	var connection_chances: Dictionary = _get_discovery_connection_chances(source_id, source_tags)
	var connections: Array = [source_id]

	var extra_one_added: bool = false
	if _rng.randf() < float(connection_chances.get("extra_one", Constants.EXTRA_CONNECTION_1_CHANCE)):
		var nearby: Array = _nearby_candidates(source_id, connections)
		if not nearby.empty():
			nearby.sort()
			var extra_one: String = nearby[_rng.randi() % nearby.size()]
			if not (extra_one in connections):
				connections.append(extra_one)
				extra_one_added = true

	if extra_one_added and _rng.randf() < float(connection_chances.get("extra_two", Constants.EXTRA_CONNECTION_2_CHANCE)):
		var loop_candidate = _distant_loop_candidate(source_id, connections)
		if loop_candidate != null and not (loop_candidate in connections):
			connections.append(loop_candidate)

	var profile: Dictionary = _select_discovered_sector_profile(new_id)
	var placement: Dictionary = _build_discovered_sector_placement(new_id, source_id)
	if not bool(placement.get("is_valid", true)):
		_last_exploration_outcome = "spatially_blocked"
		_log_event(agent_id, "expedition_failed", sector_id, {"reason": "spatially_blocked"})
		return
	var global_position: Vector3 = placement.get("global_position", Vector3.ZERO)
	connections = _filter_spatially_plausible_connections(source_id, connections, global_position)

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
	var new_name: String = _generate_sector_name_for_discovery(next_discovery_count, profile, initial_tags)

	# Wire into the world graph (bidirectional)
	GameState.world_topology[new_id] = {
		"connections": Array(connections),
		"station_ids": [new_id],
		"sector_type": str(profile.get("sector_type", "deep_space")),
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
	GameState.discovered_sector_count = next_discovery_count
	_register_discovered_sector_template(new_id, new_name, connections, global_position, initial_tags, profile, placement)
	_last_exploration_outcome = "discovered"

	# Record
	GameState.sector_names[new_id] = new_name
	if not (new_id in GameState.discovered_sectors):
		GameState.discovered_sectors.append(new_id)
	var generated_station: Dictionary = _generate_procedural_station_for_sector(new_id)
	GameState.discovery_log.append({
		"tick": GameState.sim_tick_count,
		"discoverer": agent_id,
		"from": source_id,
		"requested_from": sector_id,
		"new_sector": new_id,
		"name": new_name,
		"procedural_type": str(profile.get("procedural_type", "deep_space")),
		"global_position": global_position,
		"branch_separation_deg": float(placement.get("branch_separation_deg", 180.0)),
		"branch_mode": str(placement.get("branch_mode", "planar")),
		"generated_station_id": str(generated_station.get("id", "")),
	})
	_log_event(agent_id, "sector_discovered", source_id, {
		"new_sector": new_id,
		"name": new_name,
		"connections": connections,
		"requested_from": sector_id,
		"procedural_type": str(profile.get("procedural_type", "deep_space")),
		"global_position": global_position,
		"generated_station_id": str(generated_station.get("id", "")),
	})


func _generate_procedural_station_for_sector(sector_id: String) -> Dictionary:
	if sector_id == "":
		return {}
	if not GameState.world_topology.has(sector_id):
		return {}
	if not TemplateDatabase.locations.has(sector_id):
		return {}

	var station_id: String = "station_%s" % sector_id
	if GameState.station_by_id.has(station_id):
		return Dictionary(GameState.station_by_id.get(station_id, {})).duplicate(true)

	var sector_name: String = str(GameState.sector_names.get(sector_id, ""))
	if sector_name == "":
		sector_name = str(_get_template_value(TemplateDatabase.locations.get(sector_id), "location_name", sector_id))
	var station_name: String = "%s Station" % sector_name
	var docking_point: Vector3 = _build_procedural_station_docking_point(sector_id)

	var station_data: Dictionary = {
		"id": station_id,
		"display_name": station_name,
		"sector_id": sector_id,
		"location_id": station_id,
		"docking_point": docking_point,
	}
	GameState.station_by_id[station_id] = station_data.duplicate(true)

	var world_sector: Dictionary = GameState.world_topology.get(sector_id, {})
	world_sector["station_ids"] = [station_id]
	GameState.world_topology[sector_id] = world_sector

	var sector_tags: Array = Array(GameState.sector_tags.get(sector_id, []))
	if not ("STATION" in sector_tags):
		sector_tags.append("STATION")
	GameState.sector_tags[sector_id] = sector_tags

	GameState.locations[station_id] = {
		"location_name": station_name,
		"position_in_zone": docking_point,
		"available_services": ["trade", "contracts"],
		"sector_id": sector_id,
	}

	var sector_template = TemplateDatabase.locations.get(sector_id)
	var hints = _get_template_value(sector_template, "procedural_hints", {})
	if not (hints is Dictionary):
		hints = {}
	hints["procedural_station_id"] = station_id
	hints["procedural_station_name"] = station_name
	hints["procedural_station_docking_point"] = docking_point
	if sector_template is Dictionary:
		sector_template["procedural_hints"] = hints
		TemplateDatabase.locations[sector_id] = sector_template
	else:
		sector_template.procedural_hints = hints

	return station_data.duplicate(true)


func _build_procedural_station_docking_point(sector_id: String) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(GameState.world_seed) + ":procedural_station:" + sector_id)
	var radial_distance: float = 2800.0 + rng.randf_range(0.0, 1900.0)
	var angle: float = rng.randf_range(-PI, PI)
	var x: float = cos(angle) * radial_distance
	var z: float = sin(angle) * radial_distance
	var y: float = rng.randf_range(-220.0, 220.0)
	return Vector3(x, y, z)


func _select_discovered_sector_profile(new_id: String) -> Dictionary:
	var profile_rng: RandomNumberGenerator = _make_discovery_rng("profile", new_id)
	return _LOW_VISIBILITY_DISCOVERY_PROFILES[profile_rng.randi() % _LOW_VISIBILITY_DISCOVERY_PROFILES.size()].duplicate(true)


func _build_discovered_sector_placement(new_id: String, source_id: String) -> Dictionary:
	var placement_rng: RandomNumberGenerator = _make_discovery_rng("placement", new_id)
	var source_position: Vector3 = _get_sector_global_position(source_id)
	var branch_mode: String = "vertical" if _should_use_vertical_discovery_branch(source_id, placement_rng) else "planar"
	var preferred_direction: Vector3 = _get_discovery_base_direction(source_id, placement_rng)
	var best_candidate: Vector3 = source_position + (preferred_direction * Constants.DISCOVERY_BRANCH_DISTANCE_BASE)
	var best_axis: Vector3 = preferred_direction
	var best_clearance: float = -1.0
	var best_branch_separation: float = 180.0
	var best_score: float = -INF
	var required_branch_separation: float = _get_required_discovery_branch_angle(source_id)

	for _attempt in range(Constants.DISCOVERY_BRANCH_POSITION_ATTEMPTS):
		var distance: float = Constants.DISCOVERY_BRANCH_DISTANCE_BASE + placement_rng.randf_range(
			-Constants.DISCOVERY_BRANCH_DISTANCE_JITTER,
			Constants.DISCOVERY_BRANCH_DISTANCE_JITTER
		)
		var branch_axis: Vector3 = _build_discovery_branch_axis(source_id, preferred_direction, branch_mode, placement_rng)
		var candidate: Vector3 = source_position + (branch_axis * distance)
		candidate.y += placement_rng.randf_range(
			-Constants.DISCOVERY_PLANAR_VERTICAL_JITTER,
			Constants.DISCOVERY_PLANAR_VERTICAL_JITTER
		)
		if branch_mode == "vertical":
			var vertical_sign: float = -1.0 if placement_rng.randf() < 0.5 else 1.0
			candidate.y += vertical_sign * placement_rng.randf_range(
				Constants.DISCOVERY_VERTICAL_BRANCH_MIN_OFFSET,
				Constants.DISCOVERY_VERTICAL_BRANCH_MAX_OFFSET
			)

		var clearance: float = _measure_discovery_clearance(candidate, source_id)
		var branch_separation_deg: float = _measure_discovery_branch_separation(source_id, candidate)
		var candidate_score: float = clearance + (branch_separation_deg * Constants.DISCOVERY_BRANCH_ANGLE_SCORE_WEIGHT)
		if candidate_score > best_score:
			best_score = candidate_score
			best_clearance = clearance
			best_candidate = candidate
			best_axis = branch_axis
			best_branch_separation = branch_separation_deg
		if clearance >= Constants.DISCOVERY_BRANCH_MIN_CLEARANCE and branch_separation_deg >= required_branch_separation:
			break

	return {
		"global_position": best_candidate,
		"branch_axis": best_axis,
		"branch_separation_deg": best_branch_separation,
		"branch_mode": branch_mode,
		"is_valid": best_clearance >= Constants.DISCOVERY_BRANCH_MIN_CLEARANCE and best_branch_separation >= required_branch_separation,
	}


func _build_discovery_branch_axis(source_id: String, preferred_direction: Vector3, branch_mode: String, placement_rng: RandomNumberGenerator) -> Vector3:
	var planar_direction: Vector3 = Vector3(preferred_direction.x, 0.0, preferred_direction.z)
	if planar_direction.length_squared() < 0.001:
		planar_direction = _random_planar_direction(placement_rng)
	planar_direction = planar_direction.normalized()
	var jitter_span_deg: float = min(
		88.0,
		Constants.DISCOVERY_BRANCH_DIRECTION_JITTER_DEG + (
			float(_get_discovered_branch_count(source_id)) * Constants.DISCOVERY_BRANCH_JITTER_PER_EXISTING_BRANCH_DEG
		)
	)
	planar_direction = planar_direction.rotated(
		Vector3.UP,
		deg2rad(placement_rng.randf_range(
			-jitter_span_deg,
			jitter_span_deg
		))
	)

	if branch_mode != "vertical":
		return Vector3(
			planar_direction.x,
			preferred_direction.y,
			planar_direction.z
		).normalized()

	var vertical_sign: float = -1.0 if placement_rng.randf() < 0.5 else 1.0
	var branch_axis: Vector3 = (planar_direction * (1.0 - Constants.DISCOVERY_VERTICAL_BRANCH_Y_BIAS)) + (
		Vector3.UP * vertical_sign * Constants.DISCOVERY_VERTICAL_BRANCH_Y_BIAS
	)
	return branch_axis.normalized()


func _get_discovery_base_direction(source_id: String, placement_rng: RandomNumberGenerator) -> Vector3:
	var inherited_axis: Vector3 = _get_inherited_discovery_axis(source_id)
	var source_position: Vector3 = _get_sector_global_position(source_id)
	var away_bias: Vector3 = Vector3.ZERO
	var neighbors: Array = GameState.world_topology.get(source_id, {}).get("connections", [])
	for neighbor_id in neighbors:
		var neighbor_position: Vector3 = _get_sector_global_position(neighbor_id)
		var away_vector: Vector3 = source_position - neighbor_position
		if away_vector.length_squared() > 0.001:
			away_bias += away_vector.normalized()

	if inherited_axis.length_squared() > 0.001:
		away_bias += inherited_axis.normalized() * 1.35

	if away_bias.length_squared() < 0.001:
		return _random_planar_direction(placement_rng)
	return away_bias.normalized()


func _get_inherited_discovery_axis(source_id: String) -> Vector3:
	var source_template = TemplateDatabase.locations.get(source_id)
	var hints = _get_template_value(source_template, "procedural_hints", {})
	if not (hints is Dictionary):
		return Vector3.ZERO
	var branch_axis = hints.get("branch_axis", Vector3.ZERO)
	if branch_axis is Vector3 and branch_axis.length_squared() > 0.001:
		return branch_axis
	return Vector3.ZERO


func _should_use_vertical_discovery_branch(source_id: String, placement_rng: RandomNumberGenerator) -> bool:
	var source_template = TemplateDatabase.locations.get(source_id)
	if bool(_get_template_value(source_template, "is_procedural", false)):
		var hints = _get_template_value(source_template, "procedural_hints", {})
		if hints is Dictionary and str(hints.get("branch_mode", "planar")) == "vertical":
			return placement_rng.randf() < Constants.DISCOVERY_VERTICAL_BRANCH_CONTINUE_CHANCE
	return placement_rng.randf() < Constants.DISCOVERY_VERTICAL_BRANCH_CHANCE


func _measure_discovery_clearance(candidate_position: Vector3, source_id: String) -> float:
	var nearest_distance: float = INF
	for sector_id in TemplateDatabase.locations:
		if sector_id == source_id:
			continue
		var sector_position: Vector3 = _get_sector_global_position(sector_id)
		var distance: float = candidate_position.distance_to(sector_position)
		if distance < nearest_distance:
			nearest_distance = distance
	if nearest_distance == INF:
		return Constants.DISCOVERY_BRANCH_MIN_CLEARANCE
	return nearest_distance


func _measure_discovery_branch_separation(source_id: String, candidate_position: Vector3) -> float:
	var source_position: Vector3 = _get_sector_global_position(source_id)
	var candidate_axis: Vector3 = candidate_position - source_position
	if candidate_axis.length_squared() < 0.001:
		return 180.0
	candidate_axis = candidate_axis.normalized()
	var min_angle_deg: float = 180.0
	var neighbors: Array = GameState.world_topology.get(source_id, {}).get("connections", [])
	for neighbor_id in neighbors:
		if not _is_discovered_sector_id(str(neighbor_id)):
			continue
		var neighbor_axis: Vector3 = _get_sector_global_position(str(neighbor_id)) - source_position
		if neighbor_axis.length_squared() < 0.001:
			continue
		min_angle_deg = min(min_angle_deg, rad2deg(candidate_axis.angle_to(neighbor_axis.normalized())))
	return min_angle_deg


func _get_required_discovery_branch_angle(source_id: String) -> float:
	return Constants.DISCOVERY_BRANCH_MIN_SIBLING_ANGLE_DEG if _get_discovered_branch_count(source_id) > 0 else 0.0


func _get_discovered_branch_count(source_id: String) -> int:
	var count: int = 0
	var neighbors: Array = GameState.world_topology.get(source_id, {}).get("connections", [])
	for neighbor_id in neighbors:
		if _is_discovered_sector_id(str(neighbor_id)):
			count += 1
	return count


func _is_discovered_sector_id(sector_id: String) -> bool:
	if sector_id.begins_with("discovered_"):
		return true
	var hints = _get_template_value(TemplateDatabase.locations.get(sector_id), "procedural_hints", {})
	return hints is Dictionary and bool(hints.get("low_visibility", false))


func _filter_spatially_plausible_connections(source_id: String, candidate_connections: Array, global_position: Vector3) -> Array:
	var filtered_connections: Array = [source_id]
	for idx in range(1, candidate_connections.size()):
		var target_id: String = str(candidate_connections[idx])
		var target_position: Vector3 = _get_sector_global_position(target_id)
		if global_position.distance_to(target_position) <= Constants.DISCOVERY_MAX_LINK_DISTANCE:
			filtered_connections.append(target_id)
	return filtered_connections


func _get_discovery_connection_chances(source_id: String, source_tags: Array) -> Dictionary:
	var extra_one: float = Constants.EXTRA_CONNECTION_1_CHANCE
	var extra_two: float = Constants.EXTRA_CONNECTION_2_CHANCE
	if _is_exploration_anchor_sector(source_id, source_tags) or _graph_degree(source_id) <= 2:
		extra_one = max(extra_one, Constants.FRONTIER_DISCOVERY_EXTRA_CONNECTION_1_CHANCE)
		extra_two = max(extra_two, Constants.FRONTIER_DISCOVERY_EXTRA_CONNECTION_2_CHANCE)
	return {
		"extra_one": extra_one,
		"extra_two": extra_two,
	}


func _register_discovered_sector_template(
		new_id: String,
		new_name: String,
		connections: Array,
		global_position: Vector3,
		initial_tags: Array,
		profile: Dictionary,
		placement: Dictionary) -> void:
	var template = LocationTemplateScript.new()
	template.template_id = new_id
	template.location_name = new_name
	template.location_type = str(profile.get("location_type", "debris_field"))
	template.sector_scene_path = ""
	template.global_position = global_position
	template.is_procedural = true
	template.procedural_type = str(profile.get("procedural_type", "deep_space"))
	template.procedural_hints = {
		"branch_axis": placement.get("branch_axis", Vector3.FORWARD),
		"branch_mode": placement.get("branch_mode", "planar"),
		"branch_separation_deg": placement.get("branch_separation_deg", 180.0),
		"discovered_from": connections[0] if not connections.empty() else "",
		"low_visibility": true,
		"source_distance": global_position.distance_to(_get_sector_global_position(connections[0])) if not connections.empty() else 0.0,
	}
	template.sector_description = str(profile.get("description", "A dim deep-space contact that demanded a deliberate search."))
	template.connections = PoolStringArray(connections)
	template.sector_type = str(profile.get("sector_type", "deep_space"))
	template.initial_sector_tags = PoolStringArray(initial_tags)
	TemplateDatabase.locations[new_id] = template


func _make_discovery_rng(purpose: String, new_id: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(GameState.world_seed) + ":" + purpose + ":" + new_id + ":" + str(GameState.sim_tick_count))
	return rng


func _get_template_value(template, key: String, default_value = null):
	if template == null:
		return default_value
	if template is Dictionary:
		return template.get(key, default_value)
	var value = template.get(key)
	return value if value != null else default_value


func _get_sector_global_position(sector_id: String) -> Vector3:
	var sector_template = TemplateDatabase.locations.get(sector_id)
	var global_position = _get_template_value(sector_template, "global_position", null)
	return global_position if global_position is Vector3 else Vector3.ZERO


func _random_planar_direction(placement_rng: RandomNumberGenerator) -> Vector3:
	var angle: float = placement_rng.randf_range(-PI, PI)
	return Vector3(cos(angle), 0.0, sin(angle)).normalized()


func _generate_sector_name() -> String:
	return _generate_sector_name_for_count(GameState.discovered_sector_count)


func _generate_sector_name_for_count(discovery_count: int) -> String:
	var prefixes: Array = Array(Constants.FRONTIER_DISCOVERY_NAME_PREFIXES)
	var suffixes: Array = Array(Constants.FRONTIER_DISCOVERY_NAME_SUFFIXES)
	return _build_discovery_sector_name_candidate(discovery_count, 0, prefixes, suffixes)


func _generate_sector_name_for_discovery(discovery_count: int, profile: Dictionary, initial_tags: Array) -> String:
	var procedural_type: String = str(profile.get("procedural_type", "deep_space"))
	var prefixes: Array = _get_discovery_prefix_word_pool(procedural_type, initial_tags)
	var suffixes: Array = _get_discovery_suffix_word_pool(initial_tags)
	return _generate_unique_discovery_sector_name(discovery_count, prefixes, suffixes)


func _generate_unique_discovery_sector_name(discovery_count: int, prefixes: Array, suffixes: Array) -> String:
	var used_names: Dictionary = _used_sector_display_names()
	var max_attempts: int = Constants.DISCOVERY_NAME_UNIQUENESS_MAX_ATTEMPTS
	for attempt in range(max_attempts):
		var candidate: String = _build_discovery_sector_name_candidate(discovery_count, attempt, prefixes, suffixes)
		if not used_names.has(candidate.to_lower()):
			return candidate
	for attempt in range(max_attempts, max_attempts + 12):
		var fallback: String = _build_multi_root_discovery_name_candidate(discovery_count, attempt)
		if not used_names.has(fallback.to_lower()):
			return fallback
	return "Unnamed Reach " + str(discovery_count)


func _build_discovery_sector_name_candidate(discovery_count: int, attempt: int, prefixes: Array, suffixes: Array) -> String:
	var generated_root: String = _generate_discovery_name_root(discovery_count, attempt)
	var seed_key: String = _discovery_name_seed_key(discovery_count, attempt)
	var prefix_word: String = _select_discovery_name_word(prefixes, seed_key + ":prefix")
	var suffix_word: String = _select_discovery_name_word(suffixes, seed_key + ":suffix", prefix_word)
	return _compose_discovery_sector_name(generated_root, prefix_word, suffix_word)


func _build_multi_root_discovery_name_candidate(discovery_count: int, attempt: int) -> String:
	var leading_root: String = _generate_discovery_name_root(discovery_count, attempt)
	var trailing_root: String = _legacy_system_name_generator.generate_system_name(
		_discovery_name_seed_key(discovery_count, attempt) + ":tail",
		3,
		4
	)
	if trailing_root.empty():
		return leading_root
	return leading_root + " " + trailing_root


func _generate_discovery_name_root(discovery_count: int, attempt: int = 0) -> String:
	return _legacy_system_name_generator.generate_system_name(
		_discovery_name_seed_key(discovery_count, attempt),
		Constants.DISCOVERY_SYSTEM_NAME_LENGTH_MIN,
		Constants.DISCOVERY_SYSTEM_NAME_LENGTH_MAX
	)


func _compose_discovery_sector_name(generated_root: String, prefix_word: String, suffix_word: String) -> String:
	var cleaned_root: String = str(generated_root).strip_edges()
	if cleaned_root.empty():
		return "Unnamed Reach"
	var word_budget: int = _discovery_name_word_budget(cleaned_root.length())
	var composed_name: String = cleaned_root
	if word_budget >= 2 and not prefix_word.empty():
		composed_name = prefix_word + " " + composed_name
	if word_budget >= 1 and not suffix_word.empty():
		composed_name += " " + suffix_word
	return composed_name


func _discovery_name_word_budget(root_length: int) -> int:
	if root_length <= Constants.DISCOVERY_NAME_SHORT_ROOT_MAX_LENGTH:
		return 2
	if root_length <= Constants.DISCOVERY_NAME_MEDIUM_ROOT_MAX_LENGTH:
		return 1
	return 0


func _select_discovery_name_word(words: Array, seed_key: String, excluded_word: String = "") -> String:
	if words.empty():
		return ""
	var word_rng := RandomNumberGenerator.new()
	word_rng.seed = hash(str(GameState.world_seed) + ":discovery_word:" + str(seed_key))
	var index: int = word_rng.randi() % words.size()
	var selected_word: String = str(words[index])
	if not excluded_word.empty() and selected_word == excluded_word and words.size() > 1:
		selected_word = str(words[(index + 1) % words.size()])
	return selected_word


func _discovery_name_seed_key(discovery_count: int, attempt: int) -> String:
	return str(GameState.world_seed) + ":discovery_name:" + str(discovery_count) + ":" + str(attempt)


func _used_sector_display_names() -> Dictionary:
	var used_names: Dictionary = {}
	for sector_name in GameState.sector_names.values():
		var known_name: String = str(sector_name).strip_edges()
		if not known_name.empty():
			used_names[known_name.to_lower()] = true
	for sector_id in TemplateDatabase.locations:
		var template_name: String = str(_get_template_value(TemplateDatabase.locations.get(sector_id), "location_name", "")).strip_edges()
		if not template_name.empty():
			used_names[template_name.to_lower()] = true
	return used_names


func _get_discovery_prefix_word_pool(procedural_type: String, initial_tags: Array) -> Array:
	var procedural_pool = Constants.FRONTIER_DISCOVERY_NAME_PREFIXES_BY_PROCEDURAL_TYPE.get(procedural_type, [])
	if procedural_pool is Array and not procedural_pool.empty():
		return Array(procedural_pool)
	var environment_pool = Constants.FRONTIER_DISCOVERY_NAME_PREFIXES_BY_ENVIRONMENT.get(_discovery_environment_tag(initial_tags), [])
	if environment_pool is Array and not environment_pool.empty():
		return Array(environment_pool)
	return Array(Constants.FRONTIER_DISCOVERY_NAME_PREFIXES)


func _get_discovery_suffix_word_pool(initial_tags: Array) -> Array:
	var economy_level: String = _discovery_economy_level(initial_tags)
	var economy_pool = Constants.FRONTIER_DISCOVERY_NAME_SUFFIXES_BY_ECONOMY_LEVEL.get(economy_level, [])
	if economy_pool is Array and not economy_pool.empty():
		return Array(economy_pool)
	return Array(Constants.FRONTIER_DISCOVERY_NAME_SUFFIXES)


func _discovery_environment_tag(initial_tags: Array) -> String:
	for environment_tag in ["EXTREME", "HARSH", "MILD"]:
		if environment_tag in initial_tags:
			return environment_tag
	return "MILD"


func _discovery_economy_level(initial_tags: Array) -> String:
	var counts: Dictionary = {"POOR": 0, "ADEQUATE": 0, "RICH": 0}
	for tag in initial_tags:
		var tag_text: String = str(tag)
		for economy_level in ["POOR", "ADEQUATE", "RICH"]:
			if tag_text.ends_with("_" + economy_level):
				counts[economy_level] = int(counts.get(economy_level, 0)) + 1
	if int(counts.get("RICH", 0)) >= 2:
		return "RICH"
	if int(counts.get("POOR", 0)) >= 2:
		return "POOR"
	return "ADEQUATE"


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

	var home_sector_id: String = _resolve_known_sector_id(
		agent.get("home_location_id", ""),
		"%s.home_location_id" % agent_id
	)
	agent["is_disabled"] = false
	agent["home_location_id"] = home_sector_id
	agent["current_sector_id"] = home_sector_id
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
	var effective_chance: float = Constants.MORTAL_SPAWN_CHANCE * _mortal_spawn_age_multiplier() * (1.0 - saturation)
	effective_chance = clamp(effective_chance, 0.0, 1.0)
	if _rng.randf() > effective_chance:
		return

	var spawn_sector: String = eligible[_rng.randi() % eligible.size()]
	GameState.mortal_agent_counter += 1
	var agent_id: String = "mortal_" + str(GameState.mortal_agent_counter)
	spawn_sector = _resolve_known_sector_id(spawn_sector, "%s.spawn_sector" % agent_id)
	var role: String = _pick_mortal_spawn_role()

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


func _mortal_spawn_age_multiplier() -> float:
	match GameState.world_age:
		"PROSPERITY":
			match _prosperity_growth_stage():
				2:
					return Constants.PROSPERITY_MORTAL_SPAWN_MULTIPLIER_LATE
				1:
					return Constants.PROSPERITY_MORTAL_SPAWN_MULTIPLIER_MID
				_:
					return Constants.PROSPERITY_MORTAL_SPAWN_MULTIPLIER_EARLY
		"DISRUPTION":
			return Constants.DISRUPTION_MORTAL_SPAWN_MULTIPLIER
		"RECOVERY":
			return Constants.RECOVERY_MORTAL_SPAWN_MULTIPLIER
	return 1.0


func _prosperity_growth_stage() -> int:
	if GameState.world_age != "PROSPERITY":
		return 0
	var total_ticks: int = int(Constants.WORLD_AGE_DURATIONS.get("PROSPERITY", 0))
	var current_timer: int = int(GameState.world_age_timer)
	if total_ticks <= 0 or current_timer <= 0:
		return 0
	var elapsed_ticks: int = total_ticks - current_timer
	if elapsed_ticks < 0:
		elapsed_ticks = 0
	var progress_ratio: float = float(elapsed_ticks) / float(total_ticks)
	if progress_ratio >= Constants.PROSPERITY_GROWTH_STAGE_2_RATIO:
		return 2
	if progress_ratio >= Constants.PROSPERITY_GROWTH_STAGE_1_RATIO:
		return 1
	return 0


func _pick_mortal_spawn_role() -> String:
	var role_pool: Array = Array(Constants.MORTAL_ROLES)
	if _should_limit_mortal_explorer_spawn():
		var filtered_roles: Array = []
		for role_name in role_pool:
			if str(role_name) != "explorer":
				filtered_roles.append(str(role_name))
		if not filtered_roles.empty():
			role_pool = filtered_roles
	return str(role_pool[_rng.randi() % role_pool.size()])


func _should_limit_mortal_explorer_spawn() -> bool:
	var frontier_sector_count: int = 0
	for sector_id in GameState.sector_tags:
		var tags: Array = Array(GameState.sector_tags.get(sector_id, []))
		if _is_exploration_anchor_sector(str(sector_id), tags):
			frontier_sector_count += 1

	var explorer_cap: int = max(
		1,
		int(ceil(float(frontier_sector_count) / float(Constants.MORTAL_EXPLORER_FRONTIER_SECTOR_RATIO)))
	)
	var active_explorer_count: int = 0
	for agent_id in GameState.agents:
		var agent: Dictionary = Dictionary(GameState.agents.get(agent_id, {}))
		if agent.get("is_disabled", false):
			continue
		if str(agent.get("agent_role", "")) == "explorer":
			active_explorer_count += 1
	return active_explorer_count >= explorer_cap


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
		var home_sector_id: String = _resolve_known_sector_id(
			agent.get("home_location_id", ""),
			"%s.home_location_id" % agent_id
		)
		agent["is_disabled"] = false
		agent["home_location_id"] = home_sector_id
		agent["current_sector_id"] = home_sector_id
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
				var recovery_chance: float = Constants.BROKE_RECOVERY_CHANCE
				if str(agent.get("agent_role", "")) == "explorer":
					recovery_chance = min(1.0, recovery_chance + Constants.EXPLORER_BROKE_RECOVERY_CHANCE_BONUS)
				if _rng.randf() < recovery_chance:
					agent["wealth_tag"] = "COMFORTABLE"


func _resolve_known_sector_id(requested_sector_id: String, context: String) -> String:
	if requested_sector_id != "" and GameState.world_topology.has(requested_sector_id):
		return requested_sector_id

	_report_invalid_sector(context, requested_sector_id)

	if Constants.INITIAL_SECTOR_ID != "" and GameState.world_topology.has(Constants.INITIAL_SECTOR_ID):
		return Constants.INITIAL_SECTOR_ID
	if not GameState.world_topology.empty():
		return str(GameState.world_topology.keys()[0])

	printerr("AgentLayer: No valid fallback sector available for %s." % context)
	return ""


func _report_invalid_sector(context: String, requested_sector_id: String) -> void:
	var normalized_sector_id: String = requested_sector_id if requested_sector_id != "" else "<empty>"
	var report_key = "%s:%s" % [context, normalized_sector_id]
	if _reported_invalid_sectors.has(report_key):
		return
	_reported_invalid_sectors[report_key] = true
	printerr(
		"AgentLayer: Invalid sector reference for %s -> %s. Falling back to %s." % [
			context,
			normalized_sector_id,
			Constants.INITIAL_SECTOR_ID,
		]
	)


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


func _remove_tag(tags: Array, tag: String) -> Array:
	var result: Array = []
	for existing_tag in tags:
		if existing_tag != tag:
			result.append(existing_tag)
	return result


func _security_tag(tags: Array) -> String:
	if "SECURE" in tags:
		return "SECURE"
	if "CONTESTED" in tags:
		return "CONTESTED"
	if "LAWLESS" in tags:
		return "LAWLESS"
	return "CONTESTED"


func _sector_recently_disabled(sector_id: String) -> bool:
	if sector_id == "":
		return false
	return int(GameState.sector_disabled_until.get(sector_id, -1)) >= GameState.sim_tick_count


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
