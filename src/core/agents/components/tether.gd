# Tether: a harpoon cable between the ship that fired it (holder) and a towed body.
# Launch: the hook flies from the holder at launch_speed, homing on the target's hull and paying
# out cable behind it; it hooks on when it gets there (signal hooked), or, past max_reach, has
# missed and is winched back.
# Behaves as a rope: no force while slack, a spring-damper pull when stretched, equal and opposite
# on both bodies, so towed mass shows up in handling. It reels in until the bodies are
# min_length apart; when they drift closer, the winch takes up the slack at
# Constants.TETHER_SLACK_TAKEUP_SPEED, so a loose cable shows for a moment. Stretched past
# Constants.TETHER_SNAP_STRETCH, the hook tears free.
# Letting go (released, torn free, the target gone): the hook comes off and the winch pulls the
# cable in at Constants.TETHER_RETRACT_SPEED; the node frees itself once it is all in, and the
# harpoon cannot fire again until then (ToolController.is_retracting).
# Looks: a TetherRope drawn as a smooth camera-facing ribbon, brighter and thinner under strain,
# with the hook (scenes/prefabs/effects/harpoon_hook.tscn) at its end. Far from the camera the
# rope is not simulated and is drawn straight. Child of the holder's ToolController.

extends Node

signal hooked
signal retracted

const CableMaterial = preload("res://assets/art/effects/tether_cable_material.tres")
const HookScene = preload("res://scenes/prefabs/effects/harpoon_hook.tscn")
const TetherRope = preload("res://src/core/agents/components/tether_rope.gd")

var holder: RigidBody = null
var towed: RigidBody = null
var length: float = 0.0  # Centre to centre
var min_length: float = 0.0
var reel_speed: float = 0.0
var launch_speed: float = 0.0  # m/s; 0 = hooked at once
var max_reach: float = INF  # m from the holder at which a flying hook has missed
var launching: bool = false  # Hook in flight
var snapped: bool = false  # The hook tore free
var retracting: bool = false  # Hook off, cable winching in
var strain: float = 0.0  # 0 slack .. 1 strained (Constants.TETHER_STRAIN_FULL_STRETCH)

var _cable: ImmediateGeometry = null
var _hook: Spatial = null
var _rope = TetherRope.new()
var _rope_length := 0.0  # Hull to hull: the cable actually paid out
var _paid_out := -1.0  # Centre to centre, as the winch has it: like `length`, but it also takes in
	# slack below min_length when the bodies drift closer still, and pays it back out up to `length`
var _age := 0.0
var _hook_pos := Vector3.ZERO  # Where the flying hook is


func setup(p_holder: RigidBody, p_towed: RigidBody, p_length: float, p_min_length: float, p_reel_speed: float, p_launch_speed: float = 0.0, p_max_reach: float = INF) -> void:
	holder = p_holder
	towed = p_towed
	min_length = p_min_length
	length = max(p_length, p_min_length)
	reel_speed = p_reel_speed
	launch_speed = p_launch_speed
	max_reach = p_max_reach
	launching = launch_speed > 0.0
	if launching:
		_hook_pos = _anchor_point(holder, towed.global_transform.origin)


func _ready() -> void:
	_cable = ImmediateGeometry.new()
	_cable.set_as_toplevel(true)
	_cable.material_override = CableMaterial
	add_child(_cable)
	_hook = HookScene.instance()
	_hook.set_as_toplevel(true)
	_hook.visible = false
	add_child(_hook)


# Hooked on and holding.
func is_valid() -> bool:
	return not launching and not retracting and not snapped and is_instance_valid(holder) and is_instance_valid(towed) and towed.is_inside_tree()


func is_reeled_in() -> bool:
	return is_valid() and length <= min_length + 0.01 and get_distance() <= min_length * 1.25


# How far the flying hook is from the ship, m.
func get_hook_distance() -> float:
	return holder.global_transform.origin.distance_to(_hook_pos) if launching and is_instance_valid(holder) else 0.0


func get_distance() -> float:
	return holder.global_transform.origin.distance_to(towed.global_transform.origin) if is_valid() else 0.0


# Cable still out while winching in, m.
func get_paid_out_length() -> float:
	return _rope_length


func get_tension(stretch: float, closing_speed: float) -> float:
	var reduced_mass: float = holder.mass * towed.mass / max(holder.mass + towed.mass, 0.001)
	var omega: float = TAU / Constants.TETHER_PERIOD
	return max(0.0, reduced_mass * omega * omega * stretch + 2.0 * reduced_mass * omega * Constants.TETHER_DAMPING_RATIO * closing_speed)


# Lets go of the target: the hook comes free and the winch starts pulling the cable in.
func start_retract() -> void:
	if retracting:
		return
	retracting = true
	launching = false
	strain = 0.0
	if _rope.points.size() >= 2:
		_rope_length = max(_rope_length, _rope.get_length())


func _physics_process(delta: float) -> void:
	if retracting:
		_step_retract(delta)
		return
	if launching:
		_step_launch(delta)
		return
	if not is_valid():
		if is_instance_valid(holder):
			start_retract()  # The target is gone: nothing to hold on to
		return
	var offset: Vector3 = towed.global_transform.origin - holder.global_transform.origin
	var distance: float = offset.length()
	length = get_next_length(length, distance, delta)
	strain = clamp((distance - length) / Constants.TETHER_STRAIN_FULL_STRETCH, 0.0, 1.0)
	_step_rope(delta)
	if distance <= length or distance < 0.001:
		return  # Slack
	if distance - length > Constants.TETHER_SNAP_STRETCH:
		snapped = true  # Tears free
		start_retract()
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


# The cable the winch has out: never more than `length`; slack is taken in at
# TETHER_SLACK_TAKEUP_SPEED down to the actual distance, and paid back out freely.
static func get_next_paid_out(current: float, cable_length: float, distance: float, delta: float) -> float:
	var next: float = current
	if distance < next:
		next = max(distance, next - Constants.TETHER_SLACK_TAKEUP_SPEED * delta)
	else:
		next = distance
	return min(next, cable_length)


func get_rope_points() -> Array:
	return _rope.points


func _step_rope(delta: float) -> void:
	var from: Vector3 = _anchor_point(holder, towed.global_transform.origin)
	var to: Vector3 = _anchor_point(towed, holder.global_transform.origin)
	# Centre to centre; the visible cable runs only from hull to hull.
	var distance: float = holder.global_transform.origin.distance_to(towed.global_transform.origin)
	_paid_out = get_next_paid_out(_paid_out if _paid_out >= 0.0 else length, length, distance, delta)
	_rope_length = max(0.0, _paid_out - max(0.0, distance - from.distance_to(to)))
	if not _is_near_camera():
		_rope.reset(from, to)
		return
	var obstacles: Array = []
	for body in [holder, towed]:
		if body.has_method("get_hull_core_box"):
			obstacles.append([body.global_transform, body.get_hull_core_box()])
	var frame_velocity: Vector3 = (holder.linear_velocity + towed.linear_velocity) * 0.5
	_rope.step(from, to, _rope_length, frame_velocity, delta, obstacles)


# The hook flies at launch_speed toward the point on the target's hull facing the ship, the cable
# paying out behind it with a little give.
func _step_launch(delta: float) -> void:
	if not (is_instance_valid(holder) and is_instance_valid(towed) and towed.is_inside_tree()):
		start_retract()
		return
	var target_point: Vector3 = _anchor_point(towed, holder.global_transform.origin)
	var to_target: Vector3 = target_point - _hook_pos
	var travel: float = launch_speed * delta
	if to_target.length() <= travel:
		_hook_pos = target_point
		launching = false  # Hooked on
		length = max(min_length, holder.global_transform.origin.distance_to(towed.global_transform.origin))
		_paid_out = length
		_step_rope(delta)
		emit_signal("hooked")
		return
	_hook_pos += to_target.normalized() * travel
	if holder.global_transform.origin.distance_to(_hook_pos) > max_reach:
		start_retract()  # Missed: it outran its cable
		return
	var from: Vector3 = _anchor_point(holder, _hook_pos)
	_rope_length = from.distance_to(_hook_pos) * 1.03
	if not _is_near_camera():
		_rope.reset(from, _hook_pos)
		return
	var obstacles: Array = []
	if holder.has_method("get_hull_core_box"):
		obstacles.append([holder.global_transform, holder.get_hull_core_box()])
	_rope.step(from, _hook_pos, _rope_length, holder.linear_velocity, delta, obstacles)


# The free end flies on; the shrinking cable pulls it home.
func _step_retract(delta: float) -> void:
	if not is_instance_valid(holder):
		queue_free()
		return
	_rope_length -= Constants.TETHER_RETRACT_SPEED * delta
	if _rope_length <= 0.0 or _rope.points.size() < 2:
		emit_signal("retracted")
		queue_free()
		return
	var tip: Vector3 = _rope.points[_rope.points.size() - 1]
	var from: Vector3 = _anchor_point(holder, tip)
	if not _is_near_camera():
		_rope.reset(from, from + (tip - from).normalized() * min(from.distance_to(tip), _rope_length))
		return
	var obstacles: Array = []
	if holder.has_method("get_hull_core_box"):
		obstacles.append([holder.global_transform, holder.get_hull_core_box()])
	_rope.step(from, tip, _rope_length, holder.linear_velocity, delta, obstacles, false)


func _is_near_camera() -> bool:
	var camera = get_viewport().get_camera() if is_inside_tree() else null
	if camera == null or not is_instance_valid(holder):
		return true  # Nothing to judge by (tests): simulate
	return camera.global_transform.origin.distance_to(holder.global_transform.origin) <= Constants.TETHER_ROPE_SIM_DISTANCE


func _apply_force(body: RigidBody, force: Vector3) -> void:
	var movement = body.get("movement_system")
	if is_instance_valid(movement) and movement.has_method("add_external_force"):
		movement.add_external_force(force)


# Draws the rope as a smooth ribbon facing the camera, and places the hook at its end. Strain
# goes to the shader in the vertex colour; a strained cable also thins and shivers.
func _process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(_cable):
		return
	_cable.clear()
	_hook.visible = false
	var camera = get_viewport().get_camera() if is_inside_tree() else null
	if _rope.points.size() < 2 or camera == null or not is_instance_valid(holder) or not (retracting or launching or is_valid()):
		return
	var near: bool = _is_near_camera()
	var points: Array = TetherRope.smooth_points(_rope.points, Constants.TETHER_RENDER_SUBDIVISIONS) if near else _rope.points
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
			point += side * shiver * sin(_age * Constants.TETHER_SHIVER_FREQUENCY + i * 0.4) * sin(PI * i / last)
		_cable.set_color(color)
		_cable.add_vertex(point - side * half_width)
		_cable.set_color(color)
		_cable.add_vertex(point + side * half_width)
	_cable.end()
	_place_hook(points[last], points[last] - points[max(last - 1, 0)])


# The hook sits at the cable's end, pointing along it: into the target while attached, outward
# while it is winched home.
func _place_hook(tip: Vector3, direction: Vector3) -> void:
	if direction.length_squared() < 0.000001:
		return
	direction = direction.normalized()
	var up: Vector3 = Vector3.UP if abs(direction.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	_hook.global_transform = Transform(Basis(), tip).looking_at(tip + direction, up)
	_hook.visible = true


# Where the cable meets a body's hull, on the side facing `toward`.
func _anchor_point(body: Spatial, toward: Vector3) -> Vector3:
	if body.has_method("get_hull_point_facing"):
		return body.get_hull_point_facing(toward)
	return body.global_transform.origin
