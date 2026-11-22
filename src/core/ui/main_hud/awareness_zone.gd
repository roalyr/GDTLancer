# AwarenessZone (scenes/ui/hud/awareness_zone.tscn): the strip along the top of the HUD, between
# the top corner buttons, with what a pilot glances at, read as colours and lengths more than words:
# - the target (large), its name kept up to date (a rock chunk bared becomes an ore chunk), or a
#   jump route's destination ("JUMP TO VIDR"): a ship's faction tag before its name ("[VERDANT] ..."), distance, how a
#   fight with it would go (EASY .. DEADLY) with its pilot's level (ROOKIE .. ACE, PilotLevel) and
#   its hull, in its mark's colour (TargetKinds); the bracket then keeps only its distance;
# - own speed, ships the sensors see as pips (HudPips; the hostile ones filled, red), own signature
#   as a bar (Agent.get_signature against the hull's quiet base), dim while quiet, bright as it grows;
# - bars: own hull, energy and cargo space used (fuel, then the rest of the hold);
# - the radio, dimmer than the rest: the last HUD_RADIO_LINES lines heard, each fading out
#   HUD_RADIO_FADE s after it came (MainHUD calls add_radio_line).
# Refreshed every Constants.HUD_AWARENESS_INTERVAL s (labels lay out again on every change). It
# takes no input and is in the group "hud_awareness_zone". MainHUD sets `target`.

extends Control

const TargetKinds = preload("res://src/core/ui/main_hud/target_kinds.gd")
const Bracket = preload("res://src/core/ui/main_hud/projected_target_bracket.gd")
const CombatAssessment = preload("res://src/core/systems/combat_assessment.gd")
const PilotLevel = preload("res://src/core/systems/pilot_level.gd")
const Fuel = preload("res://src/core/systems/fuel.gd")

var target = null  # The selected target (MainHUD): a node, or a jump route (RouteTarget)
var target_name: String = ""  # Its name when picked; name_source, if set, names it afresh each refresh
var name_source: FuncRef = null  # MainHUD._resolve_target_display_name: a chunk's name follows it bared
var radio_lines: Array = []  # [[line, age in s]], oldest first
var suppressed: bool = false  # Hidden while the debug overlay is up (MainHUD)

onready var _target_row: Control = $Layout/TargetRow
onready var _target_name: Label = $Layout/TargetRow/Name
onready var _target_distance: Label = $Layout/TargetRow/Distance
onready var _target_threat: Label = $Layout/TargetRow/Threat
onready var _target_hull: Control = $Layout/TargetRow/Hull
onready var _speed: Label = $Layout/StatusRow/Speed
onready var _ships: Control = $Layout/StatusRow/Ships
onready var _signature: Control = $Layout/StatusRow/Signature
onready var _hull: Control = $Layout/Bars/Hull
onready var _energy: Control = $Layout/Bars/Energy
onready var _cargo: Control = $Layout/Bars/Cargo
onready var _radio: Label = $Layout/Radio

var _left: float = 0.0
var _name_full: String = ""  # The target's name as it would read whole (_fit_target_name may cut it)


func _ready() -> void:
	add_to_group("hud_awareness_zone")
	mouse_filter = MOUSE_FILTER_IGNORE
	for child in _all_children(self):
		if child is Control:
			child.mouse_filter = MOUSE_FILTER_IGNORE
	_target_name.set_meta(UiScale.SKIP, true)  # Its width is _fit_target_name's, at the scale in place
	connect("resized", self, "_fit_target_name")
	refresh()


func _process(delta: float) -> void:
	for entry in radio_lines:
		entry[1] += delta
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
	_ships.set_counts(seen[0], seen[1], TargetKinds.graded(Constants.COLOR_UI_TARGET_HOSTILE))
	var loudness: float = signature_loudness(player)
	_signature.set_value(loudness)
	_signature.modulate.a = lerp(Constants.HUD_SIGNATURE_ALPHA[0], Constants.HUD_SIGNATURE_ALPHA[1], loudness)
	_hull.set_value(player.get_hull_fraction())
	_energy.set_value(player.power / max(player.power_max, 0.001))
	if player.has_method("get_cargo_units"):  # Fuel first (its own colour), then the rest of the hold
		var capacity: float = max(float(player.cargo_capacity), 1.0)
		var fuel: float = float(player.cargo.get(Constants.FUEL_COMMODITY, 0)) if player.get("cargo") is Dictionary else 0.0
		_cargo.set_lead(fuel / capacity)
		_cargo.set_value((float(player.get_cargo_units()) - fuel) / capacity)
	else:
		_cargo.set_lead(0.0)
		_cargo.set_value(0.0)
	_refresh_radio()


func _refresh_target(player) -> void:
	if is_route(target):  # A jump route: where it goes, and the fuel the jump burns of what is held
		_target_row.modulate.a = 1.0
		_name_full = route_text(target)
		_set_text(_target_distance, fuel_text(player))
		_set_text(_target_threat, "")
		for label in [_target_name, _target_distance, _target_threat]:
			label.add_color_override("font_color", TargetKinds.graded(Constants.COLOR_UI_TARGET_SELECTED))
		if is_instance_valid(player) and Fuel.carried(player) < Fuel.jump_cost(player):
			_target_distance.add_color_override("font_color", TargetKinds.graded(Constants.COLOR_UI_TARGET_HOSTILE))  # Short of it
		_target_hull.visible = false
		_fit_target_name()
		return
	var has_target: bool = is_instance_valid(target) and target is Spatial and target.is_inside_tree()
	_target_row.modulate.a = 1.0 if has_target else 0.0
	if not has_target:
		return
	var color: Color = TargetKinds.color_of(target, player)
	if TargetKinds.kind_of(target) in ["rock", "body"]:
		color = TargetKinds.graded(Constants.COLOR_UI_TARGET_SELECTED)
	if name_source != null and name_source.is_valid():
		target_name = str(name_source.call_func(target))
	_name_full = name_text(target, target_name)
	_set_text(_target_distance, distance_text(player.global_transform.origin.distance_to(target.global_transform.origin)))
	_set_text(_target_threat, threat_text(player, target))
	for label in [_target_name, _target_distance, _target_threat]:
		label.add_color_override("font_color", color)
	var has_hull: bool = target.has_method("get_hull_fraction") and not target.get("is_wreck")
	_target_hull.visible = has_hull
	if has_hull:
		_target_hull.color = color
		_target_hull.set_value(target.get_hull_fraction())
	_fit_target_name()


# The target's name as wide as it reads, but no wider than the middle leaves beside the rest of
# its row in the strip: a long name is cut short with "...", and the row stays centred between the
# corner buttons.
func _fit_target_name() -> void:
	if not is_instance_valid(_target_name):
		return
	var others: float = 0.0
	for node in _target_row.get_children():
		if node != _target_name and node.visible:
			others += node.get_combined_minimum_size().x + _target_row.get_constant("separation")
	var room: float = max(0.0, rect_size.x - others)
	var font: Font = _target_name.get_font("font")
	var text: String = _name_full
	var cut: int = text.length()
	while cut > 0 and font.get_string_size(text).x > room:
		cut -= 1
		text = _name_full.left(cut).strip_edges() + "..."
	_set_text(_target_name, text)
	var width: float = ceil(min(font.get_string_size(text).x, room))
	if not is_equal_approx(_target_name.rect_min_size.x, width):
		_target_name.rect_min_size.x = width


func add_radio_line(line: String) -> void:
	radio_lines.append([line, 0.0])
	while radio_lines.size() > Constants.HUD_RADIO_LINES:
		radio_lines.pop_front()
	_refresh_radio()


# The lines still on, and the radio as bright as its newest line (a line fades over the last
# quarter of HUD_RADIO_FADE).
func _refresh_radio() -> void:
	while not radio_lines.empty() and radio_lines[0][1] >= Constants.HUD_RADIO_FADE:
		radio_lines.pop_front()
	var shown: Array = []
	var newest_age: float = Constants.HUD_RADIO_FADE
	for entry in radio_lines:
		shown.append(entry[0])
		newest_age = min(newest_age, entry[1])
	_set_text(_radio, PoolStringArray(shown).join("\n"))
	var fade_from: float = Constants.HUD_RADIO_FADE * 0.75
	_radio.modulate.a = Constants.HUD_RADIO_ALPHA * clamp(1.0 - (newest_age - fade_from) / (Constants.HUD_RADIO_FADE - fade_from), 0.0, 1.0)


static func is_route(target_node) -> bool:
	return target_node is Reference and target_node.get("target_kind") == "jump_route"


# A jump route's line: "JUMP TO VIDR".
static func route_text(route) -> String:
	var name: String = str(route.display_name) if str(route.display_name) != "" else str(route.target_sector_id)
	return "JUMP TO " + name.to_upper()


# A jump's fuel, needed / held: "FUEL 5 / 12" (Fuel.jump_cost, Fuel.carried); "" without a ship.
static func fuel_text(player) -> String:
	if not is_instance_valid(player):
		return ""
	return "FUEL %d / %d" % [Fuel.jump_cost(player), Fuel.carried(player)]


# How a fight with a live ship would go (CombatAssessment), "" for anything else.
static func threat_word(player, target_node) -> String:
	if not (target_node.has_method("is_enemy_of") and not target_node.get("is_wreck") and player.has_method("get_damage_per_second")):
		return ""
	return CombatAssessment.difficulty_label(CombatAssessment.team_advantage(player, target_node))


# The threat word and, for a ship with a pilot level, the level: "HARD · VETERAN".
static func threat_text(player, target_node) -> String:
	var word: String = threat_word(player, target_node)
	var level: String = PilotLevel.name_of(PilotLevel.of(target_node)) if word != "" else ""
	return word + (" · " + level if level != "" else "")


# The target's name in capitals, a live ship's after its faction's tag: "[VERDANT] FIGHTER M".
static func name_text(target_node, name: String) -> String:
	var tag: String = ""
	if target_node.has_method("is_enemy_of") and not target_node.get("is_wreck"):
		tag = PilotLevel.faction_tag(target_node)
	return ((tag + " ") if tag != "" else "") + name.to_upper()


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
