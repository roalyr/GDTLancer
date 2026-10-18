# RadarDisplay: lists the agents present in the current zone.

extends Control

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


func refresh() -> void:
	# Clear existing contact entries
	for child in contact_list.get_children():
		child.queue_free()

	sector_label.text = _get_current_sector_name()

	var contacts: Array = _get_contacts_in_current_zone()
	if contacts.empty():
		var empty_label := Label.new()
		empty_label.text = "No contacts detected"
		empty_label.add_color_override("font_color", Color(0.5, 0.5, 0.5))
		contact_list.add_child(empty_label)
		return

	for agent_body in contacts:
		_create_contact_entry(agent_body)


func _get_current_sector_name() -> String:
	var template = TemplateDatabase.locations.get(GameState.current_sector_id)
	if template != null and template.location_name != "":
		return template.location_name
	return "Unknown Sector"


func _get_contacts_in_current_zone() -> Array:
	var contacts: Array = []
	if not is_instance_valid(GlobalRefs.current_zone):
		return contacts
	for agent_body in get_tree().get_nodes_in_group("agent_body"):
		if not is_instance_valid(agent_body) or agent_body == GlobalRefs.player_agent_body:
			continue
		if GlobalRefs.current_zone.is_a_parent_of(agent_body):
			contacts.append(agent_body)
	return contacts


func _create_contact_entry(agent_body: Node) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL

	# Disposition color dot
	var dot := ColorRect.new()
	dot.rect_min_size = Vector2(12, 12)
	dot.color = _get_disposition_color("hostile" if agent_body.get("is_hostile") else "neutral")
	row.add_child(dot)

	var name_label := Label.new()
	name_label.text = agent_body.name
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)

	contact_list.add_child(row)


func _get_disposition_color(category: String) -> Color:
	match category:
		"friendly":
			return COLOR_FRIENDLY
		"hostile":
			return COLOR_HOSTILE
		_:
			return COLOR_NEUTRAL
