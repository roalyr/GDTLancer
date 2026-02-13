#
# PROJECT: GDTLancer
# MODULE: sim_debug_panel.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 8 (Simulation Architecture)
# LOG_REF: 2026-02-13
#

extends CanvasLayer

## SimDebugPanel: Full text-only readout of all four simulation layers.
##
## Toggle with F3. Reads directly from GameState each tick (via EventBus signal).
## Shows World Layer, Grid Layer, Agent Layer, Chronicle, and Axiom 1 status.
## Debug-only — not a gameplay UI element.


# =============================================================================
# === NODE REFERENCES =========================================================
# =============================================================================

onready var _panel: Panel = $Panel
onready var _header_label: Label = $Panel/VBoxContainer/HeaderRow/HeaderLabel
onready var _rich_text: RichTextLabel = $Panel/VBoxContainer/RichTextLabel
onready var _btn_dump: Button = $Panel/VBoxContainer/HeaderRow/BtnDumpConsole


# =============================================================================
# === STATE ===================================================================
# =============================================================================

var _visible: bool = false
var _last_plain_text: String = ""


# =============================================================================
# === LIFECYCLE ===============================================================
# =============================================================================

func _ready() -> void:
	layer = 100  # Render above everything
	_panel.visible = false
	EventBus.connect("world_event_tick_triggered", self, "_on_tick")
	_btn_dump.connect("pressed", self, "_on_dump_pressed")
	# Initial refresh if simulation is already running.
	call_deferred("_refresh")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_F3:
			_toggle()
			get_tree().set_input_as_handled()
		elif event.scancode == KEY_ESCAPE and _visible:
			_toggle()
			get_tree().set_input_as_handled()


# =============================================================================
# === TOGGLE ==================================================================
# =============================================================================

func _toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		_refresh()


# =============================================================================
# === TICK HANDLER ============================================================
# =============================================================================

func _on_tick(_seconds_amount: int = 0) -> void:
	if _visible:
		_refresh()


# =============================================================================
# === REFRESH — BUILDS THE FULL TEXT ==========================================
# =============================================================================

func _refresh() -> void:
	var bb: String = ""   # BBCode version for RichTextLabel
	var pt: String = ""   # Plain-text version for console dump

	# --- Header ---
	var header_line: String = "[TICK %d]  Seed: %s" % [GameState.sim_tick_count, GameState.world_seed]
	bb += _bbcolor(header_line, "cyan") + "\n"
	pt += header_line + "\n"

	# --- World Layer ---
	bb += _section_header("WORLD LAYER")
	pt += "\n--- WORLD LAYER ---\n"
	if GameState.world_topology.empty():
		bb += "  (not initialized)\n"
		pt += "  (not initialized)\n"
	else:
		for sector_id in GameState.world_topology:
			var topo = GameState.world_topology[sector_id]
			var haz = GameState.world_hazards.get(sector_id, {})
			var res = GameState.world_resource_potential.get(sector_id, {})
			var sector_hdr: String = "  [%s]" % sector_id
			bb += _bbcolor(sector_hdr, "white")
			var line1: String = "  type=%s  conn=%s" % [
				str(topo.get("sector_type", "?")),
				str(topo.get("connections", []))
			]
			var line2: String = "    rad=%.3f  thermal=%.0fK  grav=%.2f" % [
				haz.get("radiation_level", 0.0),
				haz.get("thermal_background_k", 0.0),
				haz.get("gravity_well_penalty", 0.0)
			]
			var line3: String = "    mineral=%.3f  propellant=%.3f" % [
				res.get("mineral_density", 0.0),
				res.get("propellant_sources", 0.0)
			]
			bb += line1 + "\n" + line2 + "\n" + line3 + "\n"
			pt += sector_hdr + line1 + "\n" + line2 + "\n" + line3 + "\n"

	# --- Grid Layer ---
	bb += _section_header("GRID LAYER")
	pt += "\n--- GRID LAYER ---\n"
	if GameState.grid_stockpiles.empty():
		bb += "  (not initialized)\n"
		pt += "  (not initialized)\n"
	else:
		for sector_id in GameState.grid_stockpiles:
			var stk = GameState.grid_stockpiles.get(sector_id, {})
			var dom = GameState.grid_dominion.get(sector_id, {})
			var mkt = GameState.grid_market.get(sector_id, {})
			var pwr = GameState.grid_power.get(sector_id, {})
			var mnt = GameState.grid_maintenance.get(sector_id, {})

			var sector_hdr: String = "  [%s]" % sector_id
			bb += _bbcolor(sector_hdr, "white")

			# Stockpiles — compact: only show named commodities (strip commodity_ prefix)
			var stockpile_dict = stk.get("commodity_stockpiles", {})
			var stk_parts: Array = []
			for cid in stockpile_dict:
				var short_id: String = cid.replace("commodity_", "")
				stk_parts.append("%s:%.0f" % [short_id, stockpile_dict[cid]])
			var stk_line: String = " stk={%s}" % PoolStringArray(stk_parts).join(",")
			bb += stk_line + "\n"

			# Dominion + security (one compact line)
			var inf_dict = dom.get("faction_influence", {})
			var top_faction: String = ""
			var top_inf: float = 0.0
			for fid in inf_dict:
				if inf_dict[fid] > top_inf:
					top_inf = inf_dict[fid]
					top_faction = fid.replace("faction_", "")
			var dom_line: String = "    dom=%s(%.2f) sec=%.2f pir=%.3f pwr=%.2f ent=%.4f" % [
				top_faction, top_inf,
				dom.get("security_level", 0.0),
				dom.get("pirate_activity", 0.0),
				pwr.get("power_load_ratio", 0.0),
				mnt.get("local_entropy_rate", 0.0)
			]
			bb += dom_line + "\n"

			pt += sector_hdr + stk_line + "\n" + dom_line + "\n"

		# Wrecks
		var wreck_count: int = GameState.grid_wrecks.size()
		var wreck_line: String = "  Wrecks: %d" % wreck_count
		bb += wreck_line + "\n"
		pt += wreck_line + "\n"

	# --- Agent Layer ---
	bb += _section_header("AGENT LAYER")
	pt += "\n--- AGENT LAYER ---\n"
	if GameState.agents.empty():
		bb += "  (not initialized)\n"
		pt += "  (not initialized)\n"
	else:
		for agent_id in GameState.agents:
			var a = GameState.agents[agent_id]
			var char_uid = a.get("char_uid", -1)
			var char_name: String = _get_character_name(char_uid)
			var disabled_tag: String = " [DISABLED]" if a.get("is_disabled", false) else ""
			var is_player: bool = (char_uid == GameState.player_character_uid)
			var name_color: String = "green" if is_player else "white"
			var agent_line: String = "  %s%s  sector=%s  hull=%.0f%%  cash=%.0f  goal=%s%s" % [
				char_name,
				" (PLAYER)" if is_player else "",
				str(a.get("current_sector_id", "?")),
				a.get("hull_integrity", 0.0) * 100.0,
				a.get("cash_reserves", 0.0),
				str(a.get("goal_archetype", "none")),
				disabled_tag
			]
			# BBCode version uses color for player name
			var agent_line_bb: String = "  %s%s  sector=%s  hull=%.0f%%  cash=%.0f  goal=%s%s" % [
				_bbcolor(char_name, name_color),
				" (PLAYER)" if is_player else "",
				str(a.get("current_sector_id", "?")),
				a.get("hull_integrity", 0.0) * 100.0,
				a.get("cash_reserves", 0.0),
				str(a.get("goal_archetype", "none")),
				disabled_tag
			]
			bb += agent_line_bb + "\n"
			pt += agent_line + "\n"

		# Hostile population
		if not GameState.hostile_population_integral.empty():
			bb += _bbcolor("  Hostile Population:\n", "red")
			pt += "  Hostile Population:\n"
			for htype in GameState.hostile_population_integral:
				var hdata = GameState.hostile_population_integral[htype]
				var hline: String = "    %s: count=%d  cap=%d" % [
					htype,
					hdata.get("current_count", 0),
					hdata.get("carrying_capacity", 0)
				]
				bb += hline + "\n"
				pt += hline + "\n"

	# --- Chronicle ---
	bb += _section_header("CHRONICLE")
	pt += "\n--- CHRONICLE ---\n"
	# Last 5 events
	var events = GameState.chronicle_event_buffer
	var event_start: int = max(0, events.size() - 5)
	if events.empty():
		bb += "  Events: (none)\n"
		pt += "  Events: (none)\n"
	else:
		var ev_header: String = "  Events (%d total, last %d):" % [events.size(), min(events.size(), 5)]
		bb += ev_header + "\n"
		pt += ev_header + "\n"
		for i in range(event_start, events.size()):
			var ev = events[i]
			var evline: String = "    T%d %s %s@%s=%s" % [
				ev.get("tick_count", 0),
				_get_character_name_by_agent(ev.get("actor_uid", "")),
				str(ev.get("action_id", "?")),
				str(ev.get("target_sector_id", "?")),
				str(ev.get("outcome", "?"))
			]
			bb += evline + "\n"
			pt += evline + "\n"
	# Last 3 rumors
	var rumors = GameState.chronicle_rumors
	var rumor_start: int = max(0, rumors.size() - 3)
	if not rumors.empty():
		bb += "  Rumors:\n"
		pt += "  Rumors:\n"
		for i in range(rumor_start, rumors.size()):
			var rline: String = "    \"%s\"" % str(rumors[i])
			bb += rline + "\n"
			pt += rline + "\n"

	# --- Axiom 1 Check ---
	bb += _section_header("AXIOM 1 CHECK")
	pt += "\n--- AXIOM 1 CHECK ---\n"
	var expected: float = GameState.world_total_matter
	var actual: float = _calculate_actual_matter()
	var drift: float = abs(actual - expected)
	var tolerance: float = Constants.AXIOM1_TOLERANCE
	var status: String = "PASS" if drift <= tolerance else "FAIL"
	var status_color: String = "green" if status == "PASS" else "red"
	var a1_line1: String = "  Expected: %.4f" % expected
	var a1_line2: String = "  Actual:   %.4f" % actual
	var a1_line3: String = "  Drift:    %.6f  (tol=%.4f)" % [drift, tolerance]
	var a1_line4: String = "  Status:   %s" % status
	bb += a1_line1 + "\n" + a1_line2 + "\n" + a1_line3 + "\n"
	bb += "  Status:   %s\n" % _bbcolor(status, status_color)
	pt += a1_line1 + "\n" + a1_line2 + "\n" + a1_line3 + "\n" + a1_line4 + "\n"

	# Cache and apply
	_last_plain_text = pt
	_header_label.text = "SIM DEBUG  [F3 to close]"
	_rich_text.bbcode_text = bb


## Dumps the current panel contents to stdout as plain text.
func _on_dump_pressed() -> void:
	_refresh()  # Ensure latest data
	print("\n========== SIM DEBUG DUMP (Tick %d) ==========" % GameState.sim_tick_count)
	print(_last_plain_text)
	print("========== END SIM DEBUG DUMP ==========")


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

## Wraps text in BBCode color tags.
func _bbcolor(text: String, color: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]


## Returns a section header line.
func _section_header(title: String) -> String:
	return "\n" + _bbcolor("--- %s ---" % title, "yellow") + "\n"


## Looks up character_name from GameState.characters by uid.
func _get_character_name(char_uid: int) -> String:
	if GameState.characters.has(char_uid):
		var c = GameState.characters[char_uid]
		if c is Resource and c.get("character_name"):
			return c.character_name
		elif c is Dictionary and c.has("character_name"):
			return c["character_name"]
	return "UID:%d" % char_uid


## Looks up character name via agent_id → agent state → char_uid.
func _get_character_name_by_agent(agent_id) -> String:
	if GameState.agents.has(agent_id):
		var a = GameState.agents[agent_id]
		return _get_character_name(a.get("char_uid", -1))
	return str(agent_id)


## Calculates actual total matter across all four conservation pools.
## Must match the formula in simulation_engine.gd verify_matter_conservation().
func _calculate_actual_matter() -> float:
	var total: float = 0.0

	# Pool 1: World resource potential
	for sector_id in GameState.world_resource_potential:
		var res = GameState.world_resource_potential[sector_id]
		total += res.get("mineral_density", 0.0)
		total += res.get("propellant_sources", 0.0)

	# Pool 2: Grid stockpiles
	for sector_id in GameState.grid_stockpiles:
		var stk = GameState.grid_stockpiles[sector_id]
		var commodities = stk.get("commodity_stockpiles", {})
		for cid in commodities:
			total += commodities[cid]

	# Pool 3: Agent inventories
	for char_uid in GameState.inventories:
		var inv = GameState.inventories[char_uid]
		if inv is Dictionary:
			for item_id in inv:
				var item = inv[item_id]
				if item is Dictionary:
					total += item.get("quantity", 0.0)
				else:
					total += float(item)

	# Pool 4: Wreck inventories
	for wid in GameState.grid_wrecks:
		var w = GameState.grid_wrecks[wid]
		var winv = w.get("wreck_inventory", {})
		for cid in winv:
			total += winv[cid]

	return total
