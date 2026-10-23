# HullScars: where hits landed on a ship's plating, a blob of molten hull glows white-orange, then
# cools over Constants.HULL_SCAR_COOL_TIME to a dark lump that stays until the hull is repaired.
# - One HullScars per ship, under its visual root (it moves and stretches with the model). Blobs
#   are merged into chunk meshes of Constants.HULL_SCAR_CHUNK_BLOBS each (child MeshInstances,
#   made as needed), so a ship costs a draw call per chunk in use, not per blob (GLES2 draws a
#   MultiMesh one instance per draw call), and a change rebuilds only its chunk. Slots fill chunks
#   in order, so new scars touch only the newest chunk. Unshaded (no light passes). Up to
#   Constants.HULL_SCAR_MAX_PER_SHIP scars, scaled by the ship's size (`size_factor`); the oldest
#   gives way.
# - Every blob is a copy of a template sphere (hull_scar_mesh.tres; slag the lighter
#   hull_slag_mesh.tres), placed and lumped on the CPU. A blob's vertices are worked out only when
#   its chunk is rebuilt, and chunks are rebuilt only while shown, at most every
#   Constants.HULL_SCAR_REBUILD_INTERVAL: hits on ships nobody sees cost only their placement.
# - Shown within Constants.HULL_SCAR_VISIBLE_DISTANCE (slag: HULL_SLAG_VISIBLE_DISTANCE) of the
#   camera, as view distances (ScreenSpace.view_distance): zooming in on a far ship shows its
#   scars. Checked every Constants.LOD_CHECK_INTERVAL while the ship has scars (Godot 3's
#   lod_max_distance does nothing).
# - Each scar's placement comes from the hit (scar_transform()): up along the plating's normal,
#   stretched along the beam on glancing hits, sunk part way in so the plating hides the rest.
# - Cooling runs in the shader (hull_scar.gdshader): each blob's vertices carry its hit time, and
#   every ship shares one material whose `now` is set while any scar is hot. Per vertex:
#   UV2 = (hit time (clock()), random seed), COLOR.r = facing (head-on hits glow hotter).
#   Per scar data (get_scar_data()): hit time, seed, facing, size (m).
# - Needs hit points on the plating: add_scar() only for hits on a hit surface (CollisionHull), never
#   the convex hull (a scar there would float off the ship).
# - Slag (set_slag_count()): lasting damage. Small blobs on the scars (up to
#   Constants.HULL_SLAG_PER_SCAR each, on the scars with the fewest, newest first) that cool and
#   flare up again every few seconds, as if re-igniting: chunks under the child "Slag", same shader
#   (relight on, hull_slag_material.tres). A slag blob belongs to its scar: when the scar gives way
#   to a new one, or grows, the slag moves with it. Not saved: the count follows the hull lost.
# - export_scars() / import_scars() keep the player's scars in the save (cold).
# - Scars are kept in script arrays; nothing is read back from the renderer (headless runs have none).

extends Spatial

const ScreenSpace = preload("res://src/core/ui/screen_space.gd")
const ScarMesh = preload("res://assets/art/effects/hull_scar_mesh.tres")
const SlagMesh = preload("res://assets/art/effects/hull_slag_mesh.tres")
const ScarMaterial = preload("res://assets/art/effects/hull_scar_material.tres")
const SlagMaterial = preload("res://assets/art/effects/hull_slag_material.tres")

const _TEMPLATES := {}  # Template mesh path -> {"vertices", "normals", "indices"} (filled once each)
const _INDEX_CACHE := {}  # Template mesh path -> indices of a full chunk of its blobs

var _capacity := 1  # Scars at most
var _next := 0  # Slot the next new scar takes (round robin)
var _count := 0  # Scars in use (slots 0.._count-1)
var _placed: Array = []  # Per scar slot: its Transform in this node's space
var _data: Array = []  # Per scar slot: Color(hit time, seed, facing, size)
var _blobs: Array = []  # Per scar slot: its vertex arrays (_blob_arrays()), or null until its chunk is rebuilt
var _chunks: Array = []  # Per scar chunk: its MeshInstance, or null until first needed
var _dirty := {}  # Scar chunks to rebuild -> true
var _hot_until := 0.0  # clock() when the latest scar is cold
var _timer := 0.0  # s to the next camera distance check
var _rebuild_timer := 0.0  # s until chunks may be rebuilt again

var _slag_root: Spatial = null  # "Slag": parent of the slag chunks, shown nearer than scars
var _slag_capacity := 1
var _slag_count := 0  # Slag blobs in use (slots 0.._slag_count-1)
var _slag_scar: Array = []  # Per slag slot: the scar slot it sits on
var _slag_jitter: Array = []  # Per slag slot: Vector2 offset across its scar (share of the scar's size)
var _slag_data: Array = []  # Per slag slot: Color(start time, seed, facing, size)
var _slag_placed: Array = []  # Per slag slot: its Transform in this node's space
var _slag_blobs: Array = []  # Per slag slot: its vertex arrays, or null until its chunk is rebuilt
var _slag_chunks: Array = []
var _slag_dirty := {}


# Seconds on the clock the shader's `now` follows. Not the shader's TIME: that wraps every hour.
static func clock() -> float:
	return OS.get_ticks_msec() * 0.001


# Where a scar from a hit sits, in world space: its blob's y axis along the plating's normal
# `hit_normal` (turned toward the shooter if it came off a back face), z along `shot_dir` flattened
# onto the plating and stretched up to 1 / Constants.HULL_SCAR_MIN_FACING on glancing hits, x across.
# `size` is the width in metres; `twist` turns it about the normal (radians). The blob's centre
# sits Constants.HULL_SCAR_SINK of its height below `hit_pos`.
static func scar_transform(hit_pos: Vector3, hit_normal: Vector3, shot_dir: Vector3, size: float, twist: float = 0.0) -> Transform:
	var n: Vector3 = hit_normal.normalized()
	var dir: Vector3 = shot_dir.normalized()
	if n.dot(dir) > 0.0:
		n = -n  # A back face of the trimesh: turn it toward the shooter
	var along: Vector3 = dir - n * dir.dot(n)  # The beam flattened onto the plating
	if along.length_squared() < 0.0001:  # Straight on: any direction will do
		along = n.cross(Vector3.UP if abs(n.y) < 0.9 else Vector3.RIGHT)
	along = along.normalized()
	var side: Vector3 = n.cross(along)  # x = y × z keeps the basis right-handed
	var height: float = size * Constants.HULL_SCAR_FLATNESS
	var basis := Basis(side * size, n * height, along * size * stretch_for(n, dir))  # Columns: x, y, z
	if twist != 0.0:
		basis = basis.rotated(n, twist)
	return Transform(basis, hit_pos - n * height * Constants.HULL_SCAR_SINK)


# How much a scar stretches along the beam: 1 head-on, up to 1 / Constants.HULL_SCAR_MIN_FACING
# grazing (the beam's energy spreads over ~1 / cos of its angle more plating).
static func stretch_for(normal: Vector3, shot_dir: Vector3) -> float:
	return 1.0 / max(abs(normal.normalized().dot(shot_dir.normalized())), Constants.HULL_SCAR_MIN_FACING)


# A scar's width in metres for a hit of `damage`.
static func size_for_damage(damage: float) -> float:
	return clamp(Constants.HULL_SCAR_SIZE_PER_SQRT_DAMAGE * sqrt(max(damage, 0.0)), Constants.HULL_SCAR_MIN_SIZE, Constants.HULL_SCAR_MAX_SIZE)


# `size_factor`: the ship's interaction radius over Constants.HULL_SCAR_REFERENCE_RADIUS; scar and
# slag capacity scale with it.
func _init(size_factor: float = 1.0) -> void:
	name = "HullScars"
	ScarMaterial.set_shader_param("cool_time", Constants.HULL_SCAR_COOL_TIME)
	_capacity = int(max(1.0, round(Constants.HULL_SCAR_MAX_PER_SHIP * size_factor)))
	for list in [_placed, _data, _blobs]:
		list.resize(_capacity)
	_chunks.resize(_chunk_count(_capacity))
	_slag_capacity = int(max(1.0, round(Constants.HULL_SLAG_MAX * size_factor)))
	for list in [_slag_scar, _slag_jitter, _slag_data, _slag_placed, _slag_blobs]:
		list.resize(_slag_capacity)
	_slag_chunks.resize(_chunk_count(_slag_capacity))
	_slag_root = Spatial.new()
	_slag_root.name = "Slag"
	add_child(_slag_root)


static func _chunk_count(blobs: int) -> int:
	return int(ceil(float(blobs) / Constants.HULL_SCAR_CHUNK_BLOBS))


func _ready() -> void:
	set_process(_count > 0)  # Godot turns _process on at ready; only a scarred ship needs it


func _process(delta: float) -> void:
	var now: float = clock()
	if now <= _hot_until + 0.5:  # A little past cold, so the last frame shows it cold
		ScarMaterial.set_shader_param("now", now)  # Shared: one value for every ship, so setting it twice is harmless
	if _slag_count > 0:
		SlagMaterial.set_shader_param("now", now)  # Slag flares up for as long as it is there
	_timer -= delta
	if _timer <= 0.0:
		_timer = Constants.LOD_CHECK_INTERVAL
		_update_shown()
	_rebuild_timer -= delta
	if _rebuild_timer <= 0.0 and visible:
		_flush(true, _slag_root.visible)


# Shows scars and slag by their view distance from the camera. Coming into view rebuilds what
# changed while out of it at once.
func _update_shown() -> void:
	var camera = get_viewport().get_camera() if is_inside_tree() else null
	var distance: float = ScreenSpace.view_distance(camera, global_transform.origin) if camera != null else 0.0
	var was_shown: bool = visible
	var slag_was_shown: bool = _slag_root.visible
	visible = distance <= Constants.HULL_SCAR_VISIBLE_DISTANCE
	_slag_root.visible = distance <= Constants.HULL_SLAG_VISIBLE_DISTANCE
	if (visible and not was_shown) or (_slag_root.visible and not slag_was_shown):
		_rebuild_timer = 0.0


# Rebuilds every changed chunk now, shown or not (normally _process does, throttled and only while shown).
func flush() -> void:
	_flush(true, true)


func _flush(scars: bool, slag: bool) -> void:
	if scars and not _dirty.empty():
		for chunk in _dirty:
			_build_chunk(chunk, false)
		_dirty.clear()
		_rebuild_timer = Constants.HULL_SCAR_REBUILD_INTERVAL
	if slag and not _slag_dirty.empty():
		for chunk in _slag_dirty:
			_build_chunk(chunk, true)
		_slag_dirty.clear()
		_rebuild_timer = Constants.HULL_SCAR_REBUILD_INTERVAL


# Rebuilds scar (or `slag`) chunk `chunk` from its blobs in use, working out the vertices of any
# blob that changed since.
func _build_chunk(chunk: int, slag: bool) -> void:
	var size: int = Constants.HULL_SCAR_CHUNK_BLOBS
	var start: int = chunk * size
	var used: int = int(clamp((_slag_count if slag else _count) - start, 0, size))
	var blobs: Array = _slag_blobs if slag else _blobs
	if used == 0 and (_slag_chunks if slag else _chunks)[chunk] == null:
		return  # Nothing there, nothing drawn yet
	for i in range(start, start + used):
		if blobs[i] == null:
			if slag:
				blobs[i] = _blob_arrays(SlagMesh, _slag_placed[i], _slag_data[i], Constants.HULL_SLAG_LUMP)
			else:
				blobs[i] = _blob_arrays(ScarMesh, _placed[i], _data[i], Constants.HULL_SCAR_LUMP)
	var node: MeshInstance = _chunk_node(chunk, slag)
	_build(node.mesh, blobs, start, used, SlagMesh if slag else ScarMesh, SlagMaterial if slag else ScarMaterial)


# Scar (or `slag`) chunk `chunk`'s MeshInstance, made on first use.
func _chunk_node(chunk: int, slag: bool) -> MeshInstance:
	var chunks: Array = _slag_chunks if slag else _chunks
	if chunks[chunk] == null:
		var node := MeshInstance.new()
		node.name = ("Slag%d" if slag else "Scars%d") % chunk
		node.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		node.mesh = ArrayMesh.new()
		(_slag_root if slag else self).add_child(node)
		chunks[chunk] = node
	return chunks[chunk]


# Joins blobs start..start+used-1's vertex arrays into `target`'s one surface (none if used is 0).
static func _build(target: ArrayMesh, blobs: Array, start: int, used: int, template_mesh: Mesh, material: Material) -> void:
	target.clear_surfaces()
	if used <= 0:
		return
	var vertices := PoolVector3Array()
	var normals := PoolVector3Array()
	var uv2 := PoolVector2Array()
	var colors := PoolColorArray()
	for i in range(start, start + used):
		var blob: Array = blobs[i]
		vertices.append_array(blob[0])
		normals.append_array(blob[1])
		uv2.append_array(blob[2])
		colors.append_array(blob[3])
	var indices: PoolIntArray = _chunk_indices(template_mesh)
	indices.resize(used * _template(template_mesh).indices.size())  # A copy, cut to the blobs in use
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], 0)  # Uncompressed: UV2 holds hit times
	target.surface_set_material(0, material)


# Triangle indices for a full chunk of `template_mesh` blobs, one after another. Cached.
static func _chunk_indices(template_mesh: Mesh) -> PoolIntArray:
	if _INDEX_CACHE.has(template_mesh.resource_path):
		return _INDEX_CACHE[template_mesh.resource_path]
	var template: Dictionary = _template(template_mesh)
	var stride: int = template.vertices.size()
	var indices := PoolIntArray()
	for i in range(Constants.HULL_SCAR_CHUNK_BLOBS):
		var base: int = i * stride
		for index in template.indices:
			indices.append(base + index)
	_INDEX_CACHE[template_mesh.resource_path] = indices
	return indices


# A template's vertices, normals and indices (a unit-wide sphere).
static func _template(template_mesh: Mesh) -> Dictionary:
	if not _TEMPLATES.has(template_mesh.resource_path):
		var arrays: Array = template_mesh.get_mesh_arrays()
		_TEMPLATES[template_mesh.resource_path] = {
			"vertices": arrays[Mesh.ARRAY_VERTEX],
			"normals": arrays[Mesh.ARRAY_NORMAL],
			"indices": arrays[Mesh.ARRAY_INDEX],
		}
	return _TEMPLATES[template_mesh.resource_path]


# One blob's vertex arrays [vertices, normals, uv2, colors] in this node's space: `template_mesh`
# placed by `placed`, its dome lumped by `lump` (share of its size) from the seed in `data`
# (Color(hit time, seed, facing, size)).
static func _blob_arrays(template_mesh: Mesh, placed: Transform, data: Color, lump: float) -> Array:
	var template: Dictionary = _template(template_mesh)
	var normal_basis: Basis = placed.basis.inverse().transposed()  # Normals under a stretched basis
	var seed: float = data.g * 100.0
	var vertices := PoolVector3Array()
	var normals := PoolVector3Array()
	var uv2 := PoolVector2Array()
	var colors := PoolColorArray()
	var count: int = template.vertices.size()
	vertices.resize(count)
	normals.resize(count)
	uv2.resize(count)
	colors.resize(count)
	var time_seed := Vector2(data.r, data.g)
	var facing := Color(data.b, 0.0, 0.0, 1.0)
	for k in range(count):
		var point: Vector3 = template.vertices[k]
		var normal: Vector3 = template.normals[k]
		var bump: float = sin(point.x * 9.0 + seed) * sin(point.z * 7.0 + seed * 1.7) * sin(point.y * 5.0 + seed * 2.3)
		vertices[k] = placed.xform(point + normal * bump * lump)
		normals[k] = normal_basis.xform(normal).normalized()
		uv2[k] = time_seed
		colors[k] = facing
	return [vertices, normals, uv2, colors]


func get_scar_count() -> int:
	return _count


func get_slag_count() -> int:
	return _slag_count


# Slag blob `index`'s placement in this node's space.
func get_slag_transform(index: int) -> Transform:
	return _slag_placed[index]


# The scar slot slag blob `index` sits on.
func get_slag_scar(index: int) -> int:
	return _slag_scar[index]


func get_scar_capacity() -> int:
	return _capacity


# Slag blobs this ship carries at no hull left (Constants.HULL_SLAG_MAX, scaled by its size).
func get_slag_capacity() -> int:
	return _slag_capacity


# Vertices of the scars and slag in use (what the chunk meshes hold once rebuilt).
func get_vertex_count() -> int:
	return _count * _template(ScarMesh).vertices.size() + _slag_count * _template(SlagMesh).vertices.size()


# Chunk meshes with something to draw: the ship's draw calls for scars and slag.
func get_draw_count() -> int:
	var count := 0
	for node in _chunks + _slag_chunks:
		if node != null and node.mesh.get_surface_count() > 0:
			count += 1
	return count


# Shows `count` slag blobs: at most get_slag_capacity() and Constants.HULL_SLAG_PER_SCAR per scar,
# each Constants.HULL_SLAG_SIZE_SHARE of its scar's size, up to HULL_SLAG_MAX_SIZE. New ones go on
# the scars with the fewest, newest first, and start hot.
func set_slag_count(count: int) -> void:
	count = int(clamp(count, 0, min(_slag_capacity, _count * Constants.HULL_SLAG_PER_SCAR)))
	if count == _slag_count:
		return
	var now: float = clock()
	for k in range(count, _slag_count):  # Fewer: their chunks lose them
		_slag_dirty[k / Constants.HULL_SCAR_CHUNK_BLOBS] = true
	_slag_count = int(min(_slag_count, count))
	while _slag_count < count:
		_slag_scar[_slag_count] = _scar_with_fewest_slag()
		_slag_jitter[_slag_count] = Vector2(rand_range(-0.15, 0.15), rand_range(-0.15, 0.15))
		_slag_data[_slag_count] = Color(now, randf(), 1.0, 0.0)
		_slag_count += 1
		_seat_slag(_slag_count - 1)
	if _slag_count > 0:
		SlagMaterial.set_shader_param("now", now)
		set_process(true)
	else:
		flush()


# The used scar slot with the fewest slag blobs; of those, the newest.
func _scar_with_fewest_slag() -> int:
	var on: Array = []
	on.resize(_capacity)
	for i in range(_capacity):
		on[i] = 0
	for k in range(_slag_count):
		on[_slag_scar[k]] += 1
	var best: int = -1
	for age in range(_count):
		var slot: int = posmod(_next - 1 - age, _capacity)  # Newest first
		if best < 0 or on[slot] < on[best]:
			best = slot
	return best


# Places slag blob `index` on its scar's dome, as the scar is now.
func _seat_slag(index: int) -> void:
	var scar: int = _slag_scar[index]
	var placed: Transform = _placed[scar]
	var scar_size: float = _data[scar].a
	var share: float = min(Constants.HULL_SLAG_SIZE_SHARE, Constants.HULL_SLAG_MAX_SIZE / max(scar_size, 0.001))
	var jitter: Vector2 = _slag_jitter[index]
	var offset: Vector3 = placed.basis.x * jitter.x + placed.basis.z * jitter.y
	offset += placed.basis.y * (0.5 - 0.25 * share)  # Up on its scar's dome (the mesh is 1 unit across), half sunk in it
	var data: Color = _slag_data[index]
	data.a = scar_size * share
	_slag_data[index] = data
	_slag_placed[index] = Transform(Basis(placed.basis.x * share, placed.basis.y * share, placed.basis.z * share), placed.origin + offset)
	_slag_blobs[index] = null
	_slag_dirty[index / Constants.HULL_SCAR_CHUNK_BLOBS] = true


# Moves the slag on scar slot `scar` with it (it was replaced or grew).
func _reseat_slag_on(scar: int) -> void:
	for k in range(_slag_count):
		if _slag_scar[k] == scar:
			_seat_slag(k)


# Scar `index`'s placement in this node's space.
func get_scar_transform(index: int) -> Transform:
	return _placed[index]


# Scar `index`'s data: hit time, seed, facing, size (m).
func get_scar_data(index: int) -> Color:
	return _data[index]


# A scar where a shot along `shot_dir` hit the plating at `hit_pos` (world), with the plating's
# `hit_normal` there. A hit close to a scar reheats and grows it instead. `surface` is the hit
# surface that was hit: two short rays check the scar's ends against it, and a scar that would
# hang over an edge shrinks to a small round one. Returns the scar's index.
func add_scar(hit_pos: Vector3, hit_normal: Vector3, shot_dir: Vector3, damage: float, surface: CollisionObject = null) -> int:
	var now: float = clock()
	shot_dir = shot_dir.normalized()
	var size: float = size_for_damage(damage)
	var to_local: Transform = global_transform.affine_inverse()
	var local_hit: Vector3 = to_local.xform(hit_pos)
	var to_world_scale: float = global_transform.basis.get_scale().x  # Local units -> m (uniform scale)
	for i in range(_count):
		var data: Color = _data[i]
		var scar_pos: Vector3 = _placed[i].origin
		if scar_pos.distance_to(local_hit) * to_world_scale <= data.a * Constants.HULL_SCAR_MERGE_SHARE:
			_reheat(i, data, now)
			return i
	var facing: float = clamp(abs(hit_normal.normalized().dot(shot_dir.normalized())), 0.0, 1.0)
	var stretch: float = stretch_for(hit_normal, shot_dir)
	if surface != null and not _fits(hit_pos, hit_normal, shot_dir, size * stretch, surface):
		size *= 0.5
		shot_dir = -hit_normal  # Round: as if head-on
		stretch = 1.0
	var twist: float = rand_range(-PI, PI) if stretch < Constants.HULL_SCAR_ROUND_STRETCH else rand_range(-0.25, 0.25)
	var placed: Transform = to_local * scar_transform(hit_pos, hit_normal, shot_dir, size, twist)
	var index: int = _push(placed, Color(now, randf(), facing, size))
	_warm(now)
	return index


# Puts a scar in the next instance (the oldest gives way when all are in use); returns its index.
func _push(placed: Transform, data: Color) -> int:
	var index: int = _next
	_count = int(min(_count + 1, _capacity))
	_put(index, placed, data)
	_next = (_next + 1) % _capacity
	return index


func _put(index: int, placed: Transform, data: Color) -> void:
	_placed[index] = placed
	_data[index] = data
	_blobs[index] = null
	_dirty[index / Constants.HULL_SCAR_CHUNK_BLOBS] = true
	_reseat_slag_on(index)


# Both ends of a scar `length` long along the beam land on `surface` within the scar's own height
# of the hit: it does not hang over an edge or a hollow.
func _fits(hit_pos: Vector3, hit_normal: Vector3, shot_dir: Vector3, length: float, surface: CollisionObject) -> bool:
	var n: Vector3 = hit_normal.normalized()
	if n.dot(shot_dir) > 0.0:
		n = -n
	var along: Vector3 = shot_dir - n * shot_dir.dot(n)
	if along.length_squared() < 0.0001:
		along = n.cross(Vector3.UP if abs(n.y) < 0.9 else Vector3.RIGHT)
	var reach: Vector3 = along.normalized() * length * 0.5
	var depth: float = max(length * 0.5, 0.5)
	var space: PhysicsDirectSpaceState = surface.get_world().direct_space_state
	for end in [hit_pos + reach, hit_pos - reach]:
		var hit: Dictionary = space.intersect_ray(end + n * depth, end - n * depth, [], Constants.HIT_SURFACE_LAYER)
		if hit.empty() or hit.collider != surface:
			return false
	return true


func _reheat(index: int, data: Color, now: float) -> void:
	var growth: float = min(Constants.HULL_SCAR_REHEAT_GROWTH, Constants.HULL_SCAR_MAX_SIZE / max(data.a, 0.001))
	var placed: Transform = _placed[index]
	if growth > 1.0:
		placed.basis = Basis(placed.basis.x * growth, placed.basis.y * growth, placed.basis.z * growth)
		data.a *= growth
	data.r = now
	_put(index, placed, data)
	_warm(now)


func _warm(now: float) -> void:
	_hot_until = now + Constants.HULL_SCAR_COOL_TIME
	ScarMaterial.set_shader_param("now", now)
	_timer = 0.0
	set_process(true)


func clear_scars() -> void:
	for chunk in range(_chunks.size()):
		_dirty[chunk] = true
	for chunk in range(_slag_chunks.size()):
		_slag_dirty[chunk] = true
	_count = 0
	_next = 0
	_slag_count = 0
	flush()
	set_process(false)


# The scars, oldest first, for the save: per scar the 12 numbers of its transform (basis x, y, z
# columns, then origin; in this node's space) and its seed, facing and size.
func export_scars() -> Array:
	var out: Array = []
	var first: int = _next if _count == _capacity else 0
	for k in range(_count):
		var i: int = (first + k) % _capacity
		var placed: Transform = _placed[i]
		var data: Color = _data[i]
		var b: Basis = placed.basis
		out.append([
			b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z,
			placed.origin.x, placed.origin.y, placed.origin.z,
			data.g, data.b, data.a,
		])
	return out


# Restores export_scars() output, cold. Malformed entries are skipped; beyond the cap the newest stay.
func import_scars(scars: Array) -> void:
	clear_scars()
	var cold: float = clock() - Constants.HULL_SCAR_COOL_TIME * 10.0
	var start: int = int(max(scars.size() - _capacity, 0))
	for k in range(start, scars.size()):
		var v = scars[k]
		if not v is Array or v.size() != 15:
			continue
		var basis := Basis(Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]), Vector3(v[6], v[7], v[8]))
		_push(Transform(basis, Vector3(v[9], v[10], v[11])), Color(cold, float(v[12]), float(v[13]), float(v[14])))
	flush()
	set_process(_count > 0)
