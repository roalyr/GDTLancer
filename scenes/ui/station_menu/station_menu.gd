extends Control

onready var label_station_name = $Panel/VBoxContainer/LabelStationName
onready var btn_trade = $Panel/VBoxContainer/BtnTrade
onready var btn_contracts = $Panel/VBoxContainer/BtnContracts
onready var btn_complete_contract = $Panel/VBoxContainer/BtnCompleteContract
onready var btn_undock = $Panel/VBoxContainer/BtnUndock

const TradeInterfaceScene = preload("res://scenes/ui/station_menu/TradeInterface.tscn")
const ContractInterfaceScene = preload("res://scenes/ui/station_menu/ContractInterface.tscn")
var trade_interface_instance = null
var contract_interface_instance = null

var current_location_id: String = ""
var completable_contract_id: String = ""

func _ready():
	visible = false
	EventBus.connect("player_docked", self, "_on_player_docked")
	EventBus.connect("player_undocked", self, "_on_player_undocked")
	
	btn_undock.connect("pressed", self, "_on_undock_pressed")
	btn_trade.connect("pressed", self, "_on_trade_pressed")
	btn_contracts.connect("pressed", self, "_on_contracts_pressed")
	btn_complete_contract.connect("pressed", self, "_on_complete_contract_pressed")
	
	trade_interface_instance = TradeInterfaceScene.instance()
	add_child(trade_interface_instance)
	trade_interface_instance.visible = false
	
	contract_interface_instance = ContractInterfaceScene.instance()
	add_child(contract_interface_instance)
	contract_interface_instance.visible = false

func _on_player_docked(location_id):
	current_location_id = location_id
	visible = true
	
	if label_station_name:
		label_station_name.text = "Docked at: " + location_id
	
	print("Station Menu Opened for: ", location_id)
	_check_completable_contracts()

func _check_completable_contracts():
	btn_complete_contract.visible = false
	completable_contract_id = ""
	
	if not GlobalRefs.contract_system:
		return
	
	var active_contracts = GlobalRefs.contract_system.get_active_contracts(GameState.player_character_uid)
	for contract in active_contracts:
		var result = GlobalRefs.contract_system.check_contract_completion(GameState.player_character_uid, contract.template_id)
		if result.can_complete:
			completable_contract_id = contract.template_id
			btn_complete_contract.text = "Complete: " + contract.title
			btn_complete_contract.visible = true
			break  # Only show one at a time for now

func _on_complete_contract_pressed():
	if completable_contract_id == "":
		return
	
	if GlobalRefs.contract_system:
		var result = GlobalRefs.contract_system.complete_contract(GameState.player_character_uid, completable_contract_id)
		if result.success:
			print("Contract Completed: ", completable_contract_id)
			# Show reward popup (TODO)
			_check_completable_contracts()  # Check if there are more
		else:
			print("Failed to complete contract: ", result.reason)

func _on_player_undocked():
	visible = false
	current_location_id = ""
	if trade_interface_instance:
		trade_interface_instance.visible = false
	if contract_interface_instance:
		contract_interface_instance.visible = false
	print("Station Menu Closed")

func _on_undock_pressed():
	EventBus.emit_signal("player_undocked")

func _on_trade_pressed():
	if trade_interface_instance:
		trade_interface_instance.open(current_location_id)

func _on_contracts_pressed():
	if contract_interface_instance:
		contract_interface_instance.open(current_location_id)
