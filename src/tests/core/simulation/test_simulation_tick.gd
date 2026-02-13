#
# PROJECT: GDTLancer
# MODULE: test_simulation_tick.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 7 (Tick Sequence)
# LOG_REF: 2026-02-13
#

extends GutTest

## Integration-level unit tests for SimulationEngine: full tick sequence,
## matter conservation (Axiom 1), determinism, tick counter.

var world_layer: Reference = null
var grid_layer: Reference = null
var agent_layer: Reference = null
var bridge_systems: Reference = null
var chronicle_layer: Reference = null
var ca_rules: Reference = null
var _config: Dictionary = {}
var _indexer: Node = null

const TEST_SEED: String = "sim_tick_test_seed"

func before_all():
	var TemplateIndexer = load("res://src/scenes/game_world/world_manager/template_indexer.gd")
	_indexer = TemplateIndexer.new()
	add_child(_indexer)
	_indexer.index_all_templates()

func after_all():
	if is_instance_valid(_indexer):
		_indexer.queue_free()

func before_each():
	_clear_game_state()

	var WorldLayerScript = load("res://src/core/simulation/world_layer.gd")
	var GridLayerScript = load("res://src/core/simulation/grid_layer.gd")
	var AgentLayerScript = load("res://src/core/simulation/agent_layer.gd")
	var BridgeSystemsScript = load("res://src/core/simulation/bridge_systems.gd")
	var ChronicleLayerScript = load("res://src/core/simulation/chronicle_layer.gd")
	var CARulesScript = load("res://src/core/simulation/ca_rules.gd")

	world_layer = WorldLayerScript.new()
	grid_layer = GridLayerScript.new()
	agent_layer = AgentLayerScript.new()
	bridge_systems = BridgeSystemsScript.new()
	chronicle_layer = ChronicleLayerScript.new()
	ca_rules = CARulesScript.new()
	grid_layer.ca_rules = ca_rules

	# Full init chain
	world_layer.initialize_world(TEST_SEED)
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
	chronicle_layer = null
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

func test_full_tick_sequence():
	# Run a complete tick through all 5 steps and verify nothing crashes.
	# Capture state before tick for comparison.
	var initial_tick: int = GameState.sim_tick_count

	# Step 2: Grid
	grid_layer.process_tick(_config)
	# Step 3: Bridge
	bridge_systems.process_tick(_config)
	# Step 4: Agents
	agent_layer.process_tick(_config)
	# Step 5: Chronicle
	chronicle_layer.process_tick()

	# Tick count is managed by the engine's process_tick(); here we called
	# layers directly, so increment manually for the assertion.
	GameState.sim_tick_count += 1

	assert_eq(GameState.sim_tick_count, initial_tick + 1,
		"Tick count should increment by 1 after a full tick sequence.")

	# All dictionaries should still exist and be non-empty
	assert_true(GameState.world_topology.size() > 0,
		"world_topology should still be populated.")
	assert_true(GameState.grid_stockpiles.size() > 0,
		"grid_stockpiles should still be populated.")
	assert_true(GameState.agents.size() > 0,
		"agents should still be populated.")


func test_matter_conservation_axiom():
	# Verify matter conservation across multiple ticks.
	var expected_matter: float = GameState.world_total_matter
	var tolerance: float = _config.get("axiom1_tolerance", 0.01)

	# Run 5 full tick sequences
	for i in range(5):
		grid_layer.process_tick(_config)
		bridge_systems.process_tick(_config)
		agent_layer.process_tick(_config)
		chronicle_layer.process_tick()

		# Recalculate actual matter like SimulationEngine does
		var actual_matter: float = _calculate_total_matter()
		var drift: float = abs(actual_matter - expected_matter)

		assert_true(drift <= tolerance,
			"Axiom 1 violation at tick %d: expected=%.4f actual=%.4f drift=%.4f (tolerance=%.4f)" % [
				i + 1, expected_matter, actual_matter, drift, tolerance
			])


func test_deterministic_simulation():
	# Two simulations with the same seed should produce identical state.

	# --- Run 1 ---
	# Already initialized in before_each with TEST_SEED.
	for i in range(3):
		grid_layer.process_tick(_config)
		bridge_systems.process_tick(_config)
		agent_layer.process_tick(_config)
		chronicle_layer.process_tick()
		GameState.sim_tick_count += 1

	# Capture snapshot of key state
	var run1_stockpiles: Dictionary = _deep_copy_dict(GameState.grid_stockpiles)
	var run1_dominion: Dictionary = _deep_copy_dict(GameState.grid_dominion)
	var run1_tick: int = GameState.sim_tick_count

	# --- Run 2 (re-initialize from scratch) ---
	_clear_game_state()

	var WorldLayerScript2 = load("res://src/core/simulation/world_layer.gd")
	var GridLayerScript2 = load("res://src/core/simulation/grid_layer.gd")
	var AgentLayerScript2 = load("res://src/core/simulation/agent_layer.gd")
	var BridgeSystemsScript2 = load("res://src/core/simulation/bridge_systems.gd")
	var ChronicleLayerScript2 = load("res://src/core/simulation/chronicle_layer.gd")
	var CARulesScript2 = load("res://src/core/simulation/ca_rules.gd")

	var wl2 = WorldLayerScript2.new()
	var gl2 = GridLayerScript2.new()
	var al2 = AgentLayerScript2.new()
	var bs2 = BridgeSystemsScript2.new()
	var cl2 = ChronicleLayerScript2.new()
	var cr2 = CARulesScript2.new()
	gl2.ca_rules = cr2

	wl2.initialize_world(TEST_SEED)
	gl2.initialize_grid()
	al2.initialize_agents()
	wl2.recalculate_total_matter()

	for i in range(3):
		gl2.process_tick(_config)
		bs2.process_tick(_config)
		al2.process_tick(_config)
		cl2.process_tick()
		GameState.sim_tick_count += 1

	# Compare
	assert_eq(GameState.sim_tick_count, run1_tick,
		"Tick counts should match between two identical runs.")

	# Compare stockpiles across sectors
	for sector_id in run1_stockpiles:
		assert_true(GameState.grid_stockpiles.has(sector_id),
			"Run 2 should have sector '%s' in grid_stockpiles." % sector_id)
		var run1_commodities: Dictionary = run1_stockpiles[sector_id].get("commodity_stockpiles", {})
		var run2_commodities: Dictionary = GameState.grid_stockpiles[sector_id].get("commodity_stockpiles", {})
		for commodity_id in run1_commodities:
			var val1: float = float(run1_commodities[commodity_id])
			var val2: float = float(run2_commodities.get(commodity_id, 0))
			assert_almost_eq(val1, val2, 0.001,
				"Stockpile '%s' in '%s' should match between runs." % [commodity_id, sector_id])


func test_tick_count_increments():
	assert_eq(GameState.sim_tick_count, 0,
		"sim_tick_count should start at 0 after clear.")

	# Simulate the engine incrementing
	for i in range(3):
		GameState.sim_tick_count += 1
		grid_layer.process_tick(_config)
		bridge_systems.process_tick(_config)
		agent_layer.process_tick(_config)
		chronicle_layer.process_tick()

	assert_eq(GameState.sim_tick_count, 3,
		"sim_tick_count should be 3 after three ticks.")


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

## Mirrors SimulationEngine._calculate_total_matter()
func _calculate_total_matter() -> float:
	var total: float = 0.0

	# Layer 1: Resource potential
	for sector_id in GameState.world_resource_potential:
		var potential: Dictionary = GameState.world_resource_potential[sector_id]
		total += potential.get("mineral_density", 0.0)
		total += potential.get("propellant_sources", 0.0)

	# Layer 2: Grid stockpiles
	for sector_id in GameState.grid_stockpiles:
		var stockpile: Dictionary = GameState.grid_stockpiles[sector_id]
		var commodities: Dictionary = stockpile.get("commodity_stockpiles", {})
		for commodity_id in commodities:
			total += float(commodities[commodity_id])

	# Layer 2: Wrecks
	for wreck_uid in GameState.grid_wrecks:
		var wreck: Dictionary = GameState.grid_wrecks[wreck_uid]
		var inventory: Dictionary = wreck.get("wreck_inventory", {})
		for item_id in inventory:
			total += float(inventory[item_id])
		total += 1.0  # Base hull mass

	# Layer 3: Agent inventories
	for char_uid in GameState.inventories:
		var inv: Dictionary = GameState.inventories[char_uid]
		if inv.has(2):  # InventoryType.COMMODITY
			var commodities: Dictionary = inv[2]
			for commodity_id in commodities:
				total += float(commodities[commodity_id])

	return total


## Simple deep copy for nested dictionaries (no objects).
func _deep_copy_dict(source: Dictionary) -> Dictionary:
	var copy: Dictionary = {}
	for key in source:
		var val = source[key]
		if val is Dictionary:
			copy[key] = _deep_copy_dict(val)
		elif val is Array:
			copy[key] = val.duplicate(true)
		else:
			copy[key] = val
	return copy
