#
# PROJECT: GDTLancer
# MODULE: simulation_report.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6
# LOG_REF: 2026-02-23
#

extends Reference

## SimulationReport: Generates chronicle-style narrative reports of simulation
## runs, matching the Python sandbox's `main.py --chronicle` output format.
##
## Usage:
##   var report = SimulationReport.new()
##   report.begin(seed_string)      # snapshot initial state
##   # ... run N ticks ...
##   report.record_epoch(tick_start, tick_end, events)   # after each epoch
##   var text = report.finalize()    # overall summary
##
## Or use the convenience method:
##   var text = report.run_and_report(engine, tick_count, epoch_size)


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


# =============================================================================
# === CONVENIENCE: ONE-SHOT RUN ===============================================
# =============================================================================

## Runs `tick_count` ticks on the given engine and returns the full chronicle
## report as a plain-text string. Events are grouped into epochs of `epoch_size`.
func run_and_report(engine, tick_count: int, epoch_size: int = 1) -> String:
	_lines.clear()
	_all_events.clear()
	_prev_sector_snap.clear()
	_total_ticks = tick_count
	_seed = GameState.world_seed

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

			# Narrative
			var narrative: Array = _epoch_narrative(epoch_events)
			if not narrative.empty():
				_lines.append_array(narrative)
			_lines.append("")

			epoch_start = epoch_end
			ticks_in_epoch = 0

	# Overall summary
	_lines.append_array(_summary())

	return PoolStringArray(_lines).join("\n")


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


func _epoch_narrative(epoch_events: Array) -> Array:
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

	# ---- Sector state change detection ----
	var cur_snap: Dictionary = _take_sector_snapshot()
	var changed_sectors: Array = _detect_sector_changes(_prev_sector_snap, cur_snap)
	_prev_sector_snap = cur_snap

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


# =============================================================================
# === OVERALL SUMMARY =========================================================
# =============================================================================

func _summary() -> Array:
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
		lines.append("    %s: %s, %s, at %s" % [
			_agent_display(agent_id), cond, wealth, sector])

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


func _detect_sector_changes(prev: Dictionary, cur: Dictionary) -> Array:
	var changes: Array = []
	for sid in cur:
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
