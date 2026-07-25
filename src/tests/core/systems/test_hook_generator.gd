# PROJECT: GDTLancer
# MODULE: test_hook_generator.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 02:15:00

extends "res://addons/gut/test.gd"

const HookGeneratorClass = preload("res://src/core/systems/hook_generator.gd")

var hook_gen: HookGenerator

func before_each():
	GameState.reset_state()
	hook_gen = HookGeneratorClass.new()

func after_each():
	if hook_gen != null:
		hook_gen.free()
		hook_gen = null

func test_generates_resource_shortage_hook():
	GameState.set_sector_track("sector_star_elace", "resources", 2)
	
	var hooks = hook_gen.generate_hooks_for_sector("sector_star_elace")
	assert_true(hooks.size() > 0)
	
	var found = false
	for h in hooks:
		if h["type"] == "RESOURCE_SHORTAGE":
			found = true
			break
	assert_true(found)

func test_generates_surplus_hook_at_high_resources():
	GameState.set_sector_track("sector_star_elace", "resources", 9)
	
	var hooks = hook_gen.generate_hooks_for_sector("sector_star_elace")
	var found = false
	for h in hooks:
		if h["type"] == "RESOURCE_SURPLUS":
			found = true
			break
	assert_true(found)

func test_generates_tag_driven_anomaly_hook():
	GameState.add_sector_tag("sector_star_elace", "anomalous_unrest")
	
	var hooks = hook_gen.generate_hooks_for_sector("sector_star_elace")
	var found = false
	for h in hooks:
		if h["type"] == "ANOMALY_INVESTIGATION":
			found = true
			break
	assert_true(found)
