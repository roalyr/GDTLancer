# PROJECT: GDTLancer
# MODULE: colony_progression_system.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §3.2 + TACTICAL_TODO.md TASK_3
# LOG_REF: 2026-06-12 23:25:00

extends Reference

var _grid_layer: Reference

func initialize(grid_layer_ref: Reference) -> void:
	_grid_layer = grid_layer_ref


func _step_colony_level(tags: Array, sector_id: String) -> Array:
	var level: String = GameState.colony_levels.get(sector_id, "frontier")
	var levels: Array = Constants.COLONY_LEVELS
	var up_progress: int = GameState.colony_upgrade_progress.get(sector_id, 0)
	var down_progress: int = GameState.colony_downgrade_progress.get(sector_id, 0)
	var upgrade_threshold: int = _colony_upgrade_threshold_for_level(level)

	# Check upgrade requirements
	var economy_ok: bool = _colony_upgrade_economy_ok(tags, level, sector_id)
	var security_ok: bool = _colony_upgrade_security_ok(tags, level)
	var environment_ok: bool = _colony_upgrade_environment_ok(tags, level)

	# Check downgrade triggers
	var degrade: bool = Constants.COLONY_DOWNGRADE_SECURITY_TRIGGER in tags
	if not degrade:
		for trigger in Constants.COLONY_DOWNGRADE_ECONOMY_TRIGGER:
			if trigger in tags:
				degrade = true
				break

	if economy_ok and security_ok and environment_ok:
		up_progress += 1
		down_progress = 0
	elif degrade:
		down_progress += 1
		up_progress = 0
	else:
		up_progress = 0
		down_progress = 0

	var min_level: String = Constants.COLONY_MINIMUM_LEVEL
	var min_idx: int = levels.find(min_level)
	if min_idx < 0:
		min_idx = 0

	var level_idx: int = levels.find(level)
	if level_idx < 0:
		level_idx = 0

	if up_progress >= upgrade_threshold and level_idx < levels.size() - 1:
		level = levels[level_idx + 1]
		up_progress = 0
	elif down_progress >= Constants.COLONY_DOWNGRADE_TICKS_REQUIRED and level_idx > 0:
		var new_idx: int = level_idx - 1
		if new_idx >= min_idx:
			level = levels[new_idx]
		down_progress = 0

	GameState.colony_levels[sector_id] = level
	GameState.colony_upgrade_progress[sector_id] = up_progress
	GameState.colony_downgrade_progress[sector_id] = down_progress
	return tags


func _colony_upgrade_threshold_for_level(level: String) -> int:
	var threshold: int = Constants.COLONY_UPGRADE_TICKS_REQUIRED
	if level == "frontier":
		threshold = Constants.FRONTIER_COLONY_UPGRADE_TICKS_REQUIRED
	elif level == "outpost":
		threshold = Constants.OUTPOST_COLONY_UPGRADE_TICKS_REQUIRED
	elif level == "colony":
		threshold = Constants.COLONY_TO_HUB_UPGRADE_TICKS_REQUIRED

	match GameState.world_age:
		"PROSPERITY":
			match _grid_layer._prosperity_growth_stage():
				2:
					if level == "colony":
						threshold -= Constants.PROSPERITY_COLONY_TO_HUB_UPGRADE_REDUCTION_LATE
					elif level == "outpost":
						threshold -= Constants.PROSPERITY_OUTPOST_TO_COLONY_UPGRADE_REDUCTION_LATE
					else:
						threshold -= Constants.PROSPERITY_COLONY_UPGRADE_REDUCTION_LATE
				1:
					if level == "colony":
						threshold -= Constants.PROSPERITY_COLONY_TO_HUB_UPGRADE_REDUCTION_MID
					elif level == "outpost":
						threshold -= Constants.PROSPERITY_OUTPOST_TO_COLONY_UPGRADE_REDUCTION_MID
					else:
						threshold -= Constants.PROSPERITY_COLONY_UPGRADE_REDUCTION_MID
		"DISRUPTION":
			threshold += 2
		"RECOVERY":
			if level == "colony":
				threshold += Constants.RECOVERY_COLONY_TO_HUB_UPGRADE_PENALTY
			elif level == "outpost":
				threshold += Constants.RECOVERY_OUTPOST_TO_COLONY_UPGRADE_PENALTY
			else:
				threshold -= 1

	var minimum_threshold: int = _minimum_colony_upgrade_threshold_for_level(level)
	if threshold < minimum_threshold:
		threshold = minimum_threshold
	return threshold


func _minimum_colony_upgrade_threshold_for_level(level: String) -> int:
	if level == "frontier":
		return 12
	if level == "outpost":
		return 11
	if level == "colony":
		return 11
	return 6


func _colony_upgrade_economy_ok(tags: Array, level: String, sector_id: String = "") -> bool:
	if level == "colony":
		for req in Constants.COLONY_TO_HUB_REQUIRED_ECONOMY:
			if not (req in tags):
				return false
		return true
	if not _meets_colony_upgrade_economy_floor(tags):
		return false
	if level == "outpost":
		var rich_count: int = _rich_economy_tag_count(tags)
		if rich_count < Constants.OUTPOST_TO_COLONY_REQUIRED_RICH_ECONOMY_COUNT:
			return false
		if rich_count >= Constants.OUTPOST_TO_COLONY_SELF_SUFFICIENT_RICH_ECONOMY_COUNT:
			return true
		return _outpost_colony_growth_support_score(sector_id) >= Constants.OUTPOST_TO_COLONY_GROWTH_SUPPORT_REQUIRED
	return true


func _meets_colony_upgrade_economy_floor(tags: Array) -> bool:
	for req in Constants.COLONY_UPGRADE_REQUIRED_ECONOMY:
		if not (req in tags or req.replace("_ADEQUATE", "_RICH") in tags):
			return false
	return true


func _rich_economy_tag_count(tags: Array) -> int:
	var rich_count: int = 0
	for tag in tags:
		if str(tag).ends_with("_RICH"):
			rich_count += 1
	return rich_count


func _outpost_colony_growth_support_score(sector_id: String) -> int:
	if sector_id == "":
		return 0

	var support_score: int = 0
	if _grid_layer._has_active_commerce_presence(sector_id):
		support_score += 1

	for neighbor_id in GameState.world_topology.get(sector_id, {}).get("connections", []):
		var neighbor_level: String = GameState.colony_levels.get(neighbor_id, "frontier")
		if neighbor_level in ["colony", "hub"]:
			support_score += 2
			continue
		if neighbor_level != "outpost":
			continue

		var neighbor_tags: Array = GameState.sector_tags.get(neighbor_id, [])
		if Constants.COLONY_UPGRADE_REQUIRED_SECURITY in neighbor_tags and _meets_colony_upgrade_economy_floor(neighbor_tags):
			support_score += 1

	return support_score


func _colony_upgrade_security_ok(tags: Array, level: String) -> bool:
	if level == "frontier":
		return _grid_layer._security_level_index(_grid_layer._security_tag(tags)) >= _grid_layer._security_level_index(Constants.FRONTIER_TO_OUTPOST_REQUIRED_SECURITY)
	return Constants.COLONY_UPGRADE_REQUIRED_SECURITY in tags


func _colony_upgrade_environment_ok(tags: Array, level: String) -> bool:
	if level == "frontier":
		return not (Constants.FRONTIER_TO_OUTPOST_BLOCKED_ENVIRONMENT in tags)
	if level == "outpost":
		return not (Constants.OUTPOST_TO_COLONY_BLOCKED_ENVIRONMENT in tags)
	return true