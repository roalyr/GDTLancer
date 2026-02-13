#
# PROJECT: GDTLancer
# MODULE: test_grid_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 3 (Grid Layer)
# LOG_REF: 2026-02-13
#

extends GutTest

## Unit tests for GridLayer: Dynamic grid state and CA processing.

var world_layer: Reference = null
var grid_layer: Reference = null
var ca_rules: Reference = null
var _config: Dictionary = {}

func before_each():
	_clear_game_state()

	var WorldLayerScript = load("res://src/core/simulation/world_layer.gd")
	var GridLayerScript = load("res://src/core/simulation/grid_layer.gd")
	var CARulesScript = load("res://src/core/simulation/ca_rules.gd")

	world_layer = WorldLayerScript.new()
	grid_layer = GridLayerScript.new()
	ca_rules = CARulesScript.new()
	grid_layer.ca_rules = ca_rules

	# Initialize world first (grid depends on it)
	world_layer.initialize_world("grid_test_seed")

	# Build a standard config
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
		"power_draw_per_agent": Constants.POWER_DRAW_PER_AGENT,
		"power_draw_per_service": Constants.POWER_DRAW_PER_SERVICE,
		"axiom1_tolerance": Constants.AXIOM1_TOLERANCE
	}

func after_each():
	_clear_game_state()
	world_layer = null
	grid_layer = null
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
	GameState.sim_tick_count = 0


# =============================================================================
# === TESTS ===================================================================
# =============================================================================

func test_grid_initialization():
	grid_layer.initialize_grid()

	# Every sector should have grid state
	for sector_id in GameState.world_topology:
		assert_true(GameState.grid_stockpiles.has(sector_id),
			"Sector %s should have stockpiles after init." % sector_id)
		assert_true(GameState.grid_dominion.has(sector_id),
			"Sector %s should have dominion after init." % sector_id)
		assert_true(GameState.grid_market.has(sector_id),
			"Sector %s should have market after init." % sector_id)
		assert_true(GameState.grid_power.has(sector_id),
			"Sector %s should have power after init." % sector_id)
		assert_true(GameState.grid_maintenance.has(sector_id),
			"Sector %s should have maintenance after init." % sector_id)

	# Stockpiles should have commodity_stockpiles dict
	for sector_id in GameState.grid_stockpiles:
		var stk: Dictionary = GameState.grid_stockpiles[sector_id]
		assert_true(stk.has("commodity_stockpiles"),
			"Stockpiles must have commodity_stockpiles key. Sector: %s" % sector_id)
		assert_true(stk.has("stockpile_capacity"),
			"Stockpiles must have stockpile_capacity key. Sector: %s" % sector_id)


func test_extraction_depletes_potential():
	grid_layer.initialize_grid()
	world_layer.recalculate_total_matter()

	# Snapshot mineral density before tick
	var first_sector: String = GameState.world_topology.keys()[0]
	var mineral_before: float = GameState.world_resource_potential[first_sector].get("mineral_density", 0.0)

	# Run one tick
	grid_layer.process_tick(_config)

	var mineral_after: float = GameState.world_resource_potential[first_sector].get("mineral_density", 0.0)

	if mineral_before > 0.0:
		assert_true(mineral_after < mineral_before,
			"Mineral density should decrease after extraction. Before: %f, After: %f" % [mineral_before, mineral_after])
	else:
		# If no minerals, density should remain 0
		assert_almost_eq(mineral_after, 0.0, 0.001,
			"Zero-mineral sectors should stay at 0.")


func test_stockpile_increases_from_extraction():
	grid_layer.initialize_grid()
	world_layer.recalculate_total_matter()

	# Find a sector with mineral deposits
	var target_sector: String = ""
	for sector_id in GameState.world_resource_potential:
		if GameState.world_resource_potential[sector_id].get("mineral_density", 0.0) > 0.0:
			target_sector = sector_id
			break

	if target_sector == "":
		# No minerals to extract — skip
		pending("No sectors with mineral_density > 0 found.")
		return

	var ore_before: float = GameState.grid_stockpiles[target_sector].get("commodity_stockpiles", {}).get("ore", 0.0)

	grid_layer.process_tick(_config)

	var ore_after: float = GameState.grid_stockpiles[target_sector].get("commodity_stockpiles", {}).get("ore", 0.0)
	assert_true(ore_after > ore_before,
		"Ore stockpile should increase from extraction. Before: %f, After: %f" % [ore_before, ore_after])


func test_price_reacts_to_supply():
	grid_layer.initialize_grid()
	world_layer.recalculate_total_matter()

	# Run one tick to generate initial market data
	grid_layer.process_tick(_config)

	var first_sector: String = GameState.world_topology.keys()[0]
	var market_data: Dictionary = GameState.grid_market.get(first_sector, {})

	# Market should have price deltas after processing
	assert_true(market_data.has("commodity_price_deltas"),
		"Market should have commodity_price_deltas after tick.")

	# Manually spike a stockpile and process again to see price react
	var stk: Dictionary = GameState.grid_stockpiles.get(first_sector, {})
	var commodities: Dictionary = stk.get("commodity_stockpiles", {})
	if commodities.has("ore"):
		var price_before: float = market_data.get("commodity_price_deltas", {}).get("ore", 0.0)

		# Flood the sector with ore
		commodities["ore"] = 900.0
		stk["commodity_stockpiles"] = commodities
		GameState.grid_stockpiles[first_sector] = stk

		grid_layer.process_tick(_config)

		var new_market: Dictionary = GameState.grid_market.get(first_sector, {})
		var price_after: float = new_market.get("commodity_price_deltas", {}).get("ore", 0.0)

		assert_true(price_after < price_before,
			"Price delta should decrease (go more negative) with high supply. Before: %f, After: %f" % [price_before, price_after])
