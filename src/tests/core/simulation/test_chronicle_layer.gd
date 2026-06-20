# PROJECT: GDTLancer
# MODULE: test_chronicle_layer.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: test_chronicle_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TACTICAL_TODO.md TASK_1; TRUTH_SIMULATION-GRAPH.md §5, §6.4
# LOG_REF: 2026-05-24 00:00:03
#

extends GutTest

## Unit tests for ChronicleLayer: event logging, rumor generation, distribution.

var chronicle: Reference = null


func before_each():
	_clear_state()
	var Script = load("res://src/core/simulation/chronicle_layer.gd")
	chronicle = Script.new()


func after_each():
	_clear_state()
	chronicle = null


# =============================================================================
# === TESTS ===================================================================
# =============================================================================

func test_log_event_stages_event():
	chronicle.log_event({
		"tick": 1,
		"actor_id": "agent_vera",
		"action": "attack",
		"sector_id": "sector_star_elace",
		"metadata": {"target": "agent_ada"},
	})
	# Event should be staged but not yet in GameState until process_tick
	chronicle.process_tick()
	assert_gt(GameState.chronicle_events.size(), 0,
		"chronicle_events should contain the logged event after process_tick.")


func test_process_tick_generates_rumors():
	# Setup: need topology for distribution
	GameState.world_topology["sector_star_elace"] = {
		"connections": ["station_beta"],
		"development_level": "colony",
	}
	GameState.world_topology["station_beta"] = {
		"connections": ["sector_star_elace"],
		"development_level": "colony",
	}
	GameState.agents["agent_vera"] = {
		"current_sector_id": "sector_star_elace",
		"is_disabled": false,
	}

	chronicle.log_event({
		"tick": 1,
		"actor_id": "agent_vera",
		"action": "dock",
		"sector_id": "sector_star_elace",
		"metadata": {},
	})
	chronicle.process_tick()

	assert_gt(GameState.chronicle_rumors.size(), 0,
		"At least one rumor should be generated from a dock event.")


func test_event_has_required_fields():
	chronicle.log_event({
		"tick": 5,
		"actor_id": "player",
		"action": "move",
		"sector_id": "station_gamma",
		"metadata": {"from": "station_delta"},
	})
	chronicle.process_tick()

	var ev: Dictionary = GameState.chronicle_events[0]
	assert_true(ev.has("tick"), "Event must have tick.")
	assert_true(ev.has("actor_id"), "Event must have actor_id.")
	assert_true(ev.has("action"), "Event must have action.")
	assert_true(ev.has("sector_id"), "Event must have sector_id.")
	assert_true(ev.has("metadata"), "Event must retain metadata as a Dictionary.")


func test_log_event_deep_copies_nested_metadata():
	var metadata := {
		"target": "agent_ada",
		"connections": ["sector_star_elace"],
	}
	chronicle.log_event({
		"tick": 2,
		"actor_id": "agent_vera",
		"action": "contract_completed",
		"sector_id": "sector_star_elace",
		"metadata": metadata,
	})
	metadata["target"] = "agent_mutated"
	metadata["connections"].append("sector_star_cob")

	chronicle.process_tick()

	var event: Dictionary = GameState.chronicle_events[0]
	var stored_meta: Dictionary = event.get("metadata", {})
	assert_eq(stored_meta.get("target", ""), "agent_ada",
		"ChronicleLayer should deep-copy metadata so later mutations do not corrupt stored events.")
	assert_eq(Array(stored_meta.get("connections", [])).size(), 1,
		"Nested metadata arrays should also be deep-copied.")


func test_contract_action_rumor_uses_humanized_text():
	chronicle.log_event({
		"tick": 3,
		"actor_id": "hauler_1",
		"action": "contract_completed",
		"sector_id": "sector_star_elace",
		"metadata": {},
	})

	chronicle.process_tick()

	assert_true(str(GameState.chronicle_rumors[0]).find("completed a relief delivery") != -1,
		"Chronicle rumors should humanize the new runtime contract actions.")


func test_buffer_capped_at_limit():
	for i in range(Constants.EVENT_BUFFER_CAP + 50):
		chronicle.log_event({
			"tick": i,
			"actor_id": "system",
			"action": "test",
			"sector_id": "s1",
			"metadata": {},
		})
	chronicle.process_tick()

	assert_true(GameState.chronicle_events.size() <= Constants.EVENT_BUFFER_CAP,
		"chronicle_events should not exceed EVENT_BUFFER_CAP.")


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

func _clear_state() -> void:
	GameState.chronicle_events = []
	GameState.chronicle_rumors = []
	GameState.world_topology.clear()
	GameState.agents.clear()