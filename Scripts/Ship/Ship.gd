extends RigidBody

onready var ui = get_node("/root/Main/UI")

# TODO check materials and shaders for FX
# Params.
const ship_mass = 1e6

# rate of change of acceleration.
const accel_damp_factor = 0.3

var velocity_limiter_state = 0
const velocity_limmiter_1 = 1e6
const velocity_limmiter_2 = 1e9
const velocity_limmiter_3 = 1e12
const velocity_limmiter_4 = 1e17


const accel_max = 1e23

const engine_delay_time_base = 0.05
# const engine_delay_lag_factor = 1

var engine_delay_timer = 0
var engine_delay_time = 0.1

var tick_step = 1
const idle_engine_ticks = 50
const accel_ticks_max = 100 + idle_engine_ticks


# Turning sensitivity LEFT-RIGHT | UP-DOWN | ROLL
const torque_factor = Vector3(10e8,5e8,5e8)
const autopilot_torque_factor = 10

const camera_vert_offset = 1
const camera_horiz_offset = 5.5

# Allowed angle deviation for autopilot to engage.
const autopilot_angle_deviation = 0.8

# Lesser is more precise, aim at ration 1:2 for decel being larger
# Higher numbers mean more agressive AP velocity handling.
const autopilot_accel_factor = 0.2 # 0.22
const autopilot_deccel_factor = 0.4 # 0.44

# Orbiting factor allows to approach not at a straight line, but slightly orbiting.
var autopilot_orbiting_factor = 0.05

# Vars.
var default_linear_damp = 0
var tx = 0
var ty = 0
var tz = 0
var engine_delay = false

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
	Signals.connect_checked("sig_accelerate", self, "is_accelerating")
	Signals.connect_checked("sig_engine_kill", self, "is_engine_kill")
	Signals.connect_checked("sig_autopilot_start", self, "is_autopilot_start")
	Signals.connect_checked("sig_autopilot_disable", self, "is_autopilot_disable")
	Signals.connect_checked("sig_target_autopilot_locked", self, "is_target_autopilot_locked")
	Signals.connect_checked("sig_velocity_limiter_set", self, "is_velocity_limiter_set")
	# =========================================================================
	
	# Initialize the vessel params.
	init_ship()

func _physics_process(delta):
	

	if engine_delay_timer <= engine_delay_time:
		engine_delay_timer += delta
	else:
		engine_delay_timer = 0.0
		engine_delay = false

		
	


func _integrate_forces(state):
	
	# TODO: arrange for proper signs for accel and torque.
	var vel = state.linear_velocity.length()
	PlayerState.ship_linear_velocity = vel
	PlayerState.apparent_velocity = vel
	
	# Limit the velocity according to engine state.
	if (vel > velocity_limmiter_1 and velocity_limiter_state == 0) or \
		(vel > velocity_limmiter_2 and velocity_limiter_state == 1) or \
		(vel > velocity_limmiter_3 and velocity_limiter_state == 2) or \
		(vel > velocity_limmiter_4 and velocity_limiter_state == 3):
		# engine_delay_time = engine_delay_time_base * engine_delay_lag_factor
		is_accelerating(false)
	else:
		engine_delay_time = engine_delay_time_base
	
	# Modify origin rebase limit.
	if vel > Constants.rebase_limit_margin*Constants.rebase_lag:
		Paths.global_space.rebase_limit = round(vel*Constants.rebase_lag)
	
	state.add_central_force(-global_transform.basis.z * PlayerState.acceleration)
	
	# Limiting by engine ticks. It is a hard rebase_limits.
	# TODO: move capped velocity to constants.
	if vel > 3e6 and self.continuous_cd:
		self.continuous_cd = false
		GameState.debug("disable ship CCD due to high velocity")
	elif vel <= 3e6 and not self.continuous_cd:
		self.continuous_cd = true
		GameState.debug("enable ship CCD")


	# AUTOPILOT
	
	# Coordinates must be within physics process because they are updating.
	if PlayerState.autopilot_target_locked:
		# Fail-safety
		if PlayerState.autopilot_target.is_class("GDScriptNativeClass"):
			return
		target_origin = PlayerState.autopilot_target.global_transform.origin
		autopilot_range = PlayerState.autopilot_target.autopilot_range

	
	# Acceleration control.
	if PlayerState.autopilot:

		var ship_origin = self.global_transform.origin
		dist_val = round(ship_origin.distance_to(target_origin))
		var ship_forward = -self.global_transform.basis.z
		var dir_vector = ship_origin.direction_to(target_origin)
		var dot_product = ship_forward.dot(dir_vector)

		steering_vector = ship_forward.cross(dir_vector)
		
		if (vel < dist_val*autopilot_accel_factor) and (dot_product > autopilot_angle_deviation)\
			and (dist_val > autopilot_range):
			is_accelerating(true)
		elif (vel > dist_val*autopilot_deccel_factor) or (dot_product < autopilot_angle_deviation)\
			or (dist_val < autopilot_range): 
			is_accelerating(false)
	
	if PlayerState.autopilot and dist_val < autopilot_range:
		Signals.emit_signal("sig_autopilot_disable")
		
	
	
	# Steering.
	var autopilot_factor_x = clamp(autopilot_torque_factor*steering_vector.x+autopilot_orbiting_factor, -1.0, 1.0)
	var autopilot_factor_y = clamp(autopilot_torque_factor*steering_vector.y+autopilot_orbiting_factor, -1.0, 1.0)
	var autopilot_factor_z = clamp(autopilot_torque_factor*steering_vector.z+autopilot_orbiting_factor, -1.0, 1.0)

	
	# Due to difference in handling LMB and stick actuation, check those separately for
	# different game modes.
	if not GameState.touchscreen_mode and GlobalInput.LMB_held:
		control_held = true
	elif GameState.touchscreen_mode and GlobalInput.stick_held:
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

		tx = -transform.basis.y*self.torque_factor.x* GlobalInput.mouse_vector.x
		ty = -transform.basis.x*self.torque_factor.y* GlobalInput.mouse_vector.y
		
		state.add_torque(tx+ty)
	



	# DAMPING

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

	self.continuous_cd = true
	self.custom_integrator = true
	self.can_sleep = false
	self.mass = self.ship_mass
	PlayerState.acceleration = 0
	PlayerState.accel_ticks = idle_engine_ticks
	adjust_exhaust()


func adjust_exhaust():
	
	var a = log(max(PlayerState.accel_ticks - idle_engine_ticks, 1))
	var accel_val = a + pow(a, pow(a, 12)*4.4e-8)
	if accel_val > 1e3:
		accel_val = 1e3

	for i in engines.get_children():
		
		var albedo = accel_val

		# Adjust light intensity
		if PlayerState.accel_ticks > idle_engine_ticks:
			i.get_node("Engine_exhaust_light").light_energy = accel_val/5
			i.get_node("Engine_exhaust_shapes").scale.z = accel_val
			albedo = accel_val
		else:
			i.get_node("Engine_exhaust_light").light_energy = 0
			i.get_node("Engine_exhaust_shapes").scale.z = 0
			albedo = 0
			
			
		# Get and modify sprite intensity.
		var shapes = i.get_node("Engine_exhaust_shapes")
		for shape in shapes.get_children():
			var m = shape.get_surface_material(0)
			
			m["shader_param/albedo"].r = clamp(albedo*0.4, 1e-6, 0.6)
			m["shader_param/albedo"].g = clamp(albedo*0.1, 1e-6, 0.2)
			m["shader_param/albedo"].b = clamp(albedo*0.05, 1e-6, 0.8)


func is_accelerating(accelerating):

	if PlayerState.acceleration < accel_max:
		if accelerating and not engine_delay:
			
			PlayerState.accel_ticks += tick_step
			engine_delay = true
			
	
	# Deceleration.
	if not accelerating and (PlayerState.accel_ticks > idle_engine_ticks) and not engine_delay:
		
		PlayerState.accel_ticks -= tick_step
		engine_delay = true

		
		if PlayerState.accel_ticks < idle_engine_ticks:
			PlayerState.accel_ticks = idle_engine_ticks

	# Adjust acceleration factor.
	PlayerState.acceleration = pow(pow(2.0, PlayerState.accel_ticks), accel_damp_factor)
	
	# Adjust visuals.
	adjust_exhaust()


func is_engine_kill():
	PlayerState.acceleration = 0
	PlayerState.accel_ticks = idle_engine_ticks
	adjust_exhaust()
		
func is_target_autopilot_locked(target):
	PlayerState.autopilot_target = target
	PlayerState.autopilot_target_locked = true
	
func is_autopilot_start():
	PlayerState.autopilot = true
	# Slightly randomize spinning when on autopilot.
	autopilot_orbiting_factor *= sign(rand_range(-1,1))

func is_autopilot_disable():
	is_engine_kill()
	PlayerState.autopilot = false

func is_velocity_limiter_set(value):
	velocity_limiter_state = value
