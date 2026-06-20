# PROJECT: GDTLancer
# MODULE: report_summarizer.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: report_summarizer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: 1-GDD-Core-Mechanics.md § 6.1
# LOG_REF: 2026-06-14 01:00:09
#

extends Reference

var _report: Reference
var _formatter: Reference

func initialize(report_ref: Reference) -> void:
	_report = report_ref
	_formatter = report_ref.formatter


func epoch_summary(epoch_events: Array) -> Array:
	var current_snap: Dictionary = take_sector_snapshot()
	var changed_sectors: Array = detect_sector_changes(_report._prev_sector_snap, current_snap)
	var focused_changes: Array = []
	if str(_report._report_request.get("focus_mode", "world")) == "sector":
		focused_changes = detect_sector_changes(
			_report._prev_sector_snap,
			current_snap,
			str(_report._report_request.get("focus_id", ""))
		)
	_report._prev_sector_snap = current_snap

	var filtered_events: Array = _report._filter_report_events(epoch_events)
	match str(_report._report_request.get("focus_mode", "world")):
		"sector":
			return sector_epoch_summary(filtered_events, current_snap, focused_changes)
		"agent":
			return agent_epoch_summary(filtered_events)
		_:
			return world_epoch_summary(filtered_events, changed_sectors)


func world_epoch_summary(epoch_events: Array, changed_sectors: Array) -> Array:
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
		lines.append("  *** CATASTROPHE struck %s! ***" % _formatter.loc(csec))
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
		var hotspot: String = _report._dict_max_key(attack_sectors)
		var hotspot_n: int = attack_sectors.get(hotspot, 0)
		var combat_line: String = "  Combat: %d engagements" % total_attacks
		if hotspot != "":
			combat_line += ", fiercest around %s (%d)" % [_formatter.loc(hotspot), hotspot_n]
		combat_line += "."
		lines.append(combat_line)

	# ---- Commerce ----
	var total_trades: int = counts.get("agent_trade", 0)
	if total_trades > 0 or cargo_loads > 0:
		var econ_parts: Array = []
		if total_trades > 0:
			var top_trade: String = _report._dict_max_key(trade_sectors)
			var trade_str: String = "%d trades" % total_trades
			if top_trade != "":
				trade_str += " (busiest: %s)" % _formatter.loc(top_trade)
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
				names.append(_formatter.agent_display(aid))
			if names.size() <= 3:
				lines.append("  New arrivals at %s: %s." % [
					_formatter.loc(sec), PoolStringArray(names).join(", ")])
			else:
				lines.append("  %d new pilots appeared at %s." % [names.size(), _formatter.loc(sec)])

	# ---- Discoveries ----
	for disc in discovered_sectors:
		var conn_names: Array = []
		for c in disc.get("connections", []):
			conn_names.append(_formatter.loc(str(c)))
		lines.append("  ** NEW SECTOR DISCOVERED: %s (linked to %s) by %s **" % [
			disc["name"],
			PoolStringArray(conn_names).join(", ") if not conn_names.empty() else "unknown",
			_formatter.agent_display(disc["actor"]),
		])

	# ---- Quiet period ----
	if lines.empty() and total_attacks == 0 and total_trades == 0:
		lines.append("  A quiet period. Routine patrols continued without incident.")

	return lines


func sector_epoch_summary(epoch_events: Array, current_snap: Dictionary, sector_changes: Array) -> Array:
	var lines: Array = []
	var focus_sector_id: String = str(_report._report_request.get("focus_id", ""))
	var focus_label: String = _formatter.sector_label_with_id(focus_sector_id)
	var action_totals: Dictionary = _report._count_actions(epoch_events)

	for entry in sector_changes:
		lines.append("  %s: %s." % [entry[0], entry[1]])

	if epoch_events.empty():
		lines.append("  Sector focus: %s had no relevant events this epoch." % focus_label)
	else:
		lines.append("  Sector focus: %s logged %d relevant events." % [focus_label, epoch_events.size()])
		var action_parts: Array = _formatter.format_action_totals(action_totals)
		if not action_parts.empty():
			lines.append("  Action totals: %s." % PoolStringArray(action_parts).join(", "))
		var actor_counts: Dictionary = _report._collect_actor_counts(epoch_events)
		if not actor_counts.empty():
			lines.append("  Active actors: %s." % _formatter.format_count_entries(actor_counts, "agent"))

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
				connection_labels.append(_formatter.sector_label_with_id(str(connection_id)))
			lines.append("  Connected sectors: %s." % PoolStringArray(connection_labels).join(", "))
	else:
		lines.append("  Current sector state: unavailable for %s." % focus_label)

	return lines


func agent_epoch_summary(epoch_events: Array) -> Array:
	var lines: Array = []
	var focus_agent_id: String = str(_report._report_request.get("focus_id", ""))
	var focus_label: String = _formatter.actor_label_with_id(focus_agent_id)
	var action_totals: Dictionary = _report._count_actions(epoch_events)

	if epoch_events.empty():
		lines.append("  Agent focus: %s had no relevant events this epoch." % focus_label)
	else:
		lines.append("  Agent focus: %s logged %d relevant events." % [focus_label, epoch_events.size()])
		var action_parts: Array = _formatter.format_action_totals(action_totals)
		if not action_parts.empty():
			lines.append("  Action totals: %s." % PoolStringArray(action_parts).join(", "))
		var sector_counts: Dictionary = _report._collect_sector_counts(epoch_events)
		if not sector_counts.empty():
			lines.append("  Sector trail: %s." % _formatter.format_count_entries(sector_counts, "sector"))

	var agent: Dictionary = GameState.agents.get(focus_agent_id, {})
	if agent.empty():
		lines.append("  Current agent state: unavailable for %s." % focus_label)
	else:
		var wealth_display: String = _format_agent_wealth(focus_agent_id, agent, false)

		lines.append("  Current agent state: sector=%s cond=%s wealth=%s cargo=%s goal=%s." % [
			_formatter.sector_label_with_id(str(agent.get("current_sector_id", ""))),
			str(agent.get("condition_tag", "?")),
			wealth_display,
			str(agent.get("cargo_tag", "?")),
			str(agent.get("goal_archetype", "none")),
		])

	return lines


func epoch_detailed_log(epoch_events: Array) -> Array:
	if str(_report._report_request.get("detail_level", "standard")) == "summary":
		return []

	var lines: Array = []
	var filtered_events: Array = _report._filter_report_events(epoch_events)
	var sort_mode: String = str(_report._report_request.get("sort_mode", "chronological"))
	lines.append("  Detailed event log (%s order):" % sort_mode)

	if filtered_events.empty():
		lines.append("    (no relevant events)")
		return lines

	var ordered_events: Array = filtered_events.duplicate(true)
	# Custom sorting calls back to formatter's helper
	ordered_events.sort_custom(_formatter, "sort_events_by_request")
	for event in ordered_events:
		lines.append("    %s" % _formatter.format_detailed_event(event))

	return lines


func summary() -> Array:
	if str(_report._report_request.get("focus_mode", "world")) != "world":
		return focused_summary()
	return world_summary()


func world_summary() -> Array:
	var lines: Array = []

	# Count action totals
	var action_totals: Dictionary = {}
	for e in _report._all_events:
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
		_report._total_ticks, age_changes])
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
	for sector_id in _report._sorted_keys(GameState.sector_tags):
		var tags: Array = GameState.sector_tags.get(sector_id, [])
		lines.append("    %s: %s economy, %s, %s environment [%s]" % [
			_formatter.loc(sector_id),
			_formatter.economy_label(tags),
			_formatter.security_label(tags),
			_formatter.environment_label(tags),
			GameState.colony_levels.get(sector_id, "frontier"),
		])

	# ---- Topology map ----
	lines.append("")
	lines.append("  Sector connections:")
	for sector_id in _report._sorted_keys(GameState.sector_tags):
		var conns: Array = GameState.world_topology.get(sector_id, {}).get("connections", [])
		var conn_names: Array = []
		for c in conns:
			conn_names.append(_formatter.loc(str(c)))
		var conn_str: String = PoolStringArray(conn_names).join(", ") if not conn_names.empty() else "(isolated)"
		lines.append("    %s <-> %s" % [_formatter.loc(sector_id), conn_str])

	# Topology metrics
	var degree_values: Array = []
	for sector_id in GameState.sector_tags:
		var d: int = GameState.world_topology.get(sector_id, {}).get("connections", []).size()
		degree_values.append(d)
	if not degree_values.empty():
		var max_d: int = _report._array_max(degree_values)
		var avg_d: float = _report._array_sum(degree_values) / float(degree_values.size())
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
	for agent_id in _report._sorted_keys(GameState.agents):
		if agent_id == "player":
			continue
		var agent: Dictionary = GameState.agents[agent_id]
		if agent.get("is_disabled", false):
			continue
		var cond: String = str(agent.get("condition_tag", "HEALTHY")).to_lower()
		var sector: String = _formatter.loc(str(agent.get("current_sector_id", "")))

		var wealth_display: String = _format_agent_wealth(agent_id, agent, true)

		lines.append("    %s: %s, %s, at %s" % [
			_formatter.agent_display(agent_id), cond, wealth_display, sector])

	return lines


func focused_summary() -> Array:
	var lines: Array = []
	var focus_mode: String = str(_report._report_request.get("focus_mode", "world"))
	var focus_id: String = str(_report._report_request.get("focus_id", ""))
	var relevant_events: Array = _report._filter_report_events(_report._all_events)
	var action_totals: Dictionary = _report._count_actions(relevant_events)

	lines.append("================================================================")
	lines.append("FOCUSED SUMMARY")
	lines.append("================================================================")
	lines.append("  Focus mode: %s  |  focus id: %s" % [focus_mode, focus_id])
	lines.append("  Simulation ran for %d ticks with %d relevant events captured." % [
		_report._total_ticks,
		relevant_events.size(),
	])
	var action_parts: Array = _formatter.format_action_totals(action_totals)
	if not action_parts.empty():
		lines.append("  Action totals: %s" % PoolStringArray(action_parts).join(", "))

	if focus_mode == "sector":
		if GameState.sector_tags.has(focus_id):
			var tags: Array = GameState.sector_tags.get(focus_id, [])
			lines.append("  Final sector state: %s economy, %s, %s environment [%s]" % [
				_formatter.economy_label(tags),
				_formatter.security_label(tags),
				_formatter.environment_label(tags),
				GameState.colony_levels.get(focus_id, "frontier"),
			])
			var connections: Array = Array(GameState.world_topology.get(focus_id, {}).get("connections", []))
			var connection_labels: Array = []
			for connection_id in connections:
				connection_labels.append(_formatter.sector_label_with_id(str(connection_id)))
			lines.append("  Connections: %s" % (
				PoolStringArray(connection_labels).join(", ") if not connection_labels.empty() else "(isolated)"
			))
		else:
			lines.append("  Final sector state: unavailable for %s" % _formatter.sector_label_with_id(focus_id))
		var actor_counts: Dictionary = _report._collect_actor_counts(relevant_events)
		if not actor_counts.empty():
			lines.append("  Active actors: %s" % _formatter.format_count_entries(actor_counts, "agent"))
	elif focus_mode == "agent":
		var agent: Dictionary = GameState.agents.get(focus_id, {})
		if agent.empty():
			lines.append("  Final agent state: unavailable for %s" % _formatter.actor_label_with_id(focus_id))
		else:
			var wealth_display: String = _format_agent_wealth(focus_id, agent, false)

			lines.append("  Final agent state: sector=%s cond=%s wealth=%s cargo=%s goal=%s" % [
				_formatter.sector_label_with_id(str(agent.get("current_sector_id", ""))),
				str(agent.get("condition_tag", "?")),
				wealth_display,
				str(agent.get("cargo_tag", "?")),
				str(agent.get("goal_archetype", "none")),
			])
		var sector_counts: Dictionary = _report._collect_sector_counts(relevant_events)
		if not sector_counts.empty():
			lines.append("  Sector trail: %s" % _formatter.format_count_entries(sector_counts, "sector"))

	return lines


func take_sector_snapshot() -> Dictionary:
	var snap: Dictionary = {}
	for sector_id in GameState.sector_tags:
		var tags: Array = GameState.sector_tags.get(sector_id, [])
		snap[sector_id] = {
			"economy": _formatter.economy_label(tags),
			"security": _formatter.security_label(tags),
			"environment": _formatter.environment_label(tags),
			"colony": GameState.colony_levels.get(sector_id, "frontier"),
			"infested": "HOSTILE_INFESTED" in tags,
		}
	return snap


func detect_sector_changes(prev: Dictionary, cur: Dictionary, focus_sector_id: String = "") -> Array:
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
			changes.append([_formatter.loc(sid), PoolStringArray(parts).join("; ")])
	return changes


func _format_agent_wealth(agent_id: String, agent: Dictionary, to_lower: bool = false) -> String:
	var character_key = ""
	if agent_id == "player":
		character_key = str(GameState.player_character_uid)
	elif agent.has("character_uid") and agent["character_uid"] != null:
		character_key = str(agent["character_uid"])
	elif GameState.persistent_agents.has(agent_id):
		var p_agent = GameState.persistent_agents[agent_id]
		if p_agent != null and p_agent.has("character_uid") and p_agent["character_uid"] != null:
			character_key = str(p_agent["character_uid"])
	elif agent.has("character_id") and agent["character_id"] != null:
		character_key = str(agent["character_id"])

	var has_char_progress = false
	var w_prog = 0
	var actual_key = character_key
	if character_key != "" and is_instance_valid(GlobalRefs.character_system):
		var exists = GameState.characters.has(character_key)
		if not exists and character_key.is_valid_integer():
			var int_key = int(character_key)
			if GameState.characters.has(int_key):
				exists = true
				actual_key = int_key
		
		if exists:
			has_char_progress = true
			w_prog = GlobalRefs.character_system.get_wealth_progress(actual_key)

	var w_tier = ""
	if agent_id == "player" and has_char_progress:
		w_tier = GlobalRefs.character_system.get_wealth_tier(actual_key)
	else:
		w_tier = str(agent.get("wealth_tag", "COMFORTABLE"))

	if to_lower:
		w_tier = w_tier.to_lower()

	if has_char_progress:
		return "%s (%d/10)" % [w_tier, w_prog]
	else:
		return w_tier
