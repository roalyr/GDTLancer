extends Position3D

onready var p = get_tree().get_root().get_node("Main/Paths")
onready var marker = preload("res://Scenes/UI/Marker.tscn").instance()
onready var object_name = self.name
onready var object_origin = self.global_transform.origin

enum MarkerRange {GALAXY, SYSTEM, STAR, PLANET, STRUCTURE}
export(MarkerRange) var marker_range

var marker_added = false
var dist_val = 0
var marker_visible_min_distance = 0
var marker_visible_max_distance = 0

func _ready():
	match marker_range:
		
		# Assign marker visibility ranges.
		MarkerRange.GALAXY:
			# print("Galaxy range for object_origin: ", self)
			marker_visible_min_distance = 0
			marker_visible_max_distance = 1e21
		MarkerRange.SYSTEM:
			# print("System range for object_origin: ", self)
			marker_visible_min_distance = 1e14
			marker_visible_max_distance = 2e18
		MarkerRange.STAR:
			# print("Star range for object_origin: ", self)
			marker_visible_min_distance = 0
			marker_visible_max_distance = 1e14
		MarkerRange.PLANET:
			# print("Planet range for object_origin: ", self)
			marker_visible_min_distance = 0
			marker_visible_max_distance = 1e13
		MarkerRange.STRUCTURE:
			# print("Planet range for object_origin: ", self)
			marker_visible_min_distance = 0
			marker_visible_max_distance = 1e8


	# TODO: handle markers disappearance properly!

	# Insert marker into the global marker list (and keep it there)
	p.common_space_state.markers.append(self)
	#print(p.common_space_state.markers)

func _physics_process(_delta):
	# Get coordinates and distance.
	var player = p.camera_rig.global_transform.origin
	object_origin = self.global_transform.origin
	dist_val = round(player.distance_to(object_origin))
	
	# Object visible, marker within range. Enable marker.
	if self.visible and dist_val >= marker_visible_min_distance and dist_val < marker_visible_max_distance:
		
		# Instance marker in the gameplay UI if not done so before.
		if !marker_added:
			#print("Adding marker for: ", self)
			p.ui_paths.markers.add_child(marker)
			marker_added = true
		
		# Multiply by scale factor of viewport to position properly.
		marker.visible = not p.viewport.get_camera().is_position_behind(object_origin)
		marker.rect_position = p.viewport.get_camera().unproject_position(
			object_origin)/p.common_viewport.render_res_factor
		
		# Update marker.
		var result_d = p.ui_paths.common_readouts.get_magnitude_units(dist_val)
		marker.get_node("Text").text = object_name + ": "\
				+str(result_d[0])+ " " + result_d[1]
	
	else: 
		if marker and marker_added:
			# If object_origin is hidden then remove marker.
			#print("Removing marker for: ", self)
			p.ui_paths.markers.remove_child(marker)
			marker_added = false