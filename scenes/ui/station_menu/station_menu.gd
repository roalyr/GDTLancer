extends Control

onready var label_station_name = $Panel/VBoxContainer/LabelStationName
onready var btn_trade = $Panel/VBoxContainer/BtnTrade
onready var btn_contracts = $Panel/VBoxContainer/BtnContracts
onready var btn_undock = $Panel/VBoxContainer/BtnUndock

const TradeInterfaceScene = preload("res://scenes/ui/station_menu/TradeInterface.tscn")
const ContractInterfaceScene = preload("res://scenes/ui/station_menu/ContractInterface.tscn")
var trade_interface_instance = null
var contract_interface_instance = null

var current_location_id: String = ""

func _ready():
	visible = false
	EventBus.connect("player_docked", self, "_on_player_docked")
	EventBus.connect("player_undocked", self, "_on_player_undocked")
	
	btn_undock.connect("pressed", self, "_on_undock_pressed")
	btn_trade.connect("pressed", self, "_on_trade_pressed")
	btn_contracts.connect("pressed", self, "_on_contracts_pressed")
	
	trade_interface_instance = TradeInterfaceScene.instance()
	add_child(trade_interface_instance)
	trade_interface_instance.visible = false
	
	contract_interface_instance = ContractInterfaceScene.instance()
	add_child(contract_interface_instance)
	contract_interface_instance.visible = false

func _on_player_docked(location_id):
	current_location_id = location_id
	visible = true
	
	# In a real implementation, we'd fetch the station name from GameState.locations[location_id]
	# For now, just show the ID
	if label_station_name:
		label_station_name.text = "Docked at: " + location_id
	
	print("Station Menu Opened for: ", location_id)

func _on_player_undocked():
	visible = false
	current_location_id = ""
	if trade_interface_instance:
		trade_interface_instance.visible = false
	if contract_interface_instance:
		contract_interface_instance.visible = false
	print("Station Menu Closed")

func _on_undock_pressed():
	# The actual undocking logic (moving ship, etc) should be handled by a system listening to this signal
	EventBus.emit_signal("player_undocked")

func _on_trade_pressed():
	if trade_interface_instance:
		trade_interface_instance.open(current_location_id)

func _on_contracts_pressed():
	if contract_interface_instance:
		contract_interface_instance.open(current_location_id)
