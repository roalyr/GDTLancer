#
# PROJECT: GDTLancer
# MODULE: src/tests/core/systems/test_quirk_system.gd
# STATUS: [Level 3 - Verified]
# TRUTH_LINK: TACTICAL_TODO.md VERIFICATION
# LOG_REF: 2025-12-23
#

extends "res://addons/gut/test.gd"

const QuirkSystem = preload("res://src/core/systems/quirk_system.gd")

var _quirk_system: Node
var _test_ship_uid: int = 999

func before_each() -> void:
	_quirk_system = QuirkSystem.new()
	add_child_autofree(_quirk_system)
	_quirk_system._ready()
	
	# Setup mock ship in GameState
	var ship = ShipTemplate.new()
	ship.ship_quirks = []
	GameState.assets_ships[_test_ship_uid] = ship

func after_each() -> void:
	GameState.assets_ships.erase(_test_ship_uid)

func test_add_quirk_success() -> void:
	var quirk_id = "test_quirk"
	watch_signals(EventBus)
	
	var result = _quirk_system.add_quirk(_test_ship_uid, quirk_id)
	
	assert_true(result, "Should return true on successful add")
	assert_true(_quirk_system.has_quirk(_test_ship_uid, quirk_id), "Ship should have the quirk")
	assert_signal_emitted(EventBus, "ship_quirk_added", "Should emit ship_quirk_added signal")

func test_add_duplicate_quirk_fails() -> void:
	var quirk_id = "test_quirk"
	_quirk_system.add_quirk(_test_ship_uid, quirk_id)
	
	watch_signals(EventBus)
	var result = _quirk_system.add_quirk(_test_ship_uid, quirk_id)
	
	assert_false(result, "Should return false when adding duplicate quirk")
	assert_signal_not_emitted(EventBus, "ship_quirk_added", "Should not emit signal for duplicate")

func test_remove_quirk() -> void:
	var quirk_id = "test_quirk"
	_quirk_system.add_quirk(_test_ship_uid, quirk_id)
	
	watch_signals(EventBus)
	var result = _quirk_system.remove_quirk(_test_ship_uid, quirk_id)
	
	assert_true(result, "Should return true on successful removal")
	assert_false(_quirk_system.has_quirk(_test_ship_uid, quirk_id), "Ship should no longer have the quirk")
	assert_signal_emitted(EventBus, "ship_quirk_removed", "Should emit ship_quirk_removed signal")

func test_get_quirks_returns_copy() -> void:
	var quirk_id = "test_quirk"
	_quirk_system.add_quirk(_test_ship_uid, quirk_id)
	
	var quirks = _quirk_system.get_quirks(_test_ship_uid)
	quirks.append("malicious_addition")
	
	var actual_quirks = _quirk_system.get_quirks(_test_ship_uid)
	assert_eq(actual_quirks.size(), 1, "Original quirks array should not be modified by external changes to returned array")
	assert_false(actual_quirks.has("malicious_addition"), "Original quirks should not contain the malicious addition")

func test_has_quirk() -> void:
	var quirk_id = "test_quirk"
	assert_false(_quirk_system.has_quirk(_test_ship_uid, quirk_id), "Should return false if quirk not present")
	
	_quirk_system.add_quirk(_test_ship_uid, quirk_id)
	assert_true(_quirk_system.has_quirk(_test_ship_uid, quirk_id), "Should return true if quirk present")
