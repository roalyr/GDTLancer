##
## PROJECT: GDTLancer
## MODULE: test_station_menu.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TACTICAL_TODO.md TASK_1
## LOG_REF: 2026-05-27 04:30:42
##

extends "res://addons/gut/test.gd"

var ContractBoardScene = load("res://scenes/ui/menus/contract_board/ContractBoard.tscn")
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
	GameState.contract_cargo_supply.clear()
	GameState.contract_cargo_reserved.clear()
	GameState.contract_payment_supply.clear()
	GameState.contract_payment_reserved.clear()
	GameState.station_by_id.clear()


func test_station_menu_has_no_embedded_contract_board_surface_even_when_runtime_contracts_exist() -> void:
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

	assert_true(station_menu.get_node_or_null("Panel/VBoxContainer/ContractBoard") == null,
		"StationMenu should not embed a contract board once the global ContractBoard owns contract actions.")


func test_station_menu_contract_button_opens_remote_contract_board_without_mutating_contract_state() -> void:
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

	var root = Node.new()
	add_child_autofree(root)

	var contract_board = ContractBoardScene.instance()
	root.add_child(contract_board)

	var station_menu = StationMenuScene.instance()
	root.add_child(station_menu)
	station_menu._on_player_docked("sector_system_elace")
	yield(get_tree(), "idle_frame")

	assert_true(station_menu.get_node_or_null("Panel/VBoxContainer/ContractBoard") == null,
		"StationMenu should remain a docking-only shell instead of rendering embedded contract rows.")

	station_menu._on_contracts_pressed()
	yield(get_tree(), "idle_frame")

	var contract_board_panel: Panel = contract_board.get_node("Panel")
	assert_true(contract_board_panel.visible,
		"StationMenu Contracts button should open the global ContractBoard overlay.")
	assert_eq(GameState.player_claimed_occurrence_id, "",
		"Opening the global ContractBoard from StationMenu should not claim a contract directly.")
	assert_eq(GameState.player_cargo_tag, "EMPTY",
		"Opening the global ContractBoard from StationMenu should not load cargo.")


func test_station_menu_contract_button_does_not_claim_or_load_when_global_board_is_missing() -> void:
	GameState.runtime_contract_occurrences = {
		"runtime_contract:sector_system_elace:RAW": {
			"occurrence_id": "runtime_contract:sector_system_elace:RAW",
			"source_sector_id": "sector_system_elace",
			"target_sector_id": "sector_system_nyx",
			"required_cargo_tag": "RAW_COMMODITY",
			"reward_credits": 125,
			"status": "open",
			"player_displayable": true,
			"claimant_agent_id": "",
		},
	}
	GameState.runtime_contract_occurrences_by_source_sector = {
		"sector_system_elace": ["runtime_contract:sector_system_elace:RAW"],
	}
	GameState.agents["player"] = {
		"cargo_tag": "EMPTY",
		"current_sector_id": "sector_system_elace",
	}

	var station_menu = StationMenuScene.instance()
	add_child_autofree(station_menu)
	station_menu._on_player_docked("sector_system_elace")
	yield(get_tree(), "idle_frame")

	station_menu._on_contracts_pressed()

	assert_eq(GameState.player_claimed_occurrence_id, "",
		"StationMenu should not claim contracts directly when the global board is unavailable.")
	assert_eq(GameState.player_cargo_tag, "EMPTY",
		"StationMenu should not load cargo directly when the global board is unavailable.")
	assert_true(station_menu.visible,
		"StationMenu should remain open as a docking shell when the global board is unavailable.")


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
