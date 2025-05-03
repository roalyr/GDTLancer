tool
extends EditorPlugin


class ShortcutDialog:
	extends ConfirmationDialog

	var shortcut: InputEventKey setget set_shortcut

	func _ready():
		window_title = "Set a gdformat shortcut"
		set_process_input(false)
		connect("about_to_show", self, "set_process_input", [true])
		connect("popup_hide", self, "set_process_input", [false])

	func _input(event: InputEvent):
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			self.shortcut = event

	func set_shortcut(value: InputEventKey) -> void:
		shortcut = value
		if shortcut:
			dialog_text = shortcut.as_text()
		else:
			dialog_text = ""


const CONFIG_PATH := "user://gdformat_plugin.cfg"

var default_shortcut := InputEventKey.new()
var shortcut := InputEventKey.new()
var format_button: Button
var shortcut_button: Button
var shortcut_dialog: ShortcutDialog
var config = ConfigFile.new()


func _enter_tree():
	format_button = Button.new()
	shortcut_button = Button.new()
	shortcut_dialog = ShortcutDialog.new()

	default_shortcut.control = true
	default_shortcut.alt = true
	default_shortcut.scancode = KEY_L

	populate_name_by_key()
	load_shortcut()

	var error = shortcut_dialog.connect("confirmed", self, "save_shortcut")
	if error:
		printerr("Error while connecting to the shortcut dialog's confirmed signal")
	else:
		get_editor_interface().get_base_control().add_child(shortcut_dialog)

	shortcut_button.text = "Set format shortcut"
	error = shortcut_button.connect("pressed", self, "show_shortcut_dialog")
	if error:
		printerr("Error while connecting to the shortcut button's pressed signal")
	else:
		add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, shortcut_button)

	format_button.text = "Format script"
	error = format_button.connect("pressed", self, "format_script")
	if error:
		printerr("Error while connecting to the format button's pressed signal")
	else:
		add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, format_button)


func _process(_delta: float):
	if format_button:
		format_button.visible = is_editing_gdscript()


func _exit_tree():
	if shortcut_button:
		if shortcut_button.is_inside_tree():
			remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, shortcut_button)
		shortcut_button.queue_free()
	if format_button:
		if format_button.is_inside_tree():
			remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, format_button)
		format_button.queue_free()
	if shortcut_dialog:
		shortcut_dialog.hide()
		shortcut_dialog.queue_free()


func _input(event: InputEvent):
	# Check the shortcut is pressed
	if (
		event is InputEventKey
		and event.is_pressed()
		and not event.is_echo()
		and event.shortcut_match(shortcut)
		and is_editing_gdscript()
	):
		format_script()


func show_shortcut_dialog() -> void:
	shortcut_dialog.popup_centered()


func populate_name_by_key() -> void:
	if NAME_BY_KEY.empty():
		for key in KEY_BY_NAME.keys():
			NAME_BY_KEY[KEY_BY_NAME[key]] = key


func save_shortcut() -> void:
	shortcut = shortcut_dialog.shortcut

	config.clear()
	config.set_value("shortcut", "mod_alt", shortcut.alt)
	config.set_value("shortcut", "mod_shift", shortcut.shift)
	config.set_value("shortcut", "mod_control", shortcut.control)
	config.set_value("shortcut", "mod_meta", shortcut.meta)
	config.set_value("shortcut", "mod_command", shortcut.command)
	config.set_value("shortcut", "key", NAME_BY_KEY[shortcut.scancode])

	var error = config.save(CONFIG_PATH)
	if error:
		printerr("Error while saving the shortcut")


func load_shortcut() -> void:
	var error = config.load(CONFIG_PATH)
	if error:
		if error != ERR_FILE_NOT_FOUND:
			printerr("Error while importing the saved shortcut")
		shortcut = default_shortcut
	else:
		shortcut.alt = config.get_value("shortcut", "mod_alt", default_shortcut.alt)
		shortcut.shift = config.get_value("shortcut", "mod_shift", default_shortcut.shift)
		shortcut.control = config.get_value("shortcut", "mod_control", default_shortcut.control)
		shortcut.meta = config.get_value("shortcut", "mod_meta", default_shortcut.meta)
		shortcut.command = config.get_value("shortcut", "mod_command", default_shortcut.command)
		var key_str = config.get_value("shortcut", "key", NAME_BY_KEY[default_shortcut.scancode])
		shortcut.scancode = KEY_BY_NAME[key_str]

	shortcut_dialog.shortcut = shortcut


func is_editing_gdscript() -> bool:
	var editor_interface := get_editor_interface()
	var focus_owner := editor_interface.get_base_control().get_focus_owner()
	if not focus_owner:
		return false

	var script_editor := editor_interface.get_script_editor()
	var script_editor_has_focus := script_editor.is_a_parent_of(focus_owner)

	if script_editor_has_focus:
		var script := get_editor_interface().get_script_editor().get_current_script()
		return script is GDScript

	return false


func save_script(script: GDScript) -> bool:
	return ResourceSaver.save(script.resource_path, script) == OK


func refresh_script(script: GDScript) -> void:
	# The goal here is to refresh the "ScriptTextEditor" with the new source code
	# It's kinda tricky and messy
	var script_text_editor: Node = get_editor_interface().get_script_editor().find_node(
		"ScriptTextEditor", true, false
	)
	var script_tab_container: TabContainer = script_text_editor.get_parent()
	var script_tab_control = script_tab_container.get_current_tab_control()

	# 1. Open a dummy resource. We break the editor if we remove the currently open script.
	get_editor_interface().edit_resource(GDScript.new())
	var tmp_tab_control = script_tab_container.get_current_tab_control()
	var tmp_is_before = tmp_tab_control.get_index() < script_tab_control.get_index()

	# 2. Close the script
	script_tab_container.remove_child(script_tab_control)

	# 3. Fetch the updated source code
	var file = File.new()
	file.open(script.resource_path, File.READ)
	script.source_code = file.get_as_text()
	file.close()

	# 4. Re-open the script
	get_editor_interface().edit_resource(script)

	# 5. Close the dummy resource
	script_tab_container.remove_child(tmp_tab_control)

	# 6. Select the correct tab if necessary
	if tmp_is_before:
		script_tab_container.current_tab = script_tab_container.current_tab - 1


func format_script() -> void:
	var script := get_editor_interface().get_script_editor().get_current_script()

	if not save_script(script):
		printerr("Error while saving the script")

	var absolute_script_path := ProjectSettings.globalize_path(script.resource_path)

	var command_output = []
	var exit_code := OS.execute("gdformat", [absolute_script_path], true, command_output, true)

	if exit_code != 0:
		for output_line in command_output:
			printerr(output_line)
		printerr("Failed to format current script. Check the above error.")
	else:
		refresh_script(script)


const KEY_BY_NAME := {
	"KEY_ESCAPE": KEY_ESCAPE,
	"KEY_TAB": KEY_TAB,
	"KEY_BACKTAB": KEY_BACKTAB,
	"KEY_BACKSPACE": KEY_BACKSPACE,
	"KEY_ENTER": KEY_ENTER,
	"KEY_KP_ENTER": KEY_KP_ENTER,
	"KEY_INSERT": KEY_INSERT,
	"KEY_DELETE": KEY_DELETE,
	"KEY_PAUSE": KEY_PAUSE,
	"KEY_PRINT": KEY_PRINT,
	"KEY_SYSREQ": KEY_SYSREQ,
	"KEY_CLEAR": KEY_CLEAR,
	"KEY_HOME": KEY_HOME,
	"KEY_END": KEY_END,
	"KEY_LEFT": KEY_LEFT,
	"KEY_UP": KEY_UP,
	"KEY_RIGHT": KEY_RIGHT,
	"KEY_DOWN": KEY_DOWN,
	"KEY_PAGEUP": KEY_PAGEUP,
	"KEY_PAGEDOWN": KEY_PAGEDOWN,
	"KEY_SHIFT": KEY_SHIFT,
	"KEY_CONTROL": KEY_CONTROL,
	"KEY_META": KEY_META,
	"KEY_ALT": KEY_ALT,
	"KEY_CAPSLOCK": KEY_CAPSLOCK,
	"KEY_NUMLOCK": KEY_NUMLOCK,
	"KEY_SCROLLLOCK": KEY_SCROLLLOCK,
	"KEY_F1": KEY_F1,
	"KEY_F2": KEY_F2,
	"KEY_F3": KEY_F3,
	"KEY_F4": KEY_F4,
	"KEY_F5": KEY_F5,
	"KEY_F6": KEY_F6,
	"KEY_F7": KEY_F7,
	"KEY_F8": KEY_F8,
	"KEY_F9": KEY_F9,
	"KEY_F10": KEY_F10,
	"KEY_F11": KEY_F11,
	"KEY_F12": KEY_F12,
	"KEY_F13": KEY_F13,
	"KEY_F14": KEY_F14,
	"KEY_F15": KEY_F15,
	"KEY_F16": KEY_F16,
	"KEY_KP_MULTIPLY": KEY_KP_MULTIPLY,
	"KEY_KP_DIVIDE": KEY_KP_DIVIDE,
	"KEY_KP_SUBTRACT": KEY_KP_SUBTRACT,
	"KEY_KP_PERIOD": KEY_KP_PERIOD,
	"KEY_KP_ADD": KEY_KP_ADD,
	"KEY_KP_0": KEY_KP_0,
	"KEY_KP_1": KEY_KP_1,
	"KEY_KP_2": KEY_KP_2,
	"KEY_KP_3": KEY_KP_3,
	"KEY_KP_4": KEY_KP_4,
	"KEY_KP_5": KEY_KP_5,
	"KEY_KP_6": KEY_KP_6,
	"KEY_KP_7": KEY_KP_7,
	"KEY_KP_8": KEY_KP_8,
	"KEY_KP_9": KEY_KP_9,
	"KEY_SUPER_L": KEY_SUPER_L,
	"KEY_SUPER_R": KEY_SUPER_R,
	"KEY_MENU": KEY_MENU,
	"KEY_HYPER_L": KEY_HYPER_L,
	"KEY_HYPER_R": KEY_HYPER_R,
	"KEY_HELP": KEY_HELP,
	"KEY_DIRECTION_L": KEY_DIRECTION_L,
	"KEY_DIRECTION_R": KEY_DIRECTION_R,
	"KEY_BACK": KEY_BACK,
	"KEY_FORWARD": KEY_FORWARD,
	"KEY_STOP": KEY_STOP,
	"KEY_REFRESH": KEY_REFRESH,
	"KEY_VOLUMEDOWN": KEY_VOLUMEDOWN,
	"KEY_VOLUMEMUTE": KEY_VOLUMEMUTE,
	"KEY_VOLUMEUP": KEY_VOLUMEUP,
	"KEY_BASSBOOST": KEY_BASSBOOST,
	"KEY_BASSUP": KEY_BASSUP,
	"KEY_BASSDOWN": KEY_BASSDOWN,
	"KEY_TREBLEUP": KEY_TREBLEUP,
	"KEY_TREBLEDOWN": KEY_TREBLEDOWN,
	"KEY_MEDIAPLAY": KEY_MEDIAPLAY,
	"KEY_MEDIASTOP": KEY_MEDIASTOP,
	"KEY_MEDIAPREVIOUS": KEY_MEDIAPREVIOUS,
	"KEY_MEDIANEXT": KEY_MEDIANEXT,
	"KEY_MEDIARECORD": KEY_MEDIARECORD,
	"KEY_HOMEPAGE": KEY_HOMEPAGE,
	"KEY_FAVORITES": KEY_FAVORITES,
	"KEY_SEARCH": KEY_SEARCH,
	"KEY_STANDBY": KEY_STANDBY,
	"KEY_OPENURL": KEY_OPENURL,
	"KEY_LAUNCHMAIL": KEY_LAUNCHMAIL,
	"KEY_LAUNCHMEDIA": KEY_LAUNCHMEDIA,
	"KEY_LAUNCH0": KEY_LAUNCH0,
	"KEY_LAUNCH1": KEY_LAUNCH1,
	"KEY_LAUNCH2": KEY_LAUNCH2,
	"KEY_LAUNCH3": KEY_LAUNCH3,
	"KEY_LAUNCH4": KEY_LAUNCH4,
	"KEY_LAUNCH5": KEY_LAUNCH5,
	"KEY_LAUNCH6": KEY_LAUNCH6,
	"KEY_LAUNCH7": KEY_LAUNCH7,
	"KEY_LAUNCH8": KEY_LAUNCH8,
	"KEY_LAUNCH9": KEY_LAUNCH9,
	"KEY_LAUNCHA": KEY_LAUNCHA,
	"KEY_LAUNCHB": KEY_LAUNCHB,
	"KEY_LAUNCHC": KEY_LAUNCHC,
	"KEY_LAUNCHD": KEY_LAUNCHD,
	"KEY_LAUNCHE": KEY_LAUNCHE,
	"KEY_LAUNCHF": KEY_LAUNCHF,
	"KEY_UNKNOWN": KEY_UNKNOWN,
	"KEY_SPACE": KEY_SPACE,
	"KEY_EXCLAM": KEY_EXCLAM,
	"KEY_QUOTEDBL": KEY_QUOTEDBL,
	"KEY_NUMBERSIGN": KEY_NUMBERSIGN,
	"KEY_DOLLAR": KEY_DOLLAR,
	"KEY_PERCENT": KEY_PERCENT,
	"KEY_AMPERSAND": KEY_AMPERSAND,
	"KEY_APOSTROPHE": KEY_APOSTROPHE,
	"KEY_PARENLEFT": KEY_PARENLEFT,
	"KEY_PARENRIGHT": KEY_PARENRIGHT,
	"KEY_ASTERISK": KEY_ASTERISK,
	"KEY_PLUS": KEY_PLUS,
	"KEY_COMMA": KEY_COMMA,
	"KEY_MINUS": KEY_MINUS,
	"KEY_PERIOD": KEY_PERIOD,
	"KEY_SLASH": KEY_SLASH,
	"KEY_0": KEY_0,
	"KEY_1": KEY_1,
	"KEY_2": KEY_2,
	"KEY_3": KEY_3,
	"KEY_4": KEY_4,
	"KEY_5": KEY_5,
	"KEY_6": KEY_6,
	"KEY_7": KEY_7,
	"KEY_8": KEY_8,
	"KEY_9": KEY_9,
	"KEY_COLON": KEY_COLON,
	"KEY_SEMICOLON": KEY_SEMICOLON,
	"KEY_LESS": KEY_LESS,
	"KEY_EQUAL": KEY_EQUAL,
	"KEY_GREATER": KEY_GREATER,
	"KEY_QUESTION": KEY_QUESTION,
	"KEY_AT": KEY_AT,
	"KEY_A": KEY_A,
	"KEY_B": KEY_B,
	"KEY_C": KEY_C,
	"KEY_D": KEY_D,
	"KEY_E": KEY_E,
	"KEY_F": KEY_F,
	"KEY_G": KEY_G,
	"KEY_H": KEY_H,
	"KEY_I": KEY_I,
	"KEY_J": KEY_J,
	"KEY_K": KEY_K,
	"KEY_L": KEY_L,
	"KEY_M": KEY_M,
	"KEY_N": KEY_N,
	"KEY_O": KEY_O,
	"KEY_P": KEY_P,
	"KEY_Q": KEY_Q,
	"KEY_R": KEY_R,
	"KEY_S": KEY_S,
	"KEY_T": KEY_T,
	"KEY_U": KEY_U,
	"KEY_V": KEY_V,
	"KEY_W": KEY_W,
	"KEY_X": KEY_X,
	"KEY_Y": KEY_Y,
	"KEY_Z": KEY_Z,
	"KEY_BRACKETLEFT": KEY_BRACKETLEFT,
	"KEY_BACKSLASH": KEY_BACKSLASH,
	"KEY_BRACKETRIGHT": KEY_BRACKETRIGHT,
	"KEY_ASCIICIRCUM": KEY_ASCIICIRCUM,
	"KEY_UNDERSCORE": KEY_UNDERSCORE,
	"KEY_QUOTELEFT": KEY_QUOTELEFT,
	"KEY_BRACELEFT": KEY_BRACELEFT,
	"KEY_BAR": KEY_BAR,
	"KEY_BRACERIGHT": KEY_BRACERIGHT,
	"KEY_ASCIITILDE": KEY_ASCIITILDE,
	"KEY_NOBREAKSPACE": KEY_NOBREAKSPACE,
	"KEY_EXCLAMDOWN": KEY_EXCLAMDOWN,
	"KEY_CENT": KEY_CENT,
	"KEY_STERLING": KEY_STERLING,
	"KEY_CURRENCY": KEY_CURRENCY,
	"KEY_YEN": KEY_YEN,
	"KEY_BROKENBAR": KEY_BROKENBAR,
	"KEY_SECTION": KEY_SECTION,
	"KEY_DIAERESIS": KEY_DIAERESIS,
	"KEY_COPYRIGHT": KEY_COPYRIGHT,
	"KEY_ORDFEMININE": KEY_ORDFEMININE,
	"KEY_GUILLEMOTLEFT": KEY_GUILLEMOTLEFT,
	"KEY_NOTSIGN": KEY_NOTSIGN,
	"KEY_HYPHEN": KEY_HYPHEN,
	"KEY_REGISTERED": KEY_REGISTERED,
	"KEY_MACRON": KEY_MACRON,
	"KEY_DEGREE": KEY_DEGREE,
	"KEY_PLUSMINUS": KEY_PLUSMINUS,
	"KEY_TWOSUPERIOR": KEY_TWOSUPERIOR,
	"KEY_THREESUPERIOR": KEY_THREESUPERIOR,
	"KEY_ACUTE": KEY_ACUTE,
	"KEY_MU": KEY_MU,
	"KEY_PARAGRAPH": KEY_PARAGRAPH,
	"KEY_PERIODCENTERED": KEY_PERIODCENTERED,
	"KEY_CEDILLA": KEY_CEDILLA,
	"KEY_ONESUPERIOR": KEY_ONESUPERIOR,
	"KEY_MASCULINE": KEY_MASCULINE,
	"KEY_GUILLEMOTRIGHT": KEY_GUILLEMOTRIGHT,
	"KEY_ONEQUARTER": KEY_ONEQUARTER,
	"KEY_ONEHALF": KEY_ONEHALF,
	"KEY_THREEQUARTERS": KEY_THREEQUARTERS,
	"KEY_QUESTIONDOWN": KEY_QUESTIONDOWN,
	"KEY_AGRAVE": KEY_AGRAVE,
	"KEY_AACUTE": KEY_AACUTE,
	"KEY_ACIRCUMFLEX": KEY_ACIRCUMFLEX,
	"KEY_ATILDE": KEY_ATILDE,
	"KEY_ADIAERESIS": KEY_ADIAERESIS,
	"KEY_ARING": KEY_ARING,
	"KEY_AE": KEY_AE,
	"KEY_CCEDILLA": KEY_CCEDILLA,
	"KEY_EGRAVE": KEY_EGRAVE,
	"KEY_EACUTE": KEY_EACUTE,
	"KEY_ECIRCUMFLEX": KEY_ECIRCUMFLEX,
	"KEY_EDIAERESIS": KEY_EDIAERESIS,
	"KEY_IGRAVE": KEY_IGRAVE,
	"KEY_IACUTE": KEY_IACUTE,
	"KEY_ICIRCUMFLEX": KEY_ICIRCUMFLEX,
	"KEY_IDIAERESIS": KEY_IDIAERESIS,
	"KEY_ETH": KEY_ETH,
	"KEY_NTILDE": KEY_NTILDE,
	"KEY_OGRAVE": KEY_OGRAVE,
	"KEY_OACUTE": KEY_OACUTE,
	"KEY_OCIRCUMFLEX": KEY_OCIRCUMFLEX,
	"KEY_OTILDE": KEY_OTILDE,
	"KEY_ODIAERESIS": KEY_ODIAERESIS,
	"KEY_MULTIPLY": KEY_MULTIPLY,
	"KEY_OOBLIQUE": KEY_OOBLIQUE,
	"KEY_UGRAVE": KEY_UGRAVE,
	"KEY_UACUTE": KEY_UACUTE,
	"KEY_UCIRCUMFLEX": KEY_UCIRCUMFLEX,
	"KEY_UDIAERESIS": KEY_UDIAERESIS,
	"KEY_YACUTE": KEY_YACUTE,
	"KEY_THORN": KEY_THORN,
	"KEY_SSHARP": KEY_SSHARP,
	"KEY_DIVISION": KEY_DIVISION,
	"KEY_YDIAERESIS": KEY_YDIAERESIS
}

const NAME_BY_KEY = {}
