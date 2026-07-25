# PROJECT: GDTLancer
# MODULE: test_tight_beam_system.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md
# LOG_REF: 2026-07-26 02:10:00

extends "res://addons/gut/test.gd"

const TightBeamSystemClass = preload("res://src/core/systems/tight_beam_system.gd")

var tight_beam: TightBeamSystem

func before_each():
	tight_beam = TightBeamSystemClass.new()

func after_each():
	if tight_beam != null:
		tight_beam.free()
		tight_beam = null

func test_send_and_delayed_delivery():
	var msg_id = tight_beam.send_message("npc_corvus", "Status Update", "Station power restored.", 2, {}, 0)
	assert_ne(msg_id, "")
	assert_eq(tight_beam.get_inbox().size(), 0)
	
	# Advance 1 tick -> not delivered yet
	var delivered_tick1 = tight_beam.process_tick(1)
	assert_eq(delivered_tick1.size(), 0)
	assert_eq(tight_beam.get_inbox().size(), 0)
	
	# Advance to tick 2 -> delivered!
	var delivered_tick2 = tight_beam.process_tick(2)
	assert_eq(delivered_tick2.size(), 1)
	assert_eq(tight_beam.get_inbox().size(), 1)
	assert_eq(tight_beam.get_inbox()[0]["subject"], "Status Update")

func test_mark_read():
	var msg_id = tight_beam.send_message("npc_corvus", "Urgent Call", "Need assistance.", 1, {}, 0)
	tight_beam.process_tick(1)
	
	assert_false(tight_beam.get_inbox()[0]["read"])
	tight_beam.mark_read(msg_id)
	assert_true(tight_beam.get_inbox()[0]["read"])
