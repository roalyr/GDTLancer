# tests/helpers/test_agent_body.gd
# A simple RigidBody for use in tests that require an agent.
# Version: 2.0 - Updated for RigidBody physics.
extends RigidBody


# The NavigationSystem's approach/orbit commands use this.
func get_interaction_radius():
	return 10.0
