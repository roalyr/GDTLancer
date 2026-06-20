# PROJECT: GDTLancer
# MODULE: test_player_controller_ship.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

extends "res://addons/gut/test.gd"

var PlayerControllerScript = load("res://src/modules/piloting/player_controller_ship.gd")

func before_each():
	GameState.reset_state()

func test_is_npc_tradeable():
	var controller = PlayerControllerScript.new()
	var dummy_target = Node.new()
	
	# Not in agent_body group
	assert_false(controller._is_npc_tradeable(dummy_target), "Not in agent_body group should fail")
	
	dummy_target.add_to_group("agent_body")
	dummy_target.name = "test_agent"
	
	# Agent not in GameState
	assert_false(controller._is_npc_tradeable(dummy_target), "Agent not in GameState should fail")
	
	# Add to GameState with wrong role
	GameState.agents["test_agent"] = {"agent_role": "pirate"}
	assert_false(controller._is_npc_tradeable(dummy_target), "Pirate role should fail")
	
	# Right roles
	GameState.agents["test_agent"]["agent_role"] = "trader"
	assert_true(controller._is_npc_tradeable(dummy_target), "Trader role should pass")
	
	GameState.agents["test_agent"]["agent_role"] = "hauler"
	assert_true(controller._is_npc_tradeable(dummy_target), "Hauler role should pass")
	
	GameState.agents["test_agent"]["agent_role"] = "prospector"
	assert_true(controller._is_npc_tradeable(dummy_target), "Prospector role should pass")
	
	dummy_target.free()
	controller.free()

class MockEventBus extends Node:
	var last_signal = ""
	var last_args = []
	func emit_signal(sig, arg1=null, arg2=null, arg3=null):
		last_signal = sig
		last_args = [arg1, arg2, arg3]

func test_interact_button_pressed_dispatches_npc_interaction():
	var controller = PlayerControllerScript.new()
	var mock_bus = MockEventBus.new()
	var _old_bus = EventBus
	
	# Swap EventBus with a mock logic manually or just use signals if we can catch them.
	# Let's just catch them using GUT's watch_signals if we can attach to EventBus.
	watch_signals(EventBus)
	
	var dummy_target = RigidBody.new()
	dummy_target.add_to_group("agent_body")
	dummy_target.name = "ada_agent"
	GameState.agents["ada_agent"] = {"agent_role": "trader"}
	
	# Set target
	controller._selected_target = dummy_target
	
	controller._on_interact_button_pressed()
	
	assert_signal_emitted_with_parameters(EventBus, "player_npc_interact_requested", ["ada_agent", dummy_target])
	
	dummy_target.free()
	controller.free()