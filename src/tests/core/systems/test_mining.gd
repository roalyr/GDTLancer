# Tests for mining (Constants MINING): a laser bares a rock's shell, a lance breaks out an OreChunk with
# the lance in it, and a harpoon's salvage takes the lance back first, then the ore.

extends GutTest

const AgentScript = preload("res://src/core/agents/agent.gd")
const LanceScript = preload("res://src/core/agents/components/lance_controller.gd")
const ShipLaws = preload("res://src/core/systems/ship_laws.gd")
const AsteroidScene = preload("res://scenes/prefabs/celestial/asteroid.tscn")

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


func test_laser_hits_bare_the_shell_and_it_closes_again_in_time():
	assert_false(rock.is_exposed())
	rock.register_hit(Vector3(0, 0, 200), Constants.MINING_SHELL_HP * 0.5)
	assert_false(rock.is_exposed(), "Half burnt")
	rock.register_hit(Vector3(0, 0, 200), Constants.MINING_SHELL_HP)
	assert_true(rock.is_exposed())
	rock._physics_process(Constants.MINING_EXPOSED_TIME + 1.0)
	assert_false(rock.is_exposed(), "Closed again")


func test_a_lance_on_a_shut_rock_glances_off():
	miner.linear_velocity = Vector3(0, 0, -200)
	assert_eq(lance.strike_rock(rock, Vector3(0, 0, 20), Vector3(0, 0, 1), 0.0), 0.0)
	assert_eq(lance.nails, int(lance.lance.count), "No lance spent")


func test_a_lance_on_a_bared_rock_breaks_out_a_chunk_with_the_lance_in_it():
	rock.cut(Constants.MINING_SHELL_HP)
	miner.linear_velocity = Vector3(0, 0, -200)
	var damage: float = lance.strike_rock(rock, Vector3(0, 0, 20), Vector3(0, 0, 1), 0.0)
	assert_gt(damage, 0.0)
	assert_eq(lance.nails, int(lance.lance.count) - 1)
	assert_almost_eq(miner.linear_velocity.z, 0.0, 0.01, "Stopped against the rock")
	assert_false(rock.is_exposed(), "The shell closes after a chunk")
	var chunk = null
	for node in get_tree().get_nodes_in_group("ore_chunk"):
		chunk = node
	assert_not_null(chunk)
	var units: int = int(clamp(round(damage / Constants.MINING_DAMAGE_PER_UNIT), 1, Constants.MINING_CHUNK_MAX))
	assert_eq(chunk.get_salvage_units(), units)
	assert_eq(rock.get_deposit(), 20 - units)
	assert_true(chunk.is_wreck, "Salvaged like a wreck")
	assert_eq(chunk.recoverable_lances_for(miner), 1, "The lance comes back first")
	assert_true(chunk.recover_lance_into(miner))
	assert_eq(lance.nails, int(lance.lance.count))
	assert_eq_deep(chunk.take_salvage(2), {Constants.MINING_DEPOSIT: 2})
	chunk.free()


func test_a_worked_out_rock_cannot_be_bared():
	rock.deposit = 0
	rock.cut(Constants.MINING_SHELL_HP * 2.0)
	assert_false(rock.is_exposed())
