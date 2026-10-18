# VertexGrid: a coarse spatial index of a mesh's vertex positions (all its paintable surfaces),
# for finding the vertices near a point without scanning them all. Built once per source mesh
# (in mesh space) and shared by every object drawing that mesh; the cache holds the source Mesh,
# so a grid lives as long as its mesh. Entries pack surface and vertex index: surface * STRIDE + i.

extends Reference

const CELLS_ACROSS = 24.0  # Cells along the longest side of the mesh's bounds
const STRIDE = 1000000  # Vertex indices per surface in a packed entry
const _CACHE := {}  # Source mesh -> grid; a const dictionary stays mutable


# The grid for `source`, built on first use from its `arrays` (per surface) for `surfaces`.
static func for_mesh(source: Mesh, arrays: Array, surfaces: Array) -> Dictionary:
	if not _CACHE.has(source):
		_CACHE[source] = build(arrays, surfaces)
	return _CACHE[source]


static func build(arrays: Array, surfaces: Array) -> Dictionary:
	var bounds := AABB()
	var first := true
	for surface in surfaces:
		for position in arrays[surface][Mesh.ARRAY_VERTEX]:
			bounds = AABB(position, Vector3.ZERO) if first else bounds.expand(position)
			first = false
	var cell: float = max(bounds.get_longest_axis_size() / CELLS_ACROSS, 0.0001)
	var cells := {}
	for surface in surfaces:
		var positions: PoolVector3Array = arrays[surface][Mesh.ARRAY_VERTEX]
		for i in range(positions.size()):
			var at: Vector3 = (positions[i] / cell).floor()
			if not cells.has(at):
				cells[at] = []
			cells[at].append(surface * STRIDE + i)
	return {"cell": cell, "cells": cells}


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
