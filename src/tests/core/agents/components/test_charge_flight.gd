# Tests for a lance charge as flown (command_charge): under the target's guns it strafes, nose on
# the lead; within strike range it comes in head-on and throws; then it breaks off on a spiral, its
# nose kept on the target, and comes back for another pass.

extends GutTest

const CommandCharge = preload("res://src/core/agents/components/navigation_system/command_charge.gd")
const Genome = preload("res://src/core/evolution/genome.gd")
const AgentSystemScript = preload("res://src/core/systems/agent_system.gd")

const LANCER = {"ship": {"type": 1, "size": 0.6, "shares": {"structure": 0.3, "engine": 0.5, "reactor": 0.08, "capacitor": 0.04, "hold": 0.08}},
	"tools": [{"kind": "laser", "type": 1}], "modules": [{"kind": "lance", "type": 1}]}
const GUNSHIP = {"ship": {"type": 2, "size": 1.0, "shares": {"structure": 0.55, "engine": 0.2, "reactor": 0.1, "capacitor": 0.05, "hold": 0.1}},
	"tools": [{"kind": "laser", "type": 2}, {"kind": "laser", "type": 2}], "modules": [{}, {}]}

var _container: Spatial = null
var _saved = []


func before_each():
	_container = Spatial.new()
	add_child_autofree(_container)
	_saved = [GlobalRefs.agent_container, GlobalRefs.asset_system, Engine.time_scale, Engine.iterations_per_second]
	GlobalRefs.agent_container = _container
	var assets = load("res://src/core/systems/asset_system.gd").new()
	add_child_autofree(assets)
	GlobalRefs.asset_system = assets


func after_each():
	GlobalRefs.agent_container = _saved[0]
	GlobalRefs.asset_system = _saved[1]
	Engine.time_scale = _saved[2]
	Engine.iterations_per_second = _saved[3]


func _ship(design: Dictionary, id: String, faction: String, at: Vector3) -> RigidBody:
	var genome: Dictionary = design.duplicate(true)
	var slot: String = Genome.slot_size(genome)
	for group in ["tools", "modules"]:
		for i in range(genome[group].size()):
			genome[group][i] = Genome._fitted(genome[group][i], slot)
	var built: Dictionary = Genome.build(genome, id, faction)
	var spawner = AgentSystemScript.new()
	autofree(spawner)
	var body = spawner.spawn_npc_from_template(Constants.NPC_BASE_TEMPLATE_PATH, at, {"faction": faction, "ship_template_id": built.ship_template_id, "fit": built.fit})
	body.get_node(Constants.AI_CONTROLLER_NODE_NAME).set_physics_process(false)  # Flown by the command alone
	return body


func test_strafe_only_under_the_guns_and_never_in_the_strike():
	assert_eq(CommandCharge.strafe_share(1500.0, 250.0, 1000.0), 0.0, "Out of its reach: straight in")
	assert_eq(CommandCharge.strafe_share(900.0, 250.0, 1000.0), 1.0, "Under its guns: the full strafe")
	assert_eq(CommandCharge.strafe_share(240.0, 250.0, 1000.0), 0.0, "In the strike: head-on")
	assert_between(CommandCharge.strafe_share(250.0 + Constants.NAV_CHARGE_STRAFE_EASE * 0.5, 250.0, 1000.0), 0.4, 0.6, "Easing out before it")
	assert_eq(CommandCharge.strafe_share(500.0, 250.0, 0.0), 0.0, "An unarmed target: straight in")


func test_a_charge_strafes_in_strikes_head_on_and_breaks_off_watching():
	Engine.iterations_per_second = 240
	Engine.time_scale = 4.0
	var lancer = _ship(LANCER, "charge_test_lancer", "verdant", Vector3(0, 0, 2500))
	var gunship = _ship(GUNSHIP, "charge_test_gunship", "violet", Vector3.ZERO)
	yield(get_tree(), "idle_frame")
	gunship.axis_lock_linear_x = true  # A sitting target
	gunship.axis_lock_linear_y = true
	gunship.axis_lock_linear_z = true
	lancer.set_lances_armed(true)
	lancer.command_charge(gunship)
	var nav = lancer.navigation_system
	var reach: float = lancer.weapon_reach_of(gunship)
	var nails: int = lancer.get_lance_nails()
	var strafed := 0.0  # Most degrees its velocity was off the line under the guns
	var strike_off := 0.0  # Most degrees off it in the strike, before the throw
	var watched_off := 0.0  # Most degrees its nose was off the target while breaking off
	var broke_off := false
	var came_back := false
	for i in range(240 * 15):  # 15 s of game time at most
		yield(get_tree(), "physics_frame")
		var to: Vector3 = gunship.global_transform.origin - lancer.global_transform.origin
		var distance: float = to.length()
		var velocity: Vector3 = lancer.linear_velocity
		var cmd: Dictionary = nav._current_command
		var off: float = rad2deg(velocity.angle_to(to)) if velocity.length() > 50.0 else 0.0
		if cmd.get("running_up", false):
			broke_off = true
			if distance > 200.0:
				watched_off = max(watched_off, rad2deg((-lancer.global_transform.basis.z).angle_to(to)))
		elif broke_off:
			came_back = true
			break
		elif lancer.get_lance_nails() == nails:
			if distance < reach * 0.8 and distance > 600.0:
				strafed = max(strafed, off)
			if distance < 230.0 and distance > 130.0:
				strike_off = max(strike_off, off)
	assert_gt(strafed, Constants.NAV_CHARGE_STRAFE_ANGLE * 0.6, "Under its guns it came in across them")
	assert_lt(strike_off, 20.0, "In the strike, head-on (passing beside its hull)")
	assert_lt(lancer.get_lance_nails(), nails, "It threw")
	assert_true(broke_off, "and broke off")
	assert_lt(watched_off, 30.0, "its nose kept on the target")
	assert_true(came_back, "then came in again")
