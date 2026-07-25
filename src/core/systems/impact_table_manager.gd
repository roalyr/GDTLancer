# PROJECT: GDTLancer
# MODULE: impact_table_manager.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 02:05:00

extends Node
class_name ImpactTableManager

const ImpactCardEntryClass = preload("res://src/core/resources/impact_card_entry.gd")
const ImpactCardPoolClass = preload("res://src/core/resources/impact_card_pool.gd")

var registered_pools: Array = [] # Array of ImpactCardPool

func register_pool(pool: ImpactCardPool) -> void:
	if pool != null and not pool in registered_pools:
		registered_pools.append(pool)

func unregister_pool(pool: ImpactCardPool) -> void:
	if pool in registered_pools:
		registered_pools.erase(pool)

func clear_pools() -> void:
	registered_pools.clear()

func evaluate_context(active_tags: Array, filter_type: String = "") -> Array:
	var matching_entries: Array = []
	for pool in registered_pools:
		if pool == null:
			continue
		var pool_matches = pool.get_matching_entries(active_tags, filter_type)
		for entry in pool_matches:
			if not entry in matching_entries:
				matching_entries.append(entry)
	return matching_entries

func select_weighted_entry(active_tags: Array, filter_type: String = "") -> ImpactCardEntry:
	var matches = evaluate_context(active_tags, filter_type)
	if matches.empty():
		return null
	
	var total_weight: int = 0
	for entry in matches:
		total_weight += entry.weight
	
	if total_weight <= 0:
		return matches[0] as ImpactCardEntry
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var roll = rng.randi_range(1, total_weight)
	
	var current_sum: int = 0
	for entry in matches:
		current_sum += entry.weight
		if roll <= current_sum:
			return entry as ImpactCardEntry
			
	return matches[0] as ImpactCardEntry

func apply_impact_entry(entry: ImpactCardEntry, target_sector_id: String = "") -> Dictionary:
	var result: Dictionary = {
		"entry_id": "",
		"type": "",
		"player_track_deltas": {},
		"sector_track_deltas": {},
		"applied_tags": [],
		"removed_tags": []
	}
	
	if entry == null:
		return result
		
	result["entry_id"] = entry.entry_id
	result["type"] = entry.type
	
	# 1. Apply player track deltas
	var p_deltas: Dictionary = {}
	for track in entry.player_track_deltas.keys():
		var delta = int(entry.player_track_deltas[track])
		var new_val = GameState.apply_player_track_delta(str(track), delta)
		p_deltas[track] = delta
	result["player_track_deltas"] = p_deltas
	
	# 2. Apply sector track deltas
	var sec_id = target_sector_id if target_sector_id != "" else GameState.current_sector_id
	var s_deltas: Dictionary = {}
	if sec_id != "":
		for track in entry.sector_track_deltas.keys():
			var delta = int(entry.sector_track_deltas[track])
			var new_val = GameState.apply_sector_track_delta(sec_id, str(track), delta)
			s_deltas[track] = delta
	result["sector_track_deltas"] = s_deltas
	
	# 3. Apply tag changes
	var app_tags: Array = []
	for tag in entry.applied_tags:
		var tag_str = str(tag)
		if sec_id != "":
			GameState.add_sector_tag(sec_id, tag_str)
		else:
			if not tag_str in GameState.world_tags:
				GameState.world_tags.append(tag_str)
		app_tags.append(tag_str)
	result["applied_tags"] = app_tags
	
	var rem_tags: Array = []
	for tag in entry.removed_tags:
		var tag_str = str(tag)
		if sec_id != "":
			GameState.remove_sector_tag(sec_id, tag_str)
		else:
			if tag_str in GameState.world_tags:
				GameState.world_tags.erase(tag_str)
		rem_tags.append(tag_str)
	result["removed_tags"] = rem_tags
	
	return result
