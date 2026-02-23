#
# PROJECT: GDTLancer
# MODULE: sim_debug_panel.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_12
# LOG_REF: 2026-02-21 (TASK_12)
#

extends CanvasLayer

## SimDebugPanel: Full text-only readout of qualitative simulation state.
##
## Toggle with F3. Reads directly from GameState each tick (via EventBus signal).
## Shows World Layer (topology + tags), Grid Layer (sector tags + colony levels),
## Agent Layer (condition/wealth/cargo/goal tags), and Chronicle (events + rumors).
## Debug-only — not a gameplay UI element.


# =============================================================================
# === NODE REFERENCES =========================================================
# =============================================================================

onready var _panel: Panel = $Panel
onready var _header_label: Label = $Panel/VBoxContainer/HeaderRow/HeaderLabel
onready var _rich_text: RichTextLabel = $Panel/VBoxContainer/RichTextLabel
onready var _btn_dump: Button = $Panel/VBoxContainer/HeaderRow/BtnDumpConsole
onready var _btn_tick: Button = $Panel/VBoxContainer/HeaderRow/BtnTick
onready var _btn_run_30: Button = $Panel/VBoxContainer/HeaderRow/BtnRun30
onready var _btn_run_300: Button = $Panel/VBoxContainer/HeaderRow/BtnRun300
onready var _btn_run_3000: Button = $Panel/VBoxContainer/HeaderRow/BtnRun3000
onready var _btn_back: Button = $Panel/VBoxContainer/HeaderRow/BtnBack


# =============================================================================
# === STATE ===================================================================
# =============================================================================

var _visible: bool = false
var _last_plain_text: String = ""

## When true, panel shows a chronicle report instead of live state.
var _showing_report: bool = false
var _report_text: String = ""
var _report_bbcode: String = ""


# =============================================================================
# === LIFECYCLE ===============================================================
# =============================================================================

func _ready() -> void:
	layer = 100  # Render above everything
	_panel.visible = false
	EventBus.connect("sim_tick_completed", self, "_on_tick")
	_btn_dump.connect("pressed", self, "_on_dump_pressed")
	_btn_tick.connect("pressed", self, "_on_tick_pressed")
	_btn_run_30.connect("pressed", self, "_on_run_batch", [30])
	_btn_run_300.connect("pressed", self, "_on_run_batch", [300])
	_btn_run_3000.connect("pressed", self, "_on_run_batch", [3000])
	_btn_back.connect("pressed", self, "_on_back_pressed")
	_btn_back.visible = false
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

func _on_tick(_tick_count: int = 0) -> void:
	if _visible:
		_refresh()


## Manually advances one simulation tick (debug only).
func _on_tick_pressed() -> void:
	if _showing_report:
		return
	if is_instance_valid(GlobalRefs.simulation_engine) and GlobalRefs.simulation_engine.has_method("request_tick"):
		GlobalRefs.simulation_engine.request_tick()
		_refresh()


## Runs a batch of N ticks and shows the chronicle report.
func _on_run_batch(tick_count: int) -> void:
	if not is_instance_valid(GlobalRefs.simulation_engine):
		return
	var engine = GlobalRefs.simulation_engine
	if not engine.has_method("run_batch_and_report"):
		return

	# Determine epoch size based on tick count
	var epoch_size: int = 1
	if tick_count >= 3000:
		epoch_size = 100
	elif tick_count >= 300:
		epoch_size = 10

	var report: String = engine.run_batch_and_report(tick_count, epoch_size)

	# Also dump to console for LLM agent consumption
	print("\n" + report + "\n")

	# Show in panel
	_report_text = report
	_report_bbcode = _plain_to_bbcode(report)
	_showing_report = true
	_btn_back.visible = true
	_header_label.text = "CHRONICLE REPORT (%d ticks)  [Back to return]" % tick_count
	_rich_text.bbcode_text = _report_bbcode
	_last_plain_text = _report_text


## Returns to the live state view from a report view.
func _on_back_pressed() -> void:
	_showing_report = false
	_btn_back.visible = false
	_report_text = ""
	_report_bbcode = ""
	_refresh()


# =============================================================================
# === REFRESH — BUILDS THE FULL TEXT ==========================================
# =============================================================================

func _refresh() -> void:
	# If we're showing a report, don't overwrite it with live state
	if _showing_report:
		return

	var bb: String = ""   # BBCode version for RichTextLabel
	var pt: String = ""   # Plain-text version for console dump

	# --- Header ---
	var header_line: String = "[TICK %d]  Seed: %s  Age: %s (%d left)  Cycle: %d" % [
		GameState.sim_tick_count,
		GameState.world_seed,
		GameState.world_age,
		GameState.world_age_timer,
		GameState.world_age_cycle_count,
	]
	bb += _bbcolor(header_line, "cyan") + "\n"
	pt += header_line + "\n"

	# World tags
	var wt_line: String = "  World Tags: %s" % str(GameState.world_tags)
	bb += wt_line + "\n"
	pt += wt_line + "\n"

	# --- World Layer (Topology) ---
	bb += _section_header("WORLD LAYER")
	pt += "\n--- WORLD LAYER ---\n"
	if GameState.world_topology.empty():
		bb += "  (not initialized)\n"
		pt += "  (not initialized)\n"
	else:
		for sector_id in GameState.world_topology:
			var topo: Dictionary = GameState.world_topology[sector_id]
			var haz: Dictionary = GameState.world_hazards.get(sector_id, {})
			var sector_name: String = GameState.sector_names.get(sector_id, sector_id)
			var sector_hdr: String = "  [%s] %s" % [sector_id, sector_name if sector_name != sector_id else ""]
			bb += _bbcolor(sector_hdr.strip_edges(), "white")
			var line1: String = "  type=%s  conn=%s  env=%s" % [
				str(topo.get("sector_type", "?")),
				str(topo.get("connections", [])),
				str(haz.get("environment", "?"))
			]
			bb += line1 + "\n"
			pt += sector_hdr.strip_edges() + line1 + "\n"

	# --- Grid Layer (Tags + Colony) ---
	bb += _section_header("GRID LAYER")
	pt += "\n--- GRID LAYER ---\n"
	if GameState.sector_tags.empty():
		bb += "  (not initialized)\n"
		pt += "  (not initialized)\n"
	else:
		for sector_id in GameState.sector_tags:
			var tags: Array = GameState.sector_tags.get(sector_id, [])
			var colony_level: String = GameState.colony_levels.get(sector_id, "?")
			var dom: Dictionary = GameState.grid_dominion.get(sector_id, {})
			var security: String = dom.get("security_tag", "?")
			var disabled_until = GameState.sector_disabled_until.get(sector_id, 0)
			var is_disabled: bool = disabled_until > GameState.sim_tick_count if disabled_until is int else false

			var sector_hdr: String = "  [%s]" % sector_id
			bb += _bbcolor(sector_hdr, "white")
			var line1: String = " colony=%s  security=%s%s" % [
				colony_level,
				security,
				"  DISABLED(until T%d)" % disabled_until if is_disabled else "",
			]
			var line2: String = "    tags=%s" % str(tags)
			bb += line1 + "\n" + line2 + "\n"
			pt += sector_hdr + line1 + "\n" + line2 + "\n"

		# Catastrophe log
		if not GameState.catastrophe_log.empty():
			var cat_header: String = "  Catastrophes: %d" % GameState.catastrophe_log.size()
			bb += _bbcolor(cat_header, "red") + "\n"
			pt += cat_header + "\n"

		# Discovery count
		var disc_line: String = "  Discovered sectors: %d / %d" % [
			GameState.discovered_sector_count, Constants.MAX_SECTOR_COUNT]
		bb += disc_line + "\n"
		pt += disc_line + "\n"

	# --- Agent Layer ---
	bb += _section_header("AGENT LAYER")
	pt += "\n--- AGENT LAYER ---\n"
	if GameState.agents.empty():
		bb += "  (not initialized)\n"
		pt += "  (not initialized)\n"
	else:
		var persistent_count: int = 0
		var mortal_count: int = 0
		var disabled_count: int = 0
		for agent_id in GameState.agents:
			var a: Dictionary = GameState.agents[agent_id]
			if a.get("is_persistent", false):
				persistent_count += 1
			else:
				mortal_count += 1
			if a.get("is_disabled", false):
				disabled_count += 1

		var summary_line: String = "  Total: %d  (persistent=%d, mortal=%d, disabled=%d)" % [
			GameState.agents.size(), persistent_count, mortal_count, disabled_count]
		bb += summary_line + "\n"
		pt += summary_line + "\n"

		for agent_id in GameState.agents:
			var a: Dictionary = GameState.agents[agent_id]
			var char_id: String = str(a.get("character_id", ""))
			var char_name: String = _get_character_name(char_id)
			var is_player: bool = (agent_id == "player")
			var disabled_tag: String = " [DISABLED]" if a.get("is_disabled", false) else ""
			var name_color: String = "green" if is_player else "white"

			var agent_line: String = "  %s%s  role=%s  sector=%s  cond=%s  wealth=%s  cargo=%s  goal=%s%s" % [
				char_name,
				" (PLAYER)" if is_player else "",
				str(a.get("agent_role", "?")),
				str(a.get("current_sector_id", "?")),
				str(a.get("condition_tag", "?")),
				str(a.get("wealth_tag", "?")),
				str(a.get("cargo_tag", "?")),
				str(a.get("goal_archetype", "none")),
				disabled_tag
			]
			var agent_line_bb: String = "  %s%s  role=%s  sector=%s  cond=%s  wealth=%s  cargo=%s  goal=%s%s" % [
				_bbcolor(char_name, name_color),
				" (PLAYER)" if is_player else "",
				str(a.get("agent_role", "?")),
				str(a.get("current_sector_id", "?")),
				str(a.get("condition_tag", "?")),
				str(a.get("wealth_tag", "?")),
				str(a.get("cargo_tag", "?")),
				str(a.get("goal_archetype", "none")),
				disabled_tag
			]
			bb += agent_line_bb + "\n"
			pt += agent_line + "\n"

		# Mortal deaths summary
		var deaths: int = GameState.mortal_agent_deaths.size()
		if deaths > 0:
			var death_line: String = "  Mortal deaths (total): %d" % deaths
			bb += _bbcolor(death_line, "red") + "\n"
			pt += death_line + "\n"

	# --- Chronicle ---
	bb += _section_header("CHRONICLE")
	pt += "\n--- CHRONICLE ---\n"
	# Last 5 events
	var events: Array = GameState.chronicle_events
	var event_start: int = max(0, events.size() - 5)
	if events.empty():
		bb += "  Events: (none)\n"
		pt += "  Events: (none)\n"
	else:
		var ev_header: String = "  Events (%d total, last %d):" % [events.size(), min(events.size(), 5)]
		bb += ev_header + "\n"
		pt += ev_header + "\n"
		for i in range(event_start, events.size()):
			var ev: Dictionary = events[i]
			var meta: Dictionary = ev.get("metadata", {})
			var meta_str: String = ""
			for key in meta:
				meta_str += " %s=%s" % [key, str(meta[key])]
			var evline: String = "    T%d %s %s@%s%s" % [
				ev.get("tick", 0),
				str(ev.get("actor_id", "?")),
				str(ev.get("action", "?")),
				str(ev.get("sector_id", "?")),
				meta_str,
			]
			bb += evline + "\n"
			pt += evline + "\n"

	# Last 3 rumors
	var rumors: Array = GameState.chronicle_rumors
	var rumor_start: int = max(0, rumors.size() - 3)
	if not rumors.empty():
		bb += "  Rumors:\n"
		pt += "  Rumors:\n"
		for i in range(rumor_start, rumors.size()):
			var r = rumors[i]
			var rstr: String = str(r.get("text", r)) if r is Dictionary else str(r)
			var rline: String = "    \"%s\"" % rstr
			bb += rline + "\n"
			pt += rline + "\n"

	# Cache and apply
	_last_plain_text = pt
	_header_label.text = "SIM DEBUG  [F3 to close]"
	_rich_text.bbcode_text = bb


## Dumps the current panel contents to stdout as plain text.
func _on_dump_pressed() -> void:
	if not _showing_report:
		_refresh()
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


## Looks up character_name from GameState.characters by id.
func _get_character_name(char_id: String) -> String:
	if char_id == "" or char_id == "null":
		return "(unnamed)"
	if GameState.characters.has(char_id):
		var c = GameState.characters[char_id]
		if c is Resource and c.get("character_name"):
			return c.character_name
		elif c is Dictionary and c.has("character_name"):
			return c["character_name"]
	return char_id


## Converts plain-text chronicle report to BBCode with color highlights.
func _plain_to_bbcode(text: String) -> String:
	var bb: String = ""
	var lines: Array = text.split("\n")
	for line in lines:
		var s: String = str(line)
		if s.begins_with("==="):
			bb += _bbcolor(s, "cyan") + "\n"
		elif s.begins_with("--- Epoch") or s.begins_with("---"):
			bb += _bbcolor(s, "yellow") + "\n"
		elif s.find("CATASTROPHE") != -1:
			bb += _bbcolor(s, "red") + "\n"
		elif s.find(">>>") != -1:
			bb += _bbcolor(s, "lime") + "\n"
		elif s.find("NEW SECTOR DISCOVERED") != -1:
			bb += _bbcolor(s, "aqua") + "\n"
		elif s.find("Combat:") != -1:
			bb += _bbcolor(s, "orange") + "\n"
		elif s.find("Commerce:") != -1:
			bb += _bbcolor(s, "green") + "\n"
		elif s.find("Losses") != -1 or s.find("Danger:") != -1:
			bb += _bbcolor(s, "salmon") + "\n"
		elif s.begins_with("OVERALL SUMMARY") or s.begins_with("CHRONICLE OF"):
			bb += _bbcolor(s, "white") + "\n"
		else:
			bb += s + "\n"
	return bb
