# PROJECT: GDTLancer
# MODULE: sim_debug_panel.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: sim_debug_panel.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §0, §6.5; TACTICAL_TODO.md TASK_1
# LOG_REF: 2026-05-28 14:01:46
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
onready var _btn_run_silent: Button = $Panel/VBoxContainer/HeaderRow/BtnRunSilent
onready var _btn_back: Button = $Panel/VBoxContainer/HeaderRow/BtnBack
onready var _btn_close: BaseButton = $Panel/VBoxContainer/HeaderRow/BtnClose

var _controls_row: HBoxContainer = null
var _report_mode_option: OptionButton = null
var _focus_mode_option: OptionButton = null
var _focus_id_option: OptionButton = null


# =============================================================================
# === STATE ===================================================================
# =============================================================================

var _visible: bool = false
var _last_plain_text: String = ""

## When true, panel shows a chronicle report instead of live state.
var _showing_report: bool = false
var _report_text: String = ""
var _report_bbcode: String = ""

const _REPORT_MODE_ITEMS := [
	{"label": "Focused Chronicle", "value": "focused"},
	{"label": "Composite Research", "value": "composite"},
]

const _FOCUS_MODE_ITEMS := [
	{"label": "World", "value": "world"},
	{"label": "Sector", "value": "sector"},
	{"label": "Agent", "value": "agent"},
]


# =============================================================================
# === LIFECYCLE ===============================================================
# =============================================================================

func _ready() -> void:
	layer = 100  # Render above everything
	_panel.visible = false
	_build_report_controls()
	_populate_static_report_options()
	_refresh_report_controls()
	EventBus.connect("sim_tick_completed", self, "_on_tick")
	_btn_dump.connect("pressed", self, "_on_dump_pressed")
	_btn_tick.connect("pressed", self, "_on_tick_pressed")
	_btn_run_30.connect("pressed", self, "_on_run_batch", [30])
	_btn_run_300.connect("pressed", self, "_on_run_batch", [300])
	_btn_run_3000.connect("pressed", self, "_on_run_batch", [3000])
	_btn_run_silent.connect("pressed", self, "_on_run_silent_pressed")
	_btn_back.connect("pressed", self, "_on_back_pressed")
	_btn_close.connect("pressed", self, "_on_close_pressed")
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
		_refresh_report_controls()
		_refresh()


# =============================================================================
# === TICK HANDLER ============================================================
# =============================================================================

func _on_tick(_tick_count: int = 0) -> void:
	if _visible:
		_refresh_report_controls()
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
	_refresh_report_controls()
	var discovery_start_index: int = GameState.discovery_log.size()
	var report_mode: String = _selected_option_value(_report_mode_option, "focused")
	var report: String = ""
	var header_text: String = ""

	if report_mode == "composite":
		if not engine.has_method("run_composite_research_report"):
			return
		var composite_tick_counts: Array = _composite_tick_counts_up_to(tick_count)
		var composite_request: Dictionary = _current_composite_request()
		report = engine.run_composite_research_report(composite_tick_counts, composite_request)
		header_text = "COMPOSITE RESEARCH REPORT (%s)  [Back to return]" % _composite_tick_count_label(composite_tick_counts)
	else:
		if not engine.has_method("run_batch_and_report"):
			return
		var report_request: Dictionary = _current_report_request()

		# Determine epoch size based on tick count
		var epoch_size: int = 1
		if tick_count >= 3000:
			epoch_size = 100
		elif tick_count >= 300:
			epoch_size = 10

		report = engine.run_batch_and_report(tick_count, epoch_size, report_request)
		header_text = "CHRONICLE REPORT (%d ticks, %s)  [Back to return]" % [tick_count, _report_request_header(report_request)]

	report = _append_batch_discovery_summary(report, discovery_start_index)

	# Also dump to console for LLM agent consumption
	print("\n" + report + "\n")

	# Show in panel
	_report_text = report
	_report_bbcode = _plain_to_bbcode(report)
	_showing_report = true
	_btn_back.visible = true
	_header_label.text = header_text
	_rich_text.bbcode_text = _report_bbcode
	_last_plain_text = _report_text


func _on_run_silent_pressed() -> void:
	if not is_instance_valid(GlobalRefs.simulation_engine):
		return
	var engine = GlobalRefs.simulation_engine
	if not engine.has_method("start_silent_raw_stream"):
		return
	engine.start_silent_raw_stream(_current_raw_log_request())
	if not _showing_report:
		_refresh()


## Returns to the live state view from a report view.
func _on_back_pressed() -> void:
	_showing_report = false
	_btn_back.visible = false
	_report_text = ""
	_report_bbcode = ""
	_refresh()


func _on_close_pressed() -> void:
	if _visible:
		_toggle()


func _on_focus_mode_selected(_index: int) -> void:
	_refresh_focus_id_options()


func _on_report_mode_selected(_index: int) -> void:
	_refresh_report_controls()


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
			var template = TemplateDatabase.locations.get(sector_id)
			var is_discovered: bool = _is_discovered_sector(sector_id, template)
			var procedural_type: String = _get_procedural_type(template)
			var sector_prefix: String = "[DISC] " if is_discovered else ""
			var sector_hdr: String = "  [%s] %s%s" % [sector_id, sector_prefix, sector_name if sector_name != sector_id else ""]
			bb += _bbcolor(sector_hdr.strip_edges(), "aqua" if is_discovered else "white")
			var line1: String = "  type=%s  conn=%s  env=%s%s" % [
				str(topo.get("sector_type", "?")),
				str(topo.get("connections", [])),
				str(haz.get("environment", "?")),
				"  proc=%s" % procedural_type if is_discovered else ""
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
		var recent_discoveries: Array = _get_recent_discoveries(5)
		if not recent_discoveries.empty():
			var discovery_header: String = "  Recent discoveries:"
			bb += _bbcolor(discovery_header, "aqua") + "\n"
			pt += discovery_header + "\n"
			for discovery in recent_discoveries:
				var discovery_line: String = "    NEW SECTOR DISCOVERED: %s" % _format_discovery_entry(discovery)
				bb += _bbcolor(discovery_line, "aqua") + "\n"
				pt += discovery_line + "\n"

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
		elif s.find("DISCOVERY SUMMARY") != -1:
			bb += _bbcolor(s, "aqua") + "\n"
		elif s.find("COMPOSITE RESEARCH CHRONICLE") != -1 or s.find("COMPOSITE WINDOW:") != -1:
			bb += _bbcolor(s, "cyan") + "\n"
		elif s.find("SAMPLED SECTORS") != -1 or s.find("SAMPLED AGENTS") != -1:
			bb += _bbcolor(s, "white") + "\n"
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


func _append_batch_discovery_summary(report: String, discovery_start_index: int) -> String:
	if discovery_start_index >= GameState.discovery_log.size():
		return report
	var appended: String = "\n\n================================================================\nDISCOVERY SUMMARY\n================================================================\n"
	for idx in range(discovery_start_index, GameState.discovery_log.size()):
		appended += "  NEW SECTOR DISCOVERED: %s\n" % _format_discovery_entry(GameState.discovery_log[idx])
	return report + appended


func _get_recent_discoveries(limit: int) -> Array:
	if GameState.discovery_log.empty():
		return []
	var start_index: int = max(0, GameState.discovery_log.size() - limit)
	var recent: Array = []
	for idx in range(start_index, GameState.discovery_log.size()):
		recent.append(GameState.discovery_log[idx])
	return recent


func _format_discovery_entry(discovery: Dictionary) -> String:
	var sector_id: String = str(discovery.get("new_sector", "?"))
	var sector_name: String = str(discovery.get("name", sector_id))
	var from_sector: String = str(discovery.get("from", "?"))
	var procedural_type: String = str(discovery.get("procedural_type", "deep_space"))
	var connections: Array = discovery.get("connections", [])
	return "T%d %s [%s] from %s type=%s conn=%s" % [
		int(discovery.get("tick", 0)),
		sector_name,
		sector_id,
		from_sector,
		procedural_type,
		str(connections),
	]


func _is_discovered_sector(sector_id: String, template = null) -> bool:
	var resolved_template = template if template != null else TemplateDatabase.locations.get(sector_id)
	if sector_id.begins_with("discovered_"):
		return true
	if resolved_template == null:
		return false
	var hints = resolved_template.get("procedural_hints")
	return hints is Dictionary and bool(hints.get("low_visibility", false))


func _get_procedural_type(template) -> String:
	if template == null:
		return ""
	var procedural_type = template.get("procedural_type")
	return str(procedural_type) if procedural_type != null else ""


func _build_report_controls() -> void:
	if _controls_row != null:
		return
	var vbox: VBoxContainer = $Panel/VBoxContainer
	_controls_row = HBoxContainer.new()
	_controls_row.name = "ReportControlsRow"
	vbox.add_child(_controls_row)
	vbox.move_child(_controls_row, 1)

	_add_report_label(_controls_row, "Output")
	_report_mode_option = _create_report_option_button("ReportModeOption", 180)
	_controls_row.add_child(_report_mode_option)
	_report_mode_option.connect("item_selected", self, "_on_report_mode_selected")

	_add_report_label(_controls_row, "Focus")
	_focus_mode_option = _create_report_option_button("FocusModeOption", 140)
	_controls_row.add_child(_focus_mode_option)
	_focus_mode_option.connect("item_selected", self, "_on_focus_mode_selected")

	_add_report_label(_controls_row, "Entity")
	_focus_id_option = _create_report_option_button("FocusIdOption", 300)
	_controls_row.add_child(_focus_id_option)


func _populate_static_report_options() -> void:
	_populate_option_button(_report_mode_option, _REPORT_MODE_ITEMS, "focused")
	_populate_option_button(_focus_mode_option, _FOCUS_MODE_ITEMS, "world")


func _refresh_report_controls() -> void:
	if _report_mode_option == null or _focus_mode_option == null:
		return
	var is_composite_mode: bool = _selected_option_value(_report_mode_option, "focused") == "composite"
	_focus_mode_option.disabled = is_composite_mode
	if is_composite_mode:
		_clear_option_button(_focus_id_option)
		_focus_id_option.add_item("(automatic sampling)")
		_focus_id_option.set_item_metadata(0, "")
		_focus_id_option.select(0)
		_focus_id_option.disabled = true
		return
	_refresh_focus_id_options()


func _refresh_focus_id_options() -> void:
	if _focus_id_option == null:
		return
	var previous_focus_id: String = _selected_option_value(_focus_id_option, "")
	var focus_mode: String = _selected_option_value(_focus_mode_option, "world")
	_clear_option_button(_focus_id_option)
	_focus_id_option.disabled = false

	if focus_mode == "world":
		_focus_id_option.add_item("World")
		_focus_id_option.set_item_metadata(0, "world")
		_focus_id_option.select(0)
		_focus_id_option.disabled = true
		return

	var focus_ids: Array = _current_focus_ids(focus_mode)
	if focus_ids.empty():
		_focus_id_option.add_item("(none available)")
		_focus_id_option.set_item_metadata(0, "")
		_focus_id_option.select(0)
		_focus_id_option.disabled = true
		return

	var selected_index: int = 0
	for focus_id in focus_ids:
		var focus_id_string: String = str(focus_id)
		_focus_id_option.add_item(_focus_id_label(focus_mode, focus_id_string))
		var item_index: int = _focus_id_option.get_item_count() - 1
		_focus_id_option.set_item_metadata(item_index, focus_id_string)
		if focus_id_string == previous_focus_id:
			selected_index = item_index
	_focus_id_option.select(selected_index)


func _current_report_request() -> Dictionary:
	var focus_mode: String = _selected_option_value(_focus_mode_option, "world")
	var focus_id: String = _selected_option_value(_focus_id_option, "world")
	if focus_mode == "world":
		focus_id = "world"
	return {
		"focus_mode": focus_mode,
		"focus_id": focus_id,
		"sort_mode": "chronological",
		"detail_level": "standard",
	}


func _current_composite_request() -> Dictionary:
	return {
		"sort_mode": "chronological",
		"detail_level": "standard",
		"sector_types": _current_sector_types(),
		"agent_roles": _current_agent_roles(),
		"include_persistent": true,
		"include_mortal": true,
	}


func _current_raw_log_request() -> Dictionary:
	return {
		"requested_by": "sim_debug_panel",
		"stream_mode": "continuous",
		"capture_scope": "full_game_state",
	}


func _report_request_header(report_request: Dictionary) -> String:
	var focus_mode: String = str(report_request.get("focus_mode", "world"))
	if focus_mode == "world":
		return "world"
	var focus_id: String = str(report_request.get("focus_id", ""))
	return "%s:%s" % [focus_mode, _focus_id_label(focus_mode, focus_id)]


func _current_focus_ids(focus_mode: String) -> Array:
	if focus_mode == "sector":
		var sector_ids: Array = []
		var seen_sector_ids: Dictionary = {}
		for sector_id in GameState.world_topology.keys():
			var sector_key: String = str(sector_id)
			if seen_sector_ids.has(sector_key):
				continue
			seen_sector_ids[sector_key] = true
			sector_ids.append(sector_key)
		for sector_id in GameState.sector_tags.keys():
			var tag_sector_key: String = str(sector_id)
			if seen_sector_ids.has(tag_sector_key):
				continue
			seen_sector_ids[tag_sector_key] = true
			sector_ids.append(tag_sector_key)
		sector_ids.sort()
		return sector_ids
	if focus_mode == "agent":
		var agent_ids: Array = []
		for agent_id in GameState.agents.keys():
			agent_ids.append(str(agent_id))
		agent_ids.sort()
		return agent_ids
	return ["world"]


func _current_sector_types() -> Array:
	var sector_types: Array = []
	for sector_id in GameState.world_topology.keys():
		var sector_type: String = str(GameState.world_topology.get(sector_id, {}).get("sector_type", ""))
		if sector_type == "" or sector_type in sector_types:
			continue
		sector_types.append(sector_type)
	sector_types.sort()
	return sector_types


func _current_agent_roles() -> Array:
	var agent_roles: Array = []
	for agent_id in GameState.agents.keys():
		if str(agent_id) == "player":
			continue
		var role: String = str(GameState.agents.get(agent_id, {}).get("agent_role", ""))
		if role == "" or role in agent_roles:
			continue
		agent_roles.append(role)
	agent_roles.sort()
	return agent_roles


func _composite_tick_counts_up_to(tick_count: int) -> Array:
	var requested_tick_counts: Array = []
	for milestone in Constants.COMPOSITE_RESEARCH_TICK_COUNTS:
		var milestone_tick_count: int = int(milestone)
		if milestone_tick_count <= tick_count:
			requested_tick_counts.append(milestone_tick_count)
	if requested_tick_counts.empty():
		requested_tick_counts.append(tick_count)
	return requested_tick_counts


func _composite_tick_count_label(tick_counts: Array) -> String:
	var labels: Array = []
	for tick_count in tick_counts:
		labels.append(str(tick_count))
	return PoolStringArray(labels).join(", ")


func _focus_id_label(focus_mode: String, focus_id: String) -> String:
	if focus_mode == "sector":
		return _format_sector_focus_label(focus_id)
	if focus_mode == "agent":
		return _format_agent_focus_label(focus_id)
	return "World"


func _format_sector_focus_label(sector_id: String) -> String:
	if sector_id == "":
		return "(no sector)"
	var sector_name: String = GameState.sector_names.get(sector_id, sector_id)
	if TemplateDatabase.locations.has(sector_id):
		var sector_template = TemplateDatabase.locations.get(sector_id)
		if sector_template != null and sector_template.get("location_name") != null:
			sector_name = str(sector_template.get("location_name"))
	if sector_name == sector_id:
		return sector_id
	return "%s [%s]" % [sector_name, sector_id]


func _format_agent_focus_label(agent_id: String) -> String:
	if agent_id == "player":
		return "Player [player]"
	var agent: Dictionary = GameState.agents.get(agent_id, {})
	if agent.empty():
		return agent_id
	var char_name: String = _get_character_name(str(agent.get("character_id", "")))
	var role: String = str(agent.get("agent_role", "idle"))
	if char_name == agent_id or char_name == "(unnamed)":
		return "%s [%s]" % [agent_id, role]
	return "%s (%s) [%s]" % [char_name, role, agent_id]


func _add_report_label(parent: HBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text + ":"
	label.rect_min_size = Vector2(48, 0)
	parent.add_child(label)


func _create_report_option_button(name: String, min_width: int) -> OptionButton:
	var button := OptionButton.new()
	button.name = name
	button.rect_min_size = Vector2(min_width, 0)
	return button


func _populate_option_button(button: OptionButton, items: Array, default_value: String) -> void:
	if button == null:
		return
	_clear_option_button(button)
	var selected_index: int = 0
	for item in items:
		button.add_item(str(item.get("label", item.get("value", ""))))
		var item_index: int = button.get_item_count() - 1
		button.set_item_metadata(item_index, str(item.get("value", "")))
		if str(item.get("value", "")) == default_value:
			selected_index = item_index
	button.select(selected_index)


func _clear_option_button(button: OptionButton) -> void:
	while button.get_item_count() > 0:
		button.remove_item(0)


func _selected_option_value(button: OptionButton, default_value: String) -> String:
	if button == null:
		return default_value
	var selected_index: int = button.get_selected()
	if selected_index < 0 or selected_index >= button.get_item_count():
		return default_value
	return str(button.get_item_metadata(selected_index))