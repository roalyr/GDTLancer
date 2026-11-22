# UI shots: starts a new game (docked at home: the fitting window), screenshots each store tab and
# a prompt, for before/after checks of UI changes. Runs the project's autoloads, so as a scene:
#     godot res://tools/ui_shots.tscn out=/abs/dir [ui_scale=1.5]
# ui_scale: UiScale's factor for the run (the player's own option otherwise; nothing is saved).
# Writes main_menu.png, hud_scale_<x>.png (each UI scale, "UI OVERLAP" lines for HUD controls that overlap), interaction_window.png, fitting_view.png (the FITTING view), fitting_<tab>.png (MARKET), fitting_ships_preview.png, announcement.png, prompt.png, notice.png, then undocked ship_window.png, pilot_window.png, map_sector.png, map_global.png, hud_<look>.png, hud_hidden.png and options_window.png there, and beside each a .txt of every control shown
# (type, rect, colours, styles; no text: prices vary), then quits. Nothing is saved.
extends Node

const PromptDialog = preload("res://src/core/ui/helpers/prompt_dialog.gd")

var out: String = "user://ui_shots"
var ui_scale: float = -1.0


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("out="):
			out = a.trim_prefix("out=")
		if a.begins_with("ui_scale="):
			ui_scale = float(a.trim_prefix("ui_scale="))
	Directory.new().make_dir_recursive(out)
	GameStateManager.save_dir = "user://ui_shots_saves/"  # A respawn saves: never into the player's saves
	add_child(load(ProjectSettings.get_setting("application/run/main_scene")).instance())
	if ui_scale > 0.0:
		UiScale.set_factor(ui_scale)  # After the main scene read the player's options
	yield(_wait(2.0), "completed")
	_shot("main_menu")
	var menu: Node = _find(get_tree().root, "_on_new_game_pressed")
	menu._on_new_game_pressed()
	yield(_wait(6.0), "completed")
	get_viewport().disable_3d = true  # Only the UI: the world behind it moves from run to run
	var fitting: Node = _find(get_tree().root, "_rebuild_store")
	fitting.show_view(fitting.FITTING)
	yield(_wait(1.0), "completed")
	_shot("fitting_view")
	fitting.show_view(fitting.MARKET)
	for tab in fitting.STORE_TABS:
		fitting._on_tab(tab)
		yield(_wait(0.5), "completed")
		_shot("fitting_%s" % tab)
	fitting._on_tab("ships")
	var ids: Array = fitting._ship_rows.keys()
	ids.sort()
	for ship_id in ids.slice(0, 6):  # Tapping from row to row: only the last stays marked
		fitting.preview_ship(ship_id)
	for ship_id in ids:
		if ship_id.begins_with("preset_ship_archetype_raider_heavy"):
			fitting.preview_ship(ship_id)
	var marked: int = 0
	var looks := {}
	for ship_id in ids:
		var row = fitting._ship_rows[ship_id]
		var style = row.get_stylebox("panel")
		var key: String = "%s a%.2f" % [style.bg_color if style is StyleBoxFlat else style.get_class(), row.self_modulate.a]
		looks[key] = looks.get(key, 0) + 1
		marked += 1 if row.has_meta("look") else 0
	print("UI SHOT marked rows: %d, looks: %s" % [marked, looks])
	yield(_wait(1.0), "completed")
	_shot("fitting_ships_preview")
	EventBus.emit_signal("announcement", "UI shots: an announcement", "warning")
	yield(_wait(0.2), "completed")
	_shot("announcement")
	PromptDialog.ask(fitting.get_parent(), "Save before exiting?", "UNSAVED PLAY IS LOST ON EXIT.", [["save", "SAVE AND EXIT"], ["exit", "EXIT"], ["cancel", "CANCEL"]])
	yield(_wait(0.5), "completed")
	_shot("prompt")
	get_tree().call_group("prompt_dialog", "queue_free")
	for child in fitting.get_parent().get_children():
		if child.name.begins_with("PromptDialog"):
			child.queue_free()
	PromptDialog.tell(fitting.get_parent(), "Saved", "THE GAME IS SAVED.")
	yield(_wait(0.5), "completed")
	_shot("notice")
	for child in fitting.get_parent().get_children():
		if child.get_script() == PromptDialog:
			child.queue_free()
	EventBus.emit_signal("player_undocked")
	yield(_wait(1.0), "completed")
	var hud: Node = fitting.get_parent()
	for window in [hud.ship_window, hud.pilot_window]:
		window.open()
		yield(_wait(0.5), "completed")
		_shot(window.filename.get_file().get_basename())
		window.close()
	hud.map_window.open()
	yield(_wait(0.5), "completed")
	_shot("map_sector")
	hud.map_window.show_tab(hud.map_window.GLOBAL)
	yield(_wait(0.5), "completed")
	_shot("map_global")
	hud.map_window.show_tab(hud.map_window.SECTOR)
	hud.map_window.close()
	get_viewport().disable_3d = false  # The HUD's looks are judged over the world
	for look in Constants.HUD_PRESET_ORDER:
		Settings.set_option("hud_preset", look)
		hud.apply_hud_preset()
		yield(_wait(0.5), "completed")
		_shot("hud_%s" % look)
	Settings.set_option("hud_preset", "standard")
	hud.apply_hud_preset()
	hud.toggle_hud()  # The eye button: the HUD gone, a dot left
	yield(_wait(0.5), "completed")
	_shot("hud_hidden")
	hud.toggle_hud()
	yield(_hud_scales(hud), "completed")
	get_viewport().disable_3d = true
	var options = menu.get("options_window")
	if options != null:
		menu._show_menu()  # The options window is the menu's: shown over it, as in play
		options.open()
		yield(_wait(0.5), "completed")
		_shot("options_window")
		options.close()
	get_tree().quit()


# The HUD at every UI scale, a ship targeted (its row is the widest): hud_scale_<x>.png, and an
# "UI OVERLAP" line for each pair of HUD controls that overlap (buttons, the top strip's columns
# and rows), or that reach past the screen. The UI scale goes back as it was.
func _hud_scales(hud: Node) -> void:
	var was: float = UiScale.factor
	var player = GlobalRefs.player_agent_body
	var nearest = null
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body != player and is_instance_valid(player) and (nearest == null or body.global_transform.origin.distance_to(player.global_transform.origin) < nearest.global_transform.origin.distance_to(player.global_transform.origin)):
			nearest = body
	if nearest != null:
		EventBus.emit_signal("player_target_selected", nearest)
	var steps: Array = Constants.UI_SCALE_STEPS.duplicate()
	steps.sort()
	for step in steps:
		UiScale.set_factor(step)
		yield(_wait(0.6), "completed")
		_shot("hud_scale_%s" % str(step))
		var found: Array = hud_overlaps(hud)
		for line in found:
			print("UI OVERLAP x%s: %s" % [str(step), line])
		print("UI SCALE x%s (HUD x%.2f): %d overlaps" % [str(step), UiScale.layout_factor, found.size()])
	UiScale.set_factor(was)
	yield(_wait(0.3), "completed")
	if nearest != null:  # The interaction window, on the ship targeted
		hud.interaction_window.open(nearest)
		yield(_wait(0.5), "completed")
		_shot("interaction_window")
		hud.interaction_window.close()


# Pairs of shown HUD controls that overlap by more than a pixel each way, controls past the
# screen's edge, and words wider than their button or than the top strip's middle:
# ["A <-> B", "C past the screen", "D's words overflow"...].
static func hud_overlaps(hud: Node) -> Array:
	var items: Array = []
	_hud_items(hud.get_node("ScreenControls"), items)
	var screen: Rect2 = hud.get_viewport_rect()
	var found: Array = []
	for i in range(items.size()):
		var a: Control = items[i]
		var rect_a: Rect2 = _drawn_rect(a)
		if not screen.grow(1.0).encloses(rect_a):
			found.append("%s past the screen" % a.name)
		for label in a.get_children():
			if label is Label and label.visible and label.text != "" and label.get_combined_minimum_size().x > rect_a.size.x + 1.0:
				found.append("%s's words overflow" % a.name)
		if a.get_parent().name == "Layout" and a.get_combined_minimum_size().x > a.get_parent().get_parent().rect_size.x + 1.0:
			found.append("%s overflows the top strip" % a.name)
		for j in range(i + 1, items.size()):
			var b: Control = items[j]
			if a.is_a_parent_of(b) or b.is_a_parent_of(a):
				continue
			var both: Rect2 = rect_a.clip(_drawn_rect(b))
			if both.size.x > 1.0 and both.size.y > 1.0:
				found.append("%s <-> %s" % [a.name, b.name])
	return found


# Where a control is drawn on screen, turned as it is (the thrust slider is upside down).
static func _drawn_rect(control: Control) -> Rect2:
	var xform: Transform2D = control.get_global_transform()
	var rect := Rect2(xform.xform(Vector2.ZERO), Vector2.ZERO)
	for corner in [Vector2(control.rect_size.x, 0), control.rect_size, Vector2(0, control.rect_size.y)]:
		rect = rect.expand(xform.xform(corner))
	return rect


# The HUD's controls checked for overlaps: shown buttons and sliders, and the top strip's rows (as
# wide as its column: wider when they overflow it, which spreads it both ways).
static func _hud_items(node: Node, items: Array) -> void:
	if node is CanvasItem and not node.visible:
		return
	if (node is BaseButton and not node.get_parent() is BaseButton) or node is Slider:
		items.append(node)
	if node.get_parent() != null and node.get_parent().name == "Layout" and node.get_parent().get_parent().name == "AwarenessZone":
		items.append(node)
	for child in node.get_children():
		_hud_items(child, items)


func _wait(seconds: float) -> void:
	yield(get_tree().create_timer(seconds), "timeout")


func _shot(name: String) -> void:
	var image: Image = get_viewport().get_texture().get_data()
	image.flip_y()
	image.save_png(out.plus_file(name + ".png"))
	var lines: Array = []
	_dump(get_tree().root, lines)
	var file := File.new()
	file.open(out.plus_file(name + ".txt"), File.WRITE)
	file.store_string(PoolStringArray(lines).join("\n"))
	file.close()
	print("UI SHOT ", out.plus_file(name + ".png"))


func _find(node: Node, method: String) -> Node:
	if node.has_method(method) and node != self:
		return node
	for child in node.get_children():
		var found = _find(child, method)
		if found != null:
			return found
	return null


# Every visible control as it lays out: class, global rect, modulate, colours and font size where
# overridden or set by a theme variation (main_theme's named looks), panel style.
func _dump(node: Node, lines: Array) -> void:
	if node is CanvasItem and not node.visible:
		return
	if node is Control:
		var line: String = "%s %s %s m%s sm%s" % [node.get_class(), node.get_global_rect().position.round(), node.rect_size.round(), node.modulate, node.self_modulate]
		var styled: bool = node.theme_type_variation != ""
		for key in ["font_color", "font_color_hover", "font_color_pressed"]:
			if node.has_color_override(key) or (styled and node.has_color(key)):
				line += " %s=%s" % [key, node.get_color(key)]
		if node.has_font_override("font") or styled:
			var font = node.get_font("font")
			if font is DynamicFont:
				line += " font=%d" % font.size
		if node is PanelContainer or node is Panel:
			var style = node.get_stylebox("panel")
			line += " panel=%s" % (style.bg_color if style is StyleBoxFlat else style.get_class())
		if node is Label or node is Button:
			line += " align=%s" % node.align
		lines.append(line)
	for child in node.get_children():
		_dump(child, lines)
