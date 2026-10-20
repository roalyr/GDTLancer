# HullScorch: damage marks on a hull, kept as a few slots and drawn by the solid shaders.
# No mesh data is touched: each hit updates a handful of shader uniforms on the hull's own material
# copies, so marks cost the same on any mesh, show on every level of detail, and need no work while
# the hull is off screen.
# - Scars (char), up to Constants.SCORCH_MAX_SCARS: a stretch of the shot line (where it met the
#   collision hull, its direction, a radius and a strength). The shader chars surfaces within the
#   radius of that line, a little in front of the point and up to SCORCH_SCAR_REACH_BACK behind it,
#   that face the shot. So the char lands on the visible plating even though the point comes from
#   the convex collision hull, and stretches on oblique faces as a real beam spot does. A hit near
#   an existing scar from about the same direction joins it (deeper, a bit wider); otherwise it takes
#   a free slot, or the weakest scar gives way and its share of the hull turns into wear.
# - Wear: blocky char patches over a share of the whole hull (old damage no slot can hold).
# - Heat, up to Constants.SCORCH_HEAT_SLOTS recent hits: a spot that glows and cools over
#   SCORCH_COOL_TIME against the ship's clock. Heat spreads in 3D from the point, so it reaches the
#   back of a thin plate and round edges. The clock is pushed to the materials only while something
#   is hot.
# Slots are kept in the visual root's space (they move with the ship and save with it) and turned
# into each mesh's own space when pushed: meshes are grouped by their placement under the root
# (lower levels of detail share their original's), and each group has its own material copies.
# Hulls that were never hit keep the shared materials, which skip all damage work in the shader.
# Where a shot lands is the caller's business: the collision hull (CollisionHull.ray_onto).

extends Node

var _root: Spatial = null
var _groups: Array = []  # {to_local, units, slots: [[instance, surface or -1, shown material, material to restore]], copies: {original: copy}}
var _scars: Array = []  # {point, direction, radius, strength}, root space
var _heats: Array = []  # {point, radius, time, heat}, root space
var _wear := 0.0
var _active := false  # Own material copies in place
var _clock := 0.0  # Seconds since setup; the shader's damage_time
var _root_scale := 1.0  # Metres per root-space unit
var _hull_area := 1.0  # Approximate hull surface, root units squared


# Collects the mesh surfaces under `visual_root` drawn with a marking shader, grouped by placement.
func setup(visual_root: Node) -> void:
	_root = visual_root
	_groups.clear()
	_scars.clear()
	_wear = 0.0
	_heats.clear()
	for _i in range(Constants.SCORCH_HEAT_SLOTS):
		_heats.append({"point": Vector3.ZERO, "radius": 1.0, "time": 0.0, "heat": 0.0})
	_active = false
	var global_scale: Vector3 = _root.global_transform.basis.get_scale() if _root.is_inside_tree() else _root.transform.basis.get_scale()
	_root_scale = max((global_scale.x + global_scale.y + global_scale.z) / 3.0, 0.0001)
	var bounds := AABB()
	var found := false
	var stack: Array = [visual_root]
	while not stack.empty():
		var node = stack.pop_back()
		stack += node.get_children()
		if not (node is MeshInstance and node.mesh is Mesh):
			continue
		var slots: Array = _marking_slots(node)
		if slots.empty():
			continue
		var to_root: Transform = _transform_to_root(node)
		var box: AABB = to_root.xform(node.get_aabb())
		bounds = box if not found else bounds.merge(box)
		found = true
		var group: Dictionary = _group_for(to_root)
		group.slots += slots
	_hull_area = max(2.0 * (bounds.size.x * bounds.size.y + bounds.size.y * bounds.size.z + bounds.size.x * bounds.size.z), 0.0001)
	set_process(false)


static func _shows_marks(material) -> bool:
	return material is ShaderMaterial and material.shader != null and "damage_mark_strength" in material.shader.code


# The surfaces of `instance` that show marks: [instance, surface (-1 = override), shown material,
# material to put back].
static func _marking_slots(instance: MeshInstance) -> Array:
	if instance.material_override != null:
		return [[instance, -1, instance.material_override, instance.material_override]] if _shows_marks(instance.material_override) else []
	var slots: Array = []
	for surface in range(instance.mesh.get_surface_count()):
		var own = instance.get_surface_material(surface) if surface < instance.get_surface_material_count() else null
		var shown = own if own != null else instance.mesh.surface_get_material(surface)
		if _shows_marks(shown):
			slots.append([instance, surface, shown, own])
	return slots


func _transform_to_root(node: Node) -> Transform:
	var to_root := Transform.IDENTITY
	while node != _root and node is Spatial:
		to_root = node.transform * to_root
		node = node.get_parent()
	return to_root


# The group of meshes placed as `to_root` (a lower level of detail shares its original's).
func _group_for(to_root: Transform) -> Dictionary:
	var to_local: Transform = to_root.affine_inverse()
	for group in _groups:
		if group.to_local.is_equal_approx(to_local):
			return group
	var scale: Vector3 = to_local.basis.get_scale()
	var group := {"to_local": to_local, "units": (scale.x + scale.y + scale.z) / 3.0, "slots": [], "copies": {}}
	_groups.append(group)
	return group


func is_paintable() -> bool:
	return not _groups.empty()


# A shot from `from_global` met the hull at `point_global` (on its collision hull, or the hull point
# facing the shooter): chars and heats there. Returns false if there is nothing to mark.
func add_hit(from_global: Vector3, point_global: Vector3, damage: float) -> bool:
	if damage <= 0.0 or _groups.empty():
		return false
	var to_root: Transform = _root.global_transform.affine_inverse()
	var point: Vector3 = to_root.xform(point_global)
	var direction: Vector3 = to_root.basis.xform(point_global - from_global).normalized()
	if direction == Vector3.ZERO:
		direction = -point.normalized() if point != Vector3.ZERO else Vector3.FORWARD
	var radius: float = Constants.SCORCH_RADIUS_PER_SQRT_DAMAGE * sqrt(damage) / _root_scale
	_activate()
	_add_scar(point, direction, radius)
	_add_heat(point, radius * Constants.SCORCH_HEAT_SPREAD, Constants.SCORCH_HEAT_PER_DAMAGE * damage)
	set_process(true)
	return true


# Joins a scar hit from about the same direction close by, or takes a slot (the weakest scar
# giving way into wear when all are taken).
func _add_scar(point: Vector3, direction: Vector3, radius: float) -> void:
	var max_radius: float = Constants.SCORCH_SCAR_MAX_RADIUS / _root_scale
	for index in range(_scars.size()):
		var scar: Dictionary = _scars[index]
		if scar.point.distance_to(point) < (scar.radius + radius) * Constants.SCORCH_SCAR_MERGE_DISTANCE and scar.direction.dot(direction) > Constants.SCORCH_SCAR_MERGE_DOT:
			var share: float = radius * radius / (scar.radius * scar.radius + radius * radius)
			scar.point = scar.point.linear_interpolate(point, share)
			scar.direction = scar.direction.linear_interpolate(direction, share).normalized()
			var grown: float = sqrt(scar.radius * scar.radius + radius * radius * Constants.SCORCH_SCAR_GROWTH)
			scar.radius = max(max(scar.radius, radius), min(grown, max_radius))
			scar.strength = 1.0 - (1.0 - scar.strength) * (1.0 - Constants.SCORCH_CENTRE_MARK)
			_push_scar(index)
			return
	var scar := {"point": point, "direction": direction, "radius": radius, "strength": Constants.SCORCH_CENTRE_MARK}
	if _scars.size() < Constants.SCORCH_MAX_SCARS:
		_scars.append(scar)
		_push_scar(_scars.size() - 1)
		return
	var weakest := 0
	for index in range(_scars.size()):
		if _scar_share(_scars[index]) < _scar_share(_scars[weakest]):
			weakest = index
	_wear = min(Constants.SCORCH_MAX_WEAR, _wear + _scar_share(_scars[weakest]))
	_scars[weakest] = scar
	_push_scar(weakest)
	_push_wear()


# Share of the hull a scar chars (strength times its disc over the hull's surface).
func _scar_share(scar: Dictionary) -> float:
	return scar.strength * PI * scar.radius * scar.radius / _hull_area


# Reheats a spot close by, or takes the coolest slot.
func _add_heat(point: Vector3, radius: float, gain: float) -> void:
	var slot := -1
	for index in range(_heats.size()):
		var spot: Dictionary = _heats[index]
		if spot.heat > 0.0 and spot.point.distance_to(point) < max(spot.radius, radius) * Constants.SCORCH_HEAT_MERGE:
			slot = index
			break
	var remaining := 0.0
	if slot >= 0:
		remaining = _heat_now(_heats[slot])
		point = _heats[slot].point.linear_interpolate(point, 0.5)
		radius = max(_heats[slot].radius, radius)
	else:
		slot = 0
		for index in range(_heats.size()):
			if _heat_now(_heats[index]) < _heat_now(_heats[slot]):
				slot = index
	_heats[slot] = {"point": point, "radius": radius, "time": _clock, "heat": min(Constants.SCORCH_MAX_HEAT, remaining + gain)}
	_push_heat(slot)


func _heat_now(spot: Dictionary) -> float:
	return spot.heat * exp(-max(_clock - spot.time, 0.0) / Constants.SCORCH_COOL_TIME)


# --- Materials ---

# Puts this hull's own material copies in place (once, on the first mark).
func _activate() -> void:
	if _active:
		return
	_active = true
	for group in _groups:
		for slot in group.slots:
			var original: ShaderMaterial = slot[2]
			if not group.copies.has(original):
				var copy: ShaderMaterial = original.duplicate()
				copy.set_shader_param("damage_active", 1.0)
				copy.set_shader_param("damage_cool_time", Constants.SCORCH_COOL_TIME)
				copy.set_shader_param("damage_glow_threshold", Constants.SCORCH_GLOW_THRESHOLD)
				copy.set_shader_param("damage_max_heat", Constants.SCORCH_MAX_HEAT)
				copy.set_shader_param("damage_scar_reach_front", Constants.SCORCH_SCAR_REACH_FRONT / _root_scale * group.units)
				copy.set_shader_param("damage_scar_reach_back", Constants.SCORCH_SCAR_REACH_BACK / _root_scale * group.units)
				copy.set_shader_param("damage_wear_cell", Constants.SCORCH_WEAR_CELL / _root_scale * group.units)
				copy.set_shader_param("damage_facing_min", Constants.SCORCH_FACING_MIN)
				group.copies[original] = copy
			_show(slot, group.copies[original])
	for index in range(Constants.SCORCH_MAX_SCARS):
		_push_scar(index)
	for index in range(_heats.size()):
		_push_heat(index)
	_push_wear()
	_push_clock()


# Back to the shared materials (a clean hull).
func _deactivate() -> void:
	if not _active:
		return
	_active = false
	for group in _groups:
		for slot in group.slots:
			if is_instance_valid(slot[0]):
				_show(slot, slot[3])
		group.copies.clear()


static func _show(slot: Array, material) -> void:
	if not is_instance_valid(slot[0]):
		return
	if slot[1] < 0:
		slot[0].material_override = material
	else:
		slot[0].set_surface_material(slot[1], material)


func _set_param(group: Dictionary, param: String, value) -> void:
	for copy in group.copies.values():
		copy.set_shader_param(param, value)


func _push_scar(index: int) -> void:
	if not _active:
		return
	for group in _groups:
		var spot := Plane(0.0, 0.0, 0.0, 1.0)
		var line := Plane(0.0, 0.0, 1.0, 0.0)  # Strength 0: unused slot
		if index < _scars.size():
			var scar: Dictionary = _scars[index]
			var point: Vector3 = group.to_local.xform(scar.point)
			var direction: Vector3 = group.to_local.basis.xform(scar.direction).normalized()
			spot = Plane(point.x, point.y, point.z, scar.radius * group.units)
			line = Plane(direction.x, direction.y, direction.z, scar.strength)
		_set_param(group, "damage_scar_%d" % index, spot)
		_set_param(group, "damage_scar_dir_%d" % index, line)


func _push_heat(index: int) -> void:
	if not _active:
		return
	var spot: Dictionary = _heats[index]
	for group in _groups:
		var point: Vector3 = group.to_local.xform(spot.point)
		_set_param(group, "damage_heat_%d" % index, Plane(point.x, point.y, point.z, max(spot.radius * group.units, 0.001)))
		_set_param(group, "damage_heat_time_%d" % index, Vector2(spot.time, spot.heat))


func _push_wear() -> void:
	if not _active:
		return
	for group in _groups:
		_set_param(group, "damage_wear", _wear)


func _push_clock() -> void:
	for group in _groups:
		_set_param(group, "damage_time", _clock)


func _process(delta: float) -> void:
	_clock += delta
	_push_clock()
	for spot in _heats:
		if _heat_now(spot) >= Constants.SCORCH_IDLE_HEAT:
			return
	# Cold everywhere: drop the spots so the stopped clock cannot leave a glow behind.
	for index in range(_heats.size()):
		if _heats[index].heat > 0.0:
			_heats[index].heat = 0.0
			_push_heat(index)
	set_process(false)


# --- What the shader shows, worked out the same way (tests, HUD) ---

# How charred the hull looks at a world point with this world normal (scars only, wear aside).
func get_char_at(point_global: Vector3, normal_global: Vector3) -> float:
	var to_root: Transform = _root.global_transform.affine_inverse()
	var point: Vector3 = to_root.xform(point_global)
	var normal: Vector3 = to_root.basis.xform(normal_global).normalized()
	var front: float = Constants.SCORCH_SCAR_REACH_FRONT / _root_scale
	var back: float = Constants.SCORCH_SCAR_REACH_BACK / _root_scale
	var clean := 1.0
	for scar in _scars:
		var relative: Vector3 = point - scar.point
		var along: float = relative.dot(scar.direction)
		if along < -front or along > back or normal.dot(scar.direction) > -Constants.SCORCH_FACING_MIN:
			continue
		var off_line: float = (relative - scar.direction * along).length()
		clean *= 1.0 - scar.strength * (1.0 - smoothstep(0.0, scar.radius, off_line))
	return 1.0 - clean


# Heat now at a world point (before the glow threshold).
func get_heat_at(point_global: Vector3) -> float:
	var point: Vector3 = _root.global_transform.affine_inverse().xform(point_global)
	var heat := 0.0
	for spot in _heats:
		heat += _heat_now(spot) * (1.0 - smoothstep(0.0, spot.radius, point.distance_to(spot.point)))
	return min(heat, Constants.SCORCH_MAX_HEAT)


# Share of the hull charred, 0 (clean) to 1: wear plus every scar's share.
func get_mark_level() -> float:
	var level: float = _wear
	for scar in _scars:
		level += _scar_share(scar)
	return min(level, 1.0)


func get_scar_count() -> int:
	return _scars.size()


func get_wear() -> float:
	return _wear


# --- Persistence (the player's hull keeps its marks across sectors and saves) ---

# {"scars": [[x, y, z, radius, dx, dy, dz, strength], ...], "wear": w} in root space. Heat is not
# kept: restored marks come back cooled.
func export_marks() -> Dictionary:
	var scars: Array = []
	for scar in _scars:
		scars.append([scar.point.x, scar.point.y, scar.point.z, scar.radius, scar.direction.x, scar.direction.y, scar.direction.z, scar.strength])
	return {"scars": scars, "wear": _wear} if not scars.empty() or _wear > 0.0 else {}


# Applies exported marks; anything else (saves from the old vertex-painted marks) is ignored.
func import_marks(marks: Dictionary) -> void:
	var scars = marks.get("scars")
	if not scars is Array or _groups.empty():
		return
	_scars.clear()
	for values in scars:
		if values is Array and values.size() == 8 and _scars.size() < Constants.SCORCH_MAX_SCARS:
			_scars.append({"point": Vector3(values[0], values[1], values[2]), "radius": float(values[3]),
				"direction": Vector3(values[4], values[5], values[6]).normalized(), "strength": clamp(float(values[7]), 0.0, 1.0)})
	_wear = clamp(float(marks.get("wear", 0.0)), 0.0, Constants.SCORCH_MAX_WEAR)
	if _scars.empty() and _wear <= 0.0:
		return
	if _active:
		for index in range(Constants.SCORCH_MAX_SCARS):
			_push_scar(index)
		_push_wear()
	else:
		_activate()


# Restores a clean hull (repairs): the shared materials come back.
func clear_marks() -> void:
	_scars.clear()
	_wear = 0.0
	for spot in _heats:
		spot.heat = 0.0
	_deactivate()
	set_process(false)
