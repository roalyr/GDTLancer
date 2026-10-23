# The shared shader blocks (assets/art/shaders/shader_common.glsl) and their copies in the shaders
# stay the same: run tools/sync_shader_blocks.py after editing a block.

extends GutTest

const SHADERS = "res://assets/art/shaders/"
const COMMON = SHADERS + "shader_common.glsl"


func _blocks(text: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("(?ms)^// @common (\\w+)\\n(.*?)^// @end\\n")
	var found := {}
	for m in re.search_all(text):
		found[m.get_string(1)] = m.get_string(2)
	return found


func _read(path: String) -> String:
	var file := File.new()
	assert_eq(file.open(path, File.READ), OK, path)
	var text := file.get_as_text()
	file.close()
	return text


func _shaders() -> Array:
	var paths: Array = []
	var dir := Directory.new()
	dir.open(SHADERS)
	dir.list_dir_begin(true, true)
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".gdshader"):
			paths.append(SHADERS + name)
		name = dir.get_next()
	paths.sort()
	return paths


func test_common_blocks_exist():
	var common := _blocks(_read(COMMON))
	for name in ["dither", "nlp", "billboard"]:
		assert_true(common.has(name), "shader_common.glsl has the %s block" % name)


func test_every_copy_matches_the_common_block():
	var common := _blocks(_read(COMMON))
	for path in _shaders():
		var copies := _blocks(_read(path))
		for name in copies:
			assert_true(common.has(name), "%s: a block named %s exists" % [path, name])
			if common.has(name):
				assert_eq(copies[name], common[name], "%s: its %s block is current (tools/sync_shader_blocks.py)" % [path, name])


func test_no_shader_keeps_its_own_copy_of_shared_code():
	var re := RegEx.new()
	re.compile("(?ms)^// @common (\\w+)\\n.*?^// @end\\n")
	for path in _shaders():
		var own: String = re.sub(_read(path), "", true)
		for helper in ["float bayer8x8(", "float dither_posterize(", "scale_factor = pow(", "uniform float scale_start"]:
			assert_false(helper in own, "%s: %s comes from a common block" % [path, helper])
