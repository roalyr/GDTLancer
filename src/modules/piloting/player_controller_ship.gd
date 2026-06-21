# PROJECT: GDTLancer
# MODULE: player_controller_ship.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: player_controller_ship.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: GDD-REVISION-LEDGER.md REV_005; universe_topology_architecture.md
# LOG_REF: 2026-06-12 01:10:00
#

extends Node

# --- References ---
var agent_script: Node = null
var agent_body: RigidBody = null
var movement_system: Node = null
var _main_camera: Camera = null
var _speed_slider: Slider = null
var _tool_controller: Node = null

# --- Thrust Throttle Control (0.0 to 1.0) ---
var current_thrust_throttle: float = 1.0
const KEY_THROTTLE_INCREMENT: float = 0.05

# --- State ---
var _current_input_state: InputState = null
var _states = {}
var _target_under_cursor: Spatial = null
var _selected_target = null setget _set_selected_target
var _can_dock_at: String = ""
var _pending_jump_target: String = ""
var _queued_jump_target_id: String = ""
var _queued_jump_direction: Vector3 = Vector3.ZERO
var _queued_jump_selection_token: String = ""
var _nearest_dock_node: Spatial = null   # Nearest station or jump point in prompt range
var _nearest_dock_type: String = ""      # "station" or "jump"
const JUMP_ALIGNMENT_MAX_DEVIATION_DEG: float = 5.0
const JUMP_ALIGNMENT_FULL_THRUST_SCALE: float = 1.0

# --- Preload States ---
const StateBase = preload("res://src/modules/piloting/player_input_states/state_base.gd")
const StateDefault = preload("res://src/modules/piloting/player_input_states/state_default.gd")
const StateFreeFlight = preload(
	"res://src/modules/piloting/player_input_states/state_free_flight.gd"
)


func _ready():
	agent_body = get_parent()
	if not (agent_body is RigidBody and agent_body.has_method("command_stop")):
		printerr("PlayerController Error: Parent is not a valid agent.")
		set_process(false)
		return

	agent_script = agent_body
	movement_system = agent_body.get_node_or_null("MovementSystem")
	if not is_instance_valid(movement_system):
		printerr("PlayerController Error: MovementSystem not found on agent.")
		set_process(false)
		return

	_tool_controller = agent_body.get_node_or_null("ToolController")

	_states = {
		"default": _register_input_state("StateDefault", StateDefault.new()),
		"free_flight": _register_input_state("StateFreeFlight", StateFreeFlight.new()),
	}

	EventBus.connect("player_docked", self, "_on_player_docked")
	EventBus.connect("player_undocked", self, "_on_player_undocked")
	EventBus.connect("player_dock_pressed", self, "_on_dock_button_pressed")

	call_deferred("_deferred_ready_setup")
	_change_state("default")


func _register_input_state(node_name: String, state: InputState) -> InputState:
	if state == null:
		return null
	state.name = node_name
	if state.get_parent() != self:
		add_child(state)
	return state


func _deferred_ready_setup():
	if not is_instance_valid(GlobalRefs.main_hud):
		yield(get_tree().create_timer(0.1), "timeout")
	_speed_slider = GlobalRefs.main_hud.get_node_or_null(
		"ScreenControls/CenterRightZone/SliderControlRight"
	)

	current_thrust_throttle = 1.0
	_update_throttle_and_slider_visuals()

	_connect_eventbus_signals()
	call_deferred("_get_camera_reference")


func _get_camera_reference():
	yield(get_tree(), "idle_frame")
	_main_camera = GlobalRefs.main_camera if is_instance_valid(GlobalRefs.main_camera) else null
	if not is_instance_valid(_main_camera):
		# Camera may not be ready yet, retry a few times
		for _i in range(10):
			yield(get_tree().create_timer(0.1), "timeout")
			_main_camera = GlobalRefs.main_camera if is_instance_valid(GlobalRefs.main_camera) else null
			if is_instance_valid(_main_camera):
				return
		printerr("PlayerController Error: Could not find valid Main Camera after retries.")


func _change_state(new_state_name: String):
	if _current_input_state != null:
		_current_input_state.exit()

	if _states.has(new_state_name):
		_current_input_state = _states[new_state_name]
		if _current_input_state != null:
			_current_input_state.enter(self)
	else:
		printerr("PlayerController Error: Attempted to change to unknown state: ", new_state_name)


func _physics_process(delta: float):
	if _is_jump_transition_active():
		_clear_queued_jump(false)
		return
	if _current_input_state != null:
		_current_input_state.physics_update(delta)
	_poll_docking_proximity()
	_process_queued_jump()


func _unhandled_input(event: InputEvent):
	if _is_jump_transition_active():
		return
	# Global inputs that work in any state
	if event.is_action_pressed("ui_accept"):
		_handle_interact_input()
		get_viewport().set_input_as_handled()
		return

	# Combat input (key-based to avoid interfering with LMB targeting/drag)
	if event is InputEventKey and event.is_action_pressed("fire_weapon"):
		_fire_weapon_at_selected_target(false, "key")
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_just_pressed("toggle_free_flight"):
		var new_state = "default" if _current_input_state is StateFreeFlight else "free_flight"
		_change_state(new_state)
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_pressed("command_speed_up"):
		var change = KEY_THROTTLE_INCREMENT * event.get_action_strength("command_speed_up")
		current_thrust_throttle = clamp(current_thrust_throttle + change, 0.0, 1.0)
		_update_throttle_and_slider_visuals()
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_pressed("command_speed_down"):
		var change = (
			KEY_THROTTLE_INCREMENT
			* event.get_action_strength("command_speed_down")
		)
		current_thrust_throttle = clamp(current_thrust_throttle - change, 0.0, 1.0)
		_update_throttle_and_slider_visuals()
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_just_pressed("command_stop"):
		_issue_stop_command()
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_just_pressed("command_approach"):
		_issue_approach_command()
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_just_pressed("command_flee"):
		_issue_flee_command()
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_just_pressed("command_orbit"):
		_issue_orbit_command()
		get_viewport().set_input_as_handled()
		return

	# Delegate other inputs to the current state
	if _current_input_state != null:
		_current_input_state.handle_input(event)


func _fire_weapon_at_selected_target(force: bool, source: String = "") -> void:
	if not is_instance_valid(_tool_controller):
		print("PlayerController: Fire skipped (no ToolController)")
		return
	if not _tool_controller.has_method("fire_at_target"):
		print("PlayerController: Fire skipped (ToolController missing fire_at_target)")
		return
	if not force and not Input.is_action_just_pressed("fire_weapon"):
		return

	var target_body: RigidBody = _get_current_target()
	if not is_instance_valid(target_body):
		print("PlayerController: Fire skipped (no selected target)")
		return

	var raw_uid = target_body.get("agent_uid")
	if raw_uid == null:
		print("PlayerController: Fire skipped (target has no agent_uid)")
		return
	var target_uid: int = int(raw_uid)
	if target_uid < 0:
		print("PlayerController: Fire skipped (invalid target uid)")
		return

	var target_pos: Vector3 = target_body.global_transform.origin
	var result: Dictionary = _tool_controller.call("fire_at_target", 0, target_uid, target_pos)
	if not result.get("success", false):
		print("PlayerController: Fire failed[", source, "]: ", result.get("reason", "Unknown"), " details=", result)
		return

	# Debug for manual verification
	var hit: bool = bool(result.get("hit", true))
	if hit:
		var damage_dict = result.get("damage_dealt", {})
		print(
			"PlayerController: Hit[",
			source,
			"] target_uid=",
			target_uid,
			" damage=",
			damage_dict,
			" hull_remaining=",
			result.get("target_hull_remaining", "?"),
			" disabled=",
			result.get("target_disabled", false)
		)
	else:
		print(
			"PlayerController: Miss[",
			source,
			"] target_uid=",
			target_uid,
			" accuracy=",
			result.get("accuracy", "?"),
			" roll=",
			result.get("roll", "?")
		)


func _get_current_target() -> RigidBody:
	if is_instance_valid(_selected_target) and _selected_target is RigidBody:
		return _selected_target as RigidBody
	return null


func is_free_flight_active() -> bool:
	return _current_input_state is StateFreeFlight


func get_active_navigation_command_type() -> int:
	if is_instance_valid(agent_body):
		var navigation_system = agent_body.get_node_or_null("NavigationSystem")
		if is_instance_valid(navigation_system) and navigation_system.has_method("get_current_command_type"):
			return navigation_system.get_current_command_type()
	return 0


func _is_route_target(target_ref) -> bool:
	return target_ref != null and target_ref.get("target_kind") == "jump_route"


func _is_selected_target_valid() -> bool:
	if _is_route_target(_selected_target):
		return true
	return is_instance_valid(_selected_target)


func _is_jump_transition_active() -> bool:
	return (
		is_instance_valid(GlobalRefs.world_manager)
		and GlobalRefs.world_manager.has_method("is_jump_transition_active")
		and GlobalRefs.world_manager.is_jump_transition_active()
	)


# --- Contextual Interact ---
func _handle_interact_input() -> void:
	if _is_jump_transition_active():
		return

	if is_instance_valid(_selected_target):
		if _is_route_target(_selected_target) or _selected_target.is_in_group("jump_point"):
			_attempt_selected_jump()
			return
		elif _selected_target.is_in_group("dockable_station"):
			var dist = agent_body.global_transform.origin.distance_to(
				_selected_target.global_transform.origin
			)
			if dist > Constants.DOCKING_ACTION_RADIUS:
				_clear_queued_jump()
				EventBus.emit_signal("dock_action_feedback", false, "Target is too far away")
				return
			_clear_queued_jump()
			EventBus.emit_signal("player_docked", _selected_target.location_id)
			return

	if GameState.current_sector_id != "":
		_clear_queued_jump()
		EventBus.emit_signal("player_docked", GameState.current_sector_id)
	else:
		_clear_queued_jump()
		EventBus.emit_signal("dock_action_feedback", false, "Can not dock with target")


# --- Dock/Attack Button Handlers ---
func _on_dock_button_pressed() -> void:
	var target = _get_current_target()
	if not is_instance_valid(target):
		# No target selected: falls back to virtual dock to sector
		_handle_interact_input()
		return
	
	if target.is_in_group("dockable_station") or target.is_in_group("jump_point") or _is_route_target(target):
		_handle_interact_input()
	else:
		if EventBus:
			EventBus.emit_signal("dock_action_feedback", false, "Cannot dock with target")


func _on_attack_button_pressed() -> void:
	var target = _get_current_target()
	if is_instance_valid(target):
		print("PlayerController: Attack button pressed, attacking target")
		_fire_weapon_at_selected_target(true, "button")
		# Emit signal to show "attacking" popup on HUD
		if EventBus:
			EventBus.emit_signal("attack_action_feedback", true, "Attacking!")
	else:
		# Emit signal to show "no target" popup on HUD
		if EventBus:
			EventBus.emit_signal("attack_action_feedback", false, "No target selected")

func _on_interact_button_pressed() -> void:
	var target = _selected_target

	if target is Node and is_instance_valid(target) and (target.is_in_group("agent_body") or target.is_in_group("Agents")):
		# Always emit signal to open InteractionWindow; it will gate trade internally.
		var agent_id: String = _resolve_agent_id(target)
		if EventBus:
			EventBus.emit_signal("player_npc_interact_requested", agent_id, target)
	elif target is Node and is_instance_valid(target) and (target.is_in_group("planet") or target.is_in_group("moon") or target.is_in_group("stellar_body") or _is_celestial(target)):
		# Open InteractionWindow for celestials with a placeholder message.
		var body_name: String = target.name
		if EventBus:
			EventBus.emit_signal("player_npc_interact_requested", "__celestial__" + body_name, target)
	else:
		# Fallback to Self/Status interaction
		if EventBus:
			EventBus.emit_signal("player_npc_interact_requested", "player", null)


func _is_celestial(node) -> bool:
	if not is_instance_valid(node) or not node is Node:
		return false
	if node.is_in_group("planet") or node.is_in_group("moon") or node.is_in_group("stellar_body"):
		return true
	var name_lower = node.name.to_lower()
	if name_lower.find("star") != -1 or name_lower.find("planet") != -1 or name_lower.find("moon") != -1:
		return true
	return false


func _resolve_agent_id(target) -> String:
	if not is_instance_valid(target):
		return ""
	# Prefer template_id — the persistent agent string key used in GameState.agents.
	var tid = target.get("template_id")
	if tid != null and str(tid) != "" and str(tid) != "-1":
		return str(tid)
	# Fallback to node name for non-persistent agents.
	if target is Node:
		return target.name
	return ""


func _is_npc_tradeable(target) -> bool:
	if not is_instance_valid(target) or not target is Node:
		return false
	if not (target.is_in_group("agent_body") or target.is_in_group("Agents")):
		return false
	var agent_id: String = _resolve_agent_id(target)
	if GameState.agents.has(agent_id):
		var role: String = str(GameState.agents[agent_id].get("agent_role", ""))
		if role in ["trader", "hauler", "prospector"]:
			return true
	return false




# --- Helper & Command Functions (Publicly callable by states) ---
func _update_target_under_cursor():
	_target_under_cursor = null


func _set_selected_target(new_target):
	if _selected_target == new_target:
		return
	_clear_queued_jump()
	_selected_target = new_target
	if _is_selected_target_valid():
		EventBus.emit_signal("player_target_selected", _selected_target)
	else:
		EventBus.emit_signal("player_target_deselected")


func _handle_single_click(_click_pos: Vector2):
	_set_selected_target(null)


func _handle_double_click(click_pos: Vector2):
	_clear_queued_jump()
	if is_instance_valid(agent_script) and is_instance_valid(_main_camera):
		var ray_origin = _main_camera.project_ray_origin(click_pos)
		var ray_normal = _main_camera.project_ray_normal(click_pos)
		var target_point = ray_origin + ray_normal * Constants.TARGETING_RAY_LENGTH
		agent_script.command_move_to(target_point)


func _issue_stop_command():
	_clear_queued_jump()
	if not is_instance_valid(agent_script):
		return
	agent_script.command_stop()
	if _current_input_state is StateFreeFlight:
		_change_state("default")


func _issue_approach_command():
	_clear_queued_jump()
	if not is_instance_valid(agent_script):
		return
	if EventBus:
		EventBus.emit_signal("player_approach_pressed")
	if _current_input_state is StateFreeFlight:
		_change_state("default")


func _issue_flee_command():
	_clear_queued_jump()
	if not is_instance_valid(agent_script):
		return
	if EventBus:
		EventBus.emit_signal("player_flee_pressed")
	if _current_input_state is StateFreeFlight:
		_change_state("default")


func _issue_orbit_command():
	_clear_queued_jump()
	if not is_instance_valid(agent_script):
		return
	if EventBus:
		EventBus.emit_signal("player_orbit_pressed")
	if _current_input_state is StateFreeFlight:
		_change_state("default")


func _update_throttle_and_slider_visuals():
	if not is_instance_valid(movement_system):
		return
	# Update the movement system's thrust throttle
	movement_system.thrust_throttle = current_thrust_throttle

	if is_instance_valid(_speed_slider):
		var slider_val = 100.0 - (current_thrust_throttle * 100.0)
		if not is_equal_approx(_speed_slider.value, slider_val):
			_speed_slider.value = slider_val


func _raycast_for_target(screen_pos: Vector2) -> Spatial:
	if not is_instance_valid(agent_body) or not is_instance_valid(_main_camera):
		return null
	var ray_origin = _main_camera.project_ray_origin(screen_pos)
	var ray_normal = _main_camera.project_ray_normal(screen_pos)
	var ray_end = ray_origin + ray_normal * Constants.TARGETING_RAY_LENGTH
	# --- FIX: Call get_world() from the agent_body node ---
	var space_state = agent_body.get_world().direct_space_state
	var result = space_state.intersect_ray(ray_origin, ray_end, [agent_body], 1)
	return result.collider if result else null


func _attempt_selected_jump() -> void:
	var target_sector_id = _get_jump_target_sector_id(_selected_target)
	if target_sector_id == "":
		_clear_queued_jump()
		EventBus.emit_signal("dock_action_feedback", false, "Can not dock with target")
		return
	var jump_direction = _resolve_jump_direction_from_target(_selected_target)
	if jump_direction.length_squared() < 0.001:
		_emit_jump_request(target_sector_id)
		return
	if not _can_queue_jump_alignment():
		_emit_jump_request(target_sector_id)
		return
	_queue_jump_alignment(target_sector_id, jump_direction)


func _get_jump_target_sector_id(target_ref) -> String:
	if _is_route_target(target_ref):
		return target_ref.target_sector_id
	if is_instance_valid(target_ref) and target_ref.is_in_group("jump_point"):
		return target_ref.target_sector_id
	return ""


func _get_jump_target_selection_token(target_ref) -> String:
	if _is_route_target(target_ref):
		return target_ref.selection_key
	if is_instance_valid(target_ref):
		return "jump_point:%s" % target_ref.get_instance_id()
	return ""


func _resolve_jump_direction_from_target(target_ref) -> Vector3:
	if _is_route_target(target_ref):
		return target_ref.route_direction.normalized()
	if is_instance_valid(target_ref) and target_ref is Spatial and is_instance_valid(agent_body):
		var raw_direction = target_ref.global_transform.origin - agent_body.global_transform.origin
		if raw_direction.length_squared() < 0.001:
			return Vector3.ZERO
		return raw_direction.normalized()
	return Vector3.ZERO


func _can_queue_jump_alignment() -> bool:
	return (
		is_instance_valid(agent_body)
		and is_instance_valid(agent_script)
		and is_instance_valid(movement_system)
		and agent_script.has_method("command_align_to")
		and movement_system.has_method("is_rotation_stopped")
	)


func _is_jump_alignment_ready(jump_direction: Vector3) -> bool:
	if jump_direction.length_squared() < 0.001:
		return true
	if not _can_queue_jump_alignment():
		return true
	return _is_jump_facing_direction_ready(jump_direction) and movement_system.is_rotation_stopped()


func _is_jump_facing_direction_ready(jump_direction: Vector3) -> bool:
	if jump_direction.length_squared() < 0.001:
		return true
	if not is_instance_valid(agent_body):
		return true
	var target_direction = jump_direction.normalized()
	var current_forward = -agent_body.global_transform.basis.z.normalized()
	var deviation_angle_deg = rad2deg(current_forward.angle_to(target_direction))
	return deviation_angle_deg < JUMP_ALIGNMENT_MAX_DEVIATION_DEG or is_equal_approx(
		deviation_angle_deg,
		JUMP_ALIGNMENT_MAX_DEVIATION_DEG
	)


func _queue_jump_alignment(target_sector_id: String, jump_direction: Vector3) -> void:
	if not _can_queue_jump_alignment():
		_emit_jump_request(target_sector_id)
		return
	_queued_jump_target_id = target_sector_id
	_queued_jump_direction = jump_direction.normalized()
	_queued_jump_selection_token = _get_jump_target_selection_token(_selected_target)
	_command_jump_alignment(_queued_jump_direction)


func _command_jump_alignment(jump_direction: Vector3) -> void:
	if jump_direction.length_squared() < 0.001:
		return
	var normalized_direction = jump_direction.normalized()
	agent_script.command_align_to(
		normalized_direction,
		true,
		JUMP_ALIGNMENT_FULL_THRUST_SCALE,
		true
	)


func _process_queued_jump() -> void:
	if _queued_jump_target_id == "":
		return
	if not _is_selected_jump_queue_still_valid():
		_clear_queued_jump()
		return
	var current_jump_direction = _resolve_jump_direction_from_target(_selected_target)
	if current_jump_direction.length_squared() >= 0.001:
		_queued_jump_direction = current_jump_direction
	if _queued_jump_direction.length_squared() < 0.001:
		_emit_jump_request(_queued_jump_target_id)
		return
	if not _can_queue_jump_alignment():
		_emit_jump_request(_queued_jump_target_id)
		return
	if not _is_jump_alignment_ready(_queued_jump_direction):
		_command_jump_alignment(_queued_jump_direction)
		return
	_emit_jump_request(_queued_jump_target_id)


func _is_selected_jump_queue_still_valid() -> bool:
	if _queued_jump_target_id == "":
		return false
	if _get_jump_target_sector_id(_selected_target) != _queued_jump_target_id:
		return false
	if _get_jump_target_selection_token(_selected_target) != _queued_jump_selection_token:
		return false
	return _nearest_dock_type == "jump" and _pending_jump_target == _queued_jump_target_id


func _emit_jump_request(target_sector_id: String) -> void:
	_clear_queued_jump(false)
	EventBus.emit_signal("player_jump_requested", target_sector_id)


func _clear_queued_jump(cancel_active_jump_alignment: bool = true) -> void:
	if cancel_active_jump_alignment:
		_cancel_active_queued_jump_alignment_command()
	_queued_jump_target_id = ""
	_queued_jump_direction = Vector3.ZERO
	_queued_jump_selection_token = ""


func _cancel_active_queued_jump_alignment_command() -> void:
	if _queued_jump_target_id == "":
		return
	if not is_instance_valid(agent_script):
		return
	if agent_script.has_method("command_idle"):
		agent_script.command_idle()


# --- Signal Handlers ---
func _on_Player_Free_Flight_Toggled():
	var new_state = "default" if _current_input_state is StateFreeFlight else "free_flight"
	_change_state(new_state)


func _on_Player_Stop_Pressed():
	_issue_stop_command()


func _on_Player_Orbit_Pressed():
	if _selected_target is Spatial and is_instance_valid(_selected_target):
		agent_script.command_orbit(_selected_target)


func _on_Player_Approach_Pressed():
	if _selected_target is Spatial and is_instance_valid(_selected_target):
		agent_script.command_approach(_selected_target)


func _on_Player_Flee_Pressed():
	if _selected_target is Spatial and is_instance_valid(_selected_target):
		agent_script.command_flee(_selected_target)

func _on_player_target_selection_requested(target_ref) -> void:
	_set_selected_target(target_ref)

func _on_Player_Ship_Speed_Slider_Changed_By_HUD(slider_ui_value: float):
	current_thrust_throttle = (100.0 - slider_ui_value) / 100.0
	_update_throttle_and_slider_visuals()


# --- Connections & Cleanup ---
func _connect_eventbus_signals():
	EventBus.connect("player_free_flight_toggled", self, "_on_Player_Free_Flight_Toggled")
	EventBus.connect("player_target_selection_requested", self, "_on_player_target_selection_requested")
	EventBus.connect("player_stop_pressed", self, "_on_Player_Stop_Pressed")
	EventBus.connect("player_orbit_pressed", self, "_on_Player_Orbit_Pressed")
	EventBus.connect("player_approach_pressed", self, "_on_Player_Approach_Pressed")
	EventBus.connect("player_flee_pressed", self, "_on_Player_Flee_Pressed")
	EventBus.connect("player_interact_pressed", self, "_on_interact_button_pressed")
	EventBus.connect(
		"player_ship_speed_changed", self, "_on_Player_Ship_Speed_Slider_Changed_By_HUD"
	)


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if EventBus.is_connected(
			"player_free_flight_toggled", self, "_on_Player_Free_Flight_Toggled"
		):
			EventBus.disconnect(
				"player_free_flight_toggled", self, "_on_Player_Free_Flight_Toggled"
			)
		if EventBus.is_connected("player_target_selection_requested", self, "_on_player_target_selection_requested"):
			EventBus.disconnect("player_target_selection_requested", self, "_on_player_target_selection_requested")
		if EventBus.is_connected("player_stop_pressed", self, "_on_Player_Stop_Pressed"):
			EventBus.disconnect("player_stop_pressed", self, "_on_Player_Stop_Pressed")
		if EventBus.is_connected("player_orbit_pressed", self, "_on_Player_Orbit_Pressed"):
			EventBus.disconnect("player_orbit_pressed", self, "_on_Player_Orbit_Pressed")
		if EventBus.is_connected("player_approach_pressed", self, "_on_Player_Approach_Pressed"):
			EventBus.disconnect("player_approach_pressed", self, "_on_Player_Approach_Pressed")
		if EventBus.is_connected("player_flee_pressed", self, "_on_Player_Flee_Pressed"):
			EventBus.disconnect("player_flee_pressed", self, "_on_Player_Flee_Pressed")
		if EventBus.is_connected("player_interact_pressed", self, "_on_interact_button_pressed"):
			EventBus.disconnect("player_interact_pressed", self, "_on_interact_button_pressed")
		if EventBus.is_connected(
			"player_ship_speed_changed", self, "_on_Player_Ship_Speed_Slider_Changed_By_HUD"
		):
			EventBus.disconnect(
				"player_ship_speed_changed", self, "_on_Player_Ship_Speed_Slider_Changed_By_HUD"
			)

# --- Proximity Polling (requires active target selection) ---
func _poll_docking_proximity():
	if not is_instance_valid(agent_body):
		return
	# Only the actively selected target can trigger dock/jump prompts
	var target = _selected_target
	var node: Spatial = null
	var dtype: String = ""
	var did: String = ""
	var dname: String = ""

	if _is_route_target(target):
		dtype = "jump"
		did = target.target_sector_id
		dname = target.display_name
	elif is_instance_valid(target):
		if target.is_in_group("dockable_station"):
			node = target
			dtype = "station"
			did = target.location_id
			dname = target.station_name
		elif target.is_in_group("jump_point"):
			node = target
			dtype = "jump"
			did = target.target_sector_id
			dname = target.target_sector_name

	var in_range := false
	if dtype == "jump" and not is_instance_valid(node):
		in_range = true
	elif is_instance_valid(node):
		var dist = agent_body.global_transform.origin.distance_to(node.global_transform.origin)
		in_range = dist <= Constants.DOCKING_PROMPT_RADIUS

	# Update state and emit signals only on change
	if in_range:
		var state_changed := (
			node != _nearest_dock_node
			or dtype != _nearest_dock_type
			or (dtype == "station" and did != _can_dock_at)
			or (dtype == "jump" and did != _pending_jump_target)
		)
		if state_changed:
			_nearest_dock_node = node
			_nearest_dock_type = dtype
			if dtype == "station":
				_can_dock_at = did
				_pending_jump_target = ""
				EventBus.emit_signal("dock_available", did)
			else:
				_pending_jump_target = did
				_can_dock_at = ""
				EventBus.emit_signal("jump_available", did, dname)
	else:
		if _nearest_dock_type != "":
			var was_type = _nearest_dock_type
			_nearest_dock_node = null
			_nearest_dock_type = ""
			_can_dock_at = ""
			_pending_jump_target = ""
			if was_type == "station":
				EventBus.emit_signal("dock_unavailable")
			else:
				EventBus.emit_signal("jump_unavailable")

func _on_player_docked(location_id):
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("Player docked at: ", location_id)
	_clear_queued_jump()
	GameState.player_docked_at = location_id
	set_process_unhandled_input(false)
	set_physics_process(false)
	# Stop the ship
	if agent_script.has_method("command_stop"):
		agent_script.command_stop()

func _on_player_undocked():
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("Player undocked")
	_clear_queued_jump()
	GameState.player_docked_at = ""
	set_process_unhandled_input(true)
	set_physics_process(true)
