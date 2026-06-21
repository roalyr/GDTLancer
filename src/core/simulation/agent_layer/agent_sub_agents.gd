# PROJECT: GDTLancer
# MODULE: agent_sub_agents.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: STRATEGICAL-TODO.md §4.1; TRUTH_GAME-LOOP-VISION.md § 1.3
# LOG_REF: 2026-06-20 20:31:00

extends Reference

var _agent_layer: Reference

func initialize(agent_layer_ref: Reference) -> void:
	_agent_layer = agent_layer_ref


## Transfers a sub-agent from one host to another, applying a morale penalty.
func sub_agent_transfer(sub_agent_id: String, from_host_id: String, to_host_id: String) -> bool:
	if not GameState.agents.has(from_host_id) or not GameState.agents.has(to_host_id):
		return false
	
	var from_agent = GameState.agents[from_host_id]
	var to_agent = GameState.agents[to_host_id]
	
	if not from_agent.has("sub_agents") or not to_agent.has("sub_agents"):
		return false
	
	if not from_agent["sub_agents"].has(sub_agent_id):
		return false
	
	var sub_agent: Dictionary = from_agent["sub_agents"][sub_agent_id]
	from_agent["sub_agents"].erase(sub_agent_id)
	
	var current_morale: int = sub_agent.get("morale", 0)
	sub_agent["morale"] = current_morale + Constants.SUB_AGENT_TRANSFER_MORALE_PENALTY
	
	to_agent["sub_agents"][sub_agent_id] = sub_agent
	return true


## Updates supplies ticks and morale values for a given agent on each tick.
func process_agent_supplies_and_morale(agent_id: String, agent: Dictionary) -> void:
	if agent.get("is_disabled", false):
		return

	# Automatic replenishment when at a sector with a station / trade service
	var current_sector = agent.get("current_sector_id", "")
	if current_sector != "":
		var has_station = false
		if GameState.world_topology.has(current_sector):
			var station_ids = GameState.world_topology[current_sector].get("station_ids", [])
			if not station_ids.empty():
				has_station = true
		if has_station:
			agent["supplies_tag"] = "SUPPLIES_ADEQUATE"
			agent["supplies_ticks_remaining"] = Constants.SUPPLIES_DEGRADATION_TICKS

	# 1. Update Supplies degradation
	var supplies_tag = agent.get("supplies_tag", "SUPPLIES_ADEQUATE")
	if supplies_tag != "SUPPLIES_NONE":
		var ticks_rem = int(agent.get("supplies_ticks_remaining", Constants.SUPPLIES_DEGRADATION_TICKS))
		ticks_rem -= 1
		if ticks_rem <= 0:
			if supplies_tag == "SUPPLIES_ADEQUATE":
				agent["supplies_tag"] = "SUPPLIES_LOW"
				agent["supplies_ticks_remaining"] = Constants.SUPPLIES_DEGRADATION_TICKS
			elif supplies_tag == "SUPPLIES_LOW":
				agent["supplies_tag"] = "SUPPLIES_NONE"
				agent["supplies_ticks_remaining"] = 0
		else:
			agent["supplies_ticks_remaining"] = ticks_rem

	# 2. Update Morale decay
	var sub_agents_dict = agent.get("sub_agents", {})
	if sub_agents_dict is Dictionary and not sub_agents_dict.empty():
		var sector_id = agent.get("current_sector_id", "")
		var sector_tags = GameState.sector_tags.get(sector_id, [])
		var is_hazard = "HARSH" in sector_tags or "EXTREME" in sector_tags
		var is_starving = agent.get("supplies_tag", "") == "SUPPLIES_NONE"

		for sub_agent_id in sub_agents_dict:
			var sub_agent = sub_agents_dict[sub_agent_id]
			if not sub_agent is Dictionary:
				continue
			
			var morale = int(sub_agent.get("morale", Constants.MORALE_INITIAL))
			
			# Sector environment decay
			if is_hazard:
				var hazard_ticks = int(sub_agent.get("consecutive_hazard_ticks", 0)) + 1
				if hazard_ticks >= Constants.MORALE_DECAY_CONSECUTIVE_TICKS_LIMIT:
					morale += Constants.MORALE_DECAY_AMOUNT # Constants.MORALE_DECAY_AMOUNT is -5
					hazard_ticks = 0
				sub_agent["consecutive_hazard_ticks"] = hazard_ticks
			else:
				sub_agent["consecutive_hazard_ticks"] = 0
				
			# Starvation penalty
			if is_starving:
				morale += Constants.MORALE_DECAY_STARVATION_AMOUNT # Constants.MORALE_DECAY_STARVATION_AMOUNT is -10
			
			# Clamp morale
			sub_agent["morale"] = clamp(morale, Constants.MORALE_MIN, Constants.MORALE_MAX)

	# 3. Check mutiny condition (Aggregate Morale reaches 0)
	if agent_id == "player":
		if sub_agents_dict is Dictionary and not sub_agents_dict.empty():
			var avg_morale = get_average_crew_morale(agent_id)
			if avg_morale == 0:
				agent["is_mutiny_active"] = true


## Computes the raw average morale of all sub-agents.
func get_average_crew_morale(agent_id: String) -> float:
	if not GameState.agents.has(agent_id):
		return 0.0
	var agent: Dictionary = GameState.agents[agent_id]
	var sub_agents_dict = agent.get("sub_agents", {})
	if not sub_agents_dict is Dictionary or sub_agents_dict.empty():
		return 0.0
	
	var total_morale: float = 0.0
	var count: int = 0
	for sub_agent_id in sub_agents_dict:
		var sub_agent = sub_agents_dict[sub_agent_id]
		if sub_agent is Dictionary:
			total_morale += sub_agent.get("morale", Constants.MORALE_INITIAL)
			count += 1
			
	if count == 0:
		return 0.0
	return total_morale / count


## Calculates the aggregate morale modifier for an agent's crew.
func get_crew_morale_modifier(agent_id: String) -> int:
	if not GameState.agents.has(agent_id):
		return 0
	var agent: Dictionary = GameState.agents[agent_id]
	var sub_agents_dict = agent.get("sub_agents", {})
	if not sub_agents_dict is Dictionary or sub_agents_dict.empty():
		return 0
	
	var avg_morale = get_average_crew_morale(agent_id)
	if avg_morale >= Constants.MORALE_MODIFIER_HIGH_THRESHOLD: # >= 80
		return 2
	elif avg_morale >= Constants.MORALE_MODIFIER_LOW_THRESHOLD: # >= 40
		return 0
	elif avg_morale > Constants.MORALE_MIN: # > 0 and < 40
		return -2
	else: # == 0
		return -4
