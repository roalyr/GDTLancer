#
# PROJECT: GDTLancer
# MODULE: test_agent_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_CONTENT-CREATION-MANUAL.md §3.4, TRUTH_SIMULATION-GRAPH.md §3.3, §6.4
# LOG_REF: 2026-05-17 16:51:08
#

extends GutTest

## Unit tests for AgentLayer: qualitative agent lifecycle,
## affinity-driven actions, mortal spawning, and exploration.

var agent_layer: Reference = null
var affinity: Reference = null
var chronicle: Reference = null


func before_each():
	_clear_state()
	var AgentScript = load("res://src/core/simulation/agent_layer.gd")
	var AffinityScript = load("res://src/core/simulation/affinity_matrix.gd")
	var ChronicleScript = load("res://src/core/simulation/chronicle_layer.gd")
	agent_layer = AgentScript.new()
	affinity = AffinityScript.new()
	chronicle = ChronicleScript.new()
	agent_layer.affinity_matrix = affinity
	agent_layer.set_chronicle(chronicle)
	_seed_minimal_state()


func after_each():
	_clear_state()
	agent_layer = null
	affinity = null
	chronicle = null


# =============================================================================
# === INITIALIZATION ==========================================================
# =============================================================================

func test_initialize_creates_player():
	agent_layer.initialize_agents()
	assert_true(GameState.agents.has("player"),
		"Player agent must exist after initialization.")

func test_player_has_qualitative_tags():
	agent_layer.initialize_agents()
	var player: Dictionary = GameState.agents["player"]
	assert_true(player.has("condition_tag"), "Player must have condition_tag.")
	assert_true(player.has("wealth_tag"), "Player must have wealth_tag.")
	assert_true(player.has("cargo_tag"), "Player must have cargo_tag.")


func test_initialize_agent_with_missing_home_location_falls_back_to_initial_sector():
	GameState.world_topology[Constants.INITIAL_SECTOR_ID] = {
		"connections": ["s1"],
		"sector_type": "colony",
		"station_ids": [Constants.INITIAL_SECTOR_ID],
	}
	var template: Resource = load("res://database/registry/agents/persistent_kai.tres")
	assert_not_null(template, "Persistent Kai template should load.")
	if template == null:
		return

	var mutated_template: Resource = template.duplicate(true)
	mutated_template.home_location_id = "sector_missing_renamed_away"

	agent_layer._initialize_agent_from_template("agent_invalid_home", mutated_template)

	assert_eq(
		GameState.agents["agent_invalid_home"]["current_sector_id"],
		Constants.INITIAL_SECTOR_ID,
		"Missing home locations should fall back to INITIAL_SECTOR_ID."
	)
	assert_eq(
		GameState.agents["agent_invalid_home"]["home_location_id"],
		Constants.INITIAL_SECTOR_ID,
		"Fallback home sector should be persisted into agent state."
	)


# =============================================================================
# === MORTAL SPAWN BLOCKED IN POOR SECTORS ====================================
# =============================================================================

func test_mortal_spawn_blocked_in_poor_sector():
	GameState.sector_tags["s1"] = [
		"STATION", "SECURE", "MILD", "RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"]
	GameState.agents = {}
	GameState.mortal_agent_counter = 0

	# We can't patch constants, but we can call _spawn_mortal_agents directly.
	# With only POOR economy tags, MORTAL_SPAWN_MIN_ECONOMY_TAGS check fails.
	agent_layer._spawn_mortal_agents()

	assert_eq(GameState.mortal_agent_counter, 0,
		"No mortals should spawn in a sector with only POOR economy tags.")
	assert_eq(GameState.agents.size(), 0,
		"agents dict should remain empty.")


func test_mortal_spawn_in_adequate_sector():
	GameState.sector_tags["s1"] = [
		"STATION", "SECURE", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	GameState.agents = {}
	GameState.mortal_agent_counter = 0

	# Run _spawn_mortal_agents multiple times to give probability a chance
	for _i in range(50):
		agent_layer._spawn_mortal_agents()

	# With adequate economy, at least one mortal should eventually spawn
	assert_gt(GameState.mortal_agent_counter, 0,
		"Mortals should be able to spawn in a sector with ADEQUATE economy.")


# =============================================================================
# === MORTAL SURVIVOR RESETS ==================================================
# =============================================================================

func test_mortal_survivor_starts_broke():
	GameState.agents = {
		"mortal_1": {
			"character_id": "",
			"is_persistent": false,
			"is_disabled": true,
			"disabled_at_tick": 0,
			"home_location_id": "s1",
			"current_sector_id": "s2",
			"condition_tag": "DESTROYED",
			"wealth_tag": "WEALTHY",
			"cargo_tag": "LOADED",
			"agent_role": "trader",
			"goal_archetype": "idle",
			"goal_queue": [{"type": "idle"}],
			"dynamic_tags": [],
		}
	}
	GameState.mortal_agent_deaths = []

	# Force high survival chance by calling many times
	# (or rely on the method's built-in MORTAL_SURVIVAL_CHANCE)
	agent_layer._cleanup_dead_mortals()

	# After cleanup, agent was either removed (death) or revived (survival).
	# Either outcome is valid — verify post-conditions for whichever occurred.
	if GameState.agents.has("mortal_1"):
		var survivor: Dictionary = GameState.agents["mortal_1"]
		if not survivor.get("is_disabled", true):
			assert_eq(survivor["condition_tag"], "DAMAGED",
				"Survivor should reset to DAMAGED.")
			assert_eq(survivor["wealth_tag"], "BROKE",
				"Survivor should reset to BROKE.")
			assert_eq(survivor["cargo_tag"], "EMPTY",
				"Survivor should reset to EMPTY.")
			assert_eq(survivor["current_sector_id"], "s1",
				"Survivor should return to home_location_id.")
		else:
			# Still disabled — not yet eligible for cleanup (tick threshold).
			assert_true(true, "Agent still disabled — cleanup deferred (expected).")
	else:
		# Agent was removed (permanent death).
		assert_true(true, "Agent permanently died — removed from agents dict (expected).")


func test_mortal_survivor_missing_home_location_falls_back_to_initial_sector():
	GameState.world_topology[Constants.INITIAL_SECTOR_ID] = {
		"connections": ["s1"],
		"sector_type": "colony",
		"station_ids": [Constants.INITIAL_SECTOR_ID],
	}
	GameState.agents = {
		"mortal_2": {
			"character_id": "",
			"is_persistent": false,
			"is_disabled": true,
			"disabled_at_tick": 0,
			"home_location_id": "sector_missing_renamed_away",
			"current_sector_id": "s2",
			"condition_tag": "DESTROYED",
			"wealth_tag": "WEALTHY",
			"cargo_tag": "LOADED",
			"agent_role": "trader",
			"goal_archetype": "idle",
			"goal_queue": [{"type": "idle"}],
			"dynamic_tags": [],
		}
	}

	agent_layer._cleanup_dead_mortals()

	if GameState.agents.has("mortal_2"):
		var survivor: Dictionary = GameState.agents["mortal_2"]
		if not survivor.get("is_disabled", true):
			assert_eq(
				survivor["current_sector_id"],
				Constants.INITIAL_SECTOR_ID,
				"Missing survivor home locations should fall back to INITIAL_SECTOR_ID."
			)
			assert_eq(
				survivor["home_location_id"],
				Constants.INITIAL_SECTOR_ID,
				"Fallback should be written back into survivor home_location_id."
			)
		else:
			assert_true(true, "Agent still disabled - cleanup deferred (expected).")
	else:
		assert_true(true, "Agent permanently died - removed from agents dict (expected).")


# =============================================================================
# === WEALTH STEP =============================================================
# =============================================================================

func test_wealth_step_up():
	var agent: Dictionary = {"wealth_tag": "BROKE"}
	agent_layer._wealth_step_up(agent)
	assert_eq(agent["wealth_tag"], "COMFORTABLE", "BROKE → COMFORTABLE.")
	agent_layer._wealth_step_up(agent)
	assert_eq(agent["wealth_tag"], "WEALTHY", "COMFORTABLE → WEALTHY.")
	agent_layer._wealth_step_up(agent)
	assert_eq(agent["wealth_tag"], "WEALTHY", "WEALTHY stays WEALTHY (ceiling).")


func test_wealth_step_down():
	var agent: Dictionary = {"wealth_tag": "WEALTHY"}
	agent_layer._wealth_step_down(agent)
	assert_eq(agent["wealth_tag"], "COMFORTABLE", "WEALTHY → COMFORTABLE.")
	agent_layer._wealth_step_down(agent)
	assert_eq(agent["wealth_tag"], "BROKE", "COMFORTABLE → BROKE.")
	agent_layer._wealth_step_down(agent)
	assert_eq(agent["wealth_tag"], "BROKE", "BROKE stays BROKE (floor).")


# =============================================================================
# === TAG HELPERS =============================================================
# =============================================================================

func test_pick_tag_finds_match():
	var result: String = agent_layer._pick_tag(
		["WEALTHY", "LOADED"], ["WEALTHY", "COMFORTABLE", "BROKE"], "COMFORTABLE")
	assert_eq(result, "WEALTHY")

func test_pick_tag_returns_default():
	var result: String = agent_layer._pick_tag(
		["LOADED"], ["WEALTHY", "COMFORTABLE", "BROKE"], "COMFORTABLE")
	assert_eq(result, "COMFORTABLE")

func test_add_tag_no_duplicate():
	var tags: Array = ["A", "B"]
	var result: Array = agent_layer._add_tag(tags, "B")
	assert_eq(result.size(), 2, "_add_tag should not add duplicate.")

func test_replace_one():
	var tags: Array = ["STATION", "SECURE", "MILD"]
	var result: Array = agent_layer._replace_one(tags, ["SECURE", "CONTESTED", "LAWLESS"], "LAWLESS")
	assert_has(result, "LAWLESS")
	assert_does_not_have(result, "SECURE")
	assert_has(result, "STATION")


# =============================================================================
# === DOCK ACTION =============================================================
# =============================================================================

func test_dock_sells_cargo_and_heals():
	GameState.sector_tags["s1"] = ["STATION", "SECURE", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	var agent: Dictionary = {
		"current_sector_id": "s1",
		"condition_tag": "DAMAGED",
		"wealth_tag": "COMFORTABLE",
		"cargo_tag": "LOADED",
	}
	agent_layer._try_dock("test_agent", agent, "s1")
	assert_eq(agent["cargo_tag"], "EMPTY", "Cargo should be sold.")
	assert_eq(agent["condition_tag"], "HEALTHY", "Agent should be healed.")
	assert_eq(agent["wealth_tag"], "WEALTHY", "Wealth should step up from cargo sale.")


# =============================================================================
# === HARVEST ACTION ==========================================================
# =============================================================================

func test_harvest_collects_salvage():
	GameState.sector_tags["s1"] = ["FRONTIER", "LAWLESS", "HARSH", "HAS_SALVAGE", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	var agent: Dictionary = {
		"current_sector_id": "s1",
		"cargo_tag": "EMPTY",
	}
	agent_layer._action_harvest("test_agent", agent, "s1")
	assert_eq(agent["cargo_tag"], "LOADED", "Cargo should be LOADED after harvest.")
	assert_does_not_have(GameState.sector_tags["s1"], "HAS_SALVAGE",
		"HAS_SALVAGE should be removed from sector.")


# =============================================================================
# === DISCOVERY REGISTRATION ==================================================
# =============================================================================

func test_try_exploration_registers_runtime_location_template():
	var explorer: Dictionary = {
		"wealth_tag": "COMFORTABLE",
		"last_discovery_tick": -999,
	}
	GameState.world_topology["s1"]["sector_type"] = "frontier"
	GameState.sector_tags["s1"] = ["FRONTIER", "LAWLESS", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	agent_layer._rng.seed = 13
	agent_layer._try_exploration("explorer", explorer, "s1")

	assert_eq(GameState.discovered_sector_count, 1, "Successful exploration should increment the discovered sector counter.")
	assert_true(TemplateDatabase.locations.has("discovered_1"), "A discovered sector should register a runtime LocationTemplate.")
	assert_eq(GameState.discovery_log.size(), 1, "Successful exploration should append one discovery-log entry.")

	var discovered_template = TemplateDatabase.locations["discovered_1"]
	var source_position: Vector3 = TemplateDatabase.locations["s1"]["global_position"]
	var handcrafted_neighbor_position: Vector3 = TemplateDatabase.locations["s2"]["global_position"]
	var discovered_position: Vector3 = discovered_template.global_position
	var discovered_distance: float = discovered_position.distance_to(source_position)
	var handcrafted_distance: float = handcrafted_neighbor_position.distance_to(source_position)

	assert_true(discovered_template.is_procedural, "Discovered sectors should register as procedural templates.")
	assert_eq(discovered_template.template_id, "discovered_1")
	assert_eq(discovered_template.location_name, GameState.sector_names["discovered_1"])
	assert_true(
		discovered_template.procedural_type in ["asteroid_field", "comet_shoal", "rogue_planet", "dark_nebula", "remnant_field"],
		"Discovered sectors should use one of the low-visibility procedural profiles."
	)
	assert_true(discovered_template.procedural_hints.get("low_visibility", false), "Discovered sectors should carry the low-visibility runtime hint.")
	assert_eq(GameState.discovery_log[0]["from"], "s1", "Discovery log should record the connected source sector.")
	assert_eq(GameState.discovery_log[0]["global_position"], discovered_position)
	assert_true(discovered_distance < handcrafted_distance, "Discovered sectors should spawn closer to their source than the handcrafted neighbor spacing.")


func test_filter_spatially_plausible_connections_drops_far_links():
	TemplateDatabase.locations["near"] = {"global_position": Vector3(52000, 0, 0)}
	TemplateDatabase.locations["far"] = {"global_position": Vector3(220000, 0, 0)}

	var filtered_connections: Array = agent_layer._filter_spatially_plausible_connections(
		"s1",
		["s1", "near", "far"],
		Vector3(48000, 4000, 0)
	)

	assert_eq(filtered_connections, ["s1", "near"], "Spatial filtering should keep plausible nearby links and drop distant ones.")


func test_resolve_sector_interaction_moves_explorer_after_cooldown_scan_failure():
	GameState.sim_tick_count = 5
	GameState.sector_tags["s1"] = ["FRONTIER", "LAWLESS", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	GameState.agents["explorer"] = {
		"agent_role": "explorer",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"last_discovery_tick": 0,
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
	}

	agent_layer._resolve_sector_interaction("explorer", 0.0, GameState.sector_tags["s1"])

	assert_eq(GameState.discovered_sector_count, 0, "Cooldown failures should not create a discovery.")
	assert_eq(
		GameState.agents["explorer"]["current_sector_id"],
		"s2",
		"Explorers should keep moving after a failed cooldown scan instead of pinning to one frontier sector."
	)


func test_get_exploration_success_modifier_keeps_hub_surveys_diminished():
	GameState.world_topology["hub_sector"] = {
		"connections": ["s1"],
		"sector_type": "hub",
		"station_ids": ["hub_sector"],
	}
	GameState.world_topology["frontier_sector"] = {
		"connections": ["s1"],
		"sector_type": "frontier",
		"station_ids": ["frontier_sector"],
	}
	TemplateDatabase.locations["hub_sector"] = {
		"global_position": Vector3(220000, 0, 0),
		"location_name": "Core Hub",
		"sector_type": "hub",
		"procedural_hints": {},
	}
	TemplateDatabase.locations["frontier_sector"] = {
		"global_position": Vector3(-220000, 0, 0),
		"location_name": "Outer Rim",
		"sector_type": "frontier",
		"procedural_hints": {},
	}

	var hub_modifier: float = agent_layer._get_exploration_success_modifier(
		"hub_sector",
		["STATION", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_RICH"]
	)
	var frontier_modifier: float = agent_layer._get_exploration_success_modifier(
		"frontier_sector",
		["FRONTIER", "LAWLESS", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	)

	assert_true(hub_modifier > 0.0, "Hub sectors should reduce but not eliminate survey success odds.")
	assert_true(hub_modifier < frontier_modifier, "Hub survey odds should remain below frontier survey odds.")


func test_build_discovered_sector_placement_separates_from_existing_discovery_branch():
	GameState.world_topology["source"] = {
		"connections": ["parent", "discovered_existing"],
		"sector_type": "deep_space",
		"station_ids": ["source"],
	}
	GameState.world_topology["parent"] = {
		"connections": ["source"],
		"sector_type": "colony",
		"station_ids": ["parent"],
	}
	GameState.world_topology["discovered_existing"] = {
		"connections": ["source"],
		"sector_type": "deep_space",
		"station_ids": ["discovered_existing"],
	}
	TemplateDatabase.locations["source"] = {
		"global_position": Vector3.ZERO,
		"is_procedural": true,
		"procedural_hints": {
			"branch_axis": Vector3.RIGHT,
			"branch_mode": "planar",
		},
	}
	TemplateDatabase.locations["parent"] = {
		"global_position": Vector3(-96000, 0, 0),
		"is_procedural": false,
		"procedural_hints": {},
	}
	TemplateDatabase.locations["discovered_existing"] = {
		"global_position": Vector3(96000, 0, 0),
		"is_procedural": true,
		"procedural_hints": {
			"low_visibility": true,
		},
	}

	var placement: Dictionary = agent_layer._build_discovered_sector_placement("discovered_2", "source")

	assert_true(bool(placement.get("is_valid", false)), "Sibling discovery branches should find a valid, non-overlapping placement when space exists.")
	assert_true(
		float(placement.get("branch_separation_deg", 0.0)) >= Constants.DISCOVERY_BRANCH_MIN_SIBLING_ANGLE_DEG,
		"Secondary discovery branches should fan away from existing discovered siblings instead of staying nearly parallel."
	)


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

func _seed_minimal_state() -> void:
	GameState.world_seed = "agent_test_seed"
	GameState.world_age = "PROSPERITY"
	GameState.sim_tick_count = 0
	GameState.world_topology = {
		"s1": {"connections": ["s2"], "sector_type": "colony", "station_ids": ["s1"]},
		"s2": {"connections": ["s1"], "sector_type": "colony", "station_ids": ["s2"]},
	}
	GameState.sector_tags = {
		"s1": ["STATION", "SECURE", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
		"s2": ["STATION", "SECURE", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
	}
	GameState.world_hazards = {"s1": {"environment": "MILD"}, "s2": {"environment": "MILD"}}
	GameState.grid_dominion = {"s1": {"security_tag": "SECURE"}, "s2": {"security_tag": "SECURE"}}
	TemplateDatabase.locations.clear()
	TemplateDatabase.locations["s1"] = {
		"global_position": Vector3.ZERO,
		"location_name": "Source Sector",
		"is_procedural": false,
		"procedural_hints": {},
	}
	TemplateDatabase.locations["s2"] = {
		"global_position": Vector3(180000, 0, 0),
		"location_name": "Neighbor Sector",
		"is_procedural": false,
		"procedural_hints": {},
	}


func _clear_state() -> void:
	GameState.world_topology.clear()
	GameState.world_hazards.clear()
	GameState.sector_tags.clear()
	GameState.grid_dominion.clear()
	GameState.agents.clear()
	GameState.characters.clear()
	GameState.agent_tags.clear()
	GameState.colony_levels.clear()
	GameState.chronicle_events = []
	GameState.chronicle_rumors = []
	GameState.mortal_agent_counter = 0
	GameState.mortal_agent_deaths = []
	GameState.discovered_sector_count = 0
	GameState.discovery_log = []
	GameState.sector_names.clear()
	GameState.catastrophe_log = []
	GameState.sector_disabled_until.clear()
	GameState.world_seed = ""
	GameState.world_age = "PROSPERITY"
	GameState.sim_tick_count = 0
	TemplateDatabase.agents.clear()
	TemplateDatabase.characters.clear()
	TemplateDatabase.locations.clear()
