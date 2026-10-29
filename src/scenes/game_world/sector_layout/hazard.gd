# Hazard: a region that hurts ships in it (Constants SECTOR_LAYOUTS "hazards"). "radiation" round a
# star: from `core` (its surface) out to `radius`; hull damage a second rises from 0 at the edge to
# HAZARD_RADIATION_DPS at the surface, as the square of the depth. Ships flown or resolved off-screen
# alike take it every HAZARD_TICK s (no attacker: nobody is credited). Routes count it
# (BeaconNetwork) and the player is told on the way in and out.

extends Spatial

export var kind: String = "radiation"
export var core: float = 5000.0  # m
export var radius: float = 15000.0  # m

var _since_tick: float = 0.0
var _player_inside: bool = false


func _ready() -> void:
	add_to_group("hazard")


# Hull lost a second at `point`.
func dps_at(point: Vector3) -> float:
	var depth: float = (radius - point.distance_to(global_transform.origin)) / max(radius - core, 1.0)
	return Constants.HAZARD_RADIATION_DPS * pow(clamp(depth, 0.0, 1.0), 2.0)


# Hull a ship flying straight from `from` to `to` would lose, times its speed (divide by the speed).
func exposure(from: Vector3, to: Vector3) -> float:
	var length: float = from.distance_to(to)
	if length <= 0.0 or _segment_distance(from, to) >= radius:
		return 0.0
	var total := 0.0
	var steps: int = Constants.ROUTE_SAMPLES
	for index in range(steps):
		total += dps_at(from.linear_interpolate(to, (index + 0.5) / steps))
	return total * length / steps


func _segment_distance(from: Vector3, to: Vector3) -> float:
	var centre: Vector3 = global_transform.origin
	var along: Vector3 = to - from
	var t: float = clamp((centre - from).dot(along) / max(along.length_squared(), 0.001), 0.0, 1.0)
	return centre.distance_to(from + along * t)


func _physics_process(delta: float) -> void:
	_since_tick += delta
	if _since_tick < Constants.HAZARD_TICK:
		return
	var tick: float = _since_tick
	_since_tick = 0.0
	var player_inside := false
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body.get("is_wreck") != false or body.get("is_docked") or not body.has_method("apply_damage"):
			continue
		var dps: float = dps_at(body.global_transform.origin)
		if body.has_method("is_player") and body.is_player() and body.global_transform.origin.distance_to(global_transform.origin) < radius:
			player_inside = true
		if dps > 0.0:
			body.apply_damage(dps * tick, null)
	if player_inside != _player_inside:
		_player_inside = player_inside
		EventBus.emit_signal("announcement", "RADIATION: the nearer the star, the more hull it burns" if player_inside else "Out of the radiation", "danger" if player_inside else "info")
