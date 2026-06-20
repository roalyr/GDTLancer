# PROJECT: GDTLancer
# MODULE: rotating_object.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

extends MeshInstance

export var rotation_speed = 0.01


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	self.rotate(Vector3(0, 1, 0), delta * rotation_speed)