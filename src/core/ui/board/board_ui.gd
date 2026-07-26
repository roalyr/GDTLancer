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

var NodeGateSystemClass = load("res://src/core/systems/node_gate_system.gd")
var gate_system = NodeGateSystemClass.new()

var selected_target_id: String = ""
var selected_target_name: String = ""
var is_target_locked: bool = false
var action_title_label: Label = null
var world_clock_label: Label = null
var board_title_label: Label = null
var session_tick_count: int = 0

func _ready() -> void:
	var main_theme = load("res://assets/themes/main_theme.tres")
	if main_theme != null:
		theme = main_theme

	action_loop = BoardActionLoopScript.new()
	add_child(action_loop)
	
	card_area = get_node_or_null("Layout/CenterPanel/CardArea")
	dice_feedback = get_node_or_null("Layout/RightPanel/DiceRollFeedback")
	action_btn = get_node_or_null("Layout/RightPanel/ExecuteActionButton") as Button
	token_grid = get_node_or_null("Layout/CenterPanel/TokenGrid") as GridContainer
	close_btn = get_node_or_null("Layout/RightPanel/CloseBoardButton") as Button
	action_title_label = get_node_or_null("Layout/RightPanel/ActionTitle") as Label
	world_clock_label = get_node_or_null("Layout/CenterPanel/WorldClockLabel") as Label
	board_title_label = get_node_or_null("Layout/CenterPanel/BoardTitle") as Label
	
	if action_btn != null and not action_btn.is_connected("pressed", self, "_on_execute_action_pressed"):
		action_btn.connect("pressed", self, "_on_execute_action_pressed")
	if close_btn != null and not close_btn.is_connected("pressed", self, "_on_close_board_pressed"):
		close_btn.connect("pressed", self, "_on_close_board_pressed")
		
	_populate_board()

func update_clock_display() -> void:
	if world_clock_label != null:
		world_clock_label.text = "BOARD SESSION CLOCK: TICK %d" % session_tick_count

func _populate_board() -> void:
	session_tick_count = 0
	update_clock_display()
	# Populate Asset Cards from AssetSystem registry if available
	if card_area != null:
		var available_cards: Array = []
		if is_instance_valid(GlobalRefs.asset_system) and GlobalRefs.asset_system.registered_cards.size() > 0:
			available_cards = GlobalRefs.asset_system.registered_cards.values()
		else:
			var c1 = AssetCardScript.new("scavenged_array", "Scavenged Array", ["Sensor", "Utility"])
			var c2 = AssetCardScript.new("structural_patch_kit", "Structural Patch Kit", ["Repair", "Consumable"])
			var c3 = AssetCardScript.new("nav_pass_outer_margin", "Nav-Pass Outer Margin", ["Traversal", "outer_margin_pass"], ["enter_outer_margin"])
			available_cards = [c1, c2, c3]
			
		card_area.set_cards(available_cards)
		
	# Populate Tokens (Sector Graph Nodes + Resident NPCs)
	if token_grid != null:
		for child in token_grid.get_children():
			child.queue_free()
		
		# --- Section 1: Local Station Facility & Vault Tokens ---
		var nodes_to_display: Array = [
			{"id": "facility_comms", "name": "Comms Relay", "label": "[FACILITY] Comms Relay\nTarget: Sensor Check", "locked": false},
			{"id": "facility_workshop", "name": "Dockside Workshop", "label": "[FACILITY] Workshop Bay\nTarget: Repair Check", "locked": false},
			{"id": "node_outer_margin_alpha", "name": "Outer Margin Vault", "label": "[LOCKED VAULT] Outer Margin\nReq: Nav-Pass", "locked": true}
		]
		
		for node_data in nodes_to_display:
			var btn = Button.new()
			btn.rect_min_size = Vector2(130, 80)
			btn.text = node_data["label"]
			if node_data["locked"]:
				btn.hint_tooltip = "Mechanically Locked: Requires Outer Margin Nav-Pass Asset Card"
				btn.add_color_override("font_color", Color(0.9, 0.4, 0.4, 1.0))
			else:
				btn.add_color_override("font_color", Color(0.4, 0.8, 1.0, 1.0))
			btn.connect("pressed", self, "_on_target_token_pressed", [node_data])
			token_grid.add_child(btn)

		# --- Section 2: Resident NPC Tokens ---
		var npc_tokens: Array = []
		if GameState.npc_data.size() > 0:
			for npc_id in GameState.npc_data.keys():
				var npc = GameState.npc_data[npc_id]
				var npc_name: String = npc.get("display_name", npc_id)
				var bond: String = npc.get("bond_strength", "STABLE")
				var tags: Array = npc.get("tags", [])
				var tag_str: String = tags[0] if tags.size() > 0 else "Resident"
				npc_tokens.append({"id": npc_id, "name": npc_name, "label": "[NPC] " + npc_name + "\nBond: " + bond + " | " + tag_str})
		else:
			npc_tokens = [
				{"id": "npc_vera", "name": "Master Vera", "label": "[NPC] Master Vera\nBond: STABLE | Stewardship"},
				{"id": "npc_kael", "name": "Trader Kael", "label": "[NPC] Trader Kael\nBond: FRAGILE | Depletion"},
				{"id": "npc_jax", "name": "Tech Jax", "label": "[NPC] Tech Jax\nBond: DEEP | Maintenance"}
			]
			
		for data in npc_tokens:
			var btn = Button.new()
			btn.rect_min_size = Vector2(130, 80)
			btn.text = data["label"]
			btn.add_color_override("font_color", Color(0.4, 1.0, 0.6, 1.0))
			btn.connect("pressed", self, "_on_target_token_pressed", [data])
			token_grid.add_child(btn)

func _on_target_token_pressed(node_data: Dictionary) -> void:
	selected_target_id = node_data.get("id", "")
	selected_target_name = node_data.get("name", "")
	is_target_locked = node_data.get("locked", false)
	_update_action_title_display()

func _update_action_title_display() -> void:
	if action_title_label != null:
		if selected_target_id.empty():
			action_title_label.text = "SELECT BOARD TOKEN"
			action_title_label.add_color_override("font_color", Color(0.7, 0.7, 0.8, 1.0))
		elif is_target_locked:
			action_title_label.text = "TARGET: " + selected_target_name + "\n[MECHANICALLY LOCKED]"
			action_title_label.add_color_override("font_color", Color(0.9, 0.3, 0.3, 1.0))
		else:
			action_title_label.text = "TARGET: " + selected_target_name + "\n[ACTIVE TARGET]"
			action_title_label.add_color_override("font_color", Color(0.3, 0.9, 0.4, 1.0))

func _get_selected_card_tags() -> Array:
	var tags: Array = []
	if card_area != null and card_area.selected_cards is Array:
		for card in card_area.selected_cards:
			if "tags" in card and card.tags is Array:
				for t in card.tags:
					tags.append(str(t).to_lower())
	return tags

func _on_execute_action_pressed() -> void:
	var d1 = randi() % 6 + 1
	var d2 = randi() % 6 + 1
	var d3 = randi() % 6 + 1
	var total = d1 + d2 + d3
	
	if dice_feedback != null:
		if dice_feedback.has_method("display_raw_roll"):
			dice_feedback.display_raw_roll([d1, d2, d3], total)
		elif dice_feedback.has_method("display_result"):
			dice_feedback.display_result({"dice_rolls": [d1, d2, d3], "total": total})

	session_tick_count += 1
	update_clock_display()

func _on_close_board_pressed() -> void:
	visible = false
	emit_signal("board_closed")
