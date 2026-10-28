# Asteroid: a hand-placed rock. Static, solid (blocks ships and laser fire), shows hits, and is an obstacle the autopilot steers around. Pick its look with `model` (a rock mesh from
# assets/models/rocks/), size it with the node's uniform scale. The rock material is applied here,
# since the rock meshes come without one.
# Mining (Constants MINING): it holds a deposit (`deposit_id`, units by size unless `deposit` is set).
# A lance thrown into it breaks a few OreChunks off its face (break_chunks); lasers only chip it.

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
export var mineable: bool = true
export var surface: Material = null  # The rock material if unset
export var display_name: String = "Asteroid"


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
			node.material_override = _surface()
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
	if mineable:
		add_to_group("mineable")
	else:
		deposit = 0


func get_display_name() -> String:
	return display_name


func _surface() -> Material:
	return surface if surface != null else RockMaterial


func get_deposit() -> int:
	if deposit < 0:
		deposit = int(round(get_apparent_radius() * Constants.MINING_ORE_PER_METRE))
	return deposit


# A lance went in at `point`, along `axis`, for `damage`: breaks damage / MINING_DAMAGE_PER_UNIT
# units of the deposit (at most MINING_CHUNK_MAX, and what is left) off the face, in a piece per
# MINING_PIECE_UNITS (at most MINING_PIECES_MAX), drifting apart off the face. Returns the chunks,
# biggest first; none from a worked-out rock.
func break_chunks(point: Vector3, axis: Vector3, damage: float) -> Array:
	if get_deposit() <= 0 or not is_inside_tree():
		return []
	var units: int = int(clamp(round(damage / Constants.MINING_DAMAGE_PER_UNIT), 1, min(Constants.MINING_CHUNK_MAX, get_deposit())))
	deposit -= units
	var pieces: int = int(clamp(ceil(float(units) / Constants.MINING_PIECE_UNITS), 1, Constants.MINING_PIECES_MAX))
	var outward: Vector3 = (point - global_transform.origin).normalized()
	if outward.length_squared() < 0.5:
		outward = -axis.normalized()
	var side: Vector3 = outward.cross(Vector3.UP if abs(outward.y) < 0.9 else Vector3.RIGHT).normalized()
	var chunks: Array = []
	var models: Array = Constants.MINING_CHUNK_MODELS
	for index in range(pieces):
		var share: int = units / pieces + (1 if index < units % pieces else 0)  # Biggest first
		var chunk = OreChunk.new()
		chunk.setup({deposit_id: share}, load(models[randi() % models.size()]), Constants.MINING_CHUNK_RADIUS * pow(float(share), 1.0 / 3.0))
		get_parent().add_child(chunk)
		var heading: Vector3 = outward
		if pieces > 1:  # Fanned round the face
			heading = outward.rotated(side.rotated(outward, TAU * index / pieces), deg2rad(Constants.MINING_PIECE_SPREAD)).normalized()
		chunk.global_transform = Transform(Basis(), point + heading * chunk.get_apparent_radius() * 1.5)
		chunk.linear_velocity = heading * Constants.MINING_CHUNK_SPEED
		chunks.append(chunk)
	return chunks


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
	if damage > 0.0 and is_inside_tree() and RockDustEffect.is_wanted(get_tree(), get_viewport(), point):
		var dust = RockDustScene.instance()
		dust.outward = (from_global - point).normalized()
		add_child(dust)
		dust.global_transform = Transform(Basis(), point)  # Unscaled: rocks are scaled up a lot
	return point


func get_hull_point_facing(from_global: Vector3) -> Vector3:
	var to_rock: Vector3 = global_transform.origin - from_global
	return global_transform.origin - to_rock.normalized() * get_apparent_radius() * 0.8
