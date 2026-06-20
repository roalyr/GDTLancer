# PROJECT: GDTLancer
# MODULE: chronicle_layer.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: GDD-MASTER-DESIGN-DIRECTIVE.md §2.2, §7.4; TRUTH_GAME-LOOP-VISION.md §5.2
# LOG_REF: 2026-06-20 19:57:00

extends Reference

## ChronicleLayer: Event capture, rumor generation, and memory distribution.
##
## Logs events during a tick, processes them into rumors, and distributes
## relevant events to nearby agents' event_memory arrays.
##
## Python reference: python_sandbox/core/simulation/chronicle_layer.py


var _staging_buffer: Array = []
var _max_events: int = 200
var _max_rumors: int = 50
var _max_agent_memory: int = 20


# =============================================================================
# === PUBLIC API ==============================================================
# =============================================================================

## Logs a notable event for processing in the next tick.
##
## @param event_packet  Dictionary — {tick, actor_id, action, sector_id, metadata}
func log_event(event_packet: Dictionary) -> void:
	var packet: Dictionary = _normalize_event_packet(event_packet)
	_staging_buffer.append(packet)


func _normalize_event_packet(event_packet: Dictionary) -> Dictionary:
	var packet: Dictionary = event_packet.duplicate(true)
	if not packet.has("tick"):
		packet["tick"] = GameState.sim_tick_count
	if not packet.has("actor_id"):
		packet["actor_id"] = "unknown"
	if not packet.has("action"):
		packet["action"] = "unknown"
	if not packet.has("sector_id"):
		packet["sector_id"] = ""
	if not packet.has("metadata") or not (packet.get("metadata", {}) is Dictionary):
		packet["metadata"] = {}
	else:
		packet["metadata"] = packet.get("metadata", {}).duplicate(true)
	return packet


## Processes all Chronicle Layer steps for one tick.
func process_tick() -> void:
	if _staging_buffer.empty():
		return

	var events: Array = _collect_events()
	var rumors: Array = _generate_rumors(events)
	_distribute_events(events)

	for rumor in rumors:
		GameState.chronicle_rumors.append(rumor)
	while GameState.chronicle_rumors.size() > _max_rumors:
		GameState.chronicle_rumors.pop_front()


# =============================================================================
# === PRIVATE — COLLECT =======================================================
# =============================================================================

func _collect_events() -> Array:
	var events: Array = _staging_buffer.duplicate()
	_staging_buffer.clear()

	for event in events:
		GameState.chronicle_events.append(event)
	while GameState.chronicle_events.size() > _max_events:
		GameState.chronicle_events.pop_front()

	return events


# =============================================================================
# === PRIVATE — RUMOR GENERATION ==============================================
# =============================================================================

func _generate_rumors(_events: Array) -> Array:
	var rumors: Array = []
	for event in _events:
		var rumor: String = _format_rumor(event)
		if rumor != "":
			rumors.append(rumor)
	return rumors


func _format_rumor(event: Dictionary) -> String:
	var actor: String = _resolve_actor_name(event.get("actor_id", ""))
	var action: String = _humanize_action(event.get("action", "unknown"))
	var sector: String = _resolve_location_name(event.get("sector_id", ""))
	if actor == "" or sector == "":
		return ""
	return "%s %s at %s." % [actor, action, sector]


# =============================================================================
# === PRIVATE — EVENT DISTRIBUTION ============================================
# =============================================================================

func _distribute_events(events: Array) -> void:
	for event in events:
		var sector_id: String = event.get("sector_id", "")
		if sector_id == "":
			continue

		# Visible sectors: event sector + connections
		var visible: Array = [sector_id]
		var connections: Array = GameState.world_topology.get(sector_id, {}).get("connections", [])
		for conn in connections:
			visible.append(conn)

		for agent_id in GameState.agents:
			var agent: Dictionary = GameState.agents[agent_id]
			if agent.get("is_disabled", false):
				continue
			if not (agent.get("current_sector_id", "") in visible):
				continue

			var memory: Array = Array(agent.get("event_memory", []))
			memory.append(event)
			while memory.size() > _max_agent_memory:
				memory.pop_front()
			agent["event_memory"] = memory


# =============================================================================
# === PRIVATE — NAME RESOLUTION ===============================================
# =============================================================================

func _resolve_actor_name(actor_id: String) -> String:
	if actor_id == "player":
		return "You"
	if GameState.agents.has(actor_id):
		var character_id: String = GameState.agents[actor_id].get("character_id", "")
		if GameState.characters.has(character_id):
			var char_data = GameState.characters[character_id]
			if char_data is Dictionary:
				return char_data.get("character_name", str(actor_id))
			elif char_data is Resource and char_data.get("character_name") != null:
				return char_data.character_name
	return str(actor_id)


func _resolve_location_name(sector_id: String) -> String:
	if sector_id == "":
		return ""
	# Try TemplateDatabase
	if TemplateDatabase.locations.has(sector_id):
		var loc = TemplateDatabase.locations[sector_id]
		if loc is Dictionary:
			return str(loc.get("location_name", sector_id))
		if loc is Resource and is_instance_valid(loc) and loc.get("location_name") != null:
			return str(loc.location_name)
	# Try sector_names in GameState
	if GameState.sector_names.has(sector_id):
		return GameState.sector_names[sector_id]
	return sector_id


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


## Resolves a narrative template based on sector and event type.
func resolve_narrative_template(sector_id: String, event_type: String) -> Resource:
	var sector_type = "star"
	if GameState.world_topology.has(sector_id):
		var topo = GameState.world_topology[sector_id]
		if topo.has("sector_type"):
			sector_type = topo["sector_type"]
			
	var economy_tag = "RAW_ADEQUATE"
	if GameState.sector_tags.has(sector_id):
		for tag in GameState.sector_tags[sector_id]:
			if tag.begins_with("RAW_") or tag.begins_with("MANUFACTURED_") or tag.begins_with("CURRENCY_"):
				economy_tag = tag
				break
				
	var security_tag = "LAWLESS"
	if GameState.sector_tags.has(sector_id):
		for tag in ["SECURE", "CONTESTED", "LAWLESS"]:
			if tag in GameState.sector_tags[sector_id]:
				security_tag = tag
				break
				
	var base_path = "res://database/registry/narratives"
	
	# Try 1: Full path
	var path1 = "%s/%s/%s/%s/%s.tres" % [base_path, sector_type, economy_tag, security_tag, event_type]
	var res = _safe_load_narrative(path1)
	if res != null:
		return res
		
	# Try 2: Replace event_type with "default"
	var path2 = "%s/%s/%s/%s/default.tres" % [base_path, sector_type, economy_tag, security_tag]
	res = _safe_load_narrative(path2)
	if res != null:
		return res
		
	# Try 3: Replace security_tag with "default"
	var path3 = "%s/%s/%s/default/default.tres" % [base_path, sector_type, economy_tag]
	res = _safe_load_narrative(path3)
	if res != null:
		return res
		
	# Try 4: Coarser sector default
	var path4 = "%s/%s/default.tres" % [base_path, sector_type]
	res = _safe_load_narrative(path4)
	if res != null:
		return res
		
	# Try 5: Global default
	var path5 = "%s/default.tres" % base_path
	res = _safe_load_narrative(path5)
	if res != null:
		return res
		
	# Fallback code-driven resource
	var fallback_res = load("res://database/definitions/narrative_template.gd").new()
	fallback_res.title = "Local Transmission"
	fallback_res.body_text = "Static interference on the local frequency. The sector is quiet."
	fallback_res.creole_dialect = "Standard"
	return fallback_res


func _safe_load_narrative(path: String) -> Resource:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Resource:
			return res
	return null
