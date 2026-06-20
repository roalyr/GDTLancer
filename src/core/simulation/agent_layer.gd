# PROJECT: GDTLancer
# MODULE: agent_layer.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: GDD-REVISION-LEDGER.md REV_007; GDD-REVISION-LEDGER.md REV_008; TRUTH_SIMULATION-GRAPH.md §2.2.1; TRUTH_PROJECT.md § Agent Parity Principle
# LOG_REF: 2026-06-20 20:31:00

extends Reference

const LocationTemplateScript = preload("res://database/definitions/location_template.gd")

const AgentRoutingScript = preload("res://src/core/simulation/agent_layer/agent_routing.gd")
const AgentExplorerScript = preload("res://src/core/simulation/agent_layer/agent_explorer.gd")
const AgentMarketScript = preload("res://src/core/simulation/agent_layer/agent_market.gd")
const AgentContractScript = preload("res://src/core/simulation/agent_layer/agent_contract.gd")
const AgentSubAgentsScript = preload("res://src/core/simulation/agent_layer/agent_sub_agents.gd")
const AgentBehaviorScript = preload("res://src/core/simulation/agent_layer/agent_behavior.gd")

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


## Sub-components
var routing: Reference
var explorer: Reference
var market: Reference
var contracts: Reference
var sub_agents: Reference
var behavior: Reference

func _init() -> void:
	routing = AgentRoutingScript.new()
	explorer = AgentExplorerScript.new()
	market = AgentMarketScript.new()
	contracts = AgentContractScript.new()
	sub_agents = AgentSubAgentsScript.new()
	behavior = AgentBehaviorScript.new()
	routing.initialize(self)
	explorer.initialize(self)
	market.initialize(self)
	contracts.initialize(self)
	sub_agents.initialize(self)
	behavior.initialize(self)


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


## Returns the quantitative health modifier of an agent based on its condition_tag.
func get_health_modifier(agent_uid: String) -> int:
	if not GameState.agents.has(agent_uid):
		return 0
	var agent: Dictionary = GameState.agents[agent_uid]
	var tag: String = agent.get("condition_tag", "HEALTHY")
	if Constants.CONDITION_MODIFIERS.has(tag):
		return Constants.CONDITION_MODIFIERS[tag]
	return 0


## Transfers a sub-agent from one host to another, applying a morale penalty.
func sub_agent_transfer(sub_agent_id: String, from_host_id: String, to_host_id: String) -> bool:
	return sub_agents.sub_agent_transfer(sub_agent_id, from_host_id, to_host_id)


func _update_supplies_and_morale(agent_id: String, agent: Dictionary) -> void:
	sub_agents.process_agent_supplies_and_morale(agent_id, agent)


## Exposes the aggregate crew morale modifier.
func get_crew_morale_modifier(agent_id: String) -> int:
	return sub_agents.get_crew_morale_modifier(agent_id)


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

		_update_supplies_and_morale(agent_id, agent)

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
		"sub_agents": {},
		"supplies_tag": "SUPPLIES_ADEQUATE",
		"supplies_ticks_remaining": Constants.SUPPLIES_DEGRADATION_TICKS,
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
		"sub_agents": {},
		"supplies_tag": "SUPPLIES_ADEQUATE",
		"supplies_ticks_remaining": Constants.SUPPLIES_DEGRADATION_TICKS,
	}


# =============================================================================
# === PRIVATE — GOAL EVALUATION ===============================================
# =============================================================================

func _evaluate_goals(agent: Dictionary, agent_id: String = "") -> void:
	behavior._evaluate_goals(agent, agent_id)


func _execute_action(agent_id: String, agent: Dictionary) -> void:
	behavior._execute_action(agent_id, agent)


func _consume_mandatory_npc_rest_tick(agent_id: String, agent: Dictionary) -> bool:
	return behavior._consume_mandatory_npc_rest_tick(agent_id, agent)


func _schedule_npc_rest_after_action(agent_id: String, agent: Dictionary, goal: String) -> void:
	behavior._schedule_npc_rest_after_action(agent_id, agent, goal)


func _should_skip_mandatory_npc_rest(agent_id: String, agent: Dictionary) -> bool:
	return behavior._should_skip_mandatory_npc_rest(agent_id, agent)


func _has_active_runtime_contract_claim(agent_id: String) -> bool:
	return behavior._has_active_runtime_contract_claim(agent_id)


func _mandatory_rest_ticks_for_agent(agent: Dictionary) -> int:
	return behavior._mandatory_rest_ticks_for_agent(agent)


func _action_flee_to_safety(agent_id: String, agent: Dictionary) -> void:
	behavior._action_flee_to_safety(agent_id, agent)


func _action_affinity_scan(agent_id: String, agent: Dictionary) -> void:
	behavior._action_affinity_scan(agent_id, agent)


func _resolve_agent_interaction(actor_id: String, target_id: String, score: float) -> bool:
	return behavior._resolve_agent_interaction(actor_id, target_id, score)


func _resolve_sector_interaction(agent_id: String, score: float, sector_tags: Array) -> void:
	behavior._resolve_sector_interaction(agent_id, score, sector_tags)


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
	behavior._try_dock(agent_id, agent, sector_id)


func _action_harvest(agent_id: String, agent: Dictionary, sector_id: String) -> void:
	behavior._action_harvest(agent_id, agent, sector_id)


func _try_load_cargo(agent_id: String, agent: Dictionary, sector_id: String) -> bool:
	return behavior._try_load_cargo(agent_id, agent, sector_id)


func _location_offers_service(location_id: String, service_id: String) -> bool:
	return behavior._location_offers_service(location_id, service_id)


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

func _graph_degree(sector_id: String) -> int:
	return routing._graph_degree(sector_id)


func _sort_by_degree(a: String, b: String) -> bool:
	return routing._sort_by_degree(a, b)


# =============================================================================
# === PRIVATE — TARGET SELECTION ==============================================
# =============================================================================

func _best_agent_target(actor_id: String, actor_tags: Array, sector_id: String, can_attack: bool) -> Array:
	return behavior._best_agent_target(actor_id, actor_tags, sector_id, can_attack)


func _is_combat_cooldown_active(agent: Dictionary) -> bool:
	return behavior._is_combat_cooldown_active(agent)


func _bilateral_trade(actor: Dictionary, target: Dictionary) -> void:
	behavior._bilateral_trade(actor, target)


func _can_agents_escalate_to_disruption(actor: Dictionary, target: Dictionary, actor_tags: Array, target_tags: Array) -> bool:
	return behavior._can_agents_escalate_to_disruption(actor, target, actor_tags, target_tags)


func _apply_non_lethal_disruption(
		actor_id: String,
		actor: Dictionary,
		target_id: String,
		target: Dictionary,
		actor_tags: Array,
		target_tags: Array
	) -> bool:
	return behavior._apply_non_lethal_disruption(actor_id, actor, target_id, target, actor_tags, target_tags)


func _can_actor_seize_cargo(actor: Dictionary, target: Dictionary, actor_tags: Array, target_tags: Array) -> bool:
	return behavior._can_actor_seize_cargo(actor, target, actor_tags, target_tags)


func _can_agents_trade(actor: Dictionary, target: Dictionary, actor_tags: Array, target_tags: Array) -> bool:
	return behavior._can_agents_trade(actor, target, actor_tags, target_tags)


func _is_commerce_role(role: String) -> bool:
	return behavior._is_commerce_role(role)


func _trade_legality_blocks_exchange(actor_legality_tag: String, target_legality_tag: String) -> bool:
	return behavior._trade_legality_blocks_exchange(actor_legality_tag, target_legality_tag)


func _has_protected_contract_cargo(agent: Dictionary, tags: Array) -> bool:
	return behavior._has_protected_contract_cargo(agent, tags)


func _share_aligned_faction(actor_tags: Array, target_tags: Array) -> bool:
	return behavior._share_aligned_faction(actor_tags, target_tags)


func _get_character_uid(agent: Dictionary) -> int:
	return behavior._get_character_uid(agent)


func _resolve_payment_instrument(payer_tags: Array, payee_tags: Array) -> String:
	return behavior._resolve_payment_instrument(payer_tags, payee_tags)


func _agent_legality_tag(tags: Array) -> String:
	return behavior._agent_legality_tag(tags)


func _tag_with_prefix(tags: Array, prefix: String) -> String:
	return behavior._tag_with_prefix(tags, prefix)


func _transfer_cargo_between_agents(source: Dictionary, destination: Dictionary) -> bool:
	return behavior._transfer_cargo_between_agents(source, destination)


func _sync_player_cargo_mirror(agent_id: String, agent: Dictionary) -> void:
	behavior._sync_player_cargo_mirror(agent_id, agent)


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
		"sub_agents": {},
		"supplies_tag": "SUPPLIES_ADEQUATE",
		"supplies_ticks_remaining": Constants.SUPPLIES_DEGRADATION_TICKS,
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


func _get_template_value(template, key: String, default_value = null):
	if template == null:
		return default_value
	if template is Dictionary:
		return template.get(key, default_value)
	var value = template.get(key)
	return value if value != null else default_value
