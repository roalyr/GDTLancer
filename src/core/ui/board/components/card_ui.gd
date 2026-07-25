# PROJECT: GDTLancer
# MODULE: card_ui.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# LOG_REF: 2026-07-26 03:10:00

extends MarginContainer

signal card_pressed(card)

var card_resource: Resource = null
var is_selected: bool = false

onready var title_label: Label = $VBoxContainer/TitleLabel
onready var tags_label: Label = $VBoxContainer/TagsLabel
onready var panel: Panel = $BackgroundPanel
onready var button: Button = $ClickButton

func _ready() -> void:
	button.connect("pressed", self, "_on_button_pressed")
	update_visuals()

func set_card(card: Resource) -> void:
	card_resource = card
	
	if title_label:
		title_label.text = card.display_name if "display_name" in card else "Data-Slate"
	if tags_label:
		if "tags" in card and card.tags is Array:
			var tag_str = ""
			for t in card.tags:
				tag_str += "[" + t.to_upper() + "]\n"
			tags_label.text = tag_str
		else:
			tags_label.text = "[RAW DATA]"
	update_visuals()

func set_selected(selected: bool) -> void:
	is_selected = selected
	update_visuals()

func update_visuals() -> void:
	if not panel: return
	if is_selected:
		# Highlighted industrial chit
		panel.self_modulate = Color(0.8, 0.5, 0.1, 1.0)
	else:
		# Standard industrial chit
		panel.self_modulate = Color(0.3, 0.35, 0.4, 1.0)

func _on_button_pressed() -> void:
	emit_signal("card_pressed", card_resource)
