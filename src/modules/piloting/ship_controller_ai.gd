# ShipControllerAI: state machine for NPC agents. Patrols, fights enemies (other factions at war
# with its own, or ships that shot it), flees fights not worth it (shooting back at its pursuer
# as it goes), strips wrecks, and with a full
# hold flies back to where it came from and leaves the sector.
# Decisions take time (skill, how close the call is): meanwhile the ship HESITATES, a state of its
# own the player can read. It turns its nose on the ship in question and eases off to a drift,
# holding fire; one wavering over breaking off a fight keeps fighting meanwhile. Being shot while
# hesitating turns any pending decision into one about the shooter, without starting over.
# Uses the same commands and ToolController as the player. Child of AgentBody in npc_agent.tscn.

extends Node

const FrameProfiler = preload("res://src/core/utils/frame_profiler.gd")

const CombatAssessment = preload("res://src/core/systems/combat_assessment.gd")

enum AIState { IDLE, PATROL, COMBAT, FLEE, DISABLED, SALVAGE, DEPART, HESITATE }

# What the player reads off a ship's behaviour (see the parity rule in the README).
const ACTIVITY_LABELS = {
	AIState.PATROL: "PATROLLING", AIState.COMBAT: "FIGHTING", AIState.FLEE: "FLEEING",
	AIState.SALVAGE: "SALVAGING", AIState.DEPART: "HAULING", AIState.HESITATE: "HESITATING",
}

# Which pending decision gives way to which (higher wins): being shot outranks anything else.
const DECISION_PRIORITY = {"engage": 0, "disengage": 0, "respond": 1}


var agent_script: RigidBody = null
var _tool_controller: Node = null
var _current_state: int = AIState.IDLE
var _target_agent: RigidBody = null
var _home_position: Vector3 = Vector3.ZERO  # Middle of its patrol
var _home_point: Vector3 = Vector3.ZERO  # Where it came from; it leaves the sector from there
var _patrol_destination: Vector3 = Vector3.ZERO
var _has_patrol_destination: bool = false
var _repath_timer: float = 0.0
var _scan_timer: float = 0.0
var _orbiting: bool = false
var _provoked: bool = false  # Shot at: chase the attacker from any distance
var skill: float = 0.5  # 0 novice .. 1 veteran: decision speed
var _pending: Dictionary = {}  # A decision being made: {"kind", "target", "timer"}
var _resume_state: int = AIState.PATROL  # What it was doing before it started hesitating
var _resume_target: RigidBody = null  # and on what
var _think_elapsed: float = 0.0  # s since it last thought
var _think_due: float = randf() * Constants.AI_THINK_INTERVAL  # First think staggered across ships


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
	_home_point = config.get("home_point", agent_script.global_transform.origin)
	skill = clamp(float(config.get("skill", skill)), 0.0, 1.0)
	_change_state(AIState.PATROL)


func get_state() -> int:
	return _current_state


func get_activity_label() -> String:
	return ACTIVITY_LABELS.get(_current_state, "")


# The ship it is fighting, fleeing from or salvaging, if any.
func get_focus() -> Node:
	return _target_agent if is_instance_valid(_target_agent) else null


# Distance the AI tries to fight at: the optimal range of the tool that works on the target.
func get_engagement_range() -> float:
	var index: int = _get_attack_tool_index()
	return _tool_controller.get_tool(index).optimal_range if index >= 0 else 0.0


func _get_attack_tool_index() -> int:
	if not is_instance_valid(_tool_controller) or not is_instance_valid(_target_agent):
		return -1
	return _tool_controller.find_tool_for(_target_agent)


# Thinks every Constants.AI_THINK_INTERVAL (ships staggered), on the time gone since: the commands
# and tool cycles it sets run on by themselves in between, and thinking every step was the second
# costliest part of a physics step.
func _physics_process(delta: float) -> void:
	_think_elapsed += delta
	if _think_elapsed < _think_due:
		return
	_think_due = Constants.AI_THINK_INTERVAL
	FrameProfiler.begin(get_tree(), "ai")
	_think(_think_elapsed)
	FrameProfiler.end(get_tree(), "ai")
	_think_elapsed = 0.0


func _think(delta: float) -> void:
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
		AIState.SALVAGE:
			_process_salvage()
		AIState.DEPART:
			_process_depart()
		AIState.HESITATE:
			_process_hesitate()


func _change_state(new_state: int) -> void:
	if _current_state == new_state:
		return
	_current_state = new_state
	_repath_timer = 0.0
	_orbiting = false
	var keeps_fighting: bool = new_state == AIState.HESITATE and _resume_state == AIState.COMBAT
	if is_instance_valid(_tool_controller) and not keeps_fighting:
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
		AIState.SALVAGE:
			agent_script.command_approach(_target_agent)
		AIState.DEPART:
			_provoked = false
			_target_agent = null
			agent_script.command_move_to(_home_point)
		AIState.HESITATE:
			if not keeps_fighting:
				agent_script.command_watch(_target_agent)


func _process_patrol() -> void:
	if _scan_timer <= 0.0:
		_scan_timer = Constants.AI_SCAN_INTERVAL
		var target = scan_for_target()
		if is_instance_valid(target):
			_consider("engage", target, desire_against(target), Constants.AI_ENGAGE_DESIRE)
			return
		elif _pending.empty():
			if agent_script.get_free_cargo() <= 0:
				_change_state(AIState.DEPART)
				return
			var wreck = scan_for_wreck()
			if is_instance_valid(wreck):
				_target_agent = wreck
				_change_state(AIState.SALVAGE)
				return

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
			return

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

	_fire_at(_target_agent)


# Keeps every weapon that works on `target` and reaches it on it; ToolController stops each on its
# own when power runs out.
func _fire_at(target) -> void:
	if not is_instance_valid(_tool_controller):
		return
	var distance: float = agent_script.global_transform.origin.distance_to(target.global_transform.origin)
	for index in range(_tool_controller.get_tool_count()):
		var tool_template = _tool_controller.get_tool(index)
		if not _tool_controller.can_target(tool_template, target):
			continue
		var in_reach: bool = distance <= tool_template.get_max_range()
		var enough_power: bool = agent_script.power >= tool_template.power_per_cycle
		if in_reach and enough_power and not _tool_controller.is_active(index):
			_tool_controller.activate(index, target)


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
	_fire_at(_target_agent)  # Running, but shooting back at whatever reaches


# Close in on a wreck, harpoon it and strip it until it is empty or the hold is full. Enemies
# that show up come first.
func _process_salvage() -> void:
	var wreck = _target_agent
	if not (is_instance_valid(wreck) and wreck.is_inside_tree() and wreck.get("is_wreck") and wreck.get_salvage_units() > 0) or agent_script.get_free_cargo() <= 0:
		_change_state(AIState.PATROL)
		return
	if _scan_timer <= 0.0:
		_scan_timer = Constants.AI_SCAN_INTERVAL
		var enemy = scan_for_target()
		if is_instance_valid(enemy):
			_consider("engage", enemy, desire_against(enemy), Constants.AI_ENGAGE_DESIRE)
			return
	var index: int = _tool_controller.find_tool_for(wreck) if is_instance_valid(_tool_controller) else -1
	if index < 0:
		if not agent_script.detects(wreck):
			_change_state(AIState.PATROL)
		return  # No harpoon fitted, or not seen yet: keep closing in
	var harpoon_range: float = _tool_controller.get_tool(index).optimal_range
	var distance: float = agent_script.global_transform.origin.distance_to(wreck.global_transform.origin)
	if not _tool_controller.is_active(index):
		_tool_controller.activate(index, wreck)  # Launches once in reach
	if distance <= harpoon_range * 0.8 and not _orbiting:
		_orbiting = true  # Here: in reach; stop and let the tether reel it in
		agent_script.command_stop()
	elif distance > harpoon_range and _orbiting:
		_orbiting = false
		agent_script.command_approach(wreck)


# Making up its mind about _target_agent (the decision in _pending, resolved by _tick_decision).
# Wavering over breaking off a fight: keeps fighting, and drops the thought if the fight turns back.
func _process_hesitate() -> void:
	if _pending.empty() or not _is_live_target(_target_agent):
		_pending = {}
		_resume()
		return
	if _resume_state != AIState.COMBAT:
		return  # Watching it (command_watch), holding fire
	if _is_live_target(_resume_target):
		_fire_at(_resume_target)
	if _pending.kind == "disengage" and _scan_timer <= 0.0:
		_scan_timer = Constants.AI_SCAN_INTERVAL
		if desire_against(_target_agent) >= Constants.AI_DISENGAGE_DESIRE:
			_pending = {}
			_resume()  # The fight turned back: keep at it


# Back to what it was doing before it hesitated (patrol, if that is over).
func _resume() -> void:
	var state: int = _resume_state
	var target = _resume_target
	_resume_target = null
	if state == AIState.COMBAT and not _is_live_target(target):
		state = AIState.PATROL
	if state == AIState.SALVAGE and not (is_instance_valid(target) and target.is_inside_tree() and target.get("is_wreck")):
		state = AIState.PATROL
	_target_agent = target
	var provoked: bool = _provoked
	_current_state = AIState.IDLE  # Re-enter, so the state's command starts again
	_change_state(state)
	if state == AIState.COMBAT:
		_provoked = provoked


# Full hold: fly back to where it came from and leave the sector with the loot.
func _process_depart() -> void:
	if agent_script.global_transform.origin.distance_to(_home_point) <= Constants.AI_DEPART_ARRIVAL_DISTANCE:
		_change_state(AIState.IDLE)
		agent_script.despawn()
		return
	if _repath_timer <= 0.0:
		_repath_timer = Constants.AI_REPATH_INTERVAL * 4.0
		agent_script.command_move_to(_home_point)


# The nearest detected wreck with something left on it that nobody else has harpooned.
func scan_for_wreck() -> RigidBody:
	var best: RigidBody = null
	var best_distance: float = Constants.AI_SALVAGE_SEARCH_RANGE
	var own_pos: Vector3 = agent_script.global_transform.origin
	for body in get_tree().get_nodes_in_group("agent_body"):
		if not (body.get("is_wreck") and body.get_salvage_units() > 0 and agent_script.detects(body)):
			continue
		var distance: float = own_pos.distance_to(body.global_transform.origin)
		if distance < best_distance and not _is_claimed(body):
			best = body
			best_distance = distance
	return best


func _is_claimed(wreck) -> bool:
	for body in get_tree().get_nodes_in_group("agent_body"):
		var tools = body.get_node_or_null("ToolController") if body != agent_script else null
		if tools == null:
			continue
		for index in range(tools.get_tool_count()):
			if tools.get_target(index) == wreck:
				return true
	return false


# The detected enemy most worth attacking, if any is worth it at all.
func scan_for_target() -> RigidBody:
	var best: RigidBody = null
	var best_desire: float = Constants.AI_ENGAGE_DESIRE
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body == agent_script or not _is_live_target(body) or not agent_script.is_enemy_of(body):
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
	var desire: float = compute_desire(
		agent_script.hull, agent_script.get_damage_per_second(),
		target.hull, target.get_damage_per_second(), target.get_salvage_value()
	)
	return desire * (Constants.AI_ENEMY_DESIRE_FACTOR if agent_script.is_enemy_of(target) else 1.0)


static func compute_desire(own_hull: float, own_dps: float, target_hull: float, target_dps: float, gain: float) -> float:
	return CombatAssessment.compute_desire(own_hull, own_dps, target_hull, target_dps, gain)


func _is_live_target(body) -> bool:
	return is_instance_valid(body) and body.is_inside_tree() and not body.get("is_wreck") and not body.get("is_docked")


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
	var fighting = _target_agent if _current_state == AIState.COMBAT else null
	if _current_state == AIState.HESITATE and _resume_state == AIState.COMBAT:
		fighting = _resume_target
	if fighting != null and fighting == source:
		_provoked = true
		return
	# Shot at: once it has made up its mind, fight back if the rule says so, otherwise run.
	_consider("respond", source, desire_against(source), Constants.AI_DISENGAGE_DESIRE)


# --- Decisions take time (see Constants AI block) ---

# Starts making a decision, and hesitates while it does. A decision already under way stands, except
# that being shot (a "respond") takes over: about the same ship it keeps the time already spent
# thinking, about another it starts over.
func _consider(kind: String, target, desire: float, threshold: float) -> void:
	var delay: float = decision_delay(desire, threshold)
	if not _pending.empty():
		if DECISION_PRIORITY.get(kind, 0) <= DECISION_PRIORITY.get(_pending.kind, 0):
			return
		if _pending.target == target:
			_pending.kind = kind
			_pending.timer = min(_pending.timer, delay)
			return
	_pending = {"kind": kind, "target": target, "timer": delay}
	if _current_state != AIState.HESITATE:
		_resume_state = _current_state
		_resume_target = _target_agent
		_target_agent = target
		_change_state(AIState.HESITATE)
	else:
		_target_agent = target
		if _resume_state != AIState.COMBAT:
			agent_script.command_watch(target)  # Already hesitating: now about another ship


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
	if _current_state != AIState.HESITATE:
		return
	if not _is_live_target(target):
		_resume()
		return
	# Re-check: act only if the rule still says so now; otherwise carry on as before.
	var desire: float = desire_against(target)
	match decision.kind:
		"engage":
			if agent_script.detects(target) and desire >= Constants.AI_ENGAGE_DESIRE:
				_start_combat(target, false)
			else:
				_resume()
		"disengage":
			if desire < Constants.AI_DISENGAGE_DESIRE:
				_target_agent = target
				_resume_target = null
				_change_state(AIState.FLEE)
			else:
				_resume()
		"respond":
			_resume_target = null
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

