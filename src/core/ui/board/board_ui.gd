# PROJECT: GDTLancer
# MODULE: board_ui.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2; TRUTH_EXPLORATION-PILLARS.md §3
# LOG_REF: 2026-07-26 03:40:00

extends Control
class_name BoardUI

signal board_closed()

var BoardActionLoopScript = load("res://src/core/systems/board_action_loop.gd")
var AssetCardScript = load("res://src/core/cards/asset_card.gd")
var ImpactCardScript = load("res://src/core/cards/impact_card.gd")

var action_loop = null

var track_container: VBoxContainer = null
var card_area = null
var dice_feedback = null
var action_btn: Button = null
var token_grid: GridContainer = null
var close_btn: Button = null

func _ready() -> void:
	action_loop = BoardActionLoopScript.new()
	add_child(action_loop)
	
	track_container = get_node_or_null("Layout/LeftPanel/TrackContainer") as VBoxContainer
	card_area = get_node_or_null("Layout/CenterPanel/CardArea")
	dice_feedback = get_node_or_null("Layout/RightPanel/DiceRollFeedback")
	action_btn = get_node_or_null("Layout/RightPanel/ExecuteActionButton") as Button
	token_grid = get_node_or_null("Layout/CenterPanel/TokenGrid") as GridContainer
	close_btn = get_node_or_null("Layout/RightPanel/CloseBoardButton") as Button
	
	if action_btn != null:
		action_btn.connect("pressed", self, "_on_execute_action_pressed")
	if close_btn != null:
		close_btn.connect("pressed", self, "_on_close_board_pressed")
		
	setup_tracks()
	_populate_board()

func setup_tracks() -> void:
	if track_container != null:
		var health_tr = track_container.get_node_or_null("HealthTrack")
		if health_tr != null and health_tr.has_method("setup_track"):
			health_tr.setup_track("health", "player")
		var wealth_tr = track_container.get_node_or_null("WealthTrack")
		if wealth_tr != null and wealth_tr.has_method("setup_track"):
			wealth_tr.setup_track("wealth", "player")
		var morale_tr = track_container.get_node_or_null("MoraleTrack")
		if morale_tr != null and morale_tr.has_method("setup_track"):
			morale_tr.setup_track("morale", "player")
		var supplies_tr = track_container.get_node_or_null("SuppliesTrack")
		if supplies_tr != null and supplies_tr.has_method("setup_track"):
			supplies_tr.setup_track("supplies", "player")

func _populate_board() -> void:
	# Populate Asset Cards from AssetSystem registry if available
	if card_area != null:
		var available_cards: Array = []
		if is_instance_valid(GlobalRefs.asset_system) and GlobalRefs.asset_system.registered_cards.size() > 0:
			available_cards = GlobalRefs.asset_system.registered_cards.values()
		else:
			var c1 = AssetCardScript.new()
			c1.card_id = "scanner_array"
			c1.display_name = "Scanner Array"
			c1.tags = ["Sensor", "Utility"]
			
			var c2 = AssetCardScript.new()
			c2.card_id = "hull_repair_kit"
			c2.display_name = "Hull Repair Kit"
			c2.tags = ["Repair", "Consumable"]
			available_cards = [c1, c2]
			
		card_area.set_cards(available_cards)
		
	# Populate Tokens (Nodes / NPCs)
	if token_grid != null:
		for child in token_grid.get_children():
			child.queue_free()
		
		var node_labels = ["Dock Core", "Derelict Bay", "Anomalous Node", "Market Post"]
		for i in range(node_labels.size()):
			var token = Button.new()
			token.rect_min_size = Vector2(100, 80)
			token.text = node_labels[i]
			token_grid.add_child(token)

func _on_execute_action_pressed() -> void:
	if card_area == null or action_loop == null:
		return
		
	var selected_cards = card_area.selected_cards
	action_loop.assemble_action(selected_cards)
	var check_res = action_loop.execute_check(10)
	
	if dice_feedback != null:
		dice_feedback.display_result(check_res)
		
	if check_res.get("success", false):
		var impact = ImpactCardScript.new()
		impact.display_name = "Board Action Success"
		impact.player_track_deltas = {"wealth": 1, "supplies": 1}
		action_loop.apply_mutation(impact)
	else:
		var impact = ImpactCardScript.new()
		impact.display_name = "Board Action Complication"
		impact.player_track_deltas = {"health": -1, "morale": -1}
		action_loop.apply_mutation(impact)

	# Advance World Clock if available
	var world_clock = get_node_or_null("/root/MainGameScene/WorldManager/WorldClock")
	if is_instance_valid(world_clock) and world_clock.has_method("advance"):
		world_clock.advance(1)

func _on_close_board_pressed() -> void:
	visible = false
	emit_signal("board_closed")

