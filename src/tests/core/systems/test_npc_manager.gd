# PROJECT: GDTLancer
# MODULE: test_npc_manager.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md
# LOG_REF: 2026-07-26 02:10:00

extends "res://addons/gut/test.gd"

const NPCManagerClass = preload("res://src/core/systems/npc_manager.gd")
const BoardActionLoopClass = preload("res://src/core/systems/board_action_loop.gd")

var npc_mgr: NPCManager
var action_loop: BoardActionLoop

func before_each():
	GameState.reset_state()
	npc_mgr = NPCManagerClass.new()
	action_loop = BoardActionLoopClass.new()
	action_loop._ready()

func after_each():
	if npc_mgr != null:
		npc_mgr.free()
		npc_mgr = null
	if action_loop != null:
		action_loop.free()
		action_loop = null

func test_register_and_retrieve_npc():
	var record = npc_mgr.register_npc("npc_corvus", "Commander Corvus", NPCManagerClass.BOND_STABLE, ["military", "station_lead"], ["VISIBLE"], "sector_star_elace")
	assert_eq(record["npc_id"], "npc_corvus")
	assert_eq(npc_mgr.get_bond_strength("npc_corvus"), NPCManagerClass.BOND_STABLE)
	assert_eq(npc_mgr.get_bond_modifier("npc_corvus"), 2)
	assert_true(npc_mgr.has_npc_tag("npc_corvus", "military"))
	assert_true(npc_mgr.has_status_flag("npc_corvus", "VISIBLE"))

func test_bond_strength_modifiers():
	npc_mgr.register_npc("npc_test", "Test NPC", NPCManagerClass.BOND_FRAGILE)
	assert_eq(npc_mgr.get_bond_modifier("npc_test"), 1)
	
	npc_mgr.set_bond_strength("npc_test", NPCManagerClass.BOND_DEEP)
	assert_eq(npc_mgr.get_bond_modifier("npc_test"), 3)

func test_bond_modifier_integration_with_action_check():
	npc_mgr.register_npc("npc_ally", "Ally NPC", NPCManagerClass.BOND_DEEP) # +3 mod
	var bond_mod = npc_mgr.get_bond_modifier("npc_ally")
	
	# Execute check with seeded dice [3, 3, 3] = 9 + 3 (bond_mod) = 12 against difficulty 10 -> success
	var result = action_loop.execute_check(10, [3, 3, 3], bond_mod)
	assert_eq(result["base_total"], 9)
	assert_eq(result["modifier"], 3)
	assert_eq(result["final_total"], 12)
	assert_true(result["success"])

func test_sector_npc_filtering():
	npc_mgr.register_npc("npc_1", "NPC 1", NPCManagerClass.BOND_FRAGILE, [], [], "sector_a")
	npc_mgr.register_npc("npc_2", "NPC 2", NPCManagerClass.BOND_STABLE, [], [], "sector_b")
	
	var in_a = npc_mgr.get_npcs_in_sector("sector_a")
	assert_eq(in_a.size(), 1)
	assert_eq(in_a[0]["npc_id"], "npc_1")
