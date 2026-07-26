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
var sector_tags_label: Label = null

func _ready() -> void:
	action_loop = BoardActionLoopScript.new()
	add_child(action_loop)
	
	track_container = get_node_or_null("Layout/LeftPanel/TrackContainer") as VBoxContainer
	card_area = get_node_or_null("Layout/CenterPanel/CardArea")
	dice_feedback = get_node_or_null("Layout/RightPanel/DiceRollFeedback")
	action_btn = get_node_or_null("Layout/RightPanel/ExecuteActionButton") as Button
	token_grid = get_node_or_null("Layout/CenterPanel/TokenGrid") as GridContainer
	close_btn = get_node_or_null("Layout/RightPanel/CloseBoardButton") as Button
	action_title_label = get_node_or_null("Layout/RightPanel/ActionTitle") as Label
	world_clock_label = get_node_or_null("Layout/CenterPanel/WorldClockLabel") as Label
	sector_tags_label = get_node_or_null("Layout/LeftPanel/TrackContainer/SectorTagsLabel") as Label
	
	if action_btn != null:
		action_btn.connect("pressed", self, "_on_execute_action_pressed")
	if close_btn != null:
		close_btn.connect("pressed", self, "_on_close_board_pressed")
	if EventBus != null and EventBus.has_signal("tick_advanced"):
		EventBus.connect("tick_advanced", self, "_on_tick_advanced")
		
	# Ensure SectorManager is active to listen for World Clock ticks
	var sector_mgr = get_node_or_null("SectorManager")
	if sector_mgr == null:
		var SectorManagerScript = load("res://src/core/systems/sector_manager.gd")
		if SectorManagerScript != null:
			sector_mgr = SectorManagerScript.new()
			sector_mgr.name = "SectorManager"
			add_child(sector_mgr)
			
	if EventBus != null and EventBus.has_signal("environmental_event_triggered"):
		EventBus.connect("environmental_event_triggered", self, "_on_environmental_event_triggered")
	if EventBus != null and EventBus.has_signal("sector_tags_changed"):
		EventBus.connect("sector_tags_changed", self, "_on_sector_tags_changed")

	setup_tracks()
	_populate_board()
	update_clock_display()
	update_sector_tags_display()

func _on_environmental_event_triggered(_sec_id: String, _event_type: String, _details: Dictionary) -> void:
	update_sector_tags_display()

func _on_sector_tags_changed(_sec_id: String, _tags: Array) -> void:
	update_sector_tags_display()

func update_sector_tags_display() -> void:
	if sector_tags_label == null:
		return
	var active_sec: String = GameState.current_sector_id if GameState.current_sector_id != "" else Constants.INITIAL_SECTOR_ID
	var tags: Array = GameState.get_sector_tags(active_sec)
	if tags.size() > 0:
		var tag_str: String = ""
		for t in tags:
			tag_str += "[" + str(t).replace("_", " ").to_upper() + "] "
		sector_tags_label.text = tag_str
		sector_tags_label.add_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
	else:
		sector_tags_label.text = "[NOMINAL / CLEAR]"
		sector_tags_label.add_color_override("font_color", Color(0.5, 0.8, 0.6, 1.0))

func update_clock_display() -> void:
	if world_clock_label == null:
		return
	var ticks: int = 0
	var world_clock = get_node_or_null("/root/MainGameScene/WorldManager/WorldClock")
	if is_instance_valid(world_clock) and "current_tick" in world_clock:
		ticks = world_clock.current_tick
	elif GameState != null:
		ticks = GameState.sim_tick_count
		
	var cycle: int = (ticks / 10) + 1
	var step: int = ticks % 10
	world_clock_label.text = "WORLD CLOCK: TICK %d  |  CYCLE %d (STEP %d/10)" % [ticks, cycle, step]

func _on_tick_advanced(_current_tick: int, _delta_ticks: int) -> void:
	update_clock_display()
	update_sector_tags_display()

func setup_tracks() -> void:
	if track_container != null:
		# Player Tracks
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

		# Sector Tracks
		var active_sec: String = GameState.current_sector_id if GameState.current_sector_id != "" else Constants.INITIAL_SECTOR_ID
		var stab_tr = track_container.get_node_or_null("StabilityTrack")
		if stab_tr != null and stab_tr.has_method("setup_track"):
			stab_tr.setup_track("stability", "sector", active_sec)
		var res_tr = track_container.get_node_or_null("ResourcesTrack")
		if res_tr != null and res_tr.has_method("setup_track"):
			res_tr.setup_track("resources", "sector", active_sec)
		var sec_tr = track_container.get_node_or_null("SecurityTrack")
		if sec_tr != null and sec_tr.has_method("setup_track"):
			sec_tr.setup_track("security", "sector", active_sec)

func _populate_board() -> void:
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
				npc_tokens.append({
					"id": npc_id,
					"name": npc_name,
					"label": "[NPC] " + npc_name + "\nBond: " + bond + "\nTag: " + tag_str,
					"locked": false
				})
		else:
			npc_tokens = [
				{"id": "npc_vera", "name": "Master Vera", "label": "[NPC] Master Vera\nBond: STABLE\nTag: Stewardship", "locked": false},
				{"id": "npc_kael", "name": "Trader Kael", "label": "[NPC] Trader Kael\nBond: FRAGILE\nTag: Depletion", "locked": false},
				{"id": "npc_jax", "name": "Tech Jax", "label": "[NPC] Tech Jax\nBond: DEEP\nTag: Maintenance", "locked": false}
			]

		for npc_data in npc_tokens:
			var btn = Button.new()
			btn.rect_min_size = Vector2(130, 80)
			btn.text = npc_data["label"]
			btn.add_color_override("font_color", Color(0.4, 1.0, 0.6, 1.0))
			btn.connect("pressed", self, "_on_target_token_pressed", [npc_data])
			token_grid.add_child(btn)

func _on_target_token_pressed(target_data: Dictionary) -> void:
	selected_target_id = target_data.get("id", "")
	selected_target_name = target_data.get("name", selected_target_id)
	is_target_locked = target_data.get("locked", false)
	
	if action_title_label != null:
		if is_target_locked:
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
	if card_area == null or action_loop == null:
		return
		
	var selected_cards = card_area.selected_cards
	var equipped_tags = _get_selected_card_tags()
	
	# Check Gating on Target Node
	if not selected_target_id.empty() and gate_system.is_node_locked(selected_target_id, card_area.selected_cards):
		if dice_feedback != null and dice_feedback.has_method("display_result"):
			var reason = gate_system.get_lock_reason(selected_target_id, card_area.selected_cards)
			dice_feedback.display_result({
				"success": false,
				"total": 0,
				"target": 10,
				"modifier": 0,
				"reason": "LOCKED: " + reason
			})
		return

	action_loop.assemble_action(selected_cards)
	
	# Target threshold calculation (reduced by equipped cards and active target)
	var card_modifier: int = selected_cards.size() * 2
	var check_res = action_loop.execute_check(10 - card_modifier)
	
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

	# Instantly refresh UI tracks so the mutated numbers update visually
	setup_tracks()

	# Advance World Clock if available
	var world_clock = get_node_or_null("/root/MainGameScene/WorldManager/WorldClock")
	if is_instance_valid(world_clock) and world_clock.has_method("advance"):
		world_clock.advance(1)
	update_clock_display()

func _on_close_board_pressed() -> void:
	visible = false
	emit_signal("board_closed")

