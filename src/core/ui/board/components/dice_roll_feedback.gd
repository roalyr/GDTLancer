# PROJECT: GDTLancer
# MODULE: dice_roll_feedback.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-08-17 04:00:00

extends Control
class_name DiceRollFeedback # Name kept for node compatibility until scene is refactored

var dice_label: Label = null
var math_label: Label = null
var outcome_label: Label = null

func _ready() -> void:
	dice_label = get_node_or_null("VBoxContainer/DiceLabel") as Label
	math_label = get_node_or_null("VBoxContainer/MathLabel") as Label
	outcome_label = get_node_or_null("VBoxContainer/OutcomeLabel") as Label

func display_raw_roll(rolls: Array, total: int) -> void:
	# Deprecated, kept for backward compatibility if called directly
	pass

func display_result(res: Dictionary) -> void:
	if res.empty():
		return
	
	var power: int = res.get("total_power", 0)
	var is_success: bool = res.get("success", false)
	
	if dice_label != null:
		dice_label.text = "CARDS APPLIED: " + str(res.get("applied_cards_count", 0))
	if math_label != null:
		math_label.text = "TOTAL POWER: " + str(power)
	if outcome_label != null:
		if is_success:
			outcome_label.text = "[ RESOLUTION: SUCCESS ]"
			outcome_label.add_color_override("font_color", Color(0.4, 0.9, 0.6, 1.0))
		else:
			outcome_label.text = "[ RESOLUTION: FAILURE ]"
			outcome_label.add_color_override("font_color", Color(0.9, 0.4, 0.4, 1.0))
