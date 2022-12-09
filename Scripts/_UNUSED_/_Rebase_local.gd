extends Position3D

onready var p = get_tree().get_root().get_node("Main/Paths")

onready var local_space = Spatial.new()
var scene = Position3D

func _ready():
	# ============================= Connect signals ===========================
	p.signals.connect("sig_exited_local_space", self, "is_exited_local_space")
	p.signals.connect("sig_entered_local_space", self, "is_entered_local_space")
	p.signals.connect("rebase_x_plus", self, "is_rebase_x_plus")
	p.signals.connect("rebase_x_minus", self, "is_rebase_x_minus")
	p.signals.connect("rebase_y_plus", self, "is_rebase_y_plus")
	p.signals.connect("rebase_y_minus", self, "is_rebase_y_minus")
	p.signals.connect("rebase_z_plus", self, "is_rebase_z_plus")
	p.signals.connect("rebase_z_minus", self, "is_rebase_z_minus")
	# =========================================================================

# SIGNAL PROCESSING
func is_entered_local_space(zone):
	
	# Get a child scene.
	print("Entered zone: ", zone)
	scene = zone.get_node("Scenes")

	# Reparent scene from global to local space.
	zone.remove_child(scene)
	p.local_space.add_child(scene)
	scene.global_transform.origin = zone.global_transform.origin
	
	# Enable local space rebase in order to "anchor" it in global space.
	p.global_space.rebase_local = true

func is_exited_local_space(zone):
	
	print("Exited zone: ", zone)
	
	# Reparent scene from local to global space (back to zone).
	p.local_space.remove_child(scene)
	zone.add_child(scene)
	scene.global_transform.origin = zone.global_transform.origin
	
	# Remove local space?
	# TODO: check for overlaps.
	# p.local_space.remove_child(local_space)
		
	# Disable local space rebase.
	p.global_space.rebase_local = false
	
# REBASE
func is_rebase_x_plus():
	p.local_space.translation.x = p.local_space.translation.x-p.global_space.rebase_limit
	
func is_rebase_x_minus():
	p.local_space.translation.x = p.local_space.translation.x+p.global_space.rebase_limit

func is_rebase_y_plus():
	p.local_space.translation.y = p.local_space.translation.y-p.global_space.rebase_limit

func is_rebase_y_minus():
	p.local_space.translation.y = p.local_space.translation.y+p.global_space.rebase_limit

func is_rebase_z_plus():
	p.local_space.translation.z = p.local_space.translation.z-p.global_space.rebase_limit
	
func is_rebase_z_minus():
	p.local_space.translation.z = p.local_space.translation.z+p.global_space.rebase_limit


