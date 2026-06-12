# PROJECT: GDTLancer
# MODULE: economy_progression_system.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §3.2 + TACTICAL_TODO.md TASK_3
# LOG_REF: 2026-06-12 23:25:00

extends Reference

const ECONOMY_LEVELS: Array = ["POOR", "ADEQUATE", "RICH"]
const CATEGORIES: Array = ["RAW", "MANUFACTURED", "CURRENCY"]

var _grid_layer: Reference

func initialize(grid_layer_ref: Reference) -> void:
	_grid_layer = grid_layer_ref


func _step_economy(tags: Array, neighbor_tags: Array, sector_id: String) -> Array:
	var result: Array = Array(tags)
	var world_age: String = GameState.world_age if GameState.world_age else "PROSPERITY"
	var role_counts: Dictionary = _grid_layer._role_counts_for_sector(sector_id)

	var sector_upgrade_progress: Dictionary = GameState.economy_upgrade_progress.get(sector_id, {})
	var sector_downgrade_progress: Dictionary = GameState.economy_downgrade_progress.get(sector_id, {})
	var sector_thresholds: Dictionary = GameState.economy_change_threshold.get(sector_id, {})

	var loaded_trade: int = _grid_layer._loaded_trade_count_for_sector(sector_id)
	var colony_level: String = GameState.colony_levels.get(sector_id, "frontier")
	var max_idx_for_level: int = _economy_max_index_for_level(colony_level)
	var has_active_commerce: bool = loaded_trade > 0 or colony_level in ["colony", "hub"]
	var has_pirate_or_infestation: bool = role_counts.get("pirate", 0) > 0 or "HOSTILE_INFESTED" in result

	for category in CATEGORIES:
		var level: String = _economy_level(result, category)
		var idx: int = ECONOMY_LEVELS.find(level)
		if idx < 0:
			idx = 1  # ADEQUATE fallback
		var delta: int = 0

		var threshold: int = sector_thresholds.get(category, Constants.ECONOMY_CHANGE_TICKS_MIN)
		var upgrade_threshold: int = _economy_upgrade_threshold_for_level(threshold, colony_level)

		# Homeostatic pressure
		if level == "RICH":
			delta -= 1
		elif level == "POOR":
			delta += 1

		# World age influence
		if world_age == "PROSPERITY":
			if has_active_commerce:
				delta += 1
		elif world_age == "DISRUPTION":
			if category == "RAW":
				delta -= 1
			elif category == "MANUFACTURED" and has_pirate_or_infestation:
				delta -= 1
		elif world_age == "RECOVERY":
			delta += 1

		# Colony maintenance drain
		if colony_level == "hub":
			delta -= 1
		elif colony_level == "colony" and category == "RAW":
			delta -= 1

		# Population density pressure
		if _grid_layer._active_agent_count_in_sector(sector_id) > 3:
			delta -= 1

		# Active commerce
		if loaded_trade > 0:
			delta += 1
		if role_counts.get("pirate", 0) > 0:
			delta -= 1

		# Progress counters
		var up_progress: int = sector_upgrade_progress.get(category, 0)
		var down_progress: int = sector_downgrade_progress.get(category, 0)

		if delta >= 1:
			up_progress += 1
			down_progress = 0
		elif delta <= -1:
			down_progress += 1
			up_progress = 0
		else:
			up_progress = 0
			down_progress = 0

		if up_progress >= upgrade_threshold and idx < max_idx_for_level:
			idx = min(max_idx_for_level, idx + 1)
			up_progress = 0
		elif down_progress >= threshold and idx > 0:
			idx = max(0, idx - 1)
			down_progress = 0

		idx = min(idx, max_idx_for_level)

		sector_upgrade_progress[category] = up_progress
		sector_downgrade_progress[category] = down_progress

		result = _grid_layer._replace_prefix(result, category + "_", category + "_" + ECONOMY_LEVELS[idx])

	GameState.economy_upgrade_progress[sector_id] = sector_upgrade_progress
	GameState.economy_downgrade_progress[sector_id] = sector_downgrade_progress
	return result


func _economy_upgrade_threshold_for_level(base_threshold: int, colony_level: String) -> int:
	var threshold: int = base_threshold
	if colony_level == "frontier":
		threshold += Constants.FRONTIER_ECONOMY_UPGRADE_TICKS_BONUS
	elif colony_level == "outpost":
		threshold += Constants.OUTPOST_ECONOMY_UPGRADE_TICKS_BONUS

	match GameState.world_age:
		"PROSPERITY":
			match _grid_layer._prosperity_growth_stage():
				2:
					threshold -= Constants.PROSPERITY_ECONOMY_SECURITY_UPGRADE_REDUCTION_LATE
				1:
					threshold -= Constants.PROSPERITY_ECONOMY_SECURITY_UPGRADE_REDUCTION_MID
		"DISRUPTION":
			threshold += 1
		"RECOVERY":
			threshold -= 1

	if threshold < Constants.ECONOMY_CHANGE_TICKS_MIN:
		threshold = Constants.ECONOMY_CHANGE_TICKS_MIN
	return threshold


func _economy_max_index_for_level(colony_level: String) -> int:
	if colony_level == "frontier":
		var frontier_max_idx: int = ECONOMY_LEVELS.find(Constants.FRONTIER_MAX_ECONOMY_LEVEL)
		return frontier_max_idx if frontier_max_idx >= 0 else 1
	return ECONOMY_LEVELS.size() - 1


func _economy_level(tags: Array, category: String) -> String:
	for level in ECONOMY_LEVELS:
		if (category + "_" + level) in tags:
			return level
	return "ADEQUATE"
