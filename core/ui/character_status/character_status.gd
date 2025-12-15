extends Control

onready var label_skill_piloting: Label = $Panel/VBoxContainer/HBoxContent/VBoxStats/LabelSkillPiloting
onready var label_skill_trading: Label = $Panel/VBoxContainer/HBoxContent/VBoxStats/LabelSkillTrading
onready var list_contracts: ItemList = $Panel/VBoxContainer/HBoxContent/VBoxContracts/ItemListContracts
onready var text_details: RichTextLabel = $Panel/VBoxContainer/HBoxContent/VBoxContracts/RichTextLabelDetails
onready var btn_close: Button = $Panel/VBoxContainer/ButtonClose
onready var btn_add_wp: Button = $Panel/VBoxContainer/HBoxContent/VBoxStats/ButtonAddWP
onready var btn_add_fp: Button = $Panel/VBoxContainer/HBoxContent/VBoxStats/ButtonAddFP
onready var btn_trigger_encounter: Button = $Panel/VBoxContainer/HBoxContent/VBoxStats/ButtonTriggerEncounter

func _ready():
	GlobalRefs.set_character_status(self)
	btn_close.connect("pressed", self, "_on_ButtonClose_pressed")
	btn_add_wp.connect("pressed", self, "_on_ButtonAddWP_pressed")
	btn_add_fp.connect("pressed", self, "_on_ButtonAddFP_pressed")
	btn_trigger_encounter.connect("pressed", self, "_on_ButtonTriggerEncounter_pressed")
	list_contracts.connect("item_selected", self, "_on_contract_selected")
	
	# Listen for contract updates to refresh if open
	EventBus.connect("contract_accepted", self, "_on_contract_update")
	EventBus.connect("contract_completed", self, "_on_contract_update")
	EventBus.connect("contract_failed", self, "_on_contract_update")
	EventBus.connect("contract_abandoned", self, "_on_contract_update")

func open_screen():
	update_display()
	self.show()

func update_display():
	# Update Skills
	if GlobalRefs.character_system:
		var char_data = GlobalRefs.character_system.get_player_character()
		if char_data:
			var piloting_skill = char_data.skills.get("piloting", 0)
			var trading_skill = char_data.skills.get("trading", 0)
			label_skill_piloting.text = "Piloting: " + str(piloting_skill)
			label_skill_trading.text = "Trading: " + str(trading_skill)
	
	# Update Contracts
	refresh_contracts()

func refresh_contracts():
	list_contracts.clear()
	text_details.text = "Select a contract to view details."
	
	if GlobalRefs.contract_system:
		var active_contracts = GlobalRefs.contract_system.get_active_contracts(GameState.player_character_uid)
		
		for contract in active_contracts:
			var text = "%s (%s)" % [contract.title, contract.contract_type]
			list_contracts.add_item(text)
			# Store contract_id (template_id) as metadata
			list_contracts.set_item_metadata(list_contracts.get_item_count() - 1, contract.template_id)

func _on_contract_selected(index):
	var contract_id = list_contracts.get_item_metadata(index)
	if GameState.active_contracts.has(contract_id):
		var contract = GameState.active_contracts[contract_id]
		_display_contract_details(contract)

func _display_contract_details(contract):
	var details = "Title: %s\n" % contract.title
	details += "Type: %s\n" % contract.contract_type
	details += "Reward: %d WP\n" % contract.reward_wp
	details += "Time Limit: %d TU\n" % contract.time_limit_tu
	
	# Calculate remaining time
	if contract.time_limit_tu > 0 and contract.accepted_at_tu >= 0:
		var elapsed = GameState.current_tu - contract.accepted_at_tu
		var remaining = contract.time_limit_tu - elapsed
		details += "Time Remaining: %d TU\n" % remaining
	
	details += "\nDescription:\n%s\n\n" % contract.description
	
	if contract.contract_type == "delivery":
		details += "Cargo Required: %s (Qty: %d)\n" % [contract.required_commodity_id, contract.required_quantity]
		details += "Destination: %s\n" % contract.destination_location_id
		
		# Check progress
		var inv_count = 0
		if GlobalRefs.inventory_system:
			inv_count = GlobalRefs.inventory_system.get_asset_count(
				GameState.player_character_uid, 
				GlobalRefs.inventory_system.InventoryType.COMMODITY, 
				contract.required_commodity_id
			)
		details += "Current Cargo: %d / %d\n" % [inv_count, contract.required_quantity]
	
	text_details.text = details

func _on_contract_update(_a = null, _b = null):
	if visible:
		refresh_contracts()

func _on_ButtonClose_pressed():
	self.hide()

func _on_ButtonAddWP_pressed():
	if GlobalRefs.character_system:
		GlobalRefs.character_system.add_wp(GameState.player_character_uid, 10)

func _on_ButtonAddFP_pressed():
	if GlobalRefs.character_system:
		GlobalRefs.character_system.add_fp(GameState.player_character_uid, 1)


func _on_ButtonTriggerEncounter_pressed():
	"""Debug button: Forces an immediate combat encounter spawn."""
	if GlobalRefs.event_system and GlobalRefs.event_system.has_method("force_encounter"):
		GlobalRefs.event_system.force_encounter()
		print("[CharacterStatus] Debug: Forced encounter triggered")
	else:
		printerr("[CharacterStatus] EventSystem not available or missing force_encounter method")
