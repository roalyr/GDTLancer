# PROJECT: GDTLancer
# MODULE: test_agent_body.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

# tests/helpers/test_agent_body.gd
# A simple RigidBody for use in tests that require an agent.
# Version: 2.0 - Updated for RigidBody physics.
extends RigidBody


# The NavigationSystem's approach/orbit commands use this.
func get_interaction_radius():
	return 10.0