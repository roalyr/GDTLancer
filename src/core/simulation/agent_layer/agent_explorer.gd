# PROJECT: GDTLancer
# MODULE: agent_explorer.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: GDD-REVISION-LEDGER.md REV_007; GDD-REVISION-LEDGER.md REV_008; TRUTH_SIMULATION-GRAPH.md §2.2.1; TRUTH_PROJECT.md § Agent Parity Principle
# LOG_REF: 2026-06-12 23:12:22

extends Reference

const LocationTemplateScript = preload("res://database/definitions/location_template.gd")

var _agent_layer: Reference

func initialize(agent_layer_ref: Reference) -> void:
	_agent_layer = agent_layer_ref

func _try_exploration(agent_id: String, agent: Dictionary, sector_id: String) -> void:
	_agent_layer._last_exploration_outcome = "blocked"

	# Cap check
	if GameState.world_topology.size() >= Constants.MAX_SECTOR_COUNT:
		_agent_layer._last_exploration_outcome = "cap"
		_agent_layer._log_event(agent_id, "expedition_failed", sector_id, {})
		return

	if agent.get("wealth_tag") == "BROKE":
		_agent_layer._last_exploration_outcome = "broke"
		_agent_layer._log_event(agent_id, "expedition_failed", sector_id, {"reason": "broke"})
		return

	# Per-agent cooldown
	var last_discovery: int = int(agent.get("last_discovery_tick", -999))
	if GameState.sim_tick_count - last_discovery < Constants.EXPLORATION_COOLDOWN_TICKS:
		_agent_layer._last_exploration_outcome = "cooldown"
		_agent_layer._log_event(agent_id, "expedition_failed", sector_id, {"reason": "cooldown"})
		return

	# Probability gate — diminishing returns
	var sector_count: int = GameState.world_topology.size()
	var saturation: float = float(sector_count) / float(Constants.MAX_SECTOR_COUNT)
	var sector_tags: Array = GameState.sector_tags.get(sector_id, [])
	var sector_modifier: float = _get_exploration_success_modifier(sector_id, sector_tags)
	var effective_chance: float = Constants.EXPLORATION_SUCCESS_CHANCE * (1.0 - saturation) * sector_modifier
	if _agent_layer._rng.randf() > effective_chance:
		_agent_layer._last_exploration_outcome = "nothing_found"
		_agent_layer._log_event(agent_id, "expedition_failed", sector_id, {"reason": "nothing_found"})
		return

	agent["last_discovery_tick"] = GameState.sim_tick_count
	var next_discovery_count: int = GameState.discovered_sector_count + 1
	var new_id: String = "discovered_" + str(next_discovery_count)

	# Determine connections (filament topology)
	var source_id: String = sector_id
	if _agent_layer._graph_degree(source_id) >= Constants.MAX_CONNECTIONS_PER_SECTOR:
		var fallback_candidates: Array = []
		var source_connections: Array = GameState.world_topology.get(source_id, {}).get("connections", [])
		for neighbor_id in source_connections:
			if _agent_layer._graph_degree(neighbor_id) < Constants.MAX_CONNECTIONS_PER_SECTOR:
				fallback_candidates.append(neighbor_id)

		if fallback_candidates.empty():
			_agent_layer._last_exploration_outcome = "region_saturated"
			_agent_layer._log_event(agent_id, "expedition_failed", sector_id, {"reason": "region_saturated"})
			return

		# Sort by degree (ascending), then by name for determinism
		fallback_candidates.sort_custom(_agent_layer, "_sort_by_degree")
		source_id = fallback_candidates[0]

	var source_tags: Array = Array(GameState.sector_tags.get(source_id, sector_tags))
	var connection_chances: Dictionary = _get_discovery_connection_chances(source_id, source_tags)
	var connections: Array = [source_id]

	var extra_one_added: bool = false
	if _agent_layer._rng.randf() < float(connection_chances.get("extra_one", Constants.EXTRA_CONNECTION_1_CHANCE)):
		var nearby: Array = _nearby_candidates(source_id, connections)
		if not nearby.empty():
			nearby.sort()
			var extra_one: String = nearby[_agent_layer._rng.randi() % nearby.size()]
			if not (extra_one in connections):
				connections.append(extra_one)
				extra_one_added = true

	if extra_one_added and _agent_layer._rng.randf() < float(connection_chances.get("extra_two", Constants.EXTRA_CONNECTION_2_CHANCE)):
		var loop_candidate = _distant_loop_candidate(source_id, connections)
		if loop_candidate != null and not (loop_candidate in connections):
			connections.append(loop_candidate)

	var profile: Dictionary = _select_discovered_sector_profile(new_id)
	var placement: Dictionary = _build_discovered_sector_placement(new_id, source_id, profile)
	if not bool(placement.get("is_valid", true)):
		_agent_layer._last_exploration_outcome = "spatially_blocked"
		_agent_layer._log_event(agent_id, "expedition_failed", sector_id, {"reason": "spatially_blocked"})
		return
	var global_position: Vector3 = placement.get("global_position", Vector3.ZERO)
	connections = _filter_spatially_plausible_connections(source_id, connections, global_position)

	# Pick initial tags (frontier bias: harsh, poor, contested)
	var sec_roll: float = _agent_layer._rng.randf()
	var security: String = "LAWLESS" if sec_roll < 0.45 else ("CONTESTED" if sec_roll < 0.85 else "SECURE")
	var env_roll: float = _agent_layer._rng.randf()
	var environment: String = "EXTREME" if env_roll < 0.3 else ("HARSH" if env_roll < 0.75 else "MILD")

	var econ_tags: Array = []
	var econ_options: Array = ["POOR", "POOR", "ADEQUATE", "ADEQUATE", "RICH"]
	for prefix in ["RAW", "MANUFACTURED", "CURRENCY"]:
		var level: String = econ_options[_agent_layer._rng.randi() % econ_options.size()]
		econ_tags.append(prefix + "_" + level)

	var initial_tags: Array = ["FRONTIER", security, environment] + econ_tags
	var new_name: String = _generate_sector_name_for_discovery(next_discovery_count, profile, initial_tags)

	# Wire into the world graph (bidirectional)
	GameState.world_topology[new_id] = {
		"connections": Array(connections),
		"station_ids": [new_id],
		"sector_type": str(profile.get("sector_type", "deep_space")),
	}
	for conn_id in connections:
		var conn_data: Dictionary = GameState.world_topology.get(conn_id, {})
		var existing_conns: Array = conn_data.get("connections", [])
		if not (new_id in existing_conns):
			existing_conns.append(new_id)

	# Initialize all required state dicts
	GameState.sector_tags[new_id] = Array(initial_tags)
	GameState.world_hazards[new_id] = {"environment": environment}
	GameState.colony_levels[new_id] = "frontier"
	GameState.colony_upgrade_progress[new_id] = 0
	GameState.colony_downgrade_progress[new_id] = 0
	GameState.security_upgrade_progress[new_id] = 0
	GameState.security_downgrade_progress[new_id] = 0

	var thresh_rng := RandomNumberGenerator.new()
	thresh_rng.seed = hash(str(GameState.world_seed) + ":sec_thresh:" + new_id)
	GameState.security_change_threshold[new_id] = thresh_rng.randi_range(
		Constants.SECURITY_CHANGE_TICKS_MIN,
		Constants.SECURITY_CHANGE_TICKS_MAX
	)
	GameState.grid_dominion[new_id] = {
		"controlling_faction_id": "",
		"security_tag": security,
	}
	GameState.economy_upgrade_progress[new_id] = {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0}
	GameState.economy_downgrade_progress[new_id] = {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0}
	GameState.economy_change_threshold[new_id] = {}
	for category in ["RAW", "MANUFACTURED", "CURRENCY"]:
		var econ_thresh_rng := RandomNumberGenerator.new()
		econ_thresh_rng.seed = hash(str(GameState.world_seed) + ":econ_thresh:" + new_id + ":" + category)
		GameState.economy_change_threshold[new_id][category] = econ_thresh_rng.randi_range(
			Constants.ECONOMY_CHANGE_TICKS_MIN,
			Constants.ECONOMY_CHANGE_TICKS_MAX
		)
	GameState.hostile_infestation_progress[new_id] = 0
	GameState.discovered_sector_count = next_discovery_count
	_register_discovered_sector_template(new_id, new_name, connections, global_position, initial_tags, profile, placement)
	_agent_layer._last_exploration_outcome = "discovered"

	# Record
	GameState.sector_names[new_id] = new_name
	if not (new_id in GameState.discovered_sectors):
		GameState.discovered_sectors.append(new_id)
	var generated_station: Dictionary = _generate_procedural_station_for_sector(new_id)
	GameState.discovery_log.append({
		"tick": GameState.sim_tick_count,
		"discoverer": agent_id,
		"from": source_id,
		"requested_from": sector_id,
		"new_sector": new_id,
		"name": new_name,
		"procedural_type": str(profile.get("procedural_type", "deep_space")),
		"global_position": global_position,
		"branch_separation_deg": float(placement.get("branch_separation_deg", 180.0)),
		"branch_mode": str(placement.get("branch_mode", "planar")),
		"generated_station_id": str(generated_station.get("id", "")),
	})
	_agent_layer._log_event(agent_id, "sector_discovered", source_id, {
		"new_sector": new_id,
		"name": new_name,
		"connections": connections,
		"requested_from": sector_id,
		"procedural_type": str(profile.get("procedural_type", "deep_space")),
		"global_position": global_position,
		"generated_station_id": str(generated_station.get("id", "")),
	})

func _should_attempt_exploration(agent: Dictionary, sector_id: String, sector_tags: Array) -> bool:
	if agent.get("wealth_tag") == "BROKE":
		return false
	if _is_exploration_cooldown_active(agent):
		return false
	if not _is_exploration_anchor_sector(sector_id, sector_tags):
		return false
	return _has_local_exploration_outlet(sector_id)

func _is_exploration_cooldown_active(agent: Dictionary) -> bool:
	var last_discovery: int = int(agent.get("last_discovery_tick", -999))
	return GameState.sim_tick_count - last_discovery < Constants.EXPLORATION_COOLDOWN_TICKS

func _is_exploration_anchor_sector(sector_id: String, sector_tags: Array) -> bool:
	if "FRONTIER" in sector_tags:
		return true
	if _has_frontier_pressure(sector_tags):
		return true
	if _is_discovered_sector_id(sector_id):
		return true
	var sector_type: String = _agent_layer._get_sector_type(sector_id)
	return sector_type in ["frontier", "deep_space", "hazard_zone"]

func _has_local_exploration_outlet(sector_id: String) -> bool:
	if _agent_layer._graph_degree(sector_id) < Constants.MAX_CONNECTIONS_PER_SECTOR:
		return true
	var neighbors: Array = Array(GameState.world_topology.get(sector_id, {}).get("connections", []))
	for neighbor_id in neighbors:
		if _agent_layer._graph_degree(str(neighbor_id)) < Constants.MAX_CONNECTIONS_PER_SECTOR:
			return true
	return false

func _handle_explorer_non_exploration_turn(agent_id: String, agent: Dictionary, sector_id: String, sector_tags: Array, at_station: bool) -> void:
	if agent.get("wealth_tag") == "BROKE":
		if at_station:
			return
		_action_move_toward_exploration_target(agent_id, agent)
		return

	if _is_exploration_cooldown_active(agent) and _is_exploration_anchor_sector(sector_id, sector_tags) and _has_local_exploration_outlet(sector_id):
		return

	_action_move_toward_exploration_target(agent_id, agent)

func _action_move_toward_exploration_target(agent_id: String, agent: Dictionary) -> void:
	var current: String = agent.get("current_sector_id", "")
	var neighbors: Array = Array(GameState.world_topology.get(current, {}).get("connections", []))
	if neighbors.empty():
		return

	var best_sector: String = ""
	var best_score: float = -1000000.0
	for neighbor_id in neighbors:
		var neighbor_key: String = str(neighbor_id)
		var n_tags: Array = Array(GameState.sector_tags.get(neighbor_key, []))
		var score: float = 0.0
		if _is_exploration_anchor_sector(neighbor_key, n_tags):
			score += 4.0
		if _has_frontier_pressure(n_tags):
			score += 1.5
		if "FRONTIER" in n_tags:
			score += 1.5
		if _is_discovered_sector_id(neighbor_key):
			score += 1.0

		var degree: int = _agent_layer._graph_degree(neighbor_key)
		if degree < Constants.MAX_CONNECTIONS_PER_SECTOR:
			score += 1.25
		if degree <= 2:
			score += 0.75

		if agent.get("wealth_tag") == "BROKE":
			score += 2.5
		if agent.get("condition_tag") == "DAMAGED":
			score += 1.0

		score -= float(_agent_layer._active_agent_count_in_sector(neighbor_key)) * 0.25

		if score > best_score or (is_equal_approx(score, best_score) and (best_sector == "" or neighbor_key < best_sector)):
			best_score = score
			best_sector = neighbor_key

	if best_sector != "":
		_agent_layer._action_move_toward(agent_id, agent, best_sector)
	else:
		_agent_layer._action_move_random(agent_id, agent)

func _get_exploration_success_modifier(sector_id: String, sector_tags: Array) -> float:
	var dev_level: String = GameState.colony_levels.get(sector_id, "frontier")
	var sector_type: String = _agent_layer._get_sector_type(sector_id)
	var modifier: float = 0.75
	match dev_level:
		"hub":
			modifier = 0.4
		"colony":
			modifier = 0.6
		"outpost":
			modifier = 0.82
		"frontier":
			modifier = 1.0
	if sector_type in ["deep_space", "hazard_zone"]:
		modifier *= 0.9
	elif sector_type == "star":
		modifier *= 1.2
	elif sector_type == "planet":
		modifier *= 1.0
	elif sector_type == "moon":
		modifier *= 0.8

	if _has_frontier_pressure(sector_tags):
		modifier = min(1.0, modifier + 0.15)
		
	return modifier

func _has_frontier_pressure(sector_tags: Array) -> bool:
	return (
		"HARSH" in sector_tags
		or "EXTREME" in sector_tags
		or "LAWLESS" in sector_tags
		or "CONTESTED" in sector_tags
	)

func _generate_procedural_station_for_sector(sector_id: String) -> Dictionary:
	if sector_id == "":
		return {}
	if not GameState.world_topology.has(sector_id):
		return {}
	if not TemplateDatabase.locations.has(sector_id):
		return {}

	var station_id: String = "station_%s" % sector_id
	if GameState.station_by_id.has(station_id):
		return Dictionary(GameState.station_by_id.get(station_id, {})).duplicate(true)

	var sector_name: String = str(GameState.sector_names.get(sector_id, ""))
	if sector_name == "":
		sector_name = str(_get_template_value(TemplateDatabase.locations.get(sector_id), "location_name", sector_id))
	var station_name: String = "%s Station" % sector_name
	var docking_point: Vector3 = _build_procedural_station_docking_point(sector_id)

	var station_data: Dictionary = {
		"id": station_id,
		"display_name": station_name,
		"sector_id": sector_id,
		"location_id": station_id,
		"docking_point": docking_point,
	}
	GameState.station_by_id[station_id] = station_data.duplicate(true)

	var world_sector: Dictionary = GameState.world_topology.get(sector_id, {})
	world_sector["station_ids"] = [station_id]
	GameState.world_topology[sector_id] = world_sector

	var sector_tags: Array = Array(GameState.sector_tags.get(sector_id, []))
	if not ("STATION" in sector_tags):
		sector_tags.append("STATION")
	GameState.sector_tags[sector_id] = sector_tags

	var market_rng := RandomNumberGenerator.new()
	market_rng.seed = hash(str(GameState.world_seed) + ":" + station_id)

	var seeded_market: Dictionary = {}
	for commodity_id in Constants.COMMODITY_CLASSIFICATION:
		if commodity_id == "commodity_default":
			continue
		var category: String = Constants.COMMODITY_CLASSIFICATION[commodity_id]
		var level: String = Constants.get_economy_level_for_category(sector_tags, category)
		var params: Dictionary = Constants.ECONOMY_LEVEL_PARAMS.get(level, Constants.ECONOMY_LEVEL_PARAMS["ADEQUATE"])
		
		var min_qty: int = params.get("min_quantity", 5)
		var max_qty: int = params.get("max_quantity", 20)
		var multiplier: float = params.get("price_multiplier", 1.0)
		
		var base_value: int = 10
		if TemplateDatabase.assets_commodities.has(commodity_id):
			var template = TemplateDatabase.assets_commodities[commodity_id]
			if template and "base_value" in template:
				base_value = template.base_value
		
		var quantity: int = market_rng.randi_range(min_qty, max_qty)
		var buy_price: int = int(round(base_value * multiplier))
		var sell_price: int = int(round(buy_price * Constants.COMMODITY_SELL_PRICE_FRACTION))
		
		seeded_market[commodity_id] = {
			"buy_price": buy_price,
			"sell_price": sell_price,
			"quantity": quantity
		}

	GameState.locations[station_id] = {
		"location_name": station_name,
		"position_in_zone": docking_point,
		"available_services": ["trade", "contracts"],
		"sector_id": sector_id,
		"market_inventory": seeded_market,
	}

	var sector_template = TemplateDatabase.locations.get(sector_id)
	var hints = _get_template_value(sector_template, "procedural_hints", {})
	if not (hints is Dictionary):
		hints = {}
	hints["procedural_station_id"] = station_id
	hints["procedural_station_name"] = station_name
	hints["procedural_station_docking_point"] = docking_point
	if sector_template is Dictionary:
		sector_template["procedural_hints"] = hints
		TemplateDatabase.locations[sector_id] = sector_template
	else:
		sector_template.procedural_hints = hints

	return station_data.duplicate(true)

func _build_procedural_station_docking_point(sector_id: String) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(GameState.world_seed) + ":procedural_station:" + sector_id)
	var radial_distance: float = 2800.0 + rng.randf_range(0.0, 1900.0)
	var angle: float = rng.randf_range(-PI, PI)
	var x: float = cos(angle) * radial_distance
	var z: float = sin(angle) * radial_distance
	var y: float = rng.randf_range(-220.0, 220.0)
	return Vector3(x, y, z)

func _select_discovered_sector_profile(new_id: String) -> Dictionary:
	var profile_rng: RandomNumberGenerator = _make_discovery_rng("profile", new_id)
	return _agent_layer._LOW_VISIBILITY_DISCOVERY_PROFILES[profile_rng.randi() % _agent_layer._LOW_VISIBILITY_DISCOVERY_PROFILES.size()].duplicate(true)

func _build_discovered_sector_placement(new_id: String, source_id: String, profile: Dictionary) -> Dictionary:
	var placement_rng: RandomNumberGenerator = _make_discovery_rng("placement", new_id)
	var source_position: Vector3 = _get_sector_global_position(source_id)
	var branch_mode: String = "vertical" if _should_use_vertical_discovery_branch(source_id, placement_rng) else "planar"
	var preferred_direction: Vector3 = _get_discovery_base_direction(source_id, placement_rng)
	
	var source_type: String = _agent_layer._get_sector_type(source_id)
	var target_type: String = str(profile.get("sector_type", "deep_space"))
	
	var base_dist: float = Constants.DISCOVERY_BRANCH_DISTANCE_BASE
	var jitter_dist: float = Constants.DISCOVERY_BRANCH_DISTANCE_JITTER
	
	# Adjust distances according to sector type pairs
	if source_type == "star" and target_type == "star":
		base_dist = 300000.0
		jitter_dist = 200000.0
	elif source_type == "star" and target_type == "planet":
		base_dist = 75000.0
		jitter_dist = 25000.0
	elif source_type == "planet" and target_type == "moon":
		base_dist = 7500.0
		jitter_dist = 2500.0
	elif target_type == "deep_space" or target_type == "hazard_zone":
		if source_type == "star":
			base_dist = 150000.0
			jitter_dist = 50000.0
		else:
			base_dist = 50000.0
			jitter_dist = 25000.0

	var best_candidate: Vector3 = source_position + (preferred_direction * base_dist)
	var best_axis: Vector3 = preferred_direction
	var best_clearance: float = -1.0
	var best_branch_separation: float = 180.0
	var best_score: float = -INF
	var required_branch_separation: float = _get_required_discovery_branch_angle(source_id)

	for _attempt in range(Constants.DISCOVERY_BRANCH_POSITION_ATTEMPTS):
		var distance: float = base_dist + placement_rng.randf_range(-jitter_dist, jitter_dist)
		var branch_axis: Vector3 = _build_discovery_branch_axis(source_id, preferred_direction, branch_mode, placement_rng)
		var candidate: Vector3 = source_position + (branch_axis * distance)
		candidate.y += placement_rng.randf_range(
			-Constants.DISCOVERY_PLANAR_VERTICAL_JITTER,
			Constants.DISCOVERY_PLANAR_VERTICAL_JITTER
		)
		if branch_mode == "vertical":
			var vertical_sign: float = -1.0 if placement_rng.randf() < 0.5 else 1.0
			candidate.y += vertical_sign * placement_rng.randf_range(
				Constants.DISCOVERY_VERTICAL_BRANCH_MIN_OFFSET,
				Constants.DISCOVERY_VERTICAL_BRANCH_MAX_OFFSET
			)

		var clearance: float = _measure_discovery_clearance(candidate, source_id)
		var branch_separation_deg: float = _measure_discovery_branch_separation(source_id, candidate)
		var candidate_score: float = clearance + (branch_separation_deg * Constants.DISCOVERY_BRANCH_ANGLE_SCORE_WEIGHT)
		if candidate_score > best_score:
			best_score = candidate_score
			best_clearance = clearance
			best_candidate = candidate
			best_axis = branch_axis
			best_branch_separation = branch_separation_deg
		if clearance >= Constants.DISCOVERY_BRANCH_MIN_CLEARANCE and branch_separation_deg >= required_branch_separation:
			break

	return {
		"global_position": best_candidate,
		"branch_axis": best_axis,
		"branch_separation_deg": best_branch_separation,
		"branch_mode": branch_mode,
		"is_valid": best_clearance >= Constants.DISCOVERY_BRANCH_MIN_CLEARANCE and best_branch_separation >= required_branch_separation,
	}

func _build_discovery_branch_axis(source_id: String, preferred_direction: Vector3, branch_mode: String, placement_rng: RandomNumberGenerator) -> Vector3:
	var planar_direction: Vector3 = Vector3(preferred_direction.x, 0.0, preferred_direction.z)
	if planar_direction.length_squared() < 0.001:
		planar_direction = _random_planar_direction(placement_rng)
	planar_direction = planar_direction.normalized()
	var jitter_span_deg: float = min(
		88.0,
		Constants.DISCOVERY_BRANCH_DIRECTION_JITTER_DEG + (
			float(_get_discovered_branch_count(source_id)) * Constants.DISCOVERY_BRANCH_JITTER_PER_EXISTING_BRANCH_DEG
		)
	)
	planar_direction = planar_direction.rotated(
		Vector3.UP,
		deg2rad(placement_rng.randf_range(
			-jitter_span_deg,
			jitter_span_deg
		))
	)

	if branch_mode != "vertical":
		return Vector3(
			planar_direction.x,
			preferred_direction.y,
			planar_direction.z
		).normalized()

	var vertical_sign: float = -1.0 if placement_rng.randf() < 0.5 else 1.0
	var branch_axis: Vector3 = (planar_direction * (1.0 - Constants.DISCOVERY_VERTICAL_BRANCH_Y_BIAS)) + (
		Vector3.UP * vertical_sign * Constants.DISCOVERY_VERTICAL_BRANCH_Y_BIAS
	)
	return branch_axis.normalized()

func _get_discovery_base_direction(source_id: String, placement_rng: RandomNumberGenerator) -> Vector3:
	var inherited_axis: Vector3 = _get_inherited_discovery_axis(source_id)
	var source_position: Vector3 = _get_sector_global_position(source_id)
	var away_bias: Vector3 = Vector3.ZERO
	var neighbors: Array = GameState.world_topology.get(source_id, {}).get("connections", [])
	for neighbor_id in neighbors:
		var neighbor_position: Vector3 = _get_sector_global_position(neighbor_id)
		var away_vector: Vector3 = source_position - neighbor_position
		if away_vector.length_squared() > 0.001:
			away_bias += away_vector.normalized()

	if inherited_axis.length_squared() > 0.001:
		away_bias += inherited_axis.normalized() * 1.35

	if away_bias.length_squared() < 0.001:
		return _random_planar_direction(placement_rng)
	return away_bias.normalized()

func _get_inherited_discovery_axis(source_id: String) -> Vector3:
	var source_template = TemplateDatabase.locations.get(source_id)
	var hints = _get_template_value(source_template, "procedural_hints", {})
	if not (hints is Dictionary):
		return Vector3.ZERO
	var branch_axis = hints.get("branch_axis", Vector3.ZERO)
	if branch_axis is Vector3 and branch_axis.length_squared() > 0.001:
		return branch_axis
	return Vector3.ZERO

func _should_use_vertical_discovery_branch(source_id: String, placement_rng: RandomNumberGenerator) -> bool:
	var source_template = TemplateDatabase.locations.get(source_id)
	if bool(_get_template_value(source_template, "is_procedural", false)):
		var hints = _get_template_value(source_template, "procedural_hints", {})
		if hints is Dictionary and str(hints.get("branch_mode", "planar")) == "vertical":
			return placement_rng.randf() < Constants.DISCOVERY_VERTICAL_BRANCH_CONTINUE_CHANCE
	return placement_rng.randf() < Constants.DISCOVERY_VERTICAL_BRANCH_CHANCE

func _measure_discovery_clearance(candidate_position: Vector3, source_id: String) -> float:
	var nearest_distance: float = INF
	for sector_id in TemplateDatabase.locations:
		if sector_id == source_id:
			continue
		var sector_position: Vector3 = _get_sector_global_position(sector_id)
		var distance: float = candidate_position.distance_to(sector_position)
		if distance < nearest_distance:
			nearest_distance = distance
	if nearest_distance == INF:
		return Constants.DISCOVERY_BRANCH_MIN_CLEARANCE
	return nearest_distance

func _measure_discovery_branch_separation(source_id: String, candidate_position: Vector3) -> float:
	var source_position: Vector3 = _get_sector_global_position(source_id)
	var candidate_axis: Vector3 = candidate_position - source_position
	if candidate_axis.length_squared() < 0.001:
		return 180.0
	candidate_axis = candidate_axis.normalized()
	var min_angle_deg: float = 180.0
	var neighbors: Array = GameState.world_topology.get(source_id, {}).get("connections", [])
	for neighbor_id in neighbors:
		if not _is_discovered_sector_id(str(neighbor_id)):
			continue
		var neighbor_axis: Vector3 = _get_sector_global_position(str(neighbor_id)) - source_position
		if neighbor_axis.length_squared() < 0.001:
			continue
		min_angle_deg = min(min_angle_deg, rad2deg(candidate_axis.angle_to(neighbor_axis.normalized())))
	return min_angle_deg

func _get_required_discovery_branch_angle(source_id: String) -> float:
	return Constants.DISCOVERY_BRANCH_MIN_SIBLING_ANGLE_DEG if _get_discovered_branch_count(source_id) > 0 else 0.0

func _get_discovered_branch_count(source_id: String) -> int:
	var count: int = 0
	var neighbors: Array = GameState.world_topology.get(source_id, {}).get("connections", [])
	for neighbor_id in neighbors:
		if _is_discovered_sector_id(str(neighbor_id)):
			count += 1
	return count

func _is_discovered_sector_id(sector_id: String) -> bool:
	if sector_id.begins_with("discovered_"):
		return true
	var hints = _get_template_value(TemplateDatabase.locations.get(sector_id), "procedural_hints", {})
	return hints is Dictionary and bool(hints.get("low_visibility", false))

func _filter_spatially_plausible_connections(source_id: String, candidate_connections: Array, global_position: Vector3) -> Array:
	var filtered_connections: Array = [source_id]
	for idx in range(1, candidate_connections.size()):
		var target_id: String = str(candidate_connections[idx])
		var target_position: Vector3 = _get_sector_global_position(target_id)
		if global_position.distance_to(target_position) <= Constants.DISCOVERY_MAX_LINK_DISTANCE:
			filtered_connections.append(target_id)
	return filtered_connections

func _get_discovery_connection_chances(source_id: String, source_tags: Array) -> Dictionary:
	var extra_one: float = Constants.EXTRA_CONNECTION_1_CHANCE
	var extra_two: float = Constants.EXTRA_CONNECTION_2_CHANCE
	if _is_exploration_anchor_sector(source_id, source_tags) or _agent_layer._graph_degree(source_id) <= 2:
		extra_one = max(extra_one, Constants.FRONTIER_DISCOVERY_EXTRA_CONNECTION_1_CHANCE)
		extra_two = max(extra_two, Constants.FRONTIER_DISCOVERY_EXTRA_CONNECTION_2_CHANCE)
	return {
		"extra_one": extra_one,
		"extra_two": extra_two,
	}

func _register_discovered_sector_template(
		new_id: String,
		new_name: String,
		connections: Array,
		global_position: Vector3,
		initial_tags: Array,
		profile: Dictionary,
		placement: Dictionary) -> void:
	var template = LocationTemplateScript.new()
	template.template_id = new_id
	template.location_name = new_name
	template.sector_scene_path = ""
	template.global_position = global_position
	template.is_procedural = true
	template.procedural_type = str(profile.get("procedural_type", "deep_space"))
	template.procedural_hints = {
		"branch_axis": placement.get("branch_axis", Vector3.FORWARD),
		"branch_mode": placement.get("branch_mode", "planar"),
		"branch_separation_deg": placement.get("branch_separation_deg", 180.0),
		"discovered_from": connections[0] if not connections.empty() else "",
		"low_visibility": true,
		"source_distance": global_position.distance_to(_get_sector_global_position(connections[0])) if not connections.empty() else 0.0,
	}
	template.sector_description = str(profile.get("description", "A dim deep-space contact that demanded a deliberate search."))
	template.connections = PoolStringArray(connections)
	template.sector_type = str(profile.get("sector_type", "deep_space"))
	template.initial_sector_tags = PoolStringArray(initial_tags)
	TemplateDatabase.locations[new_id] = template

func _make_discovery_rng(purpose: String, new_id: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(GameState.world_seed) + ":" + purpose + ":" + new_id + ":" + str(GameState.sim_tick_count))
	return rng

func _get_template_value(template, key: String, default_value = null):
	if template == null:
		return default_value
	if template is Dictionary:
		return template.get(key, default_value)
	var value = template.get(key)
	return value if value != null else default_value

func _get_sector_global_position(sector_id: String) -> Vector3:
	var sector_template = TemplateDatabase.locations.get(sector_id)
	var global_position = _get_template_value(sector_template, "global_position", null)
	return global_position if global_position is Vector3 else Vector3.ZERO

func _random_planar_direction(placement_rng: RandomNumberGenerator) -> Vector3:
	var angle: float = placement_rng.randf_range(-PI, PI)
	return Vector3(cos(angle), 0.0, sin(angle)).normalized()

func _generate_sector_name() -> String:
	return _generate_sector_name_for_count(GameState.discovered_sector_count)

func _generate_sector_name_for_count(discovery_count: int) -> String:
	var prefixes: Array = Array(Constants.FRONTIER_DISCOVERY_NAME_PREFIXES)
	var suffixes: Array = Array(Constants.FRONTIER_DISCOVERY_NAME_SUFFIXES)
	return _build_discovery_sector_name_candidate(discovery_count, 0, prefixes, suffixes)

func _generate_sector_name_for_discovery(discovery_count: int, profile: Dictionary, initial_tags: Array) -> String:
	var procedural_type: String = str(profile.get("procedural_type", "deep_space"))
	var prefixes: Array = _get_discovery_prefix_word_pool(procedural_type, initial_tags)
	var suffixes: Array = _get_discovery_suffix_word_pool(initial_tags)
	return _generate_unique_discovery_sector_name(discovery_count, prefixes, suffixes)

func _generate_unique_discovery_sector_name(discovery_count: int, prefixes: Array, suffixes: Array) -> String:
	var used_names: Dictionary = _used_sector_display_names()
	var max_attempts: int = Constants.DISCOVERY_NAME_UNIQUENESS_MAX_ATTEMPTS
	for attempt in range(max_attempts):
		var candidate: String = _build_discovery_sector_name_candidate(discovery_count, attempt, prefixes, suffixes)
		if not used_names.has(candidate.to_lower()):
			return candidate
	for attempt in range(max_attempts, max_attempts + 12):
		var fallback: String = _build_multi_root_discovery_name_candidate(discovery_count, attempt)
		if not used_names.has(fallback.to_lower()):
			return fallback
	return "Unnamed Reach " + str(discovery_count)

func _build_discovery_sector_name_candidate(discovery_count: int, attempt: int, prefixes: Array, suffixes: Array) -> String:
	var generated_root: String = _generate_discovery_name_root(discovery_count, attempt)
	var seed_key: String = _discovery_name_seed_key(discovery_count, attempt)
	var prefix_word: String = _select_discovery_name_word(prefixes, seed_key + ":prefix")
	var suffix_word: String = _select_discovery_name_word(suffixes, seed_key + ":suffix", prefix_word)
	return _compose_discovery_sector_name(generated_root, prefix_word, suffix_word)

func _build_multi_root_discovery_name_candidate(discovery_count: int, attempt: int) -> String:
	var leading_root: String = _generate_discovery_name_root(discovery_count, attempt)
	var trailing_root: String = _agent_layer._legacy_system_name_generator.generate_system_name(
		_discovery_name_seed_key(discovery_count, attempt) + ":tail",
		3,
		4
	)
	if trailing_root.empty():
		return leading_root
	return leading_root + " " + trailing_root

func _generate_discovery_name_root(discovery_count: int, attempt: int = 0) -> String:
	return _agent_layer._legacy_system_name_generator.generate_system_name(
		_discovery_name_seed_key(discovery_count, attempt),
		Constants.DISCOVERY_SYSTEM_NAME_LENGTH_MIN,
		Constants.DISCOVERY_SYSTEM_NAME_LENGTH_MAX
	)

func _compose_discovery_sector_name(generated_root: String, prefix_word: String, suffix_word: String) -> String:
	var cleaned_root: String = str(generated_root).strip_edges()
	if cleaned_root.empty():
		return "Unnamed Reach"
	var word_budget: int = _discovery_name_word_budget(cleaned_root.length())
	var composed_name: String = cleaned_root
	if word_budget >= 2 and not prefix_word.empty():
		composed_name = prefix_word + " " + composed_name
	if word_budget >= 1 and not suffix_word.empty():
		composed_name += " " + suffix_word
	return composed_name

func _discovery_name_word_budget(root_length: int) -> int:
	if root_length <= Constants.DISCOVERY_NAME_SHORT_ROOT_MAX_LENGTH:
		return 2
	if root_length <= Constants.DISCOVERY_NAME_MEDIUM_ROOT_MAX_LENGTH:
		return 1
	return 0

func _select_discovery_name_word(words: Array, seed_key: String, excluded_word: String = "") -> String:
	if words.empty():
		return ""
	var word_rng := RandomNumberGenerator.new()
	word_rng.seed = hash(str(GameState.world_seed) + ":discovery_word:" + str(seed_key))
	var index: int = word_rng.randi() % words.size()
	var selected_word: String = str(words[index])
	if not excluded_word.empty() and selected_word == excluded_word and words.size() > 1:
		selected_word = str(words[(index + 1) % words.size()])
	return selected_word

func _discovery_name_seed_key(discovery_count: int, attempt: int) -> String:
	return str(GameState.world_seed) + ":discovery_name:" + str(discovery_count) + ":" + str(attempt)

func _used_sector_display_names() -> Dictionary:
	var used_names: Dictionary = {}
	for sector_name in GameState.sector_names.values():
		var known_name: String = str(sector_name).strip_edges()
		if not known_name.empty():
			used_names[known_name.to_lower()] = true
	for sector_id in TemplateDatabase.locations:
		var template_name: String = str(_get_template_value(TemplateDatabase.locations.get(sector_id), "location_name", "")).strip_edges()
		if not template_name.empty():
			used_names[template_name.to_lower()] = true
	return used_names

func _get_discovery_prefix_word_pool(procedural_type: String, initial_tags: Array) -> Array:
	var procedural_pool = Constants.FRONTIER_DISCOVERY_NAME_PREFIXES_BY_PROCEDURAL_TYPE.get(procedural_type, [])
	if procedural_pool is Array and not procedural_pool.empty():
		return Array(procedural_pool)
	var environment_pool = Constants.FRONTIER_DISCOVERY_NAME_PREFIXES_BY_ENVIRONMENT.get(_discovery_environment_tag(initial_tags), [])
	if environment_pool is Array and not environment_pool.empty():
		return Array(environment_pool)
	return Array(Constants.FRONTIER_DISCOVERY_NAME_PREFIXES)

func _get_discovery_suffix_word_pool(initial_tags: Array) -> Array:
	var economy_level: String = _discovery_economy_level(initial_tags)
	var economy_pool = Constants.FRONTIER_DISCOVERY_NAME_SUFFIXES_BY_ECONOMY_LEVEL.get(economy_level, [])
	if economy_pool is Array and not economy_pool.empty():
		return Array(economy_pool)
	return Array(Constants.FRONTIER_DISCOVERY_NAME_SUFFIXES)

func _discovery_environment_tag(initial_tags: Array) -> String:
	for environment_tag in ["EXTREME", "HARSH", "MILD"]:
		if environment_tag in initial_tags:
			return environment_tag
	return "MILD"

func _discovery_economy_level(initial_tags: Array) -> String:
	var counts: Dictionary = {"POOR": 0, "ADEQUATE": 0, "RICH": 0}
	for tag in initial_tags:
		var tag_text: String = str(tag)
		for economy_level in ["POOR", "ADEQUATE", "RICH"]:
			if tag_text.ends_with("_" + economy_level):
				counts[economy_level] = int(counts.get(economy_level, 0)) + 1
	if int(counts.get("RICH", 0)) >= 2:
		return "RICH"
	if int(counts.get("POOR", 0)) >= 2:
		return "POOR"
	return "ADEQUATE"

func _nearby_candidates(source_id: String, exclude: Array) -> Array:
	var candidates: Array = []
	var neighbors: Array = GameState.world_topology.get(source_id, {}).get("connections", [])
	for sid in neighbors:
		if sid in exclude:
			continue
		if _agent_layer._graph_degree(sid) >= Constants.MAX_CONNECTIONS_PER_SECTOR:
			continue
		candidates.append(sid)
	return candidates

func _distant_loop_candidate(source_id: String, exclude: Array):
	if not GameState.world_topology.has(source_id):
		return null

	# BFS to find sectors at >= LOOP_MIN_HOPS distance
	var queue: Array = [[source_id, 0]]
	var visited: Dictionary = {source_id: true}
	var distant: Array = []

	while not queue.empty():
		var item: Array = queue.pop_front()
		var current_id: String = item[0]
		var depth: int = item[1]

		if depth >= Constants.LOOP_MIN_HOPS and not (current_id in exclude) and _agent_layer._graph_degree(current_id) < Constants.MAX_CONNECTIONS_PER_SECTOR:
			distant.append(current_id)

		var conns: Array = GameState.world_topology.get(current_id, {}).get("connections", [])
		for neighbor_id in conns:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append([neighbor_id, depth + 1])

	if distant.empty():
		return null

	distant.sort()
	var loop_rng := RandomNumberGenerator.new()
	loop_rng.seed = hash(str(GameState.world_seed) + ":loop:" + source_id + ":" + str(GameState.discovered_sector_count) + ":" + str(GameState.sim_tick_count))
	return distant[loop_rng.randi() % distant.size()]