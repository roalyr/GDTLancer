#
# PROJECT: GDTLancer
# MODULE: narrative_status_panel.gd
# STATUS: Level 3 - Verified
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 7 Platform Mechanics Divergence)
# LOG_REF: 2026-01-28-QA-Intern
#

extends Control

## UI panel for displaying player narrative information, including reputation,
## faction standings, ship quirks, and sector statistics.

# Node references (updated for new scene structure with Panel child)
onready var reputation_label: Label = $Panel/VBoxMain/ReputationLabel
onready var faction_container: VBoxContainer = $Panel/VBoxMain/SectionsContainer/FactionsColumn/FactionContainer
onready var quirks_container: VBoxContainer = $Panel/VBoxMain/SectionsContainer/QuirksColumn/QuirksContainer
onready var contracts_label: Label = $Panel/VBoxMain/SectionsContainer/StatsColumn/ContractsLabel
onready var button_close: Button = $Panel/VBoxMain/HBoxButtons/ButtonClose
onready var button_debug_quirk: Button = $Panel/VBoxMain/SectionsContainer/QuirksColumn/ButtonDebugAddQuirk


## Initializes connections and triggers the initial display update.
func _ready() -> void:
	# Connect signals from EventBus for reactive updates
	if EventBus:
		EventBus.connect("ship_quirk_added", self, "_on_ship_quirk_added")
		EventBus.connect("ship_quirk_removed", self, "_on_ship_quirk_removed")
		EventBus.connect("narrative_action_resolved", self, "_on_narrative_action_resolved")
		EventBus.connect("player_credits_changed", self, "_on_player_credits_changed")
		EventBus.connect("contract_completed", self, "_on_contract_completed")
	
	# Connect to internal visibility toggle
	connect("visibility_changed", self, "_on_visibility_toggled")
	
	# Signals are connected via .tscn [connection] entries, but we can also connect here
	# for safety in case the scene file was not updated:
	if button_close and not button_close.is_connected("pressed", self, "_on_ButtonClose_pressed"):
		button_close.connect("pressed", self, "_on_ButtonClose_pressed")
	if button_debug_quirk and not button_debug_quirk.is_connected("pressed", self, "_on_ButtonDebugAddQuirk_pressed"):
		button_debug_quirk.connect("pressed", self, "_on_ButtonDebugAddQuirk_pressed")


## Opens this screen and updates display.
func open_screen() -> void:
	update_display()
	self.show()


## Refreshes all sections of the narrative status display if visible.
func update_display() -> void:
	if not is_visible_in_tree():
		return
		
	_update_reputation()
	_update_factions()
	_update_quirks()
	_update_stats()


## Updates the Reputation label from GameState.
func _update_reputation() -> void:
	var rep: int = GameState.narrative_state.get("reputation", 0)
	reputation_label.text = "Reputation: " + str(rep)


## Clears and rebuilds the Faction standings list from GameState.
func _update_factions() -> void:
	# Clear existing children entries
	for child in faction_container.get_children():
		child.queue_free()
		
	var standings: Dictionary = GameState.narrative_state.get("faction_standings", {})
	if standings.empty():
		var lbl: Label = Label.new()
		lbl.text = "No known factions"
		faction_container.add_child(lbl)
		return
		
	for faction_id in standings:
		var val = standings[faction_id]
		var lbl: Label = Label.new()
		
		var display_name: String = str(faction_id).capitalize()
		if GameState.factions.has(faction_id):
			display_name = GameState.factions[faction_id].display_name
			
		lbl.text = display_name + ": " + str(val)
		faction_container.add_child(lbl)


## Rebuilds the ship quirks list for the player's active ship.
func _update_quirks() -> void:
	# Clear existing quirk entries
	for child in quirks_container.get_children():
		child.queue_free()
	
	# Retrieve player character and active ship UID
	var player_char_uid: int = GameState.player_character_uid
	if player_char_uid == -1 or not GameState.characters.has(player_char_uid):
		return
		
	var char_data = GameState.characters[player_char_uid]
	var ship_uid = char_data.get("active_ship_uid")
	
	if ship_uid == null or ship_uid == -1:
		return
		
	# Fetch quirks from the QuirkSystem if available
	var quirks: Array = []
	if is_instance_valid(GlobalRefs.quirk_system):
		quirks = GlobalRefs.quirk_system.get_quirks(ship_uid)
	
	if quirks.empty():
		var lbl: Label = Label.new()
		lbl.text = "None"
		quirks_container.add_child(lbl)
		return
		
	for q_id in quirks:
		var lbl: Label = Label.new()
		lbl.text = str(q_id).capitalize()
		quirks_container.add_child(lbl)


## Updates sector statistics from GameState session tracking.
func _update_stats() -> void:
	var completed: int = GameState.session_stats.get("contracts_completed", 0)
	var credits_earned: int = GameState.session_stats.get("total_credits_earned", 0)
	var enemies_disabled: int = GameState.session_stats.get("enemies_disabled", 0)
	
	contracts_label.text = "Contracts Completed: " + str(completed) + \
		"\nTotal Credits Earned: " + str(credits_earned) + \
		"\nCombat Victories: " + str(enemies_disabled)


## Triggered when the panel visibility changes; updates display if becoming visible.
func _on_visibility_toggled() -> void:
	if visible:
		update_display()


## Handles the close button press to hide the panel.
func _on_ButtonClose_pressed() -> void:
	self.hide()


## Debug button to add a random quirk to the player's ship.
func _on_ButtonDebugAddQuirk_pressed() -> void:
	var player_char_uid: int = GameState.player_character_uid
	if player_char_uid == -1 or not GameState.characters.has(player_char_uid):
		printerr("[NarrativeStatusPanel] No player character found for quirk debug")
		return
		
	var char_data = GameState.characters[player_char_uid]
	var ship_uid = char_data.get("active_ship_uid")
	
	if ship_uid == null or ship_uid == -1:
		printerr("[NarrativeStatusPanel] No active ship found for quirk debug")
		return
	
	# Add a sample quirk
	var sample_quirks = ["reliable", "temperamental", "fuel_efficient", "fast_but_fragile"]
	var quirk_to_add = sample_quirks[randi() % sample_quirks.size()]
	
	if is_instance_valid(GlobalRefs.quirk_system):
		var success = GlobalRefs.quirk_system.add_quirk(ship_uid, quirk_to_add)
		if success:
			print("[NarrativeStatusPanel] Debug: Added quirk '%s' to ship %d" % [quirk_to_add, ship_uid])
		else:
			print("[NarrativeStatusPanel] Debug: Quirk '%s' already exists or failed" % quirk_to_add)
	else:
		printerr("[NarrativeStatusPanel] QuirkSystem not available")


# --- Signal Handlers from EventBus ---

## Logic for when a quirk is added to any ship.
func _on_ship_quirk_added(_ship_uid: int, _quirk_id: String) -> void:
	if visible:
		_update_quirks()


## Logic for when a quirk is removed from any ship.
func _on_ship_quirk_removed(_ship_uid: int, _quirk_id: String) -> void:
	if visible:
		_update_quirks()


## Logic for when a narrative action is resolved, potentially affecting reputation.
func _on_narrative_action_resolved(_result: Dictionary) -> void:
	if visible:
		update_display()


## Refreshes stats when player credits change.
func _on_player_credits_changed(_new_val: int) -> void:
	if visible:
		_update_stats()


## Refreshes stats when a contract is completed.
func _on_contract_completed(_id: String, _success: bool) -> void:
	if visible:
		_update_stats()
