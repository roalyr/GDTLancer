# tests/helpers/mock_agent_body.gd
# A minimal agent body for the spawner to instantiate in tests.
extends KinematicBody

var init_data = null

# We will spy on this method to confirm the spawner called it.
func initialize(template, overrides):
	init_data = {"template": template, "overrides": overrides}
