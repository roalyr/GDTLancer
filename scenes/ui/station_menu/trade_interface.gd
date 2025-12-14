extends Control

onready var list_station = $Panel/VBoxMain/HBoxContent/VBoxStation/ItemListStation
onready var list_player = $Panel/VBoxMain/HBoxContent/VBoxPlayer/ItemListPlayer
onready var btn_buy = $Panel/VBoxMain/HBoxControls/BtnBuy
onready var btn_sell = $Panel/VBoxMain/HBoxControls/BtnSell
onready var btn_close = $Panel/VBoxMain/HBoxControls/BtnClose
onready var label_wp = $Panel/VBoxMain/HBoxHeader/LabelWP
onready var label_status = $Panel/VBoxMain/LabelStatus
onready var rich_text_prices = $Panel/VBoxMain/HBoxContent/VBoxInfo/ScrollContainer/RichTextLabelPrices

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
	_update_wp_display()
	_clear_price_comparison()

func _update_wp_display():
	if label_wp and GlobalRefs.character_system:
		var wp = GlobalRefs.character_system.get_wp(GameState.player_character_uid)
		label_wp.text = "Wealth Points: %d WP" % wp

func _clear_price_comparison():
	if rich_text_prices:
		rich_text_prices.bbcode_text = "[center]Select an item to see prices at all stations.[/center]"

func refresh_lists():
	list_station.clear()
	list_player.clear()
	selected_station_item_idx = -1
	selected_player_item_idx = -1
	btn_buy.disabled = true
	btn_sell.disabled = true
	if label_status:
		label_status.text = "Select an item to trade"
	
	# Populate Station Market
	if GameState.locations.has(current_location_id):
		var location = GameState.locations[current_location_id]
		var market_inventory = location.get("market_inventory")
		
		if market_inventory:
			for comm_id in market_inventory:
				var item = market_inventory[comm_id]
				var buy_price = item.get("buy_price", item.get("price", 0))
				var qty = item.get("quantity", 0)
				var display_name = _get_commodity_display_name(comm_id)
				var text = "%s x%d - %d WP" % [display_name, qty, buy_price]
				list_station.add_item(text)
				list_station.set_item_metadata(list_station.get_item_count() - 1, comm_id)
	
	# Populate Player Inventory
	var player_uid = GameState.player_character_uid
	if GlobalRefs.inventory_system:
		var commodities = GlobalRefs.inventory_system.get_inventory_by_type(player_uid, GlobalRefs.inventory_system.InventoryType.COMMODITY)
		
		for comm_id in commodities:
			var qty = commodities[comm_id]
			# Get sell price from market
			var sell_price = 0
			if GameState.locations.has(current_location_id):
				var loc = GameState.locations[current_location_id]
				var loc_market = loc.get("market_inventory")
				if loc_market and loc_market.has(comm_id):
					sell_price = loc_market[comm_id].get("sell_price", loc_market[comm_id].get("price", 0))
			
			var display_name = _get_commodity_display_name(comm_id)
			var text = "%s x%d - %d WP" % [display_name, qty, sell_price]
			list_player.add_item(text)
			list_player.set_item_metadata(list_player.get_item_count() - 1, comm_id)

func _get_commodity_display_name(comm_id: String) -> String:
	if TemplateDatabase.assets_commodities.has(comm_id):
		var template = TemplateDatabase.assets_commodities[comm_id]
		if template and template.get("commodity_name"):
			return template.commodity_name
	var display_name = comm_id.replace("commodity_", "").capitalize()
	return display_name

func _generate_price_comparison(comm_id: String):
	if not rich_text_prices:
		return
	
	var display_name = _get_commodity_display_name(comm_id)
	var text = "[center][b]%s[/b][/center]\n\n" % display_name
	text += "[u]Prices at All Stations:[/u]\n\n"
	
	# Loop through all locations
	for loc_id in GameState.locations:
		var location = GameState.locations[loc_id]
		var loc_name = location.location_name if location.location_name != "" else loc_id
		var market = location.market_inventory
		
		if market.has(comm_id):
			var item = market[comm_id]
			var buy_price = item.get("buy_price", item.get("price", 0))
			var sell_price = item.get("sell_price", item.get("price", 0))
			var qty = item.get("quantity", 0)
			
			# Highlight current location
			if loc_id == current_location_id:
				text += "[color=yellow]► %s[/color]\n" % loc_name
			else:
				text += "%s\n" % loc_name
			
			text += "  Buy: [color=red]%d WP[/color]\n" % buy_price
			text += "  Sell: [color=green]%d WP[/color]\n" % sell_price
			text += "  Stock: %d\n\n" % qty
		else:
			if loc_id == current_location_id:
				text += "[color=yellow]► %s[/color]\n" % loc_name
			else:
				text += "%s\n" % loc_name
			text += "  [i]Not available[/i]\n\n"
	
	rich_text_prices.bbcode_text = text

func _on_station_item_selected(index):
	selected_station_item_idx = index
	list_player.unselect_all()
	selected_player_item_idx = -1
	btn_buy.disabled = false
	btn_sell.disabled = true
	
	var comm_id = list_station.get_item_metadata(index)
	_generate_price_comparison(comm_id)
	
	if label_status and GameState.locations.has(current_location_id):
		var loc = GameState.locations[current_location_id]
		var item = loc.market_inventory.get(comm_id, {})
		var buy_price = item.get("buy_price", item.get("price", 0))
		label_status.text = "Buy 1 %s for %d WP" % [_get_commodity_display_name(comm_id), buy_price]

func _on_player_item_selected(index):
	selected_player_item_idx = index
	list_station.unselect_all()
	selected_station_item_idx = -1
	btn_buy.disabled = true
	btn_sell.disabled = false
	
	var comm_id = list_player.get_item_metadata(index)
	_generate_price_comparison(comm_id)
	
	if label_status and GameState.locations.has(current_location_id):
		var loc = GameState.locations[current_location_id]
		var item = loc.market_inventory.get(comm_id, {})
		var sell_price = item.get("sell_price", item.get("price", 0))
		label_status.text = "Sell 1 %s for %d WP" % [_get_commodity_display_name(comm_id), sell_price]

func _on_buy_pressed():
	if selected_station_item_idx == -1:
		return
	var comm_id = list_station.get_item_metadata(selected_station_item_idx)
	
	if GlobalRefs.trading_system:
		var result = GlobalRefs.trading_system.execute_buy(GameState.player_character_uid, current_location_id, comm_id, 1)
		if result.success:
			refresh_lists()
			_update_wp_display()
			_generate_price_comparison(comm_id)
			label_status.text = "Bought 1 %s" % _get_commodity_display_name(comm_id)
		else:
			if label_status:
				label_status.text = result.reason

func _on_sell_pressed():
	if selected_player_item_idx == -1:
		return
	var comm_id = list_player.get_item_metadata(selected_player_item_idx)
	
	if GlobalRefs.trading_system:
		var result = GlobalRefs.trading_system.execute_sell(GameState.player_character_uid, current_location_id, comm_id, 1)
		if result.success:
			refresh_lists()
			_update_wp_display()
			_generate_price_comparison(comm_id)
			label_status.text = "Sold 1 %s" % _get_commodity_display_name(comm_id)
		else:
			if label_status:
				label_status.text = result.reason

func _on_close_pressed():
	visible = false
