# Tests for BeaconNetwork, Beacon and Hazard: heat from fire, routes round a hazard for the careful
# only, choices by job, and maydays.

extends GutTest

const NetworkScript = preload("res://src/scenes/game_world/sector_layout/beacon_network.gd")
const BeaconScript = preload("res://src/scenes/game_world/sector_layout/beacon.gd")
const HazardScript = preload("res://src/scenes/game_world/sector_layout/hazard.gd")

var network: Node = null


func before_each():
	network = NetworkScript.new()
	network.set_physics_process(false)  # Driven by hand
	add_child_autofree(network)


func _beacon(kind: String, at: Vector3, side: String = "") -> Node:
	var beacon = BeaconScript.new()
	beacon.kind = kind
	beacon.faction = side
	beacon.transform.origin = at
	network.add_child(beacon)
	network.register(beacon)
	return beacon


func _star() -> Node:
	var hazard = HazardScript.new()
	hazard.set_physics_process(false)
	network.add_child(hazard)
	network.register_hazard(hazard)
	return hazard


func _ship(job: String, faction: String = "verdant", caution: float = Constants.AI_AVOID_SHARE) -> Dictionary:
	return {"from": Vector3.ZERO, "speed": 150.0, "caution": caution, "hull_max": 120.0, "faction": faction, "job": job}


func test_radiation_grows_toward_the_star():
	var star = _star()
	assert_almost_eq(star.dps_at(Vector3(0, 0, 4000)), Constants.HAZARD_RADIATION_DPS, 0.001, "At the surface: all of it")
	assert_almost_eq(star.dps_at(Vector3(0, 0, 10000)), Constants.HAZARD_RADIATION_DPS * 0.25, 0.001, "Half way out: a quarter")
	assert_eq(star.dps_at(Vector3(0, 0, 16000)), 0.0, "None outside")
	assert_gt(star.exposure(Vector3(-20000, 0, 0), Vector3(20000, 0, 0)), 0.0, "Through it")
	assert_eq(star.exposure(Vector3(-20000, 0, 17000), Vector3(20000, 0, 17000)), 0.0, "Past it")


func test_careful_ships_go_round_the_star_and_fearless_ones_through():
	_star()
	_beacon("landmark", Vector3(-12000, 0, 17000))
	_beacon("landmark", Vector3(12000, 0, 17000))
	var from := Vector3(-20000, 0, 0)
	var to := Vector3(20000, 0, 0)
	var careful: Array = network.route(from, to, 150.0, Constants.AI_AVOID_SHARE, 120.0)
	assert_eq(careful.size(), 3, "By both beacons")
	assert_eq(careful.back(), to)
	assert_eq(network.route(from, to, 150.0, 0.0, 120.0), [to], "Straight through")


func test_fire_heats_the_nearest_beacon_and_heat_fades():
	var near = _beacon("patrol", Vector3(1000, 0, 0), "verdant")
	var far = _beacon("patrol", Vector3(20000, 0, 0), "verdant")
	var victim := Spatial.new()
	var script := GDScript.new()
	script.source_code = "extends Spatial\nvar hull_max = 100.0\n"
	script.reload()
	victim.set_script(script)
	add_child_autofree(victim)
	var shooter := Spatial.new()
	add_child_autofree(shooter)
	EventBus.emit_signal("agent_damaged", victim, 50.0, shooter)
	assert_almost_eq(near.heat, 0.5, 0.001, "Half the victim's hull")
	assert_eq(far.heat, 0.0)
	EventBus.emit_signal("agent_damaged", victim, 50.0, null)
	assert_almost_eq(near.heat, 0.5, 0.001, "No attacker: no heat")
	network._update(Constants.BEACON_HEAT_HALF_LIFE)
	assert_almost_eq(near.heat, 0.25, 0.001, "Halved in a half-life")
	assert_eq(near.get_beacon_cues(), ["VERDANT PATROL", "CALM", "QUIET"], "What the player reads")


func test_jobs_choose_their_beacons():
	var picket = _beacon("patrol", Vector3(5000, 0, 0), "verdant")
	var field = _beacon("field", Vector3(0, 0, 5000))
	var landmark = _beacon("landmark", Vector3(-5000, 0, 0))
	field.value = 2.0 * Constants.CHOICE_FIELD_VALUE
	assert_eq(network.choose(_ship("patrol")).beacon, picket, "A patrol to its own picket")
	assert_eq(network.choose(_ship("mine")).beacon, field, "A miner to the ore")
	picket.presence = {"verdant": 3}
	landmark.traffic = 2.0
	assert_eq(network.choose(_ship("hunt", "raiders")).beacon, landmark, "A raider to the busy beacon, not the guarded one")
	field.heat = 5.0
	field.value = 0.5 * Constants.CHOICE_FIELD_VALUE
	assert_eq(network.choose(_ship("scavenge")).beacon, field, "Scavengers to the fight's leavings")
	var hot_field_score: float = network.interest(field, _ship("mine", "verdant", 4.0 * Constants.AI_AVOID_SHARE))
	assert_lt(hot_field_score, network.interest(field, _ship("mine", "verdant", 0.0)), "A hot field draws careful miners less")


func test_no_beacon_is_cut_off_by_distance():
	var near = _beacon("landmark", Vector3(1000, 0, 0))
	var far = _beacon("field", Vector3(0, -90000, 0))
	far.value = 5.0 * Constants.CHOICE_FIELD_VALUE
	var planned: Dictionary = network.plan(Vector3.ZERO, 150.0, Constants.AI_AVOID_SHARE, 120.0)
	assert_lt(planned.cost[1], INF, "However far")
	assert_almost_eq(planned.cost[1], 90000.0 / 150.0, 1.0, "Straight there: nothing in the way")
	assert_eq(network.choose(_ship("mine")).beacon, far, "and worth going to")
	assert_eq(network.choose(_ship("mine")).path, [far.global_transform.origin], "directly")
	assert_ne(near, far)


func test_a_mayday_draws_its_patrols_and_their_enemies_then_goes():
	_beacon("patrol", Vector3(2000, 0, 0), "verdant")
	var mayday = network.call_distress("verdant", Vector3(8000, 0, 0), "Verdant VE-1")
	assert_eq(mayday.kind, "distress")
	assert_true(mayday.player_visible, "Heard on the common frequency")
	assert_eq(network.choose(_ship("patrol")).beacon, mayday, "Its patrols go to help")
	assert_gt(network.interest(mayday, _ship("patrol", "violet")), 0.0, "Its enemies weigh it as a raid")
	assert_eq(network.interest(mayday, _ship("patrol", "raiders")), Constants.CHOICE_RAID * (1.0 + mayday.heat), "raiders too (patrolling ones)")
	assert_eq(network.interest(mayday, _ship("mine")), 0.0, "Miners keep to their rocks")
	var serial: int = network.distress_serial
	assert_eq(network.call_distress("verdant", Vector3(9000, 0, 0), "Verdant VE-2"), mayday, "One near it is renewed")
	assert_gt(network.distress_serial, serial, "Patrols hear it again")
	network.time += Constants.DISTRESS_TIME + 1.0
	network._update(Constants.BEACON_UPDATE_INTERVAL)
	assert_false(mayday in network.beacons, "Gone once it expires")
	assert_eq(network.choose(_ship("patrol")).beacon.kind, "patrol", "Back to the pickets")
