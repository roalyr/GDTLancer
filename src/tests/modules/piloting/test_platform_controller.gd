# Tests for weapon platforms (PlatformController, Constants PLATFORM_*): built by the ship laws with
# every weapon kind but the lance, never moving; they fire on their faction's enemies and on whoever
# opens fire near them; no one hunts them and no bounty rides on them.

extends GutTest

const AgentSystemScript = preload("res://src/core/systems/agent_system.gd")
const PlatformController = preload("res://src/modules/piloting/platform_controller.gd")
const AgentScript = preload("res://src/core/agents/agent.gd")
const AIScript = preload("res://src/modules/piloting/ship_controller_ai.gd")
const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")
const Bounty = preload("res://src/core/systems/bounty.gd")

var _container: Spatial = null
var _saved_container = null
var _saved_assets = null


func before_each():
	_container = Spatial.new()
	add_child_autofree(_container)
	_saved_container = GlobalRefs.agent_container
	GlobalRefs.agent_container = _container
	_saved_assets = GlobalRefs.asset_system
	var assets = load("res://src/core/systems/asset_system.gd").new()
	add_child_autofree(assets)
	GlobalRefs.asset_system = assets


func after_each():
	GlobalRefs.agent_container = _saved_container
	GlobalRefs.asset_system = _saved_assets


func _platform(faction: String, at: Vector3 = Vector3.ZERO) -> RigidBody:
	var station := Spatial.new()
	add_child_autofree(station)
	station.global_transform.origin = at + Vector3(0, 0, Constants.PLATFORM_RING_RADIUS)
	var spawner = AgentSystemScript.new()
	autofree(spawner)
	return spawner.spawn_platform(station, faction, at)


func _ship(position: Vector3, faction: String) -> RigidBody:
	var body = AgentScript.new()
	var ship = ShipTemplate.new()
	ship.signature = 5000.0
	ship.base_value = 1000
	body.ship_template = ship
	body.agent_type = "npc"
	add_child_autofree(body)
	body.global_transform.origin = position
	body.faction = faction
	body.hull_max = 50.0
	body.hull = 50.0
	var tools = ToolControllerScript.new()
	tools.name = "ToolController"
	body.add_child(tools)
	var laser = UtilityToolTemplate.new()
	laser.damage = 6.0
	laser.cycle_time = 1.0
	tools.set_tools([laser])
	var ai = AIScript.new()
	ai.name = Constants.AI_CONTROLLER_NODE_NAME
	body.add_child(ai)
	return body


func test_a_platform_is_a_law_built_ship_with_every_weapon_but_the_lance():
	var platform = _platform("verdant")
	yield(get_tree(), "idle_frame")  # Its tools load deferred (ToolController)
	assert_not_null(platform)
	assert_true(platform.is_platform)
	assert_true(platform.axis_lock_linear_x and platform.axis_lock_linear_y and platform.axis_lock_linear_z, "It never moves")
	var tools = platform.get_node("ToolController")
	var kinds := []
	for index in range(tools.get_tool_count()):
		kinds.append(tools.get_tool(index).tool_type)
	kinds.sort()
	assert_eq(kinds, ["cannon", "laser", "missile"])
	assert_eq(platform.ship_template.mass, Constants.LAW_SHIP_REF_MASS * Constants.PLATFORM_SEED.size, "The ship laws' mass")
	assert_gt(platform.hull_max, 0.0)


func test_it_fires_on_its_factions_enemies_not_on_friends():
	var platform = _platform("verdant")
	yield(get_tree(), "idle_frame")  # Its tools load deferred (ToolController)
	var friend = _ship(Vector3(0, 0, -800), "verdant")
	var enemy = _ship(Vector3(0, 0, -1200), "violet")
	var guns = platform.get_node(Constants.PLATFORM_CONTROLLER_NODE_NAME)
	assert_true(guns.is_foe(enemy))
	assert_false(guns.is_foe(friend))
	assert_eq(guns._pick_target(), enemy)


func test_a_neutral_platform_fires_only_on_whoever_opens_fire_near_it():
	var platform = _platform("")
	yield(get_tree(), "idle_frame")  # Its tools load deferred (ToolController)
	var guns = platform.get_node(Constants.PLATFORM_CONTROLLER_NODE_NAME)
	var trader = _ship(Vector3(0, 0, -600), "verdant")
	var raider = _ship(Vector3(0, 0, -1000), "raiders")
	assert_null(guns._pick_target(), "No one is its enemy by faction")
	guns._on_agent_damaged(trader, 5.0, raider)
	assert_true(guns.is_foe(raider), "It opened fire near the port")
	assert_false(guns.is_foe(trader))
	guns._on_agent_damaged(raider, 5.0, trader)
	assert_false(guns.is_foe(trader), "Fire on its foe is welcome")
	var guard = _ship(Vector3(0, 0, -700), "violet")
	var attacker = _ship(Vector3(0, 0, -900), "verdant")
	guard._hold_grudge(attacker)  # It shot the guard's ward first (ShipControllerAI _guard / assist)
	guns._on_agent_damaged(attacker, 5.0, guard)
	assert_false(guns.is_foe(guard), "Fighting back is not opening fire")
	var far_shooter = _ship(Vector3(0, 0, -20000), "violet")
	var far_victim = _ship(Vector3(0, 0, -20500), "verdant")
	guns._on_agent_damaged(far_victim, 5.0, far_shooter)
	assert_false(guns.is_foe(far_shooter), "Too far from it to care")


func test_no_one_hunts_a_platform_or_is_paid_for_one():
	var platform = _platform("verdant")
	yield(get_tree(), "idle_frame")  # Its tools load deferred (ToolController)
	var hunter = _ship(Vector3(0, 0, -900), "violet")
	platform.bounties = {"violet": 5000.0}
	assert_false(Bounty.is_worth_hunting(hunter, platform))
	assert_eq(Bounty.claimable(hunter, platform), 0.0)
	assert_ne(hunter.get_node(Constants.AI_CONTROLLER_NODE_NAME).scan_for_target(), platform, "Not prey")
	platform.bounties = {}
	var victim = _ship(Vector3(0, 0, -900), "violet")
	Bounty.on_kill(platform, victim)
	assert_false(platform.bounties.has("violet"), "No posting on a station's guns")


func test_it_holds_fire_with_a_friend_in_the_line_and_forgives_a_stray_shot():
	var platform = _platform("")
	yield(get_tree(), "idle_frame")
	var guns = platform.get_node(Constants.PLATFORM_CONTROLLER_NODE_NAME)
	var raider = _ship(Vector3(0, 0, -3000), "raiders")
	platform._hold_grudge(raider)
	assert_true(guns.clear_shot(raider))
	var trader = _ship(Vector3(0, 30, -1500), "verdant")
	assert_false(guns.clear_shot(raider), "A trader in the line of fire: it holds")
	trader.global_transform.origin = Vector3(2000, 0, -1500)
	assert_true(guns.clear_shot(raider))
	var fighter = _ship(Vector3(0, 0, -800), "violet")
	guns._on_agent_damaged(platform, 5.0, fighter)
	assert_false(guns.is_foe(fighter), "Its shot was at another ship: a stray")
	fighter.get_node("ToolController").activate(0, platform)
	guns._on_agent_damaged(platform, 5.0, fighter)
	assert_true(guns.is_foe(fighter), "Aimed at it: a foe")


var _damage_signals := 0


func _count_damage(_victim, _amount, _source) -> void:
	_damage_signals += 1


# Future-proofing (no platforms are placed in belts): mining by a station's guns is no attack. A
# lance struck into a rock and a laser burning the crust off its chunks raise no agent_damaged, so
# the platform holds no grudge and picks no target.
func test_mining_by_a_platform_does_not_set_it_off():
	var platform = _platform("")
	yield(get_tree(), "idle_frame")
	var guns = platform.get_node(Constants.PLATFORM_CONTROLLER_NODE_NAME)
	var rock = load("res://scenes/prefabs/celestial/asteroid.tscn").instance()
	add_child_autofree(rock)
	rock.global_transform.origin = Vector3(0, 0, -1000)
	rock.scale = Vector3.ONE * 30.0
	rock.deposit = 20
	var miner = _ship(Vector3(0, 0, -800), "verdant")
	miner.mass = 6000.0
	miner.power = 1000.0
	miner.power_max = 1000.0
	var lance = load("res://src/core/agents/components/lance_controller.gd").new()
	miner.add_child(lance)
	lance.setup(miner, "test_lance", load("res://src/core/systems/ship_laws.gd").lance_stats(load("res://src/tests/helpers/reference_parts.gd").genes("lance", 2)))
	EventBus.connect("agent_damaged", self, "_count_damage")
	_damage_signals = 0
	miner.linear_velocity = Vector3(0, 0, -200)  # Closing on the rock (TestMining._strike)
	lance.nails -= 1
	assert_gt(lance.strike_rock(rock, Vector3(0, 0, -980), Vector3(0, 0, 1), 0.0), 0.0, "The lance bit")
	var chunks: Array = get_tree().get_nodes_in_group("ore_chunk")
	assert_gt(chunks.size(), 0, "Pieces broke off")
	var tools = miner.get_node("ToolController")
	var laser = tools.get_tool(0)
	laser.optimal_range = 5000.0
	laser.cycle_time = 0.05
	laser.power_per_cycle = 0.0
	assert_true(tools.activate(0, chunks[0]).success, "The laser on a crusted chunk")
	for i in range(30):
		yield(get_tree(), "physics_frame")
	assert_false(chunks[0].has_crust(), "Burnt bare: the mining happened")
	tools.deactivate_all()
	assert_true(tools.activate(0, rock).success, "and on the rock itself")
	for i in range(10):
		yield(get_tree(), "physics_frame")
	EventBus.disconnect("agent_damaged", self, "_count_damage")
	assert_eq(_damage_signals, 0, "Mining hurts no ship")
	assert_false(guns.is_foe(miner), "No grudge on the miner")
	guns._scan_timer = 0.0
	guns._physics_process(0.1)
	assert_null(guns.get_target(), "Nothing to fire on")
	for node in chunks + get_tree().get_nodes_in_group("loose_lance"):
		if is_instance_valid(node):
			node.free()
