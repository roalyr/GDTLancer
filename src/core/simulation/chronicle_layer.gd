#
# PROJECT: GDTLancer
# MODULE: chronicle_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 5 (Chronicle Layer), Section 7 (Tick Sequence steps 5a–5e)
# LOG_REF: 2026-02-13
#

extends Reference

## ChronicleLayer: Event capture and rumor generation (Layer 4).
##
## The Chronicle records notable events that occur during simulation ticks,
## generates human-readable rumor strings, and distributes relevant events
## to agents' event_memory arrays for future decision-making.
##
## Processing (GDD Section 7, steps 5a–5e):
##   5a. Collect — move staged events to chronicle_event_buffer
##   5b. Tag Causality — Phase 1 stub (events are independent)
##   5c. Significance Scores — Phase 1 stub (all events = 0.5)
##   5d. Rumor Engine — generate templated text from event packets
##   5e. Distribute — push relevant events to nearby agents' event_memory
##
## Event Packet schema (GDD Section 5.1):
##   {actor_uid, action_id, target_uid, target_sector_id, tick_count, outcome, metadata}


## Staging buffer — events logged during the current tick wait here until
## process_tick() moves them into the chronicle_event_buffer.
var _staging_buffer: Array = []

## Maximum number of events to keep in chronicle_event_buffer (ring buffer).
var _max_buffer_size: int = 200

## Maximum number of rumors to keep.
var _max_rumors: int = 50

## Maximum events in an agent's event_memory.
var _max_agent_memory: int = 20


# =============================================================================
# === PUBLIC API ==============================================================
# =============================================================================

## Logs a notable event for processing in the next tick.
## Called by other systems (AgentLayer, GridLayer, etc.) when something happens.
##
## @param event_packet  Dictionary — must follow the Event Packet schema:
##   {actor_uid: int/String, action_id: String, target_uid: int/String,
##    target_sector_id: String, tick_count: int, outcome: String, metadata: Dictionary}
func log_event(event_packet: Dictionary) -> void:
	# Ensure required fields exist with defaults
	if not event_packet.has("tick_count"):
		event_packet["tick_count"] = GameState.sim_tick_count
	if not event_packet.has("outcome"):
		event_packet["outcome"] = "success"
	if not event_packet.has("metadata"):
		event_packet["metadata"] = {}

	_staging_buffer.append(event_packet)


## Processes all Chronicle Layer steps for one tick.
func process_tick() -> void:
	if _staging_buffer.empty():
		return

	# 5a. Collect: move staged events into chronicle_event_buffer
	var new_events: Array = _collect_events()

	# 5b. Tag Causality (Phase 1 stub: events are independent)
	_tag_causality(new_events)

	# 5c. Significance Scores (Phase 1 stub: all get 0.5)
	_score_significance(new_events)

	# 5d. Rumor Engine: generate text strings
	var new_rumors: Array = _generate_rumors(new_events)

	# 5e. Distribute: push events to nearby agents
	_distribute_events(new_events)

	# Append new rumors to chronicle
	for rumor in new_rumors:
		GameState.chronicle_rumors.append(rumor)
	# Trim to max size
	while GameState.chronicle_rumors.size() > _max_rumors:
		GameState.chronicle_rumors.pop_front()


# =============================================================================
# === STEP 5a: COLLECT ========================================================
# =============================================================================

## Moves all pending events from the staging buffer into chronicle_event_buffer.
## Returns the batch of newly added events for further processing.
func _collect_events() -> Array:
	var batch: Array = _staging_buffer.duplicate()
	_staging_buffer.clear()

	# Append to chronicle buffer
	for event in batch:
		GameState.chronicle_event_buffer.append(event)

	# Trim buffer to max size (ring buffer behavior)
	while GameState.chronicle_event_buffer.size() > _max_buffer_size:
		GameState.chronicle_event_buffer.pop_front()

	return batch


# =============================================================================
# === STEP 5b: TAG CAUSALITY =================================================
# =============================================================================

## Tags causal relationships between events.
## Phase 1 stub: all events are independent — no causality chains.
func _tag_causality(events: Array) -> void:
	for event in events:
		event["causality_chain"] = []  # No linked events
		event["is_root_cause"] = true


# =============================================================================
# === STEP 5c: SIGNIFICANCE SCORES ===========================================
# =============================================================================

## Assigns significance scores to events.
## Phase 1 stub: all events receive a flat score of 0.5.
## Future: score based on actor importance, rarity, economic impact, etc.
func _score_significance(events: Array) -> void:
	for event in events:
		event["significance"] = 0.5


# =============================================================================
# === STEP 5d: RUMOR ENGINE ===================================================
# =============================================================================

## Generates human-readable rumor strings from event packets.
## Phase 1: simple template — "[Actor] [action] at [Location]."
func _generate_rumors(events: Array) -> Array:
	var rumors: Array = []

	for event in events:
		var rumor: String = _format_rumor(event)
		if rumor != "":
			rumors.append(rumor)

	return rumors


## Formats a single event packet into a rumor string.
func _format_rumor(event: Dictionary) -> String:
	var actor_name: String = _resolve_actor_name(event.get("actor_uid", ""))
	var action: String = _humanize_action(event.get("action_id", "unknown"))
	var location_name: String = _resolve_location_name(event.get("target_sector_id", ""))

	if actor_name == "" or location_name == "":
		return ""

	# Add target/detail info from metadata if available
	var detail: String = ""
	var metadata: Dictionary = event.get("metadata", {})
	if metadata.has("commodity_id"):
		detail = " " + _humanize_id(metadata["commodity_id"])
	if metadata.has("quantity"):
		detail += " (x%d)" % int(metadata["quantity"])

	var outcome: String = event.get("outcome", "success")
	if outcome != "success":
		return "%s tried to %s%s at %s, but failed." % [actor_name, action, detail, location_name]

	return "%s %s%s at %s." % [actor_name, action, detail, location_name]


# =============================================================================
# === STEP 5e: DISTRIBUTE ====================================================
# =============================================================================

## Distributes relevant events to nearby agents' event_memory arrays.
## "Nearby" = agents in the same sector as the event, or connected sectors.
func _distribute_events(events: Array) -> void:
	for event in events:
		var event_sector: String = event.get("target_sector_id", "")
		if event_sector == "":
			continue

		# Get connected sectors (event is "heard" in adjacent sectors too)
		var relevant_sectors: Array = [event_sector]
		if GameState.world_topology.has(event_sector):
			var connections: Array = GameState.world_topology[event_sector].get("connections", [])
			for conn in connections:
				relevant_sectors.append(conn)

		# Push event to agents in relevant sectors
		for agent_id in GameState.agents:
			var agent: Dictionary = GameState.agents[agent_id]
			if agent.get("is_disabled", false):
				continue

			var agent_sector: String = agent.get("current_sector_id", "")
			if agent_sector in relevant_sectors:
				var memory: Array = agent.get("event_memory", [])
				memory.append(event)

				# Trim to max memory size (oldest first)
				while memory.size() > _max_agent_memory:
					memory.pop_front()

				agent["event_memory"] = memory


# =============================================================================
# === PRIVATE — NAME RESOLUTION ===============================================
# =============================================================================

## Resolves an actor UID to a human-readable name.
func _resolve_actor_name(actor_uid) -> String:
	# Check if it's a string agent_id (e.g., "persistent_vera", "player")
	if actor_uid is String:
		if actor_uid == "player":
			return "You"
		# Try to find character name via agent → char_uid → character template
		if GameState.agents.has(actor_uid):
			var agent: Dictionary = GameState.agents[actor_uid]
			var char_uid: int = agent.get("char_uid", -1)
			if GameState.characters.has(char_uid):
				var char_template: Resource = GameState.characters[char_uid]
				if char_template != null:
					return char_template.character_name
		# Fallback: humanize the ID
		return _humanize_id(actor_uid)

	# Numeric UID — look up directly in characters
	if actor_uid is int and GameState.characters.has(actor_uid):
		var char_template: Resource = GameState.characters[actor_uid]
		if char_template != null:
			return char_template.character_name

	return "Someone"


## Resolves a sector ID to a human-readable location name.
func _resolve_location_name(sector_id: String) -> String:
	if sector_id == "":
		return ""

	# Try TemplateDatabase for the location name
	if TemplateDatabase.locations.has(sector_id):
		var loc: Resource = TemplateDatabase.locations[sector_id]
		if is_instance_valid(loc):
			return loc.location_name

	# Fallback: humanize the ID
	return _humanize_id(sector_id)


## Converts an action_id into past-tense human text.
func _humanize_action(action_id: String) -> String:
	match action_id:
		"buy":
			return "bought"
		"sell":
			return "sold"
		"move":
			return "arrived"
		"repair":
			return "repaired their ship"
		"dock":
			return "docked"
		"undock":
			return "departed"
		"destroy":
			return "destroyed a target"
		"disabled":
			return "was disabled"
		"trade":
			return "traded"
		"respawn":
			return "returned"
		_:
			return action_id


## Converts a snake_case ID into Title Case display text.
## e.g., "commodity_ore" → "Ore", "station_alpha" → "Station Alpha"
func _humanize_id(id: String) -> String:
	# Strip common prefixes
	var stripped: String = id
	for prefix in ["commodity_", "persistent_", "character_", "faction_"]:
		if stripped.begins_with(prefix):
			stripped = stripped.substr(prefix.length())
			break

	# Convert underscores to spaces and capitalize
	var parts: Array = stripped.split("_")
	var result: Array = []
	for part in parts:
		if part.length() > 0:
			result.append(part.capitalize())
	return PoolStringArray(result).join(" ")
