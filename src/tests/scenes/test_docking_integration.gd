extends "res://addons/gut/test.gd"

var ZoneScene = load("res://scenes/levels/zones/zone1/basic_flight_zone.tscn")
var StationMenuScene = load("res://scenes/ui/menus/station_menu/StationMenu.tscn")
var PlayerControllerScript = load("res://src/modules/piloting/player_controller_ship.gd")
var ContractSystemScript = load("res://src/core/systems/contract_system.gd")
var InventorySystemScript = load("res://src/core/systems/inventory_system.gd")

func test_full_docking_loop():
	# Clear GameState to ensure clean slate
	GameState.active_contracts.clear()
	GameState.contracts.clear()
	GameState.locations.clear()
	
	# 1. Setup World
	var zone = ZoneScene.instance()
	add_child(zone)
	
	# Setup Systems
	var contract_system = ContractSystemScript.new()
	add_child(contract_system)
	GlobalRefs.contract_system = contract_system
	
	var inventory_system = InventorySystemScript.new()
	add_child(inventory_system)
	GlobalRefs.inventory_system = inventory_system
	
	# Ensure GameState has the station location loaded (WorldGenerator usually does this)
	if not GameState.locations.has("station_alpha"):
		var loc_template = LocationTemplate.new()
		loc_template.template_id = "station_alpha"
		loc_template.location_name = "Station Alpha"
		loc_template.market_inventory = {"commodity_ore": {"price": 10, "quantity": 100}}
		GameState.locations["station_alpha"] = loc_template
		
	# Ensure GameState has contracts loaded
	if not GameState.contracts.has("delivery_01"):
		var contract = ContractTemplate.new()
		contract.template_id = "delivery_01"
		contract.title = "Test Contract"
		contract.origin_location_id = "station_alpha"
		contract.destination_location_id = "station_beta"
		contract.contract_type = "delivery"
		contract.required_commodity_id = "commodity_ore"
		contract.required_quantity = 10
		contract.reward_wp = 100
		contract.time_limit_tu = -1
		GameState.contracts["delivery_01"] = contract
	
	# Also add station_beta location for delivery destination
	if not GameState.locations.has("station_beta"):
		var loc_beta = LocationTemplate.new()
		loc_beta.template_id = "station_beta"
		loc_beta.location_name = "Station Beta"
		GameState.locations["station_beta"] = loc_beta
	
	# 2. Setup Player & HUD
	var hud = load("res://scenes/ui/hud/main_hud.tscn").instance()
	add_child(hud)
	
	# 3. Simulate Docking Signal
	EventBus.emit_signal("dock_available", "station_alpha")
	yield(yield_for(0.1), YIELD)
	
	# Verify Prompt
	assert_true(hud.docking_prompt.visible, "Docking prompt should be visible")
	
	# 4. Simulate Interact Press
	EventBus.emit_signal("player_interact_pressed")
	# The controller usually emits player_docked, but here we simulate the signal chain
	EventBus.emit_signal("player_docked", "station_alpha")
	yield(yield_for(0.1), YIELD)
	
	# Verify Station Menu Open
	var station_menu = hud.station_menu_instance
	assert_true(station_menu.visible, "Station Menu should be visible")
	assert_eq(station_menu.current_location_id, "station_alpha")
	
	# 5. Test Trade Interface
	station_menu._on_trade_pressed()
	yield(yield_for(0.1), YIELD)
	assert_true(station_menu.trade_interface_instance.visible, "Trade Interface should be visible")
	station_menu.trade_interface_instance._on_close_pressed()
	
	# 6. Test Contract Interface
	station_menu._on_contracts_pressed()
	yield(yield_for(0.1), YIELD)
	var contract_ui = station_menu.contract_interface_instance
	assert_true(contract_ui.visible, "Contract Interface should be visible")
	
	# Verify contract list population
	assert_gt(contract_ui.list_contracts.get_item_count(), 0, "Should list at least one contract")
	
	# Select and Accept - save contract_id BEFORE accepting (refresh clears the list)
	contract_ui._on_contract_selected(0)
	var contract_id = contract_ui.list_contracts.get_item_metadata(0)
	contract_ui._on_accept_pressed()
	
	# Verify Contract Accepted in GameState
	if not GameState.active_contracts.has(contract_id):
		gut.p("Active Contracts: " + str(GameState.active_contracts.keys()))
		gut.p("Expected contract_id: " + contract_id)
		
	assert_true(GameState.active_contracts.has(contract_id), "Contract should be in active_contracts")
	
	contract_ui._on_close_pressed()
	
	# 7. Undock
	station_menu._on_undock_pressed()
	yield(yield_for(0.1), YIELD)
	assert_false(station_menu.visible, "Station Menu should be hidden after undock")
	
	# 8. Simulate Travel & Completion
	# Add required cargo
	var inv_sys = GlobalRefs.inventory_system
	inv_sys.add_asset(GameState.player_character_uid, inv_sys.InventoryType.COMMODITY, "commodity_ore", 10)
	
	# Dock at destination
	# We need to update GameState.player_docked_at manually as the signal usually does it via PlayerController
	GameState.player_docked_at = "station_beta"
	EventBus.emit_signal("player_docked", "station_beta")
	yield(yield_for(0.1), YIELD)
	
	# Verify Complete Button
	assert_true(station_menu.visible, "Station Menu should be visible at dest")
	assert_true(station_menu.btn_complete_contract.visible, "Complete Contract button should be visible")
	
	# Complete
	station_menu._on_complete_contract_pressed()
	
	# Verify
	assert_false(GameState.active_contracts.has(contract_id), "Contract should be removed from active")
	
	# Cleanup
	GlobalRefs.contract_system = null
	GlobalRefs.inventory_system = null
	contract_system.free()
	inventory_system.free()
	zone.free()
	hud.free()
