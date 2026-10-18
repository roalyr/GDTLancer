# ShipControllerAI: patrol / combat / flee state machine for NPC agents.
# Uses the same commands and ToolController as the player. Child of AgentBody in npc_agent.tscn.

extends Node

const CombatAssessment = preload("res://src/core/systems/combat_assessment.gd")

enum AIState { IDLE, PATROL, COMBAT, FLEE, DISABLED }


var is_hostile: bool = false

var agent_script: RigidBody = null
var _tool_controller: Node = null
var _current_state: int = AIState.IDLE
var _target_agent: RigidBody = null
var _home_position: Vector3 = Vector3.ZERO
var _patrol_destination: Vector3 = Vector3.ZERO
var _has_patrol_destination: bool = false
var _repath_timer: float = 0.0
var _scan_timer: float = 0.0
var _orbiting: bool = false
var _provoked: bool = false  # Shot at: chase the attacker from any distance
var skill: float = 0.5  # 0 novice .. 1 veteran: decision speed
var _pending: Dictionary = {}  # A decision being made: {"kind", "target", "timer"}


func _ready() -> void:
	var parent = get_parent()
	if not (parent is RigidBody and parent.has_method("command_move_to")):
		printerr("AI Controller Error: Parent node is not an Agent RigidBody with command methods!")
		set_physics_process(false)
		return
	agent_script = parent
	_tool_controller = parent.get_node_or_null("ToolController")
	_home_position = parent.global_transform.origin
	EventBus.connect("agent_disabled", self, "_on_agent_disabled")
	EventBus.connect("agent_damaged", self, "_on_agent_damaged")


func initialize(config: Dictionary) -> void:
	_home_position = config.get("patrol_center", agent_script.global_transform.origin)
	is_hostile = bool(config.get("hostile", is_hostile))
	skill = clamp(float(config.get("skill", skill)), 0.0, 1.0)
	_change_state(AIState.PATROL if is_hostile else AIState.IDLE)


func get_state() -> int:
	return _current_state


# Distance the AI tries to fight at: the optimal range of the tool that works on the target.
func get_engagement_range() -> float:
	var index: int = _get_attack_tool_index()
	return _tool_controller.get_tool(index).optimal_range if index >= 0 else 0.0


func _get_attack_tool_index() -> int:
	if not is_instance_valid(_tool_controller) or not is_instance_valid(_target_agent):
		return -1
	return _tool_controller.find_tool_for(_target_agent)


func _physics_process(delta: float) -> void:
	_repath_timer = max(0.0, _repath_timer - delta)
	_scan_timer = max(0.0, _scan_timer - delta)
	_tick_decision(delta)
	match _current_state:
		AIState.PATROL:
			_process_patrol()
		AIState.COMBAT:
			_process_combat()
		AIState.FLEE:
			_process_flee()


func _change_state(new_state: int) -> void:
	if _current_state == new_state:
		return
	_current_state = new_state
	_repath_timer = 0.0
	_orbiting = false
	if is_instance_valid(_tool_controller):
		_tool_controller.deactivate_all("state_change")

	match _current_state:
		AIState.IDLE, AIState.DISABLED:
			_pending = {}
			_provoked = false
			_target_agent = null
			_has_patrol_destination = false
			agent_script.command_stop()
		AIState.PATROL:
			_provoked = false
			_target_agent = null
			_has_patrol_destination = false
		AIState.COMBAT:
			agent_script.command_approach(_target_agent)
		AIState.FLEE:
			agent_script.command_flee(_target_agent)


func _process_patrol() -> void:
	if _scan_timer <= 0.0:
		_scan_timer = Constants.AI_SCAN_INTERVAL
		var target = scan_for_target()
		if is_instance_valid(target):
			_consider("engage", target, desire_against(target), Constants.AI_ENGAGE_DESIRE)

	var current_pos = agent_script.global_transform.origin
	if not _has_patrol_destination or current_pos.distance_to(_patrol_destination) <= Constants.AI_PATROL_ARRIVAL_DISTANCE:
		_patrol_destination = _pick_patrol_destination()
		_has_patrol_destination = true
		agent_script.command_move_to(_patrol_destination)


func _process_combat() -> void:
	if not _is_live_target(_target_agent):
		_change_state(AIState.PATROL)
		return
	if not _provoked and not agent_script.detects(_target_agent):
		_change_state(AIState.PATROL)  # Lost contact
		return
	# Keep weighing the fight: break off once it stops being worth it.
	if _scan_timer <= 0.0:
		_scan_timer = Constants.AI_SCAN_INTERVAL
		var desire: float = desire_against(_target_agent)
		if desire < Constants.AI_DISENGAGE_DESIRE:
			_consider("disengage", _target_agent, desire, Constants.AI_DISENGAGE_DESIRE)
		elif _pending.get("kind") == "disengage":
			_pending = {}  # The fight turned back: keep at it

	var distance: float = agent_script.global_transform.origin.distance_to(_target_agent.global_transform.origin)
	# Close to optimal range, then orbit there; re-approach if pushed out.
	var engagement_range: float = get_engagement_range()
	if distance > engagement_range * 1.2:
		if _orbiting or _repath_timer <= 0.0:
			_orbiting = false
			_repath_timer = Constants.AI_REPATH_INTERVAL
			agent_script.command_approach(_target_agent)
	elif not _orbiting:
		_orbiting = true
		agent_script.command_orbit(_target_agent)

	# Keep the attack tool on the target; ToolController stops it on its own when power runs out.
	var index: int = _get_attack_tool_index()
	if index >= 0:
		var tool_template = _tool_controller.get_tool(index)
		var in_reach: bool = distance <= tool_template.get_max_range()
		var enough_power: bool = agent_script.power >= tool_template.power_per_cycle
		if in_reach and enough_power and not _tool_controller.is_active(index):
			_tool_controller.activate(index, _target_agent)


func _process_flee() -> void:
	if not _is_live_target(_target_agent):
		_change_state(AIState.PATROL)
		return
	var distance: float = agent_script.global_transform.origin.distance_to(_target_agent.global_transform.origin)
	if distance > Constants.AI_FLEE_DISTANCE or not agent_script.detects(_target_agent):
		_change_state(AIState.PATROL)
		return
	if _repath_timer <= 0.0:
		_repath_timer = Constants.AI_REPATH_INTERVAL
		agent_script.command_flee(_target_agent)


# The detected non-hostile ship most worth attacking, if any is worth it at all.
func scan_for_target() -> RigidBody:
	var best: RigidBody = null
	var best_desire: float = Constants.AI_ENGAGE_DESIRE
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body == agent_script or not _is_live_target(body) or body.get("is_hostile"):
			continue
		if not agent_script.detects(body):
			continue
		var desire: float = desire_against(body)
		if desire >= best_desire:
			best = body
			best_desire = desire
	return best


# How much this ship wants to fight `target` (see Constants AI block and CombatAssessment).
func desire_against(target) -> float:
	return compute_desire(
		agent_script.hull, agent_script.get_damage_per_second(),
		target.hull, target.get_damage_per_second(), target.get_salvage_value()
	)


static func compute_desire(own_hull: float, own_dps: float, target_hull: float, target_dps: float, gain: float) -> float:
	return CombatAssessment.compute_desire(own_hull, own_dps, target_hull, target_dps, gain)


func _is_live_target(body) -> bool:
	return is_instance_valid(body) and body.is_inside_tree() and not body.get("is_wreck")


func _pick_patrol_destination() -> Vector3:
	var direction = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
	return _home_position + direction * randf() * Constants.AI_PATROL_RADIUS


func _on_agent_disabled(agent_body) -> void:
	if agent_body == agent_script:
		_change_state(AIState.DISABLED)


# Shot at by anyone: turn on the attacker and close in however far away it fired from, if the
# fight is worth it; otherwise flee from it.
func _on_agent_damaged(agent_body, _amount, source) -> void:
	if agent_body != agent_script or not _is_live_target(source) or source == agent_script:
		return
	if _current_state in [AIState.DISABLED, AIState.FLEE]:
		return
	if _current_state == AIState.COMBAT and _target_agent == source:
		_provoked = true
		return
	# Shot at: once it has made up its mind, fight back if the rule says so, otherwise run.
	_consider("respond", source, desire_against(source), Constants.AI_DISENGAGE_DESIRE)


# --- Decisions take time (see Constants AI block) ---

# Starts making a decision unless the same one is already under way.
func _consider(kind: String, target, desire: float, threshold: float) -> void:
	if _pending.get("kind") == kind and _pending.get("target") == target:
		return
	_pending = {"kind": kind, "target": target, "timer": decision_delay(desire, threshold)}


# Seconds this NPC takes to decide: slower for novices and for close calls, never exactly the same.
func decision_delay(desire: float, threshold: float) -> float:
	var base: float = lerp(Constants.AI_DECISION_DELAY_SLOW, Constants.AI_DECISION_DELAY_FAST, skill)
	var ambiguity: float = 1.0 - clamp(abs(desire - threshold) / max(threshold, 0.001), 0.0, 1.0)
	var jitter: float = rand_range(1.0 - Constants.AI_DECISION_RANDOMNESS, 1.0 + Constants.AI_DECISION_RANDOMNESS)
	return base * (1.0 + Constants.AI_DECISION_AMBIGUITY_WEIGHT * ambiguity) * jitter


func has_pending_decision() -> bool:
	return not _pending.empty()


func _tick_decision(delta: float) -> void:
	if _pending.empty():
		return
	_pending.timer -= delta
	if _pending.timer > 0.0:
		return
	var decision: Dictionary = _pending
	_pending = {}
	var target = decision.target
	if not _is_live_target(target) or _current_state == AIState.DISABLED:
		return
	# Re-check: act only if the rule still says so now.
	var desire: float = desire_against(target)
	match decision.kind:
		"engage":
			if _current_state == AIState.PATROL and agent_script.detects(target) and desire >= Constants.AI_ENGAGE_DESIRE:
				_start_combat(target, false)
		"disengage":
			if _current_state == AIState.COMBAT and desire < Constants.AI_DISENGAGE_DESIRE:
				_change_state(AIState.FLEE)
		"respond":
			if _current_state in [AIState.FLEE, AIState.DISABLED]:
				return
			if desire >= Constants.AI_DISENGAGE_DESIRE:
				_start_combat(target, true)
			else:
				_target_agent = target
				_change_state(AIState.FLEE)


func _start_combat(target, provoked: bool) -> void:
	_target_agent = target
	_provoked = provoked
	_current_state = AIState.IDLE  # Re-enter combat so the approach starts toward the target
	_change_state(AIState.COMBAT)

