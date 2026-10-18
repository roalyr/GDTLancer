# EngineExhaustSet: drives a ship's engine exhausts (EngineExhaust children, from
# scenes/prefabs/effects/engine_exhaust.tscn) from its thrust, as the legacy project did: the
# plume stretches out behind the nozzle and widens up to a cap as thrust rises, and every
# exhaust shape brightens with it; an idle engine keeps a faint nozzle glow, a wreck none.
# Sits on the ship scene's "Engines" node; the ship's engines share one set of material copies,
# so ships do not change each other's glow.

extends Spatial

var _materials: Dictionary = {}  # Original exhaust material -> this ship's copy
var _agent: Node = null
var _thrust := -1.0


func _ready() -> void:
	for engine in get_children():
		for node in _all_nodes(engine):
			if node is MeshInstance and node.material_override is ShaderMaterial:
				if not _materials.has(node.material_override):
					_materials[node.material_override] = node.material_override.duplicate()
				node.material_override = _materials[node.material_override]
	_agent = _find_agent()
	_apply(0.0)


func _process(_delta: float) -> void:
	var thrust: float = 0.0
	if is_instance_valid(_agent):
		thrust = -1.0 if _agent.get("is_wreck") else _agent.get_engine_activity()
	if abs(thrust - _thrust) > 0.005:
		_apply(thrust)


# `thrust`: 0 idle .. 1 full burn; below 0 the engines are dead (wreck).
func _apply(thrust: float) -> void:
	_thrust = thrust
	var dead: bool = thrust < 0.0
	var t: float = clamp(thrust, 0.0, 1.0)
	var length: float = lerp(Constants.ENGINE_PLUME_IDLE_LENGTH, Constants.ENGINE_PLUME_MAX_LENGTH, t)
	var width: float = lerp(Constants.ENGINE_PLUME_MIN_WIDTH, Constants.ENGINE_PLUME_MAX_WIDTH, t)
	for engine in get_children():
		var plume = engine.get_node_or_null("PlumeShapes")
		if plume != null:
			plume.visible = not dead and t > 0.0
			plume.scale = Vector3(width, width, length)
		var nozzle = engine.get_node_or_null("NozzleShapes")
		if nozzle != null:
			nozzle.visible = not dead
	var glow: float = 0.0 if dead else lerp(Constants.ENGINE_GLOW_IDLE, 1.0, t)
	for material in _materials.values():
		material.set_shader_param("intensity", glow)


func _find_agent() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("get_engine_activity"):
			return node
		node = node.get_parent()
	return null


static func _all_nodes(root: Node) -> Array:
	var out: Array = [root]
	for child in root.get_children():
		out += _all_nodes(child)
	return out
