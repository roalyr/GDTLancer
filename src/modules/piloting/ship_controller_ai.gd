# ShipControllerAI: patrol / combat / flee state machine for NPC agents.
# Uses the same commands and ToolController as the player. Child of AgentBody in npc_agent.tscn.

extends Node

enum AIState { IDLE, PATROL, COMBAT, FLEE, DISABLED }


var is_hostile: bool = false

var agent_script: RigidBody = null
var _tool_controller: Node = null
var _current_state: int = AIState.IDLE
var _target_agent: RigidBody = null
var _home_position: Vector3 = Vector3.ZERO
var _patrol_destination: Vector3 = Vector3.ZERO
var _has_patrol_destination: bool = false
var _repath_timer: float = 0.0
var _scan_timer: float = 0.0
var _orbiting: bool = false
var _provoked: bool = false  # Shot at: chase the attacker from any distance


func _ready() -> void:
	var parent = get_parent()
	if not (parent is RigidBody and parent.has_method("command_move_to")):
		printerr("AI Controller Error: Parent node is not an Agent RigidBody with command methods!")
		set_physics_process(false)
		return
	agent_script = parent
	_tool_controller = parent.get_node_or_null("ToolController")
	_home_position = parent.global_transform.origin
	EventBus.connect("agent_disabled", self, "_on_agent_disabled")
	EventBus.connect("agent_damaged", self, "_on_agent_damaged")


func initialize(config: Dictionary) -> void:
	_home_position = config.get("patrol_center", agent_script.global_transform.origin)
	is_hostile = bool(config.get("hostile", is_hostile))
	_change_state(AIState.PATROL if is_hostile else AIState.IDLE)


func get_state() -> int:
	return _current_state


# Distance the AI tries to fight at: the optimal range of the tool that works on the target.
func get_engagement_range() -> float:
	var index: int = _get_attack_tool_index()
	return _tool_controller.get_tool(index).optimal_range if index >= 0 else 0.0


func _get_attack_tool_index() -> int:
	if not is_instance_valid(_tool_controller) or not is_instance_valid(_target_agent):
		return -1
	return _tool_controller.find_tool_for(_target_agent)


func _physics_process(delta: float) -> void:
	_repath_timer = max(0.0, _repath_timer - delta)
	_scan_timer = max(0.0, _scan_timer - delta)
	match _current_state:
		AIState.PATROL:
			_process_patrol()
		AIState.COMBAT:
			_process_combat()
		AIState.FLEE:
			_process_flee()


func _change_state(new_state: int) -> void:
	if _current_state == new_state:
		return
	_current_state = new_state
	_repath_timer = 0.0
	_orbiting = false
	if is_instance_valid(_tool_controller):
		_tool_controller.deactivate_all("state_change")

	match _current_state:
		AIState.IDLE, AIState.DISABLED:
			_provoked = false
			_target_agent = null
			_has_patrol_destination = false
			agent_script.command_stop()
		AIState.PATROL:
			_provoked = false
			_target_agent = null
			_has_patrol_destination = false
		AIState.COMBAT:
			agent_script.command_approach(_target_agent)
		AIState.FLEE:
			agent_script.command_flee(_target_agent)


func _process_patrol() -> void:
	if _scan_timer <= 0.0:
		_scan_timer = Constants.AI_SCAN_INTERVAL
		var target = scan_for_target()
		if is_instance_valid(target):
			_target_agent = target
			_change_state(AIState.COMBAT)
			return

	var current_pos = agent_script.global_transform.origin
	if not _has_patrol_destination or current_pos.distance_to(_patrol_destination) <= Constants.AI_PATROL_ARRIVAL_DISTANCE:
		_patrol_destination = _pick_patrol_destination()
		_has_patrol_destination = true
		agent_script.command_move_to(_patrol_destination)


func _process_combat() -> void:
	if not _is_live_target(_target_agent):
		_change_state(AIState.PATROL)
		return
	if not _provoked and not agent_script.detects(_target_agent):
		_change_state(AIState.PATROL)  # Lost contact
		return
	# Keep weighing the fight: break off once it stops being worth it.
	if _scan_timer <= 0.0:
		_scan_timer = Constants.AI_SCAN_INTERVAL
		if desire_against(_target_agent) < Constants.AI_DISENGAGE_DESIRE:
			_change_state(AIState.FLEE)
			return

	var distance: float = agent_script.global_transform.origin.distance_to(_target_agent.global_transform.origin)
	# Close to optimal range, then orbit there; re-approach if pushed out.
	var engagement_range: float = get_engagement_range()
	if distance > engagement_range * 1.2:
		if _orbiting or _repath_timer <= 0.0:
			_orbiting = false
			_repath_timer = Constants.AI_REPATH_INTERVAL
			agent_script.command_approach(_target_agent)
	elif not _orbiting:
		_orbiting = true
		agent_script.command_orbit(_target_agent)

	# Keep the attack tool on the target; ToolController stops it on its own when power runs out.
	var index: int = _get_attack_tool_index()
	if index >= 0:
		var tool_template = _tool_controller.get_tool(index)
		var in_reach: bool = distance <= tool_template.get_max_range()
		var enough_power: bool = agent_script.power >= tool_template.power_per_cycle
		if in_reach and enough_power and not _tool_controller.is_active(index):
			_tool_controller.activate(index, _target_agent)


func _process_flee() -> void:
	if not _is_live_target(_target_agent):
		_change_state(AIState.PATROL)
		return
	var distance: float = agent_script.global_transform.origin.distance_to(_target_agent.global_transform.origin)
	if distance > Constants.AI_FLEE_DISTANCE or not agent_script.detects(_target_agent):
		_change_state(AIState.PATROL)
		return
	if _repath_timer <= 0.0:
		_repath_timer = Constants.AI_REPATH_INTERVAL
		agent_script.command_flee(_target_agent)


# The detected non-hostile ship most worth attacking, if any is worth it at all.
func scan_for_target() -> RigidBody:
	var best: RigidBody = null
	var best_desire: float = Constants.AI_ENGAGE_DESIRE
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body == agent_script or not _is_live_target(body) or body.get("is_hostile"):
			continue
		if not agent_script.detects(body):
			continue
		var desire: float = desire_against(body)
		if desire >= best_desire:
			best = body
			best_desire = desire
	return best


# How much this ship wants to fight `target` (see Constants AI block).
func desire_against(target) -> float:
	return compute_desire(
		agent_script.hull, agent_script.get_damage_per_second(),
		target.hull, target.get_damage_per_second(), target.get_salvage_value()
	)


# advantage = (own time to die) / (time to kill the target); scaled by what the kill is worth.
static func compute_desire(own_hull: float, own_dps: float, target_hull: float, target_dps: float, gain: float) -> float:
	if own_dps <= 0.0:
		return 0.0
	var time_to_kill: float = target_hull / own_dps
	var time_to_die: float = own_hull / max(target_dps, 0.001)
	var advantage: float = min(time_to_die / max(time_to_kill, 0.001), 100.0)
	var gain_factor: float = clamp(gain / Constants.AI_GAIN_REFERENCE, Constants.AI_GAIN_FACTOR_MIN, Constants.AI_GAIN_FACTOR_MAX)
	return advantage * gain_factor


func _is_live_target(body) -> bool:
	return is_instance_valid(body) and body.is_inside_tree() and not body.get("is_wreck")


func _pick_patrol_destination() -> Vector3:
	var direction = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
	return _home_position + direction * randf() * Constants.AI_PATROL_RADIUS


func _on_agent_disabled(agent_body) -> void:
	if agent_body == agent_script:
		_change_state(AIState.DISABLED)


# Shot at by anyone: turn on the attacker and close in however far away it fired from, if the
# fight is worth it; otherwise flee from it.
func _on_agent_damaged(agent_body, _amount, source) -> void:
	if agent_body != agent_script or not _is_live_target(source) or source == agent_script:
		return
	if _current_state in [AIState.DISABLED, AIState.FLEE]:
		return
	if _current_state == AIState.COMBAT and _target_agent == source:
		_provoked = true
		return
	_target_agent = source
	# Shot at: fight back if the same rule says it is worth it, otherwise run.
	if desire_against(source) < Constants.AI_DISENGAGE_DESIRE:
		_change_state(AIState.FLEE)
		return
	_provoked = true
	_current_state = AIState.IDLE  # Re-enter combat so the approach starts toward the attacker
	_change_state(AIState.COMBAT)

