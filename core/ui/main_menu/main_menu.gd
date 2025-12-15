extends Control

onready var btn_new_game = $ScreenControls/MainButtonsHBoxContainer/ButtonStartNewGame
onready var btn_load_game = $ScreenControls/MainButtonsHBoxContainer/ButtonLoadGame
onready var btn_save_game = $ScreenControls/MainButtonsHBoxContainer/ButtonSaveGame
onready var btn_exit_game = $ScreenControls/MainButtonsHBoxContainer/ButtonExitgame


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS

	if is_instance_valid(btn_new_game) and not btn_new_game.is_connected("pressed", self, "_on_new_game_pressed"):
		btn_new_game.connect("pressed", self, "_on_new_game_pressed")
	if is_instance_valid(btn_load_game) and not btn_load_game.is_connected("pressed", self, "_on_load_game_pressed"):
		btn_load_game.connect("pressed", self, "_on_load_game_pressed")
	if is_instance_valid(btn_save_game) and not btn_save_game.is_connected("pressed", self, "_on_save_game_pressed"):
		btn_save_game.connect("pressed", self, "_on_save_game_pressed")
	if is_instance_valid(btn_exit_game) and not btn_exit_game.is_connected("pressed", self, "_on_exit_game_pressed"):
		btn_exit_game.connect("pressed", self, "_on_exit_game_pressed")

	if is_instance_valid(EventBus) and EventBus.has_signal("main_menu_requested"):
		if not EventBus.is_connected("main_menu_requested", self, "_show_menu"):
			EventBus.connect("main_menu_requested", self, "_show_menu")

	_update_load_button_state()
	# If nothing else requests it, show menu on boot.
	call_deferred("_show_menu")


func _on_new_game_pressed() -> void:
	visible = false
	if is_instance_valid(EventBus) and EventBus.has_signal("new_game_requested"):
		EventBus.emit_signal("new_game_requested")
	else:
		printerr("MainMenu: EventBus missing signal 'new_game_requested'.")


func _on_load_game_pressed() -> void:
	if not is_instance_valid(GameStateManager):
		printerr("MainMenu: GameStateManager unavailable.")
		return

	if GameStateManager.has_method("has_save_file") and GameStateManager.has_save_file():
		var ok: bool = GameStateManager.load_game(0)
		if ok:
			visible = false
		else:
			_show_menu()
	else:
		_update_load_button_state()


func _on_save_game_pressed() -> void:
	if not is_instance_valid(GameStateManager):
		printerr("MainMenu: GameStateManager unavailable.")
		return
	GameStateManager.save_game(0)
	_update_load_button_state()


func _on_exit_game_pressed() -> void:
	get_tree().quit()


func _update_load_button_state() -> void:
	if not is_instance_valid(btn_load_game):
		return
	if is_instance_valid(GameStateManager) and GameStateManager.has_method("has_save_file"):
		btn_load_game.disabled = not GameStateManager.has_save_file()
	else:
		btn_load_game.disabled = true


func _show_menu() -> void:
	visible = true
	get_tree().paused = true
	_update_load_button_state()

