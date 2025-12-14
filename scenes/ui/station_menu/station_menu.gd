extends Control

onready var label_station_name = $Panel/VBoxContainer/LabelStationName
onready var btn_trade = $Panel/VBoxContainer/BtnTrade
onready var btn_contracts = $Panel/VBoxContainer/BtnContracts
onready var btn_complete_contract = $Panel/VBoxContainer/BtnCompleteContract
onready var btn_undock = $Panel/VBoxContainer/BtnUndock

onready var contract_popup = $ContractCompletePopup
onready var label_popup_info = $ContractCompletePopup/VBoxContainer/LabelPopupInfo
onready var btn_popup_ok = $ContractCompletePopup/VBoxContainer/BtnPopupOK

const TradeInterfaceScene = preload("res://scenes/ui/station_menu/TradeInterface.tscn")
const ContractInterfaceScene = preload("res://scenes/ui/station_menu/ContractInterface.tscn")
var trade_interface_instance = null
var contract_interface_instance = null

var current_location_id: String = ""
var completable_contract_id: String = ""
var completable_contract_title: String = ""

func _ready():
	visible = false
	EventBus.connect("player_docked", self, "_on_player_docked")
	EventBus.connect("player_undocked", self, "_on_player_undocked")
	
	btn_undock.connect("pressed", self, "_on_undock_pressed")
	btn_trade.connect("pressed", self, "_on_trade_pressed")
	btn_contracts.connect("pressed", self, "_on_contracts_pressed")
	btn_complete_contract.connect("pressed", self, "_on_complete_contract_pressed")
	btn_popup_ok.connect("pressed", self, "_on_popup_ok_pressed")
	
	trade_interface_instance = TradeInterfaceScene.instance()
	add_child(trade_interface_instance)
	trade_interface_instance.visible = false
	
	contract_interface_instance = ContractInterfaceScene.instance()
	add_child(contract_interface_instance)
	contract_interface_instance.visible = false

func _on_player_docked(location_id):
	current_location_id = location_id
	visible = true
	
	# Get station name from location data
	var station_name = location_id
	if GameState.locations.has(location_id):
		var loc = GameState.locations[location_id]
		if loc.location_name != "":
			station_name = loc.location_name
	
	if label_station_name:
		label_station_name.text = station_name
	
	print("Station Menu Opened for: ", location_id)
	_check_completable_contracts()

func _check_completable_contracts():
	btn_complete_contract.visible = false
	completable_contract_id = ""
	completable_contract_title = ""
	
	if not GlobalRefs.contract_system:
		print("StationMenu: ContractSystem not available")
		return
	
	print("StationMenu: Checking contracts for player uid: ", GameState.player_character_uid)
	print("StationMenu: Player docked at: '", GameState.player_docked_at, "'")
	
	var active_contracts = GlobalRefs.contract_system.get_active_contracts(GameState.player_character_uid)
	print("StationMenu: Found ", active_contracts.size(), " active contracts")
	
	for contract in active_contracts:
		print("StationMenu: Checking contract '", contract.title, "' - destination: '", contract.destination_location_id, "'")
		var result = GlobalRefs.contract_system.check_contract_completion(GameState.player_character_uid, contract.template_id)
		print("StationMenu: Can complete: ", result.can_complete, ", Reason: ", result.get("reason", ""))
		if result.can_complete:
			completable_contract_id = contract.template_id
			completable_contract_title = contract.title
			btn_complete_contract.text = "✓ Complete: " + contract.title
			btn_complete_contract.visible = true
			
			# Show a popup to notify player they can complete the contract
			_show_contract_ready_popup(contract)
			break

func _show_contract_ready_popup(contract):
	if contract_popup and label_popup_info:
		label_popup_info.text = "You can complete:\n\n[%s]\n\nReward: %d WP" % [contract.title, contract.reward_wp]
		contract_popup.popup_centered()

func _on_popup_ok_pressed():
	if contract_popup:
		contract_popup.hide()

func _on_complete_contract_pressed():
	if completable_contract_id == "":
		return
	
	if GlobalRefs.contract_system:
		var result = GlobalRefs.contract_system.complete_contract(GameState.player_character_uid, completable_contract_id)
		if result.success:
			print("Contract Completed: ", completable_contract_id)
			# Show completion popup
			if contract_popup and label_popup_info:
				var rewards = result.get("rewards", {})
				var wp_earned = rewards.get("wp", 0)
				label_popup_info.text = "Contract Complete!\n\n[%s]\n\nEarned: %d WP" % [completable_contract_title, wp_earned]
				contract_popup.popup_centered()
			_check_completable_contracts()
		else:
			print("Failed to complete contract: ", result.reason)

func _on_player_undocked():
	visible = false
	current_location_id = ""
	if trade_interface_instance:
		trade_interface_instance.visible = false
	if contract_interface_instance:
		contract_interface_instance.visible = false
	if contract_popup:
		contract_popup.hide()
	print("Station Menu Closed")

func _on_undock_pressed():
	EventBus.emit_signal("player_undocked")

func _on_trade_pressed():
	if trade_interface_instance:
		trade_interface_instance.open(current_location_id)

func _on_contracts_pressed():
	if contract_interface_instance:
		contract_interface_instance.open(current_location_id)
