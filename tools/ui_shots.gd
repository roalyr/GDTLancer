# UI shots: starts a new game (docked at home: the fitting window), screenshots each store tab and
# a prompt, for before/after checks of UI changes. Runs the project's autoloads, so as a scene:
#     godot res://tools/ui_shots.tscn out=/abs/dir
# Writes fitting_<tab>.png, fitting_ships_preview.png, announcement.png, prompt.png and notice.png there, and beside each a .txt of every control shown
# (type, rect, colours, styles; no text: prices vary), then quits. Nothing is saved.
extends Node

const PromptDialog = preload("res://src/core/ui/helpers/prompt_dialog.gd")

var out: String = "user://ui_shots"


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("out="):
			out = a.trim_prefix("out=")
	Directory.new().make_dir_recursive(out)
	add_child(load(ProjectSettings.get_setting("application/run/main_scene")).instance())
	yield(_wait(2.0), "completed")
	var menu: Node = _find(get_tree().root, "_on_new_game_pressed")
	menu._on_new_game_pressed()
	yield(_wait(6.0), "completed")
	get_viewport().disable_3d = true  # Only the UI: the world behind it moves from run to run
	var fitting: Node = _find(get_tree().root, "_rebuild_store")
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
	get_tree().quit()


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


# Every visible control as it lays out: class, global rect, modulate, colour overrides, panel style.
func _dump(node: Node, lines: Array) -> void:
	if node is CanvasItem and not node.visible:
		return
	if node is Control:
		var line: String = "%s %s %s m%s sm%s" % [node.get_class(), node.get_global_rect().position.round(), node.rect_size.round(), node.modulate, node.self_modulate]
		for key in ["font_color", "font_color_hover", "font_color_pressed"]:
			if node.has_color_override(key):
				line += " %s=%s" % [key, node.get_color(key)]
		if node is PanelContainer:
			var style = node.get_stylebox("panel")
			line += " panel=%s" % (style.bg_color if style is StyleBoxFlat else style.get_class())
		if node is Label or node is Button:
			line += " align=%s" % node.align
		lines.append(line)
	for child in node.get_children():
		_dump(child, lines)
