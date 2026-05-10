extends Reference

const RouteTargetScript = preload("res://src/core/targeting/route_target.gd")
const DEFAULT_ROUTE_DIRECTION = Vector3(0, 0, -1)


func build_targets_for_sector(source_sector_id: String) -> Array:
	var route_targets: Array = []
	if source_sector_id == "":
		return route_targets

	var source_position: Vector3 = _get_sector_global_position(source_sector_id)
	var connections: Array = GameState.world_topology.get(source_sector_id, {}).get("connections", [])
	for target_sector_id in connections:
		var target_template = TemplateDatabase.locations.get(target_sector_id)
		if target_template == null:
			continue
		var target_position: Vector3 = _get_sector_global_position(target_sector_id)
		var route_direction: Vector3 = _get_route_direction(source_position, target_position)
		var route_target = RouteTargetScript.new().configure(
			source_sector_id,
			str(target_sector_id),
			_get_display_name(target_template, str(target_sector_id)),
			route_direction
		)
		route_targets.append(route_target)

	return route_targets


func _get_display_name(target_template, fallback_id: String) -> String:
	var location_name = target_template.get("location_name")
	if location_name is String and location_name != "":
		return location_name
	return fallback_id


func _get_sector_global_position(sector_id: String) -> Vector3:
	var sector_template = TemplateDatabase.locations.get(sector_id)
	if sector_template == null:
		return Vector3.ZERO
	var global_position = sector_template.get("global_position")
	return global_position if global_position is Vector3 else Vector3.ZERO


func _get_route_direction(source_position: Vector3, target_position: Vector3) -> Vector3:
	var raw_direction: Vector3 = target_position - source_position
	if raw_direction == Vector3.ZERO:
		return DEFAULT_ROUTE_DIRECTION
	return raw_direction.normalized()