extends Position3D
class_name RebaseGlobal, "res://Assets/UI_images/SVG/icons/rebase_global.svg"

onready var p = get_tree().get_root().get_node("Main/Paths")

onready var rebase_limit = p.common_engine.rebase_limit_margin
var rebase_local = false

func _ready():
	# Make sure space is zeroed.
	self.global_transform.origin = Vector3(0,0,0)

func _physics_process(_delta):
	# Hide ship from view to prevent annoying visuals jitter.
	# TODO: add a sprite for the value above which is projected.
	# TODO: move this to a proper module.
	if rebase_limit > p.camera_rig.camera_push_visibility_velocity:
		p.ship.hide()
	else:
		p.ship.show()


	if p.ship.translation.x > rebase_limit:
		p.ship.translation.x = 0
		p.global_space.translation.x -= rebase_limit
		#p.local_space_galaxy.translation.x -= rebase_limit
		p.local_space_system.translation.x -= rebase_limit
		p.local_space_star.translation.x -= rebase_limit
		p.local_space_planet.translation.x -= rebase_limit
		p.local_space_structure.translation.x -= rebase_limit
		
	elif p.ship.translation.x < -rebase_limit:
		p.ship.translation.x = 0
		p.global_space.translation.x += rebase_limit
		#p.local_space_galaxy.translation.x += rebase_limit
		p.local_space_system.translation.x += rebase_limit
		p.local_space_star.translation.x += rebase_limit
		p.local_space_planet.translation.x += rebase_limit
		p.local_space_structure.translation.x += rebase_limit
		
	if p.ship.translation.y > rebase_limit:
		p.ship.translation.y = 0
		p.global_space.translation.y -= rebase_limit
		#p.local_space_galaxy.translation.y -= rebase_limit
		p.local_space_system.translation.y -= rebase_limit
		p.local_space_star.translation.y -= rebase_limit
		p.local_space_planet.translation.y -= rebase_limit
		p.local_space_structure.translation.y -= rebase_limit
		
	elif p.ship.translation.y < -rebase_limit:
		p.ship.translation.y = 0
		p.global_space.translation.y += rebase_limit
		#p.local_space_galaxy.translation.y += rebase_limit
		p.local_space_system.translation.y += rebase_limit
		p.local_space_star.translation.y += rebase_limit
		p.local_space_planet.translation.y += rebase_limit
		p.local_space_structure.translation.y += rebase_limit
		
	if p.ship.translation.z > rebase_limit:
		p.ship.translation.z = 0
		p.global_space.translation.z -= rebase_limit
		#p.local_space_galaxy.translation.z -= rebase_limit
		p.local_space_system.translation.z -= rebase_limit
		p.local_space_star.translation.z -= rebase_limit
		p.local_space_planet.translation.z -= rebase_limit
		p.local_space_structure.translation.z -= rebase_limit
		
	elif p.ship.translation.z < -rebase_limit:
		p.ship.translation.z = 0
		p.global_space.translation.z += rebase_limit
		#p.local_space_galaxy.translation.z += rebase_limit
		p.local_space_system.translation.z += rebase_limit
		p.local_space_star.translation.z += rebase_limit
		p.local_space_planet.translation.z += rebase_limit
		p.local_space_structure.translation.z += rebase_limit
