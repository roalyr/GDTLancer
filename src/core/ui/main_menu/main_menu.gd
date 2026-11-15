# MainMenu: new game, save, load, settings (OptionsWindow) and exit; it asks nothing at start. Load reads the game's own saves
# only (GameStateManager mode "play": never evolution's); exiting a game in progress (the button or
# closing the window) asks whether to save first; a new game starts a fresh world, its havens flying
# the presets. Save and load ask for a slot (a list: the player's slots, and for loading the
# autosave's too); saving over a game asks first. The autosave's slot is never offered for saving.
# Save needs a game running (before one there is nothing to save), and New during one asks first, as
# Exit does. The clock in the corner is the device's time, kept current while the menu shows.

extends Control

onready var btn_new_game = $ScreenControls/MainButtonsHBoxContainer/ButtonStartNewGame
onready var btn_load_game = $ScreenControls/MainButtonsHBoxContainer/ButtonLoadGame
onready var btn_save_game = $ScreenControls/MainButtonsHBoxContainer/ButtonSaveGame
onready var btn_exit_game = $ScreenControls/MainButtonsHBoxContainer/ButtonExitgame
onready var btn_close = $ScreenControls/ButtonClose
onready var btn_settings = $ScreenControls/MainButtonsHBoxContainer/ButtonSettings
onready var time_label: Label = $ScreenControls/TimeLabel
var options_window: Control = null
const OptionsWindowScene = preload("res://scenes/ui/menus/options_window.tscn")

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
	options_window = OptionsWindowScene.instance()
	add_child(options_window)
	if is_instance_valid(btn_settings):
		btn_settings.disabled = false
		btn_settings.connect("pressed", options_window, "open")

	if is_instance_valid(EventBus) and EventBus.has_signal("main_menu_requested"):
		if not EventBus.is_connected("main_menu_requested", self, "_show_menu"):
			EventBus.connect("main_menu_requested", self, "_show_menu")

	_update_load_button_state()
	_refresh_close_button_state()
	get_tree().set_auto_accept_quit(false)  # Closing the window asks first (_notification)
	# If nothing else requests it, show menu on boot.
	call_deferred("_show_menu")


func _process(_delta: float) -> void:
	if visible and is_instance_valid(time_label):
		var text: String = clock_text(OS.get_time())
		if time_label.text != text:
			time_label.text = text


# "HH:MM" of OS.get_time()'s {hour, minute}.
static func clock_text(time: Dictionary) -> String:
	return "%02d:%02d" % [int(time.get("hour", 0)), int(time.get("minute", 0))]


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
			_pick_save_slot(true)  # Quits once saved
		"exit":
			get_tree().quit()


func _on_new_game_pressed() -> void:
	if not _has_active_game_session():
		_start_new_game()
		return
	var prompt = PromptDialog.ask(self, "Start a new game?", "UNSAVED PLAY IS LOST.", [["new", "NEW GAME"], ["cancel", "CANCEL"]])
	prompt.connect("chosen", self, "_on_new_game_chosen")


func _on_new_game_chosen(choice) -> void:
	if choice == "new":
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

	if not GameStateManager.has_any_save():
		_update_load_button_state()
		return
	var choices: Array = []
	for slot in [GameStateManager.AUTOSAVE_SLOT] + GameStateManager.manual_slots():
		choices.append([str(slot), GameStateManager.slot_label(slot), not GameStateManager.has_save_file(slot)])
	choices.append(["cancel", "CANCEL"])
	PromptDialog.ask_list(self, "Load game", "PICK A SAVE. PLAY SINCE THE LAST SAVE IS LOST.", choices).connect("chosen", self, "_on_load_slot_chosen")


func _on_load_slot_chosen(choice) -> void:
	if choice == "cancel":
		return
	if GameStateManager.load_game(int(choice)):
		visible = false
	else:
		_show_menu()


func _on_save_game_pressed() -> void:
	if not is_instance_valid(GameStateManager):
		printerr("MainMenu: GameStateManager unavailable.")
		return
	if not _has_active_game_session():  # Nothing to save yet (the button is greyed out then)
		_refresh_close_button_state()
		return
	_pick_save_slot(false)


# The player's slots (not the autosave's), to save in; `then_quit`: the exit's SAVE AND EXIT.
func _pick_save_slot(then_quit: bool) -> void:
	var choices: Array = []
	for slot in GameStateManager.manual_slots():
		choices.append([str(slot), GameStateManager.slot_label(slot)])
	choices.append(["cancel", "CANCEL"])
	PromptDialog.ask_list(self, "Save game", "PICK A SLOT. THE AUTOSAVE HAS ITS OWN.", choices).connect("chosen", self, "_on_save_slot_chosen", [then_quit])


func _on_save_slot_chosen(choice, then_quit: bool) -> void:
	if choice == "cancel":
		return
	var slot: int = int(choice)
	if GameStateManager.has_save_file(slot):
		var prompt = PromptDialog.ask(self, "Save over slot %d?" % slot, GameStateManager.slot_label(slot), [["save", "SAVE OVER IT"], ["cancel", "CANCEL"]])
		prompt.connect("chosen", self, "_on_overwrite_chosen", [slot, then_quit])
		return
	_save_in(slot, then_quit)


func _on_overwrite_chosen(choice, slot: int, then_quit: bool) -> void:
	if choice == "save":
		_save_in(slot, then_quit)


func _save_in(slot: int, then_quit: bool) -> void:
	var success: bool = GameStateManager.save_game(slot)
	_update_load_button_state()
	if success and then_quit:
		get_tree().quit()
		return
	_show_save_notification(success, slot)


func _show_save_notification(success: bool, slot: int = -1) -> void:
	if success:
		PromptDialog.tell(self, "Saved", "THE GAME IS SAVED IN SLOT %d." % slot if slot > 0 else "THE GAME IS SAVED.")
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
	if is_instance_valid(GameStateManager) and GameStateManager.has_method("has_any_save"):
		btn_load_game.disabled = not GameStateManager.has_any_save()
	else:
		btn_load_game.disabled = true


# Close and Save need a game running.
func _refresh_close_button_state() -> void:
	if is_instance_valid(btn_close):
		btn_close.disabled = not _has_active_game_session()
	if is_instance_valid(btn_save_game):
		btn_save_game.disabled = not _has_active_game_session()


func _has_active_game_session() -> bool:
	return GameState.current_sector_id != "" or is_instance_valid(GameState.current_zone_instance)


func _show_menu() -> void:
	visible = true
	get_tree().paused = true
	_update_load_button_state()
	_refresh_close_button_state()
