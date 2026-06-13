# PROJECT: GDTLancer
# MODULE: agent_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: GDD-REVISION-LEDGER.md REV_007; GDD-REVISION-LEDGER.md REV_008; TRUTH_SIMULATION-GRAPH.md §2.2.1; TRUTH_PROJECT.md § Agent Parity Principle
# LOG_REF: 2026-06-12 23:12:22

extends Reference

const LocationTemplateScript = preload("res://database/definitions/location_template.gd")
const LegacySystemNameGeneratorScript = preload("res://src/core/utils/legacy_system_name_generator.gd")

const AgentRoutingScript = preload("res://src/core/simulation/agent_layer/agent_routing.gd")
const AgentExplorerScript = preload("res://src/core/simulation/agent_layer/agent_explorer.gd")
const AgentMarketScript = preload("res://src/core/simulation/agent_layer/agent_market.gd")
const AgentContractScript = preload("res://src/core/simulation/agent_layer/agent_contract.gd")

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

## Sub-components
var routing: Reference
var explorer: Reference
var market: Reference
var contracts: Reference

func _init() -> void:
	routing = AgentRoutingScript.new()
	explorer = AgentExplorerScript.new()
	market = AgentMarketScript.new()
	contracts = AgentContractScript.new()
	routing.initialize(self)
	explorer.initialize(self)
	market.initialize(self)
	contracts.initialize(self)


## Per-tick seeded RNG for determinism.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _reported_invalid_sectors: Dictionary = {}
var _last_exploration_outcome: String = ""
var _CONTRACT_CATEGORIES: Array = ["RAW", "MANUFACTURED", "CURRENCY"]
var _LOW_VISIBILITY_DISCOVERY_PROFILES: Array = [
	{
		"procedural_type": "asteroid_field",
		"sector_type": "star",
		"description": "A sparse asteroid field with faint returns and narrow survey lanes.",
	},
	{
		"procedural_type": "comet_shoal",
		"sector_type": "star",
		"description": "A loose comet shoal whose volatile traces only surface under deliberate scans.",
	},
	{
		"procedural_type": "rogue_planet",
		"sector_type": "star",
		"description": "A cold rogue planet drifting in deep dark with almost no ambient signature.",
	},
	{
		"procedural_type": "dark_nebula",
		"sector_type": "star",
		"description": "A dark nebula pocket that hides weak contacts behind dense interference.",
	},
	{
		"procedural_type": "remnant_field",
		"sector_type": "star",
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


## Consumes and applies pending interactions from the player that require qualitative state changes.
func _consume_pending_sim_mutations() -> void:
	for mutation in GameState.pending_sim_mutations:
		if mutation.get("type") == "player_npc_trade":
			var agent_id: String = mutation.get("agent_id", "")
			if not GameState.agents.has(agent_id):
				continue
			var agent: Dictionary = GameState.agents[agent_id]
			
			agent["cargo_tag"] = mutation.get("new_cargo_tag", agent.get("cargo_tag", "EMPTY"))
			if agent["cargo_tag"] == "LOADED":
				agent["cargo_commodity_id"] = mutation.get("new_cargo_commodity_id", "")
			elif agent.has("cargo_commodity_id"):
				agent.erase("cargo_commodity_id")
			
			var delta: int = mutation.get("wealth_delta", 0)
			if delta > 0:
				_wealth_step_up(agent)
			elif delta < 0:
				_wealth_step_down(agent)
				
	GameState.pending_sim_mutations.clear()


## Processes all Agent-layer logic for one tick.
func process_tick(config: Dictionary) -> void:
	_consume_pending_sim_mutations()
	
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


## Periodically restocks market inventories for discovered (plain dict) station locations.
func _tick_market_restock() -> void:
	_process_market_restock()


func _process_market_restock() -> void:
	market._process_market_restock()


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
		"rest_ticks_remaining": 0,
		"dynamic_tags": [],
	}


# =============================================================================
# === PRIVATE — GOAL EVALUATION ===============================================
# =============================================================================

func _evaluate_goals(agent: Dictionary, agent_id: String = "") -> void:
	# Player contract interactions are user-driven through the contract board, not auto-serviced here.
	if agent_id == "player":
		agent["goal_archetype"] = "idle"
		agent["goal_queue"] = [{"type": "idle"}]
		return
	if _consume_mandatory_npc_rest_tick(agent_id, agent):
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
		_schedule_npc_rest_after_action(agent_id, agent, goal)
		return
	if goal == "service_contract":
		_action_service_contract(agent_id, agent, str(goal_queue[0].get("occurrence_id", "")))
		_schedule_npc_rest_after_action(agent_id, agent, goal)
		return
	if goal == "affinity_scan":
		_action_affinity_scan(agent_id, agent)
		_schedule_npc_rest_after_action(agent_id, agent, goal)


func _consume_mandatory_npc_rest_tick(agent_id: String, agent: Dictionary) -> bool:
	if agent_id == "player":
		return false
	if _should_skip_mandatory_npc_rest(agent_id, agent):
		agent["rest_ticks_remaining"] = 0
		return false
	var remaining_rest_ticks: int = max(0, int(agent.get("rest_ticks_remaining", 0)))
	if remaining_rest_ticks <= 0:
		return false
	agent["rest_ticks_remaining"] = remaining_rest_ticks - 1
	return true


func _schedule_npc_rest_after_action(agent_id: String, agent: Dictionary, goal: String) -> void:
	if agent_id == "player" or goal == "idle":
		return
	if agent.get("is_disabled", false):
		return
	if _should_skip_mandatory_npc_rest(agent_id, agent):
		agent["rest_ticks_remaining"] = 0
		return
	agent["rest_ticks_remaining"] = _mandatory_rest_ticks_for_agent(agent)


func _should_skip_mandatory_npc_rest(agent_id: String, agent: Dictionary) -> bool:
	if str(agent.get("cargo_tag", "EMPTY")) == "LOADED":
		return true
	return _has_active_runtime_contract_claim(agent_id)


func _has_active_runtime_contract_claim(agent_id: String) -> bool:
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


func _mandatory_rest_ticks_for_agent(agent: Dictionary) -> int:
	var condition_tag: String = str(agent.get("condition_tag", "HEALTHY"))
	var wealth_tag: String = str(agent.get("wealth_tag", "COMFORTABLE"))
	if condition_tag == "HEALTHY" and wealth_tag == "WEALTHY":
		return 3
	if condition_tag == "HEALTHY" and wealth_tag == "COMFORTABLE":
		return 2
	return 1


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
	var actor_tags: Array = Array(actor.get("sentiment_tags", []))
	var target_tags: Array = Array(target.get("sentiment_tags", []))

	if score >= Constants.ATTACK_THRESHOLD:
		if not _can_agents_escalate_to_disruption(actor, target, actor_tags, target_tags):
			return false
		var cargo_seized: bool = _apply_non_lethal_disruption(actor_id, actor, target_id, target, actor_tags, target_tags)
		actor["last_attack_tick"] = GameState.sim_tick_count
		_log_event(actor_id, "attack", current_sector, {
			"target": target_id,
			"outcome": "non_lethal_disruption",
			"cargo_seized": cargo_seized,
		})
		_post_combat_dispersal(actor_id, actor)
		return true

	if score >= Constants.TRADE_THRESHOLD:
		if not _can_agents_trade(actor, target, actor_tags, target_tags):
			return false
		_bilateral_trade(actor, target)
		_sync_player_cargo_mirror(actor_id, actor)
		_sync_player_cargo_mirror(target_id, target)
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
	var at_station: bool = true

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
	return explorer._get_exploration_success_modifier(sector_id, sector_tags)


func _has_frontier_pressure(sector_tags: Array) -> bool:
	return explorer._has_frontier_pressure(sector_tags)


func _is_exploration_cooldown_active(agent: Dictionary) -> bool:
	return explorer._is_exploration_cooldown_active(agent)


func _should_attempt_exploration(agent: Dictionary, sector_id: String, sector_tags: Array) -> bool:
	return explorer._should_attempt_exploration(agent, sector_id, sector_tags)


func _handle_explorer_non_exploration_turn(agent_id: String, agent: Dictionary, sector_id: String, sector_tags: Array, at_station: bool) -> void:
	explorer._handle_explorer_non_exploration_turn(agent_id, agent, sector_id, sector_tags, at_station)


func _is_exploration_anchor_sector(sector_id: String, sector_tags: Array) -> bool:
	return explorer._is_exploration_anchor_sector(sector_id, sector_tags)


func _has_local_exploration_outlet(sector_id: String) -> bool:
	return explorer._has_local_exploration_outlet(sector_id)


# =============================================================================
# === PRIVATE — RUNTIME CONTRACTS =============================================
# =============================================================================

func player_accept_runtime_contract(occurrence_id: String) -> bool:
	return contracts.player_accept_runtime_contract(occurrence_id)


func player_pick_up_runtime_contract(occurrence_id: String) -> bool:
	return contracts.player_pick_up_runtime_contract(occurrence_id)


func player_complete_runtime_contract(occurrence_id: String) -> bool:
	return contracts.player_complete_runtime_contract(occurrence_id)


func _player_current_sector_id() -> String:
	return contracts._player_current_sector_id()


func _best_runtime_contract_occurrence_id(agent_id: String, agent: Dictionary, actor_tags: Array) -> String:
	return contracts._best_runtime_contract_occurrence_id(agent_id, agent, actor_tags)


func _action_service_contract(agent_id: String, agent: Dictionary, occurrence_id: String) -> void:
	contracts._action_service_contract(agent_id, agent, occurrence_id)


func _claim_runtime_contract_occurrence(agent_id: String, agent: Dictionary, occurrence_id: String) -> bool:
	return contracts._claim_runtime_contract_occurrence(agent_id, agent, occurrence_id)


func _can_npc_claim_open_runtime_contract(agent_id: String, occurrence_id: String, occurrence: Dictionary) -> bool:
	return contracts._can_npc_claim_open_runtime_contract(agent_id, occurrence_id, occurrence)


func _release_runtime_contract_claim(agent_id: String, occurrence_id: String) -> void:
	contracts._release_runtime_contract_claim(agent_id, occurrence_id)


func _clear_runtime_contract_claims_for_agent(agent_id: String, agent: Dictionary) -> void:
	contracts._clear_runtime_contract_claims_for_agent(agent_id, agent)


func _load_runtime_contract_cargo(agent_id: String, agent: Dictionary, occurrence_id: String, sector_id: String) -> bool:
	return contracts._load_runtime_contract_cargo(agent_id, agent, occurrence_id, sector_id)


func _complete_runtime_contract_occurrence(agent_id: String, agent: Dictionary, occurrence_id: String, sector_id: String) -> bool:
	return contracts._complete_runtime_contract_occurrence(agent_id, agent, occurrence_id, sector_id)


func _complete_player_contract_delivery(agent: Dictionary, occurrence_id: String, sector_id: String) -> bool:
	return contracts._complete_player_contract_delivery(agent, occurrence_id, sector_id)


func _reserve_runtime_contract_resources(occurrence: Dictionary) -> bool:
	return contracts._reserve_runtime_contract_resources(occurrence)


func _reserve_contract_accounting_unit(supply_root: Dictionary, reserved_root: Dictionary, sector_id: String, category: String) -> bool:
	return contracts._reserve_contract_accounting_unit(supply_root, reserved_root, sector_id, category)


func _release_contract_accounting_unit(supply_root: Dictionary, reserved_root: Dictionary, sector_id: String, category: String) -> bool:
	return contracts._release_contract_accounting_unit(supply_root, reserved_root, sector_id, category)


func _consume_reserved_contract_unit(reserved_root: Dictionary, sector_id: String, category: String) -> bool:
	return contracts._consume_reserved_contract_unit(reserved_root, sector_id, category)


func _apply_contract_completion_sector_impact(occurrence: Dictionary, target_sector_id: String) -> void:
	contracts._apply_contract_completion_sector_impact(occurrence, target_sector_id)


func _refresh_contract_demand_tags_for_sector(sector_id: String) -> void:
	contracts._refresh_contract_demand_tags_for_sector(sector_id)


func _contract_demand_tag(category: String) -> String:
	return contracts._contract_demand_tag(category)


func _player_can_service_contract(agent: Dictionary) -> bool:
	return contracts._player_can_service_contract(agent)


func _remove_runtime_contract_occurrence(occurrence_id: String) -> void:
	contracts._remove_runtime_contract_occurrence(occurrence_id)


func _remove_runtime_contract_index_entry(index: Dictionary, sector_id: String, occurrence_id: String) -> void:
	contracts._remove_runtime_contract_index_entry(index, sector_id, occurrence_id)


func _is_contract_service_sector_available(sector_id: String) -> bool:
	return contracts._is_contract_service_sector_available(sector_id)



# =============================================================================
# === PRIVATE — DOCK / HARVEST / CARGO ========================================
# =============================================================================

func _try_dock(agent_id: String, agent: Dictionary, sector_id: String) -> void:

	var sold_cargo: bool = false
	if agent.get("cargo_tag") == "LOADED":
		if not _has_protected_contract_cargo(agent, agent.get("sentiment_tags", [])):
			if _attempt_npc_market_sell(agent_id, agent, sector_id):
				sold_cargo = true
			else:
				# Fallback to qualitative cargo sell
				agent["cargo_tag"] = "EMPTY"
				_wealth_step_up(agent)
				sold_cargo = true

	# Attempt buy if we did not just sell cargo in this dock action
	if not sold_cargo and agent.get("cargo_tag") == "EMPTY" and agent.get("wealth_tag") != "BROKE":
		var role: String = agent.get("agent_role", "idle")
		if role in ["trader", "hauler", "prospector"]:
			_attempt_npc_market_buy(agent_id, agent, sector_id)

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

	# Attempt quantitative market buy if at station/frontier with market service
	if role in ["trader", "hauler", "prospector"]:
		if _attempt_npc_market_buy(agent_id, agent, sector_id):
			return true

	var can_load: bool = false

	if role in ["hauler", "prospector"]:
		can_load = "RAW_RICH" in sector_tags or "MANUFACTURED_RICH" in sector_tags
	elif role == "trader":
		can_load = agent.get("wealth_tag") != "BROKE"
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


# NOTE: NPC dock-trade buy/sell mutations are not shared with station_menu.gd because:
# 1. station_menu.gd is a player UI Control Node, while agent_layer.gd is a pure backend simulation class.
# 2. Player transactions mutate numeric character credits and actual inventory assets via GlobalRefs.
# 3. NPC transactions mutate qualitative wealth_tags (e.g. step_down) and cargo_tags (e.g. LOADED) rather than numeric values.
# 4. The only shared data mutation is the direct symmetric adjustment of market_inventory quantity, which is kept inline for simplicity.
func _location_offers_service(location_id: String, service_id: String) -> bool:
	if location_id == "" or not GameState.locations.has(location_id):
		return true

	var location_record = GameState.locations[location_id]
	var available_services = null
	if location_record is Dictionary:
		available_services = location_record.get("available_services", null)
	elif location_record is Object and "available_services" in location_record:
		available_services = location_record.available_services

	return not (available_services is Array) or service_id in available_services


func _can_agent_trade_at_location(agent: Dictionary, location_id: String) -> bool:
	return market._can_agent_trade_at_location(agent, location_id)


func _can_agent_trade_commodity(agent: Dictionary, commodity_id: String, location_id: String) -> bool:
	return market._can_agent_trade_commodity(agent, commodity_id, location_id)


func _attempt_npc_market_sell(agent_id: String, agent: Dictionary, sector_id: String) -> bool:
	return market._attempt_npc_market_sell(agent_id, agent, sector_id)


func _attempt_npc_market_buy(agent_id: String, agent: Dictionary, sector_id: String) -> bool:
	return market._attempt_npc_market_buy(agent_id, agent, sector_id)
# --- END GDD REVISION: TRADER LOGIC BLOCK ---


# =============================================================================
# === PRIVATE — MOVEMENT ======================================================
# =============================================================================

func _action_move_toward(agent_id: String, agent: Dictionary, target_sector_id: String) -> void:
	routing._action_move_toward(agent_id, agent, target_sector_id)


func _action_move_toward_sector(agent_id: String, agent: Dictionary, target_sector_id: String) -> void:
	routing._action_move_toward_sector(agent_id, agent, target_sector_id)


func _action_move_random(agent_id: String, agent: Dictionary) -> void:
	routing._action_move_random(agent_id, agent)


func _action_move_toward_exploration_target(agent_id: String, agent: Dictionary) -> void:
	explorer._action_move_toward_exploration_target(agent_id, agent)


func _action_move_toward_role_target(agent_id: String, agent: Dictionary) -> void:
	routing._action_move_toward_role_target(agent_id, agent)


func _post_combat_dispersal(agent_id: String, agent: Dictionary) -> void:
	routing._post_combat_dispersal(agent_id, agent)


func _build_sector_route(start_sector_id: String, target_sector_id: String) -> Array:
	return routing._build_sector_route(start_sector_id, target_sector_id)


func _reconstruct_sector_route(parents: Dictionary, start_sector_id: String, target_sector_id: String) -> Array:
	return routing._reconstruct_sector_route(parents, start_sector_id, target_sector_id)


func _sector_hops_between(start_sector_id: String, target_sector_id: String) -> int:
	return routing._sector_hops_between(start_sector_id, target_sector_id)


# =============================================================================
# === PRIVATE — EXPLORATION ===================================================
# =============================================================================

func _try_exploration(agent_id: String, agent: Dictionary, sector_id: String) -> void:
	explorer._try_exploration(agent_id, agent, sector_id)


func _generate_procedural_station_for_sector(sector_id: String) -> Dictionary:
	return explorer._generate_procedural_station_for_sector(sector_id)


func _build_procedural_station_docking_point(sector_id: String) -> Vector3:
	return explorer._build_procedural_station_docking_point(sector_id)


func _select_discovered_sector_profile(new_id: String) -> Dictionary:
	return explorer._select_discovered_sector_profile(new_id)


func _build_discovered_sector_placement(new_id: String, source_id: String, profile: Dictionary) -> Dictionary:
	return explorer._build_discovered_sector_placement(new_id, source_id, profile)


func _build_discovery_branch_axis(source_id: String, preferred_direction: Vector3, branch_mode: String, placement_rng: RandomNumberGenerator) -> Vector3:
	return explorer._build_discovery_branch_axis(source_id, preferred_direction, branch_mode, placement_rng)


func _get_discovery_base_direction(source_id: String, placement_rng: RandomNumberGenerator) -> Vector3:
	return explorer._get_discovery_base_direction(source_id, placement_rng)


func _get_inherited_discovery_axis(source_id: String) -> Vector3:
	return explorer._get_inherited_discovery_axis(source_id)


func _should_use_vertical_discovery_branch(source_id: String, placement_rng: RandomNumberGenerator) -> bool:
	return explorer._should_use_vertical_discovery_branch(source_id, placement_rng)


func _measure_discovery_clearance(candidate_position: Vector3, source_id: String) -> float:
	return explorer._measure_discovery_clearance(candidate_position, source_id)


func _measure_discovery_branch_separation(source_id: String, candidate_position: Vector3) -> float:
	return explorer._measure_discovery_branch_separation(source_id, candidate_position)


func _get_required_discovery_branch_angle(source_id: String) -> float:
	return explorer._get_required_discovery_branch_angle(source_id)


func _get_discovered_branch_count(source_id: String) -> int:
	return explorer._get_discovered_branch_count(source_id)


func _is_discovered_sector_id(sector_id: String) -> bool:
	return explorer._is_discovered_sector_id(sector_id)


func _filter_spatially_plausible_connections(source_id: String, candidate_connections: Array, global_position: Vector3) -> Array:
	return explorer._filter_spatially_plausible_connections(source_id, candidate_connections, global_position)


func _get_discovery_connection_chances(source_id: String, source_tags: Array) -> Dictionary:
	return explorer._get_discovery_connection_chances(source_id, source_tags)


func _register_discovered_sector_template(
		new_id: String,
		new_name: String,
		connections: Array,
		global_position: Vector3,
		initial_tags: Array,
		profile: Dictionary,
		placement: Dictionary) -> void:
	explorer._register_discovered_sector_template(new_id, new_name, connections, global_position, initial_tags, profile, placement)


func _make_discovery_rng(purpose: String, new_id: String) -> RandomNumberGenerator:
	return explorer._make_discovery_rng(purpose, new_id)


func _get_template_value(template, key: String, default_value = null):
	return explorer._get_template_value(template, key, default_value)


func _get_sector_global_position(sector_id: String) -> Vector3:
	return explorer._get_sector_global_position(sector_id)


func _random_planar_direction(placement_rng: RandomNumberGenerator) -> Vector3:
	return explorer._random_planar_direction(placement_rng)


func _generate_sector_name() -> String:
	return explorer._generate_sector_name()


func _generate_sector_name_for_count(discovery_count: int) -> String:
	return explorer._generate_sector_name_for_count(discovery_count)


func _generate_sector_name_for_discovery(discovery_count: int, profile: Dictionary, initial_tags: Array) -> String:
	return explorer._generate_sector_name_for_discovery(discovery_count, profile, initial_tags)


func _generate_unique_discovery_sector_name(discovery_count: int, prefixes: Array, suffixes: Array) -> String:
	return explorer._generate_unique_discovery_sector_name(discovery_count, prefixes, suffixes)


func _build_discovery_sector_name_candidate(discovery_count: int, attempt: int, prefixes: Array, suffixes: Array) -> String:
	return explorer._build_discovery_sector_name_candidate(discovery_count, attempt, prefixes, suffixes)


func _build_multi_root_discovery_name_candidate(discovery_count: int, attempt: int) -> String:
	return explorer._build_multi_root_discovery_name_candidate(discovery_count, attempt)


func _generate_discovery_name_root(discovery_count: int, attempt: int = 0) -> String:
	return explorer._generate_discovery_name_root(discovery_count, attempt)


func _compose_discovery_sector_name(generated_root: String, prefix_word: String, suffix_word: String) -> String:
	return explorer._compose_discovery_sector_name(generated_root, prefix_word, suffix_word)


func _discovery_name_word_budget(root_length: int) -> int:
	return explorer._discovery_name_word_budget(root_length)


func _select_discovery_name_word(words: Array, seed_key: String, excluded_word: String = "") -> String:
	return explorer._select_discovery_name_word(words, seed_key, excluded_word)


func _discovery_name_seed_key(discovery_count: int, attempt: int) -> String:
	return explorer._discovery_name_seed_key(discovery_count, attempt)


func _used_sector_display_names() -> Dictionary:
	return explorer._used_sector_display_names()


func _get_discovery_prefix_word_pool(procedural_type: String, initial_tags: Array) -> Array:
	return explorer._get_discovery_prefix_word_pool(procedural_type, initial_tags)


func _get_discovery_suffix_word_pool(initial_tags: Array) -> Array:
	return explorer._get_discovery_suffix_word_pool(initial_tags)


func _discovery_environment_tag(initial_tags: Array) -> String:
	return explorer._discovery_environment_tag(initial_tags)


func _discovery_economy_level(initial_tags: Array) -> String:
	return explorer._discovery_economy_level(initial_tags)


func _graph_degree(sector_id: String) -> int:
	return routing._graph_degree(sector_id)


func _sort_by_degree(a: String, b: String) -> bool:
	return routing._sort_by_degree(a, b)


func _nearby_candidates(source_id: String, exclude: Array) -> Array:
	return explorer._nearby_candidates(source_id, exclude)


func _distant_loop_candidate(source_id: String, exclude: Array):
	return explorer._distant_loop_candidate(source_id, exclude)


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
	var actor_loaded: bool = str(actor.get("cargo_tag", "EMPTY")) == "LOADED"
	var target_loaded: bool = str(target.get("cargo_tag", "EMPTY")) == "LOADED"

	var payer: Dictionary = target if actor_loaded else actor
	var payee: Dictionary = actor if actor_loaded else target
	var payer_tags: Array = Array(payer.get("sentiment_tags", []))
	var payee_tags: Array = Array(payee.get("sentiment_tags", []))
	var instrument: String = _resolve_payment_instrument(payer_tags, payee_tags)

	var cargo_transferred := false
	if actor_loaded and not target_loaded:
		cargo_transferred = _transfer_cargo_between_agents(actor, target)
	elif target_loaded and not actor_loaded:
		cargo_transferred = _transfer_cargo_between_agents(target, actor)

	if cargo_transferred and instrument == "specie":
		var payer_uid = _get_character_uid(payer)
		var payee_uid = _get_character_uid(payee)
		var inv_sys = GlobalRefs.inventory_system
		if is_instance_valid(inv_sys):
			if payer_uid != -1:
				inv_sys.remove_asset(payer_uid, 2, "commodity_specie", 1)
			if payee_uid != -1:
				inv_sys.add_asset(payee_uid, 2, "commodity_specie", 1)


func _can_agents_escalate_to_disruption(actor: Dictionary, target: Dictionary, actor_tags: Array, target_tags: Array) -> bool:
	if _share_aligned_faction(actor_tags, target_tags):
		return false

	var actor_legality_tag: String = _agent_legality_tag(actor_tags)
	var target_legality_tag: String = _agent_legality_tag(target_tags)

	if "MILITARY" in actor_tags and target_legality_tag == "LEGAL_ILLICIT":
		return true
	if "PIRATE" in actor_tags and target_legality_tag != "LEGAL_ILLICIT":
		return true
	if actor_legality_tag == "LEGAL_LAWFUL" and target_legality_tag == "LEGAL_ILLICIT":
		return true
	if actor_legality_tag == "LEGAL_ILLICIT" and target_legality_tag == "LEGAL_LAWFUL":
		return true

	return false


func _apply_non_lethal_disruption(
		actor_id: String,
		actor: Dictionary,
		target_id: String,
		target: Dictionary,
		actor_tags: Array,
		target_tags: Array
	) -> bool:
	var cargo_seized: bool = false
	target["condition_tag"] = "DAMAGED"
	_wealth_step_down(target)
	target["rest_ticks_remaining"] = max(int(target.get("rest_ticks_remaining", 0)), 1)
	if target_id != "player":
		target["goal_archetype"] = "flee_to_safety"
		target["goal_queue"] = [{"type": "flee_to_safety"}]

	if _can_actor_seize_cargo(actor, target, actor_tags, target_tags):
		cargo_seized = _transfer_cargo_between_agents(target, actor)

	_sync_player_cargo_mirror(actor_id, actor)
	_sync_player_cargo_mirror(target_id, target)
	return cargo_seized


func _can_actor_seize_cargo(actor: Dictionary, target: Dictionary, actor_tags: Array, target_tags: Array) -> bool:
	if not ("PIRATE" in actor_tags):
		return false
	if "PIRATE" in target_tags:
		return false
	if _share_aligned_faction(actor_tags, target_tags):
		return false
	if _has_protected_contract_cargo(target, target_tags):
		return false
	return str(actor.get("cargo_tag", "EMPTY")) == "EMPTY" and str(target.get("cargo_tag", "EMPTY")) == "LOADED"


func _can_agents_trade(actor: Dictionary, target: Dictionary, actor_tags: Array, target_tags: Array) -> bool:
	var actor_loaded: bool = str(actor.get("cargo_tag", "EMPTY")) == "LOADED"
	var target_loaded: bool = str(target.get("cargo_tag", "EMPTY")) == "LOADED"
	if actor_loaded == target_loaded:
		return false
	if _has_protected_contract_cargo(actor, actor_tags) or _has_protected_contract_cargo(target, target_tags):
		return false

	var actor_role: String = str(actor.get("agent_role", "idle"))
	var target_role: String = str(target.get("agent_role", "idle"))
	if not (_is_commerce_role(actor_role) or _is_commerce_role(target_role)):
		return false
	if actor_role == "military" or target_role == "military":
		return false

	var actor_legality_tag: String = _agent_legality_tag(actor_tags)
	var target_legality_tag: String = _agent_legality_tag(target_tags)
	if _trade_legality_blocks_exchange(actor_legality_tag, target_legality_tag):
		return false
	if ("PIRATE" in actor_tags or "PIRATE" in target_tags) and not (
		actor_legality_tag == "LEGAL_ILLICIT" and target_legality_tag == "LEGAL_ILLICIT"
	):
		return false

	# Dual-economy trust-gated payment instrument routing
	var payer = target if actor_loaded else actor
	var payee = actor if actor_loaded else target
	var payer_tags = Array(payer.get("sentiment_tags", []))
	var payee_tags = Array(payee.get("sentiment_tags", []))
	var instrument = _resolve_payment_instrument(payer_tags, payee_tags)
	if instrument == "specie":
		var payer_uid = _get_character_uid(payer)
		if payer_uid != -1:
			var inv_sys = GlobalRefs.inventory_system
			if is_instance_valid(inv_sys):
				if inv_sys.get_asset_count(payer_uid, 2, "commodity_specie") < 1:
					return false

	return true


func _is_commerce_role(role: String) -> bool:
	return role in ["trader", "hauler", "prospector"]


func _trade_legality_blocks_exchange(actor_legality_tag: String, target_legality_tag: String) -> bool:
	if actor_legality_tag == "LEGAL_LAWFUL" and target_legality_tag == "LEGAL_ILLICIT":
		return true
	if actor_legality_tag == "LEGAL_ILLICIT" and target_legality_tag == "LEGAL_LAWFUL":
		return true
	if actor_legality_tag == "LEGAL_TOLERATED" and target_legality_tag == "LEGAL_ILLICIT":
		return true
	if actor_legality_tag == "LEGAL_ILLICIT" and target_legality_tag == "LEGAL_TOLERATED":
		return true
	return false


func _has_protected_contract_cargo(agent: Dictionary, tags: Array) -> bool:
	if str(agent.get("cargo_tag", "EMPTY")) != "LOADED":
		return false
	if str(agent.get("contract_cargo_tag", "")) != "":
		return true
	return ("CARGO_PROTECTED" in tags) or ("CARGO_CONTRACT" in tags)


func _share_aligned_faction(actor_tags: Array, target_tags: Array) -> bool:
	var actor_faction_tag: String = _tag_with_prefix(actor_tags, "FACTION_")
	var target_faction_tag: String = _tag_with_prefix(target_tags, "FACTION_")
	if actor_faction_tag == "" or target_faction_tag == "":
		return false
	if actor_faction_tag == "FACTION_UNALIGNED" or target_faction_tag == "FACTION_UNALIGNED":
		return false
	return actor_faction_tag == target_faction_tag


func _get_character_uid(agent: Dictionary) -> int:
	if agent.has("character_uid") and agent["character_uid"] != null:
		return int(agent["character_uid"])
	for agent_id in GameState.agents:
		if GameState.agents[agent_id] == agent:
			if GameState.persistent_agents.has(agent_id):
				var p_agent = GameState.persistent_agents[agent_id]
				if p_agent != null and p_agent.has("character_uid") and p_agent["character_uid"] != null:
					return int(p_agent["character_uid"])
			if agent_id == "player" and "player_character_uid" in GameState and GameState.player_character_uid != null:
				return int(GameState.player_character_uid)
			break
	return -1


func _resolve_payment_instrument(payer_tags: Array, payee_tags: Array) -> String:
	# NOTE: GDD REVISION - Dual-currency routing has been pruned.
	# We revert to a unified abstract wealth metric (credits) aligned with qualitative TTRPG/Ironsworn mechanics.
	return "credits"


func _agent_legality_tag(tags: Array) -> String:
	var explicit_tag: String = _tag_with_prefix(tags, "LEGAL_")
	if explicit_tag != "":
		return explicit_tag
	if "PIRATE" in tags:
		return "LEGAL_ILLICIT"
	if "TRADER" in tags or "HAULER" in tags or "MILITARY" in tags:
		return "LEGAL_LAWFUL"
	return "LEGAL_TOLERATED"


func _tag_with_prefix(tags: Array, prefix: String) -> String:
	for tag in tags:
		var label: String = str(tag)
		if label.begins_with(prefix):
			return label
	return ""


func _transfer_cargo_between_agents(source: Dictionary, destination: Dictionary) -> bool:
	if str(source.get("cargo_tag", "EMPTY")) != "LOADED":
		return false
	if str(destination.get("cargo_tag", "EMPTY")) != "EMPTY":
		return false

	destination["cargo_tag"] = "LOADED"
	source["cargo_tag"] = "EMPTY"

	if source.has("contract_cargo_tag"):
		destination["contract_cargo_tag"] = source.get("contract_cargo_tag", "")
	elif destination.has("contract_cargo_tag"):
		destination.erase("contract_cargo_tag")

	if source.has("cargo_provenance_tag"):
		destination["cargo_provenance_tag"] = source.get("cargo_provenance_tag", "")
	elif destination.has("cargo_provenance_tag"):
		destination.erase("cargo_provenance_tag")

	if source.has("cargo_legality_tag"):
		destination["cargo_legality_tag"] = source.get("cargo_legality_tag", "")
	elif destination.has("cargo_legality_tag"):
		destination.erase("cargo_legality_tag")

	if source.has("contract_cargo_tag"):
		source.erase("contract_cargo_tag")
	if source.has("cargo_provenance_tag"):
		source.erase("cargo_provenance_tag")
	if source.has("cargo_legality_tag"):
		source.erase("cargo_legality_tag")

	return true


func _sync_player_cargo_mirror(agent_id: String, agent: Dictionary) -> void:
	if agent_id == "player":
		GameState.player_cargo_tag = str(agent.get("cargo_tag", "EMPTY"))


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
		var doomed_agent: Dictionary = GameState.agents.get(agent_id, {})
		_clear_runtime_contract_claims_for_agent(agent_id, doomed_agent)
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
		"rest_ticks_remaining": 0,
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
		_clear_runtime_contract_claims_for_agent(agent_id, agent)
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
		var dead_agent: Dictionary = GameState.agents[agent_id]
		_clear_runtime_contract_claims_for_agent(agent_id, dead_agent)
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
				_clear_runtime_contract_claims_for_agent(agent_id, agent)
				continue

		# Random degradation
		if _rng.randf() < Constants.AGENT_UPKEEP_CHANCE:
			if agent.get("condition_tag") == "HEALTHY":
				agent["condition_tag"] = "DAMAGED"
		if _rng.randf() < Constants.AGENT_UPKEEP_CHANCE:
			_wealth_step_down(agent)
		if agent.get("wealth_tag") == "WEALTHY" and _rng.randf() < Constants.WEALTHY_DRAIN_CHANCE:
			agent["wealth_tag"] = "COMFORTABLE"

		# Subsistence recovery: broke agents can slowly recover
		if agent.get("wealth_tag") == "BROKE":
			if true:
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
	return routing._active_agent_count_in_sector(sector_id)


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
