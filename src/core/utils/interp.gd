# Interp: physics interpolation (project setting physics/common/physics_interpolation) and the
# drawn place of things. With it on, the physics runs at its own rate (physics_fps) and every node
# moved in physics steps is drawn between its last two steps, so motion stays smooth at any frame
# rate. Whatever is drawn per frame must go by those drawn places:
# - The camera follows every frame (OrbitCamera._process), from its target's drawn transform, and
#   is itself left out of interpolation; HUD marks project drawn places (origin()).
# - A node moved per frame in _process (a cable's hook, a marker's ring, a light) is left out of
#   interpolation (keep_out()), or it would trail a frame behind.
# - A node put somewhere new (spawned, docked, an effect placed at a hit) is reset there (placed()),
#   or it would be drawn sliding in from where it was for a step.
# With interpolation off, all of these are the plain transforms and do nothing.

extends Reference


const _STATE := {}  # The project settings, read once (they hold for the run; brackets ask every frame)


static func enabled() -> bool:
	if not _STATE.has("on"):
		_STATE["on"] = bool(ProjectSettings.get_setting("physics/common/physics_interpolation"))
	return _STATE.on


# Physics steps per second of game time (project setting physics/common/physics_fps).
static func physics_rate() -> int:
	return int(ProjectSettings.get_setting("physics/common/physics_fps"))


static func transform(node: Spatial) -> Transform:
	if enabled() and node.is_inside_tree():
		return node.get_global_transform_interpolated()
	return node.global_transform


static func origin(node: Spatial) -> Vector3:
	return transform(node).origin


static func placed(node: Node) -> void:
	if enabled() and is_instance_valid(node) and node.is_inside_tree():
		node.reset_physics_interpolation()


static func keep_out(node: Node) -> void:
	if is_instance_valid(node):
		node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
