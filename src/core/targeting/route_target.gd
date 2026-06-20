# PROJECT: GDTLancer
# MODULE: route_target.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

extends Reference

var target_kind: String = "jump_route"
var selection_key: String = ""
var source_sector_id: String = ""
var target_sector_id: String = ""
var display_name: String = ""
var route_direction: Vector3 = Vector3.ZERO


func configure(source_id: String, target_id: String, target_name: String, direction: Vector3) -> Reference:
	source_sector_id = source_id
	target_sector_id = target_id
	display_name = target_name
	route_direction = direction.normalized()
	selection_key = "jump_route:%s:%s" % [source_id, target_id]
	return self


func get_projection_world_position(origin: Vector3, projection_distance: float) -> Vector3:
	if route_direction == Vector3.ZERO:
		return origin
	return origin + route_direction * projection_distance