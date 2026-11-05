# Tests for Wages and escorting: an armed friend takes a worker for its ward (one NPC escort each),
# guards it, lets it go when it is gone; escorts in range share the ward's sales; factions pay patrol
# wages to their own and to a player they think well of.

extends GutTest

const AgentScript = preload("res://src/core/agents/agent.gd")
const AIScript = preload("res://src/modules/piloting/ship_controller_ai.gd")
const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")
const Wages = preload("res://src/core/systems/wages.gd")


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
		ai._teamwork = 1.5
	return body


func _ai(body) -> Node:
	return body.get_node(Constants.AI_CONTROLLER_NODE_NAME)


func test_an_armed_friend_takes_a_worker_for_its_ward_one_each():
	var escort = _ship(Vector3.ZERO, "verdant", true)
	var worker = _ship(Vector3(0, 0, -800), "verdant", false)
	var second = _ship(Vector3(0, 0, 400), "verdant", true)
	assert_true(Wages.is_worker(worker), "Unarmed: a worker")
	assert_false(Wages.is_worker(escort))
	assert_true(_ai(escort)._take_ward())
	assert_eq(_ai(escort).get_ward(), worker)
	assert_eq(_ai(worker).get_escorts(), [escort])
	_ai(escort)._current_state = AIScript.AIState.PATROL
	assert_eq(_ai(escort).get_activity_label(), "ESCORTING", "The player sees it")
	assert_false(_ai(second)._take_ward(), "One NPC escort a ward")


func test_no_escorts_across_factions_or_where_none_are_hired_or_for_loners():
	var worker = _ship(Vector3(0, 0, -800), "verdant", false)
	assert_false(_ai(_ship(Vector3.ZERO, "violet", true))._take_ward(), "Not the enemy's worker")
	_ship(Vector3(0, 0, 900), "raiders", false)
	var raider = _ship(Vector3(0, 0, 1000), "raiders", true)
	assert_false(_ai(raider)._take_ward(), "Raiders hire no escorts")
	var loner = _ship(Vector3(0, 0, 100), "verdant", true)
	_ai(loner)._teamwork = 0.5
	assert_false(_ai(loner)._take_ward(), "A loner escorts no one")
	assert_true(Wages.can_escort(_ship(Vector3.ZERO, "", true, "player"), worker), "The player may, while not hostile")


func test_a_ward_gone_is_let_go():
	var escort = _ship(Vector3.ZERO, "verdant", true)
	var worker = _ship(Vector3(0, 0, -800), "verdant", false)
	_ai(escort)._take_ward()
	worker.become_wreck()
	assert_null(_ai(escort).get_ward())
	assert_eq(_ai(worker).get_escorts(), [])


func test_escorts_near_the_ward_share_its_sales():
	var worker = _ship(Vector3.ZERO, "verdant", false)
	var player = _ship(Vector3(0, 0, 500), "", true, "player")
	var far = _ship(Vector3(0, 0, Constants.ESCORT_PAY_RANGE + 500.0), "", true, "player")
	_ai(worker).add_escort(player)
	_ai(worker).add_escort(far)
	GameState.player_bank = 0
	var paid: int = Wages.pay_escorts(worker, 1000)
	assert_eq(paid, int(1000 * Constants.ESCORT_SHARE), "Its share, to the one in range")
	assert_eq(GameState.player_bank, paid)


func test_patrol_wages_by_faction_time_and_standing():
	assert_eq(Wages.patrol_wage("verdant", 1000.0, 1800.0), int(round(1000.0 * Constants.PATROL_WAGE_SHARE_PER_HOUR * 0.5)))
	assert_eq(Wages.patrol_wage("verdant", 1000.0, 1e6), Wages.patrol_wage("verdant", 1000.0, Constants.PATROL_WAGE_MAX_TIME), "Up to its cap")
	assert_eq(Wages.patrol_wage("raiders", 1000.0, 1800.0), 0, "Raiders pay none")
	var player = _ship(Vector3.ZERO, "", true, "player")
	GameState.player_bank = 0
	assert_eq(Wages.pay_player_patrol(player, "verdant", 3600.0), 0, "Not friendly yet: nothing")
	GameState.player_standing["verdant"] = Constants.STANDING_FRIENDLY
	var wage: int = Wages.pay_player_patrol(player, "verdant", 3600.0)
	assert_gt(wage, 0, "Friendly: its wage")
	assert_eq(GameState.player_bank, wage)
	var unarmed = _ship(Vector3.ZERO, "", false, "player")
	assert_eq(Wages.pay_player_patrol(unarmed, "verdant", 3600.0), 0, "An unarmed ship patrols nothing")


func test_a_ward_docking_to_sell_still_pays_its_escort():
	var escort = _ship(Vector3(0, 0, 300), "verdant", true)
	var worker = _ship(Vector3.ZERO, "verdant", false)
	_ai(escort)._take_ward()
	worker.dock_at(null)  # Docks, then sells (ShipControllerAI._dock, Evolution.on_docked)
	assert_eq(Wages.pay_escorts(worker, 1000), int(1000 * Constants.ESCORT_SHARE), "The escort that brought it in is paid")
	assert_null(_ai(escort).get_ward(), "Then it lets the docked ward go")
