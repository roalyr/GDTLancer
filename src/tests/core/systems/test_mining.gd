# Tests for mining (Constants MINING): a lance breaks 1 to 3 crusted OreChunks off a rock and stays
# in it as a LooseLance to harpoon out; a laser burns a chunk's crust off, the ore cools, and only
# then does a harpoon take it.

extends GutTest

const AgentScript = preload("res://src/core/agents/agent.gd")
const LanceScript = preload("res://src/core/agents/components/lance_controller.gd")
const ShipLaws = preload("res://src/core/systems/ship_laws.gd")
const AsteroidScene = preload("res://scenes/prefabs/celestial/asteroid.tscn")
const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")

var rock: StaticBody = null
var miner: RigidBody = null
var lance: Spatial = null


func before_each():
	rock = AsteroidScene.instance()
	add_child_autofree(rock)
	rock.scale = Vector3.ONE * 30.0
	rock.deposit = 20
	miner = AgentScript.new()
	add_child_autofree(miner)
	miner.global_transform.origin = Vector3(0, 0, 200)
	miner.mass = 6000.0
	lance = LanceScript.new()
	miner.add_child(lance)
	lance.setup(miner, "test_lance", ShipLaws.lance_stats(Constants.PART_TYPE_SEEDS.lance[2]))


func _strike(speed: float = 200.0) -> Array:
	miner.linear_velocity = Vector3(0, 0, -speed)
	lance.nails -= 1  # Thrown (LanceController.fire)
	var damage: float = lance.strike_rock(rock, Vector3(0, 0, 20), Vector3(0, 0, 1), 0.0)
	var chunks: Array = []
	for node in get_tree().get_nodes_in_group("ore_chunk"):
		chunks.append(node)
	return [damage, chunks]


func test_a_lance_breaks_one_to_three_crusted_pieces_off_and_stays_in_the_rock():
	var result: Array = _strike()
	var damage: float = result[0]
	var chunks: Array = result[1]
	assert_gt(damage, 0.0)
	assert_almost_eq(miner.linear_velocity.z, -200.0, 0.01, "The ship is not stopped: it threw the lance")
	var units: int = int(clamp(round(damage / Constants.MINING_DAMAGE_PER_UNIT), 1, Constants.MINING_CHUNK_MAX))
	assert_between(chunks.size(), 1, Constants.MINING_PIECES_MAX)
	var total := 0
	for chunk in chunks:
		total += chunk.get_salvage_units()
		assert_true(chunk.is_wreck, "Salvaged like a wreck")
		assert_true(chunk.has_crust(), "Crusted")
		assert_eq(LanceScript.recoverable_from(chunk, miner), 0, "No lance in the pieces")
	assert_eq(total, units)
	assert_eq(rock.get_deposit(), 20 - units)
	var loose: Array = get_tree().get_nodes_in_group("loose_lance")
	assert_eq(loose.size(), 1, "The lance stays in the rock")
	assert_eq(loose[0].linear_velocity, Vector3.ZERO)
	assert_lt(loose[0].global_transform.origin.distance_to(Vector3(0, 0, 20)), float(lance.lance.length), "At the face it struck")
	assert_eq(loose[0].recoverable_lances_for(miner), 1, "Targetable, and harpooned back")
	assert_true(loose[0].recover_lance_into(miner))
	assert_eq(lance.nails, int(lance.lance.count))
	for node in chunks + loose:
		node.free()


func test_a_chunk_is_burnt_bare_cools_and_only_then_takes_a_harpoon():
	var chunks: Array = _strike()[1]
	var chunk = chunks[0]
	var tools = ToolControllerScript.new()
	tools.name = "ToolController"
	miner.add_child(tools)
	var laser = UtilityToolTemplate.new()
	laser.tool_type = "laser"
	var harpoon = UtilityToolTemplate.new()
	harpoon.tool_type = "harpoon"
	tools.set_tools([laser, harpoon])
	assert_true(tools.can_target(laser, chunk), "A laser on the crust")
	assert_false(tools.can_target(harpoon, chunk), "No harpoon yet")
	chunk.register_hit(Vector3(0, 0, 200), Constants.MINING_CRUST_HP * 0.5)
	assert_true(chunk.has_crust(), "Half burnt")
	chunk.register_hit(Vector3(0, 0, 200), Constants.MINING_CRUST_HP)
	assert_false(chunk.has_crust())
	assert_true(chunk.is_hot(), "Bared slag, glowing")
	assert_false(tools.can_target(laser, chunk), "Nothing left to burn")
	assert_false(tools.can_target(harpoon, chunk), "Too hot to take")
	chunk._process(Constants.MINING_COOL_TIME + 1.0)
	assert_true(chunk.is_ready_to_strip())
	assert_true(tools.can_target(harpoon, chunk), "Cooled: harpoon it")
	assert_false(chunk.get_node("Model").visible, "The rock gave way to the ore")
	assert_not_null(chunk.get_node_or_null("Ore"))
	assert_eq_deep(chunk.take_salvage(1), {Constants.MINING_DEPOSIT: 1})
	for node in chunks + get_tree().get_nodes_in_group("loose_lance"):
		node.free()


func test_a_worked_out_rock_glances_a_lance_off_to_drift():
	rock.deposit = 0
	var result: Array = _strike()
	assert_eq(result[0], 0.0)
	assert_true(result[1].empty())
	var loose: Array = get_tree().get_nodes_in_group("loose_lance")
	assert_eq(loose.size(), 1, "Glanced off: adrift, to harpoon")
	assert_gt(loose[0].linear_velocity.z, 0.0, "Off the face, back the way it came")
	assert_almost_eq(loose[0].linear_velocity.length(), 200.0 * Constants.LANCE_GLANCE_KEEP, 1.0)
	loose[0].free()
