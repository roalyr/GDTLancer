extends Position3D

class_name RebaseSystem, "res://Assets/UI_images/SVG/icons/rebase_system.svg"

var scenes = Position3D

func _ready():
	# ============================= Connect signals ===========================
	Signals.connect("sig_exited_local_space_system", self, "is_exited_local_space_system")
	Signals.connect("sig_entered_local_space_system", self, "is_entered_local_space_system")
	# =========================================================================
	# Make sure space is zeroed.
	self.global_transform.origin = Vector3(0,0,0)
	
# SIGNAL PROCESSING
# TODO: handle overlapping zones.
func is_entered_local_space_system(zone):
	
	# Check if local space was previously freed (to prevent overlapping and messing coordinates).
	if LocalSpaceSystem.has_node("Scenes"):
		var scene_names = []

		for c in LocalSpaceSystem.get_node("Scenes").get_children():
			scene_names.append(c)
			
		var message = "Local space '"+LocalSpaceSystem.get_name() \
			+ "' was not freed properly, which led to overlapping and corrupt object coordinates.\n" \
			+ "Scenes which were not freed properly: " + str(scene_names) 
			
		UiPaths.gui_logic.popup_panic(message)
		
	# Get a child scenes.
	# print("Entered zone: ", zone)
	scenes = zone.get_node("Scenes")
	
	# Recenter local space origin onto zone for best precision.
	LocalSpaceSystem.global_transform = zone.global_transform

	# Reparent scenes from global to local space.
	zone.remove_child(scenes)
	LocalSpaceSystem.add_child(scenes)

func is_exited_local_space_system(zone):
	
	# print("Exited zone: ", zone)
	
	# Reparent scenes from local to global space (back to zone).
	LocalSpaceSystem.remove_child(scenes)
	zone.add_child(scenes)
	scenes.global_transform = zone.global_transform
