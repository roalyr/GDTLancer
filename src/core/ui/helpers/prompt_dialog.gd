# PromptDialog: the game's one prompt for every question and notice: a title, any text, and as many
# answers as it needs (one, OK, for a notice). scenes/ui/shared/prompt_dialog.tscn is its look, in
# the main theme (its frame: the theme's PanelContainer style; its hidden Choice button is the
# pattern for the answers). Blocks the pointer as a whole while it shows; frees itself once answered.
#     var prompt = PromptDialog.ask(self, "Save before exiting?", "...", [["save", "SAVE AND EXIT"], ["cancel", "CANCEL"]])
#     prompt.connect("chosen", self, "_on_exit_chosen")
#     PromptDialog.tell(self, "Saved", "THE GAME IS SAVED.")  # A notice: one OK
#     PromptDialog.ask_list(self, "Load", "", [["1", "SLOT 1 ..."], ["2", "SLOT 2: EMPTY", true]])  # One under another; true: greyed out

extends Control

signal chosen(choice)

const SCENE_PATH = "res://scenes/ui/shared/prompt_dialog.tscn"
const LIST_WIDTH = 1000.0  # px: a list answer's width (ask_list)


static func ask(parent: Node, title: String, text: String, choices: Array) -> Control:
	var prompt = load(SCENE_PATH).instance()
	prompt.build(title, text, choices)
	parent.add_child(prompt)
	return prompt


# The answers one under another, wide (a list of save slots): the last one (a cancel) stays in the
# row below. A choice's third item, true, greys it out (shown, not pickable).
static func ask_list(parent: Node, title: String, text: String, choices: Array) -> Control:
	var prompt = load(SCENE_PATH).instance()
	prompt.build(title, text, choices, true)
	parent.add_child(prompt)
	return prompt


# A notice: `text` and an OK.
static func tell(parent: Node, title: String, text: String) -> Control:
	return ask(parent, title, text, [["ok", "OK"]])


func build(title: String, text: String, choices: Array, vertical: bool = false) -> void:
	$Center/Frame/Box/Title.text = title.to_upper()
	$Center/Frame/Box/Text.text = text
	$Center/Frame/Box/Text.visible = text != ""
	var pattern: Button = $Center/Frame/Box/Choices/Choice
	var list: VBoxContainer = null
	if vertical:
		list = VBoxContainer.new()
		list.name = "List"
		list.mouse_filter = MOUSE_FILTER_IGNORE
		list.add_constant_override("separation", 8)
		$Center/Frame/Box.add_child_below_node($Center/Frame/Box/Text, list)
	for index in range(choices.size()):
		var choice: Array = choices[index]
		var button: Button = pattern.duplicate()
		button.name = "Choice_%s" % choice[0]
		button.text = str(choice[1]).to_upper()
		button.visible = true
		button.disabled = choice.size() > 2 and bool(choice[2])
		button.connect("pressed", self, "_on_choice", [choice[0]])
		if list != null and index < choices.size() - 1:
			button.rect_min_size = Vector2(LIST_WIDTH, pattern.rect_min_size.y)
			button.clip_text = true
			list.add_child(button)
		else:
			pattern.get_parent().add_child(button)


func _on_choice(choice) -> void:
	emit_signal("chosen", choice)
	queue_free()
