# TetherRope: the cable's shape, for looks only (the pull between the ships is Tether's spring).
# A chain of points with fixed spacing (verlet): the ends are pinned to the anchors on the two
# hulls, and the points in between keep their own motion. A taut cable pulls straight; a slack
# one drifts and bunches up as the ships close in. No gravity, so it never hangs. Motion is
# damped relative to the ships' average velocity, so the cable travels along with them.
# Points are pushed out of the hull boxes (Agent.get_hull_core_box) so slack cable does not cut
# through the ships. The far end can be let go (the hook came free): it then flies on its own
# and is pulled in as the rest length shrinks.

extends Reference

var points: Array = []  # Vector3, world space; first and last sit on the anchors
var _previous: Array = []


# Points for a cable of `rope_length`: one per TETHER_ROPE_SEGMENT_LENGTH, within the limits.
static func point_count_for(rope_length: float) -> int:
	var count: int = int(ceil(rope_length / Constants.TETHER_ROPE_SEGMENT_LENGTH)) + 1
	return int(clamp(count, Constants.TETHER_ROPE_MIN_POINTS, Constants.TETHER_ROPE_POINTS))


func reset(from: Vector3, to: Vector3) -> void:
	var count: int = point_count_for(from.distance_to(to))
	points.clear()
	for i in range(count):
		points.append(from.linear_interpolate(to, float(i) / float(count - 1)))
	_previous = points.duplicate()


# Advances the rope one physics step. `frame_velocity` is the ships' average velocity;
# `obstacles` holds [Transform, AABB] pairs: boxes in their bodies' space.
# With `to_pinned` false the far end is free and `to` is ignored.
func step(from: Vector3, to: Vector3, rest_length: float, frame_velocity: Vector3, delta: float, obstacles: Array = [], to_pinned: bool = true) -> void:
	if points.size() < 2:
		reset(from, to)
	var wanted: int = point_count_for(rest_length)
	if abs(wanted - points.size()) >= 2:  # A step of slack so it does not flip at a boundary
		resample(wanted)
	var last: int = points.size() - 1
	var free_end: int = last if to_pinned else last + 1
	var frame_step: Vector3 = frame_velocity * delta
	var slack: float = clamp(1.0 - from.distance_to(to) / max(rest_length, 0.001), 0.0, 1.0) if to_pinned else 0.0
	var nudge: float = Constants.TETHER_ROPE_BUCKLE_NUDGE * slack
	for i in range(1, free_end):
		var moved: Vector3 = points[i] - _previous[i]
		_previous[i] = points[i]
		points[i] += frame_step + (moved - frame_step) * Constants.TETHER_ROPE_DAMPING
		if nudge > 0.0:
			# A perfectly straight cable pushed end-on stays straight; real ones buckle.
			points[i] += Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)) * nudge
	_previous[0] = points[0]
	points[0] = from
	if to_pinned:
		_previous[last] = points[last]
		points[last] = to
	var spacing: float = rest_length / float(last)
	var iterations: int = Constants.TETHER_ROPE_ITERATIONS
	for iteration in range(iterations):
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
			elif i + 1 == last and to_pinned:
				points[i] = a + correction
			else:
				points[i] = a + correction * 0.5
				points[i + 1] = b - correction * 0.5
		# Hulls only on the last passes: the spacing has mostly settled by then, and it is the
		# costlier part (a transform per point and hull).
		if iteration >= iterations - Constants.TETHER_ROPE_HULL_PASSES:
			for i in range(1, free_end):
				points[i] = _push_out(points[i], obstacles)


# Re-spreads the rope over `count` points along its current shape, keeping each point's motion
# (positions and previous positions are sampled alike), so the cable does not jump.
func resample(count: int) -> void:
	if points.size() < 2 or count < 2 or count == points.size():
		return
	points = _resampled(points, count)
	_previous = _resampled(_previous, count)


static func _resampled(source: Array, count: int) -> Array:
	var out: Array = []
	var span: float = float(source.size() - 1)
	for j in range(count):
		var f: float = float(j) * span / float(count - 1)
		var i: int = int(min(floor(f), span - 1.0))
		out.append(source[i].linear_interpolate(source[i + 1], f - i))
	return out


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


# A smooth curve through `source` (Catmull-Rom), `subdivisions` drawn segments per rope segment.
# Lets the rope simulate few points and still draw without kinks.
static func smooth_points(source: Array, subdivisions: int) -> Array:
	if source.size() < 3 or subdivisions <= 1:
		return source
	var out: Array = []
	var last: int = source.size() - 1
	for i in range(last):
		var p0: Vector3 = source[max(i - 1, 0)]
		var p1: Vector3 = source[i]
		var p2: Vector3 = source[i + 1]
		var p3: Vector3 = source[min(i + 2, last)]
		for s in range(subdivisions):
			var t: float = float(s) / float(subdivisions)
			var t2: float = t * t
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t2 * t))
	out.append(source[last])
	return out
