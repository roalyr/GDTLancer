extends Position3D

class_name RebaseStar, "res://Assets/UI_images/SVG/icons/rebase_star.svg"

var scenes = Position3D

func _ready():
	# ============================= Connect signals ===========================
	Signals.connect("sig_exited_local_space_star", self, "is_exited_local_space_star")
	Signals.connect("sig_entered_local_space_star", self, "is_entered_local_space_star")
	# =========================================================================
	# Make sure space is zeroed.
	self.global_transform.origin = Vector3(0,0,0)
	
# SIGNAL PROCESSING
func is_entered_local_space_star(zone):
	
	# Check if local space was previously freed (to prevent overlapping and messing coordinates).
	if LocalSpaceStar.has_node("Scenes"):
		var scene_names = []

		for c in LocalSpaceStar.get_node("Scenes").get_children():
			scene_names.append(c)
			
		var message = "Local space '"+LocalSpaceStar.get_name() \
			+ "' was not freed properly, which led to overlapping and corrupt object coordinates.\n" \
			+ "Scenes which were not freed properly: " + str(scene_names) 
			
		UiPaths.gui_logic.popup_panic(message)
		
	# Get a child scenes.
	# print("Entered zone: ", zone)
	scenes = zone.get_node("Scenes")
	
	# Recenter local space origin onto zone for best precision.
	LocalSpaceStar.global_transform = zone.global_transform

	# Reparent scenes from global to local space.
	zone.remove_child(scenes)
	LocalSpaceStar.add_child(scenes)

func is_exited_local_space_star(zone):
	
	# print("Exited zone: ", zone)
	
	# Reparent scenes from local to global space (back to zone).
	LocalSpaceStar.remove_child(scenes)
	zone.add_child(scenes)
	scenes.global_transform = zone.global_transform
