#
# PROJECT: GDTLancer
# MODULE: grid_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §3.2 + TACTICAL_TODO.md TASK_7
# LOG_REF: 2026-02-21 (TASK_7)
#

extends Reference

## GridLayer: Tag-transition CA engine for economy, security, environment, and colony layers.
##
## Operates on GameState.sector_tags via qualitative tag transitions each tick.
## No numeric stockpiles, prices, or matter conservation — purely tag-based.
##
## Python reference: python_sandbox/core/simulation/grid_layer.py


const ECONOMY_LEVELS: Array = ["POOR", "ADEQUATE", "RICH"]
const SECURITY_LEVELS: Array = ["LAWLESS", "CONTESTED", "SECURE"]
const ENV_LEVELS: Array = ["EXTREME", "HARSH", "MILD"]
const CATEGORIES: Array = ["RAW", "MANUFACTURED", "CURRENCY"]


# =============================================================================
# === INITIALIZATION ==========================================================
# =============================================================================

## Seeds all Grid Layer state in GameState from World Layer topology + sector_tags.
## Called once at game start, after WorldLayer.initialize_world().
func initialize_grid() -> void:
	if GameState.colony_levels.empty():
		GameState.colony_levels = {}

	for sector_id in GameState.world_topology:
		var data: Dictionary = GameState.world_topology[sector_id]

		# Ensure sector_tags exist (should already be set by WorldLayer)
		if not GameState.sector_tags.has(sector_id):
			GameState.sector_tags[sector_id] = [
				"STATION", "CONTESTED", "MILD",
				"RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"
			]

		# Colony level
		if not GameState.colony_levels.has(sector_id):
			GameState.colony_levels[sector_id] = data.get("sector_type", "frontier")

		# Dominion
		if not GameState.grid_dominion.has(sector_id):
			GameState.grid_dominion[sector_id] = {
				"controlling_faction_id": "",
				"security_tag": _security_tag(GameState.sector_tags[sector_id]),
			}

		# Security progress counters
		if not GameState.security_upgrade_progress.has(sector_id):
			GameState.security_upgrade_progress[sector_id] = 0
		if not GameState.security_downgrade_progress.has(sector_id):
			GameState.security_downgrade_progress[sector_id] = 0
		if not GameState.security_change_threshold.has(sector_id):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(str(GameState.world_seed) + ":sec_thresh:" + sector_id)
			GameState.security_change_threshold[sector_id] = rng.randi_range(
				Constants.SECURITY_CHANGE_TICKS_MIN,
				Constants.SECURITY_CHANGE_TICKS_MAX
			)

		# Economy progress counters (per category)
		if not GameState.economy_upgrade_progress.has(sector_id):
			GameState.economy_upgrade_progress[sector_id] = {}
		if not GameState.economy_downgrade_progress.has(sector_id):
			GameState.economy_downgrade_progress[sector_id] = {}
		if not GameState.economy_change_threshold.has(sector_id):
			GameState.economy_change_threshold[sector_id] = {}

		for category in CATEGORIES:
			if not GameState.economy_upgrade_progress[sector_id].has(category):
				GameState.economy_upgrade_progress[sector_id][category] = 0
			if not GameState.economy_downgrade_progress[sector_id].has(category):
				GameState.economy_downgrade_progress[sector_id][category] = 0
			if not GameState.economy_change_threshold[sector_id].has(category):
				var thresh_rng := RandomNumberGenerator.new()
				thresh_rng.seed = hash(str(GameState.world_seed) + ":econ_thresh:" + sector_id + ":" + category)
				GameState.economy_change_threshold[sector_id][category] = thresh_rng.randi_range(
					Constants.ECONOMY_CHANGE_TICKS_MIN,
					Constants.ECONOMY_CHANGE_TICKS_MAX
				)

		# Hostile infestation progress
		if not GameState.hostile_infestation_progress.has(sector_id):
			GameState.hostile_infestation_progress[sector_id] = 0

	print("GridLayer: Initialized grid state for %d sectors." % GameState.world_topology.size())


# =============================================================================
# === TICK PROCESSING =========================================================
# =============================================================================

## Processes all Grid-layer tag-transition CA steps for one tick.
##
## @param config  Dictionary — tuning constants (unused in tag system, kept for API).
func process_tick(config: Dictionary) -> void:
	var new_tags: Dictionary = {}

	for sector_id in GameState.world_topology:
		var current: Array = Array(GameState.sector_tags.get(sector_id, []))
		var neighbors: Array = GameState.world_topology.get(sector_id, {}).get("connections", [])
		var neighbor_tags: Array = []
		for n in neighbors:
			neighbor_tags.append(GameState.sector_tags.get(n, []))

		var tags: Array = _step_economy(current, neighbor_tags, sector_id)
		tags = _step_security(tags, neighbor_tags, sector_id)
		tags = _step_environment(tags, sector_id)
		tags = _step_hostile_presence(tags, sector_id)
		tags = _step_colony_level(tags, sector_id)
		new_tags[sector_id] = _unique(tags)

	GameState.sector_tags = new_tags

	# Update dominion security_tag from new sector tags
	for sector_id in GameState.sector_tags:
		if not GameState.grid_dominion.has(sector_id):
			GameState.grid_dominion[sector_id] = {}
		GameState.grid_dominion[sector_id]["security_tag"] = _security_tag(GameState.sector_tags[sector_id])


# =============================================================================
# === PRIVATE — ECONOMY STEP ==================================================
# =============================================================================

func _step_economy(tags: Array, neighbor_tags: Array, sector_id: String) -> Array:
	var result: Array = Array(tags)
	var world_age: String = GameState.world_age if GameState.world_age else "PROSPERITY"
	var role_counts: Dictionary = _role_counts_for_sector(sector_id)

	var sector_upgrade_progress: Dictionary = GameState.economy_upgrade_progress.get(sector_id, {})
	var sector_downgrade_progress: Dictionary = GameState.economy_downgrade_progress.get(sector_id, {})
	var sector_thresholds: Dictionary = GameState.economy_change_threshold.get(sector_id, {})

	var loaded_trade: int = _loaded_trade_count_for_sector(sector_id)
	var colony_level: String = GameState.colony_levels.get(sector_id, "frontier")
	var has_active_commerce: bool = loaded_trade > 0 or colony_level in ["colony", "hub"]
	var has_pirate_or_infestation: bool = role_counts.get("pirate", 0) > 0 or "HOSTILE_INFESTED" in result

	for category in CATEGORIES:
		var level: String = _economy_level(result, category)
		var idx: int = ECONOMY_LEVELS.find(level)
		if idx < 0:
			idx = 1  # ADEQUATE fallback
		var delta: int = 0

		var threshold: int = sector_thresholds.get(category, Constants.ECONOMY_CHANGE_TICKS_MIN)

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
		if _active_agent_count_in_sector(sector_id) > 3:
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

		if up_progress >= threshold and idx < 2:
			idx = min(2, idx + 1)
			up_progress = 0
		elif down_progress >= threshold and idx > 0:
			idx = max(0, idx - 1)
			down_progress = 0

		sector_upgrade_progress[category] = up_progress
		sector_downgrade_progress[category] = down_progress

		result = _replace_prefix(result, category + "_", category + "_" + ECONOMY_LEVELS[idx])

	GameState.economy_upgrade_progress[sector_id] = sector_upgrade_progress
	GameState.economy_downgrade_progress[sector_id] = sector_downgrade_progress
	return result


# =============================================================================
# === PRIVATE — SECURITY STEP =================================================
# =============================================================================

func _step_security(tags: Array, neighbor_tags: Array, sector_id: String) -> Array:
	var result: Array = Array(tags)
	var security: String = _security_tag(result)
	var idx: int = SECURITY_LEVELS.find(security)
	if idx < 0:
		idx = 1  # CONTESTED fallback
	var role_counts: Dictionary = _role_counts_for_sector(sector_id)
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
	if role_counts.get("military", 0) > 0:
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

	if delta >= 1:
		up_progress += 1
		down_progress = 0
	elif delta <= -1:
		down_progress += 1
		up_progress = 0
	else:
		up_progress = 0
		down_progress = 0

	if up_progress >= threshold and idx < 2:
		idx = min(2, idx + 1)
		up_progress = 0
	elif down_progress >= threshold and idx > 0:
		idx = max(0, idx - 1)
		down_progress = 0

	GameState.security_upgrade_progress[sector_id] = up_progress
	GameState.security_downgrade_progress[sector_id] = down_progress

	result = _replace_one_of(result, ["SECURE", "CONTESTED", "LAWLESS"], SECURITY_LEVELS[idx])
	return result


# =============================================================================
# === PRIVATE — ENVIRONMENT STEP ==============================================
# =============================================================================

func _step_environment(tags: Array, sector_id: String) -> Array:
	var result: Array = Array(tags)
	var idx: int = ENV_LEVELS.find(_environment_tag(result))
	if idx < 0:
		idx = 2  # MILD fallback

	if GameState.world_age == "DISRUPTION":
		if idx == ENV_LEVELS.find("MILD"):
			idx = ENV_LEVELS.find("HARSH")
		elif idx == ENV_LEVELS.find("HARSH"):
			var role_counts: Dictionary = _role_counts_for_sector(sector_id)
			if role_counts.get("pirate", 0) > 0 or "HOSTILE_INFESTED" in result:
				idx = ENV_LEVELS.find("EXTREME")
	elif GameState.world_age == "RECOVERY":
		idx = min(2, idx + 1)

	if _sector_recently_disabled(sector_id):
		idx = 0  # EXTREME

	result = _replace_one_of(result, ["MILD", "HARSH", "EXTREME"], ENV_LEVELS[idx])
	return result


# =============================================================================
# === PRIVATE — HOSTILE PRESENCE STEP =========================================
# =============================================================================

func _step_hostile_presence(tags: Array, sector_id: String) -> Array:
	var result: Array = []
	for tag in tags:
		if tag != "HOSTILE_INFESTED" and tag != "HOSTILE_THREATENED":
			result.append(tag)

	var role_counts: Dictionary = _role_counts_for_sector(sector_id)
	var security: String = _security_tag(tags)
	var had_infested: bool = "HOSTILE_INFESTED" in tags
	var progress: int = GameState.hostile_infestation_progress.get(sector_id, 0)
	var infested_now: bool = had_infested

	if security == "LAWLESS" and role_counts.get("military", 0) == 0:
		if not had_infested:
			var build_progress: int = max(0, progress) + 1
			progress = build_progress
			if build_progress >= Constants.HOSTILE_INFESTATION_TICKS_REQUIRED:
				infested_now = true
				progress = 0
		else:
			progress = 0
	elif had_infested:
		var clear_progress: int = max(0, -progress) + 1
		progress = -clear_progress
		if clear_progress >= 2:
			infested_now = false
			progress = 0
	else:
		progress = 0

	GameState.hostile_infestation_progress[sector_id] = progress

	if infested_now:
		result.append("HOSTILE_INFESTED")
	elif security == "CONTESTED":
		result.append("HOSTILE_THREATENED")

	return result


# =============================================================================
# === PRIVATE — COLONY LEVEL STEP =============================================
# =============================================================================

func _step_colony_level(tags: Array, sector_id: String) -> Array:
	var level: String = GameState.colony_levels.get(sector_id, "frontier")
	var levels: Array = Constants.COLONY_LEVELS
	var up_progress: int = GameState.colony_upgrade_progress.get(sector_id, 0)
	var down_progress: int = GameState.colony_downgrade_progress.get(sector_id, 0)

	# Check upgrade requirements
	var economy_ok: bool = true
	for req in Constants.COLONY_UPGRADE_REQUIRED_ECONOMY:
		if not (req in tags or req.replace("_ADEQUATE", "_RICH") in tags):
			economy_ok = false
			break
	var security_ok: bool = Constants.COLONY_UPGRADE_REQUIRED_SECURITY in tags

	# Check downgrade triggers
	var degrade: bool = Constants.COLONY_DOWNGRADE_SECURITY_TRIGGER in tags
	if not degrade:
		for trigger in Constants.COLONY_DOWNGRADE_ECONOMY_TRIGGER:
			if trigger in tags:
				degrade = true
				break

	if economy_ok and security_ok:
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

	if up_progress >= Constants.COLONY_UPGRADE_TICKS_REQUIRED and level_idx < levels.size() - 1:
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


# =============================================================================
# === PRIVATE — AGENT QUERIES =================================================
# =============================================================================

## Count agents carrying cargo (LOADED) in a sector.
func _loaded_trade_count_for_sector(sector_id: String) -> int:
	var count: int = 0
	for agent_id in GameState.agents:
		var agent: Dictionary = GameState.agents[agent_id]
		if agent.get("is_disabled", false):
			continue
		if agent.get("current_sector_id", "") != sector_id:
			continue
		if agent.get("cargo_tag", "") == "LOADED":
			count += 1
	return count


## Count agents by role in a sector.
func _role_counts_for_sector(sector_id: String) -> Dictionary:
	var counts: Dictionary = {}
	for agent_id in GameState.agents:
		var agent: Dictionary = GameState.agents[agent_id]
		if agent.get("is_disabled", false):
			continue
		if agent.get("current_sector_id", "") != sector_id:
			continue
		var role: String = agent.get("agent_role", "idle")
		counts[role] = counts.get(role, 0) + 1
	return counts


## Count active non-player agents in a sector.
func _active_agent_count_in_sector(sector_id: String) -> int:
	var count: int = 0
	for agent_id in GameState.agents:
		if agent_id == "player":
			continue
		var agent: Dictionary = GameState.agents[agent_id]
		if agent.get("is_disabled", false):
			continue
		if agent.get("current_sector_id", "") == sector_id:
			count += 1
	return count


# =============================================================================
# === PRIVATE — TAG HELPERS ===================================================
# =============================================================================

func _economy_level(tags: Array, category: String) -> String:
	for level in ECONOMY_LEVELS:
		if (category + "_" + level) in tags:
			return level
	return "ADEQUATE"


func _security_tag(tags: Array) -> String:
	for tag in SECURITY_LEVELS:
		if tag in tags:
			return tag
	return "CONTESTED"


func _environment_tag(tags: Array) -> String:
	for tag in ENV_LEVELS:
		if tag in tags:
			return tag
	return "MILD"


## Replaces all tags starting with prefix with a single replacement tag.
func _replace_prefix(tags: Array, prefix: String, replacement: String) -> Array:
	var base: Array = []
	for tag in tags:
		if not tag.begins_with(prefix):
			base.append(tag)
	base.append(replacement)
	return base


## Replaces any tag found in options with a single replacement tag.
func _replace_one_of(tags: Array, options: Array, replacement: String) -> Array:
	var base: Array = []
	for tag in tags:
		if not (tag in options):
			base.append(tag)
	base.append(replacement)
	return base


## Returns true if sector is currently disabled (catastrophe cooldown).
func _sector_recently_disabled(sector_id: String) -> bool:
	var until: int = GameState.sector_disabled_until.get(sector_id, 0)
	return until > GameState.sim_tick_count


## Deduplicates tags while preserving order.
func _unique(tags: Array) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for tag in tags:
		if not seen.has(tag):
			seen[tag] = true
			out.append(tag)
	return out
