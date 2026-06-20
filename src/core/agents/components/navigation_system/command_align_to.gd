# PROJECT: GDTLancer
# MODULE: command_align_to.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: command_align_to.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §2, §6.1, §6.3
# LOG_REF: 2026-05-17 01:30:40
#

# File: core/agents/components/navigation_system/command_align_to.gd
# Version: 3.0 - RigidBody physics with PID-controlled rotation.
extends Node

var _nav_sys: Node
var _agent_body: RigidBody
var _movement_system: Node


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if not is_instance_valid(_movement_system) or not is_instance_valid(_agent_body):
		return
	
	var target_dir = _nav_sys._current_command.get("target_dir", Vector3.ZERO)
	var persist_until_cleared = _nav_sys._current_command.get("persist_until_cleared", false)
	if target_dir.length_squared() < 0.001:
		_nav_sys.set_command_idle()
		return
	
	# Rotate toward target direction using PID
	_movement_system.request_rotation_to_pid(target_dir, delta)
	if _nav_sys._current_command.get("apply_forward_thrust", false):
		_movement_system.request_thrust_forward(
			_nav_sys._current_command.get("forward_thrust_scale", 1.0)
		)
	
	# Check if aligned (use tighter threshold for alignment command)
	var current_fwd = -_agent_body.global_transform.basis.z.normalized()
	if current_fwd.dot(target_dir.normalized()) > 0.999:
		# Also ensure angular velocity is near zero
		if _agent_body.angular_velocity.length() < 0.1:
			if not persist_until_cleared:
				_nav_sys.set_command_idle()
		else:
			_movement_system.request_rotation_damping_pid(delta)