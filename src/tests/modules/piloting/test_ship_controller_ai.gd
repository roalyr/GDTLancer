# Tests for ShipControllerAI: detection-limited target choice and the predator rule (engage, keep
# fighting or break off from expected gain against expected risk).

extends GutTest

const AgentScript = preload("res://src/core/agents/agent.gd")
const AIScript = preload("res://src/modules/piloting/ship_controller_ai.gd")
const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")

var hostile: RigidBody = null
var ai: Node = null
var _saved_commodities: Dictionary = {}


func before_each():
	_saved_commodities = TemplateDatabase.assets_commodities
	var scrap = CommodityTemplate.new()
	scrap.base_value = 10
	TemplateDatabase.assets_commodities = {"test_scrap": scrap}
	hostile = _make_ship(Vector3.ZERO, true, 50.0)
	ai = AIScript.new()
	hostile.add_child(ai)


func after_each():
	TemplateDatabase.assets_commodities = _saved_commodities


# A ship with one 6-damage-per-second laser, 1.5 km signature and 200 WP of salvage.
func _make_ship(position: Vector3, is_hostile: bool, hull: float) -> RigidBody:
	var body = AgentScript.new()
	var ship = ShipTemplate.new()
	ship.signature = 1500.0
	ship.salvage_yield = {"test_scrap": 20}
	body.ship_template = ship
	add_child_autofree(body)
	body.global_transform.origin = position
	body.is_hostile = is_hostile
	body.hull_max = hull
	body.hull = hull
	var laser = UtilityToolTemplate.new()
	laser.damage = 6.0
	laser.cycle_time = 1.0
	var tools = ToolControllerScript.new()
	tools.name = "ToolController"
	body.add_child(tools)
	tools.set_tools([laser])
	return body


func test_desire_weighs_advantage_by_gain():
	assert_almost_eq(AIScript.compute_desire(50, 6, 50, 6, Constants.AI_GAIN_REFERENCE), 1.0, 0.001, "An even fight for a reference prize is just worth it.")
	assert_lt(AIScript.compute_desire(50, 6, 1000, 6, Constants.AI_GAIN_REFERENCE), Constants.AI_DISENGAGE_DESIRE, "A much tougher target is not.")
	assert_gt(AIScript.compute_desire(50, 6, 25, 6, Constants.AI_GAIN_REFERENCE), 1.5, "A weaker one is.")
	assert_eq(AIScript.compute_desire(50, 0, 25, 6, 1000), 0.0, "No weapons, no fight.")
	assert_gt(AIScript.compute_desire(50, 6, 50, 6, Constants.AI_GAIN_REFERENCE * 3), AIScript.compute_desire(50, 6, 50, 6, Constants.AI_GAIN_REFERENCE), "A richer prize is worth more risk.")


func test_scan_picks_the_most_desirable_detected_target():
	var tough = _make_ship(Vector3(0, 0, -300), false, 1000.0)
	var weak = _make_ship(Vector3(0, 0, -1200), false, 25.0)
	_make_ship(Vector3(0, 0, -100), true, 10.0)  # Fellow hostile: ignored
	var unseen = _make_ship(Vector3(0, 0, -5000), false, 5.0)  # Beyond its signature: undetected
	assert_eq(ai.scan_for_target(), weak, "Picks the weak ship, ignores the tough one and the unseen one.")
	weak.become_wreck()
	assert_null(ai.scan_for_target(), "Nothing left worth fighting that it can see.")
	assert_false(hostile.detects(unseen))
	assert_true(hostile.detects(tough))


func test_breaks_off_when_the_fight_turns():
	var prey = _make_ship(Vector3(0, 0, -500), false, 50.0)
	ai.initialize({"hostile": true, "patrol_center": Vector3.ZERO})
	ai._target_agent = prey
	ai._current_state = AIScript.AIState.IDLE
	ai._change_state(AIScript.AIState.COMBAT)
	ai._scan_timer = 0.0
	ai._process_combat()
	assert_eq(ai.get_state(), AIScript.AIState.COMBAT, "Even fight: keeps fighting.")
	hostile.hull = 10.0
	ai._scan_timer = 0.0
	ai._process_combat()
	assert_eq(ai.get_state(), AIScript.AIState.FLEE, "Badly hurt: the fight is no longer worth it.")


func test_shot_by_a_tougher_ship_it_runs_shot_by_a_weaker_one_it_turns():
	ai.initialize({"hostile": true, "patrol_center": Vector3.ZERO})
	var tough = _make_ship(Vector3(0, 0, -800), false, 1000.0)
	hostile.apply_damage(1.0, tough)
	assert_eq(ai.get_state(), AIScript.AIState.FLEE)

	ai._change_state(AIScript.AIState.PATROL)
	hostile.hull = 50.0
	var sniper = _make_ship(Vector3(0, 0, -9000), false, 20.0)
	assert_false(hostile.detects(sniper), "Too far to be seen.")
	hostile.apply_damage(1.0, sniper)
	assert_eq(ai.get_state(), AIScript.AIState.COMBAT, "Worth chasing even unseen: it knows where the shot came from.")
	ai._process_combat()
	assert_eq(ai.get_state(), AIScript.AIState.COMBAT, "Provoked: stays on the attacker without seeing it.")


func test_damage_from_nothing_alive_does_not_provoke():
	ai.initialize({"hostile": true, "patrol_center": Vector3.ZERO})
	hostile.apply_damage(1.0, null)
	assert_eq(ai.get_state(), AIScript.AIState.PATROL)


func test_hostile_starts_patrolling_and_wreck_disables():
	ai.initialize({"hostile": true, "patrol_center": Vector3.ZERO})
	assert_eq(ai.get_state(), AIScript.AIState.PATROL)
	hostile.become_wreck()
	assert_eq(ai.get_state(), AIScript.AIState.DISABLED)


# --- Signature ---

func test_signature_grows_with_engines_firing_and_leaks_and_shrinks_as_a_wreck():
	var quiet: float = hostile.get_signature()
	assert_eq(quiet, 1500.0, "At rest: the hull's base.")
	hostile._engine_activity = 1.0
	assert_almost_eq(hostile.get_signature(), quiet + Constants.SIG_ENGINE_FULL, 0.01)
	hostile._engine_activity = 0.0
	hostile.get_node("ToolController")._last_cycle_ms = OS.get_ticks_msec()
	assert_almost_eq(hostile.get_signature(), quiet + Constants.SIG_TOOL_FIRING, 50.0, "Just fired.")
	hostile.get_node("ToolController")._last_cycle_ms = -1000000
	hostile.become_wreck()
	assert_almost_eq(hostile.get_signature(), quiet * Constants.SIG_WRECK_FACTOR, 0.01)


func test_detection_is_signature_times_sensor_strength():
	var other = _make_ship(Vector3(0, 0, -2000), false, 50.0)
	assert_false(hostile.detects(other), "2 km away, 1.5 km signature, sensors x1.")
	hostile.fit_stats = {"sensor_strength": 1.5, "signature": 1500.0}
	assert_true(hostile.detects(other), "Better sensors reach it.")


func test_tools_act_only_on_detected_targets():
	var other = _make_ship(Vector3(0, 0, -400), false, 50.0)
	var tools = hostile.get_node("ToolController")
	assert_true(tools.can_target(tools.get_tool(0), other))
	other.global_transform.origin = Vector3(0, 0, -900)  # Still within laser reach, but
	other.ship_template.signature = 500.0  # quiet enough to be unseen
	assert_false(tools.can_target(tools.get_tool(0), other))
