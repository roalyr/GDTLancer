# HullScorch: accumulated damage marks on the hull, painted into mesh vertex data.
# - Vertex alpha: how marked a spot is (1 = clean); the shader blends it toward the cooled char colour.
# - UV2: (time of the last hit, heat then). The shader decays heat over damage_cool_time against a
#   per-ship clock set here every frame, glowing red, then dull red, then gone, so cooling needs no
#   mesh updates; the mesh is only re-uploaded after hits.
# Works on any mesh drawn with a solid shader (marks are on by default there); meshes without
# vertex colours get a white set, which looks the same until marked. Each ship gets its own copy
# of the material for its clock.
#
# Each hit is worked out here on the CPU, once per hit (not in a shader), as two effects:
# 1. Where it lands. Each vertex is measured against the shot line (from the shooter to its aim
#    point): how far along it (t) and how far from it. Walking along the line, the first surface is
#    the first spot with at least SCORCH_MIN_SURFACE_POINTS distinct vertex positions facing the
#    shooter within the depth band; back faces never stop the beam, and sparser spots are thin
#    details (antennas, struts) the shot passes. The impact point
#    is that surface's vertex nearest the line.
# 2. The char mark: the beam's footprint. Vertices of that surface within the mark radius of the
#    line, facing the shooter (the beam only burns what it can see). On an oblique face the
#    footprint stretches, as a real beam spot does.
# 3. Heat: conduction through the material. Every vertex within the heat radius of the impact
#    point, in 3D and whatever its orientation, so the back of a thin plate, nearby edges and
#    struts heat too, while the far side of a thick hull (beyond the radius) stays cold.
# Both radii grow with sqrt(damage); repeated hits deepen marks and add heat.
#
# Levels of detail (MeshLod): where the beam lands is worked out on the full-detail mesh, then
# the same char footprint and heat are painted onto every lower level, measured against the
# same shot line and impact point, so marks and glow stay put when a level switches. Lower levels
# are looked up through a coarse vertex grid (VertexGrid, built once per source mesh and shared by
# all objects using it), so painting them costs a few cells around the hit, not a full scan.
# Only the levels on screen are painted at once; hits on hidden levels wait and are replayed (with
# their own hit times, so heat has cooled exactly as it would have) when the level shows, a few
# per frame (Constants.SCORCH_REPLAY_BUDGET_MS).
#
# Cost: a hull off screen records shots and does nothing else until it is in view (many hits in
# a big fight). Seen hulls find the shot's surface through the full-detail mesh's vertex grid
# (cells along the shot line) instead of scanning every vertex. Grids are built in the background
# when objects are set up.

extends Node

# UV2 holds the hit time, so keep it at full float precision when uploading.
const UPLOAD_FORMAT = Mesh.ARRAY_COMPRESS_DEFAULT & ~Mesh.ARRAY_COMPRESS_TEX_UV2
const VertexGrid = preload("res://src/core/agents/components/vertex_grid.gd")

var _meshes: Array = []  # Full detail: {instance, primitives, arrays, materials, paintable: [surface index], source, dirty}
var _lod_meshes: Array = []  # Lower levels of detail, same entries plus "pending" hits; painted from the full-detail hit
var _dirty := false
var _rebuild_timer := 0.0
var _clock := 0.0  # Seconds since setup; the shader's damage_time
var _materials: Array = []  # Per-ship hull material copies that show marks
var last_hit_point = null  # World point where the last add_hit met the hull; null if it missed
var last_hit_normal = null  # World surface normal there (from the mesh), or null
var last_hit_deferred := false  # The last add_hit only recorded the shot (no one could see the hull)
var _pending_hits: Array = []  # Shots recorded while no one could see the hull: [from, aim, damage, clock]


# Collects the mesh surfaces under the ship's visual model that are drawn with a marking shader.
func setup(visual_root: Node) -> void:
	_meshes.clear()
	_lod_meshes.clear()
	var stack: Array = [visual_root]
	while not stack.empty():
		var node = stack.pop_back()
		stack += node.get_children()
		if not (node is MeshInstance and node.mesh is Mesh):
			continue
		var entry := {"instance": node, "primitives": [], "arrays": [], "materials": [], "paintable": [], "source": node.mesh, "dirty": false}
		for surface in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			entry.primitives.append(node.mesh.surface_get_primitive_type(surface) if node.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES)
			entry.arrays.append(arrays)
			entry.materials.append(node.mesh.surface_get_material(surface))
			if _shows_marks(node.get_active_material(surface)):
				entry.paintable.append(surface)
				var vertex_count: int = arrays[Mesh.ARRAY_VERTEX].size()
				var colors = arrays[Mesh.ARRAY_COLOR]
				if colors == null or colors.size() != vertex_count:
					colors = PoolColorArray()
					colors.resize(vertex_count)
					for i in range(vertex_count):
						colors[i] = Color.white
					arrays[Mesh.ARRAY_COLOR] = colors
				var heat := PoolVector2Array()
				heat.resize(colors.size())
				for i in range(heat.size()):
					heat[i] = Vector2.ZERO
				arrays[Mesh.ARRAY_TEX_UV2] = heat
		if not entry.paintable.empty():
			VertexGrid.request(entry.source, entry.arrays, entry.paintable)  # Built in the background
			if node.is_in_group("lod_mesh"):
				entry["pending"] = []
				_lod_meshes.append(entry)
			else:
				_meshes.append(entry)
			_use_own_material_copies(node)


static func _shows_marks(material) -> bool:
	return material is ShaderMaterial and material.shader != null and "damage_mark_strength" in material.shader.code


# Gives this ship its own copies of its marking materials (override and per-surface), so its
# clock and cool time never touch other objects sharing the material.
func _use_own_material_copies(instance: MeshInstance) -> void:
	if _shows_marks(instance.material_override):
		instance.material_override = _own_copy(instance.material_override)
	for surface in range(instance.get_surface_material_count()):
		if _shows_marks(instance.get_surface_material(surface)):
			instance.set_surface_material(surface, _own_copy(instance.get_surface_material(surface)))
	for surface in range(instance.mesh.get_surface_count()):
		if instance.get_surface_material(surface) == null and _shows_marks(instance.mesh.surface_get_material(surface)):
			instance.set_surface_material(surface, _own_copy(instance.mesh.surface_get_material(surface)))


func _own_copy(material: ShaderMaterial) -> ShaderMaterial:
	var copy: ShaderMaterial = material.duplicate()
	copy.set_shader_param("damage_cool_time", Constants.SCORCH_COOL_TIME)
	copy.set_shader_param("damage_glow_threshold", Constants.SCORCH_GLOW_THRESHOLD)
	copy.set_shader_param("damage_max_heat", Constants.SCORCH_MAX_HEAT)
	_materials.append(copy)
	return copy


func is_paintable() -> bool:
	return not _meshes.empty()


# Paints a mark where a shot from `from_global` toward `aim_global` first meets the hull, and
# records that point in last_hit_point. Returns the number of vertices charred or heated (0 = the shot line
# passed the hull without touching it, e.g. between wings).
# A hull off screen only records the shot: last_hit_deferred is set, no point is found, and the
# hit is painted, with its own hit time, once the hull is in view (see _replay_pending). On
# screen it is painted at once at any distance, whichever level of detail shows.
func add_hit(from_global: Vector3, aim_global: Vector3, damage: float) -> int:
	last_hit_point = null
	last_hit_normal = null
	last_hit_deferred = false
	if damage <= 0.0 or _meshes.empty():
		return 0
	if not _pending_hits.empty() or not is_watched():
		last_hit_deferred = true
		_pending_hits.append([from_global, aim_global, damage, _clock])
		if _pending_hits.size() > Constants.SCORCH_MAX_PENDING:
			_pending_hits.pop_front()  # The oldest: long cooled, only its char is lost
		return 0
	return _apply_hit(from_global, aim_global, damage, _clock)


# Whether the hull is in the camera's view, at any distance (the full-detail mesh stands for every
# level of detail: they share its place and size).
func is_watched() -> bool:
	var camera = get_viewport().get_camera() if is_inside_tree() else null
	if camera == null:
		return true  # Nothing to judge by (tests, tools)
	var planes: Array = camera.get_frustum()
	for entry in _meshes:
		if not is_instance_valid(entry.instance):
			continue
		var box: AABB = entry.instance.get_aabb()
		var to_world: Transform = entry.instance.global_transform
		var centre: Vector3 = to_world.xform(box.position + box.size * 0.5)
		var radius: float = box.size.length() * 0.5 * to_world.basis.get_scale().x
		var inside := true
		for plane in planes:
			if plane.distance_to(centre) > radius:
				inside = false
				break
		if inside:
			return true
	return false


# The hit itself, stamped with `clock` (now, or the time of a replayed hit).
# 1. The surface: vertices along the shot line within the char radius (through the mesh's vertex
#    grid, not a scan of the whole mesh), widened on coarse meshes.
# 2. The impact point: the first surface's vertex nearest the line.
# 3. Char and heat, painted around the impact point on every mesh (full detail at once, lower
#    levels of detail when shown).
func _apply_hit(from_global: Vector3, aim_global: Vector3, damage: float, clock: float) -> int:
	# Both grow with beam power: the char mark, and the wider area the heat reaches.
	var radius: float = Constants.SCORCH_RADIUS_PER_SQRT_DAMAGE * sqrt(damage)
	var surfaces_by_key := {}  # surface key -> that surface's arrays
	var instances_by_key := {}  # surface key -> its MeshInstance
	var beams_by_key := {}  # surface key -> shot direction in that mesh's space
	# [surface key, vertex index, t (m), distance from line (m), position, faces the shooter]
	var candidates: Array = _collect_candidates(from_global, aim_global, radius, surfaces_by_key, instances_by_key, beams_by_key)
	# Coarse meshes (a large low-poly rock) can have no vertex this close to the line: widen until
	# the shot finds enough surface to mark. Such marks are coarser, but always show.
	for _widen in range(Constants.SCORCH_MAX_WIDENINGS):
		if _count_points(candidates) >= Constants.SCORCH_MIN_SURFACE_POINTS:
			break
		radius *= 2.0
		candidates = _collect_candidates(from_global, aim_global, radius, surfaces_by_key, instances_by_key, beams_by_key)
	var heat_radius: float = radius * Constants.SCORCH_HEAT_SPREAD
	var depth: float = max(Constants.SCORCH_SURFACE_DEPTH, radius * 0.5)
	var first_t: float = _find_first_surface(candidates, depth)

	var closest_to_line := INF
	for candidate in candidates:
		if not candidate[5] or candidate[2] < first_t or candidate[2] > first_t + depth or candidate[3] >= closest_to_line:
			continue
		closest_to_line = candidate[3]
		var arrays: Array = surfaces_by_key[candidate[0]]
		var to_world: Transform = instances_by_key[candidate[0]].global_transform
		last_hit_point = to_world.xform(candidate[4])
		var normals = arrays[Mesh.ARRAY_NORMAL]
		if normals != null and normals.size() > candidate[1]:
			last_hit_normal = to_world.basis.xform(normals[candidate[1]]).normalized()
	if last_hit_point == null:
		return 0

	var hit := {"from": from_global, "aim": aim_global, "first_t": first_t, "depth": depth, "radius": radius,
		"heat_radius": heat_radius, "heat_gain": Constants.SCORCH_HEAT_PER_DAMAGE * damage, "point": last_hit_point, "clock": clock}
	var painted := 0
	for entry in _meshes:
		painted += _paint_entry(entry, hit)
	if painted > 0:
		for entry in _lod_meshes:
			if entry.instance.is_visible_in_tree() and entry.pending.empty():  # Older hits first
				_paint_entry(entry, hit)
			else:
				entry.pending.append(hit)
				if entry.pending.size() > Constants.SCORCH_MAX_PENDING:
					entry.pending.pop_front()  # The oldest: long cooled, only its char is lost
		_dirty = true
	return painted


# A hit painted onto one mesh (full detail or a lower level): vertices near the impact point,
# found through the source mesh's vertex grid. Char where the beam's footprint meets the surface
# facing the shooter; heat by distance from the impact point. `hit` holds the shot line, the
# surface found, both radii, the heat added and the hit time. Returns the vertices painted.
func _paint_entry(entry: Dictionary, hit: Dictionary) -> int:
	var painted := 0
	var first_t: float = hit.first_t
	var depth: float = hit.depth
	var radius: float = hit.radius
	var heat_radius: float = hit.heat_radius
	var reach: float = max(heat_radius, radius + depth)
	var to_local: Transform = entry.instance.global_transform.affine_inverse()
	var scale: float = entry.instance.global_transform.basis.get_scale().x
	var origin: Vector3 = to_local.xform(hit.from)
	var direction: Vector3 = (to_local.xform(hit.aim) - origin).normalized()
	var centre: Vector3 = to_local.xform(hit.point)
	var by_surface := {}
	for packed in VertexGrid.query(VertexGrid.for_mesh(entry.source, entry.arrays, entry.paintable), centre, reach / scale):
		var surface: int = packed / VertexGrid.STRIDE
		if not by_surface.has(surface):
			by_surface[surface] = []
		by_surface[surface].append(packed % VertexGrid.STRIDE)
	for surface in by_surface:
		var arrays: Array = entry.arrays[surface]
		var positions: PoolVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PoolColorArray = arrays[Mesh.ARRAY_COLOR]
		var heat: PoolVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		arrays[Mesh.ARRAY_COLOR] = null
		arrays[Mesh.ARRAY_TEX_UV2] = null
		for i in by_surface[surface]:
			var relative: Vector3 = positions[i] - origin
			var t_local: float = relative.dot(direction)
			var t: float = t_local * scale  # Along the shot line, m (as on the full-detail mesh)
			var line_distance: float = sqrt(max(relative.length_squared() - t_local * t_local, 0.0)) * scale
			var char_falloff := 0.0
			if t >= first_t and t <= first_t + depth and line_distance < radius and _faces_shooter(arrays, i, direction):
				char_falloff = smoothstep(radius, 0.0, line_distance)
			var heat_falloff: float = smoothstep(heat_radius, 0.0, positions[i].distance_to(centre) * scale)
			if char_falloff > 0.0:
				var color: Color = colors[i]
				color.a *= 1.0 - Constants.SCORCH_CENTRE_MARK * char_falloff
				colors[i] = color
				entry.dirty = true
			if char_falloff > 0.0 or heat_falloff > 0.0:
				painted += 1
			if heat_falloff > 0.0:
				heat[i] = Vector2(hit.clock, min(Constants.SCORCH_MAX_HEAT, heat_at(heat[i], hit.clock) + hit.heat_gain * heat_falloff))
				entry.dirty = true
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV2] = heat
	return painted


# Replays, within the frame budget: hits that landed while no one could see the hull (once someone
# can), then hits waiting for a hidden level of detail (once it shows).
func _replay_pending() -> void:
	var start: int = OS.get_ticks_usec()
	while not _pending_hits.empty() and is_watched():
		var shot: Array = _pending_hits.pop_front()
		_apply_hit(shot[0], shot[1], shot[2], shot[3])
		if OS.get_ticks_usec() - start > Constants.SCORCH_REPLAY_BUDGET_MS * 1000:
			return
	for entry in _lod_meshes:
		while not entry.pending.empty() and entry.instance.is_visible_in_tree():
			_paint_entry(entry, entry.pending.pop_front())
			_dirty = true
			if OS.get_ticks_usec() - start > Constants.SCORCH_REPLAY_BUDGET_MS * 1000:
				return


# --- Persistence (the player's hull keeps its marks across sectors and saves) ---

# Marks as {"mesh index:surface": PoolRealArray of vertex alpha}, for marked surfaces only.
# Heat is not kept: restored marks come back cooled.
func export_marks() -> Dictionary:
	var marks := {}
	for mesh_index in range(_meshes.size()):
		var entry: Dictionary = _meshes[mesh_index]
		for surface in entry.paintable:
			var alphas := PoolRealArray()
			var marked := false
			for color in entry.arrays[surface][Mesh.ARRAY_COLOR]:
				alphas.append(color.a)
				marked = marked or color.a < 1.0
			if marked:
				marks["%d:%d" % [mesh_index, surface]] = alphas
	return marks


# Applies exported marks; surfaces whose vertex count no longer matches (another hull) are skipped.
func import_marks(marks: Dictionary) -> void:
	for key in marks:
		var parts: PoolStringArray = str(key).split(":")
		if parts.size() != 2:
			continue
		var mesh_index: int = int(parts[0])
		var surface: int = int(parts[1])
		if mesh_index >= _meshes.size() or not surface in _meshes[mesh_index].paintable:
			continue
		var arrays: Array = _meshes[mesh_index].arrays[surface]
		var alphas = marks[key]
		var colors: PoolColorArray = arrays[Mesh.ARRAY_COLOR]
		if alphas.size() != colors.size():
			continue
		arrays[Mesh.ARRAY_COLOR] = null
		for i in range(colors.size()):
			var color: Color = colors[i]
			color.a = alphas[i]
			colors[i] = color
		arrays[Mesh.ARRAY_COLOR] = colors
		_meshes[mesh_index].dirty = true
		_dirty = true


# Restores a clean hull (repairs).
func clear_marks() -> void:
	_pending_hits.clear()
	for entry in _lod_meshes:
		entry.pending.clear()
	for entry in _meshes + _lod_meshes:
		entry.dirty = true
		for surface in entry.paintable:
			var arrays: Array = entry.arrays[surface]
			var colors: PoolColorArray = arrays[Mesh.ARRAY_COLOR]
			arrays[Mesh.ARRAY_COLOR] = null
			for i in range(colors.size()):
				var color: Color = colors[i]
				color.a = 1.0
				colors[i] = color
			arrays[Mesh.ARRAY_COLOR] = colors
	_dirty = true


# A vertex the beam can reach: its normal points back toward the shooter. Meshes without normals
# count every vertex as facing.
static func _faces_shooter(arrays: Array, index: int, beam_local: Vector3) -> bool:
	var normals = arrays[Mesh.ARRAY_NORMAL]
	if normals == null or normals.size() <= index:
		return true
	return normals[index].dot(beam_local) < 0.0


# PERFORMANCE (headless bench, 6-damage hit): ~3 ms on the densest rock, ~24 ms on the light
# Phoenix, whose remaining cost is mostly _find_first_surface (it re-counts points for every
# candidate start; a sliding window over the depth-sorted candidates would make it one pass).
# Further options if needed: update only the colour/UV2 byte ranges on upload
# (ArrayMesh.surface_update_region) instead of rebuilding the mesh; share immutable arrays per
# source mesh and keep only colours and heat per object.

# Vertices near the shot line, from every full-detail surface: those in the grid cells along the
# line where it crosses the mesh, measured exactly.
func _collect_candidates(from_global: Vector3, aim_global: Vector3, radius: float, surfaces_by_key: Dictionary, instances_by_key: Dictionary, beams_by_key: Dictionary) -> Array:
	var candidates: Array = []
	for mesh_index in range(_meshes.size()):
		var entry: Dictionary = _meshes[mesh_index]
		var to_local: Transform = entry.instance.global_transform.affine_inverse()
		var scale: float = entry.instance.global_transform.basis.get_scale().x
		var origin: Vector3 = to_local.xform(from_global)
		var direction: Vector3 = (to_local.xform(aim_global) - origin).normalized()
		var radius_local: float = radius / scale
		var radius_sq: float = radius_local * radius_local
		for surface in entry.paintable:
			var key: int = mesh_index * 1024 + surface
			surfaces_by_key[key] = entry.arrays[surface]
			instances_by_key[key] = entry.instance
			beams_by_key[key] = direction
		var grid: Dictionary = VertexGrid.for_mesh(entry.source, entry.arrays, entry.paintable)
		for packed in VertexGrid.query_line(grid, origin, direction, radius_local):
			var surface: int = packed / VertexGrid.STRIDE
			var i: int = packed % VertexGrid.STRIDE
			var arrays: Array = entry.arrays[surface]
			var position: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
			var relative: Vector3 = position - origin
			var t: float = relative.dot(direction)
			var distance_sq: float = relative.length_squared() - t * t
			if distance_sq < radius_sq:
				candidates.append([mesh_index * 1024 + surface, i, t * scale, sqrt(max(distance_sq, 0.0)) * scale, position, _faces_shooter(arrays, i, direction)])
	return candidates


static func _count_points(candidates: Array) -> int:
	var points := {}
	for candidate in candidates:
		points[candidate[4].snapped(Vector3.ONE * 0.001)] = true
	return points.size()


# Smallest t with at least SCORCH_MIN_SURFACE_POINTS distinct vertex positions within
# `depth` behind it (meshes repeat a vertex per face at hard edges, so positions are
# counted, not vertices). Falls back to the nearest candidate when the line only grazes thin parts.
static func _find_first_surface(candidates: Array, depth: float) -> float:
	# The beam lands on the first surface it can see: back faces (inner walls, nozzle interiors)
	# never stop it.
	var sorted: Array = []
	for candidate in candidates:
		if candidate[5]:
			sorted.append(candidate)
	if sorted.empty():
		return INF
	sorted.sort_custom(ScorchDepthSorter, "by_depth")
	for start in range(sorted.size()):
		var points := {}
		var limit: float = sorted[start][2] + depth
		for index in range(start, sorted.size()):
			if sorted[index][2] > limit:
				break
			points[sorted[index][4].snapped(Vector3.ONE * 0.001)] = true
		if points.size() >= Constants.SCORCH_MIN_SURFACE_POINTS:
			return sorted[start][2]
	return sorted[0][2]


class ScorchDepthSorter:
	static func by_depth(a, b) -> bool:
		return a[2] < b[2]


# Average marked share across paintable vertices (0 = clean hull, 1 = fully marked).
func get_average_mark() -> float:
	var total := 0.0
	var count := 0
	for entry in _meshes:
		for surface in entry.paintable:
			for color in entry.arrays[surface][Mesh.ARRAY_COLOR]:
				total += 1.0 - color.a
				count += 1
	return total / count if count > 0 else 0.0


# Heat left now from a stored (hit time, heat then) pair; same decay as the shader.
func get_heat(stored: Vector2) -> float:
	return heat_at(stored, _clock)


# Heat left at `clock` (a replayed hit's time) from a stored (hit time, heat then) pair.
static func heat_at(stored: Vector2, clock: float) -> float:
	return stored.y * exp(-max(clock - stored.x, 0.0) / Constants.SCORCH_COOL_TIME)


func _process(delta: float) -> void:
	_clock += delta
	for material in _materials:
		material.set_shader_param("damage_time", _clock)
	_rebuild_timer = max(0.0, _rebuild_timer - delta)
	_replay_pending()
	if _dirty and _rebuild_timer <= 0.0:
		rebuild_meshes()


# Uploads the painted colours: each ship gets its own mesh copy, since the imported mesh is shared.
# Only changed meshes, and only while shown: a hidden level of detail uploads once it appears.
func rebuild_meshes() -> void:
	_dirty = false
	_rebuild_timer = Constants.SCORCH_REBUILD_INTERVAL
	for entry in _meshes + _lod_meshes:
		if not is_instance_valid(entry.instance) or not entry.dirty:
			continue
		if not entry.instance.is_visible_in_tree():
			_dirty = true  # Try again once it shows
			continue
		entry.dirty = false
		var mesh := ArrayMesh.new()
		for surface in range(entry.arrays.size()):
			mesh.add_surface_from_arrays(entry.primitives[surface], entry.arrays[surface], [], UPLOAD_FORMAT)
			mesh.surface_set_material(surface, entry.materials[surface])
		entry.instance.mesh = mesh
