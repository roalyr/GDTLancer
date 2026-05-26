##
## PROJECT: GDTLancer
## MODULE: test_station_menu.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: TRUTH_PROJECT.md § Project Stack and Context; TACTICAL_TODO.md TASK_6
## LOG_REF: 2026-05-26 17:38:00
##

extends "res://addons/gut/test.gd"

var StationMenuScene = load("res://scenes/ui/menus/station_menu/StationMenu.tscn")


func before_each() -> void:
	_seed_base_state()


func after_each() -> void:
	GameState.player_docked_at = ""
	GameState.player_claimed_occurrence_id = ""
	GameState.player_cargo_tag = "EMPTY"
	GameState.current_sector_id = ""
	GameState.player_character_uid = ""
	GameState.characters.clear()
	GameState.agents.clear()
	GameState.locations.clear()
	GameState.sector_names.clear()
	GameState.world_topology.clear()
	GameState.runtime_contract_occurrences.clear()
	GameState.runtime_contract_occurrences_by_source_sector.clear()
	GameState.runtime_contract_occurrences_by_target_sector.clear()
	GameState.station_by_id.clear()


func test_contract_board_lists_only_current_sector_source_occurrences() -> void:
	GameState.runtime_contract_occurrences = {
		"runtime_contract:sector_system_elace:RAW": {
			"occurrence_id": "runtime_contract:sector_system_elace:RAW",
			"source_sector_id": "sector_system_elace",
			"target_sector_id": "sector_system_nyx",
			"required_cargo_tag": "RAW_COMMODITY",
			"reward_credits": 125,
			"status": "open",
			"player_displayable": true,
		},
		"runtime_contract:sector_system_vidr:RAW": {
			"occurrence_id": "runtime_contract:sector_system_vidr:RAW",
			"source_sector_id": "sector_system_vidr",
			"target_sector_id": "sector_system_elace",
			"required_cargo_tag": "RAW_COMMODITY",
			"reward_credits": 140,
			"status": "open",
			"player_displayable": true,
		},
	}
	GameState.runtime_contract_occurrences_by_source_sector = {
		"sector_system_elace": ["runtime_contract:sector_system_elace:RAW"],
		"sector_system_vidr": ["runtime_contract:sector_system_vidr:RAW"],
	}

	var station_menu = StationMenuScene.instance()
	add_child_autofree(station_menu)
	station_menu._on_player_docked("sector_system_elace")
	yield(get_tree(), "idle_frame")

	var contract_list: VBoxContainer = station_menu.get_node("Panel/VBoxContainer/ContractBoard/ContractScroll/ContractList")
	assert_eq(contract_list.get_child_count(), 1,
		"Contract board should show only source-side occurrences for the current dock sector.")

	var row: HBoxContainer = contract_list.get_child(0)
	var entry_label: Label = row.get_node("EntryLabel")
	assert_true(entry_label.text.find("runtime_contract:sector_system_elace:RAW") != -1,
		"Contract board should include the current sector source occurrence.")
	assert_true(entry_label.text.find("runtime_contract:sector_system_vidr:RAW") == -1,
		"Contract board should exclude occurrences sourced from other sectors.")


func test_contract_row_accept_button_updates_player_contract_state() -> void:
	GameState.runtime_contract_occurrences = {
		"runtime_contract:sector_system_elace:CURRENCY": {
			"occurrence_id": "runtime_contract:sector_system_elace:CURRENCY",
			"source_sector_id": "sector_system_elace",
			"target_sector_id": "sector_system_nyx",
			"required_cargo_tag": "CURRENCY_COMMODITY",
			"reward_credits": 225,
			"status": "open",
			"player_displayable": true,
			"claimant_agent_id": "",
		},
	}
	GameState.runtime_contract_occurrences_by_source_sector = {
		"sector_system_elace": ["runtime_contract:sector_system_elace:CURRENCY"],
	}
	GameState.agents["player"] = {
		"cargo_tag": "EMPTY",
		"current_sector_id": "sector_system_elace",
	}

	var station_menu = StationMenuScene.instance()
	add_child_autofree(station_menu)
	station_menu._on_player_docked("sector_system_elace")
	yield(get_tree(), "idle_frame")

	var contract_list: VBoxContainer = station_menu.get_node("Panel/VBoxContainer/ContractBoard/ContractScroll/ContractList")
	var row: HBoxContainer = contract_list.get_child(0)
	var accept_button: Button = row.get_node("AcceptButton")
	accept_button.emit_signal("pressed")
	yield(get_tree(), "idle_frame")

	assert_eq(GameState.player_claimed_occurrence_id, "runtime_contract:sector_system_elace:CURRENCY",
		"Clicking Accept should claim the selected occurrence for the player.")
	assert_eq(GameState.player_cargo_tag, "LOADED",
		"Clicking Accept should load player contract cargo state.")
	assert_eq(str(GameState.runtime_contract_occurrences["runtime_contract:sector_system_elace:CURRENCY"].get("claimant_agent_id", "")), "player",
		"Accepted occurrence should set claimant_agent_id to player.")
	assert_eq(str(GameState.runtime_contract_occurrences["runtime_contract:sector_system_elace:CURRENCY"].get("status", "")), "in_transit",
		"Accepted occurrence should transition to in_transit.")


func test_contract_board_station_listing_shows_procedural_station_names() -> void:
	GameState.world_topology["sector_system_elace"]["station_ids"] = ["station_sector_system_elace"]
	GameState.station_by_id["station_sector_system_elace"] = {
		"display_name": "Elace Station",
	}

	var station_menu = StationMenuScene.instance()
	add_child_autofree(station_menu)
	station_menu._on_player_docked("sector_system_elace")
	yield(get_tree(), "idle_frame")

	var station_list_label: Label = station_menu.get_node("Panel/VBoxContainer/ContractBoard/StationListLabel")
	assert_true(station_list_label.text.find("Elace Station") != -1,
		"Station listing should include procedural station display names in the current sector.")


func _seed_base_state() -> void:
	GameState.player_docked_at = "sector_system_elace"
	GameState.current_sector_id = "sector_system_elace"
	GameState.player_claimed_occurrence_id = ""
	GameState.player_cargo_tag = "EMPTY"
	GameState.player_character_uid = "1"
	GameState.characters = {
		1: {"credits": 100, "focus_points": 3},
	}
	GameState.locations = {
		"sector_system_elace": {
			"location_name": "Elace System",
			"available_services": ["trade", "contracts"],
		},
	}
	GameState.sector_names = {
		"sector_system_elace": "Elace",
		"sector_system_vidr": "Vidr",
		"sector_system_nyx": "Nyx",
	}
	GameState.world_topology = {
		"sector_system_elace": {
			"connections": [],
			"sector_type": "colony",
			"station_ids": [],
		},
	}
	GameState.runtime_contract_occurrences.clear()
	GameState.runtime_contract_occurrences_by_source_sector.clear()
	GameState.runtime_contract_occurrences_by_target_sector.clear()
	GameState.station_by_id.clear()
