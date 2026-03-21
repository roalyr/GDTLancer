#
# PROJECT: GDTLancer
# MODULE: radar_display.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT §7 Assets & Style Guide (UI: functional, monochromatic)
# LOG_REF: 2026-03-21
#

extends Control

## RadarDisplay: Contact roster panel showing all simulation agents in the
## player's current sector. Color-coded by disposition (green/yellow/red).
## Refreshes on sim_tick_completed via MainHUD calling refresh().

# --- Color Constants ---
const COLOR_FRIENDLY := Color(0.33, 1.0, 0.33)   # #55FF55
const COLOR_NEUTRAL := Color(1.0, 1.0, 0.33)      # #FFFF55
const COLOR_HOSTILE := Color(1.0, 0.33, 0.33)      # #FF5555
const COLOR_BG := Color(0.1, 0.1, 0.12, 0.85)

# --- Node References ---
onready var header_label: Label = $PanelBg/VBoxContainer/HeaderLabel
onready var sector_label: Label = $PanelBg/VBoxContainer/SectorLabel
onready var contact_list: VBoxContainer = $PanelBg/VBoxContainer/ContactList


func _ready() -> void:
	header_label.text = "SECTOR SCAN"
	sector_label.text = ""


func refresh(contact_manager) -> void:
	# Clear existing contact entries
	for child in contact_list.get_children():
		child.queue_free()

	var sector_info: Dictionary = contact_manager.get_current_sector_info()
	sector_label.text = sector_info.get("name", "Unknown Sector")

	var agents: Array = contact_manager.get_agents_in_player_sector()

	if agents.empty():
		var empty_label := Label.new()
		empty_label.text = "No contacts detected"
		empty_label.add_color_override("font_color", Color(0.5, 0.5, 0.5))
		contact_list.add_child(empty_label)
		return

	for agent_id in agents:
		var info: Dictionary = contact_manager.get_agent_info(agent_id)
		if info.empty():
			continue
		_create_contact_entry(info)


func _create_contact_entry(info: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL

	# Disposition color dot
	var dot := ColorRect.new()
	dot.rect_min_size = Vector2(12, 12)
	dot.color = _get_disposition_color(info.get("disposition_category", "neutral"))
	row.add_child(dot)

	# Name + Role label
	var name_label := Label.new()
	name_label.text = "%s - %s" % [info.get("name", "Unknown"), info.get("role", "idle").capitalize()]
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)

	# Condition indicator
	var condition_label := Label.new()
	condition_label.text = _get_condition_indicator(info.get("condition_tag", "HEALTHY"))
	condition_label.align = Label.ALIGN_RIGHT
	row.add_child(condition_label)

	contact_list.add_child(row)


func _get_disposition_color(category: String) -> Color:
	match category:
		"friendly":
			return COLOR_FRIENDLY
		"hostile":
			return COLOR_HOSTILE
		_:
			return COLOR_NEUTRAL


func _get_condition_indicator(condition_tag: String) -> String:
	match condition_tag:
		"DAMAGED":
			return "!"
		"DESTROYED":
			return "X"
		_:
			return "OK"
