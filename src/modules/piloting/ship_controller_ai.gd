# ShipControllerAI: state machine for NPC agents. Patrols, fights enemies (other factions at war
# with its own, or ships that shot it), flees fights not worth it (shooting back at its pursuer
# as it goes), strips wrecks, and with a full
# hold flies back to where it came from and leaves the sector.
# Arena NPCs (see Arena, Evolution) instead live round their arena's beacon and never leave it: they
# spawn DOCKED at one of their faction's stations, flee to one (and dock: safe, repaired) and haul
# their salvage to one to sell it; old ones retire there. Their behaviour genes set when they
# start and break off a fight, how close they fight, and at what hull they run whatever the odds.
# Runners: a ship running from its target's fight shoots back or not (a roll on its return_fire gene,
# per flight). The pursuer chases only while it reckons it can catch the runner before it is safe
# (pursuit gene), and may let a runner go that is not shooting back (mercy gene): careful ships lose
# gracefully, reckless ones fight to the death. Every NPC has them (defaults in the Constants AI block),
# and every gene bends with desperation: a broke pilot (little WP for its ship's worth) fights at
# worse odds, chases harder, spares less, shoots back more and runs later.
# Prospectors (prospect gene, with a laser, a lance and a harpoon) mine when they have nothing else to
# do: burn a rock's shell off with the laser, ram the bared rock, then harpoon and strip the chunk
# (SALVAGE) and haul it home (Constants MINING).
# Ships with a kinetic lance (lances left, fast enough to strike) ram instead of closing to laser
# range and orbiting, their lasers firing as they reach; the lance is armed only while ramming.
# Decisions take time (skill, how close the call is): meanwhile the ship HESITATES, a state of its
# own the player can read. It turns its nose on the ship in question and eases off to a drift,
# holding fire; one wavering over breaking off a fight keeps fighting meanwhile. Being shot while
# hesitating turns any pending decision into one about the shooter, without starting over.
# Uses the same commands and ToolController as the player. Child of AgentBody in npc_agent.tscn.

extends Node

const FrameProfiler = preload("res://src/core/utils/frame_profiler.gd")

const CombatAssessment = preload("res://src/core/systems/combat_assessment.gd")
const NavigationSystem = preload("res://src/core/agents/components/navigation_system.gd")

enum AIState { IDLE, PATROL, COMBAT, FLEE, DISABLED, SALVAGE, DEPART, HESITATE, DOCKED, MINE }

# What the player reads off a ship's behaviour (see the parity rule in the README).
const ACTIVITY_LABELS = {
	AIState.PATROL: "PATROLLING", AIState.COMBAT: "FIGHTING", AIState.FLEE: "FLEEING",
	AIState.SALVAGE: "SALVAGING", AIState.DEPART: "HAULING", AIState.HESITATE: "HESITATING",
	AIState.DOCKED: "DOCKED", AIState.MINE: "MINING",
}

# Which pending decision gives way to which (higher wins): being shot outranks anything else.
const DECISION_PRIORITY = {"engage": 0, "disengage": 0, "let_go": 0, "assist": 1, "respond": 2}


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
var _aiming: bool = false  # On command_aim (a cannon on the target)
var _provoked: bool = false  # Shot at: chase the attacker from any distance
var skill: float = 0.5  # 0 novice .. 1 veteran: decision speed
var _pending: Dictionary = {}  # A decision being made: {"kind", "target", "timer"}
var _resume_state: int = AIState.PATROL  # What it was doing before it started hesitating
var _resume_target: RigidBody = null  # and on what
var _think_elapsed: float = 0.0  # s since it last thought
var _think_due: float = randf() * Constants.AI_THINK_INTERVAL  # First think staggered across ships
var _threat = null  # The latest scan's enemy too strong for it that has not seen it (_keep_clear)
var _avoided = null  # The one it last kept clear of
var _arena: Dictionary = {}  # Arena NPCs: {"zone_id", "beacon" (Vector3), "stations" (its faction's)}
var _station: Spatial = null  # The station it is heading for or docked at
var _dock_timer: float = 0.0  # s left docked
var _engage_desire: float = Constants.AI_ENGAGE_DESIRE  # Behaviour genes (Constants EVO_BEHAVIOR_RANGES)
var _disengage_desire: float = Constants.AI_DISENGAGE_DESIRE
var _range_factor: float = 1.0
var _retreat_hull: float = 0.0
var _pursuit: float = Constants.AI_PURSUIT  # Chases a runner while catch time * this <= its time to safety
var _mercy: float = Constants.AI_MERCY  # Chance of letting a runner go that is not shooting back
var _return_fire: float = Constants.AI_RETURN_FIRE  # Chance, per flight, that it shoots back running
var _teamwork: float = 1.0  # Times its desire to help friends and join its leader (gene)
var _caution: float = Constants.AI_AVOID_SHARE  # Keeps clear of unseen enemies this much stronger (gene)
var _burn_reserve: float = Constants.AI_AFTERBURNER_RESERVE  # Power share kept from the afterburner (gene)
var _shooting_back: bool = true  # This flight's roll of _return_fire
var _since_hit: float = INF  # s since the ship it fights last hit it
var _runner_judged: bool = false  # Its target's current run has had its mercy roll
var _letting_go: bool = false  # and the roll was to let it go
var _spared: Dictionary = {}  # Instance id -> s left during which it does not go after that ship again
var _ramming: bool = false  # Charging its target with an armed lance (command_ram)
var _prospect: float = 0.0  # Behaviour gene: mines when idle at 0.5 or more (can_mine)
var _haul: float = Constants.AI_HAUL_SHARE  # Behaviour gene: goes home to sell once its hold is worth this share of its ship
var _rock: Spatial = null  # The rock it is mining
var _mine_time: float = 0.0  # s on _rock without a chunk
var _given_up: Dictionary = {}  # Rocks it gave up on (instance id -> true)


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
	EventBus.connect("agent_charged", self, "_on_agent_charged")


func initialize(config: Dictionary) -> void:
	_home_position = config.get("patrol_center", agent_script.global_transform.origin)
	_home_point = config.get("home_point", agent_script.global_transform.origin)
	skill = clamp(float(config.get("skill", skill)), 0.0, 1.0)
	_arena = config.get("arena", {})
	var behavior: Dictionary = config.get("behavior", {})
	_engage_desire = float(behavior.get("engage", Constants.AI_ENGAGE_DESIRE))
	_disengage_desire = float(behavior.get("disengage", Constants.AI_DISENGAGE_DESIRE))
	_range_factor = float(behavior.get("range", 1.0))
	_retreat_hull = float(behavior.get("retreat_hull", 0.0))
	_pursuit = float(behavior.get("pursuit", Constants.AI_PURSUIT))
	_mercy = float(behavior.get("mercy", Constants.AI_MERCY))
	_return_fire = float(behavior.get("return_fire", Constants.AI_RETURN_FIRE))
	_teamwork = float(behavior.get("teamwork", 1.0))
	_caution = float(behavior.get("caution", Constants.AI_AVOID_SHARE))
	_burn_reserve = float(behavior.get("burn", Constants.AI_AFTERBURNER_RESERVE))
	_prospect = float(behavior.get("prospect", 0.0))
	_haul = float(behavior.get("haul", Constants.AI_HAUL_SHARE))
	if is_instance_valid(_tool_controller) and not _tool_controller.is_connected("lance_recovered", self, "_on_lance_recovered"):
		_tool_controller.connect("lance_recovered", self, "_on_lance_recovered")
		_tool_controller.connect("ammo_recovered", self, "_on_ammo_recovered")
	for lance in (agent_script.get_lances() if agent_script.has_method("get_lances") else []):
		if not lance.is_connected("struck", self, "_on_lance_struck"):
			lance.connect("struck", self, "_on_lance_struck")
			lance.connect("glanced", self, "_on_lance_glanced")
	var docked_at = config.get("docked_at")
	if docked_at is Spatial:
		_dock(docked_at, false)
	else:
		_change_state(AIState.PATROL)


func get_state() -> int:
	return _current_state


func get_activity_label() -> String:
	if _ramming and _current_state == AIState.COMBAT:
		return "RAMMING"
	return ACTIVITY_LABELS.get(_current_state, "")


# Out of the way of an enemy too strong for it that has not seen it: patrols on the far side of home.
func _keep_clear(threat) -> void:
	var away: Vector3 = agent_script.global_transform.origin - threat.global_transform.origin
	away = away.normalized() if away.length_squared() > 1.0 else Vector3.FORWARD
	var point: Vector3 = agent_script.global_transform.origin + away * Constants.AI_PATROL_RADIUS
	if not _in_arena(point):
		point = _home_position + away * Constants.AI_PATROL_RADIUS * 0.5
	if threat != _avoided:
		_avoided = threat
		_note("avoided")
	_patrol_destination = point
	_has_patrol_destination = true
	agent_script.command_move_to(point)


# Its group's leader (Evolution ranks; Constants RENOWN_*), unless it leads or has none.
func get_leader() -> Node:
	if _arena.empty() or agent_script.evo_uid == "" or _teamwork < Constants.AI_FOLLOW_MIN_TEAMWORK:
		return null
	var leader = Evolution.leader_of(agent_script.faction, _arena.zone_id)
	return leader if leader != agent_script else null


# A follower joins the fight its leader is in, as it would go to help any friend under fire.
func _join_leader() -> bool:
	var leader = get_leader()
	if leader == null:
		return false
	var leader_ai = leader.get_node_or_null(Constants.AI_CONTROLLER_NODE_NAME)
	if leader_ai == null or not leader_ai.has_method("get_state") or leader_ai.get_state() != AIState.COMBAT:
		return false
	var target = leader_ai.get_focus()
	if not _is_live_target(target):
		return false
	_assist(leader, target)
	if not _pending.empty() and _pending.kind == "assist":
		_note("followed")
		return true
	return false


# The ship it is fighting, fleeing from or salvaging, if any.
func get_focus() -> Node:
	return _target_agent if is_instance_valid(_target_agent) else null


# Distance the AI tries to fight at: a cannon's optimal range if it has one with rounds (a gunner
# keeps out of laser reach, its lasers firing when they reach), otherwise the shortest optimal range
# among the weapons that work on the target (and have rounds left), so all of them reach; times its
# range gene.
func get_engagement_range() -> float:
	if not is_instance_valid(_tool_controller) or not is_instance_valid(_target_agent):
		return 0.0
	var cannon: int = _tool_controller.find_cannon_for(_target_agent)
	if cannon >= 0:
		return _tool_controller.get_tool(cannon).optimal_range * _range_factor
	var best: float = INF
	for index in range(_tool_controller.get_tool_count()):
		var tool_template = _tool_controller.get_tool(index)
		if tool_template.tool_type == "harpoon" or not _tool_controller.can_target(tool_template, _target_agent):
			continue
		if _tool_controller.has_magazine(index) and _tool_controller.get_ammo(index) <= 0:
			continue
		best = min(best, tool_template.optimal_range)
	return best * _range_factor if best < INF else 0.0


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
	_since_hit += delta
	for id in _spared.keys():
		_spared[id] -= delta
		if _spared[id] <= 0.0:
			_spared.erase(id)
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
		AIState.DOCKED:
			_process_docked(delta)
		AIState.MINE:
			_process_mine(delta)
	_update_afterburner()


# Lights the afterburner (if fitted) to run, to charge with the lance, to catch a runner or to close
# from far out; keeps its burn gene's share of its power for its weapons, except when running.
func _update_afterburner() -> void:
	if not agent_script.has_method("has_afterburner") or not agent_script.has_afterburner():
		return
	var want := false
	if _current_state == AIState.FLEE:
		want = true
	elif _current_state == AIState.COMBAT and _is_live_target(_target_agent):
		var distance: float = agent_script.global_transform.origin.distance_to(_target_agent.global_transform.origin)
		want = is_ram_committed() or is_running_from_me(_target_agent) or distance > get_engagement_range() * Constants.AI_AFTERBURNER_CLOSE_FACTOR
		if agent_script.power < agent_script.power_max * _burn_reserve:
			want = false
	agent_script.set_afterburner(want)

func _change_state(new_state: int) -> void:
	if _current_state == new_state:
		return
	_current_state = new_state
	_repath_timer = 0.0
	_orbiting = false
	_aiming = false
	var keeps_fighting: bool = new_state == AIState.HESITATE and _resume_state == AIState.COMBAT
	if not keeps_fighting:
		_stop_ramming()
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
			_shooting_back = randf() < _return_fire_level()
			_note("fled")
			if not _shooting_back:
				_note("held_fire")
			if not _arena.empty():
				_station = _pick_refuge(_target_agent)
			if is_instance_valid(_station) and not _arena.empty():
				agent_script.command_move_to(_station.get_undock_position())
			else:
				agent_script.command_flee(_target_agent)
		AIState.SALVAGE:
			agent_script.command_approach(_target_agent)
		AIState.DEPART:
			_provoked = false
			_target_agent = null
			if not _arena.empty():
				_station = _pick_refuge(null)
			if is_instance_valid(_station) and not _arena.empty():
				agent_script.command_move_to(_station.get_undock_position())
			else:
				agent_script.command_move_to(_home_point)
		AIState.DOCKED:
			_pending = {}
			_provoked = false
			_target_agent = null
			agent_script.command_stop()
		AIState.HESITATE:
			if not keeps_fighting:
				agent_script.command_watch(_target_agent)
		AIState.MINE:
			_mine_time = 0.0
			_ramming = false


func _process_patrol() -> void:
	if _scan_timer <= 0.0:
		_scan_timer = Constants.AI_SCAN_INTERVAL
		var lance = _lance_to_collect()
		if is_instance_valid(lance):
			_target_agent = lance
			_change_state(AIState.SALVAGE)
			return
		var target = scan_for_target()
		if is_instance_valid(target):
			_consider("engage", target, desire_against(target), _engage_level())
			return
		elif _join_leader():
			return
		elif is_instance_valid(_threat) and _pending.empty():
			_keep_clear(_threat)
			return
		elif _pending.empty():
			var wreck = scan_for_wreck()
			var lances_there: bool = is_instance_valid(wreck) and (wreck.recoverable_lances_for(agent_script) > 0 or _recoverable_ammo(wreck) > 0)
			if ((agent_script.get_free_cargo() <= 0 or hold_worth_hauling()) and not lances_there) or _due_home():
				_change_state(AIState.DEPART)
				return
			if is_instance_valid(wreck):
				_target_agent = wreck
				_change_state(AIState.SALVAGE)
				return
			if can_mine():
				var rock = scan_for_rock()
				if is_instance_valid(rock):
					_rock = rock
					_change_state(AIState.MINE)
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
	if not _in_arena(agent_script.global_transform.origin, 1.3):
		_change_state(AIState.PATROL)  # Chased out of its arena: back to the beacon
		return
	var committed: bool = is_ram_committed()
	if not committed and _should_retreat():
		_change_state(AIState.FLEE)
		return
	# Keep weighing the fight: break off once it stops being worth it.
	if not committed and _scan_timer <= 0.0:
		_scan_timer = Constants.AI_SCAN_INTERVAL
		var desire: float = desire_against(_target_agent)
		if desire < _disengage_level():
			_consider("disengage", _target_agent, desire, _disengage_level())
			return
		if _should_let_go(_target_agent):
			_consider("let_go", _target_agent, chase_margin(_target_agent) * _pursuit_level(), 1.0)
			return

	if _ram(_target_agent):
		_fire_at(_target_agent)
		return
	if can_ram() and is_instance_valid(_tool_controller) and _tool_controller.find_tool_for(_target_agent) < 0:
		_hold_off(_target_agent)  # Only a lance, and charging does not pay now
		return

	var distance: float = agent_script.global_transform.origin.distance_to(_target_agent.global_transform.origin)
	# Close to optimal range, then orbit there (a cannon: aim, holding the range); re-approach if pushed out.
	var engagement_range: float = get_engagement_range()
	var gunner: bool = is_instance_valid(_tool_controller) and _tool_controller.find_cannon_for(_target_agent) >= 0
	if gunner and distance <= engagement_range * 1.2:
		if not _aiming:
			_aiming = true
			_orbiting = false
			agent_script.command_aim(_target_agent, engagement_range)
	elif distance > engagement_range * 1.2:
		_aiming = false
		if _orbiting or _repath_timer <= 0.0:
			_orbiting = false
			_repath_timer = Constants.AI_REPATH_INTERVAL
			agent_script.command_approach(_target_agent)
	elif not _orbiting:
		_orbiting = true
		_aiming = false
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
	if not _arena.empty():
		_process_run_home()
		if _shooting_back and _is_live_target(_target_agent):
			_fire_at(_target_agent)  # Running, but shooting back at whatever reaches
		return
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
	if _shooting_back:
		_fire_at(_target_agent)  # Running, but shooting back at whatever reaches


# Close in on a wreck, harpoon it (with every harpoon it has: each strips on its own cycle) and strip
# it until it is empty or the hold is full. Enemies that show up come first.
func _process_salvage() -> void:
	var wreck = _target_agent
	if not (is_instance_valid(wreck) and wreck.is_inside_tree() and wreck.get("is_wreck") and _worth_salvaging(wreck)):
		_change_state(AIState.PATROL)
		return
	if _scan_timer <= 0.0:
		_scan_timer = Constants.AI_SCAN_INTERVAL
		var enemy = scan_for_target() if not _collecting_lances(wreck) else null
		if is_instance_valid(enemy) and not _busy_mining_past(enemy):
			_consider("engage", enemy, desire_against(enemy), _engage_level())
			return
	if wreck.is_in_group("loose_lance") and wreck.can_be_scooped_by(agent_script):
		return  # Scooped up at its next check
	if wreck.has_method("is_ready_to_strip") and not wreck.is_ready_to_strip():
		_work_chunk(wreck)
		return
	var index: int = _tool_controller.find_tool_for(wreck) if is_instance_valid(_tool_controller) else -1
	if index < 0:
		if not agent_script.detects(wreck):
			_change_state(AIState.PATROL)
		return  # No harpoon fitted (a loose lance it scoops up as it gets there), or not seen yet: keep closing in
	var harpoon_range: float = _tool_controller.get_tool(index).optimal_range
	var distance: float = agent_script.global_transform.origin.distance_to(wreck.global_transform.origin)
	for harpoon in range(_tool_controller.get_tool_count()):
		if not _tool_controller.is_active(harpoon) and _tool_controller.can_target(_tool_controller.get_tool(harpoon), wreck):
			_tool_controller.activate(harpoon, wreck)  # Launches once in reach
	if distance <= harpoon_range * 0.8 and not _orbiting:
		_orbiting = true  # Here: in reach; stop and let the tether reel it in
		agent_script.command_stop()
	elif distance > harpoon_range and _orbiting:
		_orbiting = false
		agent_script.command_approach(wreck)


# An ore chunk not ready for the harpoon: burns its crust off from within its laser's reach, then
# waits by the hot slag till it cools (Constants MINING).
func _work_chunk(chunk) -> void:
	var laser: int = _mining_laser() if is_instance_valid(_tool_controller) else -1
	if laser < 0:
		_change_state(AIState.PATROL)
		return
	var reach: float = _tool_controller.get_tool(laser).optimal_range
	var distance: float = agent_script.global_transform.origin.distance_to(chunk.global_transform.origin)
	if distance <= reach * 0.8 and not _orbiting:
		_orbiting = true
		agent_script.command_stop()
	elif distance > reach and _orbiting:
		_orbiting = false
		agent_script.command_approach(chunk)
	if chunk.has_crust():
		if not _tool_controller.is_active(laser):
			_tool_controller.activate(laser, chunk)  # Fires once in reach
	elif _tool_controller.is_active(laser):
		_tool_controller.deactivate(laser, "bared")


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
		if desire_against(_target_agent) >= _disengage_level():
			_pending = {}
			_resume()  # The fight turned back: keep at it
	elif _pending.kind == "let_go" and _scan_timer <= 0.0:
		_scan_timer = Constants.AI_SCAN_INTERVAL
		if not _should_let_go(_target_agent):
			_pending = {}
			_resume()  # It turned round, or slowed: keep at it


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


# A traveller whose time in the sector is up (Traffic): out through `point` and away.
func leave_toward(point: Vector3) -> void:
	_home_point = point
	_change_state(AIState.DEPART)


func is_leaving() -> bool:
	return _current_state == AIState.DEPART


# Full hold: fly back to where it came from and leave the sector with the loot.
func _process_depart() -> void:
	if not _arena.empty():
		_process_run_home()
		return
	if agent_script.global_transform.origin.distance_to(_home_point) <= Constants.AI_DEPART_ARRIVAL_DISTANCE:
		_change_state(AIState.IDLE)
		agent_script.despawn()
		return
	if _repath_timer <= 0.0:
		_repath_timer = Constants.AI_REPATH_INTERVAL * 4.0
		agent_script.command_move_to(_home_point)


# --- Ramming (kinetic lance) ---

func can_ram() -> bool:
	return agent_script.has_method("get_lance_nails") and agent_script.get_lance_nails() > 0 \
		and agent_script.get_top_speed() >= Constants.LANCE_CATCH_SPEED


# A target running from it that it cannot outpace by strike speed (Agent.outruns_ram).
func outruns_ram(target) -> bool:
	return agent_script.outruns_ram(target)


# Rams `target` if it can and it pays (ram_worth: weighed as it starts and again between passes);
# true while it does. Out of lances, against a runner too fast to strike (even mid-charge: running,
# it never turns to fight), or when a charge no longer pays, it stops, and the fight goes on with
# its other weapons (a lancer without any hangs back: _hold_off).
func _ram(target) -> bool:
	var weigh: bool = not _ramming or _running_up()
	if not can_ram() or outruns_ram(target) or (weigh and not ram_worth(target)):
		if _ramming:
			_stop_ramming()
			_orbiting = false
			_aiming = false
			_repath_timer = 0.0
		return false
	if not _ramming:
		_ramming = true
		agent_script.set_lances_armed(true)
		agent_script.command_ram(target)
	return true


# Charging (not running up) within AI_RAM_NO_RETURN of the target: a charge that far in is seen
# through, since breaking off would only give the target a free shot at its back; further out it
# may still break off (its retreat level), and it reconsiders while it runs up for the next.
func is_ram_committed() -> bool:
	if not _ramming or not _is_live_target(_target_agent) or _running_up():
		return false
	return agent_script.global_transform.origin.distance_to(_target_agent.global_transform.origin) < Constants.AI_RAM_NO_RETURN


func _running_up() -> bool:
	var nav = agent_script.navigation_system
	return not is_instance_valid(nav) or nav._current_command.get("running_up", true)


# Whether a charge at `target` pays (Agent.ram_outlook, Constants AI_RAM_*): the hull it would lose
# keeps it above its retreat level, or a throw would finish the target and the loss would not finish
# it. A rock, a wreck or a chunk always does (nothing shoots back).
func ram_worth(target) -> bool:
	if not (target is RigidBody and target.get("is_wreck") == false):
		return true
	var outlook: Dictionary = agent_script.ram_outlook(target)
	var hull: float = float(agent_script.hull)
	if outlook.strike >= float(target.get("hull") if target.get("hull") != null else INF):
		return outlook.cost < hull
	return outlook.cost < hull - _retreat_level() * float(agent_script.hull_max)


# A lancer whose charge does not pay and that has no other weapon on `target`: waits outside the
# reach of the target's guns (AI_RAM_HOLD_OFF), for its friends to wear it down.
func _hold_off(target) -> void:
	if _repath_timer > 0.0:
		return
	_repath_timer = Constants.AI_REPATH_INTERVAL * 2.0
	_orbiting = false
	_aiming = false
	var away: Vector3 = agent_script.global_transform.origin - target.global_transform.origin
	away = away.normalized() if away.length_squared() > 1.0 else Vector3.BACK
	var reach: float = max(agent_script.weapon_reach_of(target), Constants.LANCE_RELEASE_RANGE)
	agent_script.command_move_to(target.global_transform.origin + away * reach * Constants.AI_RAM_HOLD_OFF)


func _stop_ramming() -> void:
	_ramming = false
	if is_instance_valid(agent_script) and agent_script.has_method("set_lances_armed"):
		agent_script.set_lances_armed(false)


func _on_lance_recovered(_index) -> void:
	_note("lance_recovered")


func _on_ammo_recovered(_index, _rounds) -> void:
	_note("ammo_recovered")


func _on_lance_struck(target, _damage) -> void:
	_note("lance_hit")
	if _current_state == AIState.MINE and is_instance_valid(target) and target.is_in_group("ore_chunk"):
		_note("mined")
		_target_agent = target  # Its chunk, with its lance in it: harpoon it home
		_change_state(AIState.SALVAGE)


func _on_lance_glanced(_target, reason) -> void:
	if str(reason) == "missed":
		_note("lance_missed")
	else:
		_note("glance_slow" if str(reason).begins_with("too slow") else "glance_angle")


# --- Mining (prospect gene; Constants MINING) ---

# A prospector (prospect gene) mining, working ore or a loose lance, or hauling home: it minds its
# work (Constants AI block): it takes on no enemy out of its weapons' reach, helps no friend, and runs
# home when attacked.
func is_mining_work() -> bool:
	if _prospect < 0.5:
		return false
	if _current_state in [AIState.MINE, AIState.DEPART]:
		return true
	return _current_state == AIState.SALVAGE and is_instance_valid(_target_agent) \
			and (_target_agent.is_in_group("ore_chunk") or _target_agent.is_in_group("loose_lance"))


# An enemy a prospector at work leaves be: out of reach of all its weapons.
func _busy_mining_past(enemy) -> bool:
	if not is_mining_work() or not is_instance_valid(_tool_controller):
		return false
	var reach := 0.0
	for index in range(_tool_controller.get_tool_count()):
		if _tool_controller.can_target(_tool_controller.get_tool(index), enemy):
			reach = max(reach, _tool_controller.get_tool(index).get_max_range())
	return agent_script.global_transform.origin.distance_to(enemy.global_transform.origin) > reach


func can_mine() -> bool:
	if _prospect < 0.5 or not is_instance_valid(_tool_controller) or agent_script.get_free_cargo() <= 0 or not can_ram():
		return false
	return _mining_laser() >= 0 and _has_harpoon()


func _mining_laser() -> int:
	for index in range(_tool_controller.get_tool_count()):
		if _tool_controller.get_tool(index).tool_type == "laser":
			return index
	return -1


func _has_harpoon() -> bool:
	for index in range(_tool_controller.get_tool_count()):
		if _tool_controller.get_tool(index).tool_type == "harpoon":
			return true
	return false


# The nearest detected rock in its arena with ore left, that it has not given up on.
func scan_for_rock() -> Spatial:
	var best: Spatial = null
	var best_distance: float = Constants.AI_MINE_SEARCH_RANGE
	var own_pos: Vector3 = agent_script.global_transform.origin
	for rock in get_tree().get_nodes_in_group("mineable"):
		if _given_up.has(rock.get_instance_id()) or rock.get_deposit() <= 0 or not _in_arena(rock.global_transform.origin) or not agent_script.detects(rock):
			continue
		var distance: float = own_pos.distance_to(rock.global_transform.origin)
		if distance < best_distance:
			best = rock
			best_distance = distance
	return best


# Throws a lance into the rock (command_ram holds it off the face); the strike (_on_lance_struck)
# sends it after the biggest chunk, and the rest are picked up as wrecks. Enemies that show up come
# first.
func _process_mine(delta: float) -> void:
	_mine_time += delta
	if not (is_instance_valid(_rock) and _rock.get_deposit() > 0 and can_mine()) or _mine_time > Constants.AI_MINE_GIVE_UP:
		if is_instance_valid(_rock) and _mine_time > Constants.AI_MINE_GIVE_UP:
			_given_up[_rock.get_instance_id()] = true
		_rock = null
		_change_state(AIState.PATROL)
		return
	if _scan_timer <= 0.0:
		_scan_timer = Constants.AI_SCAN_INTERVAL
		var enemy = scan_for_target()
		if is_instance_valid(enemy) and not _busy_mining_past(enemy):
			_consider("engage", enemy, desire_against(enemy), _engage_level())
			return
	_ram(_rock)


# --- Runners: chase or let go ---

# Whether `body` is running from this ship: moving away from it at over AI_RUNNER_SPEED_SHARE of its
# top speed (what the player sees too: a ship turning tail).
func is_running_from_me(body) -> bool:
	var away: Vector3 = body.global_transform.origin - agent_script.global_transform.origin
	if away.length() < 0.001:
		return false
	return body.linear_velocity.dot(away.normalized()) > Constants.AI_RUNNER_SPEED_SHARE * max(body.get_top_speed(), 1.0)


# A runner's time to safety over the time this ship needs to get it in reach: over 1 it gets caught,
# under 1 it gets away; INF while in reach.
func chase_margin(body) -> float:
	var own_pos: Vector3 = agent_script.global_transform.origin
	var target_pos: Vector3 = body.global_transform.origin
	var index: int = _tool_controller.find_tool_for(body) if is_instance_valid(_tool_controller) else -1
	var reach: float = _tool_controller.get_tool(index).get_max_range() if index >= 0 else 0.0
	var gap: float = own_pos.distance_to(target_pos) - reach
	if gap <= 0.0:
		return INF
	var runner_speed: float = max(body.get_top_speed(), body.linear_velocity.length())
	var closing: float = agent_script.get_top_speed() - runner_speed
	if closing <= 0.0:
		return 0.0
	# Safe: docked at its nearest station in an arena, otherwise once it has fled AI_FLEE_DISTANCE
	var safe_distance: float = max(0.0, Constants.AI_FLEE_DISTANCE - own_pos.distance_to(target_pos))
	if not _arena.empty():
		safe_distance = INF
		for station in _arena.get("refuges", {}).get(body.get("faction"), []):
			if is_instance_valid(station):
				safe_distance = min(safe_distance, target_pos.distance_to(station.get_undock_position()))
	return (safe_distance / max(runner_speed, 1.0)) / (gap / closing)


# Breaks off from a runner it reckons it cannot catch, or one it lets go (a mercy roll, once per run)
# because it is not shooting back.
func _should_let_go(body) -> bool:
	if not (_is_live_target(body) and is_running_from_me(body)):
		_runner_judged = false
		return false
	var shooting_back: bool = _since_hit < Constants.AI_RETURN_FIRE_WINDOW
	if not _runner_judged:
		_runner_judged = true
		_letting_go = randf() < _mercy_level()
	if _letting_go and not shooting_back:
		return true
	return chase_margin(body) * _pursuit_level() < 1.0


func is_sparing(body) -> bool:
	return is_instance_valid(body) and _spared.has(body.get_instance_id())


# --- Arena: stations, docking, staying in the arena ---

# Heading for _station (fleeing or hauling): docks on arrival.
func _process_run_home() -> void:
	if not is_instance_valid(_station):
		_station = _pick_refuge(_target_agent)
	if not is_instance_valid(_station):
		_change_state(AIState.PATROL)
		return
	var dock_point: Vector3 = _station.get_undock_position()
	if agent_script.global_transform.origin.distance_to(dock_point) <= Constants.ARENA_DOCK_DISTANCE:
		if _current_state == AIState.FLEE:
			_note("escaped")
		_dock(_station, true)
		return
	if _repath_timer <= 0.0:
		_repath_timer = Constants.AI_REPATH_INTERVAL * 4.0
		agent_script.command_move_to(dock_point)


# Into the station: out of the world until it undocks. `service`: sells the hold and repairs (it
# arrived; a ship spawned docked has nothing to sell). An old ship retires there instead.
func _dock(station: Spatial, service: bool) -> void:
	_station = station
	agent_script.dock_at(station)
	_change_state(AIState.DOCKED)
	_dock_timer = Constants.ARENA_DOCK_TIME
	if service and Evolution.on_docked(agent_script, str(station.get("location_id"))):
		agent_script.despawn()  # Retired: its record is in the log


# Undocks once its dock time is up and no enemy waits outside (Constants ARENA_UNDOCK_CLEAR_RADIUS),
# or once it has waited ARENA_DOCK_MAX_WAIT s more for one to leave.
func _process_docked(delta: float) -> void:
	_dock_timer -= delta
	if _dock_timer > 0.0:
		return
	if _dock_timer > -Constants.ARENA_DOCK_MAX_WAIT and is_station_watched():
		return
	agent_script.undock()
	_change_state(AIState.PATROL)


# An enemy waits near its station's undock point: undocking would only send it running back in.
func is_station_watched() -> bool:
	if not is_instance_valid(_station):
		return false
	var station_pos: Vector3 = _station.get_undock_position()
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body != agent_script and _is_live_target(body) and agent_script.is_enemy_of(body) \
				and body.global_transform.origin.distance_to(station_pos) <= Constants.ARENA_UNDOCK_CLEAR_RADIUS:
			return true
	return false


# Its own station to run to: near itself and away from the threat (if any).
func _pick_refuge(threat) -> Spatial:
	var best: Spatial = null
	var best_score: float = INF
	var own_pos: Vector3 = agent_script.global_transform.origin
	for station in _arena.get("stations", []):
		if not is_instance_valid(station):
			continue
		var score: float = own_pos.distance_to(station.global_transform.origin)
		if is_instance_valid(threat):
			score -= 0.5 * threat.global_transform.origin.distance_to(station.global_transform.origin)
		if score < best_score:
			best = station
			best_score = score
	return best


# Within the arena (Constants ARENA_RADIUS, times `slack`) or not an arena NPC.
func _in_arena(point: Vector3, slack: float = 1.0) -> bool:
	return _arena.empty() or point.distance_to(_arena.beacon) <= Constants.ARENA_RADIUS * slack


# --- Behaviour genes, as desperation bends them (Constants AI block: desperation) ---

func desperation() -> float:
	return agent_script.get_desperation() if agent_script.has_method("get_desperation") else 0.0


func _nerve() -> float:
	return 1.0 - Constants.AI_DESPERATION_NERVE * desperation()


func _engage_level() -> float:
	return _engage_desire * _nerve()


func _disengage_level() -> float:
	return _disengage_desire * _nerve()


func _mercy_level() -> float:
	return _mercy * (1.0 - desperation())


func _pursuit_level() -> float:
	return _pursuit * (1.0 + desperation())


func _return_fire_level() -> float:
	return lerp(_return_fire, 1.0, desperation())


func _retreat_level() -> float:
	return _retreat_hull * (1.0 - desperation())


# Hull under its retreat gene: run home whatever the odds.
func _should_retreat() -> bool:
	return _retreat_level() > 0.0 and agent_script.get_hull_fraction() < _retreat_level()


# Counts a run-and-chase event in an arena NPC's life (Evolution.note).
func _note(event: String) -> void:
	if not _arena.empty():
		Evolution.note(str(agent_script.evo_uid), event)


# An old arena NPC goes home to retire (Evolution, Constants ARENA_MAX_LIFETIME).
# Its hold is worth its haul gene's share of its ship: worth taking home before it is lost with it.
func hold_worth_hauling() -> bool:
	var cargo_value: float = agent_script.get_cargo_value()
	return cargo_value > 0.0 and cargo_value >= _haul * agent_script.get_value()


func _due_home() -> bool:
	return not _arena.empty() and Evolution.is_old(agent_script.evo_uid)


# The nearest detected wreck with something left on it for this ship that nobody else has
# harpooned. A lancer short of lances goes for wrecks with lances that fit its seat first (they look
# AI_LANCE_SALVAGE_PRIORITY times nearer), and recovers them even with a full hold.
func scan_for_wreck() -> RigidBody:
	var best: RigidBody = null
	var best_distance: float = Constants.AI_SALVAGE_SEARCH_RANGE
	var own_pos: Vector3 = agent_script.global_transform.origin
	for body in get_tree().get_nodes_in_group("agent_body"):
		if not (body.get("is_wreck") and _worth_salvaging(body) and agent_script.detects(body) and _in_arena(body.global_transform.origin)):
			continue
		var distance: float = own_pos.distance_to(body.global_transform.origin)
		if body.recoverable_lances_for(agent_script) > 0 or _recoverable_ammo(body) > 0:
			distance /= Constants.AI_LANCE_SALVAGE_PRIORITY  # Lances or rounds for its own weapons: worth a detour
		if distance < best_distance and not _is_claimed(body):
			best = body
			best_distance = distance
	return best


# Out of lances (it has launchers, all empty): the nearest loose lance it can take back, which it
# goes for before any fight; null if none or it still has lances.
func _lance_to_collect():
	if not agent_script.has_method("get_lances") or agent_script.get_lances().empty() or agent_script.get_lance_nails() > 0:
		return null
	var best = null
	var best_distance: float = Constants.AI_SALVAGE_SEARCH_RANGE
	var own_pos: Vector3 = agent_script.global_transform.origin
	for body in get_tree().get_nodes_in_group("loose_lance"):
		if body.recoverable_lances_for(agent_script) <= 0 or not agent_script.detects(body) or not _in_arena(body.global_transform.origin) or _is_claimed(body):
			continue
		var distance: float = own_pos.distance_to(body.global_transform.origin)
		if distance < best_distance:
			best = body
			best_distance = distance
	return best


# Going for a loose lance with none left: it does not pick fights on the way (it still answers fire).
func _collecting_lances(wreck) -> bool:
	return wreck.is_in_group("loose_lance") and agent_script.has_method("get_lance_nails") and agent_script.get_lance_nails() <= 0


# Lances for its own seat, rounds for its own magazines, or salvage with room in the hold.
func _worth_salvaging(wreck) -> bool:
	if wreck.has_method("has_crust") and wreck.has_crust() and not (is_instance_valid(_tool_controller) and _mining_laser() >= 0):
		return false  # A crusted chunk needs a laser first
	return wreck.recoverable_lances_for(agent_script) > 0 or _recoverable_ammo(wreck) > 0 or (wreck.get_salvage_units() > 0 and agent_script.get_free_cargo() > 0)


func _recoverable_ammo(wreck) -> int:
	var wreck_tools = wreck.get_node_or_null("ToolController")
	if wreck_tools == null or not wreck_tools.has_method("recoverable_ammo_for") or not is_instance_valid(_tool_controller):
		return 0
	return wreck_tools.recoverable_ammo_for(_tool_controller)


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
	var best_desire: float = _engage_level()
	_threat = null
	var worst_desire: float = _engage_level() * _caution
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body == agent_script or not _is_live_target(body) or not agent_script.is_enemy_of(body):
			continue
		if is_sparing(body):
			continue
		if not _in_arena(body.global_transform.origin):
			continue
		if not agent_script.detects(body):
			continue
		var desire: float = desire_against(body)
		if desire >= best_desire:
			best = body
			best_desire = desire
		elif desire < worst_desire and not body.detects(agent_script):
			_threat = body  # Too strong, and has not seen it yet
			worst_desire = desire
	return best


# How much this ship wants to fight `target` (see Constants AI block and CombatAssessment): its side
# (its friends near it) against the target's.
func desire_against(target) -> float:
	var ours: Dictionary = CombatAssessment.side_of(agent_script)
	var theirs: Dictionary = CombatAssessment.side_of(target)
	var desire: float = compute_desire(ours.hull, ours.dps, theirs.hull, theirs.dps, target.get_salvage_value())
	if target.has_method("detects") and not target.detects(agent_script):
		desire *= Constants.AI_UNSEEN_DESIRE_FACTOR  # It strikes first
	return desire * (Constants.AI_ENEMY_DESIRE_FACTOR if agent_script.is_enemy_of(target) else 1.0)


static func compute_desire(own_hull: float, own_dps: float, target_hull: float, target_dps: float, gain: float) -> float:
	return CombatAssessment.compute_desire(own_hull, own_dps, target_hull, target_dps, gain)


func _is_live_target(body) -> bool:
	return is_instance_valid(body) and body.is_inside_tree() and not body.get("is_wreck") and not body.get("is_docked")


# A point near home (near its leader, if its group has one: Evolution.leader_of), not inside a rock (a
# few tries; the autopilot steers round the rest).
func _pick_patrol_destination() -> Vector3:
	var centre: Vector3 = _home_position
	var radius: float = Constants.AI_PATROL_RADIUS
	var leader = get_leader()
	if leader != null:
		centre = leader.global_transform.origin
		radius = Constants.AI_FOLLOW_RADIUS
	var point: Vector3 = centre
	for _try in range(8):
		var direction = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		point = centre + direction * randf() * radius
		var inside := false
		for obstacle in NavigationSystem.get_obstacles(get_tree()):
			if point.distance_to(obstacle[0]) < obstacle[1] * 1.5 + Constants.AI_PATROL_ARRIVAL_DISTANCE:
				inside = true
				break
		if not inside:
			return point
	return point


func _on_agent_disabled(agent_body) -> void:
	if agent_body == agent_script:
		_change_state(AIState.DISABLED)


# Shot at by anyone: turn on the attacker and close in however far away it fired from, if the
# fight is worth it; otherwise flee from it.
func _on_agent_damaged(agent_body, _amount, source) -> void:
	if agent_body != agent_script:
		_assist(agent_body, source)
		return
	_react_to_attack(source)


# A friend (its faction, within AI_ASSIST_RADIUS) shot at while this ship is not fighting: it weighs
# going to help (a decision, as any other: veterans make it sooner), and goes if its side, the friend
# included, wants that fight. The attacker becomes its enemy too.
func _assist(friend, source) -> void:
	if not _is_live_target(source) or source == agent_script or not _is_live_target(friend):
		return
	if friend.get("faction") != agent_script.faction or agent_script.faction == "" or source.get("faction") == agent_script.faction:
		return
	if not _current_state in [AIState.PATROL, AIState.SALVAGE, AIState.HESITATE]:
		return
	if _current_state == AIState.HESITATE and _resume_state == AIState.COMBAT:
		return
	if friend.global_transform.origin.distance_to(agent_script.global_transform.origin) > Constants.AI_ASSIST_RADIUS:
		return
	if not _in_arena(source.global_transform.origin):
		return
	if not _pending.empty() and _pending.kind == "assist" and _pending.target == source:
		return
	if _teamwork <= 0.0:
		return  # A loner: helps no one
	if is_mining_work():
		return  # A prospector at work leaves fights to others
	_consider("assist", source, desire_against(source) * _teamwork, _engage_level())


# Charged at with a lance (seen coming, see LanceController.is_charging): as good as shot at. It holds
# the grudge now (Agent does too, after it), so the charger counts as an enemy in what it decides.
func _on_agent_charged(agent_body, charger) -> void:
	if agent_body != agent_script or not _is_live_target(charger):
		return
	agent_script._hold_grudge(charger)
	_note("charged")
	_react_to_attack(charger)


func _react_to_attack(source) -> void:
	if not _is_live_target(source) or source == agent_script:
		return
	if _current_state in [AIState.DISABLED, AIState.FLEE, AIState.DOCKED]:
		return
	var fighting = _target_agent if _current_state == AIState.COMBAT else null
	if _current_state == AIState.HESITATE and _resume_state == AIState.COMBAT:
		fighting = _resume_target
	if fighting != null and fighting == source:
		_provoked = true
		_since_hit = 0.0
		return
	if is_mining_work():
		_note("fled_work")
		_change_state(AIState.FLEE)  # A prospector at work runs home, it does not fight
		return
	# Shot at: once it has made up its mind, fight back if the rule says so, otherwise run.
	_consider("respond", source, desire_against(source), _disengage_level())


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
			if agent_script.detects(target) and desire >= _engage_level():
				_start_combat(target, false)
			else:
				_resume()
		"disengage":
			if desire < _disengage_level():
				_target_agent = target
				_resume_target = null
				_change_state(AIState.FLEE)
			else:
				_resume()
		"let_go":
			if _should_let_go(target):
				_spared[target.get_instance_id()] = Constants.AI_SPARE_TIME
				_note("let_go")
				var spared_uid = target.get("evo_uid")
				if spared_uid is String and spared_uid != "":
					Evolution.note(spared_uid, "spared")
				_resume_target = null
				_change_state(AIState.PATROL)
			else:
				_resume()
		"assist":
			if desire >= _engage_level() and not _should_retreat():
				agent_script._hold_grudge(target)
				_note("assisted")
				_start_combat(target, true)
			else:
				_resume()
		"respond":
			_resume_target = null
			if desire >= _disengage_level() and not _should_retreat():
				_start_combat(target, true)
			else:
				_target_agent = target
				_change_state(AIState.FLEE)


func _start_combat(target, provoked: bool) -> void:
	_target_agent = target
	_provoked = provoked
	_since_hit = 0.0 if provoked else INF
	_runner_judged = false
	_spared.erase(target.get_instance_id())
	_current_state = AIState.IDLE  # Re-enter combat so the approach starts toward the target
	_change_state(AIState.COMBAT)

