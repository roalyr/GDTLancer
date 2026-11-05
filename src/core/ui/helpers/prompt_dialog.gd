# PromptDialog: the game's one prompt for every question and notice: a title, any text, and as many
# answers as it needs (one, OK, for a notice). scenes/ui/shared/prompt_dialog.tscn is its look, in
# the main theme (its frame: the theme's PanelContainer style; its hidden Choice button is the
# pattern for the answers). Blocks the pointer as a whole while it shows; frees itself once answered.
#     var prompt = PromptDialog.ask(self, "Save before exiting?", "...", [["save", "SAVE AND EXIT"], ["cancel", "CANCEL"]])
#     prompt.connect("chosen", self, "_on_exit_chosen")
#     PromptDialog.tell(self, "Saved", "THE GAME IS SAVED.")  # A notice: one OK

extends Control

signal chosen(choice)

const SCENE_PATH = "res://scenes/ui/shared/prompt_dialog.tscn"


static func ask(parent: Node, title: String, text: String, choices: Array) -> Control:
	var prompt = load(SCENE_PATH).instance()
	prompt.build(title, text, choices)
	parent.add_child(prompt)
	return prompt


# A notice: `text` and an OK.
static func tell(parent: Node, title: String, text: String) -> Control:
	return ask(parent, title, text, [["ok", "OK"]])


func build(title: String, text: String, choices: Array) -> void:
	$Center/Frame/Box/Title.text = title.to_upper()
	$Center/Frame/Box/Text.text = text
	$Center/Frame/Box/Text.visible = text != ""
	var pattern: Button = $Center/Frame/Box/Choices/Choice
	for choice in choices:
		var button: Button = pattern.duplicate()
		button.name = "Choice_%s" % choice[0]
		button.text = str(choice[1]).to_upper()
		button.visible = true
		button.connect("pressed", self, "_on_choice", [choice[0]])
		pattern.get_parent().add_child(button)


func _on_choice(choice) -> void:
	emit_signal("chosen", choice)
	queue_free()
