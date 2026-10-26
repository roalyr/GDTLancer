# Tests for ShipControllerAI: detection-limited target choice among enemies, the predator rule
# (engage, keep fighting or break off from expected gain against expected risk), grudges,
# salvaging wrecks and leaving with a full hold. The test hostile is Violet, at war with Verdant.

extends GutTest

const CombatAssessment = preload("res://src/core/systems/combat_assessment.gd")

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
	body.wallet = 1e6  # Comfortable: not desperate
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
	var tough = _make_ship(Vector3(0, 0, -300), "raiders", 1000.0)  # Not the weak one's side: judged alone
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
	hostile.power_max = 100.0
	hostile.power = 100.0
	ai._scan_timer = 0.0
	ai._process_combat()
	assert_eq(ai.get_state(), AIScript.AIState.HESITATE, "It takes a moment to decide")
	assert_eq(ai.get_activity_label(), "HESITATING", "and the player can read that")
	assert_true(ai.has_pending_decision())
	ai._process_hesitate()
	assert_true(hostile.get_node("ToolController").is_active(0), "while still fighting")
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


func test_fleeing_it_shoots_back_at_its_pursuer():
	var tough = _make_ship(Vector3(0, 0, -300), "verdant", 1000.0)
	hostile.power_max = 100.0
	hostile.power = 100.0
	ai.initialize({"patrol_center": Vector3.ZERO, "behavior": {"return_fire": 1.0}})
	ai._target_agent = tough
	ai._change_state(AIScript.AIState.FLEE)
	ai._process_flee()
	assert_eq(ai.get_state(), AIScript.AIState.FLEE)
	assert_true(hostile.get_node("ToolController").is_active(0), "Running, but firing back.")


func test_charged_at_by_a_neutral_ship_it_turns_on_it():
	ai.initialize({"patrol_center": Vector3.ZERO})
	var charger = _make_ship(Vector3(0, 0, -800), "", 20.0)
	assert_false(hostile.is_enemy_of(charger), "No war with this one")
	EventBus.emit_signal("agent_charged", hostile, charger)
	assert_true(hostile.is_enemy_of(charger), "until it charged with a lance")
	ai._tick_decision(100.0)
	assert_eq(ai.get_state(), AIScript.AIState.COMBAT, "A weaker ship charging: it turns on it, as if shot")


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
	assert_true(ai.has_pending_decision(), "Spots easy prey and starts deciding:")
	assert_eq(ai.get_state(), AIScript.AIState.HESITATE, "hesitates")
	assert_eq(ai.get_focus(), prey, "about that ship.")
	prey.hull = 1000.0  # Turns out to be much tougher before it commits
	ai._tick_decision(100.0)
	assert_eq(ai.get_state(), AIScript.AIState.PATROL, "Thinks better of it and patrols on.")


func test_being_shot_while_deciding_turns_the_decision_into_a_response():
	seed(11)  # Decision times are jittered: two can differ by more than the margin below
	ai.initialize({"patrol_center": Vector3.ZERO})
	var shooter = _make_ship(Vector3(0, 0, -500), "player", 50.0)
	hostile.apply_damage(1.0, shooter)
	assert_eq(ai.get_state(), AIScript.AIState.HESITATE)
	var thinking: float = ai._pending.timer
	ai._consider("engage", shooter, 0.9, Constants.AI_ENGAGE_DESIRE)  # The patrol scan spots it too
	assert_eq(ai._pending.kind, "respond", "A scan does not replace deciding how to answer fire")
	var prey = _make_ship(Vector3(0, 0, -300), "verdant", 5.0)
	ai._consider("engage", prey, 3.0, Constants.AI_ENGAGE_DESIRE)
	assert_eq(ai._pending.target, shooter, "nor does easier prey.")
	ai._pending = {}
	ai._resume()
	ai._consider("engage", shooter, 0.9, Constants.AI_ENGAGE_DESIRE)
	hostile.apply_damage(1.0, shooter)
	assert_eq(ai._pending.kind, "respond", "Shot while weighing an attack: now it is answering fire")
	assert_true(ai._pending.timer <= thinking * 2.0, "without starting over.")
	ai._tick_decision(100.0)
	assert_eq(ai.get_state(), AIScript.AIState.COMBAT, "Answers fire whenever the fight is worth keeping up.")


func test_hesitating_salvager_goes_back_to_its_wreck():
	ai.initialize({"patrol_center": Vector3.ZERO})
	var wreck = _make_ship(Vector3(0, 0, -200), "verdant", 50.0)
	wreck.become_wreck()
	ai._target_agent = wreck
	ai._change_state(AIScript.AIState.SALVAGE)
	var prey = _make_ship(Vector3(0, 0, -600), "verdant", 20.0)
	ai._consider("engage", prey, 1.5, Constants.AI_ENGAGE_DESIRE)
	assert_eq(ai.get_state(), AIScript.AIState.HESITATE)
	prey.hull = 1000.0
	ai._tick_decision(100.0)
	assert_eq(ai.get_state(), AIScript.AIState.SALVAGE, "Not worth it after all: back to the wreck")
	assert_eq(ai.get_focus(), wreck)


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
	hostile.get_node("ToolController").set_tools([hostile.get_node("ToolController").get_tool(0), harpoon, harpoon])
	ai._process_salvage()
	assert_true(hostile.get_node("ToolController").is_active(1), "Harpoon on the wreck,")
	assert_true(hostile.get_node("ToolController").is_active(2), "and the second one too: each strips on its own.")
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



func test_fires_every_weapon_that_reaches():
	var prey = _make_ship(Vector3(0, 0, -300), "verdant", 50.0)
	var tools = hostile.get_node("ToolController")
	tools.set_tools([tools.get_tool(0), tools.get_tool(0)])
	hostile.power_max = 100.0
	hostile.power = 100.0
	ai.initialize({"patrol_center": Vector3.ZERO})
	ai._start_combat(prey, false)
	ai._process_combat()
	assert_true(tools.is_active(0) and tools.is_active(1), "Both lasers on the target.")


# --- Arena NPCs ---

func _arena_station(position: Vector3) -> Spatial:
	var station = load("res://src/scenes/game_world/station/dockable_station.gd").new()
	add_child_autofree(station)
	station.global_transform.origin = position
	station.undock_offset = Vector3.ZERO
	return station


func test_arena_npcs_ignore_ships_outside_their_arena():
	ai.initialize({"patrol_center": Vector3.ZERO, "arena": {"zone_id": "t", "beacon": Vector3(0, 0, Constants.ARENA_RADIUS + 500.0), "stations": []}})
	var weak = _make_ship(Vector3(0, 0, -1200), "verdant", 25.0)
	assert_null(ai.scan_for_target(), "The weak ship is out of the arena")
	ai._arena.beacon = Vector3.ZERO
	assert_eq(ai.scan_for_target(), weak)


func test_arena_npc_flees_to_its_station_and_docks_there_then_undocks():
	var near = _arena_station(Vector3(0, 0, 2000))
	var far = _arena_station(Vector3(0, 0, -6000))
	var threat = _make_ship(Vector3(0, 0, -800), "verdant", 500.0)
	ai.initialize({"patrol_center": Vector3.ZERO, "arena": {"zone_id": "t", "beacon": Vector3.ZERO, "stations": [near, far]}})
	ai._target_agent = threat
	ai._change_state(AIScript.AIState.FLEE)
	assert_eq(ai._station, near, "Runs to the station away from the threat")
	hostile.global_transform.origin = near.get_undock_position()
	ai._process_flee()
	assert_eq(ai.get_state(), AIScript.AIState.DOCKED)
	assert_true(hostile.is_docked)
	threat.global_transform.origin = Vector3(0, 0, -6000)  # Gone: clear to undock
	ai._process_docked(Constants.ARENA_DOCK_TIME + 0.1)
	assert_eq(ai.get_state(), AIScript.AIState.PATROL)
	assert_false(hostile.is_docked)


func test_retreat_gene_runs_home_whatever_the_odds():
	var station = _arena_station(Vector3(0, 0, 3000))
	var prey = _make_ship(Vector3(0, 0, -500), "verdant", 5.0)
	ai.initialize({"patrol_center": Vector3.ZERO, "behavior": {"retreat_hull": 0.5}, "arena": {"zone_id": "t", "beacon": Vector3.ZERO, "stations": [station]}})
	ai._target_agent = prey
	ai._current_state = AIScript.AIState.IDLE
	ai._change_state(AIScript.AIState.COMBAT)
	hostile.hull = hostile.hull_max * 0.4
	ai._process_combat()
	assert_eq(ai.get_state(), AIScript.AIState.FLEE, "Under half hull: runs, though the prey is easy")


# --- Runners: chase, let go, shoot back or not ---

const MovementScript = preload("res://src/core/agents/components/movement_system.gd")


# Gives `body` a top speed (m/s; mass 1) and a velocity away from the hostile.
func _set_speed(body: RigidBody, top_speed: float, running: bool) -> void:
	var movement = MovementScript.new()
	body.add_child(movement)
	body.movement_system = movement
	body.mass = 1.0
	body.ship_template.signature = 50000.0  # Seen however far it runs
	movement.linear_thrust = top_speed * Constants.LINEAR_DRAG
	if running:
		body.linear_velocity = (body.global_transform.origin - hostile.global_transform.origin).normalized() * top_speed


func _fighting(target) -> void:
	ai._target_agent = target
	ai._current_state = AIScript.AIState.IDLE
	ai._change_state(AIScript.AIState.COMBAT)


func test_a_runner_that_does_not_shoot_back_holds_fire():
	var tough = _make_ship(Vector3(0, 0, -300), "verdant", 1000.0)
	hostile.power_max = 100.0
	hostile.power = 100.0
	ai.initialize({"patrol_center": Vector3.ZERO, "behavior": {"return_fire": 0.0}})
	ai._target_agent = tough
	ai._change_state(AIScript.AIState.FLEE)
	ai._process_flee()
	assert_false(hostile.get_node("ToolController").is_active(0), "Running without shooting back")


func test_gives_up_a_runner_it_cannot_catch_before_it_is_safe():
	var reach: float = hostile.get_node("ToolController").get_tool(0).get_max_range()
	var station = _arena_station(Vector3(0, 0, -(reach + 3000.0)))
	var prey = _make_ship(Vector3(0, 0, -(reach + 500.0)), "verdant", 5.0)
	_set_speed(hostile, 200.0, false)
	_set_speed(prey, 100.0, true)
	ai.initialize({"patrol_center": Vector3.ZERO, "behavior": {"mercy": 0.0},
		"arena": {"zone_id": "t", "beacon": Vector3.ZERO, "stations": [], "refuges": {"verdant": [station]}}})
	_fighting(prey)
	assert_true(ai.is_running_from_me(prey))
	assert_almost_eq(ai.chase_margin(prey), (2500.0 / 100.0) / (500.0 / 100.0), 0.01, "Caught in 5 s, safe in 25 s")
	ai._scan_timer = 0.0
	ai._process_combat()
	assert_eq(ai.get_state(), AIScript.AIState.COMBAT, "Catchable: keeps after it")
	station.global_transform.origin = prey.global_transform.origin + Vector3(0, 0, -200.0)
	ai._scan_timer = 0.0
	ai._process_combat()
	assert_eq(ai.get_state(), AIScript.AIState.HESITATE, "Nearly home: weighs giving up")
	ai._tick_decision(100.0)
	assert_eq(ai.get_state(), AIScript.AIState.PATROL, "and gives up")
	assert_true(ai.is_sparing(prey))
	assert_null(ai.scan_for_target(), "and leaves it be for a while")
	assert_almost_eq(ai.chase_margin(prey), 0.4, 0.01, "Safe in 2 s, caught in 5 s")
	assert_true(ai.chase_margin(prey) * 3.0 >= 1.0, "A dogged pursuer (pursuit gene 3) would have gone on")


func test_mercy_lets_go_only_a_runner_that_holds_fire():
	var reach: float = hostile.get_node("ToolController").get_tool(0).get_max_range()
	var prey = _make_ship(Vector3(0, 0, -(reach + 500.0)), "verdant", 5.0)
	_set_speed(hostile, 200.0, false)
	_set_speed(prey, 100.0, true)
	ai.initialize({"patrol_center": Vector3.ZERO, "behavior": {"mercy": 1.0}})
	_fighting(prey)
	hostile.apply_damage(1.0, prey)  # It shoots back as it runs
	ai._scan_timer = 0.0
	ai._process_combat()
	assert_eq(ai.get_state(), AIScript.AIState.COMBAT, "Shooting back: no mercy")
	ai._think(Constants.AI_RETURN_FIRE_WINDOW + 0.1)  # Holds fire a while
	ai._scan_timer = 0.0
	ai._process_combat()
	assert_eq(ai.get_state(), AIScript.AIState.HESITATE)
	ai._tick_decision(100.0)
	assert_eq(ai.get_state(), AIScript.AIState.PATROL, "Let go")
	hostile.apply_damage(1.0, prey)
	ai._tick_decision(100.0)
	assert_eq(ai.get_state(), AIScript.AIState.COMBAT, "until it shoots again")
	assert_false(ai.is_sparing(prey))


func test_waits_docked_while_an_enemy_watches_its_station():
	var station = _arena_station(Vector3(0, 0, 3000))
	var camper = _make_ship(Vector3(0, 0, 3000 + Constants.ARENA_UNDOCK_CLEAR_RADIUS - 200.0), "verdant", 50.0)  # Undock offset 0 in tests
	ai.initialize({"patrol_center": Vector3.ZERO, "docked_at": station, "arena": {"zone_id": "t", "beacon": Vector3.ZERO, "stations": [station]}})
	assert_eq(ai.get_state(), AIScript.AIState.DOCKED)
	ai._process_docked(Constants.ARENA_DOCK_TIME + 1.0)
	assert_eq(ai.get_state(), AIScript.AIState.DOCKED, "An enemy outside: stays in")
	ai._process_docked(Constants.ARENA_DOCK_MAX_WAIT)
	assert_eq(ai.get_state(), AIScript.AIState.PATROL, "but not for ever")
	ai._dock(station, false)
	camper.global_transform.origin = Vector3(0, 0, 3000 + Constants.ARENA_UNDOCK_CLEAR_RADIUS + 200.0)
	ai._process_docked(Constants.ARENA_DOCK_TIME + 1.0)
	assert_eq(ai.get_state(), AIScript.AIState.PATROL, "Clear outside: undocks on time")


# --- Desperation ---

func test_a_broke_pilot_takes_worse_odds_and_spares_less():
	ai.initialize({"patrol_center": Vector3.ZERO, "behavior": {"mercy": 0.8, "pursuit": 1.0, "return_fire": 0.2}})
	hostile.wallet = hostile.get_value() * Constants.AI_DESPERATION_COMFORT * 2.0
	assert_eq(hostile.get_desperation(), 0.0, "Rich: not desperate")
	assert_almost_eq(ai._engage_level(), Constants.AI_ENGAGE_DESIRE, 0.001)
	assert_almost_eq(ai._mercy_level(), 0.8, 0.001)
	hostile.wallet = 0.0
	assert_eq(hostile.get_desperation(), 1.0, "Broke")
	assert_almost_eq(ai._engage_level(), Constants.AI_ENGAGE_DESIRE * (1.0 - Constants.AI_DESPERATION_NERVE), 0.001, "fights at worse odds")
	assert_eq(ai._mercy_level(), 0.0, "spares nobody")
	assert_almost_eq(ai._pursuit_level(), 2.0, 0.001, "chases harder")
	assert_almost_eq(ai._return_fire_level(), 1.0, 0.001, "always shoots back")


# --- Ramming ---

func _give_lance(body: RigidBody) -> Spatial:
	var lance = load("res://src/core/agents/components/lance_controller.gd").new()
	body.add_child(lance)
	lance.setup(body, "test_lance", load("res://src/core/systems/ship_laws.gd").lance_stats(Constants.PART_TYPE_SEEDS.lance[2]))
	return lance


func test_rams_with_a_lance_while_firing_and_arms_it_only_then():
	var prey = _make_ship(Vector3(0, 0, -500), "verdant", 20.0)
	var lance = _give_lance(hostile)
	_set_speed(hostile, Constants.LAW_LANCE_MIN_SPEED * Constants.AI_RAM_SPEED_MARGIN + 10.0, false)
	hostile.power_max = 100.0
	hostile.power = 100.0
	ai.initialize({"patrol_center": Vector3.ZERO})
	assert_false(lance.armed, "Safe until it rams")
	_fighting(prey)
	ai._process_combat()
	assert_true(ai.can_ram())
	assert_eq(ai.get_activity_label(), "RAMMING", "The player can see it coming")
	assert_true(lance.armed)
	assert_true(hostile.get_node("ToolController").is_active(0), "Lasers fire as it charges")
	lance.nails = 0
	ai._process_combat()
	assert_eq(ai.get_activity_label(), "FIGHTING", "Out of lances: a laser fight")
	assert_false(lance.armed)
	ai._change_state(AIScript.AIState.PATROL)
	assert_false(lance.armed, "Never armed out of a fight")


func test_too_slow_to_strike_it_does_not_ram():
	var prey = _make_ship(Vector3(0, 0, -500), "verdant", 20.0)
	var lance = _give_lance(hostile)
	_set_speed(hostile, Constants.LAW_LANCE_MIN_SPEED * 0.9, false)
	ai.initialize({"patrol_center": Vector3.ZERO})
	_fighting(prey)
	ai._process_combat()
	assert_false(ai.can_ram())
	assert_false(lance.armed)


func test_a_lancer_short_of_lances_goes_for_wrecks_with_its_lances_first_even_when_full():
	ai.initialize({"patrol_center": Vector3.ZERO})
	hostile.cargo_capacity = 10
	hostile.add_cargo("test_scrap", 10)
	var lance = _give_lance(hostile)
	var near = _make_ship(Vector3(0, 0, -300), "verdant", 50.0)
	near.become_wreck()
	near.salvage = {"test_scrap": 5}
	var far = _make_ship(Vector3(0, 0, -800), "verdant", 50.0)
	far.become_wreck()
	var stuck = MeshInstance.new()
	stuck.add_to_group("stuck_lance")
	stuck.set_meta("nail_mass", float(lance.lance.nail_mass))
	far.add_child(stuck)
	assert_eq(ai.scan_for_wreck(), null, "Quiver full and hold full: nothing worth salvaging")
	lance.nails -= 1
	assert_eq(ai.scan_for_wreck(), far, "Its lance, further off, comes first")


func test_does_not_ram_a_runner_it_cannot_outpace_by_strike_speed():
	ai.initialize({"patrol_center": Vector3.ZERO})
	var runner = _make_ship(Vector3(0, 0, -800), "verdant", 50.0)
	runner.linear_velocity = Vector3(0, 0, -50)  # Running (test ships have no engines: neither is faster)
	assert_true(ai.outruns_ram(runner), "Same top speed: it could never close at strike speed")
	runner.linear_velocity = Vector3.ZERO
	assert_false(ai.outruns_ram(runner), "Standing: rammable")


func test_friends_near_a_ship_count_on_its_side():
	var prey = _make_ship(Vector3(0, 0, -800), "verdant", 25.0)
	var alone: float = ai.desire_against(prey)
	var escort = _make_ship(Vector3(0, 0, -1300), "verdant", 100.0)
	assert_lt(ai.desire_against(prey), alone, "Its escort makes it a harder fight")
	var hurt: float = ai.desire_against(prey)
	_make_ship(Vector3(300, 0, 0), "violet", 100.0)
	assert_gt(ai.desire_against(prey), hurt, "and its own wingman an easier one")
	var side: Dictionary = CombatAssessment.side_of(hostile)
	assert_eq(side.ships, 2, "A wingman near it counts on its side")
	assert_almost_eq(side.hull, 150.0, 0.01)
	escort.global_transform.origin = Vector3(0, 0, -800 - Constants.AI_TEAM_RADIUS - 100.0)
	assert_eq(CombatAssessment.side_of(prey).ships, 1, "A friend too far away does not")


func test_goes_to_help_a_friend_under_fire():
	ai.initialize({"patrol_center": Vector3.ZERO})
	var friend = _make_ship(Vector3(0, 0, -1500), "violet", 50.0)
	var attacker = _make_ship(Vector3(0, 0, -2500), "verdant", 30.0)
	friend.apply_damage(1.0, attacker)
	assert_eq(ai.get_state(), AIScript.AIState.HESITATE, "Weighs going to help")
	assert_eq(ai._pending.kind, "assist")
	assert_eq(ai.get_focus(), attacker, "against the attacker")
	ai._tick_decision(100.0)
	assert_eq(ai.get_state(), AIScript.AIState.COMBAT, "Goes, its friend on its side")
	assert_eq(ai.get_focus(), attacker)


func test_does_not_leave_its_own_fight_to_help_or_help_from_afar():
	ai.initialize({"patrol_center": Vector3.ZERO})
	var far_friend = _make_ship(Vector3(0, 0, Constants.AI_ASSIST_RADIUS + 500.0), "violet", 50.0)
	var attacker = _make_ship(Vector3(0, 0, Constants.AI_ASSIST_RADIUS + 1500.0), "verdant", 30.0)
	far_friend.apply_damage(1.0, attacker)
	assert_eq(ai.get_state(), AIScript.AIState.PATROL, "Too far to help")
	var near_friend = _make_ship(Vector3(0, 0, -1000), "violet", 50.0)
	var foe = _make_ship(Vector3(0, 0, -600), "verdant", 20.0)
	ai._start_combat(foe, false)
	near_friend.apply_damage(1.0, attacker)
	assert_eq(ai.get_focus(), foe, "Busy with its own fight")


func test_followers_join_their_leaders_fight():
	Evolution.new_run()
	var arena := {"zone_id": "t", "beacon": Vector3.ZERO, "stations": []}
	ai.initialize({"patrol_center": Vector3.ZERO, "arena": arena})
	var follower: Dictionary = Evolution.begin_life("violet", "t")
	var chief: Dictionary = Evolution.begin_life("violet", "t")
	Evolution.live[chief.uid].kills = 1
	hostile.evo_uid = follower.uid
	var leader = _make_ship(Vector3(0, 0, -1200), "violet", 50.0)
	leader.evo_uid = chief.uid
	Evolution.attach_body(chief.uid, leader)
	var leader_ai = AIScript.new()
	leader_ai.name = Constants.AI_CONTROLLER_NODE_NAME
	leader.add_child(leader_ai)
	leader_ai.initialize({"patrol_center": Vector3.ZERO, "arena": arena})
	assert_eq(ai.get_leader(), leader, "Its group's leader")
	assert_null(leader_ai.get_leader(), "The leader follows no one")
	var foe = _make_ship(Vector3(0, 0, -2700), "verdant", 30.0)
	assert_false(hostile.detects(foe), "Too far for the follower to see")
	leader_ai._start_combat(foe, false)
	ai._scan_timer = 0.0
	ai._process_patrol()
	assert_eq(ai._pending.get("kind"), "assist", "It goes to join the fight")
	assert_eq(ai.get_focus(), foe)
	Evolution.new_run()
	TemplateDatabase.evolved = {}  # Its lives built ships and parts the registry tests must not meet


func test_an_unseen_target_tempts_more():
	var prey = _make_ship(Vector3(0, 0, -800), "verdant", 50.0)
	var seen: float = ai.desire_against(prey)
	prey.ship_template.sensor_strength = 0.1
	prey.fit_stats = {"sensor_strength": 0.1}
	assert_false(prey.detects(hostile))
	assert_almost_eq(ai.desire_against(prey), seen * Constants.AI_UNSEEN_DESIRE_FACTOR, 0.001, "It would strike first")


func test_keeps_clear_of_a_strong_enemy_that_has_not_seen_it():
	ai.initialize({"patrol_center": Vector3.ZERO})
	var brute = _make_ship(Vector3(0, 0, -1000), "verdant", 5000.0)
	brute.fit_stats = {"sensor_strength": 0.1}
	assert_null(ai.scan_for_target(), "Too strong to fight")
	ai._scan_timer = 0.0
	ai._process_patrol()
	assert_gt(ai._patrol_destination.z, 0.0, "Patrols away from it")
	assert_eq(ai._avoided, brute)
	brute.fit_stats = {"sensor_strength": 1.0}
	ai.scan_for_target()
	assert_null(ai._threat, "Seen already: hiding is no use")


func test_loners_help_no_one_and_the_reckless_keep_clear_of_no_one():
	ai.initialize({"patrol_center": Vector3.ZERO, "behavior": {"teamwork": 0.0, "caution": 0.0}})
	var friend = _make_ship(Vector3(0, 0, -1500), "violet", 50.0)
	var attacker = _make_ship(Vector3(0, 0, -2500), "verdant", 30.0)
	friend.apply_damage(1.0, attacker)
	assert_eq(ai.get_state(), AIScript.AIState.PATROL, "A loner lets its friend fend for itself")
	var brute = _make_ship(Vector3(0, 0, -1000), "verdant", 5000.0)
	brute.fit_stats = {"sensor_strength": 0.1}
	ai.scan_for_target()
	assert_null(ai._threat, "and the reckless keep clear of no one")
