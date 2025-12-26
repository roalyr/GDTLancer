# File: modules/piloting/scripts/player_controller_ship.gd
# Version: 5.0 - RigidBody physics with thrust throttle control.

extends Node

# --- References ---
var agent_script: Node = null
var agent_body: RigidBody = null
var movement_system: Node = null
var _main_camera: Camera = null
var _speed_slider: Slider = null
var _weapon_controller: Node = null

# --- Thrust Throttle Control (0.0 to 1.0) ---
var current_thrust_throttle: float = 1.0
const KEY_THROTTLE_INCREMENT: float = 0.05

# --- State ---
var _current_input_state: InputState = null
var _states = {}
var _target_under_cursor: Spatial = null
var _selected_target: Spatial = null setget _set_selected_target
var _can_dock_at: String = ""

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

	_weapon_controller = agent_body.get_node_or_null("WeaponController")

	_states = {"default": StateDefault.new(), "free_flight": StateFreeFlight.new()}

	EventBus.connect("dock_available", self, "_on_dock_available")
	EventBus.connect("dock_unavailable", self, "_on_dock_unavailable")
	EventBus.connect("player_docked", self, "_on_player_docked")
	EventBus.connect("player_undocked", self, "_on_player_undocked")
	EventBus.connect("player_dock_pressed", self, "_on_dock_button_pressed")
	EventBus.connect("player_attack_pressed", self, "_on_attack_button_pressed")

	call_deferred("_deferred_ready_setup")
	_change_state("default")


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
	if _current_input_state and _current_input_state.has_method("exit"):
		_current_input_state.exit()

	if _states.has(new_state_name):
		_current_input_state = _states[new_state_name]
		if _current_input_state.has_method("enter"):
			_current_input_state.enter(self)
	else:
		printerr("PlayerController Error: Attempted to change to unknown state: ", new_state_name)


func _physics_process(delta: float):
	if _current_input_state and _current_input_state.has_method("physics_update"):
		_current_input_state.physics_update(delta)


func _unhandled_input(event: InputEvent):
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
	if _current_input_state and _current_input_state.has_method("handle_input"):
		_current_input_state.handle_input(event)


func _fire_weapon_at_selected_target(force: bool, source: String = "") -> void:
	if not is_instance_valid(_weapon_controller):
		print("PlayerController: Fire skipped (no WeaponController)")
		return
	if not _weapon_controller.has_method("fire_at_target"):
		print("PlayerController: Fire skipped (WeaponController missing fire_at_target)")
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
	var result: Dictionary = _weapon_controller.call("fire_at_target", 0, target_uid, target_pos)
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


# --- Contextual Interact ---
func _handle_interact_input() -> void:
	# Legacy keyboard interact - just dock if available
	if _can_dock_at != "":
		print("PlayerController: Attempting to dock at ", _can_dock_at)
		EventBus.emit_signal("player_docked", _can_dock_at)


# --- Dock/Attack Button Handlers ---
func _on_dock_button_pressed() -> void:
	if _can_dock_at != "":
		print("PlayerController: Dock button pressed, docking at ", _can_dock_at)
		EventBus.emit_signal("player_docked", _can_dock_at)
	else:
		# Emit signal to show "no dock available" popup on HUD
		if EventBus:
			EventBus.emit_signal("dock_action_feedback", false, "No station in range")


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


# --- Helper & Command Functions (Publicly callable by states) ---
func _update_target_under_cursor():
	_target_under_cursor = _raycast_for_target(get_viewport().get_mouse_position())


func _set_selected_target(new_target: Spatial):
	if _selected_target == new_target:
		return
	_selected_target = new_target
	if is_instance_valid(_selected_target):
		EventBus.emit_signal("player_target_selected", _selected_target)
	else:
		EventBus.emit_signal("player_target_deselected")


func _handle_single_click(_click_pos: Vector2):
	self._selected_target = _target_under_cursor


func _handle_double_click(click_pos: Vector2):
	if is_instance_valid(agent_script) and is_instance_valid(_main_camera):
		var ray_origin = _main_camera.project_ray_origin(click_pos)
		var ray_normal = _main_camera.project_ray_normal(click_pos)
		var target_point = ray_origin + ray_normal * Constants.TARGETING_RAY_LENGTH
		agent_script.command_move_to(target_point)


func _issue_stop_command():
	if not is_instance_valid(agent_script):
		return
	agent_script.command_stop()
	if _current_input_state is StateFreeFlight:
		_change_state("default")


func _issue_approach_command():
	if not is_instance_valid(agent_script):
		return
	if EventBus:
		EventBus.emit_signal("player_approach_pressed")
	if _current_input_state is StateFreeFlight:
		_change_state("default")


func _issue_flee_command():
	if not is_instance_valid(agent_script):
		return
	if EventBus:
		EventBus.emit_signal("player_flee_pressed")
	if _current_input_state is StateFreeFlight:
		_change_state("default")


func _issue_orbit_command():
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


# --- Signal Handlers ---
func _on_Player_Free_Flight_Toggled():
	var new_state = "default" if _current_input_state is StateFreeFlight else "free_flight"
	_change_state(new_state)


func _on_Player_Stop_Pressed():
	_issue_stop_command()


func _on_Player_Orbit_Pressed():
	if is_instance_valid(_selected_target):
		agent_script.command_orbit(_selected_target)


func _on_Player_Approach_Pressed():
	if is_instance_valid(_selected_target):
		agent_script.command_approach(_selected_target)


func _on_Player_Flee_Pressed():
	if is_instance_valid(_selected_target):
		agent_script.command_flee(_selected_target)

func _on_Player_Interact_Pressed():
	if _can_dock_at != "":
		print("PlayerController: Interact button pressed. Attempting to dock at ", _can_dock_at)
		EventBus.emit_signal("player_docked", _can_dock_at)
	else:
		print("PlayerController: Interact button pressed but no dock available.")

func _on_Player_Ship_Speed_Slider_Changed_By_HUD(slider_ui_value: float):
	current_thrust_throttle = (100.0 - slider_ui_value) / 100.0
	_update_throttle_and_slider_visuals()


# --- Connections & Cleanup ---
func _connect_eventbus_signals():
	EventBus.connect("player_free_flight_toggled", self, "_on_Player_Free_Flight_Toggled")
	EventBus.connect("player_stop_pressed", self, "_on_Player_Stop_Pressed")
	EventBus.connect("player_orbit_pressed", self, "_on_Player_Orbit_Pressed")
	EventBus.connect("player_approach_pressed", self, "_on_Player_Approach_Pressed")
	EventBus.connect("player_flee_pressed", self, "_on_Player_Flee_Pressed")
	EventBus.connect("player_interact_pressed", self, "_on_Player_Interact_Pressed")
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
		if EventBus.is_connected("player_stop_pressed", self, "_on_Player_Stop_Pressed"):
			EventBus.disconnect("player_stop_pressed", self, "_on_Player_Stop_Pressed")
		if EventBus.is_connected("player_orbit_pressed", self, "_on_Player_Orbit_Pressed"):
			EventBus.disconnect("player_orbit_pressed", self, "_on_Player_Orbit_Pressed")
		if EventBus.is_connected("player_approach_pressed", self, "_on_Player_Approach_Pressed"):
			EventBus.disconnect("player_approach_pressed", self, "_on_Player_Approach_Pressed")
		if EventBus.is_connected("player_flee_pressed", self, "_on_Player_Flee_Pressed"):
			EventBus.disconnect("player_flee_pressed", self, "_on_Player_Flee_Pressed")
		if EventBus.is_connected("player_interact_pressed", self, "_on_Player_Interact_Pressed"):
			EventBus.disconnect("player_interact_pressed", self, "_on_Player_Interact_Pressed")
		if EventBus.is_connected(
			"player_ship_speed_changed", self, "_on_Player_Ship_Speed_Slider_Changed_By_HUD"
		):
			EventBus.disconnect(
				"player_ship_speed_changed", self, "_on_Player_Ship_Speed_Slider_Changed_By_HUD"
			)

# --- Docking Handlers ---
func _on_dock_available(location_id):
	_can_dock_at = location_id
	print("PlayerController: Docking available at: ", location_id, ". Press Interact (Space/Enter) to dock.")
	# TODO: Show UI prompt

func _on_dock_unavailable():
	_can_dock_at = ""
	print("PlayerController: Docking unavailable.")
	# TODO: Hide UI prompt

func _on_player_docked(location_id):
	print("Player docked at: ", location_id)
	GameState.player_docked_at = location_id
	set_process_unhandled_input(false)
	set_physics_process(false)
	# Stop the ship
	if agent_script.has_method("command_stop"):
		agent_script.command_stop()

func _on_player_undocked():
	print("Player undocked")
	GameState.player_docked_at = ""
	set_process_unhandled_input(true)
	set_physics_process(true)

