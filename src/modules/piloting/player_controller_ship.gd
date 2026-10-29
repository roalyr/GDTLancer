# PlayerControllerShip: player input for flight, commands, targeting, docking, jumping and firing.

extends Node

# --- References ---
const ScreenSpace = preload("res://src/core/ui/screen_space.gd")
const NavigationSystem = preload("res://src/core/agents/components/navigation_system.gd")
var agent_script: Node = null
var agent_body: RigidBody = null
var movement_system: Node = null
var _main_camera: Camera = null
var _speed_slider: Slider = null
var _tool_controller: Node = null

# --- Thrust Throttle Control (0.0 to 1.0) ---
var current_thrust_throttle: float = 1.0

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

const HomePort = preload("res://src/core/systems/home_port.gd")
const Market = preload("res://src/core/systems/market.gd")
const Standing = preload("res://src/core/systems/standing.gd")

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
	if is_instance_valid(_tool_controller) and not _tool_controller.is_connected("tool_deactivated", self, "_on_tool_deactivated"):
		_tool_controller.connect("tool_deactivated", self, "_on_tool_deactivated")
		_tool_controller.connect("projectile_fired", self, "_on_projectile_fired")

	_states = {
		"default": _register_input_state("StateDefault", StateDefault.new()),
		"free_flight": _register_input_state("StateFreeFlight", StateFreeFlight.new()),
	}

	EventBus.connect("player_docked", self, "_on_player_docked")
	EventBus.connect("player_undocked", self, "_on_player_undocked")
	EventBus.connect("player_dock_pressed", self, "_on_dock_button_pressed")
	EventBus.connect("player_interact_pressed", self, "_on_interact_button_pressed")
	EventBus.connect("player_tool_pressed", self, "_on_tool_button_pressed")
	EventBus.connect("player_lance_pressed", self, "_on_lance_button_pressed")
	EventBus.connect("player_afterburner_pressed", self, "_on_afterburner_button_pressed")

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
	# A selected target (ship, celestial, station) that slips out of sensor range is lost.
	if is_instance_valid(_selected_target) and agent_body.has_method("detects") and not agent_body.detects(_selected_target):
		_set_selected_target(null)
	_poll_docking_proximity()
	_process_queued_jump()
	_sync_ram_command()


func _unhandled_input(event: InputEvent):
	if _is_jump_transition_active():
		return
	# Space toggles the laser when a ship is selected; otherwise it docks or jumps.
	# Key-only so it does not interfere with LMB targeting/drag.
	if event is InputEventKey and event.is_action_pressed("fire_weapon") and _is_tool_target(_selected_target):
		toggle_tool_for_selected()
		get_viewport().set_input_as_handled()
		return

	# Global inputs that work in any state
	if event.is_action_pressed("ui_accept"):
		_handle_interact_input()
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_just_pressed("toggle_free_flight"):
		var new_state = "default" if _current_input_state is StateFreeFlight else "free_flight"
		_change_state(new_state)
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_pressed("command_speed_up"):
		var change = Constants.PLAYER_KEY_THROTTLE_STEP * event.get_action_strength("command_speed_up")
		current_thrust_throttle = clamp(current_thrust_throttle + change, 0.0, 1.0)
		_update_throttle_and_slider_visuals()
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_pressed("command_speed_down"):
		var change = (
			Constants.PLAYER_KEY_THROTTLE_STEP
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


# Switches the tool that suits the selected target on (laser for a live ship, harpoon for a
# wreck), or off if it is already on that target.
func toggle_tool_for_selected() -> void:
	var target = _get_current_target()
	var index: int = _tool_controller.find_tool_for(target) if is_instance_valid(_tool_controller) else -1
	if index < 0:
		EventBus.emit_signal("attack_action_feedback", false, "No fitted tool works on this target")
		return
	if _tool_controller.is_active(index) and _tool_controller.get_target(index) == target:
		_tool_controller.deactivate(index)
		return
	var result: Dictionary = _tool_controller.activate(index, target)
	if not result.get("success", false):
		EventBus.emit_signal("attack_action_feedback", false, _describe_tool_failure(result.get("reason", "")))


# HUD interact button: general interaction with the selected target. Tools have their own buttons.
func _on_interact_button_pressed() -> void:
	EventBus.emit_signal("attack_action_feedback", false, "Nothing to interact with here yet")


# A HUD tool button: that tool off if it is on, otherwise on against the selected target.
# Arms the kinetic lance (its tip strikes what it meets fast enough) or makes it safe.
func _on_lance_button_pressed() -> void:
	var lance = agent_body.get_lance() if is_instance_valid(agent_body) and agent_body.has_method("get_lance") else null
	if lance == null:
		return
	if GameState.player_docked_at != "":
		EventBus.emit_signal("attack_action_feedback", false, "Undock first")
		return
	agent_body.set_lances_armed(not lance.armed)  # All launchers together


# The AFTERBURN button: lights the afterburner or puts it out.
func _on_afterburner_button_pressed() -> void:
	if not is_instance_valid(agent_body) or not agent_body.has_method("has_afterburner") or not agent_body.has_afterburner():
		return
	if GameState.player_docked_at != "":
		EventBus.emit_signal("attack_action_feedback", false, "Undock first")
		return
	if not agent_body.set_afterburner(not agent_body.afterburner_lit) and agent_body.power <= 0.0:
		EventBus.emit_signal("attack_action_feedback", false, "Afterburner: no power")


func _on_tool_button_pressed(index: int) -> void:
	if _is_jump_transition_active() or not is_instance_valid(_tool_controller):
		return
	if GameState.player_docked_at != "":
		EventBus.emit_signal("attack_action_feedback", false, "Undock first")
		return
	var tool_template = _tool_controller.get_tool(index)
	if tool_template == null:
		return
	if _tool_controller.is_active(index):
		_tool_controller.deactivate(index)
		return
	var target = _get_current_target()
	if not _tool_controller.can_target(tool_template, target):
		var needs: String = "a wreck" if tool_template.tool_type == "harpoon" else "a ship or rock"
		EventBus.emit_signal("attack_action_feedback", false, "%s needs %s selected" % [tool_template.tool_name, needs])
		return
	if _tool_controller.has_magazine(index) and _tool_controller.get_ammo(index) <= 0:
		EventBus.emit_signal("attack_action_feedback", false, _empty_message(tool_template))
		return
	var result: Dictionary = _tool_controller.activate(index, target)
	if not result.get("success", false):
		EventBus.emit_signal("attack_action_feedback", false, _describe_tool_failure(result.get("reason", "")))
	elif tool_template.tool_type == "cannon":
		agent_script.command_aim(target, tool_template.optimal_range)  # A cannon fires where the nose points: the autopilot aims it


# The player's missiles go one per press (their stock is limited): a launch switches the rack off.
func _on_projectile_fired(index: int, _projectile) -> void:
	var tool_template = _tool_controller.get_tool(index)
	if tool_template != null and tool_template.tool_type == "missile":
		_tool_controller.deactivate(index, "fired")


# A magazine ran dry, or a cannon stopped: the aim it held goes with it.
func _on_tool_deactivated(index: int, reason: String) -> void:
	var tool_template = _tool_controller.get_tool(index) if is_instance_valid(_tool_controller) else null
	if tool_template == null:
		return
	if reason == "empty":
		EventBus.emit_signal("attack_action_feedback", false, _empty_message(tool_template))
	if tool_template.tool_type == "cannon" and _tool_controller.find_cannon_for(_tool_controller.get_target(index)) < 0:
		var nav = agent_body.get_node_or_null("NavigationSystem")
		if is_instance_valid(nav) and nav.get_current_command_type() == NavigationSystem.CommandType.AIM and not _cannon_on():
			_coast()


func _cannon_on() -> bool:
	for index in range(_tool_controller.get_tool_count()):
		if _tool_controller.get_tool(index).tool_type == "cannon" and _tool_controller.is_active(index):
			return true
	return false


func _empty_message(tool_template) -> String:
	return "%s empty: refill at a base, or salvage a wreck that carried the same" % tool_template.tool_name


func _is_tool_target(target) -> bool:
	return is_instance_valid(target) and target != agent_body and (target.has_method("apply_damage") or target.is_in_group("asteroid"))


func _describe_tool_failure(reason: String) -> String:
	match reason:
		"invalid_target":
			return "No fitted tool works on this target"
		"not_implemented":
			return "This tool does not work yet"
		"wrecked":
			return "Ship is wrecked"
		"retracting":
			return "Harpoon cable still winching in"
	return "Tool unavailable"


# The selected ship, wreck or rock (route markers are not bodies).
func _get_current_target() -> Spatial:
	if is_instance_valid(_selected_target) and (_selected_target is RigidBody or _selected_target.is_in_group("asteroid")):
		return _selected_target
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
	return is_instance_valid(target_ref) and target_ref.get("target_kind") == "jump_route"


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
# Space on a non-ship target / the Dock button: jump along a selected route, or dock at a
# selected station. Docking is only ever at a station.
func _handle_interact_input() -> void:
	if _is_jump_transition_active() or GameState.player_docked_at != "":
		return
	if is_instance_valid(_selected_target):
		if _is_route_target(_selected_target) or _selected_target.is_in_group("jump_point"):
			_attempt_selected_jump()
			return
		if _selected_target.is_in_group("dockable_station"):
			request_dock(_selected_target)
			return
	EventBus.emit_signal("dock_action_feedback", false, "Select a station to dock at")


func request_dock(station: Spatial) -> void:
	_clear_queued_jump()
	var gap: float = get_docking_gap(station)
	if gap > Constants.DOCKING_ACTION_RADIUS:
		EventBus.emit_signal("dock_action_feedback", false, "Too far to dock: %.0f m to the station, %.0f m needed" % [gap, Constants.DOCKING_ACTION_RADIUS])
		return
	if Standing.is_hostile(station.get("faction")):
		EventBus.emit_signal("dock_action_feedback", false, "%s refuses docking: hostile standing" % Constants.FACTIONS[station.faction].get("name", station.faction))
		return
	EventBus.emit_signal("player_docked", station.location_id)


# Distance from this ship to the station's hull (its centre minus its obstacle radius).
func get_docking_gap(station: Spatial) -> float:
	var radius: float = station.get_obstacle_radius() if station.has_method("get_obstacle_radius") else 0.0
	return max(0.0, agent_body.global_transform.origin.distance_to(station.global_transform.origin) - radius)


# --- Dock/Attack Button Handlers ---
func _on_dock_button_pressed() -> void:
	_handle_interact_input()


func _set_selected_target(new_target):
	if _selected_target == new_target:
		return
	_clear_queued_jump()
	var previous = _selected_target
	_selected_target = new_target
	if _is_selected_target_valid():
		EventBus.emit_signal("player_target_selected", _selected_target)
	else:
		EventBus.emit_signal("player_target_deselected")
		_drop_commands_on(previous)


# The target is lost (out of sensor range, gone): whatever the ship was doing to it stops, its
# course (approach, orbit, ram, flee...) and the tools on it.
func _drop_commands_on(target) -> void:
	if target == null or not is_instance_valid(agent_body):
		return
	var nav = agent_body.get_node_or_null("NavigationSystem")
	if is_instance_valid(nav) and nav._current_command.get("target_node", null) == target and is_instance_valid(agent_script):
		agent_script.command_stop()
	if is_instance_valid(_tool_controller):
		for index in range(_tool_controller.get_tool_count()):
			if _tool_controller.is_active(index) and _tool_controller.get_target(index) == target:
				_tool_controller.deactivate(index, "target_lost")


# --- Pointer entry points (called by PointerRouter) ---

func is_pointer_input_blocked() -> bool:
	return _is_jump_transition_active()


# Click on empty space keeps the selection: only picking another target changes it (a target is
# dropped only when lost: out of sensor range or gone).
func handle_world_click(_click_pos: Vector2):
	pass


func set_free_flight(active: bool) -> void:
	if active != (_current_input_state is StateFreeFlight):
		_change_state("free_flight" if active else "default")


# Double click on a target's bracket (PointerRouter has just selected it): approach it, as the
# Approach button does (but never toggles it off).
func handle_target_double_click():
	_clear_queued_jump()
	if not is_instance_valid(agent_script):
		return
	_approach_selected()
	if _current_input_state is StateFreeFlight:
		_change_state("default")


# Double click on empty space flies toward that point.
func handle_world_double_click(click_pos: Vector2):
	_clear_queued_jump()
	if is_instance_valid(agent_script) and is_instance_valid(_main_camera):
		var ray_origin = ScreenSpace.ray_origin(_main_camera, click_pos)
		var ray_normal = ScreenSpace.ray_normal(_main_camera, click_pos)
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
	var ray_origin = ScreenSpace.ray_origin(_main_camera, screen_pos)
	var ray_normal = ScreenSpace.ray_normal(_main_camera, screen_pos)
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
	return deviation_angle_deg < Constants.JUMP_ALIGNMENT_MAX_DEVIATION_DEG or is_equal_approx(
		deviation_angle_deg,
		Constants.JUMP_ALIGNMENT_MAX_DEVIATION_DEG
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
		Constants.JUMP_ALIGNMENT_FULL_THRUST_SCALE,
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


# Orbit, approach and flee toggle: pressed again on the course already flown, they let go of it
# and the ship coasts on (_coast).
func _on_Player_Orbit_Pressed():
	if _toggled_off([NavigationSystem.CommandType.ORBIT]):
		return
	if is_instance_valid(_selected_target) and _selected_target is Spatial:
		agent_script.command_orbit(_selected_target)


# Whether the ship is flying one of `types` on the selected target; if so, it lets go and coasts on.
func _toggled_off(types: Array) -> bool:
	var nav = agent_body.get_node_or_null("NavigationSystem") if is_instance_valid(agent_body) else null
	if not is_instance_valid(nav) or not nav.get_current_command_type() in types:
		return false
	if nav._current_command.get("target_node", null) != _selected_target:
		return false
	_coast()
	return true


# No course: the ship keeps going the way it is moving, at the throttle set (still: it drifts).
func _coast() -> void:
	var velocity: Vector3 = agent_body.linear_velocity if is_instance_valid(agent_body) else Vector3.ZERO
	if velocity.length() > 1.0:
		agent_script.command_move_direction(velocity.normalized())
	else:
		agent_script.command_idle()


# APPROACH: with the lance armed, at a ship or a rock with ore, the pass that throws it (command_ram).
func _on_Player_Approach_Pressed():
	if _toggled_off([NavigationSystem.CommandType.APPROACH, NavigationSystem.CommandType.RAM]):
		return
	_approach_selected()


func _approach_selected() -> void:
	if is_instance_valid(_selected_target) and _selected_target is Spatial:
		if is_ram_ready(_selected_target):
			agent_script.command_ram(_selected_target)
		else:
			agent_script.command_approach(_selected_target)


# Whether approaching `target` means ramming it: the lance armed with lances left, and something it
# can strike: a ship, a wreck or an ore chunk (shoved), or a rock with ore left (to break chunks off),
# as NPCs ram them (null: any of these would do). A station or a worked-out rock is approached.
func is_ram_ready(target = null) -> bool:
	var lance = agent_body.get_lance() if is_instance_valid(agent_body) and agent_body.has_method("get_lance") else null
	if lance == null or not lance.armed or agent_body.get_lance_nails() <= 0:
		return false
	return target == null or is_rammable(target)


static func is_rammable(target) -> bool:
	if not (target is Spatial and is_instance_valid(target)):
		return false
	if target is RigidBody and target.has_method("apply_damage"):
		return not target.is_in_group("loose_lance")  # Harpooned, not shoved
	return target.is_in_group("mineable") and target.has_method("get_deposit") and target.get_deposit() > 0


# Arming the lance turns an approach into a ram; making it safe (or running out) turns it back.
func _sync_ram_command() -> void:
	var nav = agent_body.get_node_or_null("NavigationSystem") if is_instance_valid(agent_body) else null
	if not is_instance_valid(nav):
		return
	var type: int = nav.get_current_command_type()
	var target = nav._current_command.get("target_node", null)
	if not is_instance_valid(target):
		return
	if type == NavigationSystem.CommandType.APPROACH and is_ram_ready(target):
		agent_script.command_ram(target)
	elif type == NavigationSystem.CommandType.RAM and not is_ram_ready(target):
		agent_script.command_approach(target)


func _on_Player_Flee_Pressed():
	if _toggled_off([NavigationSystem.CommandType.FLEE]):
		return
	if is_instance_valid(_selected_target) and _selected_target is Spatial:
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
	if is_instance_valid(_tool_controller):
		_tool_controller.deactivate_all("docked")
	if agent_body.has_method("dock_at"):
		agent_body.dock_at(_find_station(location_id))
	if HomePort.is_home(location_id):
		var result: Dictionary = HomePort.service(agent_body)
		if result.units > 0 or result.repaired > 0.0 or result.lances > 0 or result.rounds > 0 or result.decoys > 0:
			var message: String = "Home port: banked %d WP from %d units, repaired %d hull" % [result.banked, result.units, result.repaired]
			if result.lances > 0:
				message += ", %d lances for %d WP" % [result.lances, result.lance_cost]
			if result.rounds > 0:
				message += ", %d rounds for %d WP" % [result.rounds, result.ammo_cost]
			if result.decoys > 0:
				message += ", %d decoys for %d WP" % [result.decoys, result.decoy_cost]
			EventBus.emit_signal("dock_action_feedback", true, message)
	else:
		_sell_hold_at(_find_station(location_id), location_id)
	set_process_unhandled_input(false)
	set_physics_process(false)
	# Stop the ship
	if agent_script.has_method("command_stop"):
		agent_script.command_stop()

# Docked at a faction's station: it buys the hold at its cargo price (Market), into the bank.
func _sell_hold_at(station: Node, location_id: String) -> void:
	var faction = station.get("faction") if is_instance_valid(station) else null
	if not Standing.has_standing(faction) or agent_body.get_cargo_units() <= 0:
		return
	var sold: Dictionary = Market.sell_hold(agent_body, location_id, faction)
	EventBus.emit_signal("dock_action_feedback", true, "%s: sold %d units for %d WP (standing %+.2f)" % [Constants.FACTIONS[faction].get("name", faction), sold.units, sold.banked, Standing.of(faction)])


func _on_player_undocked():
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("Player undocked")
	_clear_queued_jump()
	GameState.player_docked_at = ""
	if agent_body.has_method("undock"):
		agent_body.undock()
	set_process_unhandled_input(true)
	set_physics_process(true)


func _find_station(location_id: String) -> Spatial:
	for station in get_tree().get_nodes_in_group("dockable_station"):
		if station.get("location_id") == location_id:
			return station
	return null
