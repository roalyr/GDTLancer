# File: tests/helpers/mock_agent_body.gd
# A minimal agent body for the spawner to instantiate in tests.
# Version: 3.0 - Updated to RigidBody for physics-based flight.

extends RigidBody

# --- Core State & Identity (to match agent.gd) ---
var agent_type: String = ""
var template_id: String = ""
var agent_uid = -1

# --- Test-specific variable ---
# This will be populated when initialize is called, so tests can inspect it.
var init_data = null


func _ready():
	# RigidBody settings for 6DOF space flight
	mode = RigidBody.MODE_RIGID
	gravity_scale = 0.0
	can_sleep = false


# This signature now exactly matches the one in `core/agents/agent.gd`.
# We will spy on this method to confirm the spawner called it.
func initialize(template: AgentTemplate, overrides: Dictionary = {}, agent_uid: int = -1):
	# Store the received data so tests can assert it's correct.
	init_data = {
		"template": template,
		"overrides": overrides,
		"agent_uid": agent_uid
	}

	# Also set the properties just like the real agent.gd does.
	self.template_id = overrides.get("template_id")
	self.agent_type = overrides.get("agent_type")
	self.agent_uid = agent_uid
