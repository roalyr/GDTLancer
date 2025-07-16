# File: modules/piloting/scripts/player_input_states/state_base.gd
# Base class for all player input states.

class_name InputState
extends Node

var _controller: Node # Reference to the main player_controller_ship.gd

func enter(controller: Node):
	"""Called when entering this state."""
	_controller = controller

func exit():
	"""Called when exiting this state."""
	pass

func handle_input(_event: InputEvent):
	"""Handles unhandled input events."""
	pass

func physics_update(_delta: float):
	"""Handles physics process logic for this state."""
	pass
