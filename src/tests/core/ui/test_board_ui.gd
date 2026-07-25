# PROJECT: GDTLancer
# MODULE: test_board_ui.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 01:57:00

extends "res://addons/gut/test.gd"

var BoardUIScene = load("res://scenes/ui/board/board_ui.tscn")

var _board_ui = null

func before_each():
	_board_ui = autoqfree(BoardUIScene.instance())
	add_child(_board_ui)

func test_board_ui_initialization():
	assert_not_null(_board_ui, "BoardUI scene should instance correctly")
	assert_not_null(_board_ui.card_area, "CardArea should be bound")
	assert_not_null(_board_ui.dice_feedback, "DiceRollFeedback should be bound")
	assert_not_null(_board_ui.action_btn, "ExecuteActionButton should be bound")

func test_execute_action_flow():
	_board_ui.card_area.selected_cards = _board_ui.card_area.cards
	_board_ui._on_execute_action_pressed()
	assert_ne(_board_ui.dice_feedback.outcome_label.text, "Awaiting Roll...", "Outcome label should update after roll execution")
