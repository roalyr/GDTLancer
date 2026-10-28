# ProjectedTargetBracket: on-screen bracket for a world or jump-route target, with label, distance and selection.
# Visual only: it never takes the mouse. PointerRouter hit-tests brackets and emits "pressed".

extends Button

const BRACKET_TEXTURE_RECT_SIZE = Vector2(150, 150)
const BRACKET_CROSS_SCALE = 2.0  # The unselected cross, drawn this many times its texture's size
const BRACKET_HOSTILE_CROSS_SCALE = 4.0  # A live hostile's: twice everyone else's
const DISTANCE_KILOUNIT_SCALE = 1000.0
const DISTANCE_PLAIN_THRESHOLD = 2000.0
const DISTANCE_DECIMAL_K_THRESHOLD = 10000.0
const DISTANCE_SINGLE_DECIMAL_K_THRESHOLD = 100000.0
const DISTANCE_FAR_THRESHOLD = 1000000.0

var target_ref = null
var _is_selected: bool = false
var _normal_bracket: TextureRect = null
var _selected_bracket: TextureRect = null
var _distance_panel: Control = null
var _distance_label: Label = null
var _label_synced := false  # What the label shows now (_sync_label): text, and colour if any
var _shown_text := ""
var _shown_color = null
var _info_panel: Control = null
var _info_label: Label = null
var _target_label: String = ""
var _context_hint: String = ""
var _distance_fade_alpha: float = 1.0


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect_min_size = BRACKET_TEXTURE_RECT_SIZE
	_cache_scene_nodes()
	_apply_bracket_style()
	_apply_distance_fade_alpha()
	_sync_label()
	_sync_distance_label()
	set_process(true)


func _process(_delta: float) -> void:
	if _is_selected:
		_sync_distance_label()
		_apply_selected_color()  # A hostile can become a wreck while selected


func configure_target(new_target_ref, new_target_label: String = "") -> void:
	target_ref = new_target_ref
	_target_label = new_target_label
	_apply_bracket_style()
	_sync_label()
	_sync_distance_label()
	_refresh_distance_process_state()


func set_selected_state(is_selected: bool) -> void:
	if _is_selected == is_selected:
		return
	_is_selected = is_selected
	_apply_bracket_style()
	_sync_label()
	_sync_distance_label()
	_refresh_distance_process_state()


func set_context_hint(new_context_hint: String = "") -> void:
	if _context_hint == new_context_hint:
		return
	_context_hint = new_context_hint
	_sync_label()


func set_distance_fade_alpha(distance_fade_alpha: float) -> void:
	var safe_alpha = clamp(distance_fade_alpha, 0.0, 1.0)
	if is_equal_approx(_distance_fade_alpha, safe_alpha):
		return
	_distance_fade_alpha = safe_alpha
	_apply_distance_fade_alpha()


func _cache_scene_nodes() -> void:
	_normal_bracket = get_node_or_null("BracketNormal")
	_selected_bracket = get_node_or_null("BracketSelected")
	_distance_panel = get_node_or_null("BracketSelected/DistancePanel")
	_distance_label = get_node_or_null("BracketSelected/DistancePanel/DistanceLabel")
	_info_panel = get_node_or_null("InfoPanel")
	_info_label = get_node_or_null("InfoPanel/InfoLabel")

	if is_instance_valid(_normal_bracket):
		_normal_bracket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_normal_bracket.focus_mode = Control.FOCUS_NONE

	if is_instance_valid(_selected_bracket):
		_selected_bracket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_selected_bracket.focus_mode = Control.FOCUS_NONE

	if is_instance_valid(_distance_panel):
		_distance_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_distance_panel.focus_mode = Control.FOCUS_NONE

	if is_instance_valid(_distance_label):
		_distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_distance_label.focus_mode = Control.FOCUS_NONE

	if is_instance_valid(_info_panel):
		_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_info_panel.focus_mode = Control.FOCUS_NONE

	if is_instance_valid(_info_label):
		_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_info_label.focus_mode = Control.FOCUS_NONE


func _apply_bracket_style() -> void:
	if is_instance_valid(_normal_bracket):
		_normal_bracket.visible = not _is_selected
		if _is_route_target(target_ref) or _is_jump_point_target(target_ref):
			_normal_bracket.modulate = _get_jump_route_color()
		elif _is_live_ship():
			_normal_bracket.modulate = _awareness_shade(_get_ship_color())
		else:
			_normal_bracket.modulate = _get_ship_color()
			if _is_celestial():
				_normal_bracket.modulate.a *= Constants.UI_CELESTIAL_ALPHA
		_normal_bracket.rect_pivot_offset = BRACKET_TEXTURE_RECT_SIZE * 0.5
		var hostile: bool = _is_live_ship() and _is_hostile_to_player()
		_normal_bracket.rect_scale = Vector2.ONE * (BRACKET_HOSTILE_CROSS_SCALE if hostile else BRACKET_CROSS_SCALE)
	if is_instance_valid(_selected_bracket):
		_selected_bracket.visible = _is_selected
		_apply_selected_color()


# Red while the selected target is a live ship hostile to the player (dim while it has not detected
# the player), yellow otherwise (wrecks included).
func _apply_selected_color() -> void:
	if not is_instance_valid(_selected_bracket):
		return
	_selected_bracket.modulate = _awareness_shade(Constants.COLOR_UI_TARGET_HOSTILE) if _is_hostile_to_player() else Constants.COLOR_UI_TARGET_SELECTED


func refresh_style() -> void:
	_apply_bracket_style()
	if _is_live_ship() or is_instance_valid(target_ref) and target_ref.get("is_wreck"):
		_sync_label()  # Label colour follows the bracket's


# Unselected: red-orange for a live ship hostile to the player, its faction's colour otherwise, grey
# for wrecks. The cross dims it while the ship has not detected the player (_awareness_shade); the
# label does not.
func _get_ship_color() -> Color:
	if not (is_instance_valid(target_ref) and target_ref.has_method("get_faction_color")):
		return Constants.COLOR_UI_TARGET_NEUTRAL
	if target_ref.get("is_wreck"):
		return Constants.COLOR_UI_WRECK
	return Constants.COLOR_UI_TARGET_HOSTILE if _is_hostile_to_player() else target_ref.get_faction_color()


# A rock, a planet or the like: no side, not a station, a wreck or a route.
func _is_celestial() -> bool:
	return is_instance_valid(target_ref) and not target_ref.has_method("get_faction_color") and not target_ref.get("is_wreck") \
			and not _is_dockable_target(target_ref) and not _is_route_target(target_ref) and not _is_jump_point_target(target_ref)


# `color` as it is if the ship detects the player, dimmed (Constants UI_UNAWARE_*) if not.
func _awareness_shade(color: Color) -> Color:
	var player = GlobalRefs.player_agent_body
	if not target_ref.has_method("detects") or not is_instance_valid(player) or target_ref.detects(player):
		return color
	return Color(color.r * Constants.UI_UNAWARE_DIM, color.g * Constants.UI_UNAWARE_DIM, color.b * Constants.UI_UNAWARE_DIM, color.a * Constants.UI_UNAWARE_ALPHA)


func _is_live_ship() -> bool:
	return is_instance_valid(target_ref) and target_ref.has_method("get_faction_color") and not target_ref.get("is_wreck")


func _is_hostile_to_player() -> bool:
	var player = GlobalRefs.player_agent_body
	return is_instance_valid(target_ref) and target_ref.has_method("is_enemy_of") and not target_ref.get("is_wreck") and target_ref.is_enemy_of(player)


func _apply_distance_fade_alpha() -> void:
	modulate = Color(1, 1, 1, _distance_fade_alpha)


# Changes the label only when its text or colour changes: setting a Label's text lays it out again,
# and brackets are restyled every frame.
func _sync_label() -> void:
	if not is_instance_valid(_info_label):
		return
	var label_text: String = _build_label_text()
	var color = null  # Color, or null for the theme's
	if _is_route_target(target_ref) or _is_jump_point_target(target_ref):
		color = _get_jump_route_color()
	elif _is_live_ship():
		color = _get_ship_color()  # Sides read at a glance
	if _label_synced and label_text == _shown_text and typeof(color) == typeof(_shown_color) and (typeof(color) == TYPE_NIL or color == _shown_color):
		return
	_label_synced = true
	_shown_text = label_text
	_shown_color = color
	_info_label.text = label_text
	if color is Color:
		_info_label.add_color_override("font_color", color)
	else:
		_info_label.remove_color_override("font_color")
	if is_instance_valid(_info_panel):
		_info_panel.visible = label_text != ""


func _sync_distance_label() -> void:
	if not is_instance_valid(_distance_label):
		return
	_distance_label.text = _build_distance_label_text()


func _build_distance_label_text() -> String:
	if not _is_selected:
		return ""
	if _is_route_target(target_ref):
		return "FAR"
	if not (is_instance_valid(target_ref) and target_ref is Spatial):
		return ""
	if target_ref.is_in_group("jump_point"):
		return "FAR"
	if not target_ref.is_inside_tree():
		return ""
	var player_agent = GlobalRefs.player_agent_body
	if not (is_instance_valid(player_agent) and player_agent is Spatial):
		return ""
	var distance_units = player_agent.global_transform.origin.distance_to(target_ref.global_transform.origin)
	return _format_distance_label(distance_units)


func _format_distance_label(distance_units: float) -> String:
	var safe_distance_units = max(0.0, distance_units)
	if safe_distance_units >= DISTANCE_FAR_THRESHOLD:
		return "FAR"
	if safe_distance_units < DISTANCE_PLAIN_THRESHOLD:
		return str(int(round(safe_distance_units)))

	var distance_kilounits = safe_distance_units / DISTANCE_KILOUNIT_SCALE
	if safe_distance_units < DISTANCE_DECIMAL_K_THRESHOLD:
		return "%sk" % _trim_trailing_decimal_zeros("%.2f" % distance_kilounits)
	if safe_distance_units < DISTANCE_SINGLE_DECIMAL_K_THRESHOLD:
		return "%sk" % _trim_trailing_decimal_zeros("%.1f" % distance_kilounits)
	return "%dk" % int(floor(distance_kilounits))


func _trim_trailing_decimal_zeros(value_text: String) -> String:
	var trimmed_text = value_text
	while trimmed_text.find(".") != -1 and trimmed_text.ends_with("0"):
		trimmed_text = trimmed_text.substr(0, trimmed_text.length() - 1)
	if trimmed_text.ends_with("."):
		trimmed_text = trimmed_text.substr(0, trimmed_text.length() - 1)
	return trimmed_text


func _refresh_distance_process_state() -> void:
	pass


func _build_label_text() -> String:
	# Only the selected target is labelled: the rest show the bare bracket (colour says whose), which
	# keeps a crowded battlefield readable and spares a label's draw calls per bracket.
	if not _is_selected:
		return ""
	var primary_text = _resolve_primary_label()
	var secondary_text = _resolve_secondary_label()
	if primary_text == "":
		return secondary_text
	if secondary_text == "":
		return primary_text
	return "%s\n%s" % [primary_text, secondary_text]


func _resolve_primary_label() -> String:
	if _target_label != "":
		return _target_label
	if not is_instance_valid(target_ref):
		return ""
	if target_ref.get("display_name") != null and str(target_ref.get("display_name")) != "":
		return str(target_ref.get("display_name"))
	if target_ref.get("station_name") != null and str(target_ref.get("station_name")) != "":
		return str(target_ref.get("station_name"))
	if target_ref.get("agent_name") != null and str(target_ref.get("agent_name")) != "":
		return str(target_ref.get("agent_name"))
	if target_ref.get("name") != null and str(target_ref.get("name")) != "":
		return str(target_ref.get("name")).replace("_", " ")
	if target_ref.get("target_sector_id") != null and str(target_ref.get("target_sector_id")) != "":
		return str(target_ref.get("target_sector_id"))
	return ""


func _resolve_secondary_label() -> String:
	if _context_hint != "":
		return _context_hint
	return ""  # Essentials only: the rest is in the debug overlay


func _is_route_target(target_candidate) -> bool:
	return is_instance_valid(target_candidate) and target_candidate.get("target_kind") == "jump_route"


func _is_dockable_target(target_candidate) -> bool:
	return is_instance_valid(target_candidate) and target_candidate is Node and target_candidate.is_in_group("dockable_station")


func _is_jump_point_target(target_candidate) -> bool:
	return is_instance_valid(target_candidate) and target_candidate is Node and target_candidate.is_in_group("jump_point")


func _get_jump_route_color() -> Color:
	var sector_type = ""
	if is_instance_valid(target_ref):
		var dest_id = ""
		if target_ref.get("target_sector_id") != null:
			dest_id = str(target_ref.get("target_sector_id"))
		elif "target_sector_id" in target_ref:
			dest_id = str(target_ref.target_sector_id)
			
		if dest_id != "":
			sector_type = TemplateDatabase.get_sector_type(dest_id, "")
	return Constants.get_jump_type_color(sector_type)
