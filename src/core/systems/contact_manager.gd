# PROJECT: GDTLancer
# MODULE: contact_manager.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: contact_manager.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §2.1, §3.3, §6
# LOG_REF: 2026-05-10 16:13:36
#

extends Node

## ContactManager: Bridges simulation data to gameplay-facing HUD.
## Reads GameState agents/tags/sectors — provides disposition scoring,
## sector agent rosters, and sector condition queries.
## Pure read-only consumer: no GameState mutation, no simulation coupling.


# --- State ---
var _affinity_matrix = null  # AffinityMatrix Reference instance
var _sector_roster_cache: Dictionary = {}  # {sector_id: [agent_id, ...]}
var _disposition_cache: Dictionary = {}  # {agent_id: float}
var _reported_invalid_sectors: Dictionary = {}


# --- Lifecycle ---

func _ready() -> void:
	_affinity_matrix = AffinityMatrix.new()
	GlobalRefs.set_contact_manager(self)
	EventBus.connect("sim_tick_completed", self, "_on_sim_tick_completed")
	EventBus.connect("sim_initialized", self, "_on_sim_initialized")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if GlobalRefs and GlobalRefs.contact_manager == self:
			GlobalRefs.contact_manager = null
		if EventBus:
			if EventBus.is_connected("sim_tick_completed", self, "_on_sim_tick_completed"):
				EventBus.disconnect("sim_tick_completed", self, "_on_sim_tick_completed")
			if EventBus.is_connected("sim_initialized", self, "_on_sim_initialized"):
				EventBus.disconnect("sim_initialized", self, "_on_sim_initialized")
		_sector_roster_cache.clear()
		_disposition_cache.clear()


# --- Signal Handlers ---

func _on_sim_tick_completed(_tick_count) -> void:
	_rebuild_caches()


func _on_sim_initialized(_seed_string) -> void:
	_rebuild_caches()


# --- Public API ---

func get_player_sector() -> String:
	return GameState.agents.get("player", {}).get("current_sector_id", "")


func get_agents_in_sector(sector_id: String) -> Array:
	return _sector_roster_cache.get(sector_id, []).duplicate()


func get_agents_in_player_sector() -> Array:
	return get_agents_in_sector(get_player_sector())


func get_agent_disposition(agent_id: String) -> float:
	return _disposition_cache.get(agent_id, 0.0)


func get_disposition_category(agent_id: String) -> String:
	var score: float = get_agent_disposition(agent_id)
	if score >= Constants.DISPOSITION_FRIENDLY_THRESHOLD:
		return "friendly"
	elif score <= Constants.DISPOSITION_HOSTILE_THRESHOLD:
		return "hostile"
	else:
		return "neutral"


func get_agent_info(agent_id: String) -> Dictionary:
	if not GameState.agents.has(agent_id):
		return {}
	var agent: Dictionary = GameState.agents[agent_id]
	return {
		"agent_id": agent_id,
		"name": _resolve_agent_name(agent_id),
		"role": agent.get("agent_role", "idle"),
		"condition_tag": agent.get("condition_tag", "HEALTHY"),
		"wealth_tag": agent.get("wealth_tag", "COMFORTABLE"),
		"cargo_tag": agent.get("cargo_tag", "EMPTY"),
		"disposition": get_agent_disposition(agent_id),
		"disposition_category": get_disposition_category(agent_id),
		"sector_id": agent.get("current_sector_id", ""),
	}


func get_sector_info(sector_id: String) -> Dictionary:
	var tags: Array = GameState.sector_tags.get(sector_id, [])
	return {
		"sector_id": sector_id,
		"name": _resolve_sector_name(sector_id),
		"economy_tags": _parse_economy_tags(tags),
		"security_tag": _parse_security_tag(tags),
		"environment_tag": _parse_environment_tag(tags),
		"colony_level": GameState.colony_levels.get(sector_id, "frontier"),
		"dominion": GameState.grid_dominion.get(sector_id, {}).get("controlling_faction_id", ""),
		"world_age": GameState.world_age,
		"world_age_timer": GameState.world_age_timer,
		"sim_tick_count": GameState.sim_tick_count,
	}


func get_current_sector_info() -> Dictionary:
	return get_sector_info(get_player_sector())


# --- Private: Cache Rebuild ---

func _rebuild_caches() -> void:
	_sector_roster_cache.clear()
	_disposition_cache.clear()

	var player_sector: String = get_player_sector()
	if player_sector != "" and not GameState.world_topology.has(player_sector):
		_report_invalid_sector("player.current_sector_id", player_sector)
		player_sector = ""

	for agent_id in GameState.agents:
		if agent_id == "player":
			continue
		var agent: Dictionary = GameState.agents[agent_id]
		if agent.get("is_disabled", false):
			continue

		var sid: String = agent.get("current_sector_id", "")
		if sid == "":
			continue
		if not GameState.world_topology.has(sid):
			_report_invalid_sector("%s.current_sector_id" % agent_id, sid)
			continue

		if not _sector_roster_cache.has(sid):
			_sector_roster_cache[sid] = []
		_sector_roster_cache[sid].append(agent_id)

		if sid == player_sector and player_sector != "":
			_disposition_cache[agent_id] = _compute_player_disposition(agent_id)

	if player_sector != "":
		EventBus.emit_signal("sector_contacts_changed", player_sector)


func _compute_player_disposition(agent_id: String) -> float:
	var player_tags: Array = GameState.agent_tags.get("player", [])
	var agent_tags: Array = GameState.agent_tags.get(agent_id, [])
	return _affinity_matrix.compute_affinity(player_tags, agent_tags)


func _report_invalid_sector(context: String, sector_id: String) -> void:
	var normalized_sector_id: String = sector_id if sector_id != "" else "<empty>"
	var report_key = "%s:%s" % [context, normalized_sector_id]
	if _reported_invalid_sectors.has(report_key):
		return
	_reported_invalid_sectors[report_key] = true
	printerr(
		"ContactManager: Skipping invalid sector reference for %s -> %s." % [
			context,
			normalized_sector_id,
		]
	)


# --- Private: Name Resolution ---

func _resolve_agent_name(agent_id: String) -> String:
	if not GameState.agents.has(agent_id):
		return agent_id
	var agent: Dictionary = GameState.agents[agent_id]
	var character_id: String = agent.get("character_id", "")
	if character_id == "":
		return agent_id

	# Try TemplateDatabase first (Resource with character_name property)
	if TemplateDatabase.characters.has(character_id):
		var template = TemplateDatabase.characters[character_id]
		if template and "character_name" in template:
			return template.character_name

	# Fallback to GameState.characters (Dict with "character_name" key)
	if GameState.characters.has(character_id):
		var char_data = GameState.characters[character_id]
		if char_data is Dictionary and char_data.has("character_name"):
			return char_data["character_name"]

	return agent_id


func _resolve_sector_name(sector_id: String) -> String:
	# Try TemplateDatabase first (Resource with location_name property)
	if TemplateDatabase.locations.has(sector_id):
		var template = TemplateDatabase.locations[sector_id]
		if template and "location_name" in template:
			return template.location_name

	# Fallback to GameState.sector_names
	return GameState.sector_names.get(sector_id, sector_id)


# --- Private: Tag Parsing ---

func _parse_security_tag(tags: Array) -> String:
	for tag in ["SECURE", "CONTESTED", "LAWLESS"]:
		if tag in tags:
			return tag
	return "UNKNOWN"


func _parse_environment_tag(tags: Array) -> String:
	for tag in ["MILD", "HARSH", "EXTREME"]:
		if tag in tags:
			return tag
	return "UNKNOWN"


func _parse_economy_tags(tags: Array) -> Array:
	var result: Array = []
	for tag in tags:
		if tag.ends_with("_RICH") or tag.ends_with("_ADEQUATE") or tag.ends_with("_POOR"):
			result.append(tag)
	return result