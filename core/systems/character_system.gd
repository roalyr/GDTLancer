# File: core/systems/character_system.gd
# Purpose: Manages all character agents, their data, and world interactions.
# Version: 0.2 - Corrected is_connected() signature.

extends Node

# --- Data Structures ---
# We will store all spawned characters in a dictionary, keyed by their
# unique instance ID. This provides fast lookups.
var _characters: Dictionary = {}

# A data structure to track which character is currently controlled by the player.
var _player_character_id = null


# --- System Ready ---
func _ready():
	# Connect to the EventBus to listen for when new agents are spawned.
	if not EventBus.is_connected("agent_spawned", self, "_on_agent_spawned"):
		EventBus.connect("agent_spawned", self, "_on_agent_spawned")
	print("CharacterSystem Ready.")


# --- Public API ---


# Returns the Node representing the player's character, or null if not set.
func get_player_character() -> Node:
	if _player_character_id and _characters.has(_player_character_id):
		return _characters[_player_character_id]
	return null


# Returns a dictionary of all characters managed by the system.
func get_all_characters() -> Dictionary:
	return _characters


# Placeholder for the function called by the TimeSystem's world tick.
# This will eventually deduct Willpower Points (WP) from all characters.
func apply_upkeep_cost():
	# print("CharacterSystem: Applying upkeep cost...")
	# In a future version, this would iterate through all characters in _characters
	# and call a method on them like 'deduct_wp(UPKEEP_COST)'.
	pass


# --- EventBus Signal Handlers ---


# Listens for the 'agent_spawned' signal from the EventBus.
# If the spawned agent is a character, it's registered with this system.
# - agent: The Node that was just spawned.
# - agent_data: A dictionary of data associated with the agent.
func _on_agent_spawned(agent: Node, agent_data: Dictionary):
	# The GDD specifies that character agents will have an 'agent_type' of 'character'.
	if agent_data.get("agent_type") == "character":
		var instance_id = agent.get_instance_id()
		if not _characters.has(instance_id):
			_characters[instance_id] = agent
			print("CharacterSystem: Registered character with ID: %s" % instance_id)

			# If the 'is_player' flag is set, designate this as the player character.
			if agent_data.get("is_player") == true:
				_player_character_id = instance_id
				print("CharacterSystem: Agent %s designated as player character." % instance_id)

		# This is a good place to handle agent destruction to prevent memory leaks.
		# The is_connected check correctly uses 3 arguments.
		if not agent.is_connected("tree_exiting", self, "_on_agent_tree_exiting"):
			# The connect call correctly uses 4 arguments to bind the instance_id.
			agent.connect("tree_exiting", self, "_on_agent_tree_exiting", [instance_id])


# --- Internal Logic ---


# Triggered when a character node is about to be removed from the scene tree.
# This ensures we don't keep references to destroyed objects.
func _on_agent_tree_exiting(instance_id: int):
	if _characters.has(instance_id):
		_characters.erase(instance_id)
		print("CharacterSystem: Unregistered destroyed character with ID: %s" % instance_id)
		# If the player character is destroyed, clear the reference.
		if _player_character_id == instance_id:
			_player_character_id = null
			print("CharacterSystem: Player character was destroyed.")
