# combat_system.gd
# Stateless API for combat mechanics - targeting, damage, disabling
# Phase 1: Hull-only targeting, basic weapon firing
extends Node

signal combat_started(attacker_uid, defender_uid)
signal combat_ended(result)
signal damage_dealt(target_uid, amount, source_uid)
signal ship_disabled(ship_uid)
signal weapon_fired(shooter_uid, weapon_id, target_pos)

const UtilityToolTemplate = preload("res://core/resource/utility_tool_template.gd")

# Combat state tracking (per-encounter)
var _active_combatants: Dictionary = {}  # uid -> combat_state dict
var _combat_active: bool = false


func _ready():
	GlobalRefs.set_combat_system(self)
	print("CombatSystem Ready.")


# --- Public API ---

# Initialize combat state for an agent
func register_combatant(agent_uid: int, ship_template) -> void:
	if not ship_template:
		return
	
	_active_combatants[agent_uid] = {
		"current_hull": ship_template.hull_integrity,
		"max_hull": ship_template.hull_integrity,
		"current_armor": ship_template.armor_integrity,
		"max_armor": ship_template.armor_integrity,
		"is_disabled": false,
		"equipped_tools": [],
		"cooldowns": {}  # tool_id -> time_remaining
	}


func unregister_combatant(agent_uid: int) -> void:
	_active_combatants.erase(agent_uid)


func is_in_combat(agent_uid: int) -> bool:
	return _active_combatants.has(agent_uid) and not _active_combatants[agent_uid].is_disabled


func is_combat_active() -> bool:
	return _combat_active


func get_combat_state(agent_uid: int) -> Dictionary:
	return _active_combatants.get(agent_uid, {})


# Get hull percentage (0.0 - 1.0)
func get_hull_percent(agent_uid: int) -> float:
	var state = _active_combatants.get(agent_uid, {})
	if state.empty() or state.max_hull == 0:
		return 0.0
	return float(state.current_hull) / float(state.max_hull)


# Check if a target is within weapon range
func is_in_range(shooter_pos: Vector3, target_pos: Vector3, weapon: UtilityToolTemplate) -> bool:
	if not weapon:
		return false
	var distance = shooter_pos.distance_to(target_pos)
	return distance <= weapon.range_max


# Calculate damage based on weapon and distance
func calculate_damage(weapon: UtilityToolTemplate, distance: float) -> Dictionary:
	if not weapon:
		return {"hull_damage": 0, "armor_damage": 0}
	
	var base_damage = weapon.get_damage_at_range(distance)
	
	return {
		"hull_damage": base_damage * weapon.hull_damage_multiplier,
		"armor_damage": base_damage * weapon.armor_damage_multiplier
	}


# Attempt to fire a weapon at a target
func fire_weapon(shooter_uid: int, target_uid: int, weapon: UtilityToolTemplate, 
				 shooter_pos: Vector3, target_pos: Vector3) -> Dictionary:
	# Validate combatants
	if not _active_combatants.has(shooter_uid):
		return {"success": false, "reason": "Shooter not registered"}
	if not _active_combatants.has(target_uid):
		return {"success": false, "reason": "Target not registered"}
	if not weapon:
		return {"success": false, "reason": "No weapon provided"}
	
	var shooter_state = _active_combatants[shooter_uid]
	
	# Check cooldown
	var cooldown_remaining = shooter_state.cooldowns.get(weapon.template_id, 0.0)
	if cooldown_remaining > 0:
		return {"success": false, "reason": "Weapon on cooldown", "cooldown": cooldown_remaining}
	
	# Check range
	var distance = shooter_pos.distance_to(target_pos)
	if distance > weapon.range_max:
		return {"success": false, "reason": "Target out of range", "distance": distance}
	
	# Calculate hit chance
	var hit_chance = weapon.get_accuracy_at_range(distance)
	var roll = randf()
	var hit = roll <= hit_chance
	
	# Set cooldown
	var cooldown = (1.0 / weapon.fire_rate) + weapon.cooldown_time
	shooter_state.cooldowns[weapon.template_id] = cooldown
	
	# Emit weapon fired signal
	emit_signal("weapon_fired", shooter_uid, weapon.template_id, target_pos)
	
	if not hit:
		return {
			"success": true,
			"hit": false,
			"reason": "Missed",
			"accuracy": hit_chance,
			"roll": roll
		}
	
	# Calculate and apply damage
	var damage = calculate_damage(weapon, distance)
	var damage_result = apply_damage(target_uid, damage.hull_damage, damage.armor_damage, shooter_uid)
	
	return {
		"success": true,
		"hit": true,
		"damage_dealt": damage,
		"target_disabled": damage_result.disabled,
		"target_hull_remaining": damage_result.hull_remaining
	}


# Apply damage to a target
func apply_damage(target_uid: int, hull_damage: float, armor_damage: float = 0.0, source_uid: int = -1) -> Dictionary:
	if not _active_combatants.has(target_uid):
		return {"success": false, "reason": "Target not registered"}
	
	var state = _active_combatants[target_uid]
	
	if state.is_disabled:
		return {"success": false, "reason": "Target already disabled"}
	
	# Phase 1: Simple damage model - armor absorbs first, then hull
	var remaining_damage = hull_damage
	
	# Apply to armor first if present
	if armor_damage > 0 and state.current_armor > 0:
		var armor_absorbed = min(armor_damage, state.current_armor)
		state.current_armor -= armor_absorbed
	
	# Apply hull damage
	var hull_dealt = min(remaining_damage, state.current_hull)
	state.current_hull -= hull_dealt
	
	emit_signal("damage_dealt", target_uid, hull_dealt, source_uid)

	# Mirror gameplay-facing damage signals onto EventBus (HUD, AI, encounter logic).
	if EventBus:
		var target_body = _get_agent_body(target_uid)
		var source_body = _get_agent_body(source_uid)
		if is_instance_valid(target_body):
			EventBus.emit_signal("agent_damaged", target_body, hull_dealt, source_body)
	
	# Check for disable
	var disabled = state.current_hull <= 0
	if disabled:
		state.is_disabled = true
		state.current_hull = 0
		emit_signal("ship_disabled", target_uid)
		if EventBus:
			var disabled_body = _get_agent_body(target_uid)
			if is_instance_valid(disabled_body):
				EventBus.emit_signal("agent_disabled", disabled_body)
	
	return {
		"success": true,
		"hull_damage_dealt": hull_dealt,
		"hull_remaining": state.current_hull,
		"armor_remaining": state.current_armor,
		"disabled": disabled
	}


# Update cooldowns (call each frame or physics tick)
func update_cooldowns(delta: float) -> void:
	for uid in _active_combatants:
		var state = _active_combatants[uid]
		var to_remove = []
		for tool_id in state.cooldowns:
			state.cooldowns[tool_id] -= delta
			if state.cooldowns[tool_id] <= 0:
				to_remove.append(tool_id)
		for tool_id in to_remove:
			state.cooldowns.erase(tool_id)


# Check if all enemies are disabled
func check_combat_victory(player_uid: int) -> Dictionary:
	var player_alive = _active_combatants.has(player_uid) and not _active_combatants[player_uid].is_disabled
	
	if not player_alive:
		return {"victory": false, "reason": "player_disabled"}
	
	# Check if any non-player combatants are still active
	for uid in _active_combatants:
		if uid != player_uid and not _active_combatants[uid].is_disabled:
			return {"victory": false, "reason": "enemies_remain"}
	
	return {"victory": true, "reason": "all_enemies_disabled"}


# Start a combat encounter
func start_combat(participants: Array) -> void:
	_combat_active = true
	for participant in participants:
		var uid = participant.get("uid", -1)
		var ship = participant.get("ship_template", null)
		if uid >= 0 and ship:
			register_combatant(uid, ship)
	
	if participants.size() >= 2:
		emit_signal("combat_started", participants[0].get("uid", -1), participants[1].get("uid", -1))


# End combat and clean up
func end_combat(result: String = "ended") -> void:
	_combat_active = false
	_active_combatants.clear()
	emit_signal("combat_ended", result)


func _get_agent_body(agent_uid: int):
	if agent_uid < 0:
		return null

	if is_instance_valid(GlobalRefs.world_manager) and GlobalRefs.world_manager.has_method("get_agent_by_uid"):
		var from_world_manager = GlobalRefs.world_manager.get_agent_by_uid(agent_uid)
		if is_instance_valid(from_world_manager):
			return from_world_manager

	# Fallback: scan nodes in the Agents group.
	var tree = get_tree()
	if tree:
		for node in tree.get_nodes_in_group("Agents"):
			if is_instance_valid(node) and node.get("agent_uid") != null and int(node.get("agent_uid")) == agent_uid:
				return node

	return null


# --- Targeting Helpers ---

# Get closest enemy in range
func get_closest_target(_from_pos: Vector3, agent_uid: int, _max_range: float = -1.0) -> Dictionary:
	var closest_uid = -1
	var closest_dist = INF
	
	for uid in _active_combatants:
		if uid == agent_uid:
			continue
		if _active_combatants[uid].is_disabled:
			continue
		
		# Would need agent positions from another system
		# This is a placeholder - actual implementation needs position data
	
	return {"target_uid": closest_uid, "distance": closest_dist}


# --- Combat Resolution (Narrative Actions) ---

# Assess aftermath - Phase 1 narrative action after combat
func assess_aftermath(_char_uid: int, tactics_skill: int) -> Dictionary:
	# Uses CoreMechanicsAPI for action check
	var approach = Constants.ActionApproach.CAUTIOUS
	var result = CoreMechanicsAPI.perform_action_check(tactics_skill, 0, 0, approach)
	
	var success = result.result_tier in ["CritSuccess", "SuccessWithCost", "Success"]
	
	if success:
		# Could reveal faction info, salvage opportunities, etc.
		return {
			"success": true,
			"result": result,
			"findings": {
				"faction_revealed": randf() > 0.5,
				"salvage_quality": "standard" if result.result_tier != "CritSuccess" else "excellent"
			}
		}
	else:
		return {
			"success": false,
			"result": result,
			"consequence": "No useful information found"
		}


# Claim wreckage - Phase 1 narrative action
func claim_wreckage(_char_uid: int, tactics_skill: int, approach: int) -> Dictionary:
	var result = CoreMechanicsAPI.perform_action_check(tactics_skill, 0, 0, approach)
	
	var success = result.result_tier in ["CritSuccess", "SuccessWithCost", "Success"]
	var base_salvage = 50  # Base WP value
	
	if result.result_tier == "CritSuccess":
		return {
			"success": true,
			"result": result,
			"wp_gained": base_salvage * 2,
			"item_found": true
		}
	elif success:
		var wp = base_salvage
		if approach == Constants.ActionApproach.RISKY:
			wp = int(wp * 1.5)
		return {
			"success": true,
			"result": result,
			"wp_gained": wp,
			"item_found": false
		}
	else:
		return {
			"success": false,
			"result": result,
			"wp_gained": 0,
			"consequence": "Wreckage too unstable to salvage"
		}
