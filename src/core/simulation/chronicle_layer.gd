#
# PROJECT: GDTLancer
# MODULE: chronicle_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_9
# LOG_REF: 2026-02-21 (TASK_9)
#

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
	var packet: Dictionary = event_packet.duplicate()
	if not packet.has("tick"):
		packet["tick"] = GameState.sim_tick_count
	if not packet.has("actor_id"):
		packet["actor_id"] = "unknown"
	if not packet.has("action"):
		packet["action"] = "unknown"
	if not packet.has("sector_id"):
		packet["sector_id"] = ""
	if not packet.has("metadata"):
		packet["metadata"] = {}
	_staging_buffer.append(packet)


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
		var loc: Resource = TemplateDatabase.locations[sector_id]
		if is_instance_valid(loc) and loc.get("location_name") != null:
			return loc.location_name
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
		"age_change":
			return "reported a world-age shift"
		_:
			return action
