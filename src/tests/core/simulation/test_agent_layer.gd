#
# PROJECT: GDTLancer
# MODULE: test_agent_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 4 (Agent Layer)
# LOG_REF: 2026-02-13
#

extends GutTest

## Unit tests for AgentLayer: Agent initialization, goal evaluation, actions, respawn.

var world_layer: Reference = null
var grid_layer: Reference = null
var agent_layer: Reference = null
var bridge_systems: Reference = null
var ca_rules: Reference = null
var _config: Dictionary = {}

func before_each():
	_clear_game_state()

	var WorldLayerScript = load("res://src/core/simulation/world_layer.gd")
	var GridLayerScript = load("res://src/core/simulation/grid_layer.gd")
	var AgentLayerScript = load("res://src/core/simulation/agent_layer.gd")
	var BridgeSystemsScript = load("res://src/core/simulation/bridge_systems.gd")
	var CARulesScript = load("res://src/core/simulation/ca_rules.gd")

	world_layer = WorldLayerScript.new()
	grid_layer = GridLayerScript.new()
	agent_layer = AgentLayerScript.new()
	bridge_systems = BridgeSystemsScript.new()
	ca_rules = CARulesScript.new()
	grid_layer.ca_rules = ca_rules

	# Full init chain
	world_layer.initialize_world("agent_test_seed")
	grid_layer.initialize_grid()
	agent_layer.initialize_agents()
	world_layer.recalculate_total_matter()

	_config = {
		"influence_propagation_rate": Constants.CA_INFLUENCE_PROPAGATION_RATE,
		"pirate_activity_decay": Constants.CA_PIRATE_ACTIVITY_DECAY,
		"pirate_activity_growth": Constants.CA_PIRATE_ACTIVITY_GROWTH,
		"stockpile_diffusion_rate": Constants.CA_STOCKPILE_DIFFUSION_RATE,
		"extraction_rate_default": Constants.CA_EXTRACTION_RATE_DEFAULT,
		"price_sensitivity": Constants.CA_PRICE_SENSITIVITY,
		"demand_base": Constants.CA_DEMAND_BASE,
		"wreck_degradation_per_tick": Constants.WRECK_DEGRADATION_PER_TICK,
		"wreck_debris_return_fraction": Constants.WRECK_DEBRIS_RETURN_FRACTION,
		"entropy_radiation_multiplier": Constants.ENTROPY_RADIATION_MULTIPLIER,
		"entropy_base_rate": Constants.ENTROPY_BASE_RATE,
		"entropy_hull_multiplier": Constants.ENTROPY_HULL_MULTIPLIER,
		"heat_generation_in_space": Constants.HEAT_GENERATION_IN_SPACE,
		"heat_dissipation_base": Constants.HEAT_DISSIPATION_DOCKED,
		"heat_overheat_threshold": Constants.HEAT_OVERHEAT_THRESHOLD,
		"fleet_entropy_reduction": Constants.ENTROPY_FLEET_RATE_FRACTION,
		"propellant_drain_per_tick": Constants.PROPELLANT_DRAIN_PER_TICK,
		"energy_drain_per_tick": Constants.ENERGY_DRAIN_PER_TICK,
		"knowledge_noise_factor": Constants.AGENT_KNOWLEDGE_NOISE_FACTOR,
		"power_draw_per_agent": Constants.POWER_DRAW_PER_AGENT,
		"power_draw_per_service": Constants.POWER_DRAW_PER_SERVICE,
		"npc_cash_low_threshold": Constants.NPC_CASH_LOW_THRESHOLD,
		"npc_hull_repair_threshold": Constants.NPC_HULL_REPAIR_THRESHOLD,
		"commodity_base_price": Constants.COMMODITY_BASE_PRICE,
		"world_tick_interval_seconds": float(Constants.WORLD_TICK_INTERVAL_SECONDS),
		"respawn_timeout_seconds": Constants.RESPAWN_TIMEOUT_SECONDS,
		"hostile_growth_rate": Constants.HOSTILE_GROWTH_RATE,
		"axiom1_tolerance": Constants.AXIOM1_TOLERANCE
	}

func after_each():
	_clear_game_state()
	world_layer = null
	grid_layer = null
	agent_layer = null
	bridge_systems = null
	ca_rules = null


func _clear_game_state() -> void:
	GameState.world_topology.clear()
	GameState.world_hazards.clear()
	GameState.world_resource_potential.clear()
	GameState.world_total_matter = 0.0
	GameState.world_seed = ""
	GameState.grid_stockpiles.clear()
	GameState.grid_dominion.clear()
	GameState.grid_market.clear()
	GameState.grid_power.clear()
	GameState.grid_maintenance.clear()
	GameState.grid_wrecks.clear()
	GameState.grid_resource_availability.clear()
	GameState.agents.clear()
	GameState.characters.clear()
	GameState.inventories.clear()
	GameState.assets_ships.clear()
	GameState.hostile_population_integral.clear()
	GameState.player_character_uid = -1
	GameState.sim_tick_count = 0
	GameState.chronicle_event_buffer = []
	GameState.chronicle_rumors = []


# =============================================================================
# === TESTS ===================================================================
# =============================================================================

func test_agents_initialized():
	# Player + persistent NPCs should exist
	assert_true(GameState.agents.has("player"),
		"Player agent must exist after init.")
	assert_true(GameState.agents.size() > 1,
		"At least one NPC agent should exist. Got: %d" % GameState.agents.size())

	# Player should have a valid character UID
	assert_true(GameState.player_character_uid >= 0,
		"player_character_uid should be set. Got: %d" % GameState.player_character_uid)

	# All agents should have required state fields
	for agent_id in GameState.agents:
		var agent: Dictionary = GameState.agents[agent_id]
		assert_true(agent.has("char_uid"), "Agent %s must have char_uid." % agent_id)
		assert_true(agent.has("current_sector_id"), "Agent %s must have current_sector_id." % agent_id)
		assert_true(agent.has("hull_integrity"), "Agent %s must have hull_integrity." % agent_id)
		assert_true(agent.has("cash_reserves"), "Agent %s must have cash_reserves." % agent_id)
		assert_true(agent.has("goal_archetype"), "Agent %s must have goal_archetype." % agent_id)
		assert_true(agent.has("known_grid_state"), "Agent %s must have known_grid_state." % agent_id)

		# Sector must be a valid sector
		var sector: String = agent["current_sector_id"]
		assert_true(GameState.world_topology.has(sector),
			"Agent %s sector '%s' must exist in world_topology." % [agent_id, sector])


func test_npc_goal_evaluation():
	# Find an NPC and set their cash low
	var npc_id: String = _get_first_npc_id()
	if npc_id == "":
		pending("No NPCs found.")
		return

	var agent: Dictionary = GameState.agents[npc_id]
	agent["cash_reserves"] = 100.0  # Well below NPC_CASH_LOW_THRESHOLD (2000)
	agent["hull_integrity"] = 1.0   # Healthy hull

	agent_layer.process_tick(_config)

	# After processing, this NPC should have a "trade" goal
	var updated_agent: Dictionary = GameState.agents[npc_id]
	assert_eq(updated_agent["goal_archetype"], "trade",
		"NPC with low cash should get 'trade' goal. Got: %s" % updated_agent["goal_archetype"])


func test_npc_goal_repair_over_trade():
	# Repair should have priority over trade
	var npc_id: String = _get_first_npc_id()
	if npc_id == "":
		pending("No NPCs found.")
		return

	var agent: Dictionary = GameState.agents[npc_id]
	agent["cash_reserves"] = 100.0   # Low cash
	agent["hull_integrity"] = 0.3    # Below repair threshold (0.5)

	agent_layer.process_tick(_config)

	var updated_agent: Dictionary = GameState.agents[npc_id]
	assert_eq(updated_agent["goal_archetype"], "repair",
		"NPC with low hull should get 'repair' goal even if cash is low. Got: %s" % updated_agent["goal_archetype"])


func test_persistent_agent_respawn():
	var npc_id: String = _get_first_npc_id()
	if npc_id == "":
		pending("No NPCs found.")
		return

	var agent: Dictionary = GameState.agents[npc_id]
	var home_sector: String = agent.get("home_location_id", "")

	# Disable the agent
	agent["is_disabled"] = true
	agent["disabled_at_tick"] = 0
	GameState.sim_tick_count = 0

	# Advance ticks past the respawn timeout
	# respawn_timeout_seconds = 300, world_tick_interval = 60 → 5 ticks
	var ticks_needed: int = int(ceil(_config.get("respawn_timeout_seconds", 300.0) / _config.get("world_tick_interval_seconds", 60.0)))

	for i in range(ticks_needed + 1):
		GameState.sim_tick_count += 1
		agent_layer.process_tick(_config)

	var respawned_agent: Dictionary = GameState.agents[npc_id]
	assert_false(respawned_agent.get("is_disabled", true),
		"Agent should be respawned (not disabled) after enough ticks.")


func test_knowledge_snapshot_updated():
	var npc_id: String = _get_first_npc_id()
	if npc_id == "":
		pending("No NPCs found.")
		return

	# Run bridge systems to update knowledge (bridge does knowledge refresh)
	bridge_systems.process_tick(_config)

	var agent: Dictionary = GameState.agents[npc_id]
	var sector: String = agent.get("current_sector_id", "")
	var known_grid: Dictionary = agent.get("known_grid_state", {})

	# Agent at their current sector should have a knowledge snapshot
	assert_true(known_grid.has(sector),
		"Agent should have knowledge of their current sector '%s'." % sector)


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

func _get_first_npc_id() -> String:
	for agent_id in GameState.agents:
		if agent_id != "player":
			return agent_id
	return ""
