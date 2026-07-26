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

func _ready() -> void:
	var main_theme = load("res://assets/themes/main_theme.tres")
	if main_theme != null:
		theme = main_theme
	var btn = get_node_or_null("ClickButton") as Button
	if btn != null and not btn.is_connected("pressed", self, "_on_button_pressed"):
		btn.connect("pressed", self, "_on_button_pressed")
	update_visuals()

func set_card(card: Resource) -> void:
	card_resource = card
	update_visuals()

func set_selected(selected: bool) -> void:
	is_selected = selected
	update_visuals()

func update_visuals() -> void:
	var title_label = get_node_or_null("VBoxContainer/TitleLabel") as Label
	var tags_label = get_node_or_null("VBoxContainer/TagsLabel") as Label
	var panel = get_node_or_null("BackgroundPanel") as Panel
	
	if card_resource != null:
		if title_label != null:
			var c_name = card_resource.get("display_name")
			if c_name == null or str(c_name).empty():
				c_name = card_resource.get("card_id")
			if c_name == null or str(c_name).empty():
				c_name = "Asset Card"
			title_label.text = str(c_name).replace("_", " ").to_upper()
			
		if tags_label != null:
			var tag_list = card_resource.get("tags")
			if tag_list is Array and tag_list.size() > 0:
				var tag_str = ""
				for t in tag_list:
					tag_str += "[" + str(t).to_upper() + "] "
				tags_label.text = tag_str
			else:
				tags_label.text = "[ASSET]"

	if panel != null:
		if is_selected:
			panel.self_modulate = Color(0.9, 0.6, 0.2, 1.0)
		else:
			panel.self_modulate = Color(0.3, 0.35, 0.4, 1.0)

func _on_button_pressed() -> void:
	emit_signal("card_pressed", card_resource)
