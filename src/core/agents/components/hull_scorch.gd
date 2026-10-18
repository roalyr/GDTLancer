# HullScorch: accumulated damage marks on the hull, painted into mesh vertex data.
# - Vertex alpha: how marked a spot is (1 = clean); the shader blends it toward the cooled char colour.
# - UV2: (time of the last hit, heat then). The shader decays heat over damage_cool_time against a
#   per-ship clock set here every frame, glowing red, then dull red, then gone, so cooling needs no
#   mesh updates; the mesh is only re-uploaded after hits.
# Works on any mesh drawn with a solid shader (marks are on by default there); meshes without
# vertex colours get a white set, which looks the same until marked. Each ship gets its own copy
# of the material for its clock.
#
# Where a hit lands is found here on the CPU, once per hit (not in a shader):
# 1. Each vertex is measured against the shot line, from the shooter to its aim point:
#    how far along the line it is (t) and how far from it (perpendicular distance).
# 2. Vertices closer to the line than the mark radius are candidates. The smallest t among
#    them is the first surface the shot meets.
# 3. Only candidates within SURFACE_DEPTH behind that surface are marked, with a smooth falloff
#    away from the line, so the far side of the hull stays clean.
# Mark area grows with damage (radius ~ sqrt(damage)) at a fixed centre strength, so the marked
# area is proportional to damage taken. Repeated hits on the same spot deepen the mark.

extends Node

const MARK_RADIUS_PER_SQRT_DAMAGE = 1.0  # m; a 6-damage hit marks about 2.5 m across
const CENTRE_MARK = 0.35  # Share of the clean surface a single hit marks at its centre
const SURFACE_DEPTH = 1.0  # m
const REBUILD_INTERVAL = 0.2  # s; marks are painted at once, the mesh is re-uploaded at most this often
const HEAT_PER_DAMAGE = 0.08  # Heat added at a mark's centre per point of damage (1 = full glow)
const MAX_HEAT = 1.0
const COOL_TIME = 6.0  # s for heat to fall to ~37%; pushed to the shader so both agree
# UV2 holds the hit time, so keep it at full float precision when uploading.
const UPLOAD_FORMAT = Mesh.ARRAY_COMPRESS_DEFAULT & ~Mesh.ARRAY_COMPRESS_TEX_UV2

var _meshes: Array = []  # {instance, primitives, arrays, materials, paintable: [surface index]}
var _dirty := false
var _rebuild_timer := 0.0
var _clock := 0.0  # Seconds since setup; the shader's damage_time
var _materials: Array = []  # Per-ship hull material copies that show marks
var last_hit_point = null  # World point where the last add_hit met the hull; null if it missed


# Collects the mesh surfaces under the ship's visual model that are drawn with a marking shader.
func setup(visual_root: Node) -> void:
	_meshes.clear()
	var stack: Array = [visual_root]
	while not stack.empty():
		var node = stack.pop_back()
		stack += node.get_children()
		if not (node is MeshInstance and node.mesh is Mesh):
			continue
		var entry := {"instance": node, "primitives": [], "arrays": [], "materials": [], "paintable": []}
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
	copy.set_shader_param("damage_cool_time", COOL_TIME)
	_materials.append(copy)
	return copy


func is_paintable() -> bool:
	return not _meshes.empty()


# Paints a mark where a shot from `from_global` toward `aim_global` first meets the hull, and
# records that point in last_hit_point. Returns the number of vertices marked (0 = the shot line
# passed the hull without touching it, e.g. between wings).
func add_hit(from_global: Vector3, aim_global: Vector3, damage: float) -> int:
	last_hit_point = null
	if damage <= 0.0 or _meshes.empty():
		return 0
	var radius: float = MARK_RADIUS_PER_SQRT_DAMAGE * sqrt(damage)
	var candidates: Array = []  # [surface key, vertex index, t (m), distance from line (m)]
	var surfaces_by_key := {}  # surface key -> that surface's arrays
	var instances_by_key := {}  # surface key -> its MeshInstance
	var first_t := INF
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
			var positions: PoolVector3Array = entry.arrays[surface][Mesh.ARRAY_VERTEX]
			for i in range(positions.size()):
				var relative: Vector3 = positions[i] - origin
				var t: float = relative.dot(direction)
				var distance_sq: float = relative.length_squared() - t * t
				if distance_sq < radius_sq:
					candidates.append([key, i, t * scale, sqrt(max(distance_sq, 0.0)) * scale])
					first_t = min(first_t, t * scale)

	# Group the darkening per surface, then edit each colour array once while it is detached:
	# pool arrays copy on write, so a still-shared array would be copied on every vertex write.
	var updates := {}  # surface key -> [[vertex index, falloff], ...]
	var painted := 0
	var closest_to_line := INF
	for candidate in candidates:
		if candidate[2] > first_t + SURFACE_DEPTH:
			continue
		if candidate[3] < closest_to_line:
			# The hit point: the vertex of the first surface nearest the shot line.
			closest_to_line = candidate[3]
			var position: Vector3 = surfaces_by_key[candidate[0]][Mesh.ARRAY_VERTEX][candidate[1]]
			last_hit_point = instances_by_key[candidate[0]].global_transform.xform(position)
		if not updates.has(candidate[0]):
			updates[candidate[0]] = []
		updates[candidate[0]].append([candidate[1], smoothstep(radius, 0.0, candidate[3])])
		painted += 1
	var heat_gain: float = HEAT_PER_DAMAGE * damage
	for key in updates:
		var arrays: Array = surfaces_by_key[key]
		var colors: PoolColorArray = arrays[Mesh.ARRAY_COLOR]
		var heat: PoolVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		arrays[Mesh.ARRAY_COLOR] = null
		arrays[Mesh.ARRAY_TEX_UV2] = null
		for update in updates[key]:
			var falloff: float = update[1]
			var color: Color = colors[update[0]]
			color.a *= 1.0 - CENTRE_MARK * falloff
			colors[update[0]] = color
			heat[update[0]] = Vector2(_clock, min(MAX_HEAT, get_heat(heat[update[0]]) + heat_gain * falloff))
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV2] = heat
	if painted > 0:
		_dirty = true
	return painted


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
	return stored.y * exp(-max(_clock - stored.x, 0.0) / COOL_TIME)


func _process(delta: float) -> void:
	_clock += delta
	for material in _materials:
		material.set_shader_param("damage_time", _clock)
	_rebuild_timer = max(0.0, _rebuild_timer - delta)
	if _dirty and _rebuild_timer <= 0.0:
		rebuild_meshes()


# Uploads the painted colours: each ship gets its own mesh copy, since the imported mesh is shared.
func rebuild_meshes() -> void:
	_dirty = false
	_rebuild_timer = REBUILD_INTERVAL
	for entry in _meshes:
		if not is_instance_valid(entry.instance):
			continue
		var mesh := ArrayMesh.new()
		for surface in range(entry.arrays.size()):
			mesh.add_surface_from_arrays(entry.primitives[surface], entry.arrays[surface], [], UPLOAD_FORMAT)
			mesh.surface_set_material(surface, entry.materials[surface])
		entry.instance.mesh = mesh
