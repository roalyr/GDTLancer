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
onready var _header_label: Label = $Panel/VBoxContainer/HeaderLabel
onready var _rich_text: RichTextLabel = $Panel/VBoxContainer/RichTextLabel


# =============================================================================
# === STATE ===================================================================
# =============================================================================

var _visible: bool = false


# =============================================================================
# === LIFECYCLE ===============================================================
# =============================================================================

func _ready() -> void:
	layer = 100  # Render above everything
	_panel.visible = false
	EventBus.connect("world_event_tick_triggered", self, "_on_tick")
	# Initial refresh if simulation is already running.
	call_deferred("_refresh")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_F3:
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
	var text: String = ""

	# --- Header ---
	text += _bbcolor("[TICK %d]  Seed: %s" % [GameState.sim_tick_count, GameState.world_seed], "cyan")
	text += "\n"

	# --- World Layer ---
	text += _section_header("WORLD LAYER")
	if GameState.world_topology.empty():
		text += "  (not initialized)\n"
	else:
		for sector_id in GameState.world_topology:
			var topo = GameState.world_topology[sector_id]
			var haz = GameState.world_hazards.get(sector_id, {})
			var res = GameState.world_resource_potential.get(sector_id, {})
			text += _bbcolor("  [%s]" % sector_id, "white")
			text += "  type=%s  conn=%s\n" % [
				str(topo.get("sector_type", "?")),
				str(topo.get("connections", []))
			]
			text += "    rad=%.3f  thermal=%.0fK  grav=%.2f\n" % [
				haz.get("radiation_level", 0.0),
				haz.get("thermal_background_k", 0.0),
				haz.get("gravity_well_penalty", 0.0)
			]
			text += "    mineral=%.3f  propellant=%.3f\n" % [
				res.get("mineral_density", 0.0),
				res.get("propellant_sources", 0.0)
			]

	# --- Grid Layer ---
	text += _section_header("GRID LAYER")
	if GameState.grid_stockpiles.empty():
		text += "  (not initialized)\n"
	else:
		for sector_id in GameState.grid_stockpiles:
			var stk = GameState.grid_stockpiles.get(sector_id, {})
			var dom = GameState.grid_dominion.get(sector_id, {})
			var mkt = GameState.grid_market.get(sector_id, {})
			var pwr = GameState.grid_power.get(sector_id, {})
			var mnt = GameState.grid_maintenance.get(sector_id, {})

			text += _bbcolor("  [%s]" % sector_id, "white")

			# Stockpiles summary
			var stockpile_dict = stk.get("commodity_stockpiles", {})
			var stk_parts: Array = []
			for cid in stockpile_dict:
				stk_parts.append("%s:%.0f" % [cid, stockpile_dict[cid]])
			text += "  stk={%s}\n" % PoolStringArray(stk_parts).join(", ")

			# Prices
			var price_dict = mkt.get("commodity_price_deltas", {})
			var price_parts: Array = []
			for cid in price_dict:
				price_parts.append("%s:%+.2f" % [cid, price_dict[cid]])
			text += "    prices={%s}\n" % PoolStringArray(price_parts).join(", ")

			# Dominion
			var inf_dict = dom.get("faction_influence", {})
			var inf_parts: Array = []
			for fid in inf_dict:
				inf_parts.append("%s:%.2f" % [fid, inf_dict[fid]])
			text += "    dominion={%s}  sec=%.2f  piracy=%.3f\n" % [
				PoolStringArray(inf_parts).join(", "),
				dom.get("security_level", 0.0),
				dom.get("pirate_activity", 0.0)
			]

			# Power & entropy
			text += "    pwr_load=%.2f  entropy=%.4f\n" % [
				pwr.get("power_load_ratio", 0.0),
				mnt.get("local_entropy_rate", 0.0)
			]

		# Wrecks
		if not GameState.grid_wrecks.empty():
			text += _bbcolor("  Wrecks:\n", "yellow")
			for wid in GameState.grid_wrecks:
				var w = GameState.grid_wrecks[wid]
				text += "    #%s @ %s  integrity=%.2f\n" % [
					str(wid),
					str(w.get("sector_id", "?")),
					w.get("wreck_integrity", 0.0)
				]
		else:
			text += "  Wrecks: (none)\n"

	# --- Agent Layer ---
	text += _section_header("AGENT LAYER")
	if GameState.agents.empty():
		text += "  (not initialized)\n"
	else:
		for agent_id in GameState.agents:
			var a = GameState.agents[agent_id]
			var char_uid = a.get("char_uid", -1)
			var char_name: String = _get_character_name(char_uid)
			var disabled_tag: String = " [DISABLED]" if a.get("is_disabled", false) else ""
			var is_player: bool = (char_uid == GameState.player_character_uid)
			var name_color: String = "green" if is_player else "white"
			text += "  %s%s  sector=%s  hull=%.0f%%  cash=%.0f  goal=%s%s\n" % [
				_bbcolor(char_name, name_color),
				" (PLAYER)" if is_player else "",
				str(a.get("current_sector_id", "?")),
				a.get("hull_integrity", 0.0) * 100.0,
				a.get("cash_reserves", 0.0),
				str(a.get("goal_archetype", "none")),
				disabled_tag
			]

		# Hostile population
		if not GameState.hostile_population_integral.empty():
			text += _bbcolor("  Hostile Population:\n", "red")
			for htype in GameState.hostile_population_integral:
				var hdata = GameState.hostile_population_integral[htype]
				text += "    %s: count=%d  cap=%d\n" % [
					htype,
					hdata.get("current_count", 0),
					hdata.get("carrying_capacity", 0)
				]

	# --- Chronicle ---
	text += _section_header("CHRONICLE")
	# Last 10 events
	var events = GameState.chronicle_event_buffer
	var event_start: int = max(0, events.size() - 10)
	if events.empty():
		text += "  Events: (none)\n"
	else:
		text += "  Events (last %d):\n" % min(events.size(), 10)
		for i in range(event_start, events.size()):
			var ev = events[i]
			text += "    T%d: %s -> %s @ %s => %s\n" % [
				ev.get("tick_count", 0),
				_get_character_name_by_agent(ev.get("actor_uid", "")),
				str(ev.get("action_id", "?")),
				str(ev.get("target_sector_id", "?")),
				str(ev.get("outcome", "?"))
			]

	# Last 5 rumors
	var rumors = GameState.chronicle_rumors
	var rumor_start: int = max(0, rumors.size() - 5)
	if rumors.empty():
		text += "  Rumors: (none)\n"
	else:
		text += "  Rumors (last %d):\n" % min(rumors.size(), 5)
		for i in range(rumor_start, rumors.size()):
			text += "    \"%s\"\n" % str(rumors[i])

	# --- Axiom 1 Check ---
	text += _section_header("AXIOM 1 CHECK")
	var expected: float = GameState.world_total_matter
	var actual: float = _calculate_actual_matter()
	var drift: float = abs(actual - expected)
	var tolerance: float = Constants.AXIOM1_TOLERANCE
	var status: String = "PASS" if drift <= tolerance else "FAIL"
	var status_color: String = "green" if status == "PASS" else "red"
	text += "  Expected: %.4f\n" % expected
	text += "  Actual:   %.4f\n" % actual
	text += "  Drift:    %.6f  (tol=%.4f)\n" % [drift, tolerance]
	text += "  Status:   %s\n" % _bbcolor(status, status_color)

	# Apply
	_header_label.text = "SIM DEBUG  [F3 to close]"
	_rich_text.bbcode_text = text


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

## Wraps text in BBCode color tags.
func _bbcolor(text: String, color: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]


## Returns a section header line.
func _section_header(title: String) -> String:
	return "\n" + _bbcolor("--- %s ---" % title, "yellow") + "\n"


## Looks up character display_name from GameState.characters by uid.
func _get_character_name(char_uid: int) -> String:
	if GameState.characters.has(char_uid):
		var c = GameState.characters[char_uid]
		if c is Resource and c.get("display_name"):
			return c.display_name
		elif c is Dictionary and c.has("display_name"):
			return c["display_name"]
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
