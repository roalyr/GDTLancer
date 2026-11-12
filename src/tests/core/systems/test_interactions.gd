# Tests for Interactions: the free port's faction (allied to the player, open to the others), what
# the INTERACT window offers by side and role, hiring an escort and leading a wing (they keep by the
# player, guard it, are paid from its sales; deselecting lets them go), joining a trader's caravan.

extends GutTest

const AgentScript = preload("res://src/core/agents/agent.gd")
const AIScript = preload("res://src/modules/piloting/ship_controller_ai.gd")
const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")
const Interactions = preload("res://src/core/systems/interactions.gd")
const Wages = preload("res://src/core/systems/wages.gd")
const Havens = preload("res://src/core/systems/havens.gd")


class FakeController extends Node:
	var escort_ward = null
	var focus = null

	func set_escort_ward(ward) -> void:
		escort_ward = ward

	func get_focus():
		return focus


func after_each():
	GameState.reset_state()


func _ship(position: Vector3, faction: String, armed: bool, agent_type: String = "npc") -> RigidBody:
	var body = AgentScript.new()
	var ship = ShipTemplate.new()
	ship.signature = 1500.0
	ship.base_value = 1000
	body.ship_template = ship
	body.agent_type = agent_type
	add_child_autofree(body)
	body.global_transform.origin = position
	body.faction = faction
	body.hull_max = 50.0
	body.hull = 50.0
	var tools = ToolControllerScript.new()
	tools.name = "ToolController"
	body.add_child(tools)
	if armed:
		var laser = UtilityToolTemplate.new()
		laser.damage = 6.0
		laser.cycle_time = 1.0
		tools.set_tools([laser])
	if agent_type == "npc":
		var ai = AIScript.new()
		ai.name = Constants.AI_CONTROLLER_NODE_NAME
		body.add_child(ai)
		ai._current_state = AIScript.AIState.PATROL
	return body


func _player() -> RigidBody:
	var player = _ship(Vector3.ZERO, "player", true, "player")
	var controller = FakeController.new()  # Stands in for PlayerControllerShip: its escort ward
	controller.name = Constants.PLAYER_INPUT_HANDLER_NAME
	player.add_child(controller)
	return player


func _ai(body) -> Node:
	return body.get_node(Constants.AI_CONTROLLER_NODE_NAME)


func _kinds(player, ship) -> Array:
	var kinds: Array = []
	for option in Interactions.options(player, ship):
		kinds.append(option.kind)
	return kinds


func test_the_free_port_is_an_allied_faction_open_to_others():
	var freeport: Dictionary = TemplateDatabase.factions.get("freeport", {})
	assert_false(freeport.empty(), "The free port's faction")
	assert_eq(Havens.faction_of("station_elace_home"), "freeport", "owns the free port")
	assert_true(Interactions.is_allied("freeport"), "The player starts allied with it")
	assert_true(freeport.open_havens and freeport.escorts)
	var roles := {}
	for name in freeport.roster:
		roles[name.split("_")[0]] = true
	assert_true(roles.has("trader") and roles.has("prospector") and roles.has("fighter"), "Traders, prospectors and escorts")


func test_what_is_offered_by_side_and_role():
	var player = _player()
	assert_eq(_kinds(player, _ship(Vector3(0, 0, 500), "freeport", true)), ["hire", "wing"], "An allied fighter: hire or lead it")
	assert_eq(_kinds(player, _ship(Vector3(0, 0, 600), "freeport", false)), ["escort"], "An allied worker: escort it")
	assert_eq(_kinds(player, _ship(Vector3(0, 0, 700), "verdant", true)), [], "A neutral fighter follows no one")
	assert_eq(_kinds(player, _ship(Vector3(0, 0, 800), "verdant", false)), ["escort"], "A neutral worker may be escorted")
	var raider = _ship(Vector3(0, 0, 900), "raiders", true)
	assert_eq(_kinds(player, raider), [], "A hostile: nothing")
	assert_eq(Interactions.why_not(player, raider, "hire"), "Hostile")


func test_a_hired_escort_keeps_by_the_player_until_deselected():
	var player = _player()
	var fighter = _ship(Vector3(0, 0, 500), "freeport", true)
	Interactions.toggle(player, fighter, "hire")
	assert_eq(_ai(fighter).player_role(), "hire")
	assert_eq(_ai(fighter).get_ward(), player, "The player is its ward")
	assert_eq(_ai(fighter).get_activity_label(), "ESCORTING")
	assert_true(fighter in Interactions.partners(player), "A partner: filled mark, ring arrow")
	player.is_docked = true
	assert_eq(_ai(fighter).get_ward(), player, "It waits while the player docks")
	player.is_docked = false
	Interactions.toggle(player, fighter, "wing")
	assert_eq(_ai(fighter).player_role(), "wing", "Hire and wing are one or the other")
	assert_eq(_ai(fighter).get_activity_label(), "IN WING")
	Interactions.toggle(player, fighter, "wing")
	assert_eq(_ai(fighter).player_role(), "", "Deselected: let go")
	assert_null(_ai(fighter).get_ward())
	assert_false(fighter in Interactions.partners(player))


func test_followers_are_capped():
	var player = _player()
	for index in range(Constants.PLAYER_FOLLOWERS_MAX):
		Interactions.toggle(player, _ship(Vector3(0, 0, 300 + index * 100), "freeport", true), "wing")
	var extra = _ship(Vector3(0, 0, 900), "freeport", true)
	assert_ne(Interactions.why_not(player, extra, "wing"), "", "No room for another")


func test_an_escort_guards_the_player():
	var player = _player()
	var fighter = _ship(Vector3(0, 0, 500), "freeport", true)
	var raider = _ship(Vector3(0, 0, 1500), "raiders", true)
	Interactions.toggle(player, fighter, "hire")
	_ai(fighter)._assist(player, raider)
	assert_eq(_ai(fighter)._pending.get("kind"), "guard", "Turns on whoever shoots the player")
	assert_eq(_ai(fighter)._pending.get("target"), raider)


func test_hired_escorts_in_range_take_their_share_of_the_players_sales():
	var player = _player()
	var near = _ship(Vector3(0, 0, 500), "freeport", true)
	var far = _ship(Vector3(0, 0, 500), "freeport", true)
	Interactions.toggle(player, near, "hire")
	Interactions.toggle(player, far, "hire")
	far.global_transform.origin = Vector3(0, 0, Constants.ESCORT_PAY_RANGE + 500.0)
	GameState.player_bank = 1000
	var paid: int = Wages.pay_player_escorts(player, 1000)
	assert_eq(paid, int(1000 * Constants.ESCORT_SHARE), "The one in range takes the share")
	assert_eq(GameState.player_bank, 1000 - paid, "from the bank")


func test_joining_a_traders_caravan():
	var player = _player()
	var trader = _ship(Vector3(0, 0, 500), "freeport", false)
	var station = Spatial.new()
	add_child_autofree(station)
	assert_false("caravan" in _kinds(player, trader), "Not on its way: no caravan")
	_ai(trader)._trade = 1.0
	_ai(trader)._havens = {"zone_id": "station_elace_home"}
	_ai(trader)._station = station
	_ai(trader)._current_state = AIScript.AIState.DEPART
	assert_true("caravan" in _kinds(player, trader))
	Interactions.toggle(player, trader, "caravan")
	assert_true(_ai(trader).has_player_mate())
	_ai(trader)._caravan_timer = 0.0
	assert_true(player in _ai(trader).get_caravan(), "Paced as a mate")
	_ai(trader)._change_state(AIScript.AIState.DOCKED)
	assert_false(_ai(trader).has_player_mate(), "Arrived: the caravan is over")


func test_the_window_lists_the_options_as_toggles():
	var player = _player()
	var before = GlobalRefs.player_agent_body
	GlobalRefs.player_agent_body = player
	var fighter = _ship(Vector3(0, 0, 500), "freeport", true)
	var window = load("res://scenes/ui/menus/interaction_window.tscn").instance()
	add_child_autofree(window)
	window.open(fighter)
	assert_true(get_tree().paused, "Paused while open, as the options window")
	var options = window.get_node("Center/Panel/Layout/Options")
	var hire: Button = options.get_node("Option_hire")
	assert_eq(hire.text, "HIRE AS ESCORT: OFF")
	hire.emit_signal("pressed")
	assert_eq(_ai(fighter).player_role(), "hire", "Tapped: asked")
	hire = options.get_node_or_null("Option_hire")
	for child in options.get_children():
		if child.name.begins_with("Option_hire") and not child.is_queued_for_deletion():
			hire = child
	assert_eq(hire.text, "HIRE AS ESCORT: ON")
	hire.emit_signal("pressed")
	assert_eq(_ai(fighter).player_role(), "", "Tapped again: let go")
	window.open(_ship(Vector3(0, 0, 900), "raiders", true))
	assert_true(options.get_node_or_null("Note_none") != null or options.get_child_count() > 2, "A hostile: why there is nothing")
	window.close()
	assert_false(get_tree().paused)
	GlobalRefs.player_agent_body = before
