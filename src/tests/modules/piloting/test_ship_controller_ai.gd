# Tests for ShipControllerAI: detection-limited target choice among enemies, the predator rule
# (engage, keep fighting or break off from expected gain against expected risk), grudges,
# salvaging wrecks and leaving with a full hold. The test hostile is Violet, at war with Verdant.

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
	hostile = _make_ship(Vector3.ZERO, "violet", 50.0)
	ai = AIScript.new()
	hostile.add_child(ai)


func after_each():
	TemplateDatabase.assets_commodities = _saved_commodities


# A ship with one 6-damage-per-second laser, 1.5 km signature and 200 WP of salvage.
func _make_ship(position: Vector3, faction: String, hull: float) -> RigidBody:
	var body = AgentScript.new()
	var ship = ShipTemplate.new()
	ship.signature = 1500.0
	ship.salvage_yield = {"test_scrap": 20}
	body.ship_template = ship
	add_child_autofree(body)
	body.global_transform.origin = position
	body.faction = faction
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
	var tough = _make_ship(Vector3(0, 0, -300), "verdant", 1000.0)
	var weak = _make_ship(Vector3(0, 0, -1200), "verdant", 25.0)
	_make_ship(Vector3(0, 0, -100), "violet", 10.0)  # Own side: ignored
	var unseen = _make_ship(Vector3(0, 0, -5000), "verdant", 5.0)  # Beyond its signature: undetected
	assert_eq(ai.scan_for_target(), weak, "Picks the weak ship, ignores the tough one and the unseen one.")
	weak.become_wreck()
	assert_null(ai.scan_for_target(), "Nothing left worth fighting that it can see.")
	assert_false(hostile.detects(unseen))
	assert_true(hostile.detects(tough))


func test_breaks_off_when_the_fight_turns():
	var prey = _make_ship(Vector3(0, 0, -500), "verdant", 50.0)
	ai.initialize({"patrol_center": Vector3.ZERO})
	ai._target_agent = prey
	ai._current_state = AIScript.AIState.IDLE
	ai._change_state(AIScript.AIState.COMBAT)
	ai._scan_timer = 0.0
	ai._process_combat()
	assert_eq(ai.get_state(), AIScript.AIState.COMBAT, "Even fight: keeps fighting.")
	hostile.hull = 10.0
	ai._scan_timer = 0.0
	ai._process_combat()
	assert_eq(ai.get_state(), AIScript.AIState.COMBAT, "It takes a moment to decide")
	assert_true(ai.has_pending_decision())
	ai._tick_decision(100.0)
	assert_eq(ai.get_state(), AIScript.AIState.FLEE, "then breaks off: the fight is no longer worth it.")


func test_shot_by_a_tougher_ship_it_runs_shot_by_a_weaker_one_it_turns():
	ai.initialize({"patrol_center": Vector3.ZERO})
	var tough = _make_ship(Vector3(0, 0, -800), "verdant", 1000.0)
	hostile.apply_damage(1.0, tough)
	ai._tick_decision(100.0)
	assert_eq(ai.get_state(), AIScript.AIState.FLEE)

	ai._change_state(AIScript.AIState.PATROL)
	hostile.hull = 50.0
	var sniper = _make_ship(Vector3(0, 0, -9000), "", 20.0)
	assert_false(hostile.detects(sniper), "Too far to be seen.")
	assert_false(hostile.is_enemy_of(sniper), "No war with this one")
	hostile.apply_damage(1.0, sniper)
	ai._tick_decision(100.0)
	assert_true(hostile.is_enemy_of(sniper), "until it opened fire.")
	assert_eq(ai.get_state(), AIScript.AIState.COMBAT, "Worth chasing even unseen: it knows where the shot came from.")
	ai._process_combat()
	assert_eq(ai.get_state(), AIScript.AIState.COMBAT, "Provoked: stays on the attacker without seeing it.")


func test_damage_from_nothing_alive_does_not_provoke():
	ai.initialize({"patrol_center": Vector3.ZERO})
	hostile.apply_damage(1.0, null)
	assert_eq(ai.get_state(), AIScript.AIState.PATROL)


func test_hostile_starts_patrolling_and_wreck_disables():
	ai.initialize({"patrol_center": Vector3.ZERO})
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
	var other = _make_ship(Vector3(0, 0, -2000), "verdant", 50.0)
	assert_false(hostile.detects(other), "2 km away, 1.5 km signature, sensors x1.")
	hostile.fit_stats = {"sensor_strength": 1.5, "signature": 1500.0}
	assert_true(hostile.detects(other), "Better sensors reach it.")


func test_tools_act_only_on_detected_targets():
	var other = _make_ship(Vector3(0, 0, -400), "verdant", 50.0)
	var tools = hostile.get_node("ToolController")
	assert_true(tools.can_target(tools.get_tool(0), other))
	other.global_transform.origin = Vector3(0, 0, -900)  # Still within laser reach, but
	other.ship_template.signature = 500.0  # quiet enough to be unseen
	assert_false(tools.can_target(tools.get_tool(0), other))


# --- Player parity: the same assessment, as words ---

func test_player_reads_difficulty_with_the_same_rule():
	var CombatAssessment = load("res://src/core/systems/combat_assessment.gd")
	var weak = _make_ship(Vector3(0, 0, -500), "verdant", 10.0)
	var even = _make_ship(Vector3(0, 0, -500), "verdant", 50.0)
	var tough = _make_ship(Vector3(0, 0, -500), "verdant", 1000.0)
	assert_eq(CombatAssessment.difficulty_label(CombatAssessment.advantage_between(hostile, weak)), "EASY")
	assert_eq(CombatAssessment.difficulty_label(CombatAssessment.advantage_between(hostile, even)), "EVEN")
	assert_eq(CombatAssessment.difficulty_label(CombatAssessment.advantage_between(hostile, tough)), "DEADLY")


func test_signature_meter_reads_as_a_word():
	var MainHUD = load("res://src/core/ui/main_hud/main_hud.gd")
	assert_true(MainHUD.describe_signature(hostile).ends_with("QUIET"), "At rest.")
	hostile._engine_activity = 1.0
	hostile.get_node("ToolController")._last_cycle_ms = OS.get_ticks_msec()
	assert_true(MainHUD.describe_signature(hostile).ends_with("BLAZING"), "Full burn and firing: " + MainHUD.describe_signature(hostile))


# --- Hesitation ---

func test_veterans_decide_faster_and_close_calls_take_longer():
	seed(1)
	ai.skill = 0.0
	var novice: float = ai.decision_delay(3.0, 1.0)
	ai.skill = 1.0
	var veteran: float = ai.decision_delay(3.0, 1.0)
	assert_gt(novice, veteran * 3.0, "A veteran makes up its mind much sooner.")
	var clear_total := 0.0
	var close_total := 0.0
	for _i in range(20):
		clear_total += ai.decision_delay(3.0, 1.0)
		close_total += ai.decision_delay(1.05, 1.0)
	assert_gt(close_total, clear_total * 1.5, "A coin-flip situation takes longer than an obvious one.")


func test_a_decision_is_dropped_if_the_situation_changed_meanwhile():
	ai.initialize({"patrol_center": Vector3.ZERO, "skill": 0.0})
	var prey = _make_ship(Vector3(0, 0, -500), "verdant", 20.0)
	ai._scan_timer = 0.0
	ai._process_patrol()
	assert_true(ai.has_pending_decision(), "Spots easy prey and starts deciding.")
	assert_eq(ai.get_state(), AIScript.AIState.PATROL)
	prey.hull = 1000.0  # Turns out to be much tougher before it commits
	ai._tick_decision(100.0)
	assert_eq(ai.get_state(), AIScript.AIState.PATROL, "Thinks better of it.")


# --- Factions and grudges ---

func test_neutrals_are_left_alone_until_they_shoot():
	var bystander = _make_ship(Vector3(0, 0, -300), "player", 10.0)
	assert_null(ai.scan_for_target(), "A weak neutral is not prey.")
	hostile.apply_damage(1.0, bystander)
	assert_eq(ai.scan_for_target(), bystander, "Shot by it: now it is.")
	assert_false(bystander.is_enemy_of(hostile), "The grudge is one-sided.")


func test_stray_fire_from_own_side_is_forgiven():
	var wingman = _make_ship(Vector3(0, 0, -300), "violet", 50.0)
	hostile.apply_damage(1.0, wingman)
	assert_false(hostile.is_enemy_of(wingman))


# --- Salvage and leaving ---

func test_strips_the_nearest_free_wreck_and_leaves_when_full():
	ai.initialize({"patrol_center": Vector3.ZERO, "home_point": Vector3(0, 0, 200)})
	hostile.cargo_capacity = 10
	var wreck = _make_ship(Vector3(0, 0, -200), "verdant", 50.0)
	wreck.become_wreck()
	var harpoon = UtilityToolTemplate.new()
	harpoon.tool_type = "harpoon"
	harpoon.optimal_range = 300.0
	hostile.get_node("ToolController").set_tools([hostile.get_node("ToolController").get_tool(0), harpoon])
	assert_eq(ai.scan_for_wreck(), wreck)
	ai._scan_timer = 0.0
	ai._process_patrol()
	assert_eq(ai.get_state(), AIScript.AIState.SALVAGE)
	assert_eq(ai.get_activity_label(), "SALVAGING")
	ai._process_salvage()
	assert_true(hostile.get_node("ToolController").is_active(1), "Harpoon on the wreck.")
	hostile.add_cargo("test_scrap", 10)
	ai._process_salvage()
	assert_eq(ai.get_state(), AIScript.AIState.PATROL, "Hold full: lets go")
	ai._scan_timer = 0.0
	ai._process_patrol()
	assert_eq(ai.get_state(), AIScript.AIState.DEPART, "and heads home.")
	assert_eq(ai.get_activity_label(), "HAULING")
	hostile.global_transform.origin = Vector3(0, 0, 150)
	ai._process_depart()
	yield(get_tree(), "idle_frame")
	assert_false(is_instance_valid(hostile), "Gone with the loot.")

