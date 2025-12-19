# File: core/systems/action_system.gd
# Purpose: Manages the queueing, execution, and completion of character actions.
# Version: 2.0 - Reworked to match new templates.

extends Node

# Emitted when an action is completed, broadcasting the result.
# payload: The result dictionary from CoreMechanicsAPI.perform_action_check().
signal action_completed(character, action_resource, payload)

var _next_action_id: int = 1

func _ready():
	GlobalRefs.set_action_system(self)
	
	if not EventBus.is_connected("world_event_tick_triggered", self, "_on_world_event_tick"):
		EventBus.connect("world_event_tick_triggered", self, "_on_world_event_tick")
	print("ActionSystem Ready.")


# --- Public API ---

# Queues an action for a character.
# - action_approach: From Constants.ActionApproach (e.g., CAUTIOUS, RISKY).
func request_action(
	character_instance: CharacterTemplate, action_template: ActionTemplate, action_approach: int, target: Node = null
) -> bool:
	if not is_instance_valid(character_instance) or not action_template:
		return false

	var action_id = _get_new_action_id()

	GameState.active_actions[action_id] = {
		"character_instance": character_instance, 
		"action_template": action_template,
		"action_approach": action_approach,  # Store the approach for later.
		"target": target,
		"tu_progress": 0,
		"tu_cost": action_template.tu_cost
	}

	var approach_str = (
		"Cautious"
		if action_approach == Constants.ActionApproach.CAUTIOUS
		else "Risky"
	)
	print(
		(
			"ActionSystem: Queued action '%s' for %s (Approach: %s)"
			% [action_template.action_name, character_instance.character_name, approach_str]
		)
	)

	return true


# --- Signal Handlers ---
func _on_world_event_tick(tu_passed: int):
	for action_id in GameState.active_actions.keys().duplicate():
		var action = GameState.active_actions[action_id]
		action.tu_progress += tu_passed

		if action.tu_progress >= action.tu_cost:
			_process_action_completion(action_id)


# --- Private Logic ---
func _process_action_completion(action_id: int):
	if not GameState.active_actions.has(action_id):
		return

	var action_data = GameState.active_actions[action_id]
	var character_instance = action_data.character_instance
	var action_template = action_data.action_template
	var action_approach = action_data.action_approach

	# Perform the action check to get the result.
	# For now, we assume dummy values for attribute/skill levels.
	# A real implementation would get these from the character object.
	var character_attribute_value = 4  # Dummy value
	var character_skill_level = 2  # Dummy value
	var focus_spent = 0  # Dummy value

	var result_payload = CoreMechanicsAPI.perform_action_check(
		character_attribute_value, character_skill_level, focus_spent, action_approach
	)

	print(
		(
			"ActionSystem: Completed action '%s'. Result: %s"
			% [action_template.action_name, result_payload.tier_name]
		)
	)

	# Emit the signal with all relevant data.
	emit_signal("action_completed", character_instance, action_template, result_payload)

	GameState.active_actions.erase(action_id)


func _get_new_action_id() -> int:
	var id = _next_action_id
	_next_action_id += 1
	return id
