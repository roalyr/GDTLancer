# Tether: a harpoon cable between the ship that fired it (holder) and a towed body.
# Behaves as a rope: no force while slack, a spring-damper pull when stretched, equal and opposite
# on both bodies, so towed mass shows up in handling. It reels in until the bodies are
# min_length apart. Child of the holder's ToolController.

extends Node

const PERIOD = 2.0  # Seconds; stiffness of the cable for the pair's combined mass.
const DAMPING_RATIO = 0.9
const CABLE_COLOR = Color(0.55, 0.55, 0.6)

var holder: RigidBody = null
var towed: RigidBody = null
var length: float = 0.0
var min_length: float = 0.0
var reel_speed: float = 0.0

var _cable: ImmediateGeometry = null


func setup(p_holder: RigidBody, p_towed: RigidBody, p_length: float, p_min_length: float, p_reel_speed: float) -> void:
	holder = p_holder
	towed = p_towed
	min_length = p_min_length
	length = max(p_length, p_min_length)
	reel_speed = p_reel_speed


func _ready() -> void:
	_cable = ImmediateGeometry.new()
	_cable.set_as_toplevel(true)
	var material = SpatialMaterial.new()
	material.flags_unshaded = true
	material.albedo_color = CABLE_COLOR
	_cable.material_override = material
	add_child(_cable)


func is_valid() -> bool:
	return is_instance_valid(holder) and is_instance_valid(towed) and towed.is_inside_tree()


func is_reeled_in() -> bool:
	return length <= min_length + 0.01 and get_distance() <= min_length * 1.25


func get_distance() -> float:
	return holder.global_transform.origin.distance_to(towed.global_transform.origin) if is_valid() else 0.0


func get_tension(stretch: float, closing_speed: float) -> float:
	var reduced_mass: float = holder.mass * towed.mass / max(holder.mass + towed.mass, 0.001)
	var omega: float = TAU / PERIOD
	return max(0.0, reduced_mass * omega * omega * stretch + 2.0 * reduced_mass * omega * DAMPING_RATIO * closing_speed)


func _physics_process(delta: float) -> void:
	if not is_valid():
		return
	length = max(min_length, length - reel_speed * delta)
	var offset: Vector3 = towed.global_transform.origin - holder.global_transform.origin
	var distance: float = offset.length()
	if distance <= length or distance < 0.001:
		return  # Slack
	var direction: Vector3 = offset / distance
	var separating_speed: float = (towed.linear_velocity - holder.linear_velocity).dot(direction)
	var tension: float = get_tension(distance - length, separating_speed)
	_apply_force(holder, direction * tension)
	_apply_force(towed, -direction * tension)


func _apply_force(body: RigidBody, force: Vector3) -> void:
	var movement = body.get("movement_system")
	if is_instance_valid(movement) and movement.has_method("add_external_force"):
		movement.add_external_force(force)


func _process(_delta: float) -> void:
	if not is_valid() or not is_instance_valid(_cable):
		return
	_cable.clear()
	_cable.begin(Mesh.PRIMITIVE_LINES)
	_cable.add_vertex(_anchor_point(holder, towed))
	_cable.add_vertex(_anchor_point(towed, holder))
	_cable.end()


# Where the cable meets a body's hull, on the side facing the other body.
func _anchor_point(body: Spatial, other: Spatial) -> Vector3:
	if body.has_method("get_hull_point_facing"):
		return body.get_hull_point_facing(other.global_transform.origin)
	return body.global_transform.origin
