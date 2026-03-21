#
# PROJECT: GDTLancer
# MODULE: src/tests/core/systems/test_contact_manager.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md v1.2 §4.5 (Social Graph), §6 (Architectural Map)
# LOG_REF: 2026-03-21
#

extends "res://addons/gut/test.gd"

var _contact_manager: Node = null


func before_each():
	GameState.reset_state()

	# Seed minimal world topology
	GameState.world_topology["station_alpha"] = {
		"connections": ["station_beta"],
		"station_ids": ["station_alpha"],
		"sector_type": "station",
	}
	GameState.world_topology["station_beta"] = {
		"connections": ["station_alpha"],
		"station_ids": ["station_beta"],
		"sector_type": "station",
	}

	# Seed player agent
	GameState.agents["player"] = {
		"current_sector_id": "station_alpha",
		"agent_role": "trader",
		"character_id": "player_char",
		"condition_tag": "HEALTHY",
		"wealth_tag": "COMFORTABLE",
		"cargo_tag": "EMPTY",
		"is_disabled": false,
	}
	GameState.agent_tags["player"] = ["TRADER"]

	# Seed NPC agents
	GameState.agents["npc_01"] = {
		"current_sector_id": "station_alpha",
		"agent_role": "military",
		"character_id": "char_01",
		"condition_tag": "HEALTHY",
		"wealth_tag": "WEALTHY",
		"cargo_tag": "LOADED",
		"is_disabled": false,
	}
	GameState.agent_tags["npc_01"] = ["MILITARY"]

	GameState.agents["npc_02"] = {
		"current_sector_id": "station_alpha",
		"agent_role": "pirate",
		"character_id": "char_02",
		"condition_tag": "DAMAGED",
		"wealth_tag": "BROKE",
		"cargo_tag": "EMPTY",
		"is_disabled": false,
	}
	GameState.agent_tags["npc_02"] = ["PIRATE"]

	GameState.agents["npc_03"] = {
		"current_sector_id": "station_beta",
		"agent_role": "hauler",
		"character_id": "char_03",
		"condition_tag": "HEALTHY",
		"wealth_tag": "COMFORTABLE",
		"cargo_tag": "LOADED",
		"is_disabled": false,
	}
	GameState.agent_tags["npc_03"] = ["HAULER"]

	GameState.agents["npc_04"] = {
		"current_sector_id": "station_beta",
		"agent_role": "trader",
		"character_id": "char_04",
		"condition_tag": "HEALTHY",
		"wealth_tag": "COMFORTABLE",
		"cargo_tag": "EMPTY",
		"is_disabled": false,
	}
	GameState.agent_tags["npc_04"] = ["TRADER"]

	# Seed characters (fallback names via GameState)
	GameState.characters["char_01"] = {"character_name": "Commander Voss"}
	GameState.characters["char_02"] = {"character_name": "Red Marko"}

	# Seed sector tags
	GameState.sector_tags["station_alpha"] = [
		"SECURE", "MILD", "CURRENCY_RICH", "MANUFACTURED_ADEQUATE",
	]
	GameState.colony_levels["station_alpha"] = "colony"
	GameState.sector_names["station_alpha"] = "Station Alpha"

	GameState.sector_tags["station_beta"] = [
		"CONTESTED", "HARSH", "RAW_RICH",
	]
	GameState.colony_levels["station_beta"] = "outpost"

	# Instance ContactManager
	var cm_script = load("res://src/core/systems/contact_manager.gd")
	_contact_manager = Node.new()
	_contact_manager.set_script(cm_script)
	add_child(_contact_manager)
	autoqfree(_contact_manager)


func after_each():
	_contact_manager = null
	GameState.reset_state()


# --- Tests ---

func test_get_player_sector_returns_current_sector():
	assert_eq(
		_contact_manager.get_player_sector(),
		"station_alpha",
		"Should return player's current_sector_id"
	)


func test_get_agents_in_sector_returns_correct_agents():
	_contact_manager._rebuild_caches()
	var alpha_agents = _contact_manager.get_agents_in_sector("station_alpha")
	var beta_agents = _contact_manager.get_agents_in_sector("station_beta")
	assert_eq(alpha_agents.size(), 2, "station_alpha should have 2 NPCs")
	assert_eq(beta_agents.size(), 2, "station_beta should have 2 NPCs")


func test_get_agents_excludes_player():
	_contact_manager._rebuild_caches()
	var agents = _contact_manager.get_agents_in_sector("station_alpha")
	assert_does_not_have(agents, "player", "Player should not appear in contact roster")


func test_get_agents_excludes_disabled():
	GameState.agents["npc_01"]["is_disabled"] = true
	_contact_manager._rebuild_caches()
	var agents = _contact_manager.get_agents_in_sector("station_alpha")
	assert_does_not_have(agents, "npc_01", "Disabled agents should be excluded")
	assert_eq(agents.size(), 1, "Only 1 active NPC should remain in station_alpha")


func test_get_agent_disposition_computes_affinity():
	# PIRATE actor viewing MILITARY target → PIRATE:MILITARY = -1.2 (hostile)
	GameState.agent_tags["player"] = ["PIRATE"]
	GameState.agent_tags["npc_01"] = ["MILITARY"]
	_contact_manager._rebuild_caches()
	var disposition = _contact_manager.get_agent_disposition("npc_01")
	assert_lt(disposition, 0.0, "PIRATE viewing MILITARY should yield negative disposition")


func test_get_disposition_category_friendly():
	# MILITARY actor viewing PIRATE target → MILITARY:PIRATE = +1.4 (friendly / seeks)
	GameState.agent_tags["player"] = ["MILITARY"]
	GameState.agent_tags["npc_02"] = ["PIRATE"]
	_contact_manager._rebuild_caches()
	var category = _contact_manager.get_disposition_category("npc_02")
	assert_eq(category, "friendly", "Score 1.4 should be above friendly threshold")


func test_get_disposition_category_hostile():
	# PIRATE actor viewing MILITARY target → PIRATE:MILITARY = -1.2 (hostile)
	GameState.agent_tags["player"] = ["PIRATE"]
	GameState.agent_tags["npc_01"] = ["MILITARY"]
	_contact_manager._rebuild_caches()
	var category = _contact_manager.get_disposition_category("npc_01")
	assert_eq(category, "hostile", "Score -1.2 should be below hostile threshold")


func test_get_agent_info_returns_display_dict():
	_contact_manager._rebuild_caches()
	var info = _contact_manager.get_agent_info("npc_01")
	assert_has(info, "agent_id")
	assert_has(info, "name")
	assert_has(info, "role")
	assert_has(info, "condition_tag")
	assert_has(info, "wealth_tag")
	assert_has(info, "cargo_tag")
	assert_has(info, "disposition")
	assert_has(info, "disposition_category")
	assert_has(info, "sector_id")
	assert_eq(info["agent_id"], "npc_01")
	assert_eq(info["name"], "Commander Voss", "Should resolve character name from GameState")
	assert_eq(info["role"], "military")
	assert_eq(info["condition_tag"], "HEALTHY")


func test_get_sector_info_returns_tags():
	var info = _contact_manager.get_sector_info("station_alpha")
	assert_has(info, "sector_id")
	assert_has(info, "economy_tags")
	assert_has(info, "security_tag")
	assert_has(info, "environment_tag")
	assert_has(info, "colony_level")
	assert_eq(info["sector_id"], "station_alpha")
	assert_eq(info["security_tag"], "SECURE")
	assert_eq(info["environment_tag"], "MILD")
	assert_eq(info["colony_level"], "colony")
	assert_true(info["economy_tags"].has("CURRENCY_RICH"), "Should parse economy tags")


func test_rebuild_caches_updates_on_tick():
	# Caches should be empty before rebuild
	var agents_before = _contact_manager.get_agents_in_sector("station_alpha")
	# After _ready connects, sim_initialized triggers rebuild — but we can test manual rebuild
	_contact_manager._rebuild_caches()
	var agents_after = _contact_manager.get_agents_in_sector("station_alpha")
	assert_eq(agents_after.size(), 2, "Caches should be populated after rebuild")
