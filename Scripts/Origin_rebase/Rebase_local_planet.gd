extends Position3D

class_name RebasePlanet, "res://Assets/UI_images/SVG/icons/rebase_planet.svg"
onready var p = get_tree().get_root().get_node("Main/Paths")

var scenes = Position3D

func _ready():
	# ============================= Connect signals ===========================
	p.signals.connect("sig_exited_local_space_planet", self, "is_exited_local_space_planet")
	p.signals.connect("sig_entered_local_space_planet", self, "is_entered_local_space_planet")
	# =========================================================================
	# Make sure space is zeroed.
	self.global_transform.origin = Vector3(0,0,0)
	
# SIGNAL PROCESSING
func is_entered_local_space_planet(zone):
	
	# Check if local space was previously freed (to prevent overlapping and messing coordinates).
	if p.local_space_planet.has_node("Scenes"):
		var scene_names = []

		for c in p.local_space_planet.get_node("Scenes").get_children():
			scene_names.append(c)
			
		var message = "Local space '"+p.local_space_planet.get_name() \
			+ "' was not freed properly, which led to overlapping and corrupt object coordinates.\n" \
			+ "Scenes which were not freed properly: " + str(scene_names) 
			
		p.ui_paths.gui_logic.popup_panic(message)
		
	# Get a child scenes.
	# print("Entered zone: ", zone)
	scenes = zone.get_node("Scenes")
	
	# Recenter local space origin onto zone for best precision.
	p.local_space_planet.global_transform = zone.global_transform

	# Reparent scenes from global to local space.
	zone.remove_child(scenes)
	p.local_space_planet.add_child(scenes)

func is_exited_local_space_planet(zone):
	
	# print("Exited zone: ", zone)
	
	# Reparent scenes from local to global space (back to zone).
	p.local_space_planet.remove_child(scenes)
	zone.add_child(scenes)
	scenes.global_transform = zone.global_transform
