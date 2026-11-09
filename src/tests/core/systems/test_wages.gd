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


func test_an_outposts_guard_escorts_whatever_its_teamwork():
	_ship(Vector3(0, 0, -800), "verdant", false)
	var guard = _ship(Vector3.ZERO, "verdant", true)
	_ai(guard)._teamwork = 0.5
	assert_false(_ai(guard)._take_ward(), "A loner from a haven")
	_ai(guard)._havens = {"zone_id": "verdant_post"}  # Verdant Outpost: favours prospectors
	assert_true(_ai(guard).is_outpost_guard())
	assert_true(_ai(guard)._take_ward(), "An outpost's guard: escorting is its job")
	_ai(guard)._drop_ward()
	_ai(guard)._havens = {"zone_id": "verdant_haven"}
	assert_false(_ai(guard).is_outpost_guard(), "A home haven's ship is no outpost guard")


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


class Picket:
	var kind := "patrol"
	var faction := "verdant"
	func get_display_name() -> String:
		return "Picket"


func test_patrol_time_counts_only_at_a_paying_factions_pickets():
	var own = _ship(Vector3.ZERO, "verdant", true)
	var picket = Picket.new()
	Wages.on_patrol(own, picket, 10.0, true)
	Wages.on_patrol(own, picket, 5.0, false)
	var raider = _ship(Vector3.ZERO, "raiders", true)
	Wages.on_patrol(raider, picket, 10.0, true)
	var unarmed = _ship(Vector3.ZERO, "verdant", false)
	Wages.on_patrol(unarmed, picket, 10.0, true)
	picket.kind = "field"
	Wages.on_patrol(own, picket, 100.0, false)
	assert_almost_eq(Wages.take_patrol_time(own, "verdant"), 15.0, 0.01, "Its own picket, armed: on patrol")
	assert_almost_eq(Wages.take_patrol_time(own, "verdant"), 0.0, 0.01, "Taken: the count starts over")
	assert_almost_eq(Wages.take_patrol_time(raider, "verdant"), 0.0, 0.01, "Not its faction's")
	assert_almost_eq(Wages.take_patrol_time(unarmed, "verdant"), 0.0, 0.01, "Unarmed patrols nothing")


func test_the_player_patrols_only_as_a_friend():
	var player = _ship(Vector3.ZERO, "", true, "player")
	var picket = Picket.new()
	Wages.on_patrol(player, picket, 10.0, true)
	assert_almost_eq(Wages.take_patrol_time(player, "verdant"), 0.0, 0.01, "Not friendly yet")
	GameState.player_standing["verdant"] = Constants.STANDING_FRIENDLY
	Wages.on_patrol(player, picket, 10.0, true)
	assert_almost_eq(Wages.take_patrol_time(player, "verdant"), 10.0, 0.01, "Friendly: its patrol")


func test_escorting_counts_as_patrol_time_paid_by_the_ships_value():
	var worker = _ship(Vector3.ZERO, "verdant", false)
	var escort = _ship(Vector3(0, 0, 300), "verdant", true)
	assert_true(_ai(escort)._take_ward(), "Takes the worker for its ward")
	Wages.on_escort(escort, 600.0)
	var seconds: float = Wages.take_patrol_time(escort, "verdant")
	if TemplateDatabase.factions.get("verdant", {}).get("patrol_wages", false):
		assert_almost_eq(seconds, 600.0, 0.01, "Ten minutes by its ward")
		var small: int = Wages.patrol_wage("verdant", 1000.0, seconds)
		var big: int = Wages.patrol_wage("verdant", 8000.0, seconds)
		assert_eq(big, small * 8, "A ship eight times the value earns eight times the wage: the same for its cost")
	else:
		assert_eq(seconds, 0.0, "A faction without patrol wages pays no escort time")
	escort.global_transform.origin = Vector3(0, 0, Constants.ESCORT_PAY_RANGE + 500.0)
	Wages.on_escort(escort, 600.0)
	assert_eq(Wages.take_patrol_time(escort, "verdant"), 0.0, "Out of range: not escorting")


func _trader(position: Vector3, station: Spatial, speed_share: float = 1.0) -> RigidBody:
	var body = _ship(position, "verdant", false)
	body.cargo_capacity = 100
	body.add_cargo("commodity_tech", 10)
	var ai = _ai(body)
	ai._trade = 1.0
	ai._havens = {"zone_id": "arena_verdant_haven", "stations": [station]}
	ai._station = station
	return body


func test_traders_bound_alike_travel_as_a_caravan():
	var station := Spatial.new()
	add_child_autofree(station)
	var one = _trader(Vector3.ZERO, station)
	var two = _trader(Vector3(0, 0, 1000), station)
	var far = _trader(Vector3(0, 0, Constants.CARAVAN_RANGE + 2000.0), station)
	for body in [one, two, far]:
		_ai(body)._current_state = AIScript.AIState.DEPART
	assert_true(_ai(one).is_trader(), "A trader")
	var mates: Array = _ai(one).get_caravan()
	assert_true(two in mates, "Its mate bound for the same station")
	assert_false(far in mates, "Too far to be one")
	assert_eq(_ai(one).get_activity_label(), "IN CARAVAN")


func test_a_loaded_trader_waits_docked_for_company_by_its_teamwork():
	var saved: Dictionary = TemplateDatabase.assets_commodities
	var tech := CommodityTemplate.new()
	tech.template_id = "commodity_tech"
	tech.base_value = 60
	TemplateDatabase.assets_commodities = {"commodity_tech": tech}  # Its cargo is worth something
	var station := Spatial.new()
	add_child_autofree(station)
	var one = _trader(Vector3.ZERO, station)
	var ai = _ai(one)
	ai._current_state = AIScript.AIState.DOCKED
	ai._teamwork = 2.0
	ai._dock_timer = 0.0
	assert_true(ai.waits_for_caravan(), "Alone: it waits a while for one")
	ai._dock_timer = -Constants.CARAVAN_WAIT - 1.0
	assert_false(ai.waits_for_caravan(), "Not for ever")
	ai._dock_timer = 0.0
	ai._teamwork = 0.0
	assert_false(ai.waits_for_caravan(), "A loner does not wait")
	ai._teamwork = 2.0
	var two = _trader(Vector3(0, 0, 100), station)
	two.is_docked = true
	_ai(two)._current_state = AIScript.AIState.DOCKED
	_ai(two)._dock_timer = 5.0
	assert_true(ai.waits_for_caravan(), "Its mate is still busy: it waits")
	_ai(two)._dock_timer = 0.0
	assert_false(ai.waits_for_caravan(), "Both ready: they go together")
	two.is_docked = false
	two.global_transform.origin = Vector3(0, 0, 50000)
	assert_true(ai.waits_for_caravan(), "Alone again: waits")
	var guard = _ship(Vector3(0, 0, 500), "verdant", true)
	assert_false(ai.waits_for_caravan(), "A free escort near the station: it goes, to be taken as it comes out")
	TemplateDatabase.assets_commodities = saved


func test_a_trader_takes_more_escorts():
	var station := Spatial.new()
	add_child_autofree(station)
	var trader = _trader(Vector3.ZERO, station)
	var first = _ship(Vector3(0, 0, 300), "verdant", true)
	var second = _ship(Vector3(0, 0, 400), "verdant", true)
	assert_true(_ai(first)._take_ward(), "One escort")
	assert_true(_ai(second)._take_ward(), "And a second for a trader (ESCORTS_PER_TRADER)")
	assert_eq(_ai(trader).get_escorts().size(), 2)


func test_no_ship_hunts_its_own_side_for_a_bounty():
	var Bounty = load("res://src/core/systems/bounty.gd")
	var wanted = _ship(Vector3.ZERO, "xenohive", true)
	wanted.bounties = {"verdant": 5000.0}  # Verdant's price on it, for a kill
	var sibling = _ship(Vector3(0, 0, 500), "xenohive", true)
	var hunter = _ship(Vector3(0, 0, 900), "verdant", true)
	assert_false(Bounty.is_worth_hunting(sibling, wanted), "Its own hive does not hunt it")
	assert_eq(Bounty.claimable(sibling, wanted), 0.0, "nor could claim it")
	assert_true(Bounty.is_worth_hunting(hunter, wanted), "Verdant does")
