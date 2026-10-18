# ShipControllerAI: patrol / combat / flee state machine for NPC agents.
# Uses the same commands and ToolController as the player. Child of AgentBody in npc_agent.tscn.

extends Node

enum AIState { IDLE, PATROL, COMBAT, FLEE, DISABLED }

const REPATH_INTERVAL: float = 0.5
const SCAN_INTERVAL: float = 1.0
const PATROL_ARRIVAL_DISTANCE: float = 50.0

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
			_target_agent = null
			_has_patrol_destination = false
			agent_script.command_stop()
		AIState.PATROL:
			_target_agent = null
			_has_patrol_destination = false
		AIState.COMBAT:
			agent_script.command_approach(_target_agent)
		AIState.FLEE:
			agent_script.command_flee(_target_agent)


func _process_patrol() -> void:
	if _scan_timer <= 0.0:
		_scan_timer = SCAN_INTERVAL
		var target = scan_for_target()
		if is_instance_valid(target):
			_target_agent = target
			_change_state(AIState.COMBAT)
			return

	var current_pos = agent_script.global_transform.origin
	if not _has_patrol_destination or current_pos.distance_to(_patrol_destination) <= PATROL_ARRIVAL_DISTANCE:
		_patrol_destination = _pick_patrol_destination()
		_has_patrol_destination = true
		agent_script.command_move_to(_patrol_destination)


func _process_combat() -> void:
	if not _is_live_target(_target_agent):
		_change_state(AIState.PATROL)
		return
	if agent_script.get_hull_fraction() <= Constants.AI_FLEE_HULL_FRACTION:
		_change_state(AIState.FLEE)
		return

	var distance: float = agent_script.global_transform.origin.distance_to(_target_agent.global_transform.origin)
	if distance > Constants.AI_DETECTION_RANGE:
		_change_state(AIState.PATROL)
		return

	# Close to optimal range, then orbit there; re-approach if pushed out.
	var engagement_range: float = get_engagement_range()
	if distance > engagement_range * 1.2:
		if _orbiting or _repath_timer <= 0.0:
			_orbiting = false
			_repath_timer = REPATH_INTERVAL
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
	if distance > Constants.AI_DETECTION_RANGE * 2.0:
		_change_state(AIState.PATROL)
		return
	if _repath_timer <= 0.0:
		_repath_timer = REPATH_INTERVAL
		agent_script.command_flee(_target_agent)


# Nearest non-hostile, non-wrecked agent within detection range.
func scan_for_target() -> RigidBody:
	var best: RigidBody = null
	var best_distance: float = Constants.AI_DETECTION_RANGE
	var own_pos: Vector3 = agent_script.global_transform.origin
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body == agent_script or not _is_live_target(body) or body.get("is_hostile"):
			continue
		var distance: float = own_pos.distance_to(body.global_transform.origin)
		if distance <= best_distance:
			best = body
			best_distance = distance
	return best


func _is_live_target(body) -> bool:
	return is_instance_valid(body) and body.is_inside_tree() and not body.get("is_wreck")


func _pick_patrol_destination() -> Vector3:
	var direction = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
	return _home_position + direction * randf() * Constants.AI_PATROL_RADIUS


func _on_agent_disabled(agent_body) -> void:
	if agent_body == agent_script:
		_change_state(AIState.DISABLED)
