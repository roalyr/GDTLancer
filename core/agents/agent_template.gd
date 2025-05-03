# File: core/agents/agent_template.gd
# Resource Definition for Agent Stats/Config
# Version: 1.1 - Added alignment threshold export

extends Resource
class_name AgentTemplate  # Allows type hinting and creating this resource type in editor

# --- Identification ---
export var template_id: String = "default_template"  # Unique ID for this template type
export var default_agent_name: String = "Agent"  # Base name for agents using this
export var default_faction_id: String = "Neutral"  # Default faction

# --- Base Movement Capabilities (Reads defaults from Constants) ---
export var max_move_speed: float = Constants.DEFAULT_MAX_MOVE_SPEED
export var acceleration: float = Constants.DEFAULT_ACCELERATION
export var deceleration: float = Constants.DEFAULT_DECELERATION
export var max_turn_speed: float = Constants.DEFAULT_MAX_TURN_SPEED

# --- Interaction Size ---
# Used by camera targeting, docking, etc. Represents effective size.
export var interaction_radius: float = 15.0  # Default reasonable size

# --- NEW: Alignment Threshold ---
# Agent will only accelerate forward if facing within this angle (degrees) of the target direction.
# Relevant for MOVE_TO, MOVE_DIRECTION, APPROACH, FLEE commands.
export var alignment_threshold_angle_deg: float = 45.0

# --- Base Combat Stats (Placeholders - Link to Combat Module/Character System later) ---
# export var base_hull : int = 100
# export var base_shields : int = 0

# --- Base Skills (Placeholders - Link to Character System later) ---
# These represent the inherent skill level associated with this *type* of agent
# export var base_piloting_skill : int = 0
# export var base_tech_skill : int = 0
# export var base_social_skill : int = 0

# --- AI Behavior Hint (Optional) ---
# export var default_ai_behavior : String = "idle" # Hint for AI controller selection/init

# --- Visuals / Asset Links (Placeholders) ---
# Optional: Could link to default ship model path, visual effects, etc.
# export (String, FILE, "*.tscn,*.glb,*.gltf") var default_model_path = ""
