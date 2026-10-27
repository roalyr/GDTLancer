# ThreatRing: red arrows on a ring round the middle of the screen, one per hostile ship the player
# cannot see (behind the camera or off the screen), pointing the way to turn to see it: ships often
# come up from behind. Only ships the player's sensors detect (Agent.detects, the rule NPCs go by),
# within Constants.THREAT_RANGE. Hostile: it takes the player for an enemy (its
# faction's war or standing, a grudge, a bounty, territory: Agent.is_enemy_of). Nearer ones draw
# bigger and brighter. Shown only; it takes no input. The list is refreshed every
# THREAT_REFRESH_INTERVAL s, the arrows every frame.

extends Control

var _threats: Array = []  # Hostile ships in range (weak refs)
var _refresh_left: float = 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = Constants.THREAT_REFRESH_INTERVAL
		_threats = []
		for ship in threats(GlobalRefs.player_agent_body, get_tree().get_nodes_in_group("agent_body")):
			_threats.append(weakref(ship))
	update()


# The ships among `bodies` hostile to `player` and within THREAT_RANGE.
static func threats(player, bodies: Array) -> Array:
	var found: Array = []
	if not (is_instance_valid(player) and player is Spatial):
		return found
	var at: Vector3 = player.global_transform.origin
	for body in bodies:
		if body == player or not is_instance_valid(body) or not body.has_method("is_enemy_of"):
			continue
		if body.get("is_wreck") or body.get("is_docked") or not body.is_inside_tree():
			continue
		if at.distance_to(body.global_transform.origin) > Constants.THREAT_RANGE:
			continue
		if player.has_method("detects") and not player.detects(body):
			continue
		if body.is_enemy_of(player):
			found.append(body)
	return found


# Which way on the screen `point` lies from the camera's view axis (unit; y down), behind it included.
static func screen_direction(camera_transform: Transform, point: Vector3) -> Vector2:
	var local: Vector3 = camera_transform.basis.xform_inv(point - camera_transform.origin)
	var direction := Vector2(local.x, -local.y)
	if direction.length_squared() < 0.000001:
		return Vector2(0, 1)  # Dead astern: point down
	return direction.normalized()


func _draw() -> void:
	var camera = GlobalRefs.main_camera
	var player = GlobalRefs.player_agent_body
	if not (is_instance_valid(camera) and is_instance_valid(player)) or _threats.empty():
		return
	var view_size: Vector2 = camera.get_viewport().size
	var centre: Vector2 = rect_size * 0.5
	var radius: float = min(rect_size.x, rect_size.y) * Constants.THREAT_RING_RADIUS_SHARE
	var from: Vector3 = player.global_transform.origin
	for ref in _threats:
		var ship = ref.get_ref()
		if not is_instance_valid(ship) or ship.get("is_wreck") or ship.get("is_docked"):
			continue
		var point: Vector3 = ship.global_transform.origin
		if not camera.is_position_behind(point):
			var on_screen: Vector2 = camera.unproject_position(point)
			if Rect2(Vector2.ZERO, view_size).grow(-view_size.y * 0.05).has_point(on_screen):
				continue  # In sight: its bracket shows it
		var nearness: float = 1.0 - clamp(from.distance_to(point) / Constants.THREAT_RANGE, 0.0, 1.0)
		var size: float = lerp(Constants.THREAT_ARROW_SIZE[0], Constants.THREAT_ARROW_SIZE[1], nearness)
		var colour: Color = Constants.THREAT_COLOR
		colour.a = lerp(0.45, 1.0, nearness)
		var direction: Vector2 = screen_direction(camera.global_transform, point)
		var base: Vector2 = centre + direction * radius
		var tip: Vector2 = base + direction * size
		var notch: Vector2 = base + direction * size * 0.35  # A notched head reads as pointing outward
		var side: Vector2 = direction.tangent() * size * 0.4
		var head := PoolVector2Array([tip, base + side, notch, base - side])
		draw_colored_polygon(head, colour)
		head.append(tip)
		draw_polyline(head, Color(0, 0, 0, colour.a * 0.7), 2.0, true)  # Outlined: seen on a bright star too
