extends Area
class_name ZoneNebula, "res://Assets/UI_images/SVG/icons/nebula.svg"

export var enable_environemnt_switching = false
export var environment_switch_distance = 1e16


export var nebula_brightness_variation = 0.0
export var nebula_contrast_variation = 0.0
export var nebula_saturation_variation = 0.0

var refresh_rate = 1.0
var timer = 0.0
var nebula_entered = false

func _ready():
	# Disable "Monitorable" for the sake of performance.
	self.monitorable = false
	self.monitoring = true

func _physics_process(delta):
	if enable_environemnt_switching:
		# Adjust refresh rate by velocity to minimize the possible lag in visibility switch.
		if PlayerState.ship_linear_velocity == 0:
			refresh_rate = 5.0
		elif PlayerState.ship_linear_velocity > 0 and PlayerState.ship_linear_velocity <= 1e6:
			refresh_rate = 1.0
		elif PlayerState.ship_linear_velocity > 1e6 and PlayerState.ship_linear_velocity <= 1e9:
			refresh_rate = 0.5
		elif PlayerState.ship_linear_velocity > 1e9 and PlayerState.ship_linear_velocity <= 1e12:
			refresh_rate = 0.25
		elif PlayerState.ship_linear_velocity > 1e12:
			refresh_rate = 0.05


		if timer <= refresh_rate:
			timer += delta
			return
		else:
			timer = 0.0
		
		
		# We need a camera to do the rest.
		var camera = get_viewport().get_camera()
		if camera == null:
			return

		# Relative distance (in object sizes).
		var distance = camera.global_transform.origin.distance_to(self.global_transform.origin)
		var is_within_distance = false
		if distance <= environment_switch_distance:
			is_within_distance = true
		else:
			is_within_distance = false
		var data = [self, is_within_distance]
		
		#print(data)
		Signals.emit_signal("sig_nebula_distance", data)
		

func _on_Zone_nebula_body_entered(_body):
	if _body == Paths.player: 
		print("Entered: ", self.name)
		Paths.environment.nebula_brightness_variation = nebula_brightness_variation
		Paths.environment.nebula_contrast_variation = nebula_contrast_variation
		Paths.environment.nebula_saturation_variation = nebula_saturation_variation


func _on_Zone_nebula_body_exited(_body):
	if _body == Paths.player: 
		print("Exited: ", self.name)
		Paths.environment.nebula_brightness_variation = 0.0
		Paths.environment.nebula_contrast_variation = 0.0
		Paths.environment.nebula_saturation_variation = 0.0
		
