# HullScars: where hits landed on a ship's plating, a blob of molten hull glows white-orange, then
# cools over Constants.HULL_SCAR_COOL_TIME to a dark lump that stays until the hull is repaired.
# - One MultiMeshInstance per ship, under its visual root (it moves and stretches with the model):
#   every scar is an instance of one squashed sphere (hull_scar_mesh.tres), so a ship's scars are
#   one draw item, unshaded (no light passes). Up to Constants.HULL_SCAR_MAX_PER_SHIP; the oldest
#   gives way. Hidden beyond Constants.HULL_SCAR_VISIBLE_DISTANCE from the camera (checked every
#   Constants.LOD_CHECK_INTERVAL while the ship has scars; Godot 3's lod_max_distance does nothing).
# - Each scar's placement comes from the hit (scar_transform()): up along the plating's normal,
#   stretched along the beam on glancing hits, sunk part way in so the plating hides the rest.
# - Cooling runs in the shader (hull_scar.gdshader): each instance's custom data holds its hit
#   time, and every ship shares one material whose `now` is set while any scar is hot. Custom data:
#   x = hit time (clock()), y = random seed (lumps), z = facing (head-on hits glow hotter), w = size (m).
# - Needs hit points on the plating: add_scar() only for hits on a hit surface (CollisionHull), never
#   the convex hull (a scar there would float off the ship).
# - Slag (set_slag_count()): lasting damage. Small blobs on the newest scars that cool and flare up
#   again every few seconds, as if re-igniting: a second MultiMeshInstance with the same shader
#   (relight on, hull_slag_material.tres). Not saved: the count follows the hull lost.
# - export_scars() / import_scars() keep the player's scars in the save (cold).
# - Scars are kept in script arrays too, the MultiMesh only drawing them: nothing is read back from
#   the renderer (headless runs have none).

extends MultiMeshInstance

const ScarMesh = preload("res://assets/art/effects/hull_scar_mesh.tres")
const ScarMaterial = preload("res://assets/art/effects/hull_scar_material.tres")
const SlagMaterial = preload("res://assets/art/effects/hull_slag_material.tres")

var _next := 0  # Instance the next new scar takes (round robin)
var _count := 0  # Scars in use
var _placed: Array = []  # Per instance: its Transform in this node's space
var _data: Array = []  # Per instance: its custom data Color (hit time, seed, facing, size)
var _hot_until := 0.0  # clock() when the latest scar is cold
var _timer := 0.0  # s to the next camera distance check
var _slag: MultiMeshInstance = null
var _slag_count := 0


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


func _init() -> void:
	name = "HullScars"
	cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	material_override = ScarMaterial
	ScarMaterial.set_shader_param("cool_time", Constants.HULL_SCAR_COOL_TIME)
	var scars := MultiMesh.new()
	scars.transform_format = MultiMesh.TRANSFORM_3D  # Formats before the count
	scars.color_format = MultiMesh.COLOR_NONE
	scars.custom_data_format = MultiMesh.CUSTOM_DATA_FLOAT
	scars.instance_count = Constants.HULL_SCAR_MAX_PER_SHIP
	scars.visible_instance_count = 0
	scars.mesh = ScarMesh
	multimesh = scars
	_placed.resize(scars.instance_count)
	_data.resize(scars.instance_count)
	_slag = MultiMeshInstance.new()
	_slag.name = "Slag"
	_slag.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	_slag.material_override = SlagMaterial
	var slag := MultiMesh.new()
	slag.transform_format = MultiMesh.TRANSFORM_3D
	slag.color_format = MultiMesh.COLOR_NONE
	slag.custom_data_format = MultiMesh.CUSTOM_DATA_FLOAT
	slag.instance_count = Constants.HULL_SLAG_MAX
	slag.visible_instance_count = 0
	slag.mesh = ScarMesh
	_slag.multimesh = slag
	add_child(_slag)


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
		var camera = get_viewport().get_camera()
		visible = camera == null or camera.global_transform.origin.distance_to(global_transform.origin) <= Constants.HULL_SCAR_VISIBLE_DISTANCE


func get_scar_count() -> int:
	return _count


func get_slag_count() -> int:
	return _slag_count


# Slag blob `index`'s placement in this node's space.
func get_slag_transform(index: int) -> Transform:
	return _slag.multimesh.get_instance_transform(index)


# Shows `count` slag blobs (at most Constants.HULL_SLAG_MAX, and one per scar). New ones go on the
# newest scars without one, and start hot.
func set_slag_count(count: int) -> void:
	count = int(clamp(count, 0, min(Constants.HULL_SLAG_MAX, _count)))
	var now: float = clock()
	while _slag_count < count:
		var scar: int = posmod(_next - 1 - _slag_count, multimesh.instance_count)  # Newest first
		var placed: Transform = _placed[scar]
		var data: Color = _data[scar]
		var share: float = Constants.HULL_SLAG_SIZE_SHARE
		var offset: Vector3 = placed.basis.x * rand_range(-0.15, 0.15) + placed.basis.z * rand_range(-0.15, 0.15)
		offset += placed.basis.y * (0.5 - 0.25 * share)  # Up on its scar's dome (the mesh is 1 unit across), half sunk in it
		var basis := Basis(placed.basis.x * share, placed.basis.y * share, placed.basis.z * share)
		_slag.multimesh.set_instance_transform(_slag_count, Transform(basis, placed.origin + offset))
		_slag.multimesh.set_instance_custom_data(_slag_count, Color(now, randf(), 1.0, data.a * share))
		_slag_count += 1
	_slag_count = count
	_slag.multimesh.visible_instance_count = _slag_count
	if _slag_count > 0:
		SlagMaterial.set_shader_param("now", now)
		set_process(true)


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
	_put(index, placed, data)
	_next = (_next + 1) % multimesh.instance_count
	_count = int(min(_count + 1, multimesh.instance_count))
	multimesh.visible_instance_count = _count
	return index


func _put(index: int, placed: Transform, data: Color) -> void:
	_placed[index] = placed
	_data[index] = data
	multimesh.set_instance_transform(index, placed)
	multimesh.set_instance_custom_data(index, data)


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
	_count = 0
	_next = 0
	multimesh.visible_instance_count = 0
	_slag_count = 0
	_slag.multimesh.visible_instance_count = 0
	set_process(false)


# The scars, oldest first, for the save: per scar the 12 numbers of its transform (basis x, y, z
# columns, then origin; in this node's space) and its seed, facing and size.
func export_scars() -> Array:
	var out: Array = []
	var first: int = _next if _count == multimesh.instance_count else 0
	for k in range(_count):
		var i: int = (first + k) % multimesh.instance_count
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
	var start: int = int(max(scars.size() - multimesh.instance_count, 0))
	for k in range(start, scars.size()):
		var v = scars[k]
		if not v is Array or v.size() != 15:
			continue
		var basis := Basis(Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]), Vector3(v[6], v[7], v[8]))
		_push(Transform(basis, Vector3(v[9], v[10], v[11])), Color(cold, float(v[12]), float(v[13]), float(v[14])))
	set_process(_count > 0)
