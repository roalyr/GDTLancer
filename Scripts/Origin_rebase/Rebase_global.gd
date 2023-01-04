extends Position3D
class_name RebaseGlobal, "res://Assets/UI_images/SVG/icons/rebase_global.svg"

onready var rebase_limit = Constants.rebase_limit_margin
var rebase_local = false

func _ready():
	# Make sure space is zeroed.
	self.global_transform.origin = Vector3(0,0,0)

func _physics_process(_delta):
	# Hide Player from view to prevent annoying visuals jitter.
	# TODO: add a sprite for the value above which is projected.
	# TODO: move this to a proper module.
	if rebase_limit > Paths.camera_rig.camera_push_visibility_velocity:
		Player.hide()
	else:
		Player.show()


	if Player.translation.x > rebase_limit:
		Player.translation.x = 0
		GlobalSpace.translation.x -= rebase_limit
		#p.local_space_galaxy.translation.x -= rebase_limit
		LocalSpaceSystem.translation.x -= rebase_limit
		LocalSpaceStar.translation.x -= rebase_limit
		LocalSpacePlanet.translation.x -= rebase_limit
		LocalSpaceStructure.translation.x -= rebase_limit
		
	elif Player.translation.x < -rebase_limit:
		Player.translation.x = 0
		GlobalSpace.translation.x += rebase_limit
		#p.local_space_galaxy.translation.x += rebase_limit
		LocalSpaceSystem.translation.x += rebase_limit
		LocalSpaceStar.translation.x += rebase_limit
		LocalSpacePlanet.translation.x += rebase_limit
		LocalSpaceStructure.translation.x += rebase_limit
		
	if Player.translation.y > rebase_limit:
		Player.translation.y = 0
		GlobalSpace.translation.y -= rebase_limit
		#p.local_space_galaxy.translation.y -= rebase_limit
		LocalSpaceSystem.translation.y -= rebase_limit
		LocalSpaceStar.translation.y -= rebase_limit
		LocalSpacePlanet.translation.y -= rebase_limit
		LocalSpaceStructure.translation.y -= rebase_limit
		
	elif Player.translation.y < -rebase_limit:
		Player.translation.y = 0
		GlobalSpace.translation.y += rebase_limit
		#p.local_space_galaxy.translation.y += rebase_limit
		LocalSpaceSystem.translation.y += rebase_limit
		LocalSpaceStar.translation.y += rebase_limit
		LocalSpacePlanet.translation.y += rebase_limit
		LocalSpaceStructure.translation.y += rebase_limit
		
	if Player.translation.z > rebase_limit:
		Player.translation.z = 0
		GlobalSpace.translation.z -= rebase_limit
		#p.local_space_galaxy.translation.z -= rebase_limit
		LocalSpaceSystem.translation.z -= rebase_limit
		LocalSpaceStar.translation.z -= rebase_limit
		LocalSpacePlanet.translation.z -= rebase_limit
		LocalSpaceStructure.translation.z -= rebase_limit
		
	elif Player.translation.z < -rebase_limit:
		Player.translation.z = 0
		GlobalSpace.translation.z += rebase_limit
		#p.local_space_galaxy.translation.z += rebase_limit
		LocalSpaceSystem.translation.z += rebase_limit
		LocalSpaceStar.translation.z += rebase_limit
		LocalSpacePlanet.translation.z += rebase_limit
		LocalSpaceStructure.translation.z += rebase_limit
