# File: core/agents/agent.gd
# Attached to Agent (KinematicBody) root node in agent.tscn
# Version: 1.1 - Removed exports, added initialize function

extends KinematicBody

# Signals emitted by this agent
signal agent_spawned(agent_instance)
signal agent_despawning(agent_instance) # Emitted just before queue_free()

# --- Agent Identification ---
# Set via initialize()
var agent_name: String = "Default Agent"
var faction_id: String = "Neutral"

# --- Movement Capabilities ---
# Set via initialize() based on Asset/Character data
var max_move_speed: float = 50.0   # Units per second
var acceleration: float = 10.0   # Units per second^2
var deceleration: float = 15.0   # Units per second^2 (for stopping smoothly)
var max_turn_speed: float = 2.0    # Radians per second

# --- Current State ---
# Managed primarily by MovementComponent, but stored here
var current_velocity: Vector3 = Vector3.ZERO

# --- Initialization ---
# Called by the spawner (e.g., WorldManager) AFTER instancing and adding to tree
func initialize(data: Dictionary):
	# Set properties based on passed data (from Asset, Character template, etc.)
	if data.has("name"):
		self.name = data.name # Set the actual node name for easier debugging
		self.agent_name = data.name
	if data.has("faction"):
		self.faction_id = data.faction
	if data.has("max_move_speed"):
		self.max_move_speed = data.max_move_speed
	if data.has("acceleration"):
		self.acceleration = data.acceleration
	if data.has("deceleration"):
		self.deceleration = data.deceleration
	if data.has("max_turn_speed"):
		self.max_turn_speed = data.max_turn_speed

	# --- Initialize Other Core Stats/Resources (Placeholders) ---
	# self.focus_points = data.get("initial_focus", 0)
	# self.wealth_points = data.get("initial_wealth", 0)
	# self.current_hull = data.get("max_hull", 100)
	# self.max_hull = data.get("max_hull", 100)
	# Load relevant skills from Character System based on agent template/ID?

	print(self.name + " initialized.")
	emit_signal("agent_spawned", self)


# --- Core Functions ---
func _ready():
	# Add to group for easier management by systems
	add_to_group("Agents")
	# Note: Initialization happens AFTER _ready typically, when called by spawner.
	# So emitting spawn signal in initialize() might be better timing.

func despawn():
	emit_signal("agent_despawning", self)
	queue_free() # Remove the agent from the scene

# --- Helpers for Movement / Controllers ---

# Internal state for tracking movement intention this frame
# Controllers call set_movement_input()
# MovementComponent calls _get_movement_input_vector()
var _current_movement_input := Vector3.ZERO

# Called by controller scripts (AI/Player) each physics frame they intend to move
func set_movement_input(input_vector: Vector3):
	_current_movement_input = input_vector

# Called by MovementComponent to check for input this frame (used for deceleration)
func _get_movement_input_vector() -> Vector3:
	var input = _current_movement_input
	# Reset for the next frame - ensures deceleration applies if no input is set again
	_current_movement_input = Vector3.ZERO
	return input


# --- Placeholder Functions for Future Systems ---

# func take_damage(amount, type):
#     pass # Would handle hull/shield reduction

# func get_skill(skill_name: String) -> int:
#     # Would query the Character System for this agent's skill
#     return 0

# func get_asset_difficulty(asset_id: String, module_name: String) -> int:
#     # Would query the Asset System for the difficulty of equipped asset
#     return 0

# func calculate_module_modifier(module_name: String) -> int:
#     # Needs info about the currently relevant asset for this module
#     # var relevant_skill = get_skill(...)
#     # var asset_difficulty = get_asset_difficulty(...)
#     # return relevant_skill + asset_difficulty
#     return 0 # Placeholder

# func update_focus(change: int):
#     pass # Would update FP tracked potentially here or in Character System

# func update_wealth(change: int):
#     pass # Would update WP tracked potentially here or in Character System

# func add_time_units(amount: int):
#     # Could potentially signal a global Time System singleton (Autoload)
#     pass
