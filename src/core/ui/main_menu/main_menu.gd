# MainMenu: new game, save, load and exit; it asks nothing at start. Load reads the game's own save
# only (GameStateManager mode "play": never evolution's); exiting a game in progress (the button or
# closing the window) asks whether to save first; a new game starts a fresh world, its havens flying
# the presets.

extends Control

onready var btn_new_game = $ScreenControls/MainButtonsHBoxContainer/ButtonStartNewGame
onready var btn_load_game = $ScreenControls/MainButtonsHBoxContainer/ButtonLoadGame
onready var btn_save_game = $ScreenControls/MainButtonsHBoxContainer/ButtonSaveGame
onready var btn_exit_game = $ScreenControls/MainButtonsHBoxContainer/ButtonExitgame
onready var btn_close = $ScreenControls/ButtonClose

const PromptDialog = preload("res://src/core/ui/helpers/prompt_dialog.gd")



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
	if is_instance_valid(btn_close) and not btn_close.is_connected("pressed", self, "_on_close_pressed"):
		btn_close.connect("pressed", self, "_on_close_pressed")

	if is_instance_valid(EventBus) and EventBus.has_signal("main_menu_requested"):
		if not EventBus.is_connected("main_menu_requested", self, "_show_menu"):
			EventBus.connect("main_menu_requested", self, "_show_menu")

	_update_load_button_state()
	_refresh_close_button_state()
	get_tree().set_auto_accept_quit(false)  # Closing the window asks first (_notification)
	# If nothing else requests it, show menu on boot.
	call_deferred("_show_menu")


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		_request_exit()


# --- Prompts ---

func _request_exit() -> void:
	if not _has_active_game_session():
		get_tree().quit()
		return
	_show_menu()
	var prompt = PromptDialog.ask(self, "Save before exiting?", "UNSAVED PLAY IS LOST ON EXIT.", [["save", "SAVE AND EXIT"], ["exit", "EXIT"], ["cancel", "CANCEL"]])
	prompt.connect("chosen", self, "_on_exit_chosen")


func _on_exit_chosen(choice) -> void:
	match choice:
		"save":
			if GameStateManager.save_game(0):
				get_tree().quit()
			else:
				_show_save_notification(false)
		"exit":
			get_tree().quit()


func _on_new_game_pressed() -> void:
	_start_new_game()


func _start_new_game() -> void:
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
	var success: bool = GameStateManager.save_game(0)
	_update_load_button_state()
	_show_save_notification(success)


func _show_save_notification(success: bool) -> void:
	if success:
		PromptDialog.tell(self, "Saved", "THE GAME IS SAVED.")
	else:
		PromptDialog.tell(self, "Save failed", "THE GAME COULD NOT BE SAVED. THE CONSOLE SAYS WHY.")


func _on_exit_game_pressed() -> void:
	_request_exit()


func _on_close_pressed() -> void:
	if not _has_active_game_session():
		return
	visible = false
	get_tree().paused = false


func _update_load_button_state() -> void:
	if not is_instance_valid(btn_load_game):
		return
	if is_instance_valid(GameStateManager) and GameStateManager.has_method("has_save_file"):
		btn_load_game.disabled = not GameStateManager.has_save_file()
	else:
		btn_load_game.disabled = true


func _refresh_close_button_state() -> void:
	if not is_instance_valid(btn_close):
		return
	btn_close.disabled = not _has_active_game_session()


func _has_active_game_session() -> bool:
	return GameState.current_sector_id != "" or is_instance_valid(GameState.current_zone_instance)


func _show_menu() -> void:
	visible = true
	get_tree().paused = true
	_update_load_button_state()
	_refresh_close_button_state()
