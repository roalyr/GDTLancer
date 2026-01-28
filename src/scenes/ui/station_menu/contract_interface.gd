#
# PROJECT: GDTLancer
# MODULE: contract_interface.gd
# STATUS: Level 2 - Implementation
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 7 Platform Mechanics Divergence)
# LOG_REF: 2026-01-27-Senior-Dev
#

extends Control

onready var list_contracts = $Panel/HBoxContainer/VBoxList/ItemListContracts
onready var text_details = $Panel/HBoxContainer/VBoxDetails/RichTextLabelDetails
onready var btn_accept = $Panel/HBoxControls/BtnAccept
onready var btn_close = $Panel/HBoxControls/BtnClose

var current_location_id: String = ""
var selected_contract_idx: int = -1

func _ready():
	btn_close.connect("pressed", self, "_on_close_pressed")
	btn_accept.connect("pressed", self, "_on_accept_pressed")
	list_contracts.connect("item_selected", self, "_on_contract_selected")

func open(location_id: String):
	current_location_id = location_id
	visible = true
	refresh_list()

func refresh_list():
	list_contracts.clear()
	text_details.text = "Select a contract to view details."
	selected_contract_idx = -1
	btn_accept.disabled = true
	
	if GlobalRefs.contract_system:
		var contracts = GlobalRefs.contract_system.get_available_contracts_for_character(GameState.player_character_uid, current_location_id)
		
		for contract in contracts:
			var text = "%s (%s)" % [contract.title, contract.contract_type]
			list_contracts.add_item(text)
			# Store template_id as metadata
			list_contracts.set_item_metadata(list_contracts.get_item_count() - 1, contract.template_id)

func _on_contract_selected(index):
	selected_contract_idx = index
	btn_accept.disabled = false
	
	var contract_id = list_contracts.get_item_metadata(index)
	if GameState.contracts.has(contract_id):
		var contract = GameState.contracts[contract_id]
		_display_contract_details(contract)

func _display_contract_details(contract):
	var details = "Title: %s\n" % contract.title
	details += "Type: %s\n" % contract.contract_type
	details += "Difficulty: %d\n" % contract.difficulty
	details += "Reward: %d Credits\n" % contract.reward_credits
	details += "Time Limit: %d seconds\n\n" % contract.time_limit_seconds
	details += "Description:\n%s\n\n" % contract.description
	
	if contract.contract_type == "delivery":
		details += "Cargo Required: %s (Qty: %d)\n" % [contract.required_commodity_id, contract.required_quantity]
		details += "Destination: %s\n" % contract.destination_location_id
	
	text_details.text = details

func _on_accept_pressed():
	print("DEBUG: _on_accept_pressed called. Selected Idx: ", selected_contract_idx)
	if selected_contract_idx == -1: return
	var contract_id = list_contracts.get_item_metadata(selected_contract_idx)
	print("DEBUG: Contract ID from metadata: ", contract_id)
	
	if GlobalRefs.contract_system:
		print("DEBUG: ContractSystem found. Calling accept_contract...")
		var result = GlobalRefs.contract_system.accept_contract(GameState.player_character_uid, contract_id)
		if result.success:
			print("Accepted contract: ", contract_id)
			refresh_list()
		else:
			print("Failed to accept contract: ", result.reason)
			text_details.text += "\n\nERROR: " + result.reason
	else:
		print("DEBUG: GlobalRefs.contract_system is NULL")

func _on_close_pressed():
	visible = false
