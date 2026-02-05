#
# PROJECT: GDTLancer
# MODULE: src/core/ui/contacts_panel/contacts_panel.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-30.md Section 1.2
# LOG_REF: 2026-01-30
#

extends Control

onready var contact_list = $Panel/VBoxContainer/ScrollContainer/ContactList
onready var close_button = $Panel/VBoxContainer/ButtonClose

func _ready():
	close_button.connect("pressed", self, "_on_ButtonClose_pressed")
	EventBus.connect("contact_met", self, "_on_Contact_Met")
	visible = false

func open_screen() -> void:
	update_display()
	visible = true

func update_display() -> void:
	# Clear existing items
	for child in contact_list.get_children():
		child.queue_free()
		
	# Populate list
	for agent_id in GameState.persistent_agents:
		var state = GameState.persistent_agents[agent_id]
		if state.get("is_known", false):
			var entry = _build_contact_entry(agent_id, state)
			if entry:
				contact_list.add_child(entry)

	if contact_list.get_child_count() == 0:
		var label = Label.new()
		label.text = "No known contacts yet."
		label.align = Label.ALIGN_CENTER
		contact_list.add_child(label)

func _build_contact_entry(agent_id: String, state: Dictionary) -> Control:
	var agent_template = load("res://database/registry/agents/" + agent_id + ".tres")
	if not agent_template:
		return null
		
	var char_uid = state.get("character_uid", -1)
	var char_data = GameState.characters.get(char_uid)
	if not char_data:
		return null
		
	var entry_vbox = VBoxContainer.new()
	
	# Name and Status Row
	var header_hbox = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = "Name: " + char_data.character_name
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header_hbox.add_child(name_label)
	
	var status_label = Label.new()
	if state.get("is_disabled", false):
		status_label.text = "[DISABLED]"
		status_label.add_color_override("font_color", Color(1, 0, 0))
	else:
		status_label.text = "[ACTIVE]"
		status_label.add_color_override("font_color", Color(0, 1, 0))
	header_hbox.add_child(status_label)
	
	entry_vbox.add_child(header_hbox)
	
	# Info Row
	var info_label = Label.new()
	var faction_name = char_data.faction_id.replace("faction_", "").capitalize()
	var home = agent_template.home_location_id.replace("station_", "Station ").capitalize()
	info_label.text = "Faction: %s | Home: %s | Rel: %d" % [faction_name, home, state.get("relationship", 0)]
	info_label.add_color_override("font_color", Color(0.7, 0.7, 0.7))
	entry_vbox.add_child(info_label)
	
	# Description
	if char_data.description != "":
		var desc_label = Label.new()
		desc_label.text = char_data.description
		desc_label.autowrap = true
		desc_label.add_color_override("font_color", Color(0.5, 0.5, 0.5))
		entry_vbox.add_child(desc_label)
		
	# Separator
	var sep = HSeparator.new()
	entry_vbox.add_child(sep)
	
	return entry_vbox

func _on_ButtonClose_pressed() -> void:
	visible = false

func _on_Contact_Met(_agent_id) -> void:
	if visible:
		update_display()
