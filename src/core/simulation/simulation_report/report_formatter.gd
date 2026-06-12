#
# PROJECT: GDTLancer
# MODULE: report_formatter.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context
# LOG_REF: 2026-06-12 23:55:00
#

extends Reference

var _report: Reference

func initialize(report_ref: Reference) -> void:
	_report = report_ref


func format_action_totals(action_totals: Dictionary) -> Array:
	var parts: Array = []
	for action in _report._sorted_keys(action_totals):
		parts.append("%s=%d" % [action, int(action_totals[action])])
	return parts


func format_count_entries(counts: Dictionary, mode: String) -> String:
	var parts: Array = []
	for key in _report._sorted_keys(counts):
		var label: String = str(key)
		if mode == "agent":
			label = actor_label_with_id(str(key))
		elif mode == "sector":
			label = sector_label_with_id(str(key))
		parts.append("%s=%d" % [label, int(counts[key])])
	return PoolStringArray(parts).join(", ")


func format_detailed_event(event: Dictionary) -> String:
	var tick: int = int(event.get("tick", 0))
	var actor_id: String = str(event.get("actor_id", ""))
	var sector_id: String = str(event.get("sector_id", ""))
	var action: String = str(event.get("action", "unknown"))
	var base_line: String = "T%s [%s] %s %s" % [
		pad_int(tick, 4),
		sector_label_with_id(sector_id),
		actor_label_with_id(actor_id),
		humanize_action(action),
	]

	var metadata: Dictionary = event.get("metadata", {})
	if metadata.empty():
		return base_line

	var detail_level: String = str(_report._report_request.get("detail_level", "standard"))
	var max_items: int = 3
	if detail_level == "verbose":
		max_items = -1
	var metadata_text: String = format_metadata(metadata, max_items)
	if metadata_text == "":
		return base_line
	return "%s | %s" % [base_line, metadata_text]


func format_metadata(metadata: Dictionary, max_items: int) -> String:
	var keys: Array = _report._sorted_keys(metadata)
	if keys.empty():
		return ""

	var parts: Array = []
	var item_count: int = 0
	for key in keys:
		if max_items >= 0 and item_count >= max_items:
			break
		parts.append("%s=%s" % [key, format_metadata_value(str(key), metadata[key])])
		item_count += 1

	if max_items >= 0 and keys.size() > max_items:
		parts.append("+%d more" % (keys.size() - max_items))

	return PoolStringArray(parts).join("; ")


func format_metadata_value(key: String, value) -> String:
	if key in ["from", "target_sector_id", "source_sector_id", "requested_from", "new_sector"]:
		return sector_label_with_id(str(value))
	if key in ["target", "claimant_agent_id"]:
		return actor_label_with_id(str(value))
	if value is Array:
		var values: Array = []
		for item in value:
			if key == "connections":
				values.append(sector_label_with_id(str(item)))
			else:
				values.append(str(item))
		return "[%s]" % PoolStringArray(values).join(", ")
	return str(value)


func sort_events_by_request(a: Dictionary, b: Dictionary) -> bool:
	return event_sort_key(a) < event_sort_key(b)


func event_sort_key(event: Dictionary) -> String:
	var tick_key: String = pad_int(int(event.get("tick", 0)), 8)
	var sector_key: String = sector_label_with_id(str(event.get("sector_id", ""))).to_lower()
	var actor_key: String = actor_label_with_id(str(event.get("actor_id", ""))).to_lower()
	var action_key: String = str(event.get("action", "")).to_lower()
	match str(_report._report_request.get("sort_mode", "chronological")):
		"sector":
			return "%s|%s|%s|%s" % [sector_key, tick_key, actor_key, action_key]
		"agent":
			return "%s|%s|%s|%s" % [actor_key, tick_key, sector_key, action_key]
		_:
			return "%s|%s|%s|%s" % [tick_key, sector_key, actor_key, action_key]


func pad_int(value: int, width: int) -> String:
	var text: String = str(value)
	while text.length() < width:
		text = "0" + text
	return text


func loc(sector_id: String) -> String:
	if sector_id == "":
		return "deep space"
	if TemplateDatabase.locations.has(sector_id):
		var location_res: Resource = TemplateDatabase.locations[sector_id]
		if is_instance_valid(location_res) and location_res.get("location_name") != null:
			return location_res.location_name
	if GameState.sector_names.has(sector_id):
		return GameState.sector_names[sector_id]
	return sector_id


func agent_display(agent_id: String) -> String:
	var agent: Dictionary = GameState.agents.get(agent_id, {})
	var char_id: String = str(agent.get("character_id", ""))
	var name: String = resolve_character_name(char_id, agent_id)
	var role: String = str(agent.get("agent_role", ""))
	if role != "":
		return "%s (%s)" % [name, role]
	return name


func resolve_character_name(char_id: String, fallback: String = "") -> String:
	if char_id == "":
		return fallback if fallback != "" else "(unnamed)"
	if GameState.characters.has(char_id):
		var c = GameState.characters[char_id]
		if c is Resource and c.get("character_name") != null:
			return c.character_name
		elif c is Dictionary and c.has("character_name"):
			return c["character_name"]
	return char_id


func sector_label_with_id(sector_id: String) -> String:
	if sector_id == "":
		return "deep space"
	var label: String = loc(sector_id)
	if label == sector_id:
		return sector_id
	return "%s/%s" % [label, sector_id]


func actor_label_with_id(actor_id: String) -> String:
	if actor_id == "":
		return "unknown"
	var label: String = agent_display(actor_id)
	if label == actor_id:
		return actor_id
	return "%s/%s" % [label, actor_id]


func humanize_action(action: String) -> String:
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


func economy_label(tags: Array) -> String:
	for level in ["rich", "adequate", "poor"]:
		for t in tags:
			if str(t).to_lower().ends_with("_" + level):
				return level
	return "adequate"


func security_label(tags: Array) -> String:
	for t in ["SECURE", "CONTESTED", "LAWLESS"]:
		if t in tags:
			return t.to_lower()
	return "contested"


func environment_label(tags: Array) -> String:
	for t in ["MILD", "HARSH", "EXTREME"]:
		if t in tags:
			return t.to_lower()
	return "mild"
