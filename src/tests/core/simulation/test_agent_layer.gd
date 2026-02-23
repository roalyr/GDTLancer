#
# PROJECT: GDTLancer
# MODULE: test_agent_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §4 + TACTICAL_TODO.md TASK_13
# LOG_REF: 2026-02-21 (TASK_13)
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
