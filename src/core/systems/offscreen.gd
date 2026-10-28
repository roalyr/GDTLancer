# Offscreen: ships far from the player are resolved cheaply instead of flown (Constants OFFSCREEN_*).
# Past OFFSCREEN_RADIUS a ship leaves the physics (a static body: no integration, no navigation) and
# its AI, tools and lance stop; it keeps its place in the world, so it is still a marker that sensors
# pick up (Agent.detects, by its signature, as any ship) and brackets show. Back within
# OFFSCREEN_FULL_RADIUS it flies again, at the velocity it was given. Wrecks and ore chunks are only
# frozen. Docked ships are out of the physics anyway (Agent.dock_at) and keep their AI, so they undock
# on time, and are abstracted again once out.
# Every OFFSCREEN_TICK s each abstracted ship does one of, by the AI's own judgement where it has one:
#   home   - its hold full, its time up (Evolution) or its hull below its retreat level (genes):
#            to its station and docks there (sells, repairs, retires: as when flown), or a
#            traveller leaving the sector flies out to its jump point and goes;
#   fight  - the nearest enemy it detects: closes to OFFSCREEN_ENGAGE_RANGE, then deals its damage
#            per second times OFFSCREEN_HIT_SHARE through apply_damage (kills, wrecks, bounties and
#            standing as in a flown fight);
#   mine   - a prospector (ShipControllerAI.can_mine) near a rock gains OFFSCREEN_ORE_PER_SECOND;
#   patrol - back toward the middle of its patrol.
# It moves at OFFSCREEN_SPEED_SHARE of its top speed. These rules are first guesses, to be fitted to
# what flown fights and runs do (the evolution logs). A life resolved off-screen in part is not
# scored by Evolution (mark_offscreen): the rules must not shape the presets.
# A child of AgentSystem; off in the evolution sim (everything is flown there).

extends Node

var enabled: bool = true
var _entries: Dictionary = {}  # Instance id -> {"body": WeakRef, "velocity": Vector3}
var _check_left: float = 0.0
var _tick_left: float = 0.0


func _ready() -> void:
	EventBus.connect("zone_unloading", self, "_on_zone_unloading")


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = Constants.OFFSCREEN_CHECK_INTERVAL
		check()
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = Constants.OFFSCREEN_TICK
		resolve(Constants.OFFSCREEN_TICK)


func is_offscreen(body: Node) -> bool:
	return is_instance_valid(body) and _entries.has(body.get_instance_id())


# Ships resolved off-screen now (wrecks and chunks, only frozen, not counted).
func count() -> int:
	var ships := 0
	for entry in _entries.values():
		var body = entry.body.get_ref()
		if is_instance_valid(body) and not body.get("is_wreck") and not body.get("is_docked"):
			ships += 1
	return ships


# Abstracts the far ships and restores the near ones.
func check() -> void:
	var player = GlobalRefs.player_agent_body
	if not (is_instance_valid(player) and player.is_inside_tree()):
		return
	var here: Vector3 = player.global_transform.origin
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body == player or not (body is RigidBody) or not body.is_inside_tree():
			continue
		var distance: float = here.distance_to(body.global_transform.origin)
		if _entries.has(body.get_instance_id()):
			if distance < Constants.OFFSCREEN_FULL_RADIUS:
				restore(body)
		elif distance > Constants.OFFSCREEN_RADIUS and _can_abstract(body):
			abstract(body)


func _can_abstract(body: Node) -> bool:
	if body.get("is_docked"):
		return false  # Out of the physics already; its AI undocks it on time
	var tools = body.get_node_or_null("ToolController")
	return not (is_instance_valid(tools) and not tools.get("_tethers").empty())  # Towing: let the tow finish flown


func abstract(body: RigidBody) -> void:
	_entries[body.get_instance_id()] = {"body": weakref(body), "velocity": body.linear_velocity}
	body.mode = RigidBody.MODE_STATIC
	_set_flown(body, false)
	var uid: String = str(body.get("evo_uid")) if body.get("evo_uid") != null else ""
	if uid != "":
		Evolution.mark_offscreen(uid)


func restore(body: RigidBody) -> void:
	var entry: Dictionary = _entries.get(body.get_instance_id(), {})
	_entries.erase(body.get_instance_id())
	if not body.get("is_docked"):
		body.mode = RigidBody.MODE_RIGID
		body.sleeping = false
		body.linear_velocity = entry.get("velocity", Vector3.ZERO)
	_set_flown(body, true)


func _set_flown(body: Node, on: bool) -> void:
	body.set_physics_process(on)
	for name in [Constants.AI_CONTROLLER_NODE_NAME, "NavigationSystem", "ToolController"]:
		var node = body.get_node_or_null(name)
		if node != null:
			node.set_physics_process(on)
			if name == "ToolController" and not on and node.has_method("deactivate_all"):
				node.deactivate_all("offscreen")
	for lance in (body.get_lances() if body.has_method("get_lances") else []):
		lance.set_physics_process(on)


# --- Resolution ---

func resolve(dt: float) -> void:
	for id in _entries.keys():
		var entry: Dictionary = _entries[id]
		var body = entry.body.get_ref()
		if not is_instance_valid(body) or not body.is_inside_tree():
			_entries.erase(id)
			continue
		if body.get("is_wreck") or body.get("is_docked"):
			entry.velocity = Vector3.ZERO
			continue
		var ai = body.get_node_or_null(Constants.AI_CONTROLLER_NODE_NAME)
		if ai == null:
			continue
		_resolve_ship(body, ai, entry, dt)


func _resolve_ship(body: RigidBody, ai: Node, entry: Dictionary, dt: float) -> void:
	var enemy = _nearest_enemy(body)
	var going_home: bool = ai.is_leaving() or body.get_free_cargo() <= 0 or ai.hold_worth_hauling() or ai._due_home() or (enemy != null and ai._should_retreat())
	if going_home:
		_go_home(body, ai, entry, dt, enemy)
		return
	if enemy != null and ai.can_mine() and body.global_transform.origin.distance_to(enemy.global_transform.origin) > Constants.OFFSCREEN_ENGAGE_RANGE:
		enemy = null  # A prospector minds its mining (ShipControllerAI.is_mining_work)
	if enemy != null:
		var distance: float = body.global_transform.origin.distance_to(enemy.global_transform.origin)
		if distance > Constants.OFFSCREEN_ENGAGE_RANGE:
			_move(body, entry, enemy.global_transform.origin, dt, Constants.OFFSCREEN_ENGAGE_RANGE * 0.8)
		else:
			entry.velocity = Vector3.ZERO
			enemy.apply_damage(body.get_damage_per_second() * Constants.OFFSCREEN_HIT_SHARE * dt, body)
		return
	if ai.can_mine():
		var rock: Spatial = _nearest_rock(body)
		if rock != null:
			var reach: float = rock.get_apparent_radius() + Constants.OFFSCREEN_MINE_RANGE
			if body.global_transform.origin.distance_to(rock.global_transform.origin) > reach:
				_move(body, entry, rock.global_transform.origin, dt, reach * 0.8)
			else:
				entry.velocity = Vector3.ZERO
				entry["ore"] = float(entry.get("ore", 0.0)) + Constants.OFFSCREEN_ORE_PER_SECOND * dt
				var units: int = int(min(floor(entry.ore), body.get_free_cargo()))
				if units > 0:
					body.add_cargo(rock.deposit_id if rock.get("deposit_id") != null else Constants.MINING_DEPOSIT, units)
					entry.ore -= units
			return
	_move(body, entry, ai._home_position, dt, Constants.OFFSCREEN_PATROL_RADIUS)


# To its station and docked there (an arena NPC), or out through its jump point (a traveller).
func _go_home(body: RigidBody, ai: Node, entry: Dictionary, dt: float, threat) -> void:
	if not ai._arena.empty():
		var station = ai._pick_refuge(threat)
		if not is_instance_valid(station):
			_move(body, entry, ai._home_position, dt, 0.0)
			return
		var dock_point: Vector3 = station.get_undock_position()
		if body.global_transform.origin.distance_to(dock_point) <= Constants.ARENA_DOCK_DISTANCE:
			ai._dock(station, true)  # Sells, repairs or retires, as when flown
			if is_instance_valid(body) and body.is_inside_tree() and body.get("is_docked"):
				restore(body)  # Docked ships keep their AI (it undocks them)
			return
		_move(body, entry, dock_point, dt, 0.0)
		return
	if body.global_transform.origin.distance_to(ai._home_point) <= Constants.AI_DEPART_ARRIVAL_DISTANCE:
		_entries.erase(body.get_instance_id())
		body.despawn()  # Out of the sector (Traffic takes it from here)
		return
	_move(body, entry, ai._home_point, dt, 0.0)


# Toward `point` at OFFSCREEN_SPEED_SHARE of top speed, stopping `short` m from it; faces its way.
func _move(body: RigidBody, entry: Dictionary, point: Vector3, dt: float, short: float) -> void:
	var offset: Vector3 = point - body.global_transform.origin
	var distance: float = offset.length() - short
	if distance <= 1.0:
		entry.velocity = Vector3.ZERO
		return
	var speed: float = min(body.get_top_speed() * Constants.OFFSCREEN_SPEED_SHARE, distance / max(dt, 0.001))
	var velocity: Vector3 = offset.normalized() * speed
	var origin: Vector3 = body.global_transform.origin + velocity * dt
	var up: Vector3 = Vector3.UP if abs(offset.normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	body.global_transform = Transform(Basis(), origin).looking_at(origin + velocity, up)
	entry.velocity = velocity


func _nearest_enemy(body: RigidBody) -> Node:
	var best: Node = null
	var best_distance: float = INF
	var here: Vector3 = body.global_transform.origin
	for other in get_tree().get_nodes_in_group("agent_body"):
		if other == body or other.get("is_wreck") != false or other.get("is_docked") or not other.has_method("apply_damage"):
			continue
		var distance: float = here.distance_to(other.global_transform.origin)
		if distance < best_distance and body.detects(other) and body.is_enemy_of(other):
			best = other
			best_distance = distance
	return best


func _nearest_rock(body: RigidBody) -> Spatial:
	var best: Spatial = null
	var best_distance: float = Constants.AI_MINE_SEARCH_RANGE
	var here: Vector3 = body.global_transform.origin
	for rock in get_tree().get_nodes_in_group("mineable"):
		if rock.has_method("get_deposit") and rock.get_deposit() <= 0:
			continue
		var distance: float = here.distance_to(rock.global_transform.origin) - rock.get_apparent_radius()
		if distance < best_distance:
			best = rock
			best_distance = distance
	return best


func _on_zone_unloading(_zone) -> void:
	_entries.clear()
