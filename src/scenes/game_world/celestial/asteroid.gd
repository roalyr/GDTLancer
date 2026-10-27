# Asteroid: a hand-placed rock. Static, solid (blocks ships and laser fire), shows hits, and is an obstacle the autopilot steers around. Pick its look with `model` (a rock mesh from
# assets/models/rocks/), size it with the node's uniform scale. The rock material is applied here,
# since the rock meshes come without one.
# Mining (Constants MINING): it holds a deposit (`deposit_id`, units by size unless `deposit` is set).
# Laser hits burn its shell off; bared, it glows, and an armed lance struck into it breaks out an
# OreChunk (break_chunk); the shell then closes again.

extends StaticBody

const MeshLod = preload("res://src/core/agents/components/mesh_lod.gd")
const ViewDetail = preload("res://src/core/agents/components/view_detail.gd")
const CollisionHull = preload("res://src/core/agents/components/collision_hull.gd")
const RockDustScene = preload("res://scenes/prefabs/effects/rock_dust.tscn")
const RockDustEffect = preload("res://src/core/agents/effects/rock_dust_effect.gd")
const RockMaterial = preload("res://assets/art/materials_generic/mat_asteroid_rock.tres")
const OreChunk = preload("res://src/scenes/game_world/celestial/ore_chunk.gd")

export var model: PackedScene = null  # Rock mesh scene; the prefab's default is used if unset
export var stretch: Vector3 = Vector3.ONE  # Per-axis model stretch, for a non-spherical rock
export var deposit_id: String = Constants.MINING_DEPOSIT
export var deposit: int = -1  # Units; negative: by size (MINING_ORE_PER_METRE)

var shell: float = Constants.MINING_SHELL_HP  # Laser damage left before it is bared
var _exposed_left: float = 0.0  # s it stays bared
var _exposed_material: Material = null

var hull_bounds: AABB = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
var _radius := -1.0  # get_apparent_radius() cache, for _radius_basis
var _radius_basis := Basis()

onready var _model: Spatial = $Model
onready var _collision: CollisionShape = $CollisionShape


func _ready() -> void:
	add_to_group("asteroid")
	add_to_group("obstacle")
	if model != null:
		for child in _model.get_children():
			_model.remove_child(child)
			child.queue_free()
		_model.add_child(model.instance())
	_model.scale = stretch
	hull_bounds = _measure_model_bounds()
	for node in _all_nodes(_model):
		if node is MeshInstance:
			node.material_override = RockMaterial
	# Collision follows the rock's outline (convex hull of its lowest level of detail, stretch baked
	# in), so ships and shots touch rock, not air. Failing that, a sphere that fits inside the rock.
	var hull_shape = CollisionHull.shape_for(_model, _model.transform)
	if hull_shape != null:
		_collision.shape = hull_shape
		_collision.transform = Transform.IDENTITY
	else:
		var collision_radius: float = min(hull_bounds.size.x, min(hull_bounds.size.y, hull_bounds.size.z)) * 0.45
		_collision.transform = Transform(Basis().scaled(Vector3.ONE * collision_radius), hull_bounds.position + hull_bounds.size * 0.5)
	MeshLod.attach(_model, ViewDetail.attach(self, get_apparent_radius()), Constants.LOD_LEVEL_BY_BAND_DENSE)
	add_to_group("mineable")
	set_physics_process(false)


func get_deposit() -> int:
	if deposit < 0:
		deposit = int(round(get_apparent_radius() * Constants.MINING_ORE_PER_METRE))
	return deposit


func is_exposed() -> bool:
	return shell <= 0.0 and get_deposit() > 0


# Laser damage on the shell; bared at 0, for MINING_EXPOSED_TIME.
func cut(damage: float) -> void:
	if damage <= 0.0 or get_deposit() <= 0 or is_exposed():
		return
	shell = max(0.0, shell - damage)
	if shell <= 0.0:
		_exposed_left = Constants.MINING_EXPOSED_TIME
		_set_glow(true)
		set_physics_process(true)


func _physics_process(delta: float) -> void:
	_exposed_left -= delta
	if _exposed_left <= 0.0:
		_close_shell()


func _close_shell() -> void:
	shell = Constants.MINING_SHELL_HP
	_set_glow(false)
	set_physics_process(false)


func _set_glow(on: bool) -> void:
	if on and _exposed_material == null:
		_exposed_material = RockMaterial.duplicate()
		_exposed_material.set_shader_param("emission", Constants.MINING_EXPOSED_COLOR)
		_exposed_material.set_shader_param("emission_strength", 0.6)
	for node in _all_nodes(_model):
		if node is MeshInstance:
			node.material_override = _exposed_material if on else RockMaterial


# A lance went in at `point`, along `axis`, for `damage`: breaks out a chunk of the deposit (see
# Constants MINING) drifting off the face, and closes the shell. Returns the chunk, or null.
func break_chunk(point: Vector3, axis: Vector3, damage: float) -> RigidBody:
	if not is_exposed() or not is_inside_tree():
		return null
	var units: int = int(clamp(round(damage / Constants.MINING_DAMAGE_PER_UNIT), 1, min(Constants.MINING_CHUNK_MAX, get_deposit())))
	deposit -= units
	_close_shell()
	var chunk = OreChunk.new()
	var models: Array = Constants.MINING_CHUNK_MODELS
	chunk.setup({deposit_id: units}, load(models[randi() % models.size()]), Constants.MINING_CHUNK_RADIUS * pow(float(units), 1.0 / 3.0))
	get_parent().add_child(chunk)
	var outward: Vector3 = (point - global_transform.origin).normalized()
	chunk.global_transform = Transform(Basis(), point + outward * chunk.get_apparent_radius() * 1.5)
	chunk.linear_velocity = outward * Constants.MINING_CHUNK_SPEED
	return chunk


func _measure_model_bounds() -> AABB:
	var bounds := AABB()
	var found := false
	var to_body: Transform = global_transform.affine_inverse()
	for node in _all_nodes(_model):
		if node is GeometryInstance:
			var box: AABB = (to_body * node.global_transform).xform(node.get_aabb())
			bounds = box if not found else bounds.merge(box)
			found = true
	return bounds if found else AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)


static func _all_nodes(root: Node) -> Array:
	var out: Array = [root]
	for child in root.get_children():
		out += _all_nodes(child)
	return out


# World-space radius the autopilot keeps clear of.
func get_obstacle_radius() -> float:
	return get_apparent_radius()


# Detected like anything else (see Constants SIGNATURE block): by its size.
func get_signature() -> float:
	return get_apparent_radius() * Constants.SIG_PER_METRE_OF_SIZE


# Cached: rocks do not move, and ships and the HUD ask every frame. Worked out again if the rock's
# placement changes (it is scaled and placed after the model is in).
func get_apparent_radius() -> float:
	var basis: Basis = global_transform.basis
	if _radius < 0.0 or basis != _radius_basis:
		var size: Vector3 = hull_bounds.size * basis.get_scale()
		_radius = max(size.x, max(size.y, size.z)) * 0.5
		_radius_basis = basis
	return _radius


# A shot from `from_global` lands on the rock: raises a dust puff and returns the world point it
# hit. The shot line meets the rock's collision hull; failing that, the rock point facing the shooter.
func register_hit(from_global: Vector3, damage: float) -> Vector3:
	var aim: Vector3 = global_transform.xform(hull_bounds.position + hull_bounds.size * 0.5)
	var hit: Dictionary = CollisionHull.ray_onto(self, from_global, aim, get_apparent_radius() * 2.0)
	var point: Vector3 = hit.position if not hit.empty() else get_hull_point_facing(from_global)
	cut(damage)
	if damage > 0.0 and is_inside_tree() and RockDustEffect.is_wanted(get_tree(), get_viewport(), point):
		var dust = RockDustScene.instance()
		dust.outward = (from_global - point).normalized()
		add_child(dust)
		dust.global_transform = Transform(Basis(), point)  # Unscaled: rocks are scaled up a lot
	return point


func get_hull_point_facing(from_global: Vector3) -> Vector3:
	var to_rock: Vector3 = global_transform.origin - from_global
	return global_transform.origin - to_rock.normalized() * get_apparent_radius() * 0.8
