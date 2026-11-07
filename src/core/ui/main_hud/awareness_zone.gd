# AwarenessZone (scenes/ui/hud/awareness_zone.tscn): the strip along the top of the HUD with what a
# pilot glances at, read as colours and lengths more than words:
# - the target (large): its name, distance and hull, in its mark's colour (TargetKinds);
# - own speed, ships the sensors see (the hostile ones in red), own signature (its word, dimmer while
#   quiet, brighter as it grows: Agent.get_signature against the hull's quiet base);
# - bars: own hull, energy and cargo space used;
# - the radio, dimmer than the rest: the last HUD_RADIO_LINES lines heard (MainHUD.radio_lines).
# Refreshed every Constants.HUD_AWARENESS_INTERVAL s (labels lay out again on every change). It
# takes no input. MainHUD sets `target` and `radio_lines`.

extends Control

const TargetKinds = preload("res://src/core/ui/main_hud/target_kinds.gd")
const Bracket = preload("res://src/core/ui/main_hud/projected_target_bracket.gd")

var target = null  # The selected target (MainHUD)
var target_name: String = ""
var radio_lines: Array = []  # MainHUD's, oldest first
var suppressed: bool = false  # Hidden while the debug overlay is up (MainHUD)

onready var _target_row: Control = $Layout/TargetRow
onready var _target_name: Label = $Layout/TargetRow/Name
onready var _target_distance: Label = $Layout/TargetRow/Distance
onready var _target_hull: Control = $Layout/TargetRow/Hull
onready var _speed: Label = $Layout/StatusRow/Speed
onready var _ships: Label = $Layout/StatusRow/Ships
onready var _hostiles: Label = $Layout/StatusRow/Hostiles
onready var _signature: Label = $Layout/StatusRow/Signature
onready var _hull: Control = $Layout/Bars/Hull
onready var _energy: Control = $Layout/Bars/Energy
onready var _cargo: Control = $Layout/Bars/Cargo
onready var _radio: Label = $Layout/Radio

var _left: float = 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for child in _all_children(self):
		if child is Control:
			child.mouse_filter = MOUSE_FILTER_IGNORE
	refresh()


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	_left = Constants.HUD_AWARENESS_INTERVAL
	refresh()


func refresh() -> void:
	var player = GlobalRefs.player_agent_body
	var live: bool = is_instance_valid(player) and player.is_inside_tree() and player.get("hull_max") != null
	visible = live and not player.get("is_docked") and not suppressed
	if not visible:
		return
	_refresh_target(player)
	_set_text(_speed, "%d M/S" % int(round(player.linear_velocity.length())))
	var seen: Array = ships_seen(player, get_tree().get_nodes_in_group("agent_body"))
	_set_text(_ships, "SHIPS %d" % seen[0])
	_hostiles.visible = seen[1] > 0
	_set_text(_hostiles, "HOSTILE %d" % seen[1])
	_hostiles.add_color_override("font_color", TargetKinds.graded(Constants.COLOR_UI_TARGET_HOSTILE))
	var loudness: float = signature_loudness(player)
	_set_text(_signature, "SIG " + signature_word(player))
	_signature.modulate.a = lerp(Constants.HUD_SIGNATURE_ALPHA[0], Constants.HUD_SIGNATURE_ALPHA[1], loudness)
	_hull.set_value(player.get_hull_fraction())
	_energy.set_value(player.power / max(player.power_max, 0.001))
	_cargo.set_value(float(player.get_cargo_units()) / max(float(player.cargo_capacity), 1.0) if player.has_method("get_cargo_units") else 0.0)
	_refresh_radio()


func _refresh_target(player) -> void:
	var has_target: bool = is_instance_valid(target) and target is Spatial and target.is_inside_tree()
	_target_row.modulate.a = 1.0 if has_target else 0.0
	if not has_target:
		return
	var color: Color = TargetKinds.color_of(target, player)
	if TargetKinds.kind_of(target) in ["rock", "body"]:
		color = TargetKinds.graded(Constants.COLOR_UI_TARGET_SELECTED)
	_set_text(_target_name, target_name.to_upper())
	_set_text(_target_distance, distance_text(player.global_transform.origin.distance_to(target.global_transform.origin)))
	for label in [_target_name, _target_distance]:
		label.add_color_override("font_color", color)
	var has_hull: bool = target.has_method("get_hull_fraction") and not target.get("is_wreck")
	_target_hull.visible = has_hull
	if has_hull:
		_target_hull.color = color
		_target_hull.set_value(target.get_hull_fraction())


func _refresh_radio() -> void:
	var shown: Array = radio_lines.slice(max(0, radio_lines.size() - Constants.HUD_RADIO_LINES), radio_lines.size() - 1) if not radio_lines.empty() else []
	_set_text(_radio, PoolStringArray(shown).join("\n"))


# [ships the player's sensors see, of them hostile to it]: live and undocked, itself left out.
static func ships_seen(player, bodies: Array) -> Array:
	var seen := 0
	var hostile := 0
	for body in bodies:
		if body == player or not is_instance_valid(body) or not body.has_method("is_enemy_of"):
			continue
		if body.get("is_wreck") or body.get("is_docked") or not body.is_inside_tree() or not player.detects(body):
			continue
		seen += 1
		if body.is_enemy_of(player):
			hostile += 1
	return [seen, hostile]


# 0 (the hull's quiet base) to 1 (SIG_LEVEL_BLAZING times it).
static func signature_loudness(player) -> float:
	var base: float = float(player.fit_stats.get("signature", 1500.0)) if player.get("fit_stats") else 1500.0
	return clamp((player.get_signature() / max(base, 1.0) - 1.0) / (Constants.SIG_LEVEL_BLAZING - 1.0), 0.0, 1.0)


static func signature_word(player) -> String:
	var base: float = float(player.fit_stats.get("signature", 1500.0)) if player.get("fit_stats") else 1500.0
	var ratio: float = player.get_signature() / max(base, 1.0)
	if ratio > Constants.SIG_LEVEL_BLAZING:
		return "BLAZING"
	if ratio > Constants.SIG_LEVEL_LOUD:
		return "LOUD"
	if ratio > Constants.SIG_LEVEL_ACTIVE:
		return "ACTIVE"
	return "QUIET"


static func distance_text(metres: float) -> String:
	return Bracket.format_distance(metres)  # As the bracket writes it


# Setting a Label's text lays it out again: only on a change.
static func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


static func _all_children(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		found.append(child)
		found += _all_children(child)
	return found
