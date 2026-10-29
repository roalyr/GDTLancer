# BeaconNetwork: a sector's beacons as the AI's map (Constants SECTOR LAYOUT ... block). It keeps
# their numbers (heat from fire near them, traffic from ships passing, each faction's last visit
# and presence, a field's ore), plans routes over them and chooses where an NPC goes next.
#
# Routes: every beacon is linked to every other (no distance cut-off). A link costs its flying time
# plus, by the ship's caution, its ends' heat and the hull a hazard would take on the way, so a
# clear straight line always wins: fearless ships go straight and careful ones go round a star or
# a fight. One plan (Dijkstra from the ship) gives the cost to every beacon, and the path to the
# one chosen.
# Choices, by job: "patrol" (armed faction ships), "hunt" (raiders), "scavenge" (unarmed), "mine"
# (prospectors); see Constants CHOICE_*. Each beacon's interest over its route cost: the best one.
# Distress: a mayday (call_distress) is a beacon for a while; its faction's patrols are drawn to it,
# its enemies too, as to a raid. Patrolling ships choose again when one is called (distress_serial).
# Simple rules, so the patterns are the AI's own: patrols drawn to trouble, raiders to busy
# beacons patrols have left, miners to rich fields that are not hot, careful haulers round danger.

extends Node

const BeaconScript = preload("res://src/scenes/game_world/sector_layout/beacon.gd")

var time: float = 0.0  # s this network has run
var beacons: Array = []
var hazards: Array = []
var play_center: Vector3 = Vector3.ZERO
var play_radius: float = INF
var _since_update: float = 0.0
var _since_values: float = INF
var _at: Dictionary = {}  # Ship instance id -> the beacon it was last counted at
var _links: Dictionary = {}  # "i,j" -> [length, hazard exposure] between beacons (fixed: beacons do not move)
var distress_serial: int = 0  # Counts maydays called: a patrol that has not seen the latest chooses again


func _ready() -> void:
	add_to_group("beacon_network")
	EventBus.connect("agent_damaged", self, "_on_agent_damaged")
	EventBus.connect("agent_disabled", self, "_on_agent_disabled")


func register(beacon: Node) -> void:
	beacons.append(beacon)
	_links.clear()


func register_hazard(hazard: Node) -> void:
	hazards.append(hazard)
	_links.clear()


# The network of the sector `node` is in, or null.
static func of(node: Node):
	if not is_instance_valid(node) or not node.is_inside_tree():
		return null
	var found: Array = node.get_tree().get_nodes_in_group("beacon_network")
	return found[0] if not found.empty() else null


# --- Numbers ---

func _physics_process(delta: float) -> void:
	time += delta
	_since_update += delta
	_since_values += delta
	if _since_update >= Constants.BEACON_UPDATE_INTERVAL:
		_update(_since_update)
		_since_update = 0.0
	if _since_values >= Constants.BEACON_FIELD_VALUE_INTERVAL:
		_since_values = 0.0
		_count_fields()


func _update(dt: float) -> void:
	for beacon in beacons.duplicate():
		if beacon.expires <= time:
			_remove(beacon)
	var heat_keep: float = pow(0.5, dt / Constants.BEACON_HEAT_HALF_LIFE)
	var traffic_keep: float = pow(0.5, dt / Constants.BEACON_TRAFFIC_HALF_LIFE)
	for beacon in beacons:
		beacon.heat *= heat_keep
		beacon.traffic *= traffic_keep
		beacon.presence = {}
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body.get("is_wreck") != false or body.get("is_docked") or not body.has_method("apply_damage"):
			continue
		var faction: String = str(body.get("faction"))
		var beacon = nearest(body.global_transform.origin, Constants.BEACON_TRAFFIC_RADIUS, true)
		var id: int = body.get_instance_id()
		if beacon == null:
			_at.erase(id)
			continue
		beacon.presence[faction] = int(beacon.presence.get(faction, 0)) + 1
		beacon.last_visit[faction] = time
		if _at.get(id) != beacon:
			_at[id] = beacon
			beacon.traffic += 1.0


func _count_fields() -> void:
	var rocks: Array = get_tree().get_nodes_in_group("mineable")
	for beacon in beacons:
		if beacon.kind != "field":
			continue
		var total := 0
		for rock in rocks:
			if rock.global_transform.origin.distance_to(beacon.global_transform.origin) <= beacon.radius + Constants.BEACON_LOITER_RADIUS:
				total += rock.get_deposit()
		beacon.value = total


# Hull lost to someone's fire: heat at the nearest beacon (a share of the victim's hull).
func _on_agent_damaged(body, amount, source) -> void:
	if not is_instance_valid(source) or source == body or not is_instance_valid(body) or not body.is_inside_tree():
		return
	var beacon = nearest(body.global_transform.origin, Constants.BEACON_HEAT_RADIUS)
	if beacon != null:
		beacon.heat += min(float(amount), float(body.hull_max)) / max(float(body.hull_max), 1.0)


func _on_agent_disabled(body) -> void:
	if not is_instance_valid(body) or not body.is_inside_tree() or body.is_in_group("ore_chunk"):
		return
	var beacon = nearest(body.global_transform.origin, Constants.BEACON_HEAT_RADIUS)
	if beacon != null:
		beacon.heat += Constants.BEACON_HEAT_PER_KILL


# The beacon nearest `point` within `within` m (a field: within its radius, if that is more), or null.
func nearest(point: Vector3, within: float = INF, by_radius: bool = false):
	var best = null
	var best_distance: float = INF
	for beacon in beacons:
		var distance: float = point.distance_to(beacon.global_transform.origin)
		var reach: float = max(within, beacon.radius) if by_radius else within
		if distance <= reach and distance < best_distance:
			best = beacon
			best_distance = distance
	return best


# --- Distress ---

# A mayday from a ship of `faction` at `at` (Constants DISTRESS_*): a distress beacon there, or the
# one already near it renewed. Returns it.
func call_distress(faction: String, at: Vector3, caller_name: String) -> Node:
	distress_serial += 1
	for beacon in beacons:
		if beacon.kind == "distress" and beacon.faction == faction and beacon.global_transform.origin.distance_to(at) <= Constants.DISTRESS_MERGE:
			beacon.expires = time + Constants.DISTRESS_TIME
			return beacon
	var beacon = BeaconScript.new()
	beacon.name = "Beacon_Distress_%d" % distress_serial
	beacon.kind = "distress"
	beacon.faction = faction
	beacon.beacon_name = "Mayday " + caller_name
	beacon.player_visible = true  # Heard on the common frequency
	beacon.expires = time + Constants.DISTRESS_TIME
	var holder: Node = get_parent() if get_parent() is Spatial else self
	holder.add_child(beacon)
	beacon.global_transform.origin = at
	register(beacon)
	return beacon


func _remove(beacon: Node) -> void:
	beacons.erase(beacon)
	_links.clear()  # Keyed by index
	for id in _at.keys():
		if _at[id] == beacon:
			_at.erase(id)
	beacon.queue_free()


# --- Routes ---

# Hull a straight flight from `from` to `to` would lose to hazards, times the speed.
func exposure(from: Vector3, to: Vector3) -> float:
	var total := 0.0
	for hazard in hazards:
		if is_instance_valid(hazard):
			total += hazard.exposure(from, to)
	return total


func _link(i: int, j: int) -> Array:
	var key: String = "%d,%d" % [min(i, j), max(i, j)]
	if not _links.has(key):
		var a: Vector3 = beacons[i].global_transform.origin
		var b: Vector3 = beacons[j].global_transform.origin
		_links[key] = [a.distance_to(b), exposure(a, b)]
	return _links[key]


# Cost (s) of a link `length` m long with `hazard` exposure, between ends of heat `heat`.
static func link_cost(length: float, hazard: float, heat: float, speed: float, caution: float, hull_max: float) -> float:
	var care: float = max(0.0, caution) / Constants.AI_AVOID_SHARE
	var damage_share: float = hazard / max(speed, 1.0) / max(hull_max, 1.0)
	return length / max(speed, 1.0) + care * (Constants.ROUTE_HEAT_COST * heat + Constants.ROUTE_DAMAGE_COST * damage_share)


# Dijkstra from `from` over the beacons: {"cost": [s to each beacon], "prev": [index before it, -1:
# from the start]}. The start links to every beacon.
func plan(from: Vector3, speed: float, caution: float, hull_max: float) -> Dictionary:
	var n: int = beacons.size()
	var cost: Array = []
	var prev: Array = []
	var done: Array = []
	for i in range(n):
		var at: Vector3 = beacons[i].global_transform.origin
		cost.append(link_cost(from.distance_to(at), exposure(from, at), beacons[i].heat * 0.5, speed, caution, hull_max))
		prev.append(-1)
		done.append(false)
	for _step in range(n):
		var u: int = -1
		for i in range(n):
			if not done[i] and cost[i] < INF and (u < 0 or cost[i] < cost[u]):
				u = i
		if u < 0:
			break
		done[u] = true
		for v in range(n):
			if done[v]:
				continue
			var link: Array = _link(u, v)
			var through: float = cost[u] + link_cost(link[0], link[1], (beacons[u].heat + beacons[v].heat) * 0.5, speed, caution, hull_max)
			if through < cost[v]:
				cost[v] = through
				prev[v] = u
	return {"cost": cost, "prev": prev}


# The beacons' positions on the planned way to beacon `index`, in order (it last).
func path(planned: Dictionary, index: int) -> Array:
	var points: Array = []
	var at: int = index
	while at >= 0:
		points.push_front(beacons[at].global_transform.origin)
		at = planned.prev[at]
	return points


# Waypoints from `from` to `to`: through the beacons when that is cheaper than going straight
# (round a hazard, a hot beacon), straight otherwise; `to` last.
func route(from: Vector3, to: Vector3, speed: float, caution: float, hull_max: float) -> Array:
	var straight: float = link_cost(from.distance_to(to), exposure(from, to), 0.0, speed, caution, hull_max)
	var goal = nearest(to)
	if goal == null:
		return [to]
	var planned: Dictionary = plan(from, speed, caution, hull_max)
	var index: int = beacons.find(goal)
	var via: float = planned.cost[index] + link_cost(goal.global_transform.origin.distance_to(to), exposure(goal.global_transform.origin, to), 0.0, speed, caution, hull_max)
	if via >= straight:
		return [to]
	var points: Array = path(planned, index)
	points.append(to)
	return points


# --- Choices ---

# Where a ship goes next: {"beacon", "cost" (s)}, or {} if nowhere is worth it. `ship`: {"from",
# "speed", "caution", "hull_max", "faction", "keen" (how keen on fights, 1 by default), "job"}.
func choose(ship: Dictionary) -> Dictionary:
	var planned: Dictionary = plan(ship.from, ship.speed, ship.caution, ship.hull_max)
	var best := {}
	var best_score := 0.0
	for i in range(beacons.size()):
		if planned.cost[i] == INF or beacons[i].global_transform.origin.distance_to(play_center) > play_radius:
			continue
		var score: float = interest(beacons[i], ship) / (planned.cost[i] + Constants.ROUTE_TIME_FLOOR)
		if score > best_score:
			best_score = score
			best = {"beacon": beacons[i], "cost": planned.cost[i], "path": path(planned, i)}
	return best


# How much a beacon draws a ship on its job (Constants CHOICE_*).
func interest(beacon: Node, ship: Dictionary) -> float:
	var faction: String = ship.faction
	var stale: float = 1.0 + (time - float(beacon.last_visit.get(faction, 0.0))) / Constants.CHOICE_STALE_TIME
	if beacon.kind == "distress":  # Fresh trouble, fading as it ages: patrols only
		var fresh: float = clamp((beacon.expires - time) / Constants.DISTRESS_TIME, 0.0, 1.0) * float(ship.get("keen", 1.0)) * (1.0 + beacon.heat)
		if ship.job != "patrol":
			return 0.0
		if beacon.faction == faction:
			return Constants.CHOICE_DISTRESS * fresh
		return Constants.CHOICE_RAID * fresh if _at_war(faction, beacon.faction) else 0.0
	match ship.job:
		"mine":
			if beacon.kind != "field":
				return 0.0
			return beacon.value / Constants.CHOICE_FIELD_VALUE * exp(-max(0.0, ship.caution) / Constants.AI_AVOID_SHARE * beacon.heat)
		"scavenge":
			return beacon.heat + 0.1 * beacon.traffic
		"hunt":
			if beacon.kind == "haven" and beacon.faction == faction:
				return 0.0
			var guards: int = int(beacon.presence.get(beacon.faction, 0)) if beacon.faction != "" and beacon.faction != faction else 0
			return (beacon.traffic + Constants.CHOICE_HUNT_FLOOR) / (1.0 + guards) * stale
		_:  # Patrol
			var base := 0.0
			match beacon.kind:
				"patrol":
					if beacon.faction == faction:
						base = Constants.CHOICE_OWN_PATROL
					elif _at_war(faction, beacon.faction):
						base = Constants.CHOICE_RAID * float(ship.get("keen", 1.0))
				"field":
					base = Constants.CHOICE_FIELD
				"landmark":
					base = Constants.CHOICE_LANDMARK
			return base * stale * (1.0 + beacon.heat)


static func _at_war(faction: String, other: String) -> bool:
	return other in Constants.FACTIONS.get(faction, {}).get("enemies", []) or faction in Constants.FACTIONS.get(other, {}).get("enemies", [])
