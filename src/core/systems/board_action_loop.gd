# PROJECT: GDTLancer
# MODULE: board_action_loop.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 00:57:00

extends Node

var ActionCheckEngineClass = load("res://src/core/systems/action_check_engine.gd")

var current_target_node = null
var selected_asset_cards: Array = []
var last_check_result: Dictionary = {}
var check_engine = null

func _ready() -> void:
	check_engine = ActionCheckEngineClass.new()

func select_target(node) -> void:
	current_target_node = node
	selected_asset_cards.clear()
	last_check_result.clear()

func assemble_action(asset_cards: Array) -> void:
	selected_asset_cards = asset_cards.duplicate()

func execute_check(target_difficulty: int = 10, seeded_dice: Array = []) -> Dictionary:
	var player_tracks = GameState.player_tracks
	last_check_result = check_engine.resolve_check(target_difficulty, selected_asset_cards, player_tracks, seeded_dice)
	return last_check_result

func apply_mutation(impact_card, sector_id: String = "") -> bool:
	if not impact_card:
		return false

	# Apply Player track deltas
	for track in impact_card.player_track_deltas:
		var delta = int(impact_card.player_track_deltas[track])
		GameState.apply_player_track_delta(track, delta)

	# Apply Sector track deltas
	if not sector_id.empty():
		for track in impact_card.sector_track_deltas:
			var delta = int(impact_card.sector_track_deltas[track])
			GameState.apply_sector_track_delta(sector_id, track, delta)

	# Advance WorldClock by 1 tick on board action loop completion
	var world_clock = get_node_or_null("/root/WorldClock")
	if world_clock and world_clock.has_method("advance"):
		world_clock.advance(1)

	EventBus.emit_signal("interact_action_feedback", true, "Board mutated by " + impact_card.display_name)
	return true
