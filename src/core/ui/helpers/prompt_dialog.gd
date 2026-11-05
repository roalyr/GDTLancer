# PromptDialog: a modal question with a few answers (scenes/ui/shared/prompt_dialog.tscn: the look;
# its hidden Choice button is the pattern for the answers). Blocks the pointer as a whole while it
# shows; frees itself once answered.
#     var prompt = PromptDialog.ask(self, "SAVE BEFORE EXIT?", "...", [["save", "SAVE AND EXIT"], ["cancel", "CANCEL"]])
#     prompt.connect("chosen", self, "_on_exit_chosen")

extends Control

signal chosen(choice)

const SCENE_PATH = "res://scenes/ui/shared/prompt_dialog.tscn"


static func ask(parent: Node, title: String, text: String, choices: Array) -> Control:
	var prompt = load(SCENE_PATH).instance()
	prompt.build(title, text, choices)
	parent.add_child(prompt)
	return prompt


func build(title: String, text: String, choices: Array) -> void:
	$Center/Box/Title.text = title.to_upper()
	$Center/Box/Text.text = text
	var pattern: Button = $Center/Box/Choices/Choice
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
