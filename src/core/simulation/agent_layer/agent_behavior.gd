# PROJECT: GDTLancer
# MODULE: agent_behavior.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: GDD-REVISION-LEDGER.md REV_007; GDD-REVISION-LEDGER.md REV_008; TRUTH_SIMULATION-GRAPH.md §2.2.1; TRUTH_PROJECT.md § Agent Parity Principle
# LOG_REF: 2026-06-20 20:31:00

extends Reference

var _agent_layer: Reference

func initialize(agent_layer_ref: Reference) -> void:
	_agent_layer = agent_layer_ref

func _evaluate_goals(agent: Dictionary, agent_id: String = "") -> void:
	# Player contract interactions are user-driven through the contract board, not auto-serviced here.
	if agent_id == "player":
		agent["goal_archetype"] = "idle"
		agent["goal_queue"] = [{"type": "idle"}]
		return
	if _consume_mandatory_npc_rest_tick(agent_id, agent):
		agent["goal_archetype"] = "idle"
		agent["goal_queue"] = [{"type": "idle"}]
		return

	var tags: Array = agent.get("sentiment_tags", [])
	if "DESPERATE" in tags:
		agent["goal_archetype"] = "flee_to_safety"
		agent["goal_queue"] = [{"type": "flee_to_safety"}]
		return
	var runtime_contract_id: String = _agent_layer._best_runtime_contract_occurrence_id(agent_id, agent, tags)
	if runtime_contract_id != "":
		agent["goal_archetype"] = "service_contract"
		agent["goal_queue"] = [{"type": "service_contract", "occurrence_id": runtime_contract_id}]
		return
	agent["goal_archetype"] = "affinity_scan"
	agent["goal_queue"] = [{"type": "affinity_scan"}]


func _execute_action(agent_id: String, agent: Dictionary) -> void:
	var goal_queue: Array = agent.get("goal_queue", [{"type": "idle"}])
	var goal: String = goal_queue[0].get("type", "idle") if not goal_queue.empty() else "idle"

	if goal == "flee_to_safety":
		_action_flee_to_safety(agent_id, agent)
		_schedule_npc_rest_after_action(agent_id, agent, goal)
		return
	if goal == "service_contract":
		_agent_layer._action_service_contract(agent_id, agent, str(goal_queue[0].get("occurrence_id", "")))
		_schedule_npc_rest_after_action(agent_id, agent, goal)
		return
	if goal == "affinity_scan":
		_action_affinity_scan(agent_id, agent)
		_schedule_npc_rest_after_action(agent_id, agent, goal)


func _consume_mandatory_npc_rest_tick(agent_id: String, agent: Dictionary) -> bool:
	if agent_id == "player":
		return false
	if _should_skip_mandatory_npc_rest(agent_id, agent):
		agent["rest_ticks_remaining"] = 0
		return false
	var remaining_rest_ticks: int = max(0, int(agent.get("rest_ticks_remaining", 0)))
	if remaining_rest_ticks <= 0:
		return false
	agent["rest_ticks_remaining"] = remaining_rest_ticks - 1
	return true


func _schedule_npc_rest_after_action(agent_id: String, agent: Dictionary, goal: String) -> void:
	if agent_id == "player" or goal == "idle":
		return
	if agent.get("is_disabled", false):
		return
	if _should_skip_mandatory_npc_rest(agent_id, agent):
		agent["rest_ticks_remaining"] = 0
		return
	agent["rest_ticks_remaining"] = _mandatory_rest_ticks_for_agent(agent)


func _should_skip_mandatory_npc_rest(agent_id: String, agent: Dictionary) -> bool:
	if str(agent.get("cargo_tag", "EMPTY")) == "LOADED":
		return true
	return _has_active_runtime_contract_claim(agent_id)


func _has_active_runtime_contract_claim(agent_id: String) -> bool:
	for occurrence_id in GameState.runtime_contract_occurrences.keys():
		var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
		if occurrence.empty():
			continue
		if str(occurrence.get("claimant_agent_id", "")) != agent_id:
			continue
		if str(occurrence.get("status", "")) == "completed":
			continue
		return true
	return false


func _mandatory_rest_ticks_for_agent(agent: Dictionary) -> int:
	var condition_tag: String = str(agent.get("condition_tag", "HEALTHY"))
	var wealth_tag: String = str(agent.get("wealth_tag", "COMFORTABLE"))
	if condition_tag == "HEALTHY" and wealth_tag == "WEALTHY":
		return 3
	if condition_tag == "HEALTHY" and wealth_tag == "COMFORTABLE":
		return 2
	return 1


func _action_flee_to_safety(agent_id: String, agent: Dictionary) -> void:
	var current: String = agent.get("current_sector_id", "")
	var options: Array = [current]
	var connections: Array = GameState.world_topology.get(current, {}).get("connections", [])
	for conn in connections:
		options.append(conn)

	var best: String = current
	for sector_id in options:
		var tags: Array = GameState.sector_tags.get(sector_id, [])
		if "SECURE" in tags:
			best = sector_id
			break

	if best != current:
		_agent_layer._action_move_toward(agent_id, agent, best)


func _action_affinity_scan(agent_id: String, agent: Dictionary) -> void:
	if _agent_layer.affinity_matrix == null:
		return

	var actor_tags: Array = agent.get("sentiment_tags", [])
	if actor_tags.empty():
		return

	var current_sector: String = agent.get("current_sector_id", "")
	var can_attack: bool = not _is_combat_cooldown_active(agent)

	var best_result: Array = _best_agent_target(agent_id, actor_tags, current_sector, can_attack)
	var best_agent_id = best_result[0]
	var best_agent_score: float = best_result[1]

	if best_agent_id != null:
		var handled: bool = _resolve_agent_interaction(agent_id, best_agent_id, best_agent_score)
		if handled:
			return

	var sector_tags: Array = GameState.sector_tags.get(current_sector, [])
	var sector_score: float = _agent_layer.affinity_matrix.compute_affinity(actor_tags, sector_tags)
	_resolve_sector_interaction(agent_id, sector_score, sector_tags)


func _resolve_agent_interaction(actor_id: String, target_id: String, score: float) -> bool:
	var actor: Dictionary = GameState.agents.get(actor_id, {})
	var target: Dictionary = GameState.agents.get(target_id, {})
	if actor.empty() or target.empty():
		return false

	var current_sector: String = actor.get("current_sector_id", "")
	var actor_tags: Array = Array(actor.get("sentiment_tags", []))
	var target_tags: Array = Array(target.get("sentiment_tags", []))

	if score >= Constants.ATTACK_THRESHOLD:
		if not _can_agents_escalate_to_disruption(actor, target, actor_tags, target_tags):
			return false
		var cargo_seized: bool = _apply_non_lethal_disruption(actor_id, actor, target_id, target, actor_tags, target_tags)
		actor["last_attack_tick"] = GameState.sim_tick_count
		_agent_layer._log_event(actor_id, "attack", current_sector, {
			"target": target_id,
			"outcome": "non_lethal_disruption",
			"cargo_seized": cargo_seized,
		})
		_agent_layer._post_combat_dispersal(actor_id, actor)
		return true

	if score >= Constants.TRADE_THRESHOLD:
		if not _can_agents_trade(actor, target, actor_tags, target_tags):
			return false
		_bilateral_trade(actor, target)
		_sync_player_cargo_mirror(actor_id, actor)
		_sync_player_cargo_mirror(target_id, target)
		_agent_layer._log_event(actor_id, "agent_trade", current_sector, {"target": target_id})
		return true

	if score <= Constants.FLEE_THRESHOLD:
		_agent_layer._action_move_random(actor_id, actor)
		_agent_layer._log_event(actor_id, "flee", current_sector, {"target": target_id})
		return true

	return false


func _resolve_sector_interaction(agent_id: String, score: float, sector_tags: Array) -> void:
	var agent: Dictionary = GameState.agents.get(agent_id, {})
	var sector_id: String = agent.get("current_sector_id", "")
	var explorer_waiting: bool = false
	var at_station: bool = true

	# Explorers prioritise exploration
	if agent.get("agent_role") == "explorer":
		if _agent_layer._should_attempt_exploration(agent, sector_id, sector_tags):
			_agent_layer._try_exploration(agent_id, agent, sector_id)
			if _agent_layer._last_exploration_outcome == "discovered":
				return
		else:
			explorer_waiting = true

	if score >= Constants.ATTACK_THRESHOLD and "HAS_SALVAGE" in sector_tags:
		_action_harvest(agent_id, agent, sector_id)
		return

	var needs_dock: bool = (
		agent.get("condition_tag") == "DAMAGED"
		or agent.get("cargo_tag") == "LOADED"
	)

	if needs_dock and at_station:
		_try_dock(agent_id, agent, sector_id)
		return

	if agent.get("cargo_tag") == "EMPTY":
		var loaded: bool = _try_load_cargo(agent_id, agent, sector_id)
		if loaded:
			return

	if score <= Constants.FLEE_THRESHOLD:
		_agent_layer._action_move_random(agent_id, agent)
		_agent_layer._log_event(agent_id, "flee", sector_id, {"reason": "sector_affinity"})
		return

	if explorer_waiting:
		_agent_layer._handle_explorer_non_exploration_turn(agent_id, agent, sector_id, sector_tags, at_station)
		return

	_agent_layer._action_move_toward_role_target(agent_id, agent)


func _try_dock(agent_id: String, agent: Dictionary, sector_id: String) -> void:
	var sold_cargo: bool = false
	if agent.get("cargo_tag") == "LOADED":
		if not _has_protected_contract_cargo(agent, agent.get("sentiment_tags", [])):
			if _agent_layer._attempt_npc_market_sell(agent_id, agent, sector_id):
				sold_cargo = true
			else:
				# Fallback to qualitative cargo sell
				agent["cargo_tag"] = "EMPTY"
				_agent_layer._wealth_step_up(agent)
				sold_cargo = true

	# Attempt buy if we did not just sell cargo in this dock action
	if not sold_cargo and agent.get("cargo_tag") == "EMPTY" and agent.get("wealth_tag") != "BROKE":
		var role: String = agent.get("agent_role", "idle")
		if role in ["trader", "hauler", "prospector"]:
			_agent_layer._attempt_npc_market_buy(agent_id, agent, sector_id)

	if agent.get("condition_tag") == "DAMAGED":
		agent["condition_tag"] = "HEALTHY"
		if not sold_cargo:
			_agent_layer._wealth_step_down(agent)

	var location_id := sector_id
	if not GameState.locations.has(location_id) and GameState.locations.has("station_" + sector_id):
		location_id = "station_" + sector_id
	if _location_offers_service(location_id, "trade"):
		agent["supplies_tag"] = "SUPPLIES_ADEQUATE"
		agent["supplies_ticks_remaining"] = Constants.SUPPLIES_DEGRADATION_TICKS

	_agent_layer._log_event(agent_id, "dock", sector_id, {})


func _action_harvest(agent_id: String, agent: Dictionary, sector_id: String) -> void:
	var tags: Array = GameState.sector_tags.get(sector_id, [])
	if not ("HAS_SALVAGE" in tags):
		return
	agent["cargo_tag"] = "LOADED"
	var new_tags: Array = []
	for tag in tags:
		if tag != "HAS_SALVAGE":
			new_tags.append(tag)
	GameState.sector_tags[sector_id] = new_tags
	_agent_layer._log_event(agent_id, "harvest", sector_id, {})


func _try_load_cargo(agent_id: String, agent: Dictionary, sector_id: String) -> bool:
	if agent.get("cargo_tag") != "EMPTY":
		return false

	var sector_tags: Array = GameState.sector_tags.get(sector_id, [])
	var role: String = agent.get("agent_role", "idle")

	# Attempt quantitative market buy if at station/frontier with market service
	if role in ["trader", "hauler", "prospector"]:
		if _agent_layer._attempt_npc_market_buy(agent_id, agent, sector_id):
			return true

	var can_load: bool = false

	if role in ["hauler", "prospector"]:
		can_load = "RAW_RICH" in sector_tags or "MANUFACTURED_RICH" in sector_tags
	elif role == "trader":
		can_load = agent.get("wealth_tag") != "BROKE"
	elif role == "pirate":
		can_load = "HAS_SALVAGE" in sector_tags

	if can_load:
		agent["cargo_tag"] = "LOADED"
		if role == "trader":
			_agent_layer._wealth_step_down(agent)
		if role == "pirate" and "HAS_SALVAGE" in sector_tags:
			var new_tags: Array = []
			for t in GameState.sector_tags.get(sector_id, []):
				if t != "HAS_SALVAGE":
					new_tags.append(t)
			GameState.sector_tags[sector_id] = new_tags
		_agent_layer._log_event(agent_id, "load_cargo", sector_id, {})
		return true
	return false


func _location_offers_service(location_id: String, service_id: String) -> bool:
	if location_id == "" or not GameState.locations.has(location_id):
		return true

	var location_record = GameState.locations[location_id]
	var available_services = null
	if location_record is Dictionary:
		available_services = location_record.get("available_services", null)
	elif location_record is Object and "available_services" in location_record:
		available_services = location_record.available_services

	return not (available_services is Array) or service_id in available_services


func _best_agent_target(actor_id: String, actor_tags: Array, sector_id: String, can_attack: bool) -> Array:
	var best_id = null
	var best_score: float = 0.0

	for target_id in GameState.agents:
		if target_id == actor_id:
			continue
		var target: Dictionary = GameState.agents[target_id]
		if target.get("is_disabled", false):
			continue
		if target.get("current_sector_id", "") != sector_id:
			continue

		var target_tags: Array = target.get("sentiment_tags", [])
		var score: float = _agent_layer.affinity_matrix.compute_affinity(actor_tags, target_tags)

		if not can_attack and score >= Constants.ATTACK_THRESHOLD:
			continue
		if abs(score) > abs(best_score):
			best_score = score
			best_id = target_id

	return [best_id, best_score]


func _is_combat_cooldown_active(agent: Dictionary) -> bool:
	var last_attack_tick = agent.get("last_attack_tick", null)
	if last_attack_tick == null:
		return false
	return (GameState.sim_tick_count - int(last_attack_tick)) < Constants.COMBAT_COOLDOWN_TICKS


func _bilateral_trade(actor: Dictionary, target: Dictionary) -> void:
	var actor_loaded: bool = str(actor.get("cargo_tag", "EMPTY")) == "LOADED"
	var target_loaded: bool = str(target.get("cargo_tag", "EMPTY")) == "LOADED"

	var payer: Dictionary = target if actor_loaded else actor
	var payee: Dictionary = actor if actor_loaded else target
	var payer_tags: Array = Array(payer.get("sentiment_tags", []))
	var payee_tags: Array = Array(payee.get("sentiment_tags", []))
	var instrument: String = _resolve_payment_instrument(payer_tags, payee_tags)

	var cargo_transferred := false
	if actor_loaded and not target_loaded:
		cargo_transferred = _transfer_cargo_between_agents(actor, target)
	elif target_loaded and not actor_loaded:
		cargo_transferred = _transfer_cargo_between_agents(target, actor)

	if cargo_transferred and instrument == "specie":
		var payer_uid = _get_character_uid(payer)
		var payee_uid = _get_character_uid(payee)
		var inv_sys = GlobalRefs.inventory_system
		if is_instance_valid(inv_sys):
			if payer_uid != -1:
				inv_sys.remove_asset(payer_uid, 2, "commodity_specie", 1)
			if payee_uid != -1:
				inv_sys.add_asset(payee_uid, 2, "commodity_specie", 1)


func _can_agents_escalate_to_disruption(actor: Dictionary, target: Dictionary, actor_tags: Array, target_tags: Array) -> bool:
	if _share_aligned_faction(actor_tags, target_tags):
		return false

	var actor_legality_tag: String = _agent_legality_tag(actor_tags)
	var target_legality_tag: String = _agent_legality_tag(target_tags)

	if "MILITARY" in actor_tags and target_legality_tag == "LEGAL_ILLICIT":
		return true
	if "PIRATE" in actor_tags and target_legality_tag != "LEGAL_ILLICIT":
		return true
	if actor_legality_tag == "LEGAL_LAWFUL" and target_legality_tag == "LEGAL_ILLICIT":
		return true
	if actor_legality_tag == "LEGAL_ILLICIT" and target_legality_tag == "LEGAL_LAWFUL":
		return true

	return false


func _apply_non_lethal_disruption(
		actor_id: String,
		actor: Dictionary,
		target_id: String,
		target: Dictionary,
		actor_tags: Array,
		target_tags: Array
	) -> bool:
	var cargo_seized: bool = false
	target["condition_tag"] = "DAMAGED"
	_agent_layer._wealth_step_down(target)
	target["rest_ticks_remaining"] = max(int(target.get("rest_ticks_remaining", 0)), 1)
	if target_id != "player":
		target["goal_archetype"] = "flee_to_safety"
		target["goal_queue"] = [{"type": "flee_to_safety"}]

	if _can_actor_seize_cargo(actor, target, actor_tags, target_tags):
		cargo_seized = _transfer_cargo_between_agents(target, actor)

	_sync_player_cargo_mirror(actor_id, actor)
	_sync_player_cargo_mirror(target_id, target)
	return cargo_seized


func _can_actor_seize_cargo(actor: Dictionary, target: Dictionary, actor_tags: Array, target_tags: Array) -> bool:
	if not ("PIRATE" in actor_tags):
		return false
	if "PIRATE" in target_tags:
		return false
	if _share_aligned_faction(actor_tags, target_tags):
		return false
	if _has_protected_contract_cargo(target, target_tags):
		return false
	return str(actor.get("cargo_tag", "EMPTY")) == "EMPTY" and str(target.get("cargo_tag", "EMPTY")) == "LOADED"


func _can_agents_trade(actor: Dictionary, target: Dictionary, actor_tags: Array, target_tags: Array) -> bool:
	var actor_loaded: bool = str(actor.get("cargo_tag", "EMPTY")) == "LOADED"
	var target_loaded: bool = str(target.get("cargo_tag", "EMPTY")) == "LOADED"
	if actor_loaded == target_loaded:
		return false
	if _has_protected_contract_cargo(actor, actor_tags) or _has_protected_contract_cargo(target, target_tags):
		return false

	var actor_role: String = str(actor.get("agent_role", "idle"))
	var target_role: String = str(target.get("agent_role", "idle"))
	if not (_is_commerce_role(actor_role) or _is_commerce_role(target_role)):
		return false
	if actor_role == "military" or target_role == "military":
		return false

	var actor_legality_tag: String = _agent_legality_tag(actor_tags)
	var target_legality_tag: String = _agent_legality_tag(target_tags)
	if _trade_legality_blocks_exchange(actor_legality_tag, target_legality_tag):
		return false
	if ("PIRATE" in actor_tags or "PIRATE" in target_tags) and not (
		actor_legality_tag == "LEGAL_ILLICIT" and target_legality_tag == "LEGAL_ILLICIT"
	):
		return false

	# Dual-economy trust-gated payment instrument routing
	var payer = target if actor_loaded else actor
	var payee = actor if actor_loaded else target
	var payer_tags = Array(payer.get("sentiment_tags", []))
	var payee_tags = Array(payee.get("sentiment_tags", []))
	var instrument = _resolve_payment_instrument(payer_tags, payee_tags)
	if instrument == "specie":
		var payer_uid = _get_character_uid(payer)
		if payer_uid != -1:
			var inv_sys = GlobalRefs.inventory_system
			if is_instance_valid(inv_sys):
				if inv_sys.get_asset_count(payer_uid, 2, "commodity_specie") < 1:
					return false

	return true


func _is_commerce_role(role: String) -> bool:
	return role in ["trader", "hauler", "prospector"]


func _trade_legality_blocks_exchange(actor_legality_tag: String, target_legality_tag: String) -> bool:
	if actor_legality_tag == "LEGAL_LAWFUL" and target_legality_tag == "LEGAL_ILLICIT":
		return true
	if actor_legality_tag == "LEGAL_ILLICIT" and target_legality_tag == "LEGAL_LAWFUL":
		return true
	if actor_legality_tag == "LEGAL_TOLERATED" and target_legality_tag == "LEGAL_ILLICIT":
		return true
	if actor_legality_tag == "LEGAL_ILLICIT" and target_legality_tag == "LEGAL_TOLERATED":
		return true
	return false


func _has_protected_contract_cargo(agent: Dictionary, tags: Array) -> bool:
	if str(agent.get("cargo_tag", "EMPTY")) != "LOADED":
		return false
	if str(agent.get("contract_cargo_tag", "")) != "":
		return true
	return ("CARGO_PROTECTED" in tags) or ("CARGO_CONTRACT" in tags)


func _share_aligned_faction(actor_tags: Array, target_tags: Array) -> bool:
	var actor_faction_tag: String = _tag_with_prefix(actor_tags, "FACTION_")
	var target_faction_tag: String = _tag_with_prefix(target_tags, "FACTION_")
	if actor_faction_tag == "" or target_faction_tag == "":
		return false
	if actor_faction_tag == "FACTION_UNALIGNED" or target_faction_tag == "FACTION_UNALIGNED":
		return false
	return actor_faction_tag == target_faction_tag


func _get_character_uid(agent: Dictionary) -> int:
	if agent.has("character_uid") and agent["character_uid"] != null:
		return int(agent["character_uid"])
	for agent_id in GameState.agents:
		if GameState.agents[agent_id] == agent:
			if GameState.persistent_agents.has(agent_id):
				var p_agent = GameState.persistent_agents[agent_id]
				if p_agent != null and p_agent.has("character_uid") and p_agent["character_uid"] != null:
					return int(p_agent["character_uid"])
			if agent_id == "player" and "player_character_uid" in GameState and GameState.player_character_uid != null:
				return int(GameState.player_character_uid)
			break
	return -1


func _resolve_payment_instrument(payer_tags: Array, payee_tags: Array) -> String:
	return "credits"


func _agent_legality_tag(tags: Array) -> String:
	var explicit_tag: String = _tag_with_prefix(tags, "LEGAL_")
	if explicit_tag != "":
		return explicit_tag
	if "PIRATE" in tags:
		return "LEGAL_ILLICIT"
	if "TRADER" in tags or "HAULER" in tags or "MILITARY" in tags:
		return "LEGAL_LAWFUL"
	return "LEGAL_TOLERATED"


func _tag_with_prefix(tags: Array, prefix: String) -> String:
	for tag in tags:
		var label: String = str(tag)
		if label.begins_with(prefix):
			return label
	return ""


func _transfer_cargo_between_agents(source: Dictionary, destination: Dictionary) -> bool:
	if str(source.get("cargo_tag", "EMPTY")) != "LOADED":
		return false
	if str(destination.get("cargo_tag", "EMPTY")) != "EMPTY":
		return false

	destination["cargo_tag"] = "LOADED"
	source["cargo_tag"] = "EMPTY"

	if source.has("contract_cargo_tag"):
		destination["contract_cargo_tag"] = source.get("contract_cargo_tag", "")
	elif destination.has("contract_cargo_tag"):
		destination.erase("contract_cargo_tag")

	if source.has("cargo_provenance_tag"):
		destination["cargo_provenance_tag"] = source.get("cargo_provenance_tag", "")
	elif destination.has("cargo_provenance_tag"):
		destination.erase("cargo_provenance_tag")

	if source.has("cargo_legality_tag"):
		destination["cargo_legality_tag"] = source.get("cargo_legality_tag", "")
	elif destination.has("cargo_legality_tag"):
		destination.erase("cargo_legality_tag")

	if source.has("contract_cargo_tag"):
		source.erase("contract_cargo_tag")
	if source.has("cargo_provenance_tag"):
		source.erase("cargo_provenance_tag")
	if source.has("cargo_legality_tag"):
		source.erase("cargo_legality_tag")

	return true


func _sync_player_cargo_mirror(agent_id: String, agent: Dictionary) -> void:
	if agent_id == "player":
		GameState.player_cargo_tag = str(agent.get("cargo_tag", "EMPTY"))
