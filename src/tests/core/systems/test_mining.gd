# Tests for mining (Constants MINING): a lance breaks 1 to 3 crusted OreChunks off a rock and stays
# in it as a LooseLance to harpoon out; a laser burns a chunk's crust off, the ore cools, and only
# then does a harpoon take it.

extends GutTest

const PartCatalog = preload("res://src/tests/helpers/reference_parts.gd")  # Fixed reference genes, not the tunable catalogue

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
	lance.setup(miner, "test_lance", ShipLaws.lance_stats(PartCatalog.genes("lance", 2)))


func after_each():
	for child in get_children():
		if child.has_method("_update_puffs"):
			child.free()  # A wreck's explosion goes to its parent, here the test, which outlives the test


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


func test_a_harpoon_reels_in_a_loose_lance_and_a_chunk():
	var Tether = load("res://src/core/agents/components/tether.gd")
	var chunks: Array = _strike()[1]
	var loose = get_tree().get_nodes_in_group("loose_lance")[0]
	for body in [loose, chunks[0]]:
		var start: Vector3 = body.global_transform.origin
		var tether = Tether.new()
		tether.holder = miner
		tether.towed = body
		tether.length = 1.0
		tether.min_length = 1.0
		add_child_autofree(tether)
		tether._physics_process(0.1)
		yield(get_tree(), "physics_frame")
		yield(get_tree(), "physics_frame")
		var pull: Vector3 = (miner.global_transform.origin - start).normalized()
		assert_gt(body.linear_velocity.dot(pull), 0.0, "%s: pulled toward the ship, with no engine of its own" % body.name)
		tether.free()
	assert_lt(chunks[0].mass, 1000.0, "A chunk is light enough to tow")
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


# Chunks are capped (ORE_CHUNK_MAX): a strike past it breaks fewer, bigger pieces, and with no room
# the oldest chunk no ship holds goes; a held one stays.
func test_chunks_adrift_are_capped():
	rock.deposit = 1000
	var held = null
	for strike in range(Constants.ORE_CHUNK_MAX * 2):
		var before: int = rock.get_deposit()
		var chunks: Array = _strike()[1]
		var units := 0
		for chunk in chunks:
			if not chunk.is_queued_for_deletion():
				units += chunk.get_salvage_units()
		assert_true(get_tree().get_nodes_in_group("ore_chunk").size() <= Constants.ORE_CHUNK_MAX, "Never past the cap (strike %d)" % strike)
		if strike == 0:
			held = get_tree().get_nodes_in_group("ore_chunk")[0]
			var tools = ToolControllerScript.new()
			tools.name = "ToolController"
			miner.add_child(tools)
			var laser = UtilityToolTemplate.new()
			laser.tool_type = "laser"
			tools.set_tools([laser])
			tools._targets[0] = held  # A laser on it: held
		for loose in get_tree().get_nodes_in_group("loose_lance"):
			loose.free()
		lance.nails = int(lance.lance.count)
	assert_true(is_instance_valid(held) and not held.is_queued_for_deletion(), "The held chunk, the oldest, stays")
	assert_eq(get_tree().get_nodes_in_group("ore_chunk").size(), Constants.ORE_CHUNK_MAX)
	for chunk in get_tree().get_nodes_in_group("ore_chunk"):
		chunk.free()


func test_a_strike_with_room_for_one_keeps_all_its_ore_in_one_piece():
	rock.deposit = 1000
	var OreChunkScript = load("res://src/scenes/game_world/celestial/ore_chunk.gd")
	var fillers: Array = []
	for index in range(Constants.ORE_CHUNK_MAX - 1):
		var filler = OreChunkScript.new()
		filler.setup({"commodity_ore": 1}, null, 1.0)
		add_child(filler)
		fillers.append(filler)
	var result: Array = _strike()
	var fresh: Array = []
	for chunk in result[1]:
		if not chunk in fillers:
			fresh.append(chunk)
	assert_eq(fresh.size(), 1, "One slot left: one piece")
	assert_eq(fresh[0].get_salvage_units(), int(clamp(round(result[0] / Constants.MINING_DAMAGE_PER_UNIT), 1, Constants.MINING_CHUNK_MAX)), "holding the whole strike's ore")
	for chunk in get_tree().get_nodes_in_group("ore_chunk"):
		chunk.free()
	for loose in get_tree().get_nodes_in_group("loose_lance"):
		loose.free()


func test_chunk_models_are_low_poly():
	for path in Constants.MINING_CHUNK_MODELS:
		var model: Node = load(path).instance()
		var triangles := 0
		var nodes: Array = [model]
		while not nodes.empty():
			var node: Node = nodes.pop_back()
			nodes += node.get_children()
			if node is MeshInstance and node.mesh != null:
				triangles += node.mesh.get_faces().size() / 3
		model.free()
		assert_true(triangles > 0 and triangles <= Constants.MINING_CHUNK_TRIANGLES_MAX, "%s: %d triangles" % [path, triangles])


# A one-unit chunk: the harpoon strips its unit into the hold and lets go saying so; the bare chunk
# is gone, so there is nothing left to harpoon again.
func test_a_one_unit_chunk_is_stripped_whole_and_goes():
	var OreChunkScript = load("res://src/scenes/game_world/celestial/ore_chunk.gd")
	var PlayerController = load("res://src/modules/piloting/player_controller_ship.gd")
	var chunk = OreChunkScript.new()
	chunk.setup({Constants.MINING_DEPOSIT: 1}, null, 1.0)
	add_child(chunk)
	chunk.crust = 0.0
	chunk.heat = 0.0
	miner.ship_template = ShipTemplate.new()
	miner.cargo_capacity = 10
	var tools = ToolControllerScript.new()
	tools.name = "ToolController"
	miner.add_child(tools)
	var harpoon = UtilityToolTemplate.new()
	harpoon.tool_type = "harpoon"
	tools.set_tools([harpoon])
	tools._targets[0] = chunk
	tools._stripped[0] = 0
	var stub := GDScript.new()  # A cable already reeled in
	stub.source_code = "extends Node\nvar retracting = false\nvar launching = false\nvar snapped = false\nfunc is_reeled_in(): return true\nfunc start_retract(): retracting = true\n"
	stub.reload()
	var tether = Node.new()
	tether.set_script(stub)
	add_child_autofree(tether)
	tools._tethers[0] = tether
	watch_signals(tools)
	tools._process_harpoon(0, chunk)
	assert_eq(miner.get_cargo_units(), 1, "The unit is in the hold")
	assert_signal_emitted_with_parameters(tools, "tool_deactivated", [0, "stripped"])
	assert_eq(tools.get_stripped(0), 1)
	assert_string_contains(PlayerController.stripped_message(tools.get_stripped(0)), "1 unit into the hold")
	yield(get_tree(), "idle_frame")
	assert_false(is_instance_valid(chunk) and not chunk.is_queued_for_deletion(), "Stripped bare, the chunk is gone")
