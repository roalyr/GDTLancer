#
# PROJECT: GDTLancer
# MODULE: tool_controller.gd
# STATUS: Level 3 - Verified
# TRUTH_LINK: TACTICAL_TODO.md - Naming Standardization
# LOG_REF: 2026-01-28-QA-Intern
#

## ToolController: Manages tool (weapon) firing and cooldowns for an agent.
## Attaches as child of AgentBody (RigidBody), interfaces with CombatSystem for damage.
extends Node

const UtilityToolTemplate = preload("res://database/definitions/utility_tool_template.gd")

signal weapon_fired(weapon_index, target_position)
signal weapon_cooldown_started(weapon_index, duration)
signal weapon_ready(weapon_index)

# --- References (set in _ready) ---
var _agent_body: RigidBody = null  # Parent AgentBody
var _ship_template = null  # Linked ShipTemplate (via AssetSystem)
var _weapons: Array = []  # Loaded UtilityToolTemplate instances
var _cooldowns: Dictionary = {}  # weapon_index -> remaining_time


# --- Initialization ---
func _ready() -> void:
	_agent_body = get_parent()
	if not _agent_body is RigidBody:
		printerr("ToolController: Parent must be RigidBody")
		return
	# Defer weapon loading to allow agent initialization to complete first
	call_deferred("_load_weapons_from_ship")


func _load_weapons_from_ship() -> void:
	# Get character_uid from agent, then ship from AssetSystem
	var raw_char_uid = _agent_body.get("character_uid")
	var uid_str: String = str(raw_char_uid) if raw_char_uid != null else "-1"
	var uid_valid: bool = uid_str != "-1" and uid_str != ""

	# First try to get ship from character (pass original type for dict key match)
	if uid_valid and is_instance_valid(GlobalRefs.asset_system):
		_ship_template = GlobalRefs.asset_system.get_ship_for_character(raw_char_uid)
	
	# If no ship via character, try to get cached ship_template from agent body (for hostile NPCs)
	if not is_instance_valid(_ship_template):
		var agent_ship = _agent_body.get("ship_template")
		if is_instance_valid(agent_ship):
			_ship_template = agent_ship
	
	if not is_instance_valid(_ship_template):
		print("ToolController: No ship template available for agent, cannot load weapons.")
		return  # No ship available

	# Load each equipped tool template
	var equipped_list = _ship_template.get("equipped_tools")
	if equipped_list == null:
		equipped_list = _ship_template.get("equipped_weapons")
	if equipped_list == null:
		equipped_list = []

	for tool_id in equipped_list:
		var tool_template = null
		if TemplateDatabase and TemplateDatabase.has_method("get_template"):
			tool_template = TemplateDatabase.callv("get_template", [tool_id])

		if tool_template and tool_template.get("tool_type") == "weapon":
			_weapons.append(tool_template)
			_cooldowns[_weapons.size() - 1] = 0.0
	
	if _weapons.size() > 0:
		print("ToolController: Loaded ", _weapons.size(), " weapon(s) for agent")
	else:
		# Helpful during manual integration verification.
		print(
			"ToolController: No weapons loaded for agent_uid=",
			_agent_body.get("agent_uid"),
			" ship=",
			_ship_template.get("template_id"),
			" equipped_weapons=",
			_ship_template.get("equipped_weapons"),
			" equipped_tools=",
			_ship_template.get("equipped_tools")
		)


func _physics_process(delta: float) -> void:
	# Update local cooldown timers.
	for idx in _cooldowns.keys():
		if _cooldowns[idx] > 0:
			_cooldowns[idx] -= delta
			if _cooldowns[idx] <= 0:
				_cooldowns[idx] = 0
				emit_signal("weapon_ready", idx)


# --- Public API ---

func get_weapon_count() -> int:
	return _weapons.size()


func get_weapon(index: int) -> Resource:
	if index >= 0 and index < _weapons.size():
		return _weapons[index]
	return null


func is_weapon_ready(index: int) -> bool:
	return _cooldowns.get(index, 0.0) <= 0.0


func get_cooldown_remaining(index: int) -> float:
	return _cooldowns.get(index, 0.0)


func fire_at_target(weapon_index: int, target_uid: int, target_position: Vector3) -> Dictionary:
	# CombatSystem removed — rebuild later on Agent layer
	return {"success": false, "reason": "CombatSystem not available (removed)"}


func _ensure_combatant_registered(uid: int) -> void:
	# CombatSystem removed — no-op stub
	pass
