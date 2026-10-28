# LooseLance: a thrown lance that did not stay in a ship: one that glanced off or missed (drifting,
# slowing to a stop: Constants LANCE_LOOSE_DAMP), or one stuck in a rock it broke ore off (still).
# It passes for a wreck holding just the lance: brackets show it, a harpoon tows it and takes the
# lance back into a seat it fits (LanceController.recover_from), and salvagers short of lances look
# for it. It touches nothing (no collision): it is pulled out of a rock as easily as picked up.
# Recovered, it is gone; AgentSystem clears the oldest past Constants.LANCE_LOOSE_MAX.

extends RigidBody

const LANCE_CONTROLLER_PATH = "res://src/core/agents/components/lance_controller.gd"  # Loaded when used: it preloads this

var is_wreck: bool = true
var is_docked: bool = false
var faction: String = ""
var wreck_time_ms: int = 0
var hull_bounds: AABB = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
var _length: float = 10.0


# `mesh`: the lance (LanceController._lance_mesh), placed along `axis` with its middle at `centre`;
# `nail_mass`: kg, for the seats it fits.
func setup(mesh: MeshInstance, length: float, nail_mass: float, centre: Vector3, axis: Vector3, velocity: Vector3) -> void:
	name = "LooseLance"
	_length = max(length, 1.0)
	gravity_scale = 0.0
	can_sleep = false
	collision_layer = 0
	collision_mask = 0
	mass = max(nail_mass, 1.0)
	linear_damp = Constants.LANCE_LOOSE_DAMP
	angular_damp = Constants.LANCE_LOOSE_DAMP
	hull_bounds = AABB(-Vector3.ONE * _length * 0.5, Vector3.ONE * _length)
	var lances = load(LANCE_CONTROLLER_PATH)
	mesh.add_to_group(lances.LANCE_GROUP)
	mesh.set_meta("nail_mass", nail_mass)
	add_child(mesh)
	global_transform = Transform(lances._basis_along(axis), centre)
	linear_velocity = velocity


func _ready() -> void:
	add_to_group("agent_body")
	add_to_group("wreck")
	add_to_group("loose_lance")
	wreck_time_ms = OS.get_ticks_msec()


func get_display_name() -> String:
	return "Lance"


func is_player() -> bool:
	return false


func apply_damage(_amount: float, _source: Node = null) -> void:
	pass


func register_hit(from_global: Vector3, _damage: float, _aim_at = null) -> Vector3:
	return get_hull_point_facing(from_global)


func get_hull_point_facing(_from_global: Vector3) -> Vector3:
	return global_transform.origin


func get_random_aim_point() -> Vector3:
	return global_transform.origin


func get_apparent_radius() -> float:
	return _length * 0.5


func get_hull_radius() -> float:
	return _length * 0.5


func get_signature() -> float:
	return max(Constants.SIG_MIN, _length * Constants.SIG_PER_METRE_OF_SIZE)


func get_value() -> float:
	return 0.0


func get_salvage_units() -> int:
	return 0


func take_salvage(_units: int) -> Dictionary:
	return {}


func recoverable_lances_for(salvager) -> int:
	return load(LANCE_CONTROLLER_PATH).recoverable_from(self, salvager)


# Takes the lance back into `salvager`; the empty body goes.
func recover_lance_into(salvager) -> bool:
	if not load(LANCE_CONTROLLER_PATH).recover_from(self, salvager):
		return false
	call_deferred("despawn")
	return true


func despawn() -> void:
	if is_queued_for_deletion():
		return
	EventBus.emit_signal("agent_despawning", self)
	queue_free()
