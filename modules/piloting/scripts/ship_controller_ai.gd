
# File: modules/piloting/scripts/ship_controller_ai.gd
# Attach to Node child of AgentBody in npc_agent.tscn
# Version 3.0 - Sprint 9: Combat encounter AI state machine

extends Node

enum AIState { IDLE, PATROL, COMBAT, FLEE, DISABLED }

# --- Configuration ---
export var aggro_range: float = 800.0
export var weapon_range: float = 500.0
export var flee_hull_threshold: float = 0.2
export var patrol_radius: float = 200.0
export var is_hostile: bool = false

# --- References ---
var agent_script: Node = null

# --- State ---
var _current_state: int = AIState.IDLE
var _target_agent: KinematicBody = null
var _home_position: Vector3 = Vector3.ZERO
var _weapon_controller: Node = null

var _patrol_destination: Vector3 = Vector3.ZERO
var _has_patrol_destination: bool = false

var _repath_timer: float = 0.0
const _REPATH_INTERVAL: float = 0.5

var _halted_in_range: bool = false

var _fire_timer: float = 0.0
const AI_FIRE_INTERVAL: float = 1.5  # Seconds between fire attempts

var _weapon_range_initialized: bool = false


func _ready() -> void:
	var parent = get_parent()
	if parent is KinematicBody and parent.has_method("command_move_to"):
		agent_script = parent
		_weapon_controller = parent.get_node_or_null("WeaponController")
		_home_position = parent.global_transform.origin
		set_physics_process(true)
	else:
		printerr(
			"AI Controller Error: Parent node is not an Agent KinematicBody with command methods!"
		)
		set_physics_process(false)
		set_script(null)
		return

	if is_instance_valid(EventBus):
		if not EventBus.is_connected("agent_disabled", self, "_on_agent_disabled"):
			EventBus.connect("agent_disabled", self, "_on_agent_disabled")

	# WeaponController loads weapons deferred; retry a few times to sync AI weapon_range.
	call_deferred("_deferred_init_weapon_range")


func _deferred_init_weapon_range() -> void:
	for _i in range(20):
		if _try_init_weapon_range_from_weapon_controller():
			_weapon_range_initialized = true
			return
		yield(get_tree().create_timer(0.1), "timeout")


func _try_init_weapon_range_from_weapon_controller() -> bool:
	if not is_instance_valid(_weapon_controller) and is_instance_valid(agent_script):
		_weapon_controller = agent_script.get_node_or_null("WeaponController")
	if not is_instance_valid(_weapon_controller):
		return false
	if not _weapon_controller.has_method("get_weapon_count"):
		return false
	var count = int(_weapon_controller.call("get_weapon_count"))
	if count <= 0:
		return false
	if not _weapon_controller.has_method("get_weapon"):
		return false
	var weapon = _weapon_controller.call("get_weapon", 0)
	if not weapon:
		return false
	var raw_max = weapon.get("range_max")
	if raw_max == null:
		return false
	var max_range: float = float(raw_max)
	if max_range <= 0.0:
		return false
	# Keep a small safety buffer so we don't orbit exactly at max range.
	weapon_range = max(10.0, max_range * 0.9)
	return true


func initialize(config: Dictionary) -> void:
	if not is_instance_valid(agent_script):
		printerr("AI Initialize Error: Agent script invalid. Cannot configure AI.")
		return

	if config.has("patrol_center") and config.patrol_center is Vector3:
		_home_position = config.patrol_center
	elif config.has("initial_target") and config.initial_target is Vector3:
		_home_position = config.initial_target
	else:
		_home_position = agent_script.global_transform.origin

	is_hostile = bool(config.get("hostile", is_hostile))

	# If hostile: start patrolling/scanning immediately.
	if is_hostile:
		_change_state(AIState.PATROL)
		return

	# Preserve prior behavior for non-hostile NPCs: optionally move once.
	if config.has("initial_target") and config.initial_target is Vector3:
		agent_script.command_move_to(config.initial_target)


func _physics_process(delta: float) -> void:
	match _current_state:
		AIState.IDLE:
			_process_idle(delta)
		AIState.PATROL:
			_process_patrol(delta)
		AIState.COMBAT:
			_process_combat(delta)
		AIState.FLEE:
			_process_flee(delta)
		AIState.DISABLED:
			pass


func _change_state(new_state: int) -> void:
	if _current_state == new_state:
		return

	_current_state = new_state
	_halted_in_range = false
	_repath_timer = 0.0
	_fire_timer = 0.0

	match _current_state:
		AIState.IDLE:
			_target_agent = null
			_has_patrol_destination = false
			if is_instance_valid(agent_script) and agent_script.has_method("command_stop"):
				agent_script.command_stop()
		AIState.PATROL:
			_target_agent = null
			_has_patrol_destination = false
		AIState.COMBAT:
			# Entry action: start approaching target if possible.
			if is_instance_valid(agent_script) and is_instance_valid(_target_agent):
				if agent_script.has_method("command_approach"):
					agent_script.command_approach(_target_agent)
				else:
					agent_script.command_move_to(_target_agent.global_transform.origin)
		AIState.FLEE:
			# Entry action: flee from target if possible.
			if is_instance_valid(agent_script) and is_instance_valid(_target_agent):
				if agent_script.has_method("command_flee"):
					agent_script.command_flee(_target_agent)
				else:
					var flee_pos = _calculate_flee_position()
					agent_script.command_move_to(flee_pos)
		AIState.DISABLED:
			if is_instance_valid(agent_script) and agent_script.has_method("command_stop"):
				agent_script.command_stop()
			_target_agent = null
			_has_patrol_destination = false


func _process_idle(_delta: float) -> void:
	if not is_hostile:
		return
	var target = _scan_for_target()
	if is_instance_valid(target):
		_target_agent = target
		_change_state(AIState.COMBAT)


func _process_patrol(_delta: float) -> void:
	if not is_hostile:
		_change_state(AIState.IDLE)
		return

	var target = _scan_for_target()
	if is_instance_valid(target):
		_target_agent = target
		_change_state(AIState.COMBAT)
		return

	if not is_instance_valid(agent_script):
		return

	var current_pos = agent_script.global_transform.origin
	if not _has_patrol_destination or current_pos.distance_to(_patrol_destination) <= 10.0:
		_patrol_destination = _pick_patrol_destination()
		_has_patrol_destination = true
		agent_script.command_move_to(_patrol_destination)


func _process_combat(delta: float) -> void:
	if not is_hostile:
		_change_state(AIState.IDLE)
		return

	if not is_instance_valid(agent_script):
		_change_state(AIState.IDLE)
		return

	if not is_instance_valid(_target_agent):
		_change_state(AIState.PATROL)
		return

	var self_pos: Vector3 = agent_script.global_transform.origin
	var target_pos: Vector3 = _target_agent.global_transform.origin
	var distance: float = self_pos.distance_to(target_pos)

	# Drop combat if target out of aggro range.
	if distance > aggro_range:
		_target_agent = null
		_change_state(AIState.PATROL)
		return

	# Hull check only valid if CombatSystem has state for this agent.
	if is_instance_valid(GlobalRefs.combat_system) and GlobalRefs.combat_system.has_method("is_in_combat"):
		if GlobalRefs.combat_system.is_in_combat(int(agent_script.agent_uid)):
			var hull_pct: float = GlobalRefs.combat_system.get_hull_percent(int(agent_script.agent_uid))
			if hull_pct > 0.0 and hull_pct < flee_hull_threshold:
				_change_state(AIState.FLEE)
				return

	# Approach target until within weapon range.
	_repath_timer = max(0.0, _repath_timer - delta)
	if distance > weapon_range:
		_halted_in_range = false
		if _repath_timer <= 0.0:
			_repath_timer = _REPATH_INTERVAL
			if agent_script.has_method("command_approach"):
				agent_script.command_approach(_target_agent)
			else:
				agent_script.command_move_to(target_pos)
	else:
		# In weapon range: orbit the player instead of just stopping
		if not _halted_in_range:
			_halted_in_range = true
			if agent_script.has_method("command_orbit"):
				agent_script.command_orbit(_target_agent)

		_fire_timer = max(0.0, _fire_timer - delta)
		if _fire_timer <= 0.0 and _is_in_weapon_range():
			_try_fire_weapon()


func _try_fire_weapon() -> void:
	if not is_instance_valid(_weapon_controller) and is_instance_valid(agent_script):
		_weapon_controller = agent_script.get_node_or_null("WeaponController")

	if not is_instance_valid(_weapon_controller):
		return
	if not is_instance_valid(_target_agent):
		return

	var target_pos: Vector3 = _target_agent.global_transform.origin
	var raw_target_uid = _target_agent.get("agent_uid")
	var target_uid: int = -1
	if raw_target_uid != null:
		target_uid = int(raw_target_uid)

	var result: Dictionary = _weapon_controller.fire_at_target(0, target_uid, target_pos)

	if result.get("success", false):
		_fire_timer = AI_FIRE_INTERVAL
	elif result.get("reason") == "Weapon on cooldown":
		_fire_timer = float(result.get("cooldown", 0.5))


func _is_in_weapon_range() -> bool:
	if not is_instance_valid(_target_agent) or not is_instance_valid(agent_script):
		return false
	var distance = agent_script.global_transform.origin.distance_to(_target_agent.global_transform.origin)
	return distance <= weapon_range


func _process_flee(delta: float) -> void:
	if not is_instance_valid(agent_script):
		_change_state(AIState.IDLE)
		return

	if not is_instance_valid(_target_agent):
		_change_state(AIState.PATROL)
		return

	var self_pos: Vector3 = agent_script.global_transform.origin
	var target_pos: Vector3 = _target_agent.global_transform.origin
	var distance: float = self_pos.distance_to(target_pos)

	if distance > aggro_range * 2.0:
		# Don't despawn just because we fled far away; that makes encounters feel broken.
		# Instead, drop combat target and resume patrol.
		_target_agent = null
		_change_state(AIState.PATROL)
		return

	_repath_timer = max(0.0, _repath_timer - delta)
	if _repath_timer <= 0.0:
		_repath_timer = _REPATH_INTERVAL
		if agent_script.has_method("command_flee"):
			agent_script.command_flee(_target_agent)
		else:
			var flee_pos = _calculate_flee_position()
			agent_script.command_move_to(flee_pos)


func _scan_for_target() -> KinematicBody:
	if not is_hostile:
		return null
	var player = GlobalRefs.player_agent_body
	if not is_instance_valid(player) and is_instance_valid(GlobalRefs.world_manager):
		player = GlobalRefs.world_manager.get("player_agent")
	if not is_instance_valid(player):
		return null
	if not is_instance_valid(agent_script):
		return null

	var distance = agent_script.global_transform.origin.distance_to(player.global_transform.origin)
	if distance <= aggro_range:
		return player
	return null


func _pick_patrol_destination() -> Vector3:
	# Simple random offset within patrol_radius on XZ plane.
	var angle: float = randf() * TAU
	var radius: float = randf() * patrol_radius
	var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * radius
	return _home_position + offset


func _calculate_flee_position() -> Vector3:
	if not is_instance_valid(agent_script) or not is_instance_valid(_target_agent):
		return _home_position
	var self_pos: Vector3 = agent_script.global_transform.origin
	var target_pos: Vector3 = _target_agent.global_transform.origin
	var away: Vector3 = (self_pos - target_pos)
	if away.length() <= 0.001:
		away = Vector3(1, 0, 0)
	away = away.normalized()
	return self_pos + away * aggro_range


func _on_agent_disabled(agent_body) -> void:
	if is_instance_valid(agent_script) and agent_body == agent_script:
		_change_state(AIState.DISABLED)
