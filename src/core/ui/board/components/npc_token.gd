# PROJECT: GDTLancer
# MODULE: npc_token.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 02:10:00

extends PanelContainer
class_name NPCToken

signal token_clicked(npc_id)

var npc_id: String = ""

var name_label: Label = null
var bond_label: Label = null
var tags_label: Label = null

func _ready() -> void:
	name_label = get_node_or_null("VBoxContainer/NameLabel") as Label
	bond_label = get_node_or_null("VBoxContainer/BondLabel") as Label
	tags_label = get_node_or_null("VBoxContainer/TagsLabel") as Label
	
	var button = get_node_or_null("VBoxContainer/SelectButton") as Button
	if button != null:
		button.connect("pressed", self, "_on_button_pressed")
		
	update_display()

func setup_token(p_npc_id: String) -> void:
	npc_id = p_npc_id
	update_display()

func update_display() -> void:
	if npc_id.empty() or not GameState.npc_data.has(npc_id):
		if name_label != null:
			name_label.text = "Unknown NPC"
		if bond_label != null:
			bond_label.text = "[NONE]"
		if tags_label != null:
			tags_label.text = ""
		return
		
	var data: Dictionary = GameState.npc_data[npc_id]
	var display_name: String = data.get("display_name", npc_id)
	var bond: String = data.get("bond_strength", "NONE")
	var tags: Array = data.get("tags", [])
	
	var mod: int = 0
	match bond:
		"FRAGILE": mod = 1
		"STABLE": mod = 2
		"DEEP": mod = 3
		_: mod = 0
		
	if name_label != null:
		name_label.text = display_name
	if bond_label != null:
		bond_label.text = "[" + bond + " (+" + str(mod) + ")]"
	if tags_label != null:
		if tags.empty():
			tags_label.text = ""
		else:
			tags_label.text = "Tags: " + str(tags)

func _on_button_pressed() -> void:
	emit_signal("token_clicked", npc_id)
