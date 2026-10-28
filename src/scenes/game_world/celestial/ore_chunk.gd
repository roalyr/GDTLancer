# OreChunk: a piece a lance broke out of a bared rock (Asteroid.break_chunk; Constants MINING). It
# drifts, holds its rock's deposit as salvage, and passes for a wreck: brackets show it, a harpoon tows
# and strips it (the lance stuck in it first, into a seat it fits), and salvagers look for it the same
# way (it is in the agent_body group with is_wreck set). Stripped, it is cleared away like a wreck.

extends RigidBody

const LanceController = preload("res://src/core/agents/components/lance_controller.gd")
const MeshLod = preload("res://src/core/agents/components/mesh_lod.gd")
const RockMaterial = preload("res://assets/art/materials_generic/mat_asteroid_rock.tres")

var is_wreck: bool = true
var is_docked: bool = false
var faction: String = ""
var salvage: Dictionary = {}  # Commodity id -> units left to strip
var wreck_time_ms: int = 0
var hull_bounds: AABB = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
var _radius: float = 1.0


# `model`: a rock mesh scene; `radius`: m.
func setup(units: Dictionary, model: PackedScene, radius: float) -> void:
	salvage = units.duplicate()
	_radius = max(radius, 1.0)
	name = "OreChunk"
	gravity_scale = 0.0
	can_sleep = false
	var unit_mass := 0.0
	for commodity_id in salvage:
		var commodity = TemplateDatabase.get_template(commodity_id)
		unit_mass += int(salvage[commodity_id]) * (float(commodity.unit_mass) if commodity is CommodityTemplate else 50.0)
	mass = Constants.MINING_CHUNK_BASE_MASS + unit_mass
	var shape := CollisionShape.new()
	var sphere := SphereShape.new()
	sphere.radius = _radius * 0.8
	shape.shape = sphere
	add_child(shape)
	var holder := Spatial.new()
	holder.name = "Model"
	add_child(holder)
	if model != null:
		holder.add_child(model.instance())
	var bounds := AABB()
	var found := false
	for node in _all_nodes(holder):
		if node is MeshInstance:
			node.material_override = RockMaterial
			if node.mesh != null:
				bounds = node.get_aabb() if not found else bounds.merge(node.get_aabb())
				found = true
	var model_radius: float = max(bounds.size.x, max(bounds.size.y, bounds.size.z)) * 0.5 if found else 1.0
	holder.scale = Vector3.ONE * _radius / max(model_radius, 0.001)
	hull_bounds = AABB(-Vector3.ONE * _radius, Vector3.ONE * _radius * 2.0)


func _ready() -> void:
	add_to_group("agent_body")
	add_to_group("wreck")
	add_to_group("ore_chunk")
	wreck_time_ms = OS.get_ticks_msec()


static func _all_nodes(root: Node) -> Array:
	var out: Array = [root]
	for child in root.get_children():
		out += _all_nodes(child)
	return out


func get_display_name() -> String:
	var units := 0
	for commodity_id in salvage:
		units += int(salvage[commodity_id])
	return "Ore chunk (%d)" % units


func is_player() -> bool:
	return false


func apply_damage(_amount: float, _source: Node = null) -> void:
	pass  # Rock: shots only chip it


func register_hit(from_global: Vector3, _damage: float, _aim_at = null) -> Vector3:
	return get_hull_point_facing(from_global)


func get_hull_point_facing(from_global: Vector3) -> Vector3:
	var to_chunk: Vector3 = global_transform.origin - from_global
	return global_transform.origin - to_chunk.normalized() * _radius * 0.8


func get_random_aim_point() -> Vector3:
	return global_transform.origin


func get_apparent_radius() -> float:
	return _radius


func get_hull_radius() -> float:
	return _radius


func get_signature() -> float:
	return max(Constants.SIG_MIN, _radius * Constants.SIG_PER_METRE_OF_SIZE)


func get_value() -> float:
	return 0.0


func get_salvage_units() -> int:
	var units := 0
	for commodity_id in salvage:
		units += int(salvage[commodity_id])
	return units


# Removes up to `units`, in name order; returns {id: units}.
func take_salvage(units: int) -> Dictionary:
	var taken := {}
	var ids: Array = salvage.keys()
	ids.sort()
	for commodity_id in ids:
		if units <= 0:
			break
		var amount: int = int(min(units, int(salvage[commodity_id])))
		if amount <= 0:
			continue
		taken[commodity_id] = amount
		units -= amount
		salvage[commodity_id] = int(salvage[commodity_id]) - amount
		if salvage[commodity_id] <= 0:
			salvage.erase(commodity_id)
	return taken


func recoverable_lances_for(salvager) -> int:
	return LanceController.recoverable_from(self, salvager)


func recover_lance_into(salvager) -> bool:
	return LanceController.recover_from(self, salvager)


func despawn() -> void:
	EventBus.emit_signal("agent_despawning", self)
	queue_free()
