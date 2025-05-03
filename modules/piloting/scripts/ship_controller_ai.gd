# File: modules/piloting/scripts/ship_controller_ai.gd
# Attach to Node child of AgentBody in npc_agent.tscn
# Version 2.1 - Simplified for agent command execution model

extends Node

# --- References ---
# Set in _ready()
var agent_script: Node = null  # Reference to the parent agent.gd script instance


# --- Initialization ---
func _ready():
	# Get reference to parent agent script
	var parent = get_parent()
	# Check if parent is the correct type and has the command methods
	if parent is KinematicBody and parent.has_method("command_move_to"):
		agent_script = parent
		# print("AI Controller ready for: ", agent_script.agent_name) # Optional Debug
	else:
		printerr(
			"AI Controller Error: Parent node is not an Agent KinematicBody with command methods!"
		)
		# If setup fails, this controller can't function.
		# We can disable physics process (though it's empty now)
		# or even detach the script to prevent errors.
		set_physics_process(false)
		set_script(null)  # Detach script if parent is wrong


# Called by WorldManager's spawn_agent function (via initialize dictionary in agent.gd)
# The 'config' dictionary here is the 'overrides' passed to spawn_agent
func initialize(config: Dictionary):
	# Ensure agent script reference is valid before issuing command
	if not is_instance_valid(agent_script):
		printerr("AI Initialize Error: Agent script invalid. Cannot issue command.")
		return

	# Read necessary parameters from config dictionary if present
	var stopping_dist = config.get("stopping_distance", 10.0)  # May not be needed by AI now
	# TODO: Agent's MOVE_TO command should probably use its own internal stopping distance logic

	# Immediately issue the initial command based on 'initial_target' in config
	if config.has("initial_target") and config.initial_target is Vector3:
		var target_pos = config.initial_target
		print(agent_script.agent_name, " AI issuing command: MOVE_TO ", target_pos)
		# Call the command method on the agent script
		agent_script.command_move_to(target_pos)
	else:
		# If no target, the agent remains IDLE (its default state)
		if is_instance_valid(agent_script):  # Check again just in case
			print(
				"AI Controller Warning: No initial target provided for ",
				agent_script.agent_name,
				". Agent will remain idle."
			)

# --- No Physics Update Needed ---
# For this simple "go-to" AI, the agent itself executes the command issued
# during initialize. This controller doesn't need to do anything frame-by-frame.
# More complex AI would have state machines here, checking conditions and
# issuing different commands (approach, orbit, flee, etc.) as needed.
# func _physics_process(delta):
#     pass

# --- No Event Handling Needed Here ---
# The agent itself now emits "agent_reached_destination" via EventBus
# when its relevant command (MOVE_TO -> STOPPING -> IDLE) completes.
# WorldManager listens for that signal to trigger the despawn.
# func _handle_target_reached(): # Removed
# func _on_Agent_Reached_Destination(agent_body): # Removed

# --- No Public Functions Needed Here ---
# func set_target(new_target: Vector3): # Removed - command issued once at init
