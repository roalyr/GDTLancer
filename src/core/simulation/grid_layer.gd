# PROJECT: GDTLancer
# MODULE: grid_layer.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: grid_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §3.2 + TACTICAL_TODO.md TASK_3
# LOG_REF: 2026-05-26 19:02:00
#

extends Reference

const EconomyProgressionSystemScript = preload("res://src/core/simulation/grid_layer/economy_progression_system.gd")
const SecurityProgressionSystemScript = preload("res://src/core/simulation/grid_layer/security_progression_system.gd")
const ColonyProgressionSystemScript = preload("res://src/core/simulation/grid_layer/colony_progression_system.gd")

## GridLayer: Tag-transition CA engine for economy, security, environment, and colony layers.
##
## Operates on GameState.sector_tags via qualitative tag transitions each tick.
## No open-ended stockpiles or prices; only bounded internal counters back runtime contract cargo/payment.
##
## Python reference: python_sandbox/core/simulation/grid_layer.py


const ECONOMY_LEVELS: Array = ["POOR", "ADEQUATE", "RICH"]
const SECURITY_LEVELS: Array = ["LAWLESS", "CONTESTED", "SECURE"]
const ENV_LEVELS: Array = ["EXTREME", "HARSH", "MILD"]
const CATEGORIES: Array = ["RAW", "MANUFACTURED", "CURRENCY"]

## Sub-systems
var economy: Reference
var security: Reference
var colony: Reference

func _init() -> void:
	economy = EconomyProgressionSystemScript.new()
	security = SecurityProgressionSystemScript.new()
	colony = ColonyProgressionSystemScript.new()
	economy.initialize(self)
	security.initialize(self)
	colony.initialize(self)


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
			GameState.colony_levels[sector_id] = data.get("development_level", "frontier")

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
		if not GameState.contract_generation_pressure.has(sector_id):
			GameState.contract_generation_pressure[sector_id] = {}
		if not GameState.contract_generation_threshold.has(sector_id):
			GameState.contract_generation_threshold[sector_id] = {}

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
			if not GameState.contract_generation_pressure[sector_id].has(category):
				GameState.contract_generation_pressure[sector_id][category] = 0
			if not GameState.contract_generation_threshold[sector_id].has(category):
				var contract_rng := RandomNumberGenerator.new()
				contract_rng.seed = hash(str(GameState.world_seed) + ":contract_thresh:" + sector_id + ":" + category)
				GameState.contract_generation_threshold[sector_id][category] = contract_rng.randi_range(
					Constants.CONTRACT_PRESSURE_TICKS_MIN,
					Constants.CONTRACT_PRESSURE_TICKS_MAX
				)

		# Hostile infestation progress
		if not GameState.hostile_infestation_progress.has(sector_id):
			GameState.hostile_infestation_progress[sector_id] = 0

	_refresh_contract_accounting_state(true)

	if Constants.VERBOSE_RUNTIME_LOGS:
		print("GridLayer: Initialized grid state for %d sectors." % GameState.world_topology.size())


## Seeds contract-demand tags and pressure from the authored starting world state
## so the player-facing contract board is populated before the first live tick.
func seed_initial_contract_demand() -> void:
	for sector_id in GameState.world_topology:
		var tags: Array = Array(GameState.sector_tags.get(sector_id, []))
		var serviceable: bool = _is_contract_service_sector(tags)
		var sector_disabled: bool = _sector_recently_disabled(sector_id)
		var sector_pressure: Dictionary = GameState.contract_generation_pressure.get(sector_id, {})
		var sector_thresholds: Dictionary = GameState.contract_generation_threshold.get(sector_id, {})
		var demand_count: int = 0

		for category in CATEGORIES:
			var poor_tag: String = category + "_POOR"
			var demand_tag: String = _contract_demand_tag(category)
			var threshold: int = int(sector_thresholds.get(category, Constants.CONTRACT_PRESSURE_TICKS_MIN))
			var can_generate: bool = serviceable and (poor_tag in tags) and not sector_disabled

			if can_generate:
				sector_pressure[category] = max(int(sector_pressure.get(category, 0)), threshold)
				tags = _add_tag(tags, demand_tag)
			else:
				tags = _remove_tag(tags, demand_tag)

			if demand_tag in tags:
				demand_count += 1

		GameState.contract_generation_pressure[sector_id] = sector_pressure
		tags = _remove_tag(tags, "TRADE_LANE_ACTIVE")

		var needs_relief: bool = demand_count >= 2
		if demand_count > 0 and (_security_tag(tags) != "SECURE" or GameState.world_age == "DISRUPTION"):
			needs_relief = true

		if needs_relief:
			tags = _add_tag(tags, "RELIEF_NEEDED")
		else:
			tags = _remove_tag(tags, "RELIEF_NEEDED")

		GameState.sector_tags[sector_id] = _unique(tags)

	_refresh_contract_accounting_state(false)


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
		tags = _step_contract_demand(tags, sector_id)
		new_tags[sector_id] = _unique(tags)

	GameState.sector_tags = new_tags

	# Update dominion security_tag from new sector tags
	for sector_id in GameState.sector_tags:
		if not GameState.grid_dominion.has(sector_id):
			GameState.grid_dominion[sector_id] = {}
		GameState.grid_dominion[sector_id]["security_tag"] = _security_tag(GameState.sector_tags[sector_id])

	_refresh_contract_accounting_state(false)


# =============================================================================
# === PRIVATE — ECONOMY STEP ==================================================
# =============================================================================

func _step_economy(tags: Array, neighbor_tags: Array, sector_id: String) -> Array:
	return economy._step_economy(tags, neighbor_tags, sector_id)


# =============================================================================
# === PRIVATE — SECURITY STEP =================================================
# =============================================================================

func _step_security(tags: Array, neighbor_tags: Array, sector_id: String) -> Array:
	return security._step_security(tags, neighbor_tags, sector_id)


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
	return colony._step_colony_level(tags, sector_id)


# =============================================================================
# === PRIVATE — CONTRACT DEMAND STEP ==========================================
# =============================================================================

func _step_contract_demand(tags: Array, sector_id: String) -> Array:
	var result: Array = Array(tags)
	var serviceable: bool = _is_contract_service_sector(result)
	var active_relief: bool = _has_active_trade_relief(sector_id)
	var sector_disabled: bool = _sector_recently_disabled(sector_id)
	var sector_pressure: Dictionary = GameState.contract_generation_pressure.get(sector_id, {})
	var sector_thresholds: Dictionary = GameState.contract_generation_threshold.get(sector_id, {})
	var demand_count: int = 0

	for category in CATEGORIES:
		var poor_tag: String = category + "_POOR"
		var demand_tag: String = _contract_demand_tag(category)
		var threshold: int = sector_thresholds.get(category, Constants.CONTRACT_PRESSURE_TICKS_MIN)
		var pressure: int = sector_pressure.get(category, 0)
		var can_generate: bool = serviceable and (poor_tag in result) and not sector_disabled

		if can_generate:
			if active_relief:
				pressure = max(0, pressure - Constants.CONTRACT_RELIEF_DECAY_PER_TICK)
			else:
				pressure = min(Constants.CONTRACT_PRESSURE_CAP, pressure + 1)
		else:
			pressure = max(0, pressure - 1)

		sector_pressure[category] = pressure
		if can_generate and pressure >= threshold:
			result = _add_tag(result, demand_tag)
		else:
			result = _remove_tag(result, demand_tag)

		if demand_tag in result:
			demand_count += 1

	GameState.contract_generation_pressure[sector_id] = sector_pressure

	if active_relief and demand_count > 0:
		result = _add_tag(result, "TRADE_LANE_ACTIVE")
	else:
		result = _remove_tag(result, "TRADE_LANE_ACTIVE")

	var needs_relief: bool = demand_count >= 2
	if demand_count > 0 and (_security_tag(result) != "SECURE" or GameState.world_age == "DISRUPTION"):
		needs_relief = true

	if needs_relief:
		result = _add_tag(result, "RELIEF_NEEDED")
	else:
		result = _remove_tag(result, "RELIEF_NEEDED")

	return result


func _refresh_contract_accounting_state(initial_seed: bool) -> void:
	for sector_id in GameState.world_topology:
		_ensure_contract_accounting_sector(sector_id)
		var tags: Array = Array(GameState.sector_tags.get(sector_id, []))
		var cargo_supply: Dictionary = GameState.contract_cargo_supply.get(sector_id, {})
		var cargo_reserved: Dictionary = GameState.contract_cargo_reserved.get(sector_id, {})
		var payment_supply: Dictionary = GameState.contract_payment_supply.get(sector_id, {})
		var payment_reserved: Dictionary = GameState.contract_payment_reserved.get(sector_id, {})

		for category in CATEGORIES:
			cargo_supply[category] = _step_contract_accounting_supply(
				int(cargo_supply.get(category, 0)),
				_contract_cargo_supply_cap(tags, sector_id, category),
				initial_seed
			)
			cargo_reserved[category] = max(0, int(cargo_reserved.get(category, 0)))
			payment_supply[category] = _step_contract_accounting_supply(
				int(payment_supply.get(category, 0)),
				_contract_payment_supply_cap(tags, sector_id, category),
				initial_seed
			)
			payment_reserved[category] = max(0, int(payment_reserved.get(category, 0)))

		GameState.contract_cargo_supply[sector_id] = cargo_supply
		GameState.contract_cargo_reserved[sector_id] = cargo_reserved
		GameState.contract_payment_supply[sector_id] = payment_supply
		GameState.contract_payment_reserved[sector_id] = payment_reserved


func _ensure_contract_accounting_sector(sector_id: String) -> void:
	if not GameState.contract_cargo_supply.has(sector_id):
		GameState.contract_cargo_supply[sector_id] = {}
	if not GameState.contract_cargo_reserved.has(sector_id):
		GameState.contract_cargo_reserved[sector_id] = {}
	if not GameState.contract_payment_supply.has(sector_id):
		GameState.contract_payment_supply[sector_id] = {}
	if not GameState.contract_payment_reserved.has(sector_id):
		GameState.contract_payment_reserved[sector_id] = {}


func _step_contract_accounting_supply(current_supply: int, cap: int, initial_seed: bool) -> int:
	var bounded_cap: int = max(0, cap)
	var bounded_supply: int = max(0, current_supply)
	if initial_seed:
		return bounded_cap
	if bounded_supply < bounded_cap:
		return bounded_supply + 1
	if bounded_supply > bounded_cap:
		return bounded_supply - 1
	return bounded_supply


func _contract_cargo_supply_cap(tags: Array, sector_id: String, category: String) -> int:
	if not _is_contract_service_sector(tags) or _sector_recently_disabled(sector_id):
		return 0

	var base_supply: int = 0
	match _economy_level(tags, category):
		"ADEQUATE":
			base_supply = 1
		"RICH":
			base_supply = 2
		_:
			base_supply = 0

	if base_supply <= 0:
		return 0

	var colony_level: String = str(GameState.colony_levels.get(sector_id, "frontier"))
	match colony_level:
		"frontier":
			return int(min(base_supply, 1))
		"colony", "hub":
			return base_supply + 1
		_:
			return base_supply


func _contract_payment_supply_cap(tags: Array, sector_id: String, category: String) -> int:
	if not _is_contract_service_sector(tags) or _sector_recently_disabled(sector_id):
		return 0

	var base_supply: int = 1
	match str(GameState.colony_levels.get(sector_id, "frontier")):
		"colony":
			base_supply = 2
		"hub":
			base_supply = 3
		_:
			base_supply = 1

	if _security_tag(tags) == "LAWLESS":
		base_supply = max(0, base_supply - 1)

	if _contract_demand_tag(category) in tags or (category + "_POOR") in tags:
		base_supply = max(base_supply, 1)

	return base_supply


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


func _has_active_trade_relief(sector_id: String) -> bool:
	return _has_active_commerce_presence(sector_id)


func _has_active_commerce_presence(sector_id: String) -> bool:
	var role_counts: Dictionary = _role_counts_for_sector(sector_id)
	return _loaded_trade_count_for_sector(sector_id) > 0 \
		or role_counts.get("trader", 0) > 0 \
		or role_counts.get("hauler", 0) > 0


func _prosperity_growth_stage() -> int:
	if GameState.world_age != "PROSPERITY":
		return 0
	var total_ticks: int = int(Constants.WORLD_AGE_DURATIONS.get("PROSPERITY", 0))
	var current_timer: int = int(GameState.world_age_timer)
	if total_ticks <= 0 or current_timer <= 0:
		return 0
	var elapsed_ticks: int = total_ticks - current_timer
	if elapsed_ticks < 0:
		elapsed_ticks = 0
	var progress_ratio: float = float(elapsed_ticks) / float(total_ticks)
	if progress_ratio >= Constants.PROSPERITY_GROWTH_STAGE_2_RATIO:
		return 2
	if progress_ratio >= Constants.PROSPERITY_GROWTH_STAGE_1_RATIO:
		return 1
	return 0


# Progression helper methods removed; delegated to economy/security/colony systems.


# =============================================================================
# === PRIVATE — TAG HELPERS ===================================================
# =============================================================================

func _is_contract_service_sector(tags: Array) -> bool:
	return "STATION" in tags or "FRONTIER" in tags


func _contract_demand_tag(category: String) -> String:
	return "CONTRACT_DEMAND_%s" % category

func _economy_level(tags: Array, category: String) -> String:
	return economy._economy_level(tags, category)


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


func _security_level_index(security_tag: String) -> int:
	var idx: int = SECURITY_LEVELS.find(security_tag)
	return idx if idx >= 0 else 1


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


func _add_tag(tags: Array, tag: String) -> Array:
	var result: Array = Array(tags)
	if not (tag in result):
		result.append(tag)
	return result


func _remove_tag(tags: Array, tag: String) -> Array:
	var result: Array = []
	for existing_tag in tags:
		if existing_tag != tag:
			result.append(existing_tag)
	return result


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


# =============================================================================
# === DELEGATION WRAPPERS FOR BACKWARD COMPATIBILITY ==========================
# =============================================================================

func _economy_upgrade_threshold_for_level(base_threshold: int, colony_level: String) -> int:
	return economy._economy_upgrade_threshold_for_level(base_threshold, colony_level)

func _economy_max_index_for_level(colony_level: String) -> int:
	return economy._economy_max_index_for_level(colony_level)

func _security_upgrade_threshold_for_level(base_threshold: int, colony_level: String) -> int:
	return security._security_upgrade_threshold_for_level(base_threshold, colony_level)

func _security_max_index_for_level(colony_level: String) -> int:
	return security._security_max_index_for_level(colony_level)

func _colony_upgrade_threshold_for_level(level: String) -> int:
	return colony._colony_upgrade_threshold_for_level(level)

func _minimum_colony_upgrade_threshold_for_level(level: String) -> int:
	return colony._minimum_colony_upgrade_threshold_for_level(level)

func _colony_upgrade_economy_ok(tags: Array, level: String, sector_id: String = "") -> bool:
	return colony._colony_upgrade_economy_ok(tags, level, sector_id)

func _meets_colony_upgrade_economy_floor(tags: Array) -> bool:
	return colony._meets_colony_upgrade_economy_floor(tags)

func _rich_economy_tag_count(tags: Array) -> int:
	return colony._rich_economy_tag_count(tags)

func _outpost_colony_growth_support_score(sector_id: String) -> int:
	return colony._outpost_colony_growth_support_score(sector_id)

func _colony_upgrade_security_ok(tags: Array, level: String) -> bool:
	return colony._colony_upgrade_security_ok(tags, level)

func _colony_upgrade_environment_ok(tags: Array, level: String) -> bool:
	return colony._colony_upgrade_environment_ok(tags, level)
