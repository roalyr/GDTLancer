#
# PROJECT: GDTLancer
# MODULE: test_world_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 2 (World Layer)
# LOG_REF: 2026-02-13
#

extends GutTest

## Unit tests for WorldLayer: Static world initialization from LocationTemplate data.

var world_layer: Reference = null

func before_each():
	_clear_game_state()
	var WorldLayerScript = load("res://src/core/simulation/world_layer.gd")
	world_layer = WorldLayerScript.new()

func after_each():
	_clear_game_state()
	world_layer = null


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
	GameState.agents.clear()
	GameState.characters.clear()
	GameState.inventories.clear()
	GameState.sim_tick_count = 0


# =============================================================================
# === TESTS ===================================================================
# =============================================================================

func test_world_initialization():
	world_layer.initialize_world("test_seed_42")

	# All sectors should have topology, hazards, and resource potential
	assert_true(GameState.world_topology.size() > 0,
		"world_topology should have at least one sector.")
	assert_eq(GameState.world_topology.size(), GameState.world_hazards.size(),
		"Every sector in topology should have hazard data.")
	assert_eq(GameState.world_topology.size(), GameState.world_resource_potential.size(),
		"Every sector in topology should have resource potential.")

	# Verify structure of each entry
	for sector_id in GameState.world_topology:
		var topo: Dictionary = GameState.world_topology[sector_id]
		assert_true(topo.has("connections"), "Topology entry must have connections. Sector: %s" % sector_id)
		assert_true(topo.has("sector_type"), "Topology entry must have sector_type. Sector: %s" % sector_id)

		var haz: Dictionary = GameState.world_hazards[sector_id]
		assert_true(haz.has("radiation_level"), "Hazards entry must have radiation_level. Sector: %s" % sector_id)
		assert_true(haz.has("thermal_background_k"), "Hazards entry must have thermal_background_k. Sector: %s" % sector_id)

		var res: Dictionary = GameState.world_resource_potential[sector_id]
		assert_true(res.has("mineral_density"), "Resource potential must have mineral_density. Sector: %s" % sector_id)
		assert_true(res.has("propellant_sources"), "Resource potential must have propellant_sources. Sector: %s" % sector_id)


func test_total_matter_calculated():
	world_layer.initialize_world("test_seed_42")

	assert_true(GameState.world_total_matter > 0.0,
		"world_total_matter should be > 0 after init. Got: %f" % GameState.world_total_matter)

	# Verify it equals the sum of all resource potential
	var expected_total: float = 0.0
	for sector_id in GameState.world_resource_potential:
		var res: Dictionary = GameState.world_resource_potential[sector_id]
		expected_total += res.get("mineral_density", 0.0)
		expected_total += res.get("propellant_sources", 0.0)

	assert_almost_eq(GameState.world_total_matter, expected_total, 0.001,
		"world_total_matter should equal the sum of all resource potential.")


func test_deterministic_init():
	# Two initializations with same seed should produce identical world state
	world_layer.initialize_world("determinism_test")

	var topology_1: Dictionary = GameState.world_topology.duplicate(true)
	var hazards_1: Dictionary = GameState.world_hazards.duplicate(true)
	var resources_1: Dictionary = GameState.world_resource_potential.duplicate(true)
	var matter_1: float = GameState.world_total_matter

	# Clear and re-initialize with same seed
	_clear_game_state()
	world_layer.initialize_world("determinism_test")

	assert_eq(GameState.world_topology.size(), topology_1.size(),
		"Same seed must produce same number of sectors.")

	for sector_id in topology_1:
		assert_true(GameState.world_topology.has(sector_id),
			"Same seed must produce same sector IDs. Missing: %s" % sector_id)

		# Verify resource values match exactly
		var r1: Dictionary = resources_1[sector_id]
		var r2: Dictionary = GameState.world_resource_potential[sector_id]
		assert_almost_eq(r1["mineral_density"], r2["mineral_density"], 0.0001,
			"Mineral density must be deterministic for sector %s" % sector_id)
		assert_almost_eq(r1["propellant_sources"], r2["propellant_sources"], 0.0001,
			"Propellant sources must be deterministic for sector %s" % sector_id)

	assert_almost_eq(GameState.world_total_matter, matter_1, 0.001,
		"Total matter must be deterministic.")


func test_world_seed_stored():
	world_layer.initialize_world("my_custom_seed")
	assert_eq(GameState.world_seed, "my_custom_seed",
		"world_seed should be stored in GameState.")


func test_connections_are_bidirectional():
	world_layer.initialize_world("connectivity_test")

	for sector_id in GameState.world_topology:
		var connections: Array = GameState.world_topology[sector_id].get("connections", [])
		for conn_id in connections:
			if GameState.world_topology.has(conn_id):
				var reverse: Array = GameState.world_topology[conn_id].get("connections", [])
				assert_true(reverse.has(sector_id),
					"Connection from %s → %s must be bidirectional." % [sector_id, conn_id])
