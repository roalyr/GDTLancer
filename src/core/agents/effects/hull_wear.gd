# HullWear: accumulated damage on a ship's paint. The hull materials (solid_dither_no_alpha_8x8)
# draw soot patches (their damage_texture, spread by their damage_noise) over more of the hull and
# darker the more hull is lost (their `damage`, 0..1); repairs take them away.
# - The hull materials are shared by every ship, so a ship gets its own copies the first time it is
#   damaged: every MeshInstance under its visual root, every level of detail. Undamaged ships keep
#   the shared ones (and the shader skips the patches at damage 0).
# - Not saved: it follows the hull lost (Agent._update_damage_trails()).

extends Reference

const WearShader = preload("res://assets/art/shaders/solid_dither_no_alpha_8x8.gdshader")

var damage := 0.0  # Hull lost, 0..1

var _root: Node = null
var _materials: Array = []  # The ship's own copies, once made
var _own := false


func _init(visual_root: Node) -> void:
	_root = visual_root


func set_damage(value: float) -> void:
	value = clamp(value, 0.0, 1.0)
	if value == damage:
		return
	damage = value
	if not _own:
		if damage <= 0.0 or not is_instance_valid(_root):
			return
		_make_own()
	for material in _materials:
		material.set_shader_param("damage", damage)


# The ship's own copies of its hull materials, in use (empty until it is first damaged).
func get_materials() -> Array:
	return _materials


func _make_own() -> void:
	_own = true
	var copies := {}  # Shared material -> this ship's copy
	var stack: Array = [_root]
	while not stack.empty():
		var node = stack.pop_back()
		stack += node.get_children()
		if not node is MeshInstance:
			continue
		if _wears(node.material_override):
			node.material_override = _copy(node.material_override, copies)
		for surface in range(node.get_surface_material_count()):
			var material: Material = node.get_surface_material(surface)
			if material == null and node.mesh != null:
				material = node.mesh.surface_get_material(surface)
			if _wears(material):
				node.set_surface_material(surface, _copy(material, copies))
	_materials = copies.values()


static func _wears(material: Material) -> bool:
	return material is ShaderMaterial and material.shader == WearShader


static func _copy(material: Material, copies: Dictionary) -> Material:
	if not copies.has(material):
		copies[material] = material.duplicate()
	return copies[material]
