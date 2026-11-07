# NebulaCloud (scenes/prefabs/ambient/nebula_cloud.tscn): a local nebula, scenery only (put it
# under the sector's AmbientVisuals). `puffs` soft camera-facing glows (fx_nebula_puff.gdshader)
# scattered in a ball of `radius` m, each `puff_size` m across give or take half, in `tint`; the
# same `seed_value` lays them out the same. Built when it enters the tree (and in the editor when a
# field changes), so the scene keeps only the fields.

tool
extends Spatial

const PuffShader = preload("res://assets/art/shaders/fx_nebula_puff.gdshader")

export var radius: float = 20000.0 setget _set_radius  # m
export var puffs: int = 24 setget _set_puffs
export var puff_size: float = 16000.0 setget _set_puff_size  # m across
export var tint: Color = Color(0.35, 0.5, 0.9, 1.0) setget _set_tint
export var strength: float = 0.25 setget _set_strength  # How bright (it adds up where puffs overlap)
export var seed_value: int = 1 setget _set_seed


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		if child.name.begins_with("Puff"):
			remove_child(child)
			child.free()
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for index in range(puffs):
		var material := ShaderMaterial.new()
		material.shader = PuffShader
		material.set_shader_param("tint", tint)
		material.set_shader_param("strength", strength)
		material.set_shader_param("seed", random.randf() * 100.0)
		var puff := MeshInstance.new()
		puff.name = "Puff%d" % index
		puff.mesh = quad
		puff.material_override = material
		puff.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		var direction := Vector3(random.randf_range(-1, 1), random.randf_range(-1, 1) * 0.5, random.randf_range(-1, 1))
		puff.translation = direction.normalized() * radius * pow(random.randf(), 0.5) if direction.length_squared() > 0.0001 else Vector3.ZERO
		puff.scale = Vector3.ONE * puff_size * random.randf_range(0.5, 1.5)
		add_child(puff)


func _rebuild() -> void:
	if is_inside_tree():
		build()


func _set_radius(value: float) -> void:
	radius = value
	_rebuild()


func _set_puffs(value: int) -> void:
	puffs = int(max(0, value))
	_rebuild()


func _set_puff_size(value: float) -> void:
	puff_size = value
	_rebuild()


func _set_tint(value: Color) -> void:
	tint = value
	_rebuild()


func _set_strength(value: float) -> void:
	strength = value
	_rebuild()


func _set_seed(value: int) -> void:
	seed_value = value
	_rebuild()
