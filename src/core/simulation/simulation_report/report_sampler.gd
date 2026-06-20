# PROJECT: GDTLancer
# MODULE: report_sampler.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: report_sampler.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context
# LOG_REF: 2026-06-12 23:55:00
#

extends Reference

var _report: Reference

func initialize(report_ref: Reference) -> void:
	_report = report_ref


func sample_sector_ids_by_type(window_tick_count: int, composite_request: Dictionary) -> Dictionary:
	var requested_sector_types: Array = Array(composite_request.get("sector_types", []))
	var candidates_by_type: Dictionary = {}
	for sector_id in _report._sorted_keys(GameState.world_topology):
		var topology: Dictionary = GameState.world_topology.get(sector_id, {})
		var sector_type: String = str(topology.get("sector_type", "unknown"))
		if sector_type == "":
			sector_type = "unknown"
		if not requested_sector_types.empty() and not (sector_type in requested_sector_types):
			continue
		if not candidates_by_type.has(sector_type):
			candidates_by_type[sector_type] = []
		candidates_by_type[sector_type].append(str(sector_id))

	var samples: Dictionary = {}
	for sector_type in _report._sorted_keys(candidates_by_type):
		var sector_ids: Array = Array(candidates_by_type[sector_type])
		sector_ids.sort()
		if sector_ids.empty():
			continue
		var sample_index: int = deterministic_index(sector_ids.size(), "%s:sector:%s:%d" % [_report._seed, str(sector_type), window_tick_count])
		samples[sector_type] = str(sector_ids[sample_index])
	return samples


func sample_agent_entries(window_tick_count: int, composite_request: Dictionary) -> Array:
	var requested_agent_roles: Array = Array(composite_request.get("agent_roles", []))
	var include_persistent: bool = bool(composite_request.get("include_persistent", true))
	var include_mortal: bool = bool(composite_request.get("include_mortal", true))
	var candidates_by_class_and_role: Dictionary = {}

	for agent_id in _report._sorted_keys(GameState.agents):
		if str(agent_id) == "player":
			continue
		var agent: Dictionary = GameState.agents.get(agent_id, {})
		if bool(agent.get("is_disabled", false)):
			continue
		var agent_role: String = str(agent.get("agent_role", "idle"))
		if not requested_agent_roles.empty() and not (agent_role in requested_agent_roles):
			continue
		var agent_class: String = "persistent" if bool(agent.get("is_persistent", false)) else "mortal"
		if agent_class == "persistent" and not include_persistent:
			continue
		if agent_class == "mortal" and not include_mortal:
			continue
		var group_key: String = "%s|%s" % [agent_class, agent_role]
		if not candidates_by_class_and_role.has(group_key):
			candidates_by_class_and_role[group_key] = []
		candidates_by_class_and_role[group_key].append(str(agent_id))

	var samples: Array = []
	for group_key in _report._sorted_keys(candidates_by_class_and_role):
		var agent_ids: Array = Array(candidates_by_class_and_role[group_key])
		agent_ids.sort()
		if agent_ids.empty():
			continue
		var parts: Array = str(group_key).split("|")
		var sample_index: int = deterministic_index(agent_ids.size(), "%s:agent:%s:%d" % [_report._seed, str(group_key), window_tick_count])
		samples.append({
			"agent_id": str(agent_ids[sample_index]),
			"agent_class": str(parts[0]),
			"agent_role": str(parts[1]),
		})
	return samples


func deterministic_index(size: int, key: String) -> int:
	if size <= 1:
		return 0
	var hashed_value: int = int(hash(key))
	if hashed_value < 0:
		hashed_value = -hashed_value
	return hashed_value % size