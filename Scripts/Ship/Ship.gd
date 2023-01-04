extends RigidBody

# TODO check materials and shaders for FX
# Params.
const ship_mass = 1e6
const accel_factor = 1e2 # Propulsion force.
const accel_ticks_max = pow(2,29) # Engine propulsion increments. Pow 2.

# Turning sensitivity LEFT-RIGHT | UP-DOWN | ROLL
const torque_factor = Vector3(15e8,7e8,7e8)

const camera_vert_offset = 1
const camera_horiz_offset = 6

const engine_step_delay = 0.3

const autopilot_angle_deviation = 0.8

# Lesser is more precise, aim at ration 1:2 for decel being larger
# Higher numbers mean more agressive AP velocity handling.
const autopilot_accel_factor = 0.22 # 0.22
const autopilot_deccel_factor = 0.44 # 0.44

# Orbiting factor allows to approach not at a straight line, but slightly orbiting.
const autopilot_orbiting_factor = 0.1 # Keep it small. Less than 1.0 - deviation

# Vars.
var default_linear_damp = 0
var tx = 0
var ty = 0
var tz = 0
var engine_delay = false

var autopilot_target = Position3D
var target_origin = Vector3(0,0,0)
var autopilot_range = 0

var dist_val = 0
var steering_vector = Vector3(0,0,0)
var control_held = false

# Objects.
var torque = Vector3(0,0,0)

# Nodes.

onready var engines = get_node("Engines")





# Called when the node enters the scene tree for the first time.
func _ready():
	# ============================= Connect signals ===========================
	Signals.connect("sig_accelerate", self, "is_accelerating")
	Signals.connect("sig_engine_kill", self, "is_engine_kill")
	Signals.connect("sig_autopilot_start", self, "is_autopilot_start")
	Signals.connect("sig_autopilot_disable", self, "is_autopilot_disable")
	# =========================================================================
	
	# Initialize the vessel params.
	init_ship()

func _integrate_forces(state):	

	
	#print("L: ", state.total_linear_damp, "   A: ", state.total_angular_damp)
	# TODO: arrange for proper signs for accel and torque.
	var vel = state.linear_velocity.length()
	PlayerState.ship_linear_velocity = vel
	PlayerState.apparent_velocity = vel
	
	# Modify origin rebase limit.
	if vel > Constants.rebase_limit_margin*Constants.rebase_lag:
		GlobalSpace.rebase_limit = round(vel*Constants.rebase_lag)
	
	state.add_central_force(-global_transform.basis.z * PlayerState.acceleration* PlayerState.acceleration)
	
	# Limiting by engine ticks. It is a hard rebase_limits.
	# TODO: move capped velocity to constants.
	if vel > 3e6 and self.continuous_cd:
		self.continuous_cd = false
		print("disable ship CCD due to high velocity")
	elif vel <= 3e6 and not self.continuous_cd:
		self.continuous_cd = true
		print("enable ship CCD")


	# AUTOPILOT
	
	# Coordinates must be within physics process because they are updating.
	if PlayerState.autopilot_target_locked:
		# Fail-safety
		if autopilot_target.is_class("GDScriptNativeClass"):
			return
		target_origin = autopilot_target.global_transform.origin
		autopilot_range = autopilot_target.autopilot_range
	
	#print(autopilot_range)

	
	# Acceleration control.
	if PlayerState.autopilot:

		var ship_origin = self.global_transform.origin
		dist_val = round(ship_origin.distance_to(target_origin))
		var ship_forward = -self.global_transform.basis.z
		var dir_vector = ship_origin.direction_to(target_origin)
		var dot_product = ship_forward.dot(dir_vector)

		steering_vector = ship_forward.cross(dir_vector)
		
		# TODO: improve acceleration rate based on distance.
		if (vel < dist_val*autopilot_accel_factor) and (dot_product > autopilot_angle_deviation)\
			and (dist_val > autopilot_range):
			is_accelerating(true)
		elif (vel > dist_val*autopilot_deccel_factor) or (dot_product < autopilot_angle_deviation)\
			or (dist_val < autopilot_range): 
			is_accelerating(false)
	
	if PlayerState.autopilot and dist_val < autopilot_range:
		Signals.emit_signal("sig_autopilot_disable")
	
	# Steering.
	# Get deltas (multiply and clamp):
	var autopilot_torque_factor = 10

	var autopilot_factor_x = clamp(autopilot_torque_factor*steering_vector.x+autopilot_orbiting_factor, -1.0, 1.0)
	var autopilot_factor_y = clamp(autopilot_torque_factor*steering_vector.y+autopilot_orbiting_factor, -1.0, 1.0)
	var autopilot_factor_z = clamp(autopilot_torque_factor*steering_vector.z+autopilot_orbiting_factor, -1.0, 1.0)

	
	# Due to difference in handling LMB and stick actuation, check those separately for
	# different game modes.
	if not GameOptions.touchscreen_mode and GlobalInput.LMB_held:
		control_held = true
	elif GameOptions.touchscreen_mode and Paths.ui.stick_held:
		control_held = true
	else: 
		control_held = false
	
	# If AP is on, controls are not engaged, but allow camera orbit.
	if PlayerState.autopilot and \
		((not PlayerState.turret_mode and not (control_held or PlayerState.mouse_flight)) \
		or PlayerState.turret_mode):

		# Fix directions being flipped

		tx = self.torque_factor.x* autopilot_factor_x
		ty = self.torque_factor.y* autopilot_factor_y
		tz = self.torque_factor.z* autopilot_factor_z

		state.add_torque(Vector3(tx, ty, tz))
	
	
	
	
	
	# AUTOPILOT




	
	if not PlayerState.turret_mode and (control_held or PlayerState.mouse_flight):

		var tx = -transform.basis.y*self.torque_factor.x* GlobalInput.mouse_vector.x
		var ty = -transform.basis.x*self.torque_factor.y* GlobalInput.mouse_vector.y
		
		state.add_torque(tx+ty)
	
	#print(state.get_total_angular_damp())


	# DAMPING
	var damp_coeff = 1e-4
	var damp_linear = 1.0 - state.step * Constants.global_linear_damp

	if (damp_linear < 0):
		damp_linear = 0


	var damp_angular = 1.0 - state.step * Constants.global_angular_damp 

	if (damp_angular < 0):
		damp_angular = 0
	
	state.linear_velocity *= damp_linear
	state.angular_velocity *= damp_angular



# ================================== Other ====================================
# TODO: Split it off to self's specific properties later on.
func init_ship():
	# Enable continuous collision detection
	# TODO: enable ccd based on velocity
	self.continuous_cd = true
	self.custom_integrator = true
	self.can_sleep = false
	self.mass = self.ship_mass
	adjust_exhaust()
	# Initiate timer.
	engine_cooldown()

# Globally limit the speed of engine gear shifting.
func engine_cooldown():
	get_tree().create_timer(engine_step_delay).connect("timeout", self, "set_timing", [false])

# Do not remove, it is needed for engine change speed control.
func set_timing(value: bool):
	engine_delay = value
	# Reset timer
	engine_cooldown()

func adjust_exhaust():
	
	var engine_warp_factor = 1e-3
	
	var a = log(max(PlayerState.accel_ticks, 1))
	var accel_val = pow(a, 1.0 + pow(a,5)*2e-5)
	if accel_val > 1e3:
		accel_val = 1e3
	
	for i in engines.get_children():
		
		# Adjust shape size.
		i.get_node("Engine_exhaust_shapes").scale.z = accel_val

		var albedo = accel_val

		# Get and modify sprite intensity.
		var shapes = i.get_node("Engine_exhaust_shapes")
		for shape in shapes.get_children():
			var m = shape.get_surface_material(0)
			
			m["shader_param/albedo"].r = clamp(albedo*0.4, 1e-6, 0.6)
			m["shader_param/albedo"].g = clamp(albedo*0.1, 1e-6, 0.2)
			m["shader_param/albedo"].b = clamp(albedo*0.05, 1e-6, 0.8)
		
		# Adjust light intensity
		if PlayerState.accel_ticks > 0:
			i.get_node("Engine_exhaust_light").light_energy = accel_val
		else:
			i.get_node("Engine_exhaust_light").light_energy = 0.1



# SIGNAL PROCESSING
#func is_accelerating_old(flag):
#	if flag and (PlayerState.accel_ticks < accel_ticks_max) and not engine_delay:
#		if PlayerState.accel_ticks == 0:
#			PlayerState.accel_ticks = 1
#		PlayerState.accel_ticks *= 2
#		PlayerState.acceleration += PlayerState.accel_ticks*accel_factor
#		engine_delay = true
#	elif not flag and (PlayerState.accel_ticks > 0) and not engine_delay:
#		PlayerState.acceleration -= PlayerState.accel_ticks*accel_factor
#		PlayerState.accel_ticks /= 2
#		if PlayerState.accel_ticks == 1:
#			PlayerState.accel_ticks = 0
#		engine_delay = true
#	adjust_exhaust()
#
#func is_accelerating(flag):
#	if flag and (PlayerState.accel_ticks < accel_ticks_max) and not engine_delay:
#		if PlayerState.accel_ticks == 0:
#			PlayerState.accel_ticks = 1
#		PlayerState.accel_ticks *= 2
#		PlayerState.acceleration += PlayerState.accel_ticks*accel_factor
#		engine_delay = true
#	elif not flag and (PlayerState.accel_ticks > 0) and not engine_delay:
#		PlayerState.acceleration -= PlayerState.accel_ticks*accel_factor
#		PlayerState.accel_ticks /= 2
#		if PlayerState.accel_ticks == 1:
#			PlayerState.accel_ticks = 0
#		engine_delay = true
#	adjust_exhaust()

func is_accelerating(accelerating):
	if accelerating and (PlayerState.accel_ticks < accel_ticks_max) and not engine_delay:
		if PlayerState.accel_ticks == 0:
			PlayerState.accel_ticks = 1
		PlayerState.accel_ticks *= 2
		PlayerState.acceleration += PlayerState.accel_ticks*accel_factor
		engine_delay = true
	elif not accelerating and (PlayerState.accel_ticks > 0) and not engine_delay:
		PlayerState.acceleration -= PlayerState.accel_ticks*accel_factor
		PlayerState.accel_ticks /= 2
		if PlayerState.accel_ticks == 1:
			PlayerState.accel_ticks = 0
		engine_delay = true
	adjust_exhaust()


func is_engine_kill():
	PlayerState.acceleration = 0
	PlayerState.accel_ticks = 0
	adjust_exhaust()


func is_autopilot_start():
	if PlayerState.autopilot_target_locked:
		autopilot_target = PlayerState.autopilot_target
		PlayerState.autopilot = true
	
func is_autopilot_disable():
	is_engine_kill()
	PlayerState.autopilot = false
