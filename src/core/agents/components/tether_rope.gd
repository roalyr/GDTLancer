# TetherRope: the cable's shape, for looks only (the pull between the ships is Tether's spring).
# A chain of points with fixed spacing (verlet): the ends are pinned to the anchors on the two
# hulls, and the points in between keep their own motion. A taut cable pulls straight; a slack
# one drifts and bunches up as the ships close in. No gravity, so it never hangs. Motion is
# damped relative to the ships' average velocity, so the cable travels along with them.
# Points are pushed out of the hull boxes (Agent.get_hull_core_box) so slack cable does not cut
# through the ships.

extends Reference

var points: Array = []  # Vector3, world space; first and last sit on the anchors
var _previous: Array = []


func reset(from: Vector3, to: Vector3) -> void:
	var count: int = int(max(Constants.TETHER_ROPE_POINTS, 2))
	points.clear()
	for i in range(count):
		points.append(from.linear_interpolate(to, float(i) / float(count - 1)))
	_previous = points.duplicate()


# Advances the rope one physics step. `frame_velocity` is the ships' average velocity;
# `obstacles` holds [Transform, AABB] pairs: boxes in their bodies' space.
func step(from: Vector3, to: Vector3, rest_length: float, frame_velocity: Vector3, delta: float, obstacles: Array = []) -> void:
	if points.size() < 2:
		reset(from, to)
	var last: int = points.size() - 1
	var frame_step: Vector3 = frame_velocity * delta
	var slack: float = clamp(1.0 - from.distance_to(to) / max(rest_length, 0.001), 0.0, 1.0)
	var nudge: float = Constants.TETHER_ROPE_BUCKLE_NUDGE * slack
	for i in range(1, last):
		var moved: Vector3 = points[i] - _previous[i]
		_previous[i] = points[i]
		points[i] += frame_step + (moved - frame_step) * Constants.TETHER_ROPE_DAMPING
		if nudge > 0.0:
			# A perfectly straight cable pushed end-on stays straight; real ones buckle.
			points[i] += Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)) * nudge
	_previous[0] = points[0]
	_previous[last] = points[last]
	points[0] = from
	points[last] = to
	var spacing: float = rest_length / float(last)
	for _iteration in range(Constants.TETHER_ROPE_ITERATIONS):
		for i in range(last):
			var a: Vector3 = points[i]
			var b: Vector3 = points[i + 1]
			var offset: Vector3 = b - a
			var distance: float = offset.length()
			if distance < 0.000001:
				continue
			var correction: Vector3 = offset * ((distance - spacing) / distance)
			if i == 0:
				points[i + 1] = b - correction
			elif i + 1 == last:
				points[i] = a + correction
			else:
				points[i] = a + correction * 0.5
				points[i + 1] = b - correction * 0.5
		for i in range(1, last):
			points[i] = _push_out(points[i], obstacles)


func get_length() -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total


static func _push_out(point: Vector3, obstacles: Array) -> Vector3:
	for obstacle in obstacles:
		var xform: Transform = obstacle[0]
		var box: AABB = obstacle[1]
		var local: Vector3 = xform.xform_inv(point)
		if not box.has_point(local):
			continue
		# Out through the nearest face.
		var best_axis := 0
		var best_target := 0.0
		var best_depth := INF
		for axis in range(3):
			var to_low: float = local[axis] - box.position[axis]
			var to_high: float = box.end[axis] - local[axis]
			if to_low < best_depth:
				best_depth = to_low
				best_axis = axis
				best_target = box.position[axis]
			if to_high < best_depth:
				best_depth = to_high
				best_axis = axis
				best_target = box.end[axis]
		local[best_axis] = best_target
		point = xform.xform(local)
	return point
