# Tether: a harpoon cable between the ship that fired it (holder) and a towed body.
# Behaves as a rope: no force while slack, a spring-damper pull when stretched, equal and opposite
# on both bodies, so towed mass shows up in handling. It reels in until the bodies are
# min_length apart; when they drift closer, the winch takes up the slack at
# Constants.TETHER_SLACK_TAKEUP_SPEED, so a loose cable shows for a moment. Stretched past
# Constants.TETHER_SNAP_STRETCH, the cable snaps. Child of the holder's ToolController.
# Looks: a TetherRope drawn as a camera-facing ribbon, brighter and thinner under strain.

extends Node

const CableMaterial = preload("res://assets/art/effects/tether_cable_material.tres")
const TetherRope = preload("res://src/core/agents/components/tether_rope.gd")

var holder: RigidBody = null
var towed: RigidBody = null
var length: float = 0.0
var min_length: float = 0.0
var reel_speed: float = 0.0
var snapped: bool = false
var strain: float = 0.0  # 0 slack .. 1 strained (Constants.TETHER_STRAIN_FULL_STRETCH)

var _cable: ImmediateGeometry = null
var _rope = TetherRope.new()
var _age := 0.0


func setup(p_holder: RigidBody, p_towed: RigidBody, p_length: float, p_min_length: float, p_reel_speed: float) -> void:
	holder = p_holder
	towed = p_towed
	min_length = p_min_length
	length = max(p_length, p_min_length)
	reel_speed = p_reel_speed


func _ready() -> void:
	_cable = ImmediateGeometry.new()
	_cable.set_as_toplevel(true)
	_cable.material_override = CableMaterial
	add_child(_cable)


func is_valid() -> bool:
	return not snapped and is_instance_valid(holder) and is_instance_valid(towed) and towed.is_inside_tree()


func is_reeled_in() -> bool:
	return length <= min_length + 0.01 and get_distance() <= min_length * 1.25


func get_distance() -> float:
	return holder.global_transform.origin.distance_to(towed.global_transform.origin) if is_valid() else 0.0


func get_tension(stretch: float, closing_speed: float) -> float:
	var reduced_mass: float = holder.mass * towed.mass / max(holder.mass + towed.mass, 0.001)
	var omega: float = TAU / Constants.TETHER_PERIOD
	return max(0.0, reduced_mass * omega * omega * stretch + 2.0 * reduced_mass * omega * Constants.TETHER_DAMPING_RATIO * closing_speed)


func _physics_process(delta: float) -> void:
	if not is_valid():
		return
	var offset: Vector3 = towed.global_transform.origin - holder.global_transform.origin
	var distance: float = offset.length()
	length = get_next_length(length, distance, delta)
	strain = clamp((distance - length) / Constants.TETHER_STRAIN_FULL_STRETCH, 0.0, 1.0)
	_step_rope(delta)
	if distance <= length or distance < 0.001:
		return  # Slack
	if distance - length > Constants.TETHER_SNAP_STRETCH:
		snapped = true
		if is_instance_valid(_cable):
			_cable.clear()
		return
	var direction: Vector3 = offset / distance
	var separating_speed: float = (towed.linear_velocity - holder.linear_velocity).dot(direction)
	var tension: float = get_tension(distance - length, separating_speed)
	_apply_force(holder, direction * tension)
	_apply_force(towed, -direction * tension)


# Reels in at reel_speed; slack (the bodies closer than the cable is long) is taken up at
# TETHER_SLACK_TAKEUP_SPEED on top, never past the actual distance.
func get_next_length(current: float, distance: float, delta: float) -> float:
	var next: float = current - reel_speed * delta
	if distance < next:
		next = max(distance, next - Constants.TETHER_SLACK_TAKEUP_SPEED * delta)
	return max(min_length, next)


func get_rope_points() -> Array:
	return _rope.points


func _step_rope(delta: float) -> void:
	var from: Vector3 = _anchor_point(holder, towed)
	var to: Vector3 = _anchor_point(towed, holder)
	var obstacles: Array = []
	for body in [holder, towed]:
		if body.has_method("get_hull_core_box"):
			obstacles.append([body.global_transform, body.get_hull_core_box()])
	var frame_velocity: Vector3 = (holder.linear_velocity + towed.linear_velocity) * 0.5
	# `length` runs centre to centre; the visible cable only from hull to hull.
	var inside_hulls: float = max(0.0, get_distance() - from.distance_to(to))
	_rope.step(from, to, max(0.0, length - inside_hulls), frame_velocity, delta, obstacles)


func _apply_force(body: RigidBody, force: Vector3) -> void:
	var movement = body.get("movement_system")
	if is_instance_valid(movement) and movement.has_method("add_external_force"):
		movement.add_external_force(force)


# Draws the rope as a ribbon facing the camera. Strain goes to the shader in the vertex colour;
# a strained cable also thins and shivers.
func _process(delta: float) -> void:
	_age += delta
	if not is_valid() or not is_instance_valid(_cable):
		return
	_cable.clear()
	var points: Array = _rope.points
	var camera = get_viewport().get_camera() if is_inside_tree() else null
	if points.size() < 2 or camera == null:
		return
	var eye: Vector3 = camera.global_transform.origin
	var half_width: float = Constants.TETHER_CABLE_WIDTH * 0.5 * (1.0 - Constants.TETHER_STRAIN_THINNING * strain)
	var shiver: float = Constants.TETHER_SHIVER_AMPLITUDE * strain * strain
	var last: int = points.size() - 1
	var color := Color(strain, 0.0, 0.0, 1.0)
	_cable.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(points.size()):
		var tangent: Vector3 = points[min(i + 1, last)] - points[max(i - 1, 0)]
		var side: Vector3 = tangent.cross(eye - points[i])
		side = side.normalized() if side.length_squared() > 0.0000001 else Vector3.UP
		var point: Vector3 = points[i]
		if i > 0 and i < last:
			point += side * shiver * sin(_age * Constants.TETHER_SHIVER_FREQUENCY + i * 1.7) * sin(PI * i / last)
		_cable.set_color(color)
		_cable.add_vertex(point - side * half_width)
		_cable.set_color(color)
		_cable.add_vertex(point + side * half_width)
	_cable.end()


# Where the cable meets a body's hull, on the side facing the other body.
func _anchor_point(body: Spatial, other: Spatial) -> Vector3:
	if body.has_method("get_hull_point_facing"):
		return body.get_hull_point_facing(other.global_transform.origin)
	return body.global_transform.origin
