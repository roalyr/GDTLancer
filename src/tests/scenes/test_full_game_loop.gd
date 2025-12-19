# File: tests/scenes/test_full_game_loop.gd
# Purpose: GUT integration test for the Phase 1 player journey.
# Version: 1.0

extends "res://addons/gut/test.gd"

const MainHUDScene = preload("res://scenes/ui/hud/main_hud.tscn")
const ContractSystemScript = preload("res://src/core/systems/contract_system.gd")
const TradingSystemScript = preload("res://src/core/systems/trading_system.gd")
const InventorySystemScript = preload("res://src/core/systems/inventory_system.gd")
const CharacterSystemScript = preload("res://src/core/systems/character_system.gd")
const AssetSystemScript = preload("res://src/core/systems/asset_system.gd")

const PLAYER_UID := 0
const PLAYER_SHIP_UID := 1
const LOCATION_ALPHA := "station_alpha"
const LOCATION_BETA := "station_beta"
const CONTRACT_ID := "delivery_01"

var _hud = null
var _contract_system = null
var _trading_system = null
var _inventory_system = null
var _character_system = null
var _asset_system = null


func before_each():
	_reset_game_state()
	_setup_systems()
	_setup_world_data()
	_setup_player()
	_setup_hud()


func after_each():
	if is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null

	if is_instance_valid(_contract_system):
		_contract_system.queue_free()
	if is_instance_valid(_trading_system):
		_trading_system.queue_free()
	if is_instance_valid(_inventory_system):
		_inventory_system.queue_free()
	if is_instance_valid(_character_system):
		_character_system.queue_free()
	if is_instance_valid(_asset_system):
		_asset_system.queue_free()

	_contract_system = null
	_trading_system = null
	_inventory_system = null
	_character_system = null
	_asset_system = null

	GlobalRefs.contract_system = null
	GlobalRefs.trading_system = null
	GlobalRefs.inventory_system = null
	GlobalRefs.character_system = null
	GlobalRefs.asset_system = null

	_reset_game_state()


func test_full_game_loop_delivery_trade_and_complete():
	# Start docked at Station Alpha.
	GameState.player_docked_at = LOCATION_ALPHA
	EventBus.emit_signal("player_docked", LOCATION_ALPHA)
	yield(yield_for(0.05), YIELD)

	var station_menu = _hud.station_menu_instance
	assert_true(is_instance_valid(station_menu), "Station menu should exist under HUD")
	assert_true(station_menu.visible, "Station menu should be visible when docked")
	assert_eq(station_menu.current_location_id, LOCATION_ALPHA)

	# Sprint 10: Player starts with empty cargo.
	assert_eq(
		_inventory_system.get_asset_count(PLAYER_UID, _inventory_system.InventoryType.COMMODITY, "commodity_ore"),
		0,
		"Player should start with 0 ore"
	)

	# Accept a delivery contract at Station Alpha.
	var accept_result = _contract_system.accept_contract(PLAYER_UID, CONTRACT_ID)
	assert_true(accept_result.success, "Contract acceptance should succeed")
	assert_true(GameState.active_contracts.has(CONTRACT_ID), "Contract should be active")

	# Trade: buy required cargo at Station Alpha.
	var buy_qty := 10
	var buy_result = _trading_system.execute_buy(PLAYER_UID, LOCATION_ALPHA, "commodity_ore", buy_qty)
	assert_true(buy_result.success, "Buying ore should succeed")
	assert_eq(
		_inventory_system.get_asset_count(PLAYER_UID, _inventory_system.InventoryType.COMMODITY, "commodity_ore"),
		buy_qty,
		"Cargo should contain the purchased ore"
	)
	assert_eq(
		GameState.locations[LOCATION_ALPHA].market_inventory["commodity_ore"].quantity,
		90,
		"Market inventory should decrement"
	)

	# Undock.
	EventBus.emit_signal("player_undocked")
	yield(yield_for(0.05), YIELD)
	assert_false(station_menu.visible, "Station menu should hide on undock")

	# Dock at destination.
	GameState.player_docked_at = LOCATION_BETA
	EventBus.emit_signal("player_docked", LOCATION_BETA)
	yield(yield_for(0.05), YIELD)
	assert_true(station_menu.visible, "Station menu should be visible at destination")
	assert_eq(station_menu.current_location_id, LOCATION_BETA)
	assert_true(station_menu.btn_complete_contract.visible, "Complete Contract button should be visible")

	# Complete contract via station menu (falls back to direct completion if narrative system missing).
	var wp_before: int = int(_character_system.get_wp(PLAYER_UID))
	station_menu._on_complete_contract_pressed()
	yield(yield_for(0.05), YIELD)

	assert_false(GameState.active_contracts.has(CONTRACT_ID), "Contract should be removed from active")
	assert_eq(
		_inventory_system.get_asset_count(PLAYER_UID, _inventory_system.InventoryType.COMMODITY, "commodity_ore"),
		0,
		"Contract completion should remove delivery cargo"
	)
	assert_eq(
		_character_system.get_wp(PLAYER_UID),
		wp_before + 100,
		"Contract completion should reward WP"
	)


# ---- Helpers ----

func _reset_game_state() -> void:
	GameState.characters.clear()
	GameState.inventories.clear()
	GameState.assets_ships.clear()
	GameState.assets_modules.clear()
	GameState.locations.clear()
	GameState.contracts.clear()
	GameState.active_contracts.clear()
	GameState.current_tu = 0
	GameState.player_character_uid = PLAYER_UID
	GameState.player_docked_at = ""
	GameState.narrative_state = {
		"reputation": 0,
		"faction_standings": {},
		"known_contacts": [],
		"chronicle_entries": []
	}
	GameState.session_stats = {
		"contracts_completed": 0,
		"total_wp_earned": 0,
		"total_wp_spent": 0,
		"enemies_disabled": 0,
		"time_played_tu": 0
	}


func _setup_systems() -> void:
	_contract_system = ContractSystemScript.new()
	add_child(_contract_system)
	GlobalRefs.contract_system = _contract_system

	_trading_system = TradingSystemScript.new()
	add_child(_trading_system)
	GlobalRefs.trading_system = _trading_system

	_inventory_system = InventorySystemScript.new()
	add_child(_inventory_system)
	GlobalRefs.inventory_system = _inventory_system

	_character_system = Node.new()
	_character_system.set_script(CharacterSystemScript)
	add_child(_character_system)
	GlobalRefs.character_system = _character_system

	_asset_system = Node.new()
	_asset_system.set_script(AssetSystemScript)
	add_child(_asset_system)
	GlobalRefs.asset_system = _asset_system


func _setup_world_data() -> void:
	# Locations
	var loc_alpha = LocationTemplate.new()
	loc_alpha.template_id = LOCATION_ALPHA
	loc_alpha.location_name = "Station Alpha"
	loc_alpha.market_inventory = {
		"commodity_ore": {"quantity": 100, "buy_price": 10, "sell_price": 8}
	}
	GameState.locations[LOCATION_ALPHA] = loc_alpha

	var loc_beta = LocationTemplate.new()
	loc_beta.template_id = LOCATION_BETA
	loc_beta.location_name = "Station Beta"
	GameState.locations[LOCATION_BETA] = loc_beta

	# Contract
	var contract = ContractTemplate.new()
	contract.template_id = CONTRACT_ID
	contract.contract_type = "delivery"
	contract.title = "Deliver Ore"
	contract.origin_location_id = LOCATION_ALPHA
	contract.destination_location_id = LOCATION_BETA
	contract.required_commodity_id = "commodity_ore"
	contract.required_quantity = 10
	contract.reward_wp = 100
	contract.reward_reputation = 0
	contract.reward_items = {}
	contract.time_limit_tu = -1
	GameState.contracts[CONTRACT_ID] = contract


func _setup_player() -> void:
	var player = CharacterTemplate.new()
	player.template_id = "player_test"
	player.character_name = "Player"
	player.wealth_points = 1000
	player.focus_points = 3
	player.active_ship_uid = PLAYER_SHIP_UID
	GameState.characters[PLAYER_UID] = player

	var ship = ShipTemplate.new()
	ship.template_id = "ship_test"
	ship.ship_model_name = "Test Ship"
	ship.cargo_capacity = 100
	GameState.assets_ships[PLAYER_SHIP_UID] = ship

	_inventory_system.create_inventory_for_character(PLAYER_UID)
	_inventory_system.add_asset(PLAYER_UID, _inventory_system.InventoryType.SHIP, PLAYER_SHIP_UID, 1)


func _setup_hud() -> void:
	_hud = MainHUDScene.instance()
	add_child(_hud)
