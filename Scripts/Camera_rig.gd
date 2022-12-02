extends Spatial

#TODO: make this scene instance to any object that is focused on in game.

# Values.
var camera_min_zoom = 0
var camera_max_zoom = 0
var current_zoom = 0
var camera_vert = 0
var camera_horiz = 0
var zoom_ticks = 0
var camera_push_z = 0
var camera_push_y = 0
# Chase camera positions.
var vert = 0
var horiz = 0
# Camera velocity-related effects.
var init_push = Vector2(0.0, 0.0)
var init_fov = Vector2(0.0, 0.0)
var init_brightness = Vector2(0.0, 0.0)
var init_near = Vector2(0.0, 0.0)


# Objects.
var mouse_vector = Vector2(0,0)
var control_held = false

# TODO: move to common?
# Those numbers are made to create a distortion effect 
var camera_fov_velocity_factor = 1e-4
var camera_fov_derivative = 4
var camera_fov_max_delta = 175 - 60

var camera_brightness_velocity_factor = 1e-4
var camera_brightness_derivative = 0.1
var camera_brightness_max_delta = 5.0
# TODO: adjust background colors separatenly?

var camera_z_near_velocity_factor = 1e-5

# Paths node.
onready var p = get_tree().get_root().get_node("Main/Paths")

func _ready():
	# ============================ Initialize nodes ===========================

	# ============================ Connect signals ============================
	p.signals.connect("sig_turret_mode_on", self, "is_turret_mode_on")
	p.signals.connect("sig_zoom_value_changed", self, "is_zoom_value_changed")
	# =========================================================================
	
	# Safeguards to prevent clipping.
	camera_min_zoom = p.ship.camera_horiz_offset
	camera_max_zoom = p.common_camera.camera_zoom_out_max
	# Puts camera at proper distance from the model at start.
	current_zoom = p.ship.camera_horiz_offset
	fix_camera()
	
func _physics_process(delta):
	
	# Due to difference in handling LMB and stick actuation, check those separately for
	# different game modes.
	var control_held = false
	if not p.main.touchscreen_mode and p.input.LMB_held:
		control_held = true
	elif p.main.touchscreen_mode and p.ui.stick_held:
		control_held = true
	else: 
		control_held = false
	
	
	# Track the change in camera mode and update mouse vector when LMB is held.
	# When the mouse is released proceed with a little of inertia for smoothness.
	if p.ship_state.turret_mode and \
	(control_held or p.ship_state.mouse_flight):
		mouse_vector = p.input.mouse_vector
		orbit_camera(mouse_vector)
	elif p.ship_state.turret_mode and \
	(not control_held or not p.ship_state.mouse_flight):
		# Stop inertia at small value of the vector.
		if abs(mouse_vector.x) > 0.01:
			mouse_vector /= p.common_camera.camera_inertia_factor
			yield(get_tree().create_timer(delta), "timeout")
			orbit_camera(mouse_vector)
	
	# Chase camera.
	if not p.ship_state.turret_mode and \
	(control_held or p.ship_state.mouse_flight):
		mouse_vector = p.input.mouse_vector
		chase_camera(mouse_vector, delta)\
	# Return to initial position.
	elif not p.ship_state.turret_mode and not \
	(control_held or p.ship_state.mouse_flight):
		mouse_vector = Vector2(0,0)
		chase_camera(mouse_vector, delta)
	
# ================================== Other ====================================
func orbit_camera(mv):
	# Compensate camera roll speed by camera altitude.
	var phi = abs(cos(self.rotation.x))
	var roll_vert = -mv.y * p.common_camera.camera_sensitivity
	var roll_horiz = -mv.x * p.common_camera.camera_sensitivity*phi
	camera_vert = self.rotation_degrees.x
	camera_horiz = self.rotation_degrees.y
	if camera_vert + roll_vert >= p.common_camera.camera_turret_roll_vert_limit:
		self.rotation_degrees.x = p.common_camera.camera_turret_roll_vert_limit
	elif camera_vert + roll_vert <= -p.common_camera.camera_turret_roll_vert_limit:
		self.rotation_degrees.x = -p.common_camera.camera_turret_roll_vert_limit
	else:
		self.rotate_object_local(Vector3(1,0,0), deg2rad(roll_vert))
	self.rotate_object_local(Vector3(0,1,0), deg2rad(roll_horiz))
	self.rotation.z = 0

func chase_camera(mv, delta):
	# Initial and final camera position.
	var init_tilt = Vector2($Camera.rotation.x, $Camera.rotation.y)

	# $Camera.rotation.x - vertical, $Camera.rotation.y - horizontal
	# UP - DOWN
	if mv.y < 0:
		vert = -mv.y*cos(
			$Camera.rotation.x
			)/(p.ship.camera_chase_tilt_horiz_damp_up)
	else:
		vert = -mv.y*cos(
			$Camera.rotation.x
			)/(p.ship.camera_chase_tilt_horiz_damp_down)
	# LEFT - RIGHT
	if mv.x < 0:
		horiz = -mv.x*cos(
			$Camera.rotation.y
			)/(p.ship.camera_chase_tilt_vert_damp_left)
	else:
		horiz = -mv.x*cos(
			$Camera.rotation.y
			)/(p.ship.camera_chase_tilt_vert_damp_right)
			
	
	var fin_tilt = Vector2(vert, horiz)
	var fin_push = Vector2(p.ship_state.ship_linear_velocity, 0.0)
	var fin_fov = Vector2(p.ship_state.ship_linear_velocity, 0.0)
	var fin_brightness = Vector2(p.ship_state.ship_linear_velocity, 0.0)
	var fin_near = Vector2(p.ship_state.ship_linear_velocity, 0.0)
		
	var tmp_tilt = init_tilt.linear_interpolate(fin_tilt, delta
		* p.ship.camera_tilt_velocity_factor)
	var tmp_push = init_push.linear_interpolate(fin_push, pow(delta
		*p.ship.camera_push_velocity_factor,3))
	var tmp_fov = init_fov.linear_interpolate(fin_fov, delta
		* camera_fov_velocity_factor)
	var tmp_brightness = init_brightness.linear_interpolate(fin_brightness, delta
		* camera_brightness_velocity_factor)
	
	# Needed to prevent artifacts.
	var tmp_near = init_near.linear_interpolate(fin_near, delta
		* camera_z_near_velocity_factor)
		
	# Prevent camera sliding forward
	# if tmp_push.x < camera_min_zoom:
	tmp_push.x = camera_min_zoom+tmp_push.x
	
	# Vertical camera push to hide the jitter from the engine trail.
	# Normalize value here and add it to default offset at 0 speed.
	camera_push_y = p.ship.camera_vert_offset \
		+ clamp(3*log(tmp_push.x/p.ship.camera_horiz_offset), 
			1e-6, p.ship.camera_push_max_factor)
	
	# Vertical push to hide overall jittering model.
	camera_push_z = clamp(tmp_push.x, 1e-6, p.ship.camera_push_max_factor)
	
	
	$Camera.translation.z = camera_push_z
	$Camera.translation.y = camera_push_y
	
	# This simulates warp effect and hides ship model.
	p.camera.fov = p.common_camera.camera_fov \
		+ clamp(camera_fov_derivative*log(tmp_fov.x), 1e-6, camera_fov_max_delta)
	
	# Brightness adjustment for velocity.
	p.environment.warp_brightness_variation = clamp(camera_brightness_derivative*log(tmp_brightness.x), 1e-6, camera_brightness_max_delta)
	
	# Increasing camera Z near value prevents flickering.
	p.camera.near = p.common_camera.camera_near + tmp_near.x
	
	# print(p.camera.near)
	
	# Tilt motion
	$Camera.rotation.x = tmp_tilt.x
	$Camera.rotation.y = tmp_tilt.y
	self.rotation.x = -tmp_tilt.x
	self.rotation.y = -tmp_tilt.y

	

# Initial position for turret camera
func turret_camera():
	$Camera.translation.y = 0
	$Camera.translation.z = p.ship.camera_horiz_offset
	zoom_ticks = 0
	current_zoom = p.ship.camera_horiz_offset

# Initial position for chase camera
func fix_camera():
	self.rotation_degrees.x = 0
	self.rotation_degrees.y = 0
	self.rotation_degrees.z = 0
	$Camera.rotation_degrees.x = 0
	$Camera.rotation_degrees.y = 0
	$Camera.rotation_degrees.z = 0
	$Camera.translation.y = p.ship.camera_vert_offset
	$Camera.translation.z = p.ship.camera_horiz_offset
	zoom_ticks = 0
	current_zoom = p.ship.camera_horiz_offset
	
func zoom_camera(mouse_event):
	if mouse_event.is_pressed():
		var delta = get_physics_process_delta_time()
		#print(camera_min_zoom," | ",  current_zoom, " | ", camera_max_zoom)
		if mouse_event.button_index == BUTTON_WHEEL_UP and \
		current_zoom <= camera_max_zoom:
			#zoom_ticks += 1
			#current_zoom += pow(p.common_camera.camera_zoom_step*zoom_ticks,3)
			current_zoom *= 2
			$Camera.translation.z = current_zoom
		elif mouse_event.button_index == BUTTON_WHEEL_DOWN and \
		current_zoom >= camera_min_zoom: # and zoom_ticks > 0:
			#current_zoom -= pow(p.common_camera.camera_zoom_step*zoom_ticks,3)
			#zoom_ticks -= 1
			current_zoom /= 2
			$Camera.translation.z = current_zoom
	
# SIGNAL PROCESSING
func is_turret_mode_on(flag):
	if flag:
		# Reset camera first.
		fix_camera()
		turret_camera()
	else:
		fix_camera()

func is_zoom_value_changed(value):
	# print(camera_min_zoom," | ",  current_zoom, " | ", camera_max_zoom)
	zoom_ticks = value
	current_zoom = p.common_camera.camera_zoom_step*zoom_ticks
	if current_zoom <= camera_max_zoom and \
	current_zoom >= camera_min_zoom and \
	zoom_ticks > 0:
		$Camera.translation.z = current_zoom

func is_fov_value_changed(value):
	p.camera.fov = value
