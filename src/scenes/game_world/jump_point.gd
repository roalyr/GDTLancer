#
# PROJECT: GDTLancer
# MODULE: jump_point.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT §Architecture, TACTICAL_TODO §TASK_4
# LOG_REF: 2026-03-27
#

extends StaticBody

export var target_sector_id: String = ""
export var target_sector_name: String = ""

onready var detection_zone = $DetectionZone

func _ready():
	add_to_group("jump_point")
	if detection_zone:
		detection_zone.monitoring = true
		detection_zone.monitorable = true
		detection_zone.collision_layer = 1
		detection_zone.collision_mask = 1
		detection_zone.connect("body_entered", self, "_on_body_entered")
		detection_zone.connect("body_exited", self, "_on_body_exited")

		var bodies = detection_zone.get_overlapping_bodies()
		for body in bodies:
			_on_body_entered(body)
	else:
		printerr("JumpPoint Error: DetectionZone not found!")

func _on_body_entered(body):
	if body == self:
		return
	if not body is RigidBody:
		return
	if body.has_method("is_player") and body.is_player():
		EventBus.emit_signal("jump_available", target_sector_id, target_sector_name)

func _on_body_exited(body):
	if body == self:
		return
	if not body is RigidBody:
		return
	if body.has_method("is_player") and body.is_player():
		EventBus.emit_signal("jump_unavailable")
