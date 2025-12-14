extends Control

onready var list_station = $Panel/HBoxContainer/VBoxStation/ItemListStation
onready var list_player = $Panel/HBoxContainer/VBoxPlayer/ItemListPlayer
onready var btn_buy = $Panel/HBoxControls/BtnBuy
onready var btn_sell = $Panel/HBoxControls/BtnSell
onready var btn_close = $Panel/HBoxControls/BtnClose

var current_location_id: String = ""
var selected_station_item_idx: int = -1
var selected_player_item_idx: int = -1

func _ready():
	btn_close.connect("pressed", self, "_on_close_pressed")
	btn_buy.connect("pressed", self, "_on_buy_pressed")
	btn_sell.connect("pressed", self, "_on_sell_pressed")
	
	list_station.connect("item_selected", self, "_on_station_item_selected")
	list_player.connect("item_selected", self, "_on_player_item_selected")

func open(location_id: String):
	current_location_id = location_id
	visible = true
	refresh_lists()

func refresh_lists():
	list_station.clear()
	list_player.clear()
	selected_station_item_idx = -1
	selected_player_item_idx = -1
	btn_buy.disabled = true
	btn_sell.disabled = true
	
	# Populate Station Market
	if GameState.locations.has(current_location_id):
		var location = GameState.locations[current_location_id]
		var market_inventory = location.get("market_inventory")
		
		if market_inventory:
			for comm_id in market_inventory:
				var item = market_inventory[comm_id]
				var text = "%s (Qty: %d) - %d WP" % [comm_id, item.quantity, item.price]
				list_station.add_item(text)
				list_station.set_item_metadata(list_station.get_item_count() - 1, comm_id)
	
	# Populate Player Inventory
	var player_uid = GameState.player_character_uid
	if GlobalRefs.inventory_system:
		var commodities = GlobalRefs.inventory_system.get_inventory_by_type(player_uid, GlobalRefs.inventory_system.InventoryType.COMMODITY)
		
		for comm_id in commodities:
			var qty = commodities[comm_id]
			# Get price from market if possible, else 0
			var sell_price = 0
			if GameState.locations.has(current_location_id):
				var loc = GameState.locations[current_location_id]
				var loc_market = loc.get("market_inventory")
				if loc_market and loc_market.has(comm_id):
					sell_price = loc_market[comm_id].price
			
			var text = "%s (Qty: %d) - Sell: %d WP" % [comm_id, qty, sell_price]
			list_player.add_item(text)
			list_player.set_item_metadata(list_player.get_item_count() - 1, comm_id)

func _on_station_item_selected(index):
	selected_station_item_idx = index
	list_player.unselect_all()
	selected_player_item_idx = -1
	btn_buy.disabled = false
	btn_sell.disabled = true

func _on_player_item_selected(index):
	selected_player_item_idx = index
	list_station.unselect_all()
	selected_station_item_idx = -1
	btn_buy.disabled = true
	btn_sell.disabled = false

func _on_buy_pressed():
	if selected_station_item_idx == -1: return
	var comm_id = list_station.get_item_metadata(selected_station_item_idx)
	
	# For now, buy 1 unit
	if GlobalRefs.trading_system:
		var result = GlobalRefs.trading_system.buy_commodity(GameState.player_character_uid, current_location_id, comm_id, 1)
		if result.success:
			print("Bought 1 ", comm_id)
			refresh_lists()
		else:
			print("Buy failed: ", result.reason)

func _on_sell_pressed():
	if selected_player_item_idx == -1: return
	var comm_id = list_player.get_item_metadata(selected_player_item_idx)
	
	# For now, sell 1 unit
	if GlobalRefs.trading_system:
		var result = GlobalRefs.trading_system.sell_commodity(GameState.player_character_uid, current_location_id, comm_id, 1)
		if result.success:
			print("Sold 1 ", comm_id)
			refresh_lists()
		else:
			print("Sell failed: ", result.reason)

func _on_close_pressed():
	visible = false
