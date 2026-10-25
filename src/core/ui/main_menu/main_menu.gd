# MainMenu: new game, save, load and exit. At start it offers to load the saved game (with a summary
# of it); exiting a game in progress (the button or closing the window) asks whether to save first;
# a new game while the arenas' evolution is running asks whether to keep it.

extends Control

onready var btn_new_game = $ScreenControls/MainButtonsHBoxContainer/ButtonStartNewGame
onready var btn_load_game = $ScreenControls/MainButtonsHBoxContainer/ButtonLoadGame
onready var btn_save_game = $ScreenControls/MainButtonsHBoxContainer/ButtonSaveGame
onready var btn_exit_game = $ScreenControls/MainButtonsHBoxContainer/ButtonExitgame
onready var btn_close = $ScreenControls/ButtonClose

const PromptDialog = preload("res://src/core/ui/helpers/prompt_dialog.gd")

# Save notification popup (created dynamically)
var _save_popup: AcceptDialog = null
var _offered_load: bool = false  # The load prompt shows once, at start


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
	call_deferred("_offer_load")


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		_request_exit()


# --- Prompts ---

func _offer_load() -> void:
	if _offered_load:
		return
	_offered_load = true
	var summary: Dictionary = GameStateManager.get_save_summary() if is_instance_valid(GameStateManager) else {}
	if summary.empty():
		return
	var prompt = PromptDialog.ask(self, "Continue the saved game?", describe_save(summary), [["load", "LOAD GAME"], ["no", "NOT NOW"]])
	prompt.connect("chosen", self, "_on_load_offer_chosen")


func _on_load_offer_chosen(choice) -> void:
	if choice == "load":
		_on_load_game_pressed()


static func describe_save(summary: Dictionary) -> String:
	return PoolStringArray([
		"SAVED %s" % summary.get("saved_at", "?"),
		"PLAYED %.1f H" % (float(summary.get("play_time", 0.0)) / 3600.0),
		"ARENAS %.1f H SIMULATED (%.1f H WATCHED)" % [float(summary.get("game_time", 0.0)) / 3600.0, float(summary.get("real_time", 0.0)) / 3600.0],
		"EVOLUTION %d LIVES ENDED, %d BORN, %d NICHES, %d GENOMES" % [int(summary.get("lives", 0)), int(summary.get("births", 0)), int(summary.get("niches", 0)), int(summary.get("genomes", 0))],
		"BANK %d WP" % int(summary.get("bank", 0)),
	]).join("\n")


func _request_exit() -> void:
	if not _has_active_game_session():
		get_tree().quit()
		return
	_show_menu()
	var prompt = PromptDialog.ask(self, "Save before exiting?", "UNSAVED PLAY AND EVOLUTION ARE LOST ON EXIT.", [["save", "SAVE AND EXIT"], ["exit", "EXIT"], ["cancel", "CANCEL"]])
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
	if Evolution.lives_ended() > 0 or not Evolution.live.empty():
		var text: String = "THE ARENAS HAVE RUN %.1f H: %d LIVES ENDED." % [Evolution.game_time / 3600.0, Evolution.lives_ended()]
		var prompt = PromptDialog.ask(self, "Keep the evolution?", text, [["keep", "KEEP EVOLUTION"], ["over", "START OVER"], ["cancel", "CANCEL"]])
		prompt.connect("chosen", self, "_on_new_game_chosen")
		return
	_start_new_game()


func _on_new_game_chosen(choice) -> void:
	if choice == "cancel":
		return
	GameStateManager.keep_evolution = choice == "keep"
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
	if not is_instance_valid(_save_popup):
		_save_popup = AcceptDialog.new()
		_save_popup.pause_mode = Node.PAUSE_MODE_PROCESS
		add_child(_save_popup)
	
	if success:
		_save_popup.window_title = "Save Complete"
		_save_popup.dialog_text = "Game saved successfully!"
	else:
		_save_popup.window_title = "Save Failed"
		_save_popup.dialog_text = "Failed to save game. Check console for details."
	
	_save_popup.popup_centered()


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
