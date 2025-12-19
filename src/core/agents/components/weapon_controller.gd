# File: core/agents/components/weapon_controller.gd
# Purpose: Manages weapon firing and cooldowns for an agent.
# Attaches as child of AgentBody (KinematicBody).
extends Node

const UtilityToolTemplate = preload("res://database/definitions/utility_tool_template.gd")

signal weapon_fired(weapon_index, target_position)
signal weapon_cooldown_started(weapon_index, duration)
signal weapon_ready(weapon_index)

# --- References (set in _ready) ---
var _agent_body: KinematicBody = null  # Parent AgentBody
var _ship_template = null  # Linked ShipTemplate (via AssetSystem)
var _weapons: Array = []  # Loaded UtilityToolTemplate instances
var _cooldowns: Dictionary = {}  # weapon_index -> remaining_time


# --- Initialization ---
func _ready() -> void:
	_agent_body = get_parent()
	if not _agent_body is KinematicBody:
		printerr("WeaponController: Parent must be KinematicBody")
		return
	# Defer weapon loading to allow agent initialization to complete first
	call_deferred("_load_weapons_from_ship")


func _load_weapons_from_ship() -> void:
	# Get character_uid from agent, then ship from AssetSystem
	var char_uid: int = -1
	var raw_char_uid = _agent_body.get("character_uid")
	if raw_char_uid != null:
		char_uid = int(raw_char_uid)
	
	# First try to get ship from character
	if char_uid >= 0 and is_instance_valid(GlobalRefs.asset_system):
		_ship_template = GlobalRefs.asset_system.get_ship_for_character(char_uid)
	
	# If no ship via character, try to get cached ship_template from agent body (for hostile NPCs)
	if not is_instance_valid(_ship_template):
		var agent_ship = _agent_body.get("ship_template")
		if is_instance_valid(agent_ship):
			_ship_template = agent_ship
	
	if not is_instance_valid(_ship_template):
		print("WeaponController: No ship template available for agent, cannot load weapons.")
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
		print("WeaponController: Loaded ", _weapons.size(), " weapon(s) for agent")
	else:
		# Helpful during manual integration verification.
		print(
			"WeaponController: No weapons loaded for agent_uid=",
			_agent_body.get("agent_uid"),
			" ship=",
			_ship_template.get("template_id"),
			" equipped_weapons=",
			_ship_template.get("equipped_weapons"),
			" equipped_tools=",
			_ship_template.get("equipped_tools")
		)


func _physics_process(delta: float) -> void:
	# Keep CombatSystem cooldowns ticking (CombatSystem stores cooldowns per combatant).
	if is_instance_valid(GlobalRefs.combat_system) and GlobalRefs.combat_system.has_method("update_cooldowns"):
		GlobalRefs.combat_system.update_cooldowns(delta)

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
	if weapon_index < 0 or weapon_index >= _weapons.size():
		return {"success": false, "reason": "Invalid weapon index"}

	if not is_weapon_ready(weapon_index):
		return {"success": false, "reason": "Weapon on cooldown", "cooldown": _cooldowns[weapon_index]}

	var weapon = _weapons[weapon_index]
	var shooter_uid: int = int(_agent_body.get("agent_uid"))
	var shooter_pos: Vector3 = _agent_body.global_transform.origin

	if not is_instance_valid(GlobalRefs.combat_system):
		return {"success": false, "reason": "CombatSystem unavailable"}

	# Ensure both combatants registered
	_ensure_combatant_registered(shooter_uid)
	_ensure_combatant_registered(target_uid)

	# Fire via CombatSystem
	var result = GlobalRefs.combat_system.fire_weapon(
		shooter_uid,
		target_uid,
		weapon,
		shooter_pos,
		target_position
	)

	if result.get("success", false):
		# Start cooldown
		var cooldown_seconds: float = 0.0
		if weapon and weapon is UtilityToolTemplate:
			var fire_rate: float = float(max(weapon.fire_rate, 0.0001))
			cooldown_seconds = (1.0 / fire_rate) + float(weapon.cooldown_time)
		_cooldowns[weapon_index] = cooldown_seconds
		emit_signal("weapon_cooldown_started", weapon_index, cooldown_seconds)
		emit_signal("weapon_fired", weapon_index, target_position)

	return result


func _ensure_combatant_registered(uid: int) -> void:
	if not is_instance_valid(GlobalRefs.combat_system):
		return
	# Don't confuse "in combat" (alive/active) with "registered" (has hull state).
	# We need registration even when combat hasn't started yet.
	if GlobalRefs.combat_system.has_method("get_combat_state"):
		var existing_state: Dictionary = GlobalRefs.combat_system.get_combat_state(uid)
		if not existing_state.empty():
			return
	else:
		# Fallback for older CombatSystem API.
		if GlobalRefs.combat_system.is_in_combat(uid):
			return

	var ship = null

	# Prefer current ship if this is the local agent.
	if _agent_body and int(_agent_body.get("agent_uid")) == uid and is_instance_valid(_ship_template):
		ship = _ship_template

	# Resolve uid -> AgentBody and use its cached ship_template.
	if not is_instance_valid(ship):
		var agent_body = null
		if is_instance_valid(GlobalRefs.world_manager) and GlobalRefs.world_manager.has_method("get_agent_by_uid"):
			agent_body = GlobalRefs.world_manager.get_agent_by_uid(uid)

		if not is_instance_valid(agent_body):
			var tree = get_tree()
			if tree:
				for node in tree.get_nodes_in_group("Agents"):
					if (
						is_instance_valid(node)
						and node.get("agent_uid") != null
						and int(node.get("agent_uid")) == uid
					):
						agent_body = node
						break

		if is_instance_valid(agent_body):
			var cached_ship = agent_body.get("ship_template")
			if is_instance_valid(cached_ship):
				ship = cached_ship
			else:
				# If this body has a character_uid, use AssetSystem mapping.
				var raw_char_uid = agent_body.get("character_uid")
				if raw_char_uid != null and int(raw_char_uid) >= 0 and is_instance_valid(GlobalRefs.asset_system):
					ship = GlobalRefs.asset_system.get_ship_for_character(int(raw_char_uid))

	# Try to interpret uid as character_uid.
	if not is_instance_valid(ship) and is_instance_valid(GlobalRefs.asset_system):
		ship = GlobalRefs.asset_system.get_ship_for_character(uid)

	# Fallback: interpret uid as ship_uid.
	if not is_instance_valid(ship) and is_instance_valid(GlobalRefs.asset_system):
		ship = GlobalRefs.asset_system.get_ship(uid)

	if is_instance_valid(ship):
		GlobalRefs.combat_system.register_combatant(uid, ship)
