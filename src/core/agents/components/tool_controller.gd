# ToolController: switches an agent's tools on against a target and runs their cycles.
# Tools come from the ship preset (ShipTemplate.equipped_tools -> UtilityToolTemplate presets).
# No aiming: results depend on range and on the target's angular velocity.
# Child of AgentBody; used identically by the player and the AI.
#
# Tool types:
#   laser   - targets live ships; each cycle deals damage scaled by hit quality. Whatever is in the
#             line of fire (a rock, another ship) takes the shot instead: rocks flash, ships are damaged.
#           - point defence: a laser free to fire shoots instead at a missile coming at its own ship
#             within its optimal range (hit quality as for a ship: a fast crossing missile is hard
#             to track, a head-on one easy), switched on or not.
#   missile - targets live ships; each cycle launches a guided Missile (Projectile) from the rack's
#             magazine, unless the ones already on their way would finish the target. One use each.
#   cannon  - targets live ships; fixed forward, so it fires only when the nose points where the
#             target will be by the time a Shell gets there (the ship aims: NavigationSystem's aim
#             command). Rounds from a magazine.
#   Magazines (missiles, cannon rounds) refill at a base, or from a wreck's (harpoon salvage).
#   harpoon - targets wrecks; one launch attaches a tether that reels in to a safe towing distance,
#             then strips salvage into the hold one unit per strip_interval. Off (or the hook tears
#             free) = the hook lets go and the cable winches in; it cannot fire again until it is in.

extends Node

const LaserHitEffect = preload("res://src/core/agents/effects/laser_hit_effect.gd")
const LaserHitScene = preload("res://scenes/prefabs/effects/laser_hit.tscn")
const LaserBeam = preload("res://src/core/agents/effects/laser_beam.gd")
const Tether = preload("res://src/core/agents/components/tether.gd")
const MissileScript = preload("res://src/core/agents/components/missile.gd")
const ShellScript = preload("res://src/core/agents/components/shell.gd")
const AMMO_TYPES = ["missile", "cannon"]
const WEAPON_TYPES = ["laser", "missile", "cannon"]

signal tool_activated(tool_index, target)
signal tool_deactivated(tool_index, reason)
signal tool_cycled(tool_index, target, hit_quality, damage)
signal salvage_stripped(tool_index, commodities)
signal lance_recovered(tool_index)
signal ammo_recovered(tool_index, rounds)
signal ammo_changed(tool_index, ammo)
signal projectile_fired(tool_index, projectile)
signal missile_intercepted(tool_index, missile, destroyed)
signal tool_blocked(tool_index, target, blocker)  # Something in the line of fire took the shot

# Tethered bodies stop this far apart: the sum of both apparent radii times this factor.

var _agent_body: RigidBody = null
var _tools: Array = []  # UtilityToolTemplate per mount, in ship order
var _targets: Dictionary = {}  # tool_index -> target body while switched on
var _cycle_timers: Dictionary = {}  # tool_index -> seconds until the next cycle may start
var _tethers: Dictionary = {}  # tool_index -> Tether node while a harpoon is attached
var _retracting: Dictionary = {}  # tool_index -> Tether node winching its cable in
var _last_cycle_ms: int = -1000000  # When a tool last cycled (drives the firing signature)
var _ammo: Dictionary = {}  # tool_index -> rounds left, for tools with a magazine
var _in_flight: Array = []  # Missiles launched and still flying


func _ready() -> void:
	_agent_body = get_parent()
	if not _agent_body is RigidBody:
		printerr("ToolController: Parent must be RigidBody")
		return
	if _agent_body.has_method("_on_tool_ammo_changed"):
		connect("ammo_changed", _agent_body, "_on_tool_ammo_changed")
	# The agent body resolves its ShipTemplate in initialize(), after _ready.
	call_deferred("_load_tools_if_unset")


func _load_tools_if_unset() -> void:
	if _tools.empty():
		load_tools_from_ship()


func set_tools(tools: Array, ammo: Array = []) -> void:
	deactivate_all("refit")
	_tools = tools.duplicate()
	_cycle_timers.clear()
	_fill_magazines(ammo)


func load_tools_from_ship() -> void:
	deactivate_all("refit")
	_tools.clear()
	_cycle_timers.clear()
	var ship = _agent_body.get("ship_template")
	if not is_instance_valid(ship):
		return
	var tool_ids: Array = _agent_body.get_fitted_tool_ids() if _agent_body.has_method("get_fitted_tool_ids") else ship.equipped_tools
	for tool_id in tool_ids:
		var tool_template = TemplateDatabase.get_template(tool_id)
		if tool_template is UtilityToolTemplate:
			_tools.append(tool_template)
		else:
			printerr("ToolController: Ship '", ship.template_id, "' fits unknown tool '", tool_id, "'")
	_fill_magazines(_saved_player_ammo())


# Full magazines, except where `ammo` (rounds per tool, -1 full) says otherwise.
func _fill_magazines(ammo: Array) -> void:
	_ammo.clear()
	for index in range(_tools.size()):
		if int(_tools[index].ammo) > 0:
			var left: int = int(ammo[index]) if index < ammo.size() and int(ammo[index]) >= 0 else int(_tools[index].ammo)
			_ammo[index] = int(clamp(left, 0, int(_tools[index].ammo)))


# The player's magazines as last left (GameState.player_tool_ammo: [[tool id, rounds] per slot]),
# for the tools that are still the same.
func _saved_player_ammo() -> Array:
	if not (_agent_body.has_method("is_player") and _agent_body.is_player()):
		return []
	var saved: Array = GameState.player_tool_ammo
	var ammo: Array = []
	for index in range(_tools.size()):
		var entry = saved[index] if index < saved.size() else null
		ammo.append(int(entry[1]) if entry is Array and entry.size() == 2 and str(entry[0]) == str(_tools[index].template_id) else -1)
	return ammo


func get_ammo(index: int) -> int:
	return int(_ammo.get(index, -1))


func has_magazine(index: int) -> bool:
	return _ammo.has(index)


# Refills magazines (all of them, or at most `rounds` in all); returns {tool_index: rounds added}.
func restock_ammo(rounds: int = -1) -> Dictionary:
	var added := {}
	for index in _ammo.keys():
		var room: int = int(_tools[index].ammo) - int(_ammo[index])
		var take: int = room if rounds < 0 else int(min(room, rounds))
		if take <= 0:
			continue
		_set_ammo(index, int(_ammo[index]) + take)
		added[index] = take
		if rounds >= 0:
			rounds -= take
	return added


func _set_ammo(index: int, rounds: int) -> void:
	_ammo[index] = rounds
	if _agent_body.has_method("is_player") and _agent_body.is_player():
		var saved: Array = []
		for i in range(_tools.size()):
			saved.append([str(_tools[i].template_id), int(_ammo.get(i, -1))])
		GameState.player_tool_ammo = saved
	emit_signal("ammo_changed", index, rounds)


# kg of rounds fired (the ship is that much lighter).
func spent_ammo_mass() -> float:
	var total := 0.0
	for index in _ammo:
		total += float(_tools[index].round_mass) * (int(_tools[index].ammo) - int(_ammo[index]))
	return total


# Rounds in this (wreck's) magazines that `salvager`'s ToolController can take: of the same kind
# and, within AMMO_RECOVER_MASS_TOLERANCE, the same round mass.
func recoverable_ammo_for(salvager_tools) -> int:
	var total := 0
	for pair in _ammo_pairs(salvager_tools):
		total += int(min(int(_ammo[pair[1]]), int(salvager_tools._tools[pair[0]].ammo) - int(salvager_tools._ammo[pair[0]])))
	return total


# Moves one batch (a missile; a share of a magazine of cannon rounds) into `salvager_tools`;
# returns {"index": its tool, "rounds": moved}, or {} if nothing fits.
func recover_ammo_into(salvager_tools) -> Dictionary:
	for pair in _ammo_pairs(salvager_tools):
		var own_tool = salvager_tools._tools[pair[0]]
		var batch: int = 1 if own_tool.tool_type == "missile" else int(max(1, ceil(int(own_tool.ammo) * Constants.AMMO_RECOVER_SHARE)))
		var rounds: int = int(min(batch, min(int(_ammo[pair[1]]), int(own_tool.ammo) - int(salvager_tools._ammo[pair[0]]))))
		if rounds <= 0:
			continue
		_set_ammo(pair[1], int(_ammo[pair[1]]) - rounds)
		salvager_tools._set_ammo(pair[0], int(salvager_tools._ammo[pair[0]]) + rounds)
		return {"index": pair[0], "rounds": rounds}
	return {}


func _ammo_pairs(salvager_tools) -> Array:
	var pairs: Array = []
	if salvager_tools == null or salvager_tools == self:
		return pairs
	for own_index in salvager_tools._ammo:
		var own_tool = salvager_tools._tools[own_index]
		if int(salvager_tools._ammo[own_index]) >= int(own_tool.ammo):
			continue
		for index in _ammo:
			var tool_template = _tools[index]
			if int(_ammo[index]) > 0 and tool_template.tool_type == own_tool.tool_type \
					and abs(float(tool_template.round_mass) - float(own_tool.round_mass)) <= Constants.AMMO_RECOVER_MASS_TOLERANCE * float(own_tool.round_mass):
				pairs.append([own_index, index])
	return pairs


# --- Public API ---

func get_tool_count() -> int:
	return _tools.size()


func get_tool(index: int) -> Resource:
	return _tools[index] if index >= 0 and index < _tools.size() else null


# First fitted tool that can act on `target`, or -1.
func find_tool_for(target) -> int:
	for index in range(_tools.size()):
		if can_target(_tools[index], target):
			return index
	return -1


# Laser: live ships and rocks. Harpoon: wrecks.
func can_target(tool_template, target) -> bool:
	if not (is_instance_valid(target) and target != _agent_body and target is Spatial):
		return false
	var is_ship: bool = target.has_method("apply_damage")
	if _agent_body.has_method("detects") and not _agent_body.detects(target):
		return false  # Tools act only on what the ship's sensors can see
	match tool_template.tool_type:
		"laser":
			return (is_ship and not target.get("is_wreck")) or target.is_in_group("asteroid")
		"missile", "cannon":
			return is_ship and not target.get("is_wreck")
		"harpoon":
			return is_ship and bool(target.get("is_wreck"))
	return false


func is_active(index: int) -> bool:
	return _targets.has(index)


func get_target(index: int) -> Node:
	return _targets.get(index)


func get_tether(index: int) -> Node:
	return _tethers.get(index)


# The harpoon's cable is still winching in: it cannot fire yet.
func is_retracting(index: int) -> bool:
	if _retracting.has(index) and is_instance_valid(_retracting[index]):
		return true
	_retracting.erase(index)
	return false


func get_retracting_tether(index: int) -> Node:
	return _retracting.get(index) if is_retracting(index) else null


# 0 at the start of a cycle, 1 when the next cycle is due.
func get_cycle_progress(index: int) -> float:
	var tool_template = get_tool(index)
	if tool_template == null or not is_active(index) or tool_template.cycle_time <= 0.0:
		return 0.0
	return clamp(1.0 - _cycle_timers.get(index, 0.0) / tool_template.cycle_time, 0.0, 1.0)


func activate(index: int, target: Node) -> Dictionary:
	var tool_template = get_tool(index)
	if tool_template == null:
		return {"success": false, "reason": "no_tool"}
	if not tool_template.tool_type in WEAPON_TYPES + ["harpoon"]:
		return {"success": false, "reason": "not_implemented"}
	if _agent_body.get("is_wreck"):
		return {"success": false, "reason": "wrecked"}
	if is_retracting(index):
		return {"success": false, "reason": "retracting"}
	if not can_target(tool_template, target):
		return {"success": false, "reason": "invalid_target"}
	if is_active(index):
		deactivate(index, "retarget")
	_targets[index] = target
	if not _cycle_timers.has(index):
		_cycle_timers[index] = 0.0
	emit_signal("tool_activated", index, target)
	return {"success": true}


func deactivate(index: int, reason: String = "manual") -> void:
	if not _targets.has(index):
		return
	_targets.erase(index)
	if _tethers.has(index):
		var tether = _tethers[index]
		_tethers.erase(index)
		if is_instance_valid(tether):
			tether.start_retract()
			_retracting[index] = tether
	emit_signal("tool_deactivated", index, reason)


func deactivate_all(reason: String = "manual") -> void:
	for index in _targets.keys():
		deactivate(index, reason)


# Angular velocity of `to` as seen from `from`: transversal relative speed over distance.
static func compute_angular_velocity(from_pos: Vector3, from_vel: Vector3, to_pos: Vector3, to_vel: Vector3) -> float:
	var offset: Vector3 = to_pos - from_pos
	var distance: float = offset.length()
	if distance <= 0.001:
		return 0.0
	var direction: Vector3 = offset / distance
	var relative_vel: Vector3 = to_vel - from_vel
	var transversal: Vector3 = relative_vel - direction * relative_vel.dot(direction)
	return transversal.length() / distance


# Closest distance a tether reels two bodies to.
static func get_tether_min_length(holder: Node, towed: Node) -> float:
	return (_apparent_radius(holder) + _apparent_radius(towed)) * Constants.TETHER_CLEARANCE


static func _apparent_radius(body: Node) -> float:
	return float(body.get_apparent_radius()) if body.has_method("get_apparent_radius") else 10.0


# 1 right after a tool cycle, fading to 0 over SIG_TOOL_DECAY.
func get_firing_activity() -> float:
	return clamp(1.0 - (OS.get_ticks_msec() - _last_cycle_ms) / (Constants.SIG_TOOL_DECAY * 1000.0), 0.0, 1.0)


# Damage per second from the fitted weapons (what an observer sees): lasers at full hit quality;
# missiles left, their damage spread over AI_MISSILE_FIGHT_TIME (at most a launch a cycle) times
# the share expected to hit; cannons with rounds left at their cycle, times the share that hit.
func get_damage_per_second() -> float:
	var total := 0.0
	for index in range(_tools.size()):
		var tool_template = _tools[index]
		if tool_template.cycle_time <= 0.0:
			continue
		var rate: float = tool_template.damage / tool_template.cycle_time
		match tool_template.tool_type:
			"laser":
				total += rate
			"missile":
				total += min(rate, tool_template.damage * max(0, get_ammo(index)) / Constants.AI_MISSILE_FIGHT_TIME) * Constants.AI_MISSILE_HIT_SHARE
			"cannon":
				if get_ammo(index) > 0:
					total += rate * Constants.AI_CANNON_HIT_SHARE
	return total


# The fitted cannon with rounds left that works on `target`, or -1.
func find_cannon_for(target) -> int:
	for index in range(_tools.size()):
		if _tools[index].tool_type == "cannon" and get_ammo(index) > 0 and can_target(_tools[index], target):
			return index
	return -1


# Where the cannon at `index` must point for a round to meet `target`: its lead direction (rounds
# leave at the ship's velocity plus the muzzle speed along the nose).
func cannon_aim_direction(index: int, target: Spatial) -> Vector3:
	var tool_template = get_tool(index)
	var from: Vector3 = _agent_body.global_transform.origin
	var target_velocity = target.get("linear_velocity")
	return MissileScript.intercept_direction(from, _agent_body.linear_velocity, target.global_transform.origin,
		target_velocity if target_velocity is Vector3 else Vector3.ZERO, max(float(tool_template.projectile_speed) if tool_template != null else 1.0, 1.0))


# --- Cycling ---

func _physics_process(delta: float) -> void:
	for index in _cycle_timers.keys():
		_cycle_timers[index] = max(0.0, _cycle_timers[index] - delta)
	if _agent_body.get("is_wreck"):
		if not _targets.empty():
			deactivate_all("wrecked")
		return
	_point_defence()
	if _targets.empty():
		return
	for index in _targets.keys():
		var target = _targets[index]
		if not can_target(_tools[index], target):
			deactivate(index, "target_lost")
			continue
		match _tools[index].tool_type:
			"laser":
				_process_laser(index, target)
			"missile":
				_process_missile(index, target)
			"cannon":
				_process_cannon(index, target)
			"harpoon":
				_process_harpoon(index, target)


# Each laser free to fire (cycle done) shoots the nearest missile coming at this ship within its
# optimal range, if there is one.
func _point_defence() -> void:
	var missiles: Array = get_tree().get_nodes_in_group(MissileScript.GROUP) if is_inside_tree() else []
	if missiles.empty():
		return
	var from_pos: Vector3 = _agent_body.global_transform.origin
	for index in range(_tools.size()):
		var tool_template = _tools[index]
		if tool_template.tool_type != "laser" or _cycle_timers.get(index, 0.0) > 0.0:
			continue
		var best = null
		var best_distance: float = tool_template.optimal_range * Constants.POINT_DEFENCE_RANGE_SHARE
		for missile in missiles:
			if not is_instance_valid(missile) or missile.done or missile.target != _agent_body:
				continue
			var distance: float = from_pos.distance_to(missile.global_transform.origin)
			if distance < best_distance:
				best = missile
				best_distance = distance
		if best == null or not _agent_body.try_spend_power(tool_template.power_per_cycle):
			continue
		var angular: float = compute_angular_velocity(from_pos, _agent_body.linear_velocity, best.global_transform.origin, best.velocity)
		var damage: float = tool_template.damage * tool_template.get_hit_quality(best_distance, angular)
		_cycle_timers[index] = tool_template.cycle_time
		_last_cycle_ms = OS.get_ticks_msec()
		_spawn_beam(best, best.global_transform.origin, damage)
		var destroyed: bool = best.take_hit(damage)
		emit_signal("missile_intercepted", index, best, destroyed)
		if destroyed and _agent_body.has_method("is_player") and _agent_body.is_player():
			EventBus.emit_signal("attack_action_feedback", true, "Missile shot down")
		if destroyed:
			missiles.erase(best)


func _process_missile(index: int, target: Node) -> void:
	if _cycle_timers.get(index, 0.0) > 0.0:
		return
	if get_ammo(index) <= 0:
		deactivate(index, "empty")
		return
	var tool_template = _tools[index]
	var from_pos: Vector3 = _agent_body.global_transform.origin
	if from_pos.distance_to(target.global_transform.origin) > tool_template.get_max_range():
		return
	if inbound_damage(target) >= float(target.get("hull")):
		return  # Enough on its way already
	if not _agent_body.try_spend_power(tool_template.power_per_cycle):
		return  # Waits for power
	var direction: Vector3 = (target.global_transform.origin - from_pos).normalized()
	var missile = MissileScript.new()
	missile.setup({"projectile_speed": tool_template.projectile_speed, "projectile_accel": tool_template.projectile_accel,
		"turn_rate": tool_template.turn_rate, "round_mass": tool_template.round_mass})
	var start: Vector3 = from_pos + direction * (_apparent_radius(_agent_body) + 2.0)
	missile.launch(_agent_body, target, start, _agent_body.linear_velocity + direction * Constants.MISSILE_LAUNCH_SPEED, tool_template.damage, tool_template.flight_time)
	_in_flight.append(missile)
	_after_shot(index, tool_template, missile)
	if target.has_method("is_player") and target.is_player():
		EventBus.emit_signal("announcement", "Missile inbound! Lasers shoot it down; a sharp turn near it makes it overshoot", "danger")


# Damage of this ship's missiles still on their way to `target`.
func inbound_damage(target) -> float:
	var total := 0.0
	for missile in _in_flight.duplicate():
		if not is_instance_valid(missile) or missile.done:
			_in_flight.erase(missile)
		elif missile.target == target:
			total += missile.damage
	return total


func _process_cannon(index: int, target: Node) -> void:
	if _cycle_timers.get(index, 0.0) > 0.0:
		return
	if get_ammo(index) <= 0:
		deactivate(index, "empty")
		return
	var tool_template = _tools[index]
	var from_pos: Vector3 = _agent_body.global_transform.origin
	var distance: float = from_pos.distance_to(target.global_transform.origin)
	if distance > tool_template.get_max_range():
		return
	var nose: Vector3 = -_agent_body.global_transform.basis.z.normalized()
	var aim: Vector3 = cannon_aim_direction(index, target)
	var miss: float = distance * sin(min(nose.angle_to(aim), PI * 0.5))
	if nose.dot(aim) <= 0.0 or miss > _apparent_radius(target) * Constants.CANNON_AIM_SHARE:
		return  # Not pointing where it will be
	if not _agent_body.try_spend_power(tool_template.power_per_cycle):
		return  # Waits for power
	var shell = ShellScript.new()
	shell.size = pow(float(tool_template.round_mass) / Constants.LAW_CANNON_REF_ROUND, 1.0 / 3.0)
	shell.launch(_agent_body, target, from_pos + nose * (_apparent_radius(_agent_body) + 1.0), _agent_body.linear_velocity + nose * tool_template.projectile_speed, tool_template.damage, tool_template.flight_time)
	_after_shot(index, tool_template, shell)


func _after_shot(index: int, tool_template, projectile) -> void:
	_cycle_timers[index] = tool_template.cycle_time
	_last_cycle_ms = OS.get_ticks_msec()
	_set_ammo(index, get_ammo(index) - 1)
	emit_signal("projectile_fired", index, projectile)
	emit_signal("tool_cycled", index, projectile.target, 1.0, 0.0)


func _process_laser(index: int, target: Node) -> void:
	if _cycle_timers.get(index, 0.0) > 0.0:
		return
	var tool_template = _tools[index]
	var from_pos: Vector3 = _agent_body.global_transform.origin
	var to_pos: Vector3 = target.global_transform.origin
	var distance: float = from_pos.distance_to(to_pos)
	if distance > tool_template.get_max_range():
		return  # Stays switched on; cycles resume once back in range.
	if not _agent_body.try_spend_power(tool_template.power_per_cycle):
		return  # Stays switched on: fires again once the capacitor has the charge

	var target_velocity = target.get("linear_velocity")  # Rocks are static
	var angular: float = compute_angular_velocity(
		from_pos, _agent_body.linear_velocity, to_pos, target_velocity if target_velocity is Vector3 else Vector3.ZERO
	)
	var quality: float = tool_template.get_hit_quality(distance, angular)
	var damage: float = tool_template.damage * quality
	_cycle_timers[index] = tool_template.cycle_time
	_last_cycle_ms = OS.get_ticks_msec()
	var blocker = find_blocker(target)
	if blocker != null:
		_hit_body(blocker, from_pos, damage)
		emit_signal("tool_blocked", index, target, blocker)
		return
	_hit_body(target, from_pos, damage)
	emit_signal("tool_cycled", index, target, quality, damage)


# The first body between this ship and the target's aim point, or null for a clear line. Hit
# surfaces never block (Constants.SHOT_BLOCK_MASK): the shooter's own sits round the ray's start.
func find_blocker(target: Spatial):
	if not _agent_body.is_inside_tree():
		return null
	var aim: Vector3 = target.get_random_aim_point() if target.has_method("get_random_aim_point") else target.global_transform.origin
	var hit: Dictionary = _agent_body.get_world().direct_space_state.intersect_ray(
		_agent_body.global_transform.origin, aim, [_agent_body], Constants.SHOT_BLOCK_MASK
	)
	if hit.empty() or hit.collider == target:
		return null
	return hit.collider


# Damages (if it can be damaged) and flashes whatever the shot lands on; a faint beam shows the
# shot either way (a miss too: it ends on the near side of what it was fired at).
func _hit_body(body: Spatial, from_pos: Vector3, damage: float) -> void:
	var hit_point: Vector3
	if damage > 0.0:
		hit_point = body.register_hit(from_pos, damage) if body.has_method("register_hit") else _find_hit_point(body)
		_spawn_hit_effect(body, hit_point, damage)
	else:
		hit_point = _find_hit_point(body)
	_spawn_beam(body, hit_point, damage)
	if body.has_method("apply_damage"):
		body.apply_damage(damage, _agent_body)


func _process_harpoon(index: int, target: Node) -> void:
	var tool_template = _tools[index]
	if not _tethers.has(index):
		_launch_harpoon(index, target, tool_template)
		return
	var tether = _tethers[index]
	if tether.retracting:
		deactivate(index, "snapped" if tether.snapped else "missed")  # Already winching in
		return
	if tether.launching:
		return  # Hook still in flight
	if not tether.is_reeled_in() or _cycle_timers.get(index, 0.0) > 0.0:
		return
	_cycle_timers[index] = tool_template.strip_interval
	var wreck_tools = target.get_node_or_null("ToolController")
	if wreck_tools != null and not wreck_tools.has_method("recover_ammo_into"):
		wreck_tools = null
	if target.has_method("recover_lance_into") and target.recover_lance_into(_agent_body):
		emit_signal("lance_recovered", index)  # Lances that fit its own seat come out first, into the quiver
	elif wreck_tools != null and wreck_tools.recoverable_ammo_for(self) > 0:
		var rounds: Dictionary = wreck_tools.recover_ammo_into(self)  # Then missiles and rounds that fit its magazines
		emit_signal("ammo_recovered", rounds.index, rounds.rounds)
	elif _agent_body.get_free_cargo() <= 0:
		return  # Hold full: keep towing.
	else:
		var taken: Dictionary = target.take_salvage(1)
		for commodity_id in taken:
			_agent_body.add_cargo(commodity_id, taken[commodity_id])
		if not taken.empty():
			emit_signal("salvage_stripped", index, taken)
	if target.get_salvage_units() <= 0 and not (target.has_method("recoverable_lances_for") and target.recoverable_lances_for(_agent_body) > 0) \
			and not (wreck_tools != null and wreck_tools.recoverable_ammo_for(self) > 0):
		deactivate(index, "stripped")


func _launch_harpoon(index: int, target: Node, tool_template) -> void:
	if _cycle_timers.get(index, 0.0) > 0.0:
		return
	var distance: float = _agent_body.global_transform.origin.distance_to(target.global_transform.origin)
	if distance > tool_template.get_max_range():
		return  # Stays armed; launches once in reach.
	if not _agent_body.try_spend_power(tool_template.power_per_cycle):
		deactivate(index, "no_power")
		return
	var tether = Tether.new()
	tether.setup(
		_agent_body, target, distance, get_tether_min_length(_agent_body, target), tool_template.reel_speed,
		tool_template.launch_speed, tool_template.get_max_range() * Constants.TETHER_LAUNCH_REACH_FACTOR
	)
	add_child(tether)
	_tethers[index] = tether
	_cycle_timers[index] = tool_template.strip_interval
	emit_signal("tool_cycled", index, target, 1.0, 0.0)


# Lasers are invisible in vacuum: the hit shows as a flash and vaporized hull material (and a faint
# beam, _spawn_beam(), as a gameplay cue).
func _spawn_hit_effect(target: Spatial, hit_point: Vector3, damage: float) -> void:
	if LaserHitEffect.intensity_for_damage(damage) <= 0.0 or not target.is_inside_tree():
		return
	var effect = LaserHitScene.instance()
	effect.damage = damage
	effect.outward = (_agent_body.global_transform.origin - hit_point).normalized()
	target.add_child(effect)
	effect.global_transform = Transform(Basis(), hit_point)  # Unscaled even on scaled bodies (asteroids)


func _spawn_beam(body: Spatial, hit_point: Vector3, damage: float) -> void:
	if not body.is_inside_tree() or not _agent_body.is_inside_tree():
		return
	var heat: float = clamp(LaserHitEffect.intensity_for_damage(damage) / Constants.HIT_FX_HOT_INTENSITY, 0.0, 1.0)
	var beam = LaserBeam.new()
	beam.setup(_agent_body, body, hit_point, Constants.HIT_FX_COOL_COLOR.linear_interpolate(Constants.HIT_FX_HOT_COLOR, heat))
	_agent_body.add_child(beam)


# Fallback hit point for targets without register_hit: the side of their bounds facing this ship.
func _find_hit_point(target: Spatial) -> Vector3:
	if target.has_method("get_hull_point_facing"):
		return target.get_hull_point_facing(_agent_body.global_transform.origin)
	return target.global_transform.origin
