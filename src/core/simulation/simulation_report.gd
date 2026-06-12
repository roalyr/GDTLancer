#
# PROJECT: GDTLancer
# MODULE: simulation_report.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context
# LOG_REF: 2026-06-12 23:55:00
#

extends Reference

# --- Component Scripts ---
const SamplerClass = preload("res://src/core/simulation/simulation_report/report_sampler.gd")
const SummarizerClass = preload("res://src/core/simulation/simulation_report/report_summarizer.gd")
const FormatterClass = preload("res://src/core/simulation/simulation_report/report_formatter.gd")

# --- State ---
var _lines: Array = []
var _prev_sector_snap: Dictionary = {}
var _all_events: Array = []
var _total_ticks: int = 0
var _seed: String = ""
var _report_request: Dictionary = {}

# --- Delegates ---
var sampler: Reference = null
var summarizer: Reference = null
var formatter: Reference = null


# --- Initialization ---
func _init():
	formatter = FormatterClass.new()
	formatter.initialize(self)

	sampler = SamplerClass.new()
	sampler.initialize(self)

	summarizer = SummarizerClass.new()
	summarizer.initialize(self)


# =============================================================================
# === CONVENIENCE: ONE-SHOT RUN ===============================================
# =============================================================================

func run_and_report(engine, tick_count: int, epoch_size: int = 1, report_request: Dictionary = {}) -> String:
	_lines.clear()
	_all_events.clear()
	_prev_sector_snap.clear()
	_total_ticks = tick_count
	_seed = GameState.world_seed
	_report_request = _normalize_report_request(report_request)

	var seen_event_refs: Dictionary = {}
	var all_new_events: Array = []

	for e in GameState.chronicle_events:
		seen_event_refs[e] = true

	_prev_sector_snap = _take_sector_snapshot()

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

		for e in GameState.chronicle_events:
			if not seen_event_refs.has(e):
				seen_event_refs[e] = true
				all_new_events.append(e)

		var current_tick: int = GameState.sim_tick_count
		if ticks_in_epoch >= epoch_size or _i == tick_count - 1:
			var epoch_end: int = current_tick
			epoch_num += 1

			var epoch_events: Array = _collect_epoch_events(all_new_events, epoch_start, epoch_end)
			_all_events.append_array(epoch_events)

			var age: String = GameState.world_age
			_lines.append("--- Epoch %d: ticks %d-%d [%s] ---" % [
				epoch_num, epoch_start + 1, epoch_end, age
			])

			var epoch_summary_lines: Array = _epoch_summary(epoch_events)
			if not epoch_summary_lines.empty():
				_lines.append_array(epoch_summary_lines)
			var detailed_log: Array = _epoch_detailed_log(epoch_events)
			if not detailed_log.empty():
				_lines.append_array(detailed_log)
			_lines.append("")

			epoch_start = epoch_end
			ticks_in_epoch = 0

	_lines.append_array(_summary())

	return PoolStringArray(_lines).join("\n")


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
			lines.append("  Sector type sample [%s]: %s" % [str(sector_type), formatter.sector_label_with_id(sector_id)])
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
				formatter.actor_label_with_id(agent_id),
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


# =============================================================================
# === DELEGATION WRAPPERS =====================================================
# =============================================================================

func _epoch_summary(epoch_events: Array) -> Array:
	if summarizer:
		return summarizer.epoch_summary(epoch_events)
	return []


func _world_epoch_summary(epoch_events: Array, changed_sectors: Array) -> Array:
	if summarizer:
		return summarizer.world_epoch_summary(epoch_events, changed_sectors)
	return []


func _sector_epoch_summary(epoch_events: Array, current_snap: Dictionary, sector_changes: Array) -> Array:
	if summarizer:
		return summarizer.sector_epoch_summary(epoch_events, current_snap, sector_changes)
	return []


func _agent_epoch_summary(epoch_events: Array) -> Array:
	if summarizer:
		return summarizer.agent_epoch_summary(epoch_events)
	return []


func _epoch_detailed_log(epoch_events: Array) -> Array:
	if summarizer:
		return summarizer.epoch_detailed_log(epoch_events)
	return []


func _summary() -> Array:
	if summarizer:
		return summarizer.summary()
	return []


func _world_summary() -> Array:
	if summarizer:
		return summarizer.world_summary()
	return []


func _focused_summary() -> Array:
	if summarizer:
		return summarizer.focused_summary()
	return []


func _take_sector_snapshot() -> Dictionary:
	if summarizer:
		return summarizer.take_sector_snapshot()
	return {}


func _detect_sector_changes(prev: Dictionary, cur: Dictionary, focus_sector_id: String = "") -> Array:
	if summarizer:
		return summarizer.detect_sector_changes(prev, cur, focus_sector_id)
	return []


func _sample_sector_ids_by_type(window_tick_count: int, composite_request: Dictionary) -> Dictionary:
	if sampler:
		return sampler.sample_sector_ids_by_type(window_tick_count, composite_request)
	return {}


func _sample_agent_entries(window_tick_count: int, composite_request: Dictionary) -> Array:
	if sampler:
		return sampler.sample_agent_entries(window_tick_count, composite_request)
	return []


func _deterministic_index(size: int, key: String) -> int:
	if sampler:
		return sampler.deterministic_index(size, key)
	return 0


func _loc(sector_id: String) -> String:
	if formatter:
		return formatter.loc(sector_id)
	return sector_id


func _agent_display(agent_id: String) -> String:
	if formatter:
		return formatter.agent_display(agent_id)
	return agent_id


func _resolve_character_name(char_id: String, fallback: String = "") -> String:
	if formatter:
		return formatter.resolve_character_name(char_id, fallback)
	return char_id


func _sector_label_with_id(sector_id: String) -> String:
	if formatter:
		return formatter.sector_label_with_id(sector_id)
	return sector_id


func _actor_label_with_id(actor_id: String) -> String:
	if formatter:
		return formatter.actor_label_with_id(actor_id)
	return actor_id


func _humanize_action(action: String) -> String:
	if formatter:
		return formatter.humanize_action(action)
	return action


# =============================================================================
# === COMMON HELPERS — INTERNAL DATA UTILITIES ================================
# =============================================================================

func _collect_epoch_events(events: Array, start: int, end: int) -> Array:
	var result: Array = []
	for e in events:
		var t: int = int(e.get("tick", 0))
		if t > start and t <= end:
			result.append(e)
	return result


func _filter_report_events(events: Array) -> Array:
	var filtered: Array = []
	for event in events:
		if _event_matches_report_request(event):
			filtered.append(event)
	return filtered


func _event_matches_report_request(event: Dictionary) -> bool:
	var focus_mode: String = str(_report_request.get("focus_mode", "world"))
	var focus_id: String = str(_report_request.get("focus_id", ""))
	match focus_mode:
		"sector":
			return _event_references_sector(event, focus_id)
		"agent":
			return _event_references_agent(event, focus_id)
		_:
			return true


func _event_references_sector(event: Dictionary, sector_id: String) -> bool:
	if str(event.get("sector_id", "")) == sector_id:
		return true
	var metadata: Dictionary = event.get("metadata", {})
	if str(metadata.get("from", "")) == sector_id or str(metadata.get("new_sector", "")) == sector_id:
		return true
	if str(metadata.get("target_sector_id", "")) == sector_id or str(metadata.get("source_sector_id", "")) == sector_id:
		return true
	return false


func _event_references_agent(event: Dictionary, agent_id: String) -> bool:
	if str(event.get("actor_id", "")) == agent_id:
		return true
	var metadata: Dictionary = event.get("metadata", {})
	if str(metadata.get("target", "")) == agent_id:
		return true
	return false


func _count_actions(events: Array) -> Dictionary:
	var counts: Dictionary = {}
	for e in events:
		var a: String = str(e.get("action", ""))
		counts[a] = counts.get(a, 0) + 1
	return counts


func _collect_actor_counts(events: Array) -> Dictionary:
	var counts: Dictionary = {}
	for e in events:
		var actor: String = str(e.get("actor_id", ""))
		if actor != "":
			counts[actor] = counts.get(actor, 0) + 1
	return counts


func _collect_sector_counts(events: Array) -> Dictionary:
	var counts: Dictionary = {}
	for e in events:
		var sector: String = str(e.get("sector_id", ""))
		if sector != "":
			counts[sector] = counts.get(sector, 0) + 1
	return counts


func _dict_max_key(d: Dictionary) -> String:
	var best_key: String = ""
	var best_val: int = -1
	for k in d:
		if d[k] > best_val:
			best_val = d[k]
			best_key = str(k)
	return best_key


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
