#
# PROJECT: GDTLancer
# MODULE: simulation_report.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context
# LOG_REF: 2026-06-11 00:15:00
#

extends Reference

## SimulationReport: Generates chronicle-style narrative reports of simulation
## runs, matching the Python sandbox's `main.py --chronicle` output format
## while also supporting focus-aware and sort-aware scoped analysis.
##
## Usage:
##   var report = SimulationReport.new()
##   report.begin(seed_string)      # snapshot initial state
##   # ... run N ticks ...
##   report.record_epoch(tick_start, tick_end, events)   # after each epoch
##   var text = report.finalize()    # overall summary
##
## Or use the convenience method:
##   var text = report.run_and_report(engine, tick_count, epoch_size, report_request)


# =============================================================================
# === STATE ===================================================================
# =============================================================================

## All chronicle lines accumulated during the run.
var _lines: Array = []

## Sector snapshot from the previous epoch (for change detection).
var _prev_sector_snap: Dictionary = {}

## All events collected across all epochs (for summary stats).
var _all_events: Array = []

## Total ticks run.
var _total_ticks: int = 0

## Seed string.
var _seed: String = ""

## Normalized request describing report focus and formatting.
var _report_request: Dictionary = {}


# =============================================================================
# === CONVENIENCE: ONE-SHOT RUN ===============================================
# =============================================================================

## Runs `tick_count` ticks on the given engine and returns the full chronicle
## report as a plain-text string. Events are grouped into epochs of `epoch_size`.
func run_and_report(engine, tick_count: int, epoch_size: int = 1, report_request: Dictionary = {}) -> String:
	_lines.clear()
	_all_events.clear()
	_prev_sector_snap.clear()
	_total_ticks = tick_count
	_seed = GameState.world_seed
	_report_request = _normalize_report_request(report_request)

	# Identity-based deduplication: track which event objects we've already
	# copied so that the 200-event rolling cap in ChronicleLayer doesn't
	# cause us to lose events.  We scan the whole buffer each tick and copy
	# any previously-unseen events into our own uncapped list.
	# (Mirrors the Python sandbox approach in main.py _run_chronicle.)
	var seen_event_refs: Dictionary = {}   # event dict ref -> true
	var all_new_events: Array = []         # uncapped accumulator

	# Seed the seen set with any pre-existing events so we don't double-count.
	for e in GameState.chronicle_events:
		seen_event_refs[e] = true

	# Take initial sector snapshot
	_prev_sector_snap = _take_sector_snapshot()

	# Header
	_lines.append("================================================================")
	_lines.append("CHRONICLE OF THE SECTOR  (seed: %s)" % _seed)
	_lines.append("================================================================")
	_lines.append("REPORT MODE: %s  |  FOCUS: %s  |  SORT: %s  |  DETAIL: %s" % [
		str(_report_request.get("focus_mode", "world")).to_upper(),
		str(_report_request.get("focus_id", "world")),
		str(_report_request.get("sort_mode", "chronological")),
		str(_report_request.get("detail_level", "standard")),
	])
	_lines.append("")

	var epoch_start: int = GameState.sim_tick_count
	var epoch_num: int = 0
	var ticks_in_epoch: int = 0

	for _i in range(tick_count):
		engine.process_tick()
		ticks_in_epoch += 1

		# Scan the rolling buffer for any event dicts we haven't seen yet.
		# Because ChronicleLayer caps at 200 with pop_front, index-based
		# tracking breaks once the buffer fills.  Checking object identity
		# (Dictionary reference equality) is immune to buffer eviction.
		for e in GameState.chronicle_events:
			if not seen_event_refs.has(e):
				seen_event_refs[e] = true
				all_new_events.append(e)

		# End of epoch?
		var current_tick: int = GameState.sim_tick_count
		if ticks_in_epoch >= epoch_size or _i == tick_count - 1:
			var epoch_end: int = current_tick
			epoch_num += 1

			# Filter to this epoch's events from the uncapped accumulator
			var epoch_events: Array = _collect_epoch_events(all_new_events, epoch_start, epoch_end)
			_all_events.append_array(epoch_events)

			# Epoch header
			var age: String = GameState.world_age
			_lines.append("--- Epoch %d: ticks %d-%d [%s] ---" % [
				epoch_num, epoch_start + 1, epoch_end, age
			])

			var epoch_summary: Array = _epoch_summary(epoch_events)
			if not epoch_summary.empty():
				_lines.append_array(epoch_summary)
			var detailed_log: Array = _epoch_detailed_log(epoch_events)
			if not detailed_log.empty():
				_lines.append_array(detailed_log)
			_lines.append("")

			epoch_start = epoch_end
			ticks_in_epoch = 0

	# Overall summary
	_lines.append_array(_summary())

	return PoolStringArray(_lines).join("\n")


## Runs one cumulative research pass and emits a bundled chronicle that
## captures requested milestones from the same live simulation run.
func run_composite_report(engine, tick_counts: Array, composite_request: Dictionary = {}) -> String:
	_lines.clear()
	_all_events.clear()
	_prev_sector_snap.clear()
	_total_ticks = 0
	_seed = GameState.world_seed
	_report_request = {}

	var normalized_tick_counts: Array = _normalize_composite_tick_counts(tick_counts)
	if normalized_tick_counts.empty():
		return "(no composite tick windows requested)"

	var normalized_request: Dictionary = _normalize_composite_request(composite_request)
	var tick_labels: Array = []
	for tick_count in normalized_tick_counts:
		tick_labels.append(str(tick_count))

	_lines.append("================================================================")
	_lines.append("COMPOSITE RESEARCH CHRONICLE  (seed: %s)" % _seed)
	_lines.append("================================================================")
	_lines.append("WINDOWS: %s" % PoolStringArray(tick_labels).join(", "))
	_lines.append("SECTOR SAMPLING: one deterministic sample per sector type")
	_lines.append("AGENT SAMPLING: one deterministic sample per role and persistence class")
	_lines.append("")

	var seen_event_refs: Dictionary = {}
	var all_new_events: Array = []
	for existing_event in GameState.chronicle_events:
		seen_event_refs[existing_event] = true

	var start_tick: int = GameState.sim_tick_count
	var next_window_index: int = 0
	var max_tick_count: int = int(normalized_tick_counts[normalized_tick_counts.size() - 1])

	while GameState.sim_tick_count - start_tick < max_tick_count:
		engine.process_tick()

		for event in GameState.chronicle_events:
			if seen_event_refs.has(event):
				continue
			seen_event_refs[event] = true
			all_new_events.append(event)

		var elapsed_ticks: int = GameState.sim_tick_count - start_tick
		while next_window_index < normalized_tick_counts.size() and elapsed_ticks >= int(normalized_tick_counts[next_window_index]):
			var window_tick_count: int = int(normalized_tick_counts[next_window_index])
			var window_end_tick: int = start_tick + window_tick_count
			var window_events: Array = _collect_epoch_events(all_new_events, start_tick, window_end_tick)
			_lines.append_array(_build_composite_window_section(window_tick_count, window_events, normalized_request))
			if next_window_index < normalized_tick_counts.size() - 1:
				_lines.append("")
			next_window_index += 1

	return PoolStringArray(_lines).join("\n")


func _normalize_report_request(report_request: Dictionary) -> Dictionary:
	var focus_mode: String = str(report_request.get("focus_mode", "world")).to_lower()
	if not (focus_mode in ["world", "sector", "agent"]):
		focus_mode = "world"

	var sort_mode: String = str(report_request.get("sort_mode", "chronological")).to_lower()
	if not (sort_mode in ["chronological", "sector", "agent"]):
		sort_mode = "chronological"

	var detail_level: String = str(report_request.get("detail_level", "standard")).to_lower()
	if not (detail_level in ["summary", "standard", "verbose"]):
		detail_level = "standard"

	var focus_id: String = str(report_request.get("focus_id", ""))
	if focus_mode == "world" or focus_id == "":
		focus_id = "world" if focus_mode == "world" else focus_id

	return {
		"focus_mode": focus_mode,
		"focus_id": focus_id,
		"sort_mode": sort_mode,
		"detail_level": detail_level,
	}


func _normalize_composite_tick_counts(tick_counts: Array) -> Array:
	var normalized: Array = []
	var seen_values: Dictionary = {}
	for raw_value in tick_counts:
		var tick_count: int = int(raw_value)
		if tick_count <= 0:
			continue
		if seen_values.has(tick_count):
			continue
		seen_values[tick_count] = true
		normalized.append(tick_count)
	normalized.sort()
	return normalized


func _normalize_composite_request(composite_request: Dictionary) -> Dictionary:
	var detail_level: String = str(composite_request.get("detail_level", "summary")).to_lower()
	if not (detail_level in ["summary", "standard", "verbose"]):
		detail_level = "summary"

	var sort_mode: String = str(composite_request.get("sort_mode", "chronological")).to_lower()
	if not (sort_mode in ["chronological", "sector", "agent"]):
		sort_mode = "chronological"

	var sector_types: Array = []
	for sector_type in Array(composite_request.get("sector_types", [])):
		var normalized_sector_type: String = str(sector_type)
		if normalized_sector_type == "" or normalized_sector_type in sector_types:
			continue
		sector_types.append(normalized_sector_type)
	sector_types.sort()

	var agent_roles: Array = []
	for agent_role in Array(composite_request.get("agent_roles", [])):
		var normalized_agent_role: String = str(agent_role)
		if normalized_agent_role == "" or normalized_agent_role in agent_roles:
			continue
		agent_roles.append(normalized_agent_role)
	agent_roles.sort()

	return {
		"detail_level": detail_level,
		"sort_mode": sort_mode,
		"sector_types": sector_types,
		"agent_roles": agent_roles,
		"include_persistent": bool(composite_request.get("include_persistent", true)),
		"include_mortal": bool(composite_request.get("include_mortal", true)),
	}


func _build_composite_window_section(window_tick_count: int, window_events: Array, composite_request: Dictionary) -> Array:
	var lines: Array = []
	var previous_all_events: Array = _all_events
	var previous_total_ticks: int = _total_ticks
	var previous_report_request: Dictionary = _report_request.duplicate(true)

	_all_events = window_events.duplicate(true)
	_total_ticks = window_tick_count
	_report_request = _normalize_report_request({
		"focus_mode": "world",
		"focus_id": "world",
		"sort_mode": "chronological",
		"detail_level": "standard",
	})

	lines.append("================================================================")
	lines.append("COMPOSITE WINDOW: %d ticks" % window_tick_count)
	lines.append("================================================================")
	lines.append("  Captured events: %d" % _all_events.size())
	lines.append_array(_world_summary())

	lines.append("")
	lines.append("================================================================")
	lines.append("SAMPLED SECTORS")
	lines.append("================================================================")
	var sector_samples: Dictionary = _sample_sector_ids_by_type(window_tick_count, composite_request)
	if sector_samples.empty():
		lines.append("  (no eligible sector samples)")
	else:
		for sector_type in _sorted_keys(sector_samples):
			var sector_id: String = str(sector_samples[sector_type])
			_report_request = _normalize_report_request({
				"focus_mode": "sector",
				"focus_id": sector_id,
				"sort_mode": str(composite_request.get("sort_mode", "chronological")),
				"detail_level": str(composite_request.get("detail_level", "summary")),
			})
			lines.append("  Sector type sample [%s]: %s" % [str(sector_type), _sector_label_with_id(sector_id)])
			lines.append_array(_focused_summary())
			if str(composite_request.get("detail_level", "summary")) != "summary":
				lines.append_array(_epoch_detailed_log(_all_events))
			lines.append("")
		if not lines.empty() and lines[lines.size() - 1] == "":
			lines.remove(lines.size() - 1)

	lines.append("")
	lines.append("================================================================")
	lines.append("SAMPLED AGENTS")
	lines.append("================================================================")
	var agent_samples: Array = _sample_agent_entries(window_tick_count, composite_request)
	if agent_samples.empty():
		lines.append("  (no eligible agent samples)")
	else:
		for sample in agent_samples:
			var agent_id: String = str(sample.get("agent_id", ""))
			_report_request = _normalize_report_request({
				"focus_mode": "agent",
				"focus_id": agent_id,
				"sort_mode": str(composite_request.get("sort_mode", "chronological")),
				"detail_level": str(composite_request.get("detail_level", "summary")),
			})
			lines.append("  Agent sample [%s %s]: %s" % [
				str(sample.get("agent_class", "unknown")),
				str(sample.get("agent_role", "unknown")),
				_actor_label_with_id(agent_id),
			])
			lines.append_array(_focused_summary())
			if str(composite_request.get("detail_level", "summary")) != "summary":
				lines.append_array(_epoch_detailed_log(_all_events))
			lines.append("")
		if not lines.empty() and lines[lines.size() - 1] == "":
			lines.remove(lines.size() - 1)

	_all_events = previous_all_events
	_total_ticks = previous_total_ticks
	_report_request = previous_report_request
	return lines


func _sample_sector_ids_by_type(window_tick_count: int, composite_request: Dictionary) -> Dictionary:
	var requested_sector_types: Array = Array(composite_request.get("sector_types", []))
	var candidates_by_type: Dictionary = {}
	for sector_id in _sorted_keys(GameState.world_topology):
		var topology: Dictionary = GameState.world_topology.get(sector_id, {})
		var sector_type: String = str(topology.get("sector_type", "unknown"))
		if sector_type == "":
			sector_type = "unknown"
		if not requested_sector_types.empty() and not (sector_type in requested_sector_types):
			continue
		if not candidates_by_type.has(sector_type):
			candidates_by_type[sector_type] = []
		candidates_by_type[sector_type].append(str(sector_id))

	var samples: Dictionary = {}
	for sector_type in _sorted_keys(candidates_by_type):
		var sector_ids: Array = Array(candidates_by_type[sector_type])
		sector_ids.sort()
		if sector_ids.empty():
			continue
		var sample_index: int = _deterministic_index(sector_ids.size(), "%s:sector:%s:%d" % [_seed, str(sector_type), window_tick_count])
		samples[sector_type] = str(sector_ids[sample_index])
	return samples


func _sample_agent_entries(window_tick_count: int, composite_request: Dictionary) -> Array:
	var requested_agent_roles: Array = Array(composite_request.get("agent_roles", []))
	var include_persistent: bool = bool(composite_request.get("include_persistent", true))
	var include_mortal: bool = bool(composite_request.get("include_mortal", true))
	var candidates_by_class_and_role: Dictionary = {}

	for agent_id in _sorted_keys(GameState.agents):
		if str(agent_id) == "player":
			continue
		var agent: Dictionary = GameState.agents.get(agent_id, {})
		if bool(agent.get("is_disabled", false)):
			continue
		var agent_role: String = str(agent.get("agent_role", "idle"))
		if not requested_agent_roles.empty() and not (agent_role in requested_agent_roles):
			continue
		var agent_class: String = "persistent" if bool(agent.get("is_persistent", false)) else "mortal"
		if agent_class == "persistent" and not include_persistent:
			continue
		if agent_class == "mortal" and not include_mortal:
			continue
		var group_key: String = "%s|%s" % [agent_class, agent_role]
		if not candidates_by_class_and_role.has(group_key):
			candidates_by_class_and_role[group_key] = []
		candidates_by_class_and_role[group_key].append(str(agent_id))

	var samples: Array = []
	for group_key in _sorted_keys(candidates_by_class_and_role):
		var agent_ids: Array = Array(candidates_by_class_and_role[group_key])
		agent_ids.sort()
		if agent_ids.empty():
			continue
		var parts: Array = str(group_key).split("|")
		var sample_index: int = _deterministic_index(agent_ids.size(), "%s:agent:%s:%d" % [_seed, str(group_key), window_tick_count])
		samples.append({
			"agent_id": str(agent_ids[sample_index]),
			"agent_class": str(parts[0]),
			"agent_role": str(parts[1]),
		})
	return samples


func _deterministic_index(size: int, key: String) -> int:
	if size <= 1:
		return 0
	var hashed_value: int = int(hash(key))
	if hashed_value < 0:
		hashed_value = -hashed_value
	return hashed_value % size


# =============================================================================
# === EPOCH NARRATIVE =========================================================
# =============================================================================

func _collect_epoch_events(events: Array, start: int, end: int) -> Array:
	var result: Array = []
	for e in events:
		var t: int = int(e.get("tick", 0))
		if t > start and t <= end:
			result.append(e)
	return result


func _epoch_summary(epoch_events: Array) -> Array:
	var current_snap: Dictionary = _take_sector_snapshot()
	var changed_sectors: Array = _detect_sector_changes(_prev_sector_snap, current_snap)
	var focused_changes: Array = []
	if str(_report_request.get("focus_mode", "world")) == "sector":
		focused_changes = _detect_sector_changes(
			_prev_sector_snap,
			current_snap,
			str(_report_request.get("focus_id", ""))
		)
	_prev_sector_snap = current_snap

	var filtered_events: Array = _filter_report_events(epoch_events)
	match str(_report_request.get("focus_mode", "world")):
		"sector":
			return _sector_epoch_summary(filtered_events, current_snap, focused_changes)
		"agent":
			return _agent_epoch_summary(filtered_events)
		_:
			return _world_epoch_summary(filtered_events, changed_sectors)


func _world_epoch_summary(epoch_events: Array, changed_sectors: Array) -> Array:
	var lines: Array = []

	# Count actions
	var counts: Dictionary = {}
	var attack_sectors: Dictionary = {}
	var attacker_counts: Dictionary = {}
	var trade_sectors: Dictionary = {}
	var cargo_loads: int = 0
	var harvest_count: int = 0
	var flee_count: int = 0
	var spawn_entries: Array = []  # [actor, sector]
	var catastrophe_sectors: Array = []
	var age_changes: Array = []
	var discovered_sectors: Array = []

	for e in epoch_events:
		var action: String = str(e.get("action", ""))
		counts[action] = counts.get(action, 0) + 1
		var actor: String = str(e.get("actor_id", ""))
		var sector: String = str(e.get("sector_id", ""))

		match action:
			"attack":
				attacker_counts[actor] = attacker_counts.get(actor, 0) + 1
				attack_sectors[sector] = attack_sectors.get(sector, 0) + 1
			"agent_trade":
				trade_sectors[sector] = trade_sectors.get(sector, 0) + 1
			"flee":
				flee_count += 1
			"spawn":
				spawn_entries.append([actor, sector])
			"catastrophe":
				catastrophe_sectors.append(sector)
			"age_change":
				var meta: Dictionary = e.get("metadata", {})
				age_changes.append(str(meta.get("new_age", "")))
			"load_cargo":
				cargo_loads += 1
			"harvest":
				harvest_count += 1
			"sector_discovered":
				var meta: Dictionary = e.get("metadata", {})
				discovered_sectors.append({
					"actor": actor,
					"name": str(meta.get("name", "unknown")),
					"new_sector": str(meta.get("new_sector", "")),
					"from": sector,
					"connections": meta.get("connections", []),
				})

	var respawn_count: int = counts.get("respawn", 0)
	var survived_count: int = counts.get("survived", 0)
	var perma_deaths: int = counts.get("perma_death", 0)

	# ---- World age changes ----
	for new_age in age_changes:
		var flavor: Dictionary = {
			"PROSPERITY": "A new age of Prosperity dawned across the sector.",
			"DISRUPTION": "The age of Disruption began. Instability spread.",
			"RECOVERY": "Recovery took hold. Communities began rebuilding.",
		}
		lines.append("  >>> %s" % flavor.get(new_age, "The world entered %s." % new_age))
		lines.append("")

	# ---- Catastrophes ----
	var unique_cat: Dictionary = {}
	for csec in catastrophe_sectors:
		unique_cat[csec] = true
	for csec in unique_cat:
		lines.append("  *** CATASTROPHE struck %s! ***" % _loc(csec))
	if not unique_cat.empty():
		lines.append("")

	# ---- Sector changes ----
	if not changed_sectors.empty():
		for entry in changed_sectors:
			lines.append("  %s: %s." % [entry[0], entry[1]])
		lines.append("")

	# ---- Combat ----
	var total_attacks: int = counts.get("attack", 0)
	if total_attacks > 0:
		var hotspot: String = _dict_max_key(attack_sectors)
		var hotspot_n: int = attack_sectors.get(hotspot, 0)
		var combat_line: String = "  Combat: %d engagements" % total_attacks
		if hotspot != "":
			combat_line += ", fiercest around %s (%d)" % [_loc(hotspot), hotspot_n]
		combat_line += "."
		lines.append(combat_line)

	# ---- Commerce ----
	var total_trades: int = counts.get("agent_trade", 0)
	if total_trades > 0 or cargo_loads > 0:
		var econ_parts: Array = []
		if total_trades > 0:
			var top_trade: String = _dict_max_key(trade_sectors)
			var trade_str: String = "%d trades" % total_trades
			if top_trade != "":
				trade_str += " (busiest: %s)" % _loc(top_trade)
			econ_parts.append(trade_str)
		if cargo_loads > 0:
			econ_parts.append("%d cargo runs loaded" % cargo_loads)
		if harvest_count > 0:
			econ_parts.append("%d salvage operations" % harvest_count)
		lines.append("  Commerce: %s." % PoolStringArray(econ_parts).join(", "))

	# ---- Danger ----
	if flee_count >= 3:
		lines.append("  Danger: %d pilots fled dangerous encounters." % flee_count)

	# ---- Losses ----
	var loss_parts: Array = []
	if respawn_count > 0:
		loss_parts.append("%d pilots respawned after prior destruction" % respawn_count)
	if survived_count > 0:
		loss_parts.append("%d mortals narrowly survived destruction" % survived_count)
	if perma_deaths > 0:
		loss_parts.append("%d were lost permanently" % perma_deaths)
	if not loss_parts.empty():
		lines.append("  Losses & returns: %s." % PoolStringArray(loss_parts).join("; "))

	# ---- Spawns ----
	if not spawn_entries.empty():
		var sector_spawns: Dictionary = {}
		for entry in spawn_entries:
			var aid: String = entry[0]
			var sec: String = entry[1]
			if not sector_spawns.has(sec):
				sector_spawns[sec] = []
			sector_spawns[sec].append(aid)
		for sec in sector_spawns:
			var names: Array = []
			for aid in sector_spawns[sec]:
				names.append(_agent_display(aid))
			if names.size() <= 3:
				lines.append("  New arrivals at %s: %s." % [
					_loc(sec), PoolStringArray(names).join(", ")])
			else:
				lines.append("  %d new pilots appeared at %s." % [names.size(), _loc(sec)])

	# ---- Discoveries ----
	for disc in discovered_sectors:
		var conn_names: Array = []
		for c in disc.get("connections", []):
			conn_names.append(_loc(str(c)))
		lines.append("  ** NEW SECTOR DISCOVERED: %s (linked to %s) by %s **" % [
			disc["name"],
			PoolStringArray(conn_names).join(", ") if not conn_names.empty() else "unknown",
			_agent_display(disc["actor"]),
		])

	# ---- Quiet period ----
	if lines.empty() and total_attacks == 0 and total_trades == 0:
		lines.append("  A quiet period. Routine patrols continued without incident.")

	return lines


func _sector_epoch_summary(epoch_events: Array, current_snap: Dictionary, sector_changes: Array) -> Array:
	var lines: Array = []
	var focus_sector_id: String = str(_report_request.get("focus_id", ""))
	var focus_label: String = _sector_label_with_id(focus_sector_id)
	var action_totals: Dictionary = _count_actions(epoch_events)

	for entry in sector_changes:
		lines.append("  %s: %s." % [entry[0], entry[1]])

	if epoch_events.empty():
		lines.append("  Sector focus: %s had no relevant events this epoch." % focus_label)
	else:
		lines.append("  Sector focus: %s logged %d relevant events." % [focus_label, epoch_events.size()])
		var action_parts: Array = _format_action_totals(action_totals)
		if not action_parts.empty():
			lines.append("  Action totals: %s." % PoolStringArray(action_parts).join(", "))
		var actor_counts: Dictionary = _collect_actor_counts(epoch_events)
		if not actor_counts.empty():
			lines.append("  Active actors: %s." % _format_count_entries(actor_counts, "agent"))

	if current_snap.has(focus_sector_id):
		var snap: Dictionary = current_snap.get(focus_sector_id, {})
		lines.append("  Current sector state: %s economy, %s security, %s environment [%s]." % [
			str(snap.get("economy", "adequate")),
			str(snap.get("security", "contested")),
			str(snap.get("environment", "mild")),
			str(snap.get("colony", "frontier")),
		])
		var connections: Array = Array(GameState.world_topology.get(focus_sector_id, {}).get("connections", []))
		if not connections.empty():
			var connection_labels: Array = []
			for connection_id in connections:
				connection_labels.append(_sector_label_with_id(str(connection_id)))
			lines.append("  Connected sectors: %s." % PoolStringArray(connection_labels).join(", "))
	else:
		lines.append("  Current sector state: unavailable for %s." % focus_label)

	return lines


func _agent_epoch_summary(epoch_events: Array) -> Array:
	var lines: Array = []
	var focus_agent_id: String = str(_report_request.get("focus_id", ""))
	var focus_label: String = _actor_label_with_id(focus_agent_id)
	var action_totals: Dictionary = _count_actions(epoch_events)

	if epoch_events.empty():
		lines.append("  Agent focus: %s had no relevant events this epoch." % focus_label)
	else:
		lines.append("  Agent focus: %s logged %d relevant events." % [focus_label, epoch_events.size()])
		var action_parts: Array = _format_action_totals(action_totals)
		if not action_parts.empty():
			lines.append("  Action totals: %s." % PoolStringArray(action_parts).join(", "))
		var sector_counts: Dictionary = _collect_sector_counts(epoch_events)
		if not sector_counts.empty():
			lines.append("  Sector trail: %s." % _format_count_entries(sector_counts, "sector"))

	var agent: Dictionary = GameState.agents.get(focus_agent_id, {})
	if agent.empty():
		lines.append("  Current agent state: unavailable for %s." % focus_label)
	else:
		var credits: int = 0
		var character_uid = -1
		if agent.has("character_uid") and agent["character_uid"] != null:
			character_uid = int(agent["character_uid"])
		elif GameState.persistent_agents.has(focus_agent_id):
			var p_agent = GameState.persistent_agents[focus_agent_id]
			if p_agent != null and p_agent.has("character_uid") and p_agent["character_uid"] != null:
				character_uid = int(p_agent["character_uid"])
		
		if character_uid != -1 and is_instance_valid(GlobalRefs.character_system):
			credits = int(GlobalRefs.character_system.get_credits(character_uid))

		lines.append("  Current agent state: sector=%s cond=%s wealth=%s (%d cr) cargo=%s goal=%s." % [
			_sector_label_with_id(str(agent.get("current_sector_id", ""))),
			str(agent.get("condition_tag", "?")),
			str(agent.get("wealth_tag", "?")),
			credits,
			str(agent.get("cargo_tag", "?")),
			str(agent.get("goal_archetype", "none")),
		])

	return lines


func _epoch_detailed_log(epoch_events: Array) -> Array:
	if str(_report_request.get("detail_level", "standard")) == "summary":
		return []

	var lines: Array = []
	var filtered_events: Array = _filter_report_events(epoch_events)
	var sort_mode: String = str(_report_request.get("sort_mode", "chronological"))
	lines.append("  Detailed event log (%s order):" % sort_mode)

	if filtered_events.empty():
		lines.append("    (no relevant events)")
		return lines

	var ordered_events: Array = filtered_events.duplicate(true)
	ordered_events.sort_custom(self, "_sort_events_by_request")
	for event in ordered_events:
		lines.append("    %s" % _format_detailed_event(event))

	return lines


func _filter_report_events(events: Array) -> Array:
	var filtered: Array = []
	for event in events:
		if _event_matches_report_request(event):
			filtered.append(event)
	return filtered


func _event_matches_report_request(event: Dictionary) -> bool:
	var focus_mode: String = str(_report_request.get("focus_mode", "world"))
	if focus_mode == "world":
		return true
	var focus_id: String = str(_report_request.get("focus_id", ""))
	if focus_id == "":
		return true
	if focus_mode == "sector":
		return _event_references_sector(event, focus_id)
	if focus_mode == "agent":
		return _event_references_agent(event, focus_id)
	return true


func _event_references_sector(event: Dictionary, sector_id: String) -> bool:
	if str(event.get("sector_id", "")) == sector_id:
		return true
	var metadata: Dictionary = event.get("metadata", {})
	for key in ["from", "target_sector_id", "source_sector_id", "requested_from", "new_sector"]:
		if str(metadata.get(key, "")) == sector_id:
			return true
	var connections: Array = Array(metadata.get("connections", []))
	for connection_id in connections:
		if str(connection_id) == sector_id:
			return true
	return false


func _event_references_agent(event: Dictionary, agent_id: String) -> bool:
	if str(event.get("actor_id", "")) == agent_id:
		return true
	var metadata: Dictionary = event.get("metadata", {})
	for key in ["target", "claimant_agent_id"]:
		if str(metadata.get(key, "")) == agent_id:
			return true
	return false


func _count_actions(events: Array) -> Dictionary:
	var counts: Dictionary = {}
	for event in events:
		var action: String = str(event.get("action", ""))
		counts[action] = int(counts.get(action, 0)) + 1
	return counts


func _collect_actor_counts(events: Array) -> Dictionary:
	var counts: Dictionary = {}
	for event in events:
		var actor_id: String = str(event.get("actor_id", ""))
		if actor_id == "":
			continue
		counts[actor_id] = int(counts.get(actor_id, 0)) + 1
	return counts


func _collect_sector_counts(events: Array) -> Dictionary:
	var counts: Dictionary = {}
	for event in events:
		var sector_id: String = str(event.get("sector_id", ""))
		if sector_id == "":
			continue
		counts[sector_id] = int(counts.get(sector_id, 0)) + 1
	return counts


func _format_action_totals(action_totals: Dictionary) -> Array:
	var parts: Array = []
	for action in _sorted_keys(action_totals):
		parts.append("%s=%d" % [action, int(action_totals[action])])
	return parts


func _format_count_entries(counts: Dictionary, mode: String) -> String:
	var parts: Array = []
	for key in _sorted_keys(counts):
		var label: String = str(key)
		if mode == "agent":
			label = _actor_label_with_id(str(key))
		elif mode == "sector":
			label = _sector_label_with_id(str(key))
		parts.append("%s=%d" % [label, int(counts[key])])
	return PoolStringArray(parts).join(", ")


func _format_detailed_event(event: Dictionary) -> String:
	var tick: int = int(event.get("tick", 0))
	var actor_id: String = str(event.get("actor_id", ""))
	var sector_id: String = str(event.get("sector_id", ""))
	var action: String = str(event.get("action", "unknown"))
	var base_line: String = "T%s [%s] %s %s" % [
		_pad_int(tick, 4),
		_sector_label_with_id(sector_id),
		_actor_label_with_id(actor_id),
		_humanize_action(action),
	]

	var metadata: Dictionary = event.get("metadata", {})
	if metadata.empty():
		return base_line

	var detail_level: String = str(_report_request.get("detail_level", "standard"))
	var max_items: int = 3
	if detail_level == "verbose":
		max_items = -1
	var metadata_text: String = _format_metadata(metadata, max_items)
	if metadata_text == "":
		return base_line
	return "%s | %s" % [base_line, metadata_text]


func _format_metadata(metadata: Dictionary, max_items: int) -> String:
	var keys: Array = _sorted_keys(metadata)
	if keys.empty():
		return ""

	var parts: Array = []
	var item_count: int = 0
	for key in keys:
		if max_items >= 0 and item_count >= max_items:
			break
		parts.append("%s=%s" % [key, _format_metadata_value(str(key), metadata[key])])
		item_count += 1

	if max_items >= 0 and keys.size() > max_items:
		parts.append("+%d more" % (keys.size() - max_items))

	return PoolStringArray(parts).join("; ")


func _format_metadata_value(key: String, value) -> String:
	if key in ["from", "target_sector_id", "source_sector_id", "requested_from", "new_sector"]:
		return _sector_label_with_id(str(value))
	if key in ["target", "claimant_agent_id"]:
		return _actor_label_with_id(str(value))
	if value is Array:
		var values: Array = []
		for item in value:
			if key == "connections":
				values.append(_sector_label_with_id(str(item)))
			else:
				values.append(str(item))
		return "[%s]" % PoolStringArray(values).join(", ")
	return str(value)


func _sort_events_by_request(a: Dictionary, b: Dictionary) -> bool:
	return _event_sort_key(a) < _event_sort_key(b)


func _event_sort_key(event: Dictionary) -> String:
	var tick_key: String = _pad_int(int(event.get("tick", 0)), 8)
	var sector_key: String = _sector_label_with_id(str(event.get("sector_id", ""))).to_lower()
	var actor_key: String = _actor_label_with_id(str(event.get("actor_id", ""))).to_lower()
	var action_key: String = str(event.get("action", "")).to_lower()
	match str(_report_request.get("sort_mode", "chronological")):
		"sector":
			return "%s|%s|%s|%s" % [sector_key, tick_key, actor_key, action_key]
		"agent":
			return "%s|%s|%s|%s" % [actor_key, tick_key, sector_key, action_key]
		_:
			return "%s|%s|%s|%s" % [tick_key, sector_key, actor_key, action_key]


func _pad_int(value: int, width: int) -> String:
	var text: String = str(value)
	while text.length() < width:
		text = "0" + text
	return text


# =============================================================================
# === OVERALL SUMMARY =========================================================
# =============================================================================

func _summary() -> Array:
	if str(_report_request.get("focus_mode", "world")) != "world":
		return _focused_summary()
	return _world_summary()


func _world_summary() -> Array:
	var lines: Array = []

	# Count action totals
	var action_totals: Dictionary = {}
	for e in _all_events:
		var a: String = str(e.get("action", ""))
		action_totals[a] = action_totals.get(a, 0) + 1

	var total_attacks: int = action_totals.get("attack", 0)
	var total_trades: int = action_totals.get("agent_trade", 0)
	var total_spawns: int = action_totals.get("spawn", 0)
	var total_respawns: int = action_totals.get("respawn", 0)
	var total_perma_deaths: int = action_totals.get("perma_death", 0)
	var total_catastrophes: int = action_totals.get("catastrophe", 0)
	var age_changes: int = action_totals.get("age_change", 0)
	var total_discoveries: int = action_totals.get("sector_discovered", 0)

	lines.append("================================================================")
	lines.append("OVERALL SUMMARY")
	lines.append("================================================================")
	lines.append("  Simulation ran for %d ticks (%d world-age transitions)." % [
		_total_ticks, age_changes])
	lines.append("  Total engagements: %d  |  Total trades: %d" % [
		total_attacks, total_trades])
	lines.append("  Newcomers arrived: %d  |  Pilots respawned: %d" % [
		total_spawns, total_respawns])
	if total_perma_deaths > 0:
		lines.append("  Permanently lost: %d" % total_perma_deaths)
	if total_catastrophes > 0:
		lines.append("  Catastrophes endured: %d" % total_catastrophes)
	if total_discoveries > 0:
		lines.append("  New sectors discovered: %d  |  Total sectors: %d" % [
			total_discoveries, GameState.sector_tags.size()])

	# ---- Final sector state ----
	lines.append("")
	lines.append("  Final state of the sector:")
	for sector_id in _sorted_keys(GameState.sector_tags):
		var tags: Array = GameState.sector_tags.get(sector_id, [])
		lines.append("    %s: %s economy, %s, %s environment [%s]" % [
			_loc(sector_id),
			_economy_label(tags),
			_security_label(tags),
			_environment_label(tags),
			GameState.colony_levels.get(sector_id, "frontier"),
		])

	# ---- Topology map ----
	lines.append("")
	lines.append("  Sector connections:")
	for sector_id in _sorted_keys(GameState.sector_tags):
		var conns: Array = GameState.world_topology.get(sector_id, {}).get("connections", [])
		var conn_names: Array = []
		for c in conns:
			conn_names.append(_loc(str(c)))
		var conn_str: String = PoolStringArray(conn_names).join(", ") if not conn_names.empty() else "(isolated)"
		lines.append("    %s <-> %s" % [_loc(sector_id), conn_str])

	# Topology metrics
	var degree_values: Array = []
	for sector_id in GameState.sector_tags:
		var d: int = GameState.world_topology.get(sector_id, {}).get("connections", []).size()
		degree_values.append(d)
	if not degree_values.empty():
		var max_d: int = _array_max(degree_values)
		var avg_d: float = _array_sum(degree_values) / float(degree_values.size())
		var bottlenecks: int = 0
		var d1: int = 0
		var d2: int = 0
		var d3: int = 0
		var d4: int = 0
		for d in degree_values:
			if d <= 2:
				bottlenecks += 1
			if d == 1:
				d1 += 1
			elif d == 2:
				d2 += 1
			elif d == 3:
				d3 += 1
			elif d == 4:
				d4 += 1
		lines.append("  Topology: max_degree=%d avg=%.1f bottlenecks=%d distribution=[d1:%d, d2:%d, d3:%d, d4:%d]" % [
			max_d, avg_d, bottlenecks, d1, d2, d3, d4])

	# ---- Active pilots ----
	lines.append("")
	lines.append("  Active pilots:")
	for agent_id in _sorted_keys(GameState.agents):
		if agent_id == "player":
			continue
		var agent: Dictionary = GameState.agents[agent_id]
		if agent.get("is_disabled", false):
			continue
		var cond: String = str(agent.get("condition_tag", "HEALTHY")).to_lower()
		var wealth: String = str(agent.get("wealth_tag", "COMFORTABLE")).to_lower()
		var sector: String = _loc(str(agent.get("current_sector_id", "")))

		var credits: int = 0
		var character_uid = -1
		if agent.has("character_uid") and agent["character_uid"] != null:
			character_uid = int(agent["character_uid"])
		elif GameState.persistent_agents.has(agent_id):
			var p_agent = GameState.persistent_agents[agent_id]
			if p_agent != null and p_agent.has("character_uid") and p_agent["character_uid"] != null:
				character_uid = int(p_agent["character_uid"])
		
		if character_uid != -1 and is_instance_valid(GlobalRefs.character_system):
			credits = int(GlobalRefs.character_system.get_credits(character_uid))

		lines.append("    %s: %s, %s (%d cr), at %s" % [
			_agent_display(agent_id), cond, wealth, credits, sector])

	return lines


func _focused_summary() -> Array:
	var lines: Array = []
	var focus_mode: String = str(_report_request.get("focus_mode", "world"))
	var focus_id: String = str(_report_request.get("focus_id", ""))
	var relevant_events: Array = _filter_report_events(_all_events)
	var action_totals: Dictionary = _count_actions(relevant_events)

	lines.append("================================================================")
	lines.append("FOCUSED SUMMARY")
	lines.append("================================================================")
	lines.append("  Focus mode: %s  |  focus id: %s" % [focus_mode, focus_id])
	lines.append("  Simulation ran for %d ticks with %d relevant events captured." % [
		_total_ticks,
		relevant_events.size(),
	])
	var action_parts: Array = _format_action_totals(action_totals)
	if not action_parts.empty():
		lines.append("  Action totals: %s" % PoolStringArray(action_parts).join(", "))

	if focus_mode == "sector":
		if GameState.sector_tags.has(focus_id):
			var tags: Array = GameState.sector_tags.get(focus_id, [])
			lines.append("  Final sector state: %s economy, %s, %s environment [%s]" % [
				_economy_label(tags),
				_security_label(tags),
				_environment_label(tags),
				GameState.colony_levels.get(focus_id, "frontier"),
			])
			var connections: Array = Array(GameState.world_topology.get(focus_id, {}).get("connections", []))
			var connection_labels: Array = []
			for connection_id in connections:
				connection_labels.append(_sector_label_with_id(str(connection_id)))
			lines.append("  Connections: %s" % (
				PoolStringArray(connection_labels).join(", ") if not connection_labels.empty() else "(isolated)"
			))
		else:
			lines.append("  Final sector state: unavailable for %s" % _sector_label_with_id(focus_id))
		var actor_counts: Dictionary = _collect_actor_counts(relevant_events)
		if not actor_counts.empty():
			lines.append("  Active actors: %s" % _format_count_entries(actor_counts, "agent"))
	elif focus_mode == "agent":
		var agent: Dictionary = GameState.agents.get(focus_id, {})
		if agent.empty():
			lines.append("  Final agent state: unavailable for %s" % _actor_label_with_id(focus_id))
		else:
			var credits: int = 0
			var character_uid = -1
			if agent.has("character_uid") and agent["character_uid"] != null:
				character_uid = int(agent["character_uid"])
			elif GameState.persistent_agents.has(focus_id):
				var p_agent = GameState.persistent_agents[focus_id]
				if p_agent != null and p_agent.has("character_uid") and p_agent["character_uid"] != null:
					character_uid = int(p_agent["character_uid"])
			
			if character_uid != -1 and is_instance_valid(GlobalRefs.character_system):
				credits = int(GlobalRefs.character_system.get_credits(character_uid))

			lines.append("  Final agent state: sector=%s cond=%s wealth=%s (%d cr) cargo=%s goal=%s" % [
				_sector_label_with_id(str(agent.get("current_sector_id", ""))),
				str(agent.get("condition_tag", "?")),
				str(agent.get("wealth_tag", "?")),
				credits,
				str(agent.get("cargo_tag", "?")),
				str(agent.get("goal_archetype", "none")),
			])
		var sector_counts: Dictionary = _collect_sector_counts(relevant_events)
		if not sector_counts.empty():
			lines.append("  Sector trail: %s" % _format_count_entries(sector_counts, "sector"))

	return lines


# =============================================================================
# === SECTOR SNAPSHOT & CHANGE DETECTION ======================================
# =============================================================================

func _take_sector_snapshot() -> Dictionary:
	var snap: Dictionary = {}
	for sector_id in GameState.sector_tags:
		var tags: Array = GameState.sector_tags.get(sector_id, [])
		snap[sector_id] = {
			"economy": _economy_label(tags),
			"security": _security_label(tags),
			"environment": _environment_label(tags),
			"colony": GameState.colony_levels.get(sector_id, "frontier"),
			"infested": "HOSTILE_INFESTED" in tags,
		}
	return snap


func _detect_sector_changes(prev: Dictionary, cur: Dictionary, focus_sector_id: String = "") -> Array:
	var changes: Array = []
	for sid in cur:
		if focus_sector_id != "" and str(sid) != focus_sector_id:
			continue
		var c: Dictionary = cur[sid]
		var p: Dictionary = prev.get(sid, {})
		var parts: Array = []

		if p.has("economy") and p["economy"] != c["economy"]:
			parts.append("economy shifted from %s to %s" % [p["economy"], c["economy"]])
		if p.has("security") and p["security"] != c["security"]:
			parts.append("security changed from %s to %s" % [p["security"], c["security"]])
		if p.has("environment") and p["environment"] != c["environment"]:
			parts.append("environment went from %s to %s" % [p["environment"], c["environment"]])
		if p.has("colony") and p["colony"] != c["colony"]:
			var levels: Array = ["frontier", "outpost", "colony", "hub"]
			if levels.find(c["colony"]) > levels.find(p["colony"]):
				parts.append("grew from %s to %s" % [p["colony"], c["colony"]])
			else:
				parts.append("declined from %s to %s" % [p["colony"], c["colony"]])
		if not p.get("infested", false) and c.get("infested", false):
			parts.append("became infested with hostiles")
		elif p.get("infested", false) and not c.get("infested", false):
			parts.append("was cleared of hostile infestation")

		if not parts.empty():
			changes.append([_loc(sid), PoolStringArray(parts).join("; ")])
	return changes


# =============================================================================
# === HELPERS — NAME RESOLUTION ===============================================
# =============================================================================

## Resolve sector_id to human-readable name.
func _loc(sector_id: String) -> String:
	if sector_id == "":
		return "deep space"
	# TemplateDatabase
	if TemplateDatabase.locations.has(sector_id):
		var loc: Resource = TemplateDatabase.locations[sector_id]
		if is_instance_valid(loc) and loc.get("location_name") != null:
			return loc.location_name
	# sector_names
	if GameState.sector_names.has(sector_id):
		return GameState.sector_names[sector_id]
	return sector_id


## Display name + role for an agent.
func _agent_display(agent_id: String) -> String:
	var agent: Dictionary = GameState.agents.get(agent_id, {})
	var char_id: String = str(agent.get("character_id", ""))
	var name: String = _resolve_character_name(char_id, agent_id)
	var role: String = str(agent.get("agent_role", ""))
	if role != "":
		return "%s (%s)" % [name, role]
	return name


func _resolve_character_name(char_id: String, fallback: String = "") -> String:
	if char_id == "":
		return fallback if fallback != "" else "(unnamed)"
	if GameState.characters.has(char_id):
		var c = GameState.characters[char_id]
		if c is Resource and c.get("character_name") != null:
			return c.character_name
		elif c is Dictionary and c.has("character_name"):
			return c["character_name"]
	return char_id


func _sector_label_with_id(sector_id: String) -> String:
	if sector_id == "":
		return "deep space"
	var label: String = _loc(sector_id)
	if label == sector_id:
		return sector_id
	return "%s/%s" % [label, sector_id]


func _actor_label_with_id(actor_id: String) -> String:
	if actor_id == "":
		return "unknown"
	var label: String = _agent_display(actor_id)
	if label == actor_id:
		return actor_id
	return "%s/%s" % [label, actor_id]


func _humanize_action(action: String) -> String:
	match action:
		"move":
			return "moved"
		"attack":
			return "attacked"
		"agent_trade":
			return "traded"
		"dock":
			return "docked"
		"harvest":
			return "harvested salvage"
		"load_cargo":
			return "loaded cargo"
		"contract_claimed":
			return "claimed a relief contract"
		"contract_loaded":
			return "loaded relief cargo"
		"contract_completed":
			return "completed a relief delivery"
		"flee":
			return "fled"
		"exploration":
			return "explored"
		"sector_discovered":
			return "discovered a new sector"
		"spawn":
			return "appeared"
		"respawn":
			return "returned"
		"survived":
			return "narrowly survived destruction"
		"perma_death":
			return "was permanently lost"
		"catastrophe":
			return "witnessed catastrophe"
		"catastrophe_death":
			return "was lost in catastrophe"
		"expedition_failed":
			return "failed an expedition"
		"age_change":
			return "reported a world-age shift"
		_:
			return action


# =============================================================================
# === HELPERS — TAG LABELS ====================================================
# =============================================================================

func _economy_label(tags: Array) -> String:
	for level in ["rich", "adequate", "poor"]:
		for t in tags:
			if str(t).to_lower().ends_with("_" + level):
				return level
	return "adequate"


func _security_label(tags: Array) -> String:
	for t in ["SECURE", "CONTESTED", "LAWLESS"]:
		if t in tags:
			return t.to_lower()
	return "contested"


func _environment_label(tags: Array) -> String:
	for t in ["MILD", "HARSH", "EXTREME"]:
		if t in tags:
			return t.to_lower()
	return "mild"


# =============================================================================
# === HELPERS — UTILITY =======================================================
# =============================================================================

## Returns the key with the highest value in a Dictionary.
func _dict_max_key(d: Dictionary) -> String:
	var best_key: String = ""
	var best_val: int = -1
	for k in d:
		if d[k] > best_val:
			best_val = d[k]
			best_key = str(k)
	return best_key


## Sorts dictionary keys as strings.
func _sorted_keys(d: Dictionary) -> Array:
	var keys: Array = []
	for k in d:
		keys.append(str(k))
	keys.sort()
	return keys


func _array_max(arr: Array) -> int:
	var m: int = 0
	for v in arr:
		if int(v) > m:
			m = int(v)
	return m


func _array_sum(arr: Array) -> int:
	var s: int = 0
	for v in arr:
		s += int(v)
	return s
