# Navigation command: close in on a (possibly moving) target and hold at approach distance (with
# "at_weapons", at the range of the weapons on it while any are: ToolController.fighting_range,
# times NAV_APPROACH_WEAPON_SHARE, so it holds inside their reach). The command stays on once there: the ship keeps pace with the target, and closes in again if it
# drops more than Constants.NAV_APPROACH_RESUME_MARGIN behind (so a pursuit does not end on arrival).

extends Node

var _nav_sys: Node
var _agent_body: RigidBody
var _movement_system: Node

# State for tracking target motion
var _prev_target_pos: Vector3 = Vector3.ZERO
var _target_velocity: Vector3 = Vector3.ZERO


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if not is_instance_valid(_movement_system) or not is_instance_valid(_agent_body):
		return

	var cmd = _nav_sys._current_command
	var target_node = cmd.target_node
	if not is_instance_valid(target_node):
		_nav_sys.set_command_stopping()
		return
		
	var target_pos = target_node.global_transform.origin
	var target_size = _nav_sys._get_target_effective_size(target_node)
	var safe_distance = max(Constants.NAV_APPROACH_MIN_DISTANCE, target_size * Constants.NAV_APPROACH_DISTANCE_MULTIPLIER)
	if cmd.get("at_weapons", false):
		var tools = _agent_body.get_node_or_null("ToolController")
		if tools != null and tools.has_method("fighting_range"):
			safe_distance = max(safe_distance, tools.fighting_range(target_node) * Constants.NAV_APPROACH_WEAPON_SHARE)

	# Estimate target velocity
	if cmd.get("is_new", true):
		_prev_target_pos = target_pos
		_target_velocity = Vector3.ZERO
		cmd["is_new"] = false
	else:
		if delta > 0.001:
			_target_velocity = (target_pos - _prev_target_pos) / delta
		_prev_target_pos = target_pos

	var vector_to_target = target_pos - _agent_body.global_transform.origin
	var distance = vector_to_target.length()

	var current_speed = _movement_system.get_current_speed()
	var direction = vector_to_target.normalized() if distance > 0.01 else Vector3.ZERO

	# Arrived: hold, matching the target's velocity, until it pulls away past the margin.
	var hold_distance: float = safe_distance + Constants.NAV_ARRIVAL_DISTANCE_THRESHOLD
	var holding: bool = cmd.get("holding", false)
	if distance < hold_distance or (holding and distance < hold_distance + Constants.NAV_APPROACH_RESUME_MARGIN):
		if not holding:
			EventBus.emit_signal("agent_reached_destination", _agent_body)
			cmd["holding"] = true
		if direction != Vector3.ZERO:
			_movement_system.request_rotation_to_pid(direction, delta)
		_movement_system.request_velocity_pid(_target_velocity, delta)
		return
	cmd["holding"] = false
	# Nose on it; the velocity its own plus toward it, as fast as it can still stop at the approach
	# distance ("How a ship is flown": no flip to brake)
	_movement_system.request_rotation_to_pid(direction, delta)
	var closing: float = _movement_system.arrival_speed(distance - safe_distance, _movement_system.top_speed(), _movement_system.acceleration())
	_movement_system.request_velocity(_target_velocity + direction * closing)
