# File: core/agents/agent.gd
# Attached to Agent (KinematicBody) root node in agent.tscn
# Version: 2.1 - Removed invalid is_rotation check for Godot 3

extends KinematicBody

# --- Agent Identification ---
var agent_name: String = "Default Agent"
var faction_id: String = "Neutral"
var template_id: String = "default"

# --- Movement Capabilities ---
var max_move_speed: float = 0.0
var acceleration: float = 0.0
var deceleration: float = 0.0
var max_turn_speed: float = 0.0 # Radians per second

# --- Current State ---
var current_velocity: Vector3 = Vector3.ZERO

# --- Controller Inputs ---
var _intended_thrust_direction: Vector3 = Vector3.ZERO
var _intended_look_direction: Vector3 = Vector3.FORWARD

# --- Initialization ---
func initialize(template: AgentTemplate, overrides: Dictionary = {}):
	if not template is AgentTemplate:
		printerr("Agent Initialize Error: Invalid template for ", self.name); return

	self.template_id = template.template_id
	self.agent_name = overrides.get("name", template.default_agent_name + "_" + str(get_instance_id()))
	self.faction_id = overrides.get("faction", template.default_faction_id)
	self.max_move_speed = overrides.get("max_move_speed", template.max_move_speed)
	self.acceleration = overrides.get("acceleration", template.acceleration)
	self.deceleration = overrides.get("deceleration", template.deceleration)
	self.max_turn_speed = overrides.get("max_turn_speed", template.max_turn_speed)
	self.name = self.agent_name

	_intended_look_direction = -global_transform.basis.z.normalized()
	# ... (Initialize other stats/resources placeholders) ...
	print(self.name + " initialized using template '", self.template_id, "'.")

# --- Godot Lifecycle ---
func _ready():
	add_to_group("Agents")
	set_physics_process(true)

func _physics_process(delta):
	_perform_rotation(delta)
	_perform_movement(delta)

# --- Internal Movement & Rotation Logic ---
func _perform_rotation(delta):
	if _intended_look_direction.length_squared() < 0.001: return

	var target_dir = _intended_look_direction # Already normalized
	var current_transform = global_transform
	var current_basis = current_transform.basis

	var up_vector = Vector3.UP
	if abs(target_dir.dot(Vector3.UP)) > 0.999:
		up_vector = Vector3.FORWARD

	var look_at_transform = Transform(Basis(), Vector3.ZERO).looking_at(target_dir, up_vector)
	var target_basis = look_at_transform.basis

	# Orthonormalize bases before slerp
	current_basis = current_basis.orthonormalized()
	target_basis = target_basis.orthonormalized()

	# *** REMOVED is_rotation() check ***

	# Use spherical linear interpolation (slerp) for smooth rotation
	# Assumes orthonormalized bases are valid for slerp
	var new_basis = current_basis.slerp(target_basis, max_turn_speed * delta)
	global_transform.basis = new_basis


func _perform_movement(delta):
	var target_velocity: Vector3
	if _intended_thrust_direction.length_squared() > 0.001:
		target_velocity = _intended_thrust_direction.normalized() * max_move_speed
		current_velocity = current_velocity.linear_interpolate(target_velocity, acceleration * delta)
	else:
		current_velocity = current_velocity.linear_interpolate(Vector3.ZERO, deceleration * delta)

	current_velocity = move_and_slide(current_velocity, Vector3.UP)
	_intended_thrust_direction = Vector3.ZERO # Reset thrust intention


# --- Public Methods for Controllers ---
func set_thrust_input(direction: Vector3):
	_intended_thrust_direction = direction

func set_look_input(direction: Vector3):
	if direction.length_squared() > 0.001:
		_intended_look_direction = direction.normalized()
	# else: Maintain last look direction (current implementation)

# --- Despawn ---
func despawn():
	print("Agent ", self.name, " despawning...")
	EventBus.emit_signal("agent_despawning", self)
	queue_free()

# --- Placeholder Functions ---
# func take_damage(amount, type): pass
# func get_skill(skill_name: String) -> int: return 0
# func calculate_module_modifier(module_name: String) -> int: return 0
