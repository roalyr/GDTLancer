# ToolController: switches an agent's tools on against a target and runs their cycles.
# Tools come from the ship preset (ShipTemplate.equipped_tools -> UtilityToolTemplate presets).
# No aiming: results depend on range and on the target's angular velocity.
# Child of AgentBody; used identically by the player and the AI.
#
# Tool types:
#   laser   - targets live ships; each cycle deals damage scaled by hit quality. Whatever is in the
#             line of fire (a rock, another ship) takes the shot instead: rocks are marked, ships damaged.
#   harpoon - targets wrecks; one launch attaches a tether that reels in to a safe towing distance,
#             then strips salvage into the hold one unit per strip_interval. Off = cable released.

extends Node

const LaserHitEffect = preload("res://src/core/agents/effects/laser_hit_effect.gd")
const LaserHitScene = preload("res://scenes/prefabs/effects/laser_hit.tscn")
const Tether = preload("res://src/core/agents/components/tether.gd")

signal tool_activated(tool_index, target)
signal tool_deactivated(tool_index, reason)
signal tool_cycled(tool_index, target, hit_quality, damage)
signal salvage_stripped(tool_index, commodities)
signal tool_blocked(tool_index, target, blocker)  # Something in the line of fire took the shot

# Tethered bodies stop this far apart: the sum of both apparent radii times this factor.

var _agent_body: RigidBody = null
var _tools: Array = []  # UtilityToolTemplate per mount, in ship order
var _targets: Dictionary = {}  # tool_index -> target body while switched on
var _cycle_timers: Dictionary = {}  # tool_index -> seconds until the next cycle may start
var _tethers: Dictionary = {}  # tool_index -> Tether node while a harpoon is attached


func _ready() -> void:
	_agent_body = get_parent()
	if not _agent_body is RigidBody:
		printerr("ToolController: Parent must be RigidBody")
		return
	# The agent body resolves its ShipTemplate in initialize(), after _ready.
	call_deferred("_load_tools_if_unset")


func _load_tools_if_unset() -> void:
	if _tools.empty():
		load_tools_from_ship()


func set_tools(tools: Array) -> void:
	deactivate_all("refit")
	_tools = tools.duplicate()
	_cycle_timers.clear()


func load_tools_from_ship() -> void:
	deactivate_all("refit")
	_tools.clear()
	_cycle_timers.clear()
	var ship = _agent_body.get("ship_template")
	if not is_instance_valid(ship):
		return
	for tool_id in ship.equipped_tools:
		var tool_template = TemplateDatabase.get_template(tool_id)
		if tool_template is UtilityToolTemplate:
			_tools.append(tool_template)
		else:
			printerr("ToolController: Ship '", ship.template_id, "' fits unknown tool '", tool_id, "'")


# --- Public API ---

func get_tool_count() -> int:
	return _tools.size()


func get_tool(index: int) -> Resource:
	return _tools[index] if index >= 0 and index < _tools.size() else null


# First fitted tool that can act on `target`, or -1.
func find_tool_for(target) -> int:
	for index in range(_tools.size()):
		if can_target(_tools[index], target):
			return index
	return -1


# Laser: live ships and rocks. Harpoon: wrecks.
func can_target(tool_template, target) -> bool:
	if not (is_instance_valid(target) and target != _agent_body and target is Spatial):
		return false
	var is_ship: bool = target.has_method("apply_damage")
	match tool_template.tool_type:
		"laser":
			return (is_ship and not target.get("is_wreck")) or target.is_in_group("asteroid")
		"harpoon":
			return is_ship and bool(target.get("is_wreck"))
	return false


func is_active(index: int) -> bool:
	return _targets.has(index)


func get_target(index: int) -> Node:
	return _targets.get(index)


func get_tether(index: int) -> Node:
	return _tethers.get(index)


# 0 at the start of a cycle, 1 when the next cycle is due.
func get_cycle_progress(index: int) -> float:
	var tool_template = get_tool(index)
	if tool_template == null or not is_active(index) or tool_template.cycle_time <= 0.0:
		return 0.0
	return clamp(1.0 - _cycle_timers.get(index, 0.0) / tool_template.cycle_time, 0.0, 1.0)


func activate(index: int, target: Node) -> Dictionary:
	var tool_template = get_tool(index)
	if tool_template == null:
		return {"success": false, "reason": "no_tool"}
	if not tool_template.tool_type in ["laser", "harpoon"]:
		return {"success": false, "reason": "not_implemented"}
	if _agent_body.get("is_wreck"):
		return {"success": false, "reason": "wrecked"}
	if not can_target(tool_template, target):
		return {"success": false, "reason": "invalid_target"}
	if is_active(index):
		deactivate(index, "retarget")
	_targets[index] = target
	if not _cycle_timers.has(index):
		_cycle_timers[index] = 0.0
	emit_signal("tool_activated", index, target)
	return {"success": true}


func deactivate(index: int, reason: String = "manual") -> void:
	if not _targets.has(index):
		return
	_targets.erase(index)
	if _tethers.has(index):
		if is_instance_valid(_tethers[index]):
			_tethers[index].queue_free()
		_tethers.erase(index)
	emit_signal("tool_deactivated", index, reason)


func deactivate_all(reason: String = "manual") -> void:
	for index in _targets.keys():
		deactivate(index, reason)


# Angular velocity of `to` as seen from `from`: transversal relative speed over distance.
static func compute_angular_velocity(from_pos: Vector3, from_vel: Vector3, to_pos: Vector3, to_vel: Vector3) -> float:
	var offset: Vector3 = to_pos - from_pos
	var distance: float = offset.length()
	if distance <= 0.001:
		return 0.0
	var direction: Vector3 = offset / distance
	var relative_vel: Vector3 = to_vel - from_vel
	var transversal: Vector3 = relative_vel - direction * relative_vel.dot(direction)
	return transversal.length() / distance


# Closest distance a tether reels two bodies to.
static func get_tether_min_length(holder: Node, towed: Node) -> float:
	return (_apparent_radius(holder) + _apparent_radius(towed)) * Constants.TETHER_CLEARANCE


static func _apparent_radius(body: Node) -> float:
	return float(body.get_apparent_radius()) if body.has_method("get_apparent_radius") else 10.0


# --- Cycling ---

func _physics_process(delta: float) -> void:
	for index in _cycle_timers.keys():
		_cycle_timers[index] = max(0.0, _cycle_timers[index] - delta)
	if _targets.empty():
		return
	if _agent_body.get("is_wreck"):
		deactivate_all("wrecked")
		return
	for index in _targets.keys():
		var target = _targets[index]
		if not can_target(_tools[index], target):
			deactivate(index, "target_lost")
			continue
		match _tools[index].tool_type:
			"laser":
				_process_laser(index, target)
			"harpoon":
				_process_harpoon(index, target)


func _process_laser(index: int, target: Node) -> void:
	if _cycle_timers.get(index, 0.0) > 0.0:
		return
	var tool_template = _tools[index]
	var from_pos: Vector3 = _agent_body.global_transform.origin
	var to_pos: Vector3 = target.global_transform.origin
	var distance: float = from_pos.distance_to(to_pos)
	if distance > tool_template.get_max_range():
		return  # Stays switched on; cycles resume once back in range.
	if not _agent_body.try_spend_power(tool_template.power_per_cycle):
		deactivate(index, "no_power")
		return

	var target_velocity = target.get("linear_velocity")  # Rocks are static
	var angular: float = compute_angular_velocity(
		from_pos, _agent_body.linear_velocity, to_pos, target_velocity if target_velocity is Vector3 else Vector3.ZERO
	)
	var quality: float = tool_template.get_hit_quality(distance, angular)
	var damage: float = tool_template.damage * quality
	_cycle_timers[index] = tool_template.cycle_time
	var blocker = find_blocker(target)
	if blocker != null:
		_hit_body(blocker, from_pos, damage)
		emit_signal("tool_blocked", index, target, blocker)
		return
	_hit_body(target, from_pos, damage)
	emit_signal("tool_cycled", index, target, quality, damage)


# The first body between this ship and the target's aim point, or null for a clear line.
func find_blocker(target: Spatial):
	if not _agent_body.is_inside_tree():
		return null
	var aim: Vector3 = target.get_random_aim_point() if target.has_method("get_random_aim_point") else target.global_transform.origin
	var hit: Dictionary = _agent_body.get_world().direct_space_state.intersect_ray(
		_agent_body.global_transform.origin, aim, [_agent_body]
	)
	if hit.empty() or hit.collider == target:
		return null
	return hit.collider


# Marks, damages (if it can be damaged) and flashes whatever the shot lands on.
func _hit_body(body: Spatial, from_pos: Vector3, damage: float) -> void:
	if damage > 0.0:
		var hit_point: Vector3 = body.register_hit(from_pos, damage) if body.has_method("register_hit") else _find_hit_point(body)
		_spawn_hit_effect(body, hit_point, damage)
	if body.has_method("apply_damage"):
		body.apply_damage(damage, _agent_body)


func _process_harpoon(index: int, target: Node) -> void:
	var tool_template = _tools[index]
	if not _tethers.has(index):
		_launch_harpoon(index, target, tool_template)
		return
	var tether = _tethers[index]
	if not tether.is_reeled_in() or _cycle_timers.get(index, 0.0) > 0.0:
		return
	_cycle_timers[index] = tool_template.strip_interval
	if _agent_body.get_free_cargo() <= 0:
		return  # Hold full: keep towing.
	var taken: Dictionary = target.take_salvage(1)
	for commodity_id in taken:
		_agent_body.add_cargo(commodity_id, taken[commodity_id])
	if not taken.empty():
		emit_signal("salvage_stripped", index, taken)
	if target.get_salvage_units() <= 0:
		deactivate(index, "stripped")


func _launch_harpoon(index: int, target: Node, tool_template) -> void:
	if _cycle_timers.get(index, 0.0) > 0.0:
		return
	var distance: float = _agent_body.global_transform.origin.distance_to(target.global_transform.origin)
	if distance > tool_template.get_max_range():
		return  # Stays armed; launches once in reach.
	if not _agent_body.try_spend_power(tool_template.power_per_cycle):
		deactivate(index, "no_power")
		return
	var tether = Tether.new()
	tether.setup(_agent_body, target, distance, get_tether_min_length(_agent_body, target), tool_template.reel_speed)
	add_child(tether)
	_tethers[index] = tether
	_cycle_timers[index] = tool_template.strip_interval
	emit_signal("tool_cycled", index, target, 1.0, 0.0)


# Lasers are invisible in vacuum: only the hit shows, as a flash and vaporized hull material.
func _spawn_hit_effect(target: Spatial, hit_point: Vector3, damage: float) -> void:
	if LaserHitEffect.intensity_for_damage(damage) <= 0.0 or not target.is_inside_tree():
		return
	var effect = LaserHitScene.instance()
	effect.damage = damage
	effect.outward = (_agent_body.global_transform.origin - hit_point).normalized()
	target.add_child(effect)
	effect.global_transform = Transform(Basis(), hit_point)  # Unscaled even on scaled bodies (asteroids)


# Fallback hit point for targets without hull marking: the side of their bounds facing this ship.
func _find_hit_point(target: Spatial) -> Vector3:
	if target.has_method("get_hull_point_facing"):
		return target.get_hull_point_facing(_agent_body.global_transform.origin)
	return target.global_transform.origin
