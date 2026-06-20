# PROJECT: GDTLancer
# MODULE: agent_contract.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: src/core/simulation/agent_layer/agent_contract.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: 1-GDD-Core-Mechanics.md § 6.1
# LOG_REF: 2026-06-14 01:00:09
#

extends Reference

var _agent_layer: Reference

func initialize(agent_layer_ref: Reference) -> void:
	_agent_layer = agent_layer_ref


func player_accept_runtime_contract(occurrence_id: String) -> bool:
	var selected_occurrence_id: String = str(occurrence_id)
	if selected_occurrence_id == "":
		return false

	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(selected_occurrence_id, {})
	if occurrence.empty():
		return false

	var existing_claim_id: String = str(GameState.player_claimed_occurrence_id)
	if existing_claim_id != "" and existing_claim_id != selected_occurrence_id:
		return false

	var claimant_agent_id: String = str(occurrence.get("claimant_agent_id", ""))
	if claimant_agent_id != "" and claimant_agent_id != "player":
		return false
	if claimant_agent_id == "" and not _reserve_runtime_contract_resources(occurrence):
		return false

	GameState.player_claimed_occurrence_id = selected_occurrence_id
	occurrence["claimant_agent_id"] = "player"
	occurrence["status"] = "claimed"
	occurrence["claimed_at_tick"] = GameState.sim_tick_count
	occurrence["last_refreshed_tick"] = GameState.sim_tick_count
	GameState.runtime_contract_occurrences[selected_occurrence_id] = occurrence

	if claimant_agent_id == "":
		_agent_layer._log_event("player", "contract_claimed", _player_current_sector_id(), {
			"occurrence_id": selected_occurrence_id,
			"target_sector_id": str(occurrence.get("target_sector_id", "")),
		})

	return true


func player_pick_up_runtime_contract(occurrence_id: String) -> bool:
	var selected_occurrence_id: String = str(occurrence_id)
	if selected_occurrence_id == "":
		return false
	if str(GameState.player_claimed_occurrence_id) != selected_occurrence_id:
		return false
	if not GameState.agents.has("player"):
		return false

	var player_agent: Dictionary = GameState.agents.get("player", {})
	if player_agent.empty():
		return false

	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(selected_occurrence_id, {})
	if occurrence.empty():
		return false
	if str(occurrence.get("claimant_agent_id", "")) != "player":
		return false

	var current_sector_id: String = _player_current_sector_id()
	if current_sector_id == "":
		return false

	var pickup_success: bool = _load_runtime_contract_cargo("player", player_agent, selected_occurrence_id, current_sector_id)
	if pickup_success:
		GameState.agents["player"] = player_agent
	return pickup_success


func player_complete_runtime_contract(occurrence_id: String) -> bool:
	var selected_occurrence_id: String = str(occurrence_id)
	if selected_occurrence_id == "":
		return false
	if str(GameState.player_claimed_occurrence_id) != selected_occurrence_id:
		return false
	if not GameState.agents.has("player"):
		return false

	var player_agent: Dictionary = GameState.agents.get("player", {})
	if player_agent.empty():
		return false

	var current_sector_id: String = _player_current_sector_id()
	if current_sector_id == "":
		return false

	var completion_success: bool = _complete_player_contract_delivery(player_agent, selected_occurrence_id, current_sector_id)
	if completion_success:
		GameState.agents["player"] = player_agent
	return completion_success


func _player_current_sector_id() -> String:
	if GameState.agents.has("player"):
		var player_agent: Dictionary = GameState.agents.get("player", {})
		if not player_agent.empty() and str(player_agent.get("current_sector_id", "")) != "":
			return str(player_agent.get("current_sector_id", ""))
	return str(GameState.current_sector_id)


func _best_runtime_contract_occurrence_id(agent_id: String, agent: Dictionary, actor_tags: Array) -> String:
	if agent_id == "player":
		if not _player_can_service_contract(agent):
			return ""
		var player_occurrence_id: String = str(GameState.player_claimed_occurrence_id)
		if player_occurrence_id == "":
			return ""
		if not GameState.runtime_contract_occurrences.has(player_occurrence_id):
			return ""
		return player_occurrence_id

	var role: String = str(agent.get("agent_role", "idle"))
	if not (role in ["trader", "hauler"]):
		return ""
	if actor_tags.empty() or _agent_layer.affinity_matrix == null:
		return ""

	var current_sector_id: String = str(agent.get("current_sector_id", ""))
	var cargo_loaded: bool = agent.get("cargo_tag", "EMPTY") == "LOADED"
	var occurrence_ids: Array = GameState.runtime_contract_occurrences.keys()
	occurrence_ids.sort()
	var best_occurrence_id: String = ""
	var best_score: float = -1000000.0

	for occurrence_id in occurrence_ids:
		var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
		if occurrence.empty():
			continue
		var required_roles: Array = Array(occurrence.get("required_roles", []))
		if not (role in required_roles):
			continue
		var claimant_agent_id: String = str(occurrence.get("claimant_agent_id", ""))
		if claimant_agent_id != "" and claimant_agent_id != agent_id:
			continue
		if cargo_loaded and claimant_agent_id != agent_id:
			continue

		var source_sector_id: String = str(occurrence.get("source_sector_id", ""))
		var target_sector_id: String = str(occurrence.get("target_sector_id", ""))
		var route_goal_sector_id: String = target_sector_id if cargo_loaded else source_sector_id
		var hops_to_goal: int = _agent_layer._sector_hops_between(current_sector_id, route_goal_sector_id)
		if hops_to_goal < 0:
			continue

		var score: float = _agent_layer.affinity_matrix.compute_affinity(actor_tags, Array(occurrence.get("priority_tags", [])))
		if claimant_agent_id == agent_id:
			score += 6.0
		if current_sector_id == route_goal_sector_id:
			score += 1.5
		score -= float(hops_to_goal)

		if score > best_score or (is_equal_approx(score, best_score) and (best_occurrence_id == "" or occurrence_id < best_occurrence_id)):
			best_score = score
			best_occurrence_id = occurrence_id

	return best_occurrence_id


func _action_service_contract(agent_id: String, agent: Dictionary, occurrence_id: String) -> void:
	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	if occurrence.empty():
		if agent_id == "player":
			return
		_agent_layer._action_move_toward_role_target(agent_id, agent)
		return
	if not _claim_runtime_contract_occurrence(agent_id, agent, occurrence_id):
		if agent_id == "player":
			return
		_agent_layer._action_move_toward_role_target(agent_id, agent)
		return

	occurrence = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	var source_sector_id: String = str(occurrence.get("source_sector_id", ""))
	var target_sector_id: String = str(occurrence.get("target_sector_id", ""))
	var current_sector_id: String = str(agent.get("current_sector_id", ""))

	if source_sector_id == "" or target_sector_id == "" or current_sector_id == "":
		_release_runtime_contract_claim(agent_id, occurrence_id)
		if agent_id == "player":
			return
		_agent_layer._action_move_toward_role_target(agent_id, agent)
		return

	if agent.get("cargo_tag", "EMPTY") == "EMPTY":
		if not _is_contract_service_sector_available(source_sector_id):
			return
		if current_sector_id != source_sector_id:
			if agent_id == "player":
				return
			_agent_layer._action_move_toward_sector(agent_id, agent, source_sector_id)
			return
		if _load_runtime_contract_cargo(agent_id, agent, occurrence_id, source_sector_id):
			return
	else:
		if not _is_contract_service_sector_available(target_sector_id):
			return
		if current_sector_id != target_sector_id:
			if agent_id == "player":
				return
			_agent_layer._action_move_toward_sector(agent_id, agent, target_sector_id)
			return
		if agent_id == "player":
			if _complete_player_contract_delivery(agent, occurrence_id, target_sector_id):
				return
		elif _complete_runtime_contract_occurrence(agent_id, agent, occurrence_id, target_sector_id):
			return

	if agent_id == "player":
		return
	_agent_layer._action_move_toward_role_target(agent_id, agent)


func _claim_runtime_contract_occurrence(agent_id: String, agent: Dictionary, occurrence_id: String) -> bool:
	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	if occurrence.empty():
		return false
	if agent_id == "player":
		if not _player_can_service_contract(agent):
			return false
		if str(GameState.player_claimed_occurrence_id) != occurrence_id:
			return false
	else:
		var required_roles: Array = Array(occurrence.get("required_roles", []))
		if not (str(agent.get("agent_role", "idle")) in required_roles):
			return false
	var claimant_agent_id: String = str(occurrence.get("claimant_agent_id", ""))
	if claimant_agent_id != "" and claimant_agent_id != agent_id:
		return false

	if claimant_agent_id == "":
		if agent_id != "player" and not _can_npc_claim_open_runtime_contract(agent_id, occurrence_id, occurrence):
			return false
		if not _reserve_runtime_contract_resources(occurrence):
			return false
		occurrence["claimant_agent_id"] = agent_id
		occurrence["status"] = "claimed"
		occurrence["claimed_at_tick"] = GameState.sim_tick_count
		_agent_layer._log_event(agent_id, "contract_claimed", str(agent.get("current_sector_id", "")), {
			"occurrence_id": occurrence_id,
			"target_sector_id": str(occurrence.get("target_sector_id", "")),
		})
	else:
		occurrence["status"] = str(occurrence.get("status", "claimed"))

	occurrence["last_refreshed_tick"] = GameState.sim_tick_count
	GameState.runtime_contract_occurrences[occurrence_id] = occurrence
	return true


func _can_npc_claim_open_runtime_contract(agent_id: String, occurrence_id: String, occurrence: Dictionary) -> bool:
	var claim_grace_ticks: int = max(0, int(Constants.NPC_RUNTIME_CONTRACT_CLAIM_GRACE_TICKS))
	var created_at_tick: int = int(occurrence.get("created_at_tick", GameState.sim_tick_count))
	if GameState.sim_tick_count - created_at_tick < claim_grace_ticks:
		return false

	var claim_chance: float = clamp(float(Constants.NPC_RUNTIME_CONTRACT_CLAIM_CHANCE), 0.0, 1.0)
	if claim_chance <= 0.0:
		return false
	if claim_chance >= 1.0:
		return true

	var claim_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	claim_rng.seed = hash(str(GameState.world_seed) + ":contract_claim:" + str(GameState.sim_tick_count) + ":" + occurrence_id + ":" + agent_id)
	return claim_rng.randf() < claim_chance


func _release_runtime_contract_claim(agent_id: String, occurrence_id: String) -> void:
	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	if occurrence.empty():
		return
	if str(occurrence.get("claimant_agent_id", "")) != agent_id:
		return
	var category: String = str(occurrence.get("commodity_category", ""))
	var source_sector_id: String = str(occurrence.get("source_accounting_sector_id", occurrence.get("source_sector_id", "")))
	var target_sector_id: String = str(occurrence.get("payment_accounting_sector_id", occurrence.get("target_sector_id", "")))
	if bool(occurrence.get("source_reserved", false)) and not bool(occurrence.get("cargo_picked_up", false)):
		_release_contract_accounting_unit(
			GameState.contract_cargo_supply,
			GameState.contract_cargo_reserved,
			source_sector_id,
			category
		)
	occurrence["source_reserved"] = false
	if bool(occurrence.get("payment_reserved", false)):
		_release_contract_accounting_unit(
			GameState.contract_payment_supply,
			GameState.contract_payment_reserved,
			target_sector_id,
			category
		)
	occurrence["payment_reserved"] = false
	occurrence["claimant_agent_id"] = ""
	occurrence["status"] = "open"
	if occurrence.has("claimed_at_tick"):
		occurrence.erase("claimed_at_tick")
	GameState.runtime_contract_occurrences[occurrence_id] = occurrence
	if agent_id == "player":
		GameState.player_claimed_occurrence_id = ""
		GameState.player_cargo_tag = "EMPTY"


func _clear_runtime_contract_claims_for_agent(agent_id: String, agent: Dictionary) -> void:
	var occurrence_ids: Array = GameState.runtime_contract_occurrences.keys()
	occurrence_ids.sort()
	var cleared_loaded_contract: bool = false

	for occurrence_id in occurrence_ids:
		var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
		if occurrence.empty():
			continue
		if str(occurrence.get("claimant_agent_id", "")) != agent_id:
			continue

		if not bool(occurrence.get("cargo_picked_up", false)):
			var source_sector_id: String = str(occurrence.get("source_sector_id", ""))
			var target_sector_id: String = str(occurrence.get("target_sector_id", ""))
			_release_runtime_contract_claim(agent_id, occurrence_id)
			if not _is_contract_service_sector_available(source_sector_id) or not _is_contract_service_sector_available(target_sector_id):
				_remove_runtime_contract_occurrence(occurrence_id)
			continue

		var category: String = str(occurrence.get("commodity_category", ""))
		var payment_sector_id: String = str(occurrence.get("payment_accounting_sector_id", occurrence.get("target_sector_id", "")))
		if bool(occurrence.get("payment_reserved", false)):
			_release_contract_accounting_unit(
				GameState.contract_payment_supply,
				GameState.contract_payment_reserved,
				payment_sector_id,
				category
			)
		_remove_runtime_contract_occurrence(occurrence_id)
		cleared_loaded_contract = true

	if cleared_loaded_contract:
		agent["cargo_tag"] = "EMPTY"
		if agent.has("contract_cargo_tag"):
			agent.erase("contract_cargo_tag")
		if agent.has("cargo_commodity_id"):
			agent.erase("cargo_commodity_id")
		if agent_id == "player":
			GameState.player_cargo_tag = "EMPTY"

	if agent_id == "player":
		GameState.player_claimed_occurrence_id = ""


func _load_runtime_contract_cargo(agent_id: String, agent: Dictionary, occurrence_id: String, sector_id: String) -> bool:
	if agent.get("cargo_tag", "EMPTY") != "EMPTY":
		return false
	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	if occurrence.empty():
		return false
	if sector_id != str(occurrence.get("source_sector_id", "")):
		return false
	if not _is_contract_service_sector_available(sector_id):
		return false
	if not _reserve_runtime_contract_resources(occurrence):
		return false
	if not _consume_reserved_contract_unit(
		GameState.contract_cargo_reserved,
		sector_id,
		str(occurrence.get("commodity_category", ""))
	):
		return false

	agent["cargo_tag"] = "LOADED"
	agent["cargo_commodity_id"] = occurrence.get("commodity_id", "")
	if agent_id == "player":
		GameState.player_cargo_tag = "LOADED"
		agent["contract_cargo_tag"] = str(occurrence.get("required_cargo_tag", ""))
	if str(agent.get("agent_role", "idle")) == "trader":
		_agent_layer._wealth_step_down(agent)
	occurrence["source_reserved"] = false
	occurrence["cargo_picked_up"] = true
	occurrence["status"] = "in_transit"
	occurrence["last_refreshed_tick"] = GameState.sim_tick_count
	GameState.runtime_contract_occurrences[occurrence_id] = occurrence
	_agent_layer._log_event(agent_id, "contract_loaded", sector_id, {
		"occurrence_id": occurrence_id,
		"target_sector_id": str(occurrence.get("target_sector_id", "")),
	})
	return true


func _complete_runtime_contract_occurrence(agent_id: String, agent: Dictionary, occurrence_id: String, sector_id: String) -> bool:
	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	if occurrence.empty():
		return false
	if agent.get("cargo_tag", "EMPTY") != "LOADED":
		return false
	if sector_id != str(occurrence.get("target_sector_id", "")):
		return false
	if not _is_contract_service_sector_available(sector_id):
		return false
	if not _reserve_runtime_contract_resources(occurrence):
		return false
	if not _consume_reserved_contract_unit(
		GameState.contract_payment_reserved,
		sector_id,
		str(occurrence.get("commodity_category", ""))
	):
		return false

	_agent_layer._try_dock(agent_id, agent, sector_id)
	agent["cargo_tag"] = "EMPTY"
	if agent.has("cargo_commodity_id"):
		agent.erase("cargo_commodity_id")
	occurrence["payment_reserved"] = false
	_apply_contract_completion_sector_impact(occurrence, sector_id)
	_agent_layer._log_event(agent_id, "contract_completed", sector_id, {
		"occurrence_id": occurrence_id,
		"source_sector_id": str(occurrence.get("source_sector_id", "")),
	})
	_remove_runtime_contract_occurrence(occurrence_id)
	return true


func _complete_player_contract_delivery(agent: Dictionary, occurrence_id: String, sector_id: String) -> bool:
	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	if occurrence.empty():
		return false
	if str(GameState.player_claimed_occurrence_id) != occurrence_id:
		return false
	if str(occurrence.get("claimant_agent_id", "")) != "player":
		return false
	if str(occurrence.get("target_sector_id", "")) != sector_id:
		return false
	if str(agent.get("cargo_tag", "EMPTY")) != "LOADED":
		return false
	if str(GameState.player_cargo_tag) != "LOADED":
		return false
	if not _is_contract_service_sector_available(sector_id):
		return false

	var required_cargo_tag: String = str(occurrence.get("required_cargo_tag", ""))
	if required_cargo_tag != "":
		var loaded_cargo_tag: String = str(agent.get("contract_cargo_tag", required_cargo_tag))
		if loaded_cargo_tag != required_cargo_tag:
			return false
	if not _reserve_runtime_contract_resources(occurrence):
		return false
	if not _consume_reserved_contract_unit(
		GameState.contract_payment_reserved,
		sector_id,
		str(occurrence.get("commodity_category", ""))
	):
		return false

	agent["cargo_tag"] = "EMPTY"
	if agent.has("contract_cargo_tag"):
		agent.erase("contract_cargo_tag")
	if agent.has("cargo_commodity_id"):
		agent.erase("cargo_commodity_id")
	GameState.player_cargo_tag = "EMPTY"

	var value_class: String = str(occurrence.get("contract_value_class", "Low"))
	var progress_amount: int = Constants.CONTRACT_VALUE_CLASSES.get(value_class, 1)
	if GlobalRefs.character_system != null and GlobalRefs.character_system.has_method("add_wealth_progress"):
		var player_character_uid = GameState.player_character_uid
		if player_character_uid != "":
			GlobalRefs.character_system.add_wealth_progress(player_character_uid, progress_amount)

	_apply_contract_completion_sector_impact(occurrence, sector_id)

	occurrence["status"] = "completed"
	occurrence["claimant_agent_id"] = ""
	occurrence["payment_reserved"] = false
	if occurrence.has("claimed_at_tick"):
		occurrence.erase("claimed_at_tick")
	occurrence["completed_at_tick"] = GameState.sim_tick_count
	occurrence["last_refreshed_tick"] = GameState.sim_tick_count
	GameState.runtime_contract_occurrences[occurrence_id] = occurrence

	GameState.player_claimed_occurrence_id = ""
	_agent_layer._log_event("player", "contract_completed", sector_id, {
		"occurrence_id": occurrence_id,
		"source_sector_id": str(occurrence.get("source_sector_id", "")),
		"contract_value_class": value_class,
		"progress_amount": progress_amount
	})
	return true


func _reserve_runtime_contract_resources(occurrence: Dictionary) -> bool:
	if occurrence.empty():
		return false
	var category: String = str(occurrence.get("commodity_category", ""))
	var source_sector_id: String = str(occurrence.get("source_sector_id", ""))
	var target_sector_id: String = str(occurrence.get("target_sector_id", ""))
	if category == "" or source_sector_id == "" or target_sector_id == "":
		return false

	var reserved_source_now: bool = false
	if not bool(occurrence.get("cargo_picked_up", false)) and not bool(occurrence.get("source_reserved", false)):
		if not _reserve_contract_accounting_unit(
			GameState.contract_cargo_supply,
			GameState.contract_cargo_reserved,
			source_sector_id,
			category
		):
			return false
		occurrence["source_reserved"] = true
		reserved_source_now = true

	if not bool(occurrence.get("payment_reserved", false)):
		if not _reserve_contract_accounting_unit(
			GameState.contract_payment_supply,
			GameState.contract_payment_reserved,
			target_sector_id,
			category
		):
			if reserved_source_now:
				_release_contract_accounting_unit(
					GameState.contract_cargo_supply,
					GameState.contract_cargo_reserved,
					source_sector_id,
					category
				)
				occurrence["source_reserved"] = false
			return false
		occurrence["payment_reserved"] = true

	return true


func _reserve_contract_accounting_unit(supply_root: Dictionary, reserved_root: Dictionary, sector_id: String, category: String) -> bool:
	if sector_id == "" or category == "":
		return false
	var supply_by_sector: Dictionary = supply_root.get(sector_id, {})
	var reserved_by_sector: Dictionary = reserved_root.get(sector_id, {})
	var available_units: int = int(supply_by_sector.get(category, 0))
	if available_units <= 0:
		return false
	supply_by_sector[category] = available_units - 1
	reserved_by_sector[category] = int(reserved_by_sector.get(category, 0)) + 1
	supply_root[sector_id] = supply_by_sector
	reserved_root[sector_id] = reserved_by_sector
	return true


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


func _consume_reserved_contract_unit(reserved_root: Dictionary, sector_id: String, category: String) -> bool:
	if sector_id == "" or category == "":
		return false
	var reserved_by_sector: Dictionary = reserved_root.get(sector_id, {})
	var reserved_units: int = int(reserved_by_sector.get(category, 0))
	if reserved_units <= 0:
		return false
	reserved_by_sector[category] = reserved_units - 1
	reserved_root[sector_id] = reserved_by_sector
	return true


func _apply_contract_completion_sector_impact(occurrence: Dictionary, target_sector_id: String) -> void:
	if target_sector_id == "":
		return
	if not GameState.contract_generation_pressure.has(target_sector_id):
		return

	var category: String = str(occurrence.get("commodity_category", ""))
	if not (category in _agent_layer._CONTRACT_CATEGORIES):
		return

	var sector_pressure: Dictionary = GameState.contract_generation_pressure.get(target_sector_id, {})
	var previous_pressure: int = int(sector_pressure.get(category, 0))
	var completion_relief_decay: int = max(1, int(Constants.CONTRACT_RELIEF_DECAY_PER_TICK) + 1)
	sector_pressure[category] = max(0, previous_pressure - completion_relief_decay)
	GameState.contract_generation_pressure[target_sector_id] = sector_pressure

	_refresh_contract_demand_tags_for_sector(target_sector_id)


func _refresh_contract_demand_tags_for_sector(sector_id: String) -> void:
	if sector_id == "":
		return
	if not GameState.sector_tags.has(sector_id):
		return

	var tags: Array = Array(GameState.sector_tags.get(sector_id, []))
	var serviceable: bool = true
	var sector_disabled: bool = _agent_layer._sector_recently_disabled(sector_id)
	var sector_pressure: Dictionary = GameState.contract_generation_pressure.get(sector_id, {})
	var sector_thresholds: Dictionary = GameState.contract_generation_threshold.get(sector_id, {})
	var demand_count: int = 0

	for category in _agent_layer._CONTRACT_CATEGORIES:
		var demand_tag: String = _contract_demand_tag(category)
		var poor_tag: String = "%s_POOR" % category
		var threshold: int = int(sector_thresholds.get(category, Constants.CONTRACT_PRESSURE_TICKS_MIN))
		var pressure: int = int(sector_pressure.get(category, 0))
		var can_generate: bool = serviceable and (poor_tag in tags) and not sector_disabled

		if can_generate and pressure >= threshold:
			tags = _agent_layer._add_tag(tags, demand_tag)
		else:
			tags = _agent_layer._remove_tag(tags, demand_tag)

		if demand_tag in tags:
			demand_count += 1

	tags = _agent_layer._remove_tag(tags, "TRADE_LANE_ACTIVE")

	var needs_relief: bool = demand_count >= 2
	if demand_count > 0 and (_agent_layer._security_tag(tags) != "SECURE" or GameState.world_age == "DISRUPTION"):
		needs_relief = true

	if needs_relief:
		tags = _agent_layer._add_tag(tags, "RELIEF_NEEDED")
	else:
		tags = _agent_layer._remove_tag(tags, "RELIEF_NEEDED")

	GameState.sector_tags[sector_id] = tags


func _contract_demand_tag(category: String) -> String:
	return "CONTRACT_DEMAND_%s" % category


func _player_can_service_contract(agent: Dictionary) -> bool:
	if str(GameState.player_claimed_occurrence_id) == "":
		return false
	if str(agent.get("agent_role", "idle")) != "idle":
		return false
	return true


func _remove_runtime_contract_occurrence(occurrence_id: String) -> void:
	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	if occurrence.empty():
		return
	var target_sector_id: String = str(occurrence.get("target_sector_id", ""))
	var source_sector_id: String = str(occurrence.get("source_sector_id", ""))
	GameState.runtime_contract_occurrences.erase(occurrence_id)
	_remove_runtime_contract_index_entry(GameState.runtime_contract_occurrences_by_target_sector, target_sector_id, occurrence_id)
	_remove_runtime_contract_index_entry(GameState.runtime_contract_occurrences_by_source_sector, source_sector_id, occurrence_id)


func _remove_runtime_contract_index_entry(index: Dictionary, sector_id: String, occurrence_id: String) -> void:
	if not index.has(sector_id):
		return
	var updated_ids: Array = []
	for existing_id in Array(index.get(sector_id, [])):
		if existing_id != occurrence_id:
			updated_ids.append(existing_id)
	if updated_ids.empty():
		index.erase(sector_id)
	else:
		index[sector_id] = updated_ids


func _is_contract_service_sector_available(sector_id: String) -> bool:
	if sector_id == "":
		return false
	var sector_tags: Array = Array(GameState.sector_tags.get(sector_id, []))
	if "DISABLED" in sector_tags:
		return false
	return not _agent_layer._sector_recently_disabled(sector_id)