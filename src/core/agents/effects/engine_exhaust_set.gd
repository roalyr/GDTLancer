# EngineExhaustSet: drives a ship's engine exhausts (EngineExhaust children, from
# scenes/prefabs/effects/engine_exhaust.tscn) from its thrust, as the legacy project did: the
# plume stretches out behind the nozzle and widens up to a cap as thrust rises, and every
# exhaust shape brightens with it; an idle engine keeps a faint nozzle glow, a wreck none.
# A ship has a main nozzle facing each way (ShipModel.NOZZLE_DIRECTIONS): each exhaust burns by how
# much of the thrust pushes away from it (its own +Z is where its exhaust points; the ship's
# get_engine_thrust(), in ship space), so a ship flying sideways burns its side nozzles. Speed along
# that push makes the plume longer and slimmer (up to ENGINE_PLUME_SPEED_STRETCH at top speed). A
# burning plume is at least ENGINE_PLUME_BURN_LENGTH, whichever way it points: its length says the
# nozzle burns, its brightness how hard (thrust) and how fast it goes that way (fainter when slow,
# ENGINE_PLUME_STANDSTILL_ALPHA). A ship holding a pace sideways, on a little thrust, shows a side
# plume as long as a rear one would be, only fainter; never a flat one. Speed is a share of the
# cruise top speed (the afterburner out), so lighting one never shortens the plume; while it is lit
# the pushing exhausts stretch further (ENGINE_PLUME_AFTERBURNER_STRETCH) and burn brighter. A host without
# get_engine_thrust (a missile) pushes straight ahead at get_engine_activity().
# Sits on the ship scene's "Engines" node; exhausts facing the same way share one set of material
# copies (one per ship and direction), so ships and directions do not change each other's glow.
# Settings "engine_exhausts" off: a ship's exhausts are hidden and not worked out (a missile's stay:
# its plume is how an inbound one is seen).

extends Spatial
const FrameProfiler = preload("res://src/core/utils/frame_profiler.gd")

var _groups: Array = []  # [{"push": Vector3 (ship space), "exhausts": [Spatial], "materials": [ShaderMaterial], "thrust", "speed"}]
var _agent: Node = null


func _ready() -> void:
	var by_direction := {}
	for engine in get_children():
		if not engine is Spatial:
			continue
		var exhaust: Vector3 = (transform.basis * engine.transform.basis).z.normalized()
		var key: String = "%.2f,%.2f,%.2f" % [exhaust.x, exhaust.y, exhaust.z]
		if not by_direction.has(key):
			by_direction[key] = {"push": -exhaust, "exhausts": [], "materials": [], "copies": {}, "thrust": -2.0, "speed": -1.0, "boost": false}
			by_direction[key]["plume_materials"] = []
			_groups.append(by_direction[key])
		var group: Dictionary = by_direction[key]
		group.exhausts.append(engine)
		var plume_shapes = engine.get_node_or_null("PlumeShapes")
		for node in _all_nodes(engine):
			if node is MeshInstance and node.material_override is ShaderMaterial:
				if not group.copies.has(node.material_override):
					group.copies[node.material_override] = node.material_override.duplicate()
					var copy: ShaderMaterial = group.copies[node.material_override]
					if plume_shapes != null and plume_shapes.is_a_parent_of(node):
						group.plume_materials.append(copy)  # The plume's: faint at low speed
					else:
						group.materials.append(copy)  # The nozzle's
				node.material_override = group.copies[node.material_override]
	for group in _groups:
		group.erase("copies")
	_agent = _find_agent()
	for group in _groups:
		_apply(group, 0.0, 0.0, false)
	Settings.connect("changed", self, "_on_settings_changed")
	_show_setting()


func _on_settings_changed(key: String, _value) -> void:
	if key == "engine_exhausts":
		_show_setting()


# Shown and worked out, or (the option off, on a ship) neither.
func _show_setting() -> void:
	var shown: bool = Settings.get_option("engine_exhausts") or not (is_instance_valid(_agent) and _agent.has_method("get_engine_thrust"))
	visible = shown
	set_process(shown)
	if shown:
		for group in _groups:
			group.thrust = -2.0  # Redrawn at the next frame, whatever changed while hidden


# Timed as the profiler's "exhaust" section (FrameProfiler; free when none runs).
func _process(_delta: float) -> void:
	var tree: SceneTree = get_tree()
	FrameProfiler.begin(tree, "exhaust")
	_burn(_delta)
	FrameProfiler.end(tree, "exhaust")


func _burn(_delta: float) -> void:
	var thrust := Vector3.ZERO  # Ship space, length 0 idle .. 1 full burn
	var velocity := Vector3.ZERO  # Ship space, shares of top speed
	var dead := false
	var boost := false  # The afterburner lit
	if is_instance_valid(_agent):
		dead = bool(_agent.get("is_wreck"))
		var basis: Basis = _agent.global_transform.basis.orthonormalized()
		if _agent.has_method("get_engine_thrust"):
			thrust = _agent.get_engine_thrust()
		else:
			thrust = Vector3.FORWARD * _agent.get_engine_activity()
		var top: float = _agent.get_cruise_top_speed() if _agent.has_method("get_cruise_top_speed") else _agent.get_top_speed()
		velocity = basis.xform_inv(_agent.linear_velocity) / max(top, 1.0)
		boost = _agent.get("afterburner_lit") == true  # A missile has none: bool(null) would stop every frame here
	for group in _groups:
		var push: float = -1.0 if dead else max(0.0, thrust.dot(group.push))
		var speed: float = clamp(velocity.dot(group.push), 0.0, 1.0)
		if abs(push - group.thrust) > 0.005 or abs(speed - group.speed) > Constants.ENGINE_PLUME_SPEED_STEP or boost != group.boost:
			_apply(group, push, speed, boost)


# One direction's exhausts at `thrust` (0 idle .. 1 full burn; below 0 the engines are dead, a wreck)
# and `speed` (share of cruise top speed along their push); `boost`: the afterburner lit.
func _apply(group: Dictionary, thrust: float, speed: float, boost: bool) -> void:
	group.thrust = thrust
	group.speed = speed
	group.boost = boost
	var dead: bool = thrust < 0.0
	var t: float = clamp(thrust, 0.0, 1.0)
	var length: float = lerp(Constants.ENGINE_PLUME_BURN_LENGTH, Constants.ENGINE_PLUME_MAX_LENGTH, t) * (1.0 + Constants.ENGINE_PLUME_SPEED_STRETCH * speed)
	if boost:
		length *= 1.0 + Constants.ENGINE_PLUME_AFTERBURNER_STRETCH * t  # Only where it pushes
	var width: float = lerp(Constants.ENGINE_PLUME_MIN_WIDTH, Constants.ENGINE_PLUME_MAX_WIDTH, t) * (1.0 - Constants.ENGINE_PLUME_SPEED_SLIM * speed)
	for engine in group.exhausts:
		var plume = engine.get_node_or_null("PlumeShapes")
		if plume != null:
			plume.visible = not dead and t > 0.0
			plume.scale = Vector3(width, width, length)
		var nozzle = engine.get_node_or_null("NozzleShapes")
		if nozzle != null:
			nozzle.visible = not dead
	var glow: float = 0.0 if dead else lerp(Constants.ENGINE_GLOW_IDLE, 1.0, t * lerp(Constants.ENGINE_GLOW_STANDSTILL_SHARE, 1.0, speed))
	if boost:
		glow *= 1.0 + Constants.ENGINE_GLOW_AFTERBURNER_BOOST * t
	for material in group.materials:
		material.set_shader_param("intensity", glow)
	var plume_glow: float = 0.0 if dead else lerp(Constants.ENGINE_GLOW_IDLE, 1.0, t) * lerp(Constants.ENGINE_PLUME_STANDSTILL_ALPHA, 1.0, speed)  # By thrust; speed: how faint
	if boost:
		plume_glow *= 1.0 + Constants.ENGINE_GLOW_AFTERBURNER_BOOST * t
	for material in group.plume_materials:
		material.set_shader_param("intensity", plume_glow)


# The exhausts' groups by direction, for tests: [{"push": Vector3, "thrust": float, ...}].
func get_groups() -> Array:
	return _groups


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
