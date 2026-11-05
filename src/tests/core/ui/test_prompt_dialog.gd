# Tests for PromptDialog: one scene for every prompt and notice, any text, any answers.

extends GutTest

const PromptDialog = preload("res://src/core/ui/helpers/prompt_dialog.gd")


func _choices(prompt: Node) -> Array:
	var found: Array = []
	for button in prompt.get_node("Center/Frame/Box/Choices").get_children():
		if button.visible:
			found.append(button)
	return found


func test_a_prompt_shows_its_text_and_answers_and_says_which_was_chosen():
	var holder = add_child_autofree(Control.new())
	var prompt = PromptDialog.ask(holder, "Save before exiting?", "UNSAVED PLAY IS LOST.", [["save", "Save and exit"], ["exit", "Exit"], ["cancel", "Cancel"]])
	assert_eq(prompt.get_node("Center/Frame/Box/Title").text, "SAVE BEFORE EXITING?")
	assert_eq(prompt.get_node("Center/Frame/Box/Text").text, "UNSAVED PLAY IS LOST.")
	var buttons: Array = _choices(prompt)
	assert_eq(buttons.size(), 3)
	assert_eq(buttons[0].text, "SAVE AND EXIT", "In the HUD's capitals")
	watch_signals(prompt)
	buttons[2].emit_signal("pressed")
	assert_signal_emitted_with_parameters(prompt, "chosen", ["cancel"])
	assert_true(prompt.is_queued_for_deletion(), "Answered, it goes")


func test_a_notice_has_one_ok():
	var holder = add_child_autofree(Control.new())
	var notice = PromptDialog.tell(holder, "Saved", "THE GAME IS SAVED.")
	var buttons: Array = _choices(notice)
	assert_eq(buttons.size(), 1)
	assert_eq(buttons[0].text, "OK")
	assert_eq(notice.theme, preload("res://assets/themes/main_theme.tres"), "The game's theme")
