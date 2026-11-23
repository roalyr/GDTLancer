# Tests for Constants.

extends GutTest


func test_core_scene_paths_exist():
	# Check if the constants point to *something* - doesn't guarantee validity yet
	assert_ne(Constants.NPC_AGENT_SCENE_PATH, "", "NPC Agent Scene Path should not be empty")
	assert_ne(Constants.PLAYER_AGENT_SCENE_PATH, "", "Player Agent Scene Path should not be empty")
	prints("Tested Core Scene Paths Existence (basic check)")


func test_core_node_names_exist():
	assert_ne(Constants.AGENT_CONTAINER_NAME, "", "Agent Container Name check")
	assert_ne(Constants.AGENT_BODY_NODE_NAME, "", "Agent Body Node Name check")
	prints("Tested Core Node Names Existence")


func test_jump_travel_duration_is_symmetric_by_sector_type():
	assert_eq(Constants.get_jump_travel_duration("system", "system"), Constants.JUMP_DURATION_SYSTEM_SYSTEM)
	assert_eq(Constants.get_jump_travel_duration("system", "deep_space"), Constants.JUMP_DURATION_ANY_DEEP_SPACE)
	assert_eq(Constants.get_jump_travel_duration("deep_space", "system"), Constants.JUMP_DURATION_ANY_DEEP_SPACE)


# Tools run as SceneTree scripts (godot -s: evolution_sim, classify_presets) preload Constants.gd
# before any autoload exists. Code in it that names another autoload (Strings.t, Settings...) makes
# that preload pull the autoloads in by their scripts, round to Constants again: a cyclic load, and
# the tool does not compile (evolution_sim did not run from 2026-11-21 to 11-23). Comments may name them.
func test_constants_code_names_no_other_autoload():
	var file := File.new()
	assert_eq(file.open("res://src/autoload/Constants.gd", File.READ), OK)
	var config := ConfigFile.new()
	assert_eq(config.load("res://project.godot"), OK)
	var autoloads: Array = config.get_section_keys("autoload")
	var found := []
	var line_number := 0
	while not file.eof_reached():
		var line: String = file.get_line()
		line_number += 1
		var code: String = line.split("#")[0]
		for name in autoloads:
			if name != "Constants":
				var pattern := RegEx.new()
				pattern.compile("\\b%s\\." % name)
				if pattern.search(code) != null:
					found.append("%d: %s" % [line_number, line.strip_edges()])
	file.close()
	assert_eq(found, [], "Constants.gd names no autoload in its code")
