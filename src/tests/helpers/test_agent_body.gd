# tests/helpers/test_agent_body.gd
# A simple KinematicBody for use in tests that require an agent.
extends KinematicBody

var current_velocity = Vector3.ZERO


# The NavigationSystem's approach/orbit commands use this.
func get_interaction_radius():
	return 10.0
