# PROJECT: GDTLancer
# MODULE: security_progression_system.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §3.2 + TACTICAL_TODO.md TASK_3
# LOG_REF: 2026-06-12 23:25:00

extends Reference

const SECURITY_LEVELS: Array = ["LAWLESS", "CONTESTED", "SECURE"]

var _grid_layer: Reference

func initialize(grid_layer_ref: Reference) -> void:
	_grid_layer = grid_layer_ref


func _step_security(tags: Array, neighbor_tags: Array, sector_id: String) -> Array:
	var result: Array = Array(tags)
	var security: String = _security_tag(result)
	var idx: int = SECURITY_LEVELS.find(security)
	if idx < 0:
		idx = 1  # CONTESTED fallback
	var colony_level: String = GameState.colony_levels.get(sector_id, "frontier")
	var max_idx_for_level: int = _security_max_index_for_level(colony_level)
	var role_counts: Dictionary = _grid_layer._role_counts_for_sector(sector_id)
	var delta: int = 0

	# Homeostatic pressure
	if security == "SECURE":
		delta -= 1
	elif security == "LAWLESS":
		delta += 1

	# World age influence
	if GameState.world_age == "DISRUPTION":
		delta -= 1
	elif GameState.world_age in ["PROSPERITY", "RECOVERY"]:
		delta += 1

	# Agent presence
	if role_counts.get("patrol", 0) > 0:
		delta += 1
	if role_counts.get("pirate", 0) > 0:
		delta -= 1
	if "HOSTILE_INFESTED" in result:
		delta -= 1

	# Regional influence from neighbors
	var neighbor_indices: Array = []
	for n_tags in neighbor_tags:
		if n_tags and not n_tags.empty():
			var n_idx: int = SECURITY_LEVELS.find(_security_tag(n_tags))
			if n_idx >= 0:
				neighbor_indices.append(n_idx)

	if not neighbor_indices.empty():
		var total: float = 0.0
		for ni in neighbor_indices:
			total += float(ni)
		var avg: float = total / float(neighbor_indices.size())
		if avg > float(idx):
			delta += 1
		elif avg < float(idx):
			delta -= 1

	# Progress-counter gating
	var up_progress: int = GameState.security_upgrade_progress.get(sector_id, 0)
	var down_progress: int = GameState.security_downgrade_progress.get(sector_id, 0)
	var threshold: int = GameState.security_change_threshold.get(
		sector_id, Constants.SECURITY_CHANGE_TICKS_MIN
	)
	var upgrade_threshold: int = _security_upgrade_threshold_for_level(threshold, colony_level)

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

	GameState.security_upgrade_progress[sector_id] = up_progress
	GameState.security_downgrade_progress[sector_id] = down_progress

	result = _grid_layer._replace_one_of(result, ["SECURE", "CONTESTED", "LAWLESS"], SECURITY_LEVELS[idx])
	return result


func _security_upgrade_threshold_for_level(base_threshold: int, colony_level: String) -> int:
	var threshold: int = base_threshold
	if colony_level == "frontier":
		threshold += Constants.FRONTIER_SECURITY_UPGRADE_TICKS_BONUS
	elif colony_level == "outpost":
		threshold += Constants.OUTPOST_SECURITY_UPGRADE_TICKS_BONUS

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

	if threshold < Constants.SECURITY_CHANGE_TICKS_MIN:
		threshold = Constants.SECURITY_CHANGE_TICKS_MIN
	return threshold


func _security_max_index_for_level(colony_level: String) -> int:
	if colony_level == "frontier":
		var frontier_max_idx: int = SECURITY_LEVELS.find(Constants.FRONTIER_MAX_SECURITY_LEVEL)
		return frontier_max_idx if frontier_max_idx >= 0 else 1
	return SECURITY_LEVELS.size() - 1


func _security_tag(tags: Array) -> String:
	for tag in SECURITY_LEVELS:
		if tag in tags:
			return tag
	return "CONTESTED"


func _security_level_index(security_tag: String) -> int:
	var idx: int = SECURITY_LEVELS.find(security_tag)
	return idx if idx >= 0 else 1