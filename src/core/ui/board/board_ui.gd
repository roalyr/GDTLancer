# PROJECT: GDTLancer
# MODULE: board_ui.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2; TRUTH_EXPLORATION-PILLARS.md §3
# LOG_REF: 2026-07-26 01:57:00

extends Control
class_name BoardUI

var BoardActionLoopScript = load("res://src/core/systems/board_action_loop.gd")
var AssetCardScript = load("res://src/core/cards/asset_card.gd")
var ImpactCardScript = load("res://src/core/cards/impact_card.gd")

var action_loop = null

var track_container: VBoxContainer = null
var card_area = null
var dice_feedback = null
var action_btn: Button = null
var token_grid: GridContainer = null

func _ready() -> void:
	action_loop = BoardActionLoopScript.new()
	add_child(action_loop)
	
	track_container = get_node_or_null("Layout/LeftPanel/TrackContainer") as VBoxContainer
	card_area = get_node_or_null("Layout/CenterPanel/CardArea")
	dice_feedback = get_node_or_null("Layout/RightPanel/DiceRollFeedback")
	action_btn = get_node_or_null("Layout/RightPanel/ExecuteActionButton") as Button
	token_grid = get_node_or_null("Layout/CenterPanel/TokenGrid") as GridContainer
	
	if action_btn != null:
		action_btn.connect("pressed", self, "_on_execute_action_pressed")
		
	_populate_sample_board()

func _populate_sample_board() -> void:
	if card_area != null:
		var c1 = AssetCardScript.new()
		c1.card_id = "scanner_array"
		c1.display_name = "Scanner Array"
		c1.tags = ["Sensor", "Utility"]
		
		var c2 = AssetCardScript.new()
		c2.card_id = "hull_repair_kit"
		c2.display_name = "Hull Repair Kit"
		c2.tags = ["Repair", "Consumable"]
		
		card_area.set_cards([c1, c2])
		
	if token_grid != null:
		for child in token_grid.get_children():
			child.queue_free()
		for i in range(4):
			var token = Button.new()
			token.rect_min_size = Vector2(80, 80)
			token.text = "Node " + str(i + 1)
			token_grid.add_child(token)

func _on_execute_action_pressed() -> void:
	if card_area == null or action_loop == null:
		return
		
	var selected_cards = card_area.selected_cards
	action_loop.assemble_action(selected_cards)
	var check_res = action_loop.execute_check(12)
	
	if dice_feedback != null:
		dice_feedback.display_result(check_res)
		
	if check_res.get("success", false):
		var impact = ImpactCardScript.new()
		impact.display_name = "Node Opportunity"
		impact.player_track_deltas = {"wealth": 1, "supplies": 1}
		action_loop.apply_mutation(impact)
