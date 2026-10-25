# PromptDialog: a modal question with a few answers, in the main theme (HUD-style buttons). Blocks
# the pointer as a whole while it shows; frees itself once answered.
#     var prompt = PromptDialog.ask(self, "SAVE BEFORE EXIT?", "...", [["save", "SAVE AND EXIT"], ["cancel", "CANCEL"]])
#     prompt.connect("chosen", self, "_on_exit_chosen")

extends Control

signal chosen(choice)

const MainTheme = preload("res://assets/themes/main_theme.tres")


static func ask(parent: Node, title: String, text: String, choices: Array) -> Control:
	var prompt = load("res://src/core/ui/helpers/prompt_dialog.gd").new()
	prompt.build(title, text, choices)
	parent.add_child(prompt)
	return prompt


func build(title: String, text: String, choices: Array) -> void:
	name = "PromptDialog"
	theme = MainTheme
	pause_mode = Node.PAUSE_MODE_PROCESS
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = MOUSE_FILTER_STOP  # Modal: nothing behind it takes the pointer
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_constant_override("separation", 24)
	center.add_child(box)
	var title_label := Label.new()
	title_label.text = title.to_upper()
	title_label.align = Label.ALIGN_CENTER
	title_label.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(title_label)
	var text_label := Label.new()
	text_label.text = text
	text_label.align = Label.ALIGN_CENTER
	text_label.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(text_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGN_CENTER
	buttons.mouse_filter = MOUSE_FILTER_IGNORE
	buttons.add_constant_override("separation", 16)
	box.add_child(buttons)
	for choice in choices:
		var button := Button.new()
		button.text = str(choice[1]).to_upper()
		button.rect_min_size = Vector2(260, 64)
		button.mouse_filter = MOUSE_FILTER_STOP
		button.connect("pressed", self, "_on_choice", [choice[0]])
		buttons.add_child(button)


func _on_choice(choice) -> void:
	emit_signal("chosen", choice)
	queue_free()
