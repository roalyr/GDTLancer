#
# PROJECT: GDTLancer
# MODULE: contract_generation_system.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §3.3, §3.4, §6.3, §6.4; TACTICAL_TODO.md TASK_2
# LOG_REF: 2026-06-06 00:20:00
#

extends Reference

## ContractGenerationSystem: Builds runtime qualitative contract occurrences
## from active sector demand tags without relying on authored templates.

const CATEGORIES: Array = ["RAW", "MANUFACTURED", "CURRENCY"]
const SECURITY_TAGS: Array = ["SECURE", "CONTESTED", "LAWLESS"]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func process_tick(config: Dictionary) -> void:
	_rng.seed = hash(str(GameState.world_seed) + ":contract_generation:" + str(GameState.sim_tick_count))
	var previous_occurrences: Dictionary = GameState.runtime_contract_occurrences
	var generated_occurrences: Dictionary = {}
	var occurrences_by_target: Dictionary = {}
	var occurrences_by_source: Dictionary = {}
	var allocated_source_backing: Dictionary = {}
	var allocated_payment_backing: Dictionary = {}
	var sector_ids: Array = GameState.world_topology.keys()
	sector_ids.sort()
	var global_cap: int = int(config.get("contract_occurrence_global_cap", Constants.CONTRACT_OCCURRENCE_GLOBAL_CAP))
	var per_sector_cap: int = int(config.get("contract_occurrence_per_sector_cap", Constants.CONTRACT_OCCURRENCE_PER_SECTOR_CAP))
	_seed_retained_occurrences(
		previous_occurrences,
		generated_occurrences,
		occurrences_by_target,
		occurrences_by_source,
		global_cap,
		allocated_source_backing,
		allocated_payment_backing
	)

	for sector_id in sector_ids:
		if generated_occurrences.size() >= global_cap:
			break

		var target_tags: Array = Array(GameState.sector_tags.get(sector_id, []))
		var demand_categories: Array = _active_demand_categories(target_tags)
		if demand_categories.empty():
			continue

		var generated_for_sector: int = 0
		for category in demand_categories:
			if generated_occurrences.size() >= global_cap:
				break
			if generated_for_sector >= per_sector_cap:
				break

			var occurrence_id: String = _occurrence_id(sector_id, category)
			if _was_completed_last_tick(previous_occurrences.get(occurrence_id, {})):
				continue
			if generated_occurrences.has(occurrence_id):
				generated_for_sector += 1
				continue
			if not _can_allocate_target_payment(sector_id, category, allocated_payment_backing):
				continue

			var source_packet: Dictionary = _find_best_source_sector(sector_id, category, config, allocated_source_backing)
			if source_packet.empty():
				continue

			var occurrence: Dictionary = _build_occurrence(
				occurrence_id,
				sector_id,
				category,
				target_tags,
				source_packet
			)
			occurrence = _merge_existing_occurrence_state(
				occurrence,
				previous_occurrences.get(occurrence_id, {})
			)
			_register_occurrence_accounting(occurrence, allocated_source_backing, allocated_payment_backing)
			generated_occurrences[occurrence_id] = occurrence
			_index_occurrence(occurrences_by_target, sector_id, occurrence_id)
			_index_occurrence(occurrences_by_source, str(source_packet.get("sector_id", "")), occurrence_id)
			generated_for_sector += 1

	GameState.runtime_contract_occurrences = generated_occurrences
	GameState.runtime_contract_occurrences_by_target_sector = occurrences_by_target
	GameState.runtime_contract_occurrences_by_source_sector = occurrences_by_source


func _seed_retained_occurrences(
	previous_occurrences: Dictionary,
	generated_occurrences: Dictionary,
	occurrences_by_target: Dictionary,
	occurrences_by_source: Dictionary,
	global_cap: int,
	allocated_source_backing: Dictionary,
	allocated_payment_backing: Dictionary
) -> void:
	var occurrence_ids: Array = previous_occurrences.keys()
	occurrence_ids.sort()
	for occurrence_id in occurrence_ids:
		if generated_occurrences.size() >= global_cap:
			break
		var previous_occurrence: Dictionary = previous_occurrences.get(occurrence_id, {})
		if not (_should_retain_claimed_occurrence(previous_occurrence) or _should_retain_recent_open_occurrence(previous_occurrence)):
			_cleanup_unretained_claim(previous_occurrence)
			continue
		var retained_occurrence: Dictionary = previous_occurrence.duplicate(true)
		retained_occurrence["last_refreshed_tick"] = GameState.sim_tick_count
		generated_occurrences[occurrence_id] = retained_occurrence
		_index_occurrence(
			occurrences_by_target,
			str(retained_occurrence.get("target_sector_id", "")),
			occurrence_id
		)
		_index_occurrence(
			occurrences_by_source,
			str(retained_occurrence.get("source_sector_id", "")),
			occurrence_id
		)
		_register_occurrence_accounting(retained_occurrence, allocated_source_backing, allocated_payment_backing)


func _should_retain_claimed_occurrence(previous_occurrence: Dictionary) -> bool:
	if previous_occurrence.empty():
		return false
	var claimant_agent_id: String = str(previous_occurrence.get("claimant_agent_id", ""))
	if claimant_agent_id == "":
		return false
	var status: String = str(previous_occurrence.get("status", "open"))
	if not (status in ["claimed", "in_transit"]):
		return false
	if not _claimant_is_valid(claimant_agent_id, previous_occurrence):
		return false
	if not bool(previous_occurrence.get("cargo_picked_up", false)):
		return _pre_pickup_occurrence_remains_serviceable(previous_occurrence)
	return true


func _should_retain_recent_open_occurrence(previous_occurrence: Dictionary) -> bool:
	if previous_occurrence.empty():
		return false
	if str(previous_occurrence.get("status", "open")) != "open":
		return false
	if str(previous_occurrence.get("claimant_agent_id", "")) != "":
		return false
	if not bool(previous_occurrence.get("player_displayable", true)):
		return false
	var created_at_tick: int = int(previous_occurrence.get("created_at_tick", -1))
	if created_at_tick < 0:
		return false
	return created_at_tick >= GameState.sim_tick_count - 1


func _merge_existing_occurrence_state(occurrence: Dictionary, previous_occurrence: Dictionary) -> Dictionary:
	if previous_occurrence.empty():
		return occurrence
	if previous_occurrence.has("commodity_id"):
		occurrence["commodity_id"] = str(previous_occurrence.get("commodity_id", "commodity_default"))
	if previous_occurrence.has("created_at_tick"):
		occurrence["created_at_tick"] = int(previous_occurrence.get("created_at_tick", GameState.sim_tick_count))
	if previous_occurrence.has("source_accounting_sector_id"):
		occurrence["source_accounting_sector_id"] = str(previous_occurrence.get("source_accounting_sector_id", occurrence.get("source_sector_id", "")))
	if previous_occurrence.has("payment_accounting_sector_id"):
		occurrence["payment_accounting_sector_id"] = str(previous_occurrence.get("payment_accounting_sector_id", occurrence.get("target_sector_id", "")))
	var claimant_agent_id: String = str(previous_occurrence.get("claimant_agent_id", ""))
	if claimant_agent_id != "" and _claimant_is_valid(claimant_agent_id, occurrence):
		occurrence["claimant_agent_id"] = claimant_agent_id
		occurrence["status"] = str(previous_occurrence.get("status", "claimed"))
		if previous_occurrence.has("claimed_at_tick"):
			occurrence["claimed_at_tick"] = int(previous_occurrence.get("claimed_at_tick", GameState.sim_tick_count))
	if previous_occurrence.has("completed_at_tick"):
		occurrence["completed_at_tick"] = int(previous_occurrence.get("completed_at_tick", -1))
	if previous_occurrence.has("player_displayable"):
		occurrence["player_displayable"] = bool(previous_occurrence.get("player_displayable", true))
	if previous_occurrence.has("required_cargo_tag"):
		occurrence["required_cargo_tag"] = str(previous_occurrence.get("required_cargo_tag", ""))
	if previous_occurrence.has("reward_credits"):
		occurrence["reward_credits"] = int(previous_occurrence.get("reward_credits", 0))
	if previous_occurrence.has("source_reserved"):
		occurrence["source_reserved"] = bool(previous_occurrence.get("source_reserved", false))
	if previous_occurrence.has("payment_reserved"):
		occurrence["payment_reserved"] = bool(previous_occurrence.get("payment_reserved", false))
	if previous_occurrence.has("cargo_picked_up"):
		occurrence["cargo_picked_up"] = bool(previous_occurrence.get("cargo_picked_up", false))
	return occurrence


func _was_completed_last_tick(previous_occurrence: Dictionary) -> bool:
	if previous_occurrence.empty():
		return false
	if str(previous_occurrence.get("status", "open")) != "completed":
		return false
	var completed_at_tick: int = int(previous_occurrence.get("completed_at_tick", -1))
	return completed_at_tick >= 0 and completed_at_tick < GameState.sim_tick_count


func _claimant_is_valid(agent_id: String, occurrence: Dictionary) -> bool:
	if agent_id == "" or not GameState.agents.has(agent_id):
		return false
	var agent: Dictionary = GameState.agents.get(agent_id, {})
	if agent.empty() or agent.get("is_disabled", false):
		return false
	if agent_id == "player":
		return str(GameState.player_claimed_occurrence_id) == str(occurrence.get("occurrence_id", ""))
	var required_roles: Array = Array(occurrence.get("required_roles", []))
	return str(agent.get("agent_role", "idle")) in required_roles


func _pre_pickup_occurrence_remains_serviceable(previous_occurrence: Dictionary) -> bool:
	var source_sector_id: String = str(previous_occurrence.get("source_sector_id", ""))
	var target_sector_id: String = str(previous_occurrence.get("target_sector_id", ""))
	return _occurrence_endpoint_is_serviceable(source_sector_id) and _occurrence_endpoint_is_serviceable(target_sector_id)


func _occurrence_endpoint_is_serviceable(sector_id: String) -> bool:
	if sector_id == "":
		return false
	var tags: Array = Array(GameState.sector_tags.get(sector_id, []))
	if tags.empty():
		return false
	if "DISABLED" in tags:
		return false
	return _is_serviceable_sector(tags)


func _cleanup_unretained_claim(previous_occurrence: Dictionary) -> void:
	if previous_occurrence.empty():
		return
	if str(previous_occurrence.get("claimant_agent_id", "")) == "":
		return
	var status: String = str(previous_occurrence.get("status", "open"))
	if not (status in ["claimed", "in_transit"]):
		return
	var category: String = str(previous_occurrence.get("commodity_category", ""))
	var source_sector_id: String = str(previous_occurrence.get("source_accounting_sector_id", previous_occurrence.get("source_sector_id", "")))
	var payment_sector_id: String = str(previous_occurrence.get("payment_accounting_sector_id", previous_occurrence.get("target_sector_id", "")))
	if bool(previous_occurrence.get("source_reserved", false)):
		_release_contract_accounting_unit(
			GameState.contract_cargo_supply,
			GameState.contract_cargo_reserved,
			source_sector_id,
			category
		)
	if bool(previous_occurrence.get("payment_reserved", false)):
		_release_contract_accounting_unit(
			GameState.contract_payment_supply,
			GameState.contract_payment_reserved,
			payment_sector_id,
			category
		)


func _active_demand_categories(tags: Array) -> Array:
	var categories: Array = []
	for category in CATEGORIES:
		if _contract_demand_tag(category) in tags:
			categories.append(category)
	return categories


func _find_best_source_sector(target_sector_id: String, category: String, config: Dictionary, allocated_source_backing: Dictionary) -> Dictionary:
	var max_hops: int = int(config.get("contract_source_search_max_hops", Constants.CONTRACT_SOURCE_SEARCH_MAX_HOPS))
	var frontier: Array = [{"sector_id": target_sector_id, "distance": 0}]
	var visited: Dictionary = {target_sector_id: true}
	var best_candidate: Dictionary = {}
	var best_score: float = -1000000.0
	var best_sector_id: String = ""

	while not frontier.empty():
		var packet: Dictionary = frontier[0]
		frontier.remove(0)
		var sector_id: String = str(packet.get("sector_id", ""))
		var distance: int = int(packet.get("distance", 0))

		if sector_id != target_sector_id and _is_qualifying_source_sector(sector_id, category, allocated_source_backing):
			var score: float = _source_score(sector_id, category, distance)
			if best_candidate.empty() or score > best_score or (is_equal_approx(score, best_score) and sector_id < best_sector_id):
				best_candidate = {"sector_id": sector_id, "distance": distance}
				best_score = score
				best_sector_id = sector_id

		if distance >= max_hops:
			continue

		var neighbor_ids: Array = Array(GameState.world_topology.get(sector_id, {}).get("connections", []))
		neighbor_ids.sort()
		for neighbor_id in neighbor_ids:
			if visited.has(neighbor_id):
				continue
			visited[neighbor_id] = true
			frontier.append({"sector_id": neighbor_id, "distance": distance + 1})

	return best_candidate


func _is_qualifying_source_sector(sector_id: String, category: String, allocated_source_backing: Dictionary) -> bool:
	var tags: Array = Array(GameState.sector_tags.get(sector_id, []))
	if tags.empty():
		return false
	if not _is_serviceable_sector(tags):
		return false
	if "DISABLED" in tags or "HOSTILE_INFESTED" in tags or "LAWLESS" in tags:
		return false
	if not ((category + "_ADEQUATE") in tags or (category + "_RICH") in tags):
		return false
	return _can_allocate_source_cargo(sector_id, category, allocated_source_backing)


func _source_score(sector_id: String, category: String, distance: int) -> float:
	var score: float = 0.0
	var tags: Array = Array(GameState.sector_tags.get(sector_id, []))
	if (category + "_RICH") in tags:
		score += 6.0
	elif (category + "_ADEQUATE") in tags:
		score += 3.0

	if "SECURE" in tags:
		score += 2.0
	elif "CONTESTED" in tags:
		score += 1.0

	if "TRADE_LANE_ACTIVE" in tags:
		score += 1.0
	if "STATION" in tags:
		score += 0.5

	score -= float(distance) * 1.5
	return score


func _build_occurrence(occurrence_id: String, target_sector_id: String, category: String, target_tags: Array, source_packet: Dictionary) -> Dictionary:
	var source_sector_id: String = str(source_packet.get("sector_id", ""))
	var route_hops: int = int(source_packet.get("distance", 0))
	var category_label: String = _category_label(category)
	var source_label: String = _sector_label(source_sector_id)
	var target_label: String = _sector_label(target_sector_id)
	var required_cargo_tag: String = _cargo_tag_for_category(category)
	# UI-facing reward metadata for player contract board; does not drive CA economy simulation.
	var reward_credits: int = _calculate_reward_credits(category, route_hops)
	var commodity_id: String = Constants.get_random_commodity_for_category(category, _rng)
	if commodity_id == "":
		commodity_id = "commodity_default"
	return {
		"occurrence_id": occurrence_id,
		"generator_id": "qualitative_demand",
		"contract_type": "delivery",
		"commodity_category": category,
		"commodity_id": commodity_id,
		"demand_tag": _contract_demand_tag(category),
		"source_sector_id": source_sector_id,
		"target_sector_id": target_sector_id,
		"source_accounting_sector_id": source_sector_id,
		"payment_accounting_sector_id": target_sector_id,
		"destination_sector_id": target_sector_id,
		"origin_location_id": source_sector_id,
		"destination_location_id": target_sector_id,
		"status": "open",
		"claimant_agent_id": "",
		"required_roles": ["trader", "hauler"],
		"priority_tags": _build_priority_tags(target_tags, category),
		"route_hops": route_hops,
		"created_at_tick": GameState.sim_tick_count,
		"completed_at_tick": -1,
		"last_refreshed_tick": GameState.sim_tick_count,
		"title": "%s Relief Route to %s" % [category_label, target_label],
		"description": "%s demand in %s can be relieved from %s." % [category_label, target_label, source_label],
		"player_displayable": true,
		"required_cargo_tag": required_cargo_tag,
		"reward_credits": reward_credits,
		"source_reserved": false,
		"payment_reserved": false,
		"cargo_picked_up": false,
	}


func _build_priority_tags(target_tags: Array, category: String) -> Array:
	var tags: Array = [_contract_demand_tag(category), _security_tag(target_tags)]
	if "RELIEF_NEEDED" in target_tags:
		tags.append("RELIEF_NEEDED")
	if GameState.world_age == "DISRUPTION":
		tags.append("WORLD_AGE_DISRUPTION")
	return _unique(tags)


func _occurrence_id(target_sector_id: String, category: String) -> String:
	return "runtime_contract:%s:%s" % [target_sector_id, category]


func _contract_demand_tag(category: String) -> String:
	return "CONTRACT_DEMAND_%s" % category


func _is_serviceable_sector(tags: Array) -> bool:
	return "STATION" in tags or "FRONTIER" in tags


func _category_label(category: String) -> String:
	match category:
		"RAW":
			return "Raw"
		"MANUFACTURED":
			return "Manufactured"
		"CURRENCY":
			return "Currency"
		_:
			return category.capitalize()


func _security_tag(tags: Array) -> String:
	for security_tag in SECURITY_TAGS:
		if security_tag in tags:
			return security_tag
	return "CONTESTED"


func _sector_label(sector_id: String) -> String:
	return str(GameState.sector_names.get(sector_id, sector_id))


func _cargo_tag_for_category(category: String) -> String:
	match category:
		"RAW":
			return "RAW_COMMODITY"
		"MANUFACTURED":
			return "MANUFACTURED_COMMODITY"
		"CURRENCY":
			return "CURRENCY_COMMODITY"
		_:
			return "UNKNOWN_COMMODITY"


func _calculate_reward_credits(category: String, route_hops: int) -> int:
	var base_reward: int = 0
	match category:
		"RAW":
			base_reward = 100
		"MANUFACTURED":
			base_reward = 150
		"CURRENCY":
			base_reward = 200
		_:
			base_reward = 50
	var distance_bonus: int = route_hops * 25
	return base_reward + distance_bonus


func _register_occurrence_accounting(occurrence: Dictionary, allocated_source_backing: Dictionary, allocated_payment_backing: Dictionary) -> void:
	var category: String = str(occurrence.get("commodity_category", ""))
	if not (category in CATEGORIES):
		return
	_increment_allocated_count(
		allocated_source_backing,
		str(occurrence.get("source_sector_id", "")),
		category
	)
	_increment_allocated_count(
		allocated_payment_backing,
		str(occurrence.get("target_sector_id", "")),
		category
	)


func _can_allocate_source_cargo(sector_id: String, category: String, allocated_source_backing: Dictionary) -> bool:
	return _allocated_count(allocated_source_backing, sector_id, category) < _sector_category_backing(
		GameState.contract_cargo_supply,
		GameState.contract_cargo_reserved,
		sector_id,
		category
	)


func _can_allocate_target_payment(sector_id: String, category: String, allocated_payment_backing: Dictionary) -> bool:
	return _allocated_count(allocated_payment_backing, sector_id, category) < _sector_category_backing(
		GameState.contract_payment_supply,
		GameState.contract_payment_reserved,
		sector_id,
		category
	)


func _sector_category_backing(supply_root: Dictionary, reserved_root: Dictionary, sector_id: String, category: String) -> int:
	if sector_id == "":
		return 0
	var supply_by_sector: Dictionary = supply_root.get(sector_id, {})
	var reserved_by_sector: Dictionary = reserved_root.get(sector_id, {})
	return int(max(0, int(supply_by_sector.get(category, 0)) + int(reserved_by_sector.get(category, 0))))


func _allocated_count(allocated_root: Dictionary, sector_id: String, category: String) -> int:
	if sector_id == "":
		return 0
	return int(allocated_root.get(sector_id, {}).get(category, 0))


func _increment_allocated_count(allocated_root: Dictionary, sector_id: String, category: String) -> void:
	if sector_id == "" or not (category in CATEGORIES):
		return
	var allocated_by_sector: Dictionary = allocated_root.get(sector_id, {})
	allocated_by_sector[category] = int(allocated_by_sector.get(category, 0)) + 1
	allocated_root[sector_id] = allocated_by_sector


func _release_contract_accounting_unit(supply_root: Dictionary, reserved_root: Dictionary, sector_id: String, category: String) -> bool:
	if sector_id == "" or category == "":
		return false
	var supply_by_sector: Dictionary = supply_root.get(sector_id, {})
	var reserved_by_sector: Dictionary = reserved_root.get(sector_id, {})
	var reserved_units: int = int(reserved_by_sector.get(category, 0))
	if reserved_units <= 0:
		return false
	reserved_by_sector[category] = reserved_units - 1
	supply_by_sector[category] = int(supply_by_sector.get(category, 0)) + 1
	supply_root[sector_id] = supply_by_sector
	reserved_root[sector_id] = reserved_by_sector
	return true


func _index_occurrence(index: Dictionary, sector_id: String, occurrence_id: String) -> void:
	if sector_id == "":
		return
	if not index.has(sector_id):
		index[sector_id] = []
	if occurrence_id in index[sector_id]:
		return
	index[sector_id].append(occurrence_id)


func _unique(values: Array) -> Array:
	var seen: Dictionary = {}
	var result: Array = []
	for value in values:
		if not seen.has(value):
			seen[value] = true
			result.append(value)
	return result