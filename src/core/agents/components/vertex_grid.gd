# VertexGrid: a coarse spatial index of a mesh's vertex positions (all its paintable surfaces),
# for finding the vertices near a point or along a line without scanning them all. Built once per
# source mesh (in mesh space) and shared by every object drawing that mesh; the cache holds the
# source Mesh, so a grid lives as long as its mesh. Entries pack surface and vertex index:
# surface * STRIDE + i.
#
# Building takes tens of milliseconds on a dense mesh, so grids are requested when an object is
# set up (sector load, ship spawn) and built on one worker thread; a grid needed before it is
# ready is built on the spot. The worker only reads vertex positions (pool arrays, copied on
# write) and its results are handed over under a mutex.

extends Reference

const CELLS_ACROSS = 24.0  # Cells along the longest side of the mesh's bounds
const STRIDE = 1000000  # Vertex indices per surface in a packed entry
const _CACHE := {}  # Source mesh -> grid; a const dictionary stays mutable
const _WORK := {"queue": [], "results": {}, "thread": null, "worker": null, "mutex": null}  # Background builds


# Queues a background build of the grid for `source` (positions read from its `arrays`).
static func request(source: Mesh, arrays: Array, surfaces: Array) -> void:
	_reap()
	if _CACHE.has(source):
		return
	if _WORK.mutex == null:
		_WORK.mutex = Mutex.new()
	var positions := {}
	for surface in surfaces:
		positions[surface] = arrays[surface][Mesh.ARRAY_VERTEX]
	_WORK.mutex.lock()
	var queued: bool = _WORK.results.has(source)
	for job in _WORK.queue:
		queued = queued or job[0] == source
	if not queued:
		_WORK.queue.append([source, positions])
	_WORK.mutex.unlock()
	if not queued and _WORK.thread == null:
		_WORK.thread = Thread.new()
		_WORK.worker = load("res://src/core/agents/components/vertex_grid.gd").new()  # Kept alive while it runs
		_WORK.thread.start(_WORK.worker, "_work")


# The grid for `source`: built in the background if it is ready, otherwise built now.
static func for_mesh(source: Mesh, arrays: Array, surfaces: Array) -> Dictionary:
	if _CACHE.has(source):
		return _CACHE[source]
	if _WORK.mutex != null:
		_WORK.mutex.lock()
		if _WORK.results.has(source):
			_CACHE[source] = _WORK.results[source]
			_WORK.results.erase(source)
		else:
			for job in _WORK.queue.duplicate():
				if job[0] == source:
					_WORK.queue.erase(job)  # Needed now: build it here instead
		_WORK.mutex.unlock()
	if not _CACHE.has(source):
		var positions := {}
		for surface in surfaces:
			positions[surface] = arrays[surface][Mesh.ARRAY_VERTEX]
		_CACHE[source] = build(positions)
	return _CACHE[source]


static func is_ready(source: Mesh) -> bool:
	if _CACHE.has(source):
		return true
	if _WORK.mutex == null:
		return false
	_WORK.mutex.lock()
	var done: bool = _WORK.results.has(source)
	_WORK.mutex.unlock()
	return done


# On exit: drops queued builds, joins the worker (a running thread must not be left behind) and
# empties the caches (they hold meshes).
static func shutdown() -> void:
	if _WORK.mutex == null:
		_CACHE.clear()
		return
	_WORK.mutex.lock()
	_WORK.queue.clear()
	_WORK.mutex.unlock()
	if _WORK.thread != null:
		_WORK.thread.wait_to_finish()
		_WORK.thread = null
	_WORK.worker = null
	_WORK.results.clear()
	_CACHE.clear()  # The cache holds meshes: let them go at exit


# Joins the worker once it has finished its queue (call from the main thread).
static func _reap() -> void:
	if _WORK.thread != null and not _WORK.thread.is_alive():
		_WORK.thread.wait_to_finish()
		_WORK.thread = null
		_WORK.mutex.lock()
		var more: bool = not _WORK.queue.empty()
		_WORK.mutex.unlock()
		if more:
			_WORK.thread = Thread.new()
			_WORK.worker = load("res://src/core/agents/components/vertex_grid.gd").new()  # Kept alive while it runs
			_WORK.thread.start(_WORK.worker, "_work")


# Worker thread: builds queued grids until the queue is empty.
func _work(_userdata = null) -> void:
	while true:
		_WORK.mutex.lock()
		if _WORK.queue.empty():
			_WORK.mutex.unlock()
			return
		var job: Array = _WORK.queue.pop_front()
		_WORK.mutex.unlock()
		var grid: Dictionary = build(job[1])
		_WORK.mutex.lock()
		_WORK.results[job[0]] = grid
		_WORK.mutex.unlock()


# `positions`: {surface: PoolVector3Array}.
static func build(positions: Dictionary) -> Dictionary:
	var bounds := AABB()
	var first := true
	for surface in positions:
		for position in positions[surface]:
			bounds = AABB(position, Vector3.ZERO) if first else bounds.expand(position)
			first = false
	var cell: float = max(bounds.get_longest_axis_size() / CELLS_ACROSS, 0.0001)
	var cells := {}
	for surface in positions:
		var surface_positions: PoolVector3Array = positions[surface]
		for i in range(surface_positions.size()):
			var at: Vector3 = (surface_positions[i] / cell).floor()
			if not cells.has(at):
				cells[at] = []
			cells[at].append(surface * STRIDE + i)
	return {"cell": cell, "cells": cells, "bounds": bounds}


# Packed entries of the vertices within `reach` of `point` (cells that may hold them; callers
# measure). Walks the cells in range, or the occupied cells when there are fewer of those.
static func query(grid: Dictionary, point: Vector3, reach: float) -> Array:
	var cell: float = grid.cell
	var low: Vector3 = ((point - Vector3.ONE * reach) / cell).floor()
	var high: Vector3 = ((point + Vector3.ONE * reach) / cell).floor()
	var found: Array = []
	var cells: Dictionary = grid.cells
	var span: Vector3 = high - low + Vector3.ONE
	if span.x * span.y * span.z > cells.size():
		for at in cells:
			if at.x >= low.x and at.x <= high.x and at.y >= low.y and at.y <= high.y and at.z >= low.z and at.z <= high.z:
				found.append_array(cells[at])
		return found
	for x in range(int(low.x), int(high.x) + 1):
		for y in range(int(low.y), int(high.y) + 1):
			for z in range(int(low.z), int(high.z) + 1):
				var at := Vector3(x, y, z)
				if cells.has(at):
					found.append_array(cells[at])
	return found


# Packed entries of the vertices that may lie within `reach` of the line through `origin` along
# `direction` (unit), where it crosses the mesh: cells around points stepped along the line
# inside the bounds (grown by the reach), each cell taken once.
static func query_line(grid: Dictionary, origin: Vector3, direction: Vector3, reach: float) -> Array:
	var bounds: AABB = grid.bounds.grow(reach)
	var span = _slab(bounds, origin, direction)
	if span == null:
		return []
	var cell: float = grid.cell
	var cells: Dictionary = grid.cells
	var seen := {}
	var found: Array = []
	# Samples a reach apart; each covers a cube a bit wider than the reach, so the cubes together
	# hold every point within reach of the line.
	var step: float = max(cell, reach)
	var half: float = sqrt(reach * reach + step * step * 0.25)
	var t: float = span.x
	while t <= span.y + step:
		var point: Vector3 = origin + direction * min(t, span.y)
		var low: Vector3 = ((point - Vector3.ONE * half) / cell).floor()
		var high: Vector3 = ((point + Vector3.ONE * half) / cell).floor()
		for x in range(int(low.x), int(high.x) + 1):
			for y in range(int(low.y), int(high.y) + 1):
				for z in range(int(low.z), int(high.z) + 1):
					var at := Vector3(x, y, z)
					if not seen.has(at):
						seen[at] = true
						if cells.has(at):
							found.append_array(cells[at])
		t += step
	return found


# Where the line enters and leaves `box` (as Vector2(t in, t out)), or null if it misses.
static func _slab(box: AABB, origin: Vector3, direction: Vector3):
	var t_in := -INF
	var t_out := INF
	for axis in range(3):
		if abs(direction[axis]) < 0.000001:
			if origin[axis] < box.position[axis] or origin[axis] > box.end[axis]:
				return null
			continue
		var t1: float = (box.position[axis] - origin[axis]) / direction[axis]
		var t2: float = (box.end[axis] - origin[axis]) / direction[axis]
		t_in = max(t_in, min(t1, t2))
		t_out = min(t_out, max(t1, t2))
	return Vector2(t_in, t_out) if t_in <= t_out else null
