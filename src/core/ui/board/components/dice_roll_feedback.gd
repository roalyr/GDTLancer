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

func display_result(res: Dictionary) -> void:
	if res.empty():
		return
		
	var rolls: Array = res.get("dice_rolls", [0, 0, 0])
	var base_total: int = res.get("base_total", 0)
	var modifier: int = res.get("modifier", 0)
	var final_total: int = res.get("final_total", 0)
	var target_diff: int = res.get("target_difficulty", 0)
	var success: bool = res.get("success", false)
	var margin: int = res.get("margin", 0)
	
	if dice_label != null:
		dice_label.text = "3d6 Rolls: " + str(rolls)
	if math_label != null:
		var mod_sign = "+" if modifier >= 0 else ""
		math_label.text = str(base_total) + " " + mod_sign + str(modifier) + " = " + str(final_total) + " (vs Target " + str(target_diff) + ")"
	if outcome_label != null:
		if success:
			outcome_label.text = "SUCCESS! (Margin +" + str(margin) + ")"
		else:
			outcome_label.text = "FAILURE! (Margin " + str(margin) + ")"
