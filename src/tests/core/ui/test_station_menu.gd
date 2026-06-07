##
## PROJECT: GDTLancer
## MODULE: test_station_menu.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: TRUTH_PROJECT.md § Compatibility Constraints; TACTICAL_TODO.md TASK_4; commodity_classification_architecture.md §6
## LOG_REF: 2026-06-06 00:55:00
##

extends "res://addons/gut/test.gd"

var ContractBoardScene = load("res://scenes/ui/menus/contract_board/ContractBoard.tscn")
var StationMenuScene = load("res://scenes/ui/menus/station_menu/StationMenu.tscn")

const CharacterSystem = preload("res://src/core/systems/character_system.gd")
const InventorySystem = preload("res://src/core/systems/inventory_system.gd")

var _char_sys: CharacterSystem
var _inv_sys: InventorySystem


func before_each() -> void:
	_char_sys = CharacterSystem.new()
	add_child_autofree(_char_sys)
	GlobalRefs.character_system = _char_sys

	_inv_sys = InventorySystem.new()
	add_child_autofree(_inv_sys)
	GlobalRefs.inventory_system = _inv_sys

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
	GlobalRefs.character_system = null
	GlobalRefs.inventory_system = null


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
	if GlobalRefs.inventory_system:
		GlobalRefs.inventory_system.create_inventory_for_character(1)
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
			"development_level": "colony",
			"station_ids": [],
		},
	}
	GameState.runtime_contract_occurrences.clear()
	GameState.runtime_contract_occurrences_by_source_sector.clear()
	GameState.runtime_contract_occurrences_by_target_sector.clear()
	GameState.station_by_id.clear()


func test_station_menu_gating_and_button_text() -> void:
	var station_menu = StationMenuScene.instance()
	add_child_autofree(station_menu)

	# 1. Test only lawful trade offered
	GameState.locations["sector_system_elace"] = {
		"location_name": "Elace System",
		"available_services": ["trade", "contracts"],
		"market_inventory": {},
	}
	station_menu._on_player_docked("sector_system_elace")
	yield(get_tree(), "idle_frame")

	assert_eq(station_menu._btn_trade.text, "Trade", "Button text should be 'Trade' when only lawful trade is offered.")
	
	station_menu._on_trade_pressed()
	assert_true(station_menu._market_section.visible, "Market section should be visible.")
	assert_eq(station_menu._label_market_header.text, "Market (Lawful)", "Header should read 'Market (Lawful)'.")

	# 2. Test only black market offered
	GameState.locations["sector_system_elace"] = {
		"location_name": "Elace System",
		"available_services": ["black_market", "contracts"],
		"market_inventory": {},
	}
	station_menu._on_player_docked("sector_system_elace")
	yield(get_tree(), "idle_frame")

	assert_eq(station_menu._btn_trade.text, "Access Black Market", "Button text should be 'Access Black Market' when only black market is offered.")
	
	station_menu._on_trade_pressed()
	assert_true(station_menu._market_section.visible, "Market section should be visible.")
	assert_eq(station_menu._label_market_header.text, "Black Market (Illicit)", "Header should read 'Black Market (Illicit)'.")

	# 3. Test both offered
	GameState.locations["sector_system_elace"] = {
		"location_name": "Elace System",
		"available_services": ["trade", "black_market", "contracts"],
		"market_inventory": {},
	}
	station_menu._on_player_docked("sector_system_elace")
	yield(get_tree(), "idle_frame")

	assert_eq(station_menu._btn_trade.text, "Trade", "Button text should be 'Trade' when both are offered.")
	
	station_menu._on_trade_pressed()
	assert_true(station_menu._market_section.visible, "Market section should be visible.")
	assert_eq(station_menu._label_market_header.text, "Market & Black Market", "Header should read 'Market & Black Market'.")

	# 4. Test neither offered
	GameState.locations["sector_system_elace"] = {
		"location_name": "Elace System",
		"available_services": ["contracts"],
		"market_inventory": {},
	}
	station_menu._on_player_docked("sector_system_elace")
	yield(get_tree(), "idle_frame")

	station_menu._on_trade_pressed()
	assert_false(station_menu._market_section.visible, "Market section should NOT be visible when neither trade nor black market is offered.")
	assert_true(station_menu._service_status_message.find("Trade is not offered") != -1, "Feedback message should be set.")


func test_station_menu_transaction_buy_and_sell() -> void:
	var station_menu = StationMenuScene.instance()
	add_child_autofree(station_menu)

	# Setup player character and inventory
	var player_uid = 1
	GameState.player_character_uid = str(player_uid)
	GameState.characters = {
		player_uid: {"credits": 100, "focus_points": 3},
	}
	if GlobalRefs.inventory_system:
		GlobalRefs.inventory_system.create_inventory_for_character(player_uid)
		var inv = GameState.inventories[player_uid][2]
		inv.clear()

	# Setup market inventory
	GameState.locations["sector_system_elace"] = {
		"location_name": "Elace System",
		"available_services": ["trade"],
		"market_inventory": {
			"commodity_ore": {
				"buy_price": 10,
				"sell_price": 8,
				"quantity": 5,
			}
		},
	}

	station_menu._on_player_docked("sector_system_elace")
	yield(get_tree(), "idle_frame")

	# Open trade
	station_menu._on_trade_pressed()
	yield(get_tree(), "idle_frame")

	# Verify UI elements generated
	assert_eq(station_menu._market_list.get_child_count(), 1, "There should be one row generated for commodity_ore.")
	var row = station_menu._market_list.get_child(0)
	var btn_buy: Button = row.get_child(4)
	var btn_sell: Button = row.get_child(5)

	assert_false(btn_buy.disabled, "Buy button should be enabled.")
	assert_true(btn_sell.disabled, "Sell button should be disabled as player has 0 ore.")

	# Perform buy
	btn_buy.emit_signal("pressed")
	yield(get_tree(), "idle_frame")

	# Assert credits reduced, player got asset, station quantity decremented
	var pc = GameState.characters[player_uid]
	assert_eq(pc.credits, 87, "Player credits should decrease by buy_price (13).")
	assert_eq(GlobalRefs.inventory_system.get_asset_count(player_uid, 2, "commodity_ore"), 1, "Player should have 1 commodity_ore in inventory.")
	assert_eq(GameState.locations["sector_system_elace"].market_inventory["commodity_ore"]["quantity"], 4, "Station commodity quantity should decrease to 4.")

	# Refresh UI is automatic, let's verify buttons state
	row = station_menu._market_list.get_child(0)
	btn_buy = row.get_child(4)
	btn_sell = row.get_child(5)
	assert_false(btn_buy.disabled, "Buy button should remain enabled.")
	assert_false(btn_sell.disabled, "Sell button should now be enabled as player has 1 ore.")

	# Perform sell
	btn_sell.emit_signal("pressed")
	yield(get_tree(), "idle_frame")

	# Assert credits increased, player lost asset, station quantity incremented
	assert_eq(pc.credits, 98, "Player credits should increase by sell_price (11) to 98.")
	assert_eq(GlobalRefs.inventory_system.get_asset_count(player_uid, 2, "commodity_ore"), 0, "Player should have 0 commodity_ore in inventory.")
	assert_eq(GameState.locations["sector_system_elace"].market_inventory["commodity_ore"]["quantity"], 5, "Station commodity quantity should increase back to 5.")

	row = station_menu._market_list.get_child(0)
	btn_buy = row.get_child(4)
	btn_sell = row.get_child(5)
	assert_false(btn_buy.disabled, "Buy button should remain enabled.")
	assert_true(btn_sell.disabled, "Sell button should be disabled again.")


func test_station_menu_contraband_gating() -> void:
	# Pre-seed commodity templates
	var ore_temp = CommodityTemplate.new()
	ore_temp.template_id = "commodity_ore"
	ore_temp.commodity_name = "Ore"
	TemplateDatabase.assets_commodities["commodity_ore"] = ore_temp

	var contra_temp = CommodityTemplate.new()
	contra_temp.template_id = "commodity_contraband"
	contra_temp.commodity_name = "Contraband"
	TemplateDatabase.assets_commodities["commodity_contraband"] = contra_temp

	var player_uid = 100
	GameState.player_character_uid = player_uid
	var pc = {"credits": 1000, "focus_points": 5}
	GameState.characters[player_uid] = pc

	var station_menu = StationMenuScene.instance()
	add_child_autofree(station_menu)

	# 1. Station offers only trade (lawful)
	GameState.locations["sector_system_elace"] = {
		"location_name": "Elace System",
		"available_services": ["trade"],
		"market_inventory": {
			"commodity_ore": {"buy_price": 10, "sell_price": 5, "quantity": 5},
			"commodity_contraband": {"buy_price": 200, "sell_price": 150, "quantity": 5}
		}
	}
	station_menu._on_player_docked("sector_system_elace")
	yield(get_tree(), "idle_frame")
	station_menu._on_trade_pressed()
	yield(get_tree(), "idle_frame")

	# It should list commodity_ore but not commodity_contraband
	var rows = station_menu._market_list.get_children()
	assert_eq(rows.size(), 1, "Only 1 commodity should be listed under lawful trade.")
	assert_eq(rows[0].get_child(0).text, "Ore", "First listed item should be Ore.")

	# Close trade UI
	station_menu._on_trade_pressed()

	# 2. Station offers only black market
	GameState.locations["sector_system_elace"] = {
		"location_name": "Elace System",
		"available_services": ["black_market"],
		"market_inventory": {
			"commodity_ore": {"buy_price": 10, "sell_price": 5, "quantity": 5},
			"commodity_contraband": {"buy_price": 200, "sell_price": 150, "quantity": 5}
		}
	}
	station_menu._on_player_docked("sector_system_elace")
	yield(get_tree(), "idle_frame")
	station_menu._on_trade_pressed()
	yield(get_tree(), "idle_frame")

	# Both should be listed (Black market lists both legal ore and illegal contraband)
	rows = station_menu._market_list.get_children()
	assert_eq(rows.size(), 2, "Both commodities should be listed in the Black Market.")
	var names = []
	for r in rows:
		names.append(r.get_child(0).text)
	names.sort()
	assert_eq(names, ["Contraband", "Ore"], "Listed items should be Contraband and Ore.")

