extends Spatial
class_name LODs_trigger, "res://Assets/UI_images/SVG/icons/lod_icon.svg"

# If `false`, LOD won't update anymore. This can be used for performance comparison
# purposes.
export var enable_lod = true

export var object_absolute_size = 0

# The maximum LOD 0 (high quality) distance in units.
export var lod_0_relative_distance = 5

# The maximum LOD 1 (medium quality) distance in units.
export var lod_1_relative_distance = 25

# The maximum LOD 2 (low quality) distance in units.
# Past this distance, all LOD variants are hidden.
export var lod_2_relative_distance = 150

# The rate at which LODs will be updated (in seconds). Lower values are more reactive
# but use more CPU, which is especially noticeable with large amounts of LOD-enabled nodes.
# Set this accordingly depending on your camera movement speed.
# The default value should suit most projects already.
# Note: Slow cameras don't need to have LOD-enabled objects update their status often.
# This can overridden by setting the project setting `lod/refresh_rate`.
export var refresh_rate = 0.25

# The internal refresh timer.
var timer = 0.0
# Keep a track on current lod level to pause showing / hiding calls.
var lod_level = -1

func _ready():
	# Get actual size of the object.
	if object_absolute_size == 0:
		object_absolute_size = self.get_scale().length()
	# print(self, ":", object_absolute_size)

	# Add random jitter to the timer to ensure LODs don't all swap at the same time.
	randomize()
	timer += rand_range(0, refresh_rate)


# Despite LOD not being related to physics, we chose to run in `_physics_process()`
# to minimize the amount of method calls per second (and therefore decrease CPU usage).
func _physics_process(delta):
		
	if timer <= refresh_rate:
		timer += delta
		return
	else:
		timer = 0.0
		
	# We need a camera to do the rest.
	var camera = get_viewport().get_camera()
	if camera == null:
		return
		
	if not enable_lod:
		# Show
		if is_shown("LOD0"):
			return
		else:
			show_scenes("LOD0")
			# Hide
			hide_scenes("LOD1")
			hide_scenes("LOD2")
			hide_scenes("LOD3")
			return

	# Relative distance (in object sizes).
	var distance = camera.global_transform.origin.distance_to(global_transform.origin) \
		/ object_absolute_size
		
	# The LOD level to choose (lower is more detailed).
	
	if distance < lod_0_relative_distance:
		# Show
		if is_shown("LOD0"):
			return
		else:
			show_scenes("LOD0")
			# Hide
			hide_scenes("LOD1")
			hide_scenes("LOD2")
			hide_scenes("LOD3")

	elif distance < lod_1_relative_distance:
		# Show
		if is_shown("LOD1"):
			return
		else:
			show_scenes("LOD1")
			# Hide
			hide_scenes("LOD2")
			hide_scenes("LOD0")
			hide_scenes("LOD3")

	elif distance < lod_2_relative_distance:
		# Show
		if is_shown("LOD2"):
			return
		else:
			show_scenes("LOD2")
			# Hide
			hide_scenes("LOD1")
			hide_scenes("LOD0")
			hide_scenes("LOD3")

	else:
		# Show
		if is_shown("LOD3"):
			return
		else:
			show_scenes("LOD3")
			# Hide
			hide_scenes("LOD0")
			hide_scenes("LOD1")
			hide_scenes("LOD2")

func show_scenes(lod_name):
	self.get_node(lod_name).show()
			
func hide_scenes(lod_name):
	self.get_node(lod_name).hide()

func is_shown(lod_name):
	if self.get_node(lod_name).visible:
		return true
