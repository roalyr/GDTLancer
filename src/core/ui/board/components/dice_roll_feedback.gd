# PROJECT: GDTLancer
# MODULE: dice_roll_feedback.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 01:57:00

extends Control
class_name DiceRollFeedback

var dice_label: Label = null
var math_label: Label = null
var outcome_label: Label = null

func _ready() -> void:
	dice_label = get_node_or_null("VBoxContainer/DiceLabel") as Label
	math_label = get_node_or_null("VBoxContainer/MathLabel") as Label
	outcome_label = get_node_or_null("VBoxContainer/OutcomeLabel") as Label

func display_raw_roll(rolls: Array, total: int) -> void:
	if dice_label != null:
		dice_label.text = "3D6 DICE: " + str(rolls[0]) + "  +  " + str(rolls[1]) + "  +  " + str(rolls[2])
	if math_label != null:
		math_label.text = "DICE SUM: " + str(total)
	if outcome_label != null:
		outcome_label.text = "[ RAW RESULT: " + str(total) + " ]"
		outcome_label.add_color_override("font_color", Color(0.4, 0.9, 0.6, 1.0))

func display_result(res: Dictionary) -> void:
	if res.empty():
		return
	var rolls: Array = res.get("dice_rolls", [randi() % 6 + 1, randi() % 6 + 1, randi() % 6 + 1])
	var total: int = res.get("total", rolls[0] + rolls[1] + rolls[2])
	display_raw_roll(rolls, total)
