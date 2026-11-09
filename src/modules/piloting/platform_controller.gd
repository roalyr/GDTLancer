# PlatformController: a weapon platform's mind (Constants PLATFORM_*). A platform is a ship built by
# the ship laws (PLATFORM_SEED) that never moves (its body's translation is locked; its engine share
# only turns it) and stands guard by a station (AgentSystem places and rebuilds them, HavenMarker.platforms).
# - Targets: the nearest ship in reach that is its enemy (Agent.is_enemy_of; a neutral platform has
#   none by faction) or that opened fire near it (PLATFORM_GUARD_RADIUS) on anyone but its own side
#   or its enemies, and not in defence (at a ship it holds a grudge on: one that shot it, or its
#   ward or friend it went to help): it holds a grudge on that ship from then on.
# - It turns to face the target (NavigationSystem's watch; an active cannon holds the nose on its
#   lead), and fires every weapon in reach, as the AI does (ShipControllerAI._fire_at), but only
#   with a clear shot: it holds fire while a ship not its foe is near the line (PLATFORM_CLEAR_SHOT).
# - A stray hit on it (a shot at another ship) is no attack: only a shooter aiming at it is a foe.
# - Rounds come back on a timer (PLATFORM_REARM_INTERVAL), not from a base.
# Other platforms are never its targets.

extends Node

const ShipLaws = preload("res://src/core/systems/ship_laws.gd")
const Genome = preload("res://src/core/evolution/genome.gd")

var agent_script: RigidBody = null
var station: Spatial = null  # The station it guards
var _tools: Node = null
var _target = null
var _scan_timer := 0.0
var _rearm_timer := 0.0


# The platform's ship and fit for `faction` (template ids, registered once): ShipLaws from PLATFORM_SEED.
static func build(faction: String) -> Dictionary:
	var genome: Dictionary = Genome.seed_genome(Constants.PLATFORM_SEED)
	var ship_id: String = "platform_ship@%s" % faction
	if not TemplateDatabase.evolved.has(ship_id):
		var ship = ShipLaws.build_ship_template(genome.ship, ship_id, "Weapon Platform", faction)
		ship.ship_scene = load(Constants.PLATFORM_HULL_SCENE)
		TemplateDatabase.register_evolved(ship)
	var fit := {"tools": [], "modules": []}
	for part in genome.tools:
		fit.tools.append(Genome.ensure_part_template(part))
	for part in genome.modules:
		fit.modules.append(Genome.ensure_part_template(part))
	return {"ship_template_id": ship_id, "fit": fit}


func _ready() -> void:
	agent_script = get_parent()
	_tools = agent_script.get_node_or_null("ToolController")
	EventBus.connect("agent_damaged", self, "_on_agent_damaged")
	agent_script.axis_lock_linear_x = true
	agent_script.axis_lock_linear_y = true
	agent_script.axis_lock_linear_z = true
	_scan_timer = randf() * Constants.PLATFORM_SCAN_INTERVAL


func setup(guarded: Spatial) -> void:
	station = guarded


func get_target():
	return _target if _is_live_target(_target) else null


# What the HUD shows of it, as of a ship (ShipControllerAI.get_activity_label).
func get_activity_label() -> String:
	return "FIRING" if get_target() != null else "GUARDING"


func _physics_process(delta: float) -> void:
	if not is_instance_valid(agent_script) or agent_script.is_wreck or not is_instance_valid(_tools):
		return
	_rearm_timer += delta
	if _rearm_timer >= Constants.PLATFORM_REARM_INTERVAL:
		_rearm_timer = 0.0
		_tools.restock_ammo()
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = Constants.PLATFORM_SCAN_INTERVAL
	var target = _pick_target()
	if target != _target:
		_tools.deactivate_all("retarget")
		_target = target
		if target == null:
			agent_script.command_stop()
		else:
			agent_script.command_watch(target)
	if target != null:
		if clear_shot(target):
			_fire_at(target)
		else:
			_tools.deactivate_all("blocked")


func _fire_at(target) -> void:
	var distance: float = agent_script.global_transform.origin.distance_to(target.global_transform.origin)
	for index in range(_tools.get_tool_count()):
		var tool_template = _tools.get_tool(index)
		if tool_template == null or not tool_template.tool_type in ["laser", "missile", "cannon"]:
			continue
		if _tools.is_active(index) or not _tools.can_target(tool_template, target):
			continue
		if distance <= _tools.reach_on(index, target) and agent_script.power >= tool_template.power_per_cycle:
			_tools.activate(index, target)


# No ship but foes within PLATFORM_CLEAR_SHOT m (plus its size) of the line to `target`.
func clear_shot(target) -> bool:
	var from: Vector3 = agent_script.global_transform.origin
	var line: Vector3 = target.global_transform.origin - from
	var length: float = line.length()
	if length < 1.0:
		return true
	var along_unit: Vector3 = line / length
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body == agent_script or body == target or not _is_live_target(body) or body.get("is_platform") or is_foe(body):
			continue
		var offset: Vector3 = body.global_transform.origin - from
		var along: float = offset.dot(along_unit)
		if along <= 0.0 or along >= length + Constants.PLATFORM_CLEAR_SHOT:
			continue
		var radius: float = body.get_hull_radius() if body.has_method("get_hull_radius") else 0.0
		if (offset - along_unit * along).length() <= Constants.PLATFORM_CLEAR_SHOT + radius:
			return false
	return true


# Whether `source` aims a weapon at it now (a stray shot at another ship is no attack).
static func _aims_at(source, body) -> bool:
	var tools = source.get_node_or_null("ToolController")
	if tools == null or not tools.has_method("get_target"):
		return true  # Nothing to tell by: take it as meant
	for index in range(tools.get_tool_count()):
		if tools.get_target(index) == body:
			return true
	var lance = source.get_lance() if source.has_method("get_lance") else null
	return lance != null and lance.has_method("get_aim_target") and lance.get_aim_target() == body


# The nearest foe its weapons reach.
func _pick_target():
	var reach := 0.0
	for index in range(_tools.get_tool_count()):
		var tool_template = _tools.get_tool(index)
		if tool_template != null:
			reach = max(reach, tool_template.get_max_range())
	var here: Vector3 = agent_script.global_transform.origin
	var best = null
	var best_distance: float = reach
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body == agent_script or not _is_live_target(body) or body.get("is_platform"):
			continue
		var distance: float = here.distance_to(body.global_transform.origin)
		if distance > best_distance or not is_foe(body) or not agent_script.detects(body):
			continue
		best = body
		best_distance = distance
	return best


# Whom it fires on: those it holds a grudge on, and its faction's enemies (a neutral platform: none).
func is_foe(body) -> bool:
	if agent_script._grudges.has(body.get_instance_id()):
		return true
	return agent_script.faction != "" and agent_script.is_enemy_of(body)


func _is_live_target(body) -> bool:
	return is_instance_valid(body) and body.is_inside_tree() and not body.get("is_wreck") and not body.get("is_docked")


# Someone shot at near it: unless that is its own side, or the one shot at is its foe, the shooter is
# now its foe.
func _on_agent_damaged(victim, _amount, source) -> void:
	if not (is_instance_valid(agent_script) and not agent_script.is_wreck and _is_live_target(source) and is_instance_valid(victim)):
		return
	if source == agent_script or source.get("is_platform") or victim == source:
		return
	if agent_script.faction != "" and source.get("faction") == agent_script.faction:
		return
	if victim != agent_script and is_foe(victim):
		return  # Fire on its foes is welcome
	if victim != agent_script and source.get("_grudges") is Dictionary and source._grudges.has(victim.get_instance_id()):
		return  # Fighting back (era 59 smoke: escorts guarding their ward by the Free Port were shot down as aggressors)
	if victim == agent_script and not _aims_at(source, agent_script):
		return  # A stray shot (era 59 smoke: fighters whose shells missed and hit a platform were shot down)
	if victim.global_transform.origin.distance_to(agent_script.global_transform.origin) > Constants.PLATFORM_GUARD_RADIUS:
		return
	agent_script._hold_grudge(source)
