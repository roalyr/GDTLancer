--- Start of ./addons/gdformat/gdformat.gd ---

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

--- Start of ./addons/gut/autofree.gd ---

# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# Class used to keep track of objects to be freed and utilities to free them.
# ##############################################################################
var _to_free = []
var _to_queue_free = []

func add_free(thing):
	if(typeof(thing) == TYPE_OBJECT):
		if(!thing is Reference):
			_to_free.append(thing)

func add_queue_free(thing):
	_to_queue_free.append(thing)

func get_queue_free_count():
	return _to_queue_free.size()

func get_free_count():
	return _to_free.size()

func free_all():
	for i in range(_to_free.size()):
		if(is_instance_valid(_to_free[i])):
			_to_free[i].free()
	_to_free.clear()

	for i in range(_to_queue_free.size()):
		if(is_instance_valid(_to_queue_free[i])):
			_to_queue_free[i].queue_free()
	_to_queue_free.clear()

--- Start of ./addons/gut/comparator.gd ---

var _utils = load('res://addons/gut/utils.gd').get_instance()
var _strutils = _utils.Strutils.new()
var _max_length = 100
var _should_compare_int_to_float = true

const MISSING = '|__missing__gut__compare__value__|'
const DICTIONARY_DISCLAIMER = 'Dictionaries are compared-by-ref.  See assert_eq in wiki.'

func _cannot_comapre_text(v1, v2):
	return str('Cannot compare ', _strutils.types[typeof(v1)], ' with ',
		_strutils.types[typeof(v2)], '.')

func _make_missing_string(text):
	return '<missing ' + text + '>'

func _create_missing_result(v1, v2, text):
	var to_return = null
	var v1_str = format_value(v1)
	var v2_str = format_value(v2)

	if(typeof(v1) == TYPE_STRING and v1 == MISSING):
		v1_str = _make_missing_string(text)
		to_return = _utils.CompareResult.new()
	elif(typeof(v2) == TYPE_STRING and v2 == MISSING):
		v2_str = _make_missing_string(text)
		to_return = _utils.CompareResult.new()

	if(to_return != null):
		to_return.summary = str(v1_str, ' != ', v2_str)
		to_return.are_equal = false

	return to_return


func simple(v1, v2, missing_string=''):
	var missing_result = _create_missing_result(v1, v2, missing_string)
	if(missing_result != null):
		return missing_result

	var result = _utils.CompareResult.new()
	var cmp_str = null
	var extra = ''

	if(_should_compare_int_to_float and [2, 3].has(typeof(v1)) and [2, 3].has(typeof(v2))):
		result.are_equal = v1 == v2

	elif(_utils.are_datatypes_same(v1, v2)):
		result.are_equal = v1 == v2
		if(typeof(v1) == TYPE_DICTIONARY):
			if(result.are_equal):
				extra = '.  Same dictionary ref.  '
			else:
				extra = '.  Different dictionary refs.  '
			extra += DICTIONARY_DISCLAIMER

		if(typeof(v1) == TYPE_ARRAY):
			var array_result = _utils.DiffTool.new(v1, v2, _utils.DIFF.SHALLOW)
			result.summary = array_result.get_short_summary()
			if(!array_result.are_equal()):
				extra = ".\n" + array_result.get_short_summary()

	else:
		cmp_str = '!='
		result.are_equal = false
		extra = str('.  ', _cannot_comapre_text(v1, v2))

	cmp_str = get_compare_symbol(result.are_equal)
	result.summary = str(format_value(v1), ' ', cmp_str, ' ', format_value(v2), extra)

	return result


func shallow(v1, v2):
	var result =  null

	if(_utils.are_datatypes_same(v1, v2)):
		if(typeof(v1) in [TYPE_ARRAY, TYPE_DICTIONARY]):
			result = _utils.DiffTool.new(v1, v2, _utils.DIFF.SHALLOW)
		else:
			result = simple(v1, v2)
	else:
		result = simple(v1, v2)

	return result


func deep(v1, v2):
	var result =  null

	if(_utils.are_datatypes_same(v1, v2)):
		if(typeof(v1) in [TYPE_ARRAY, TYPE_DICTIONARY]):
			result = _utils.DiffTool.new(v1, v2, _utils.DIFF.DEEP)
		else:
			result = simple(v1, v2)
	else:
		result = simple(v1, v2)

	return result


func format_value(val, max_val_length=_max_length):
	return _strutils.truncate_string(_strutils.type2str(val), max_val_length)


func compare(v1, v2, diff_type=_utils.DIFF.SIMPLE):
	var result = null
	if(diff_type == _utils.DIFF.SIMPLE):
		result = simple(v1, v2)
	elif(diff_type == _utils.DIFF.SHALLOW):
		result = shallow(v1, v2)
	elif(diff_type ==  _utils.DIFF.DEEP):
		result = deep(v1, v2)

	return result


func get_should_compare_int_to_float():
	return _should_compare_int_to_float


func set_should_compare_int_to_float(should_compare_int_float):
	_should_compare_int_to_float = should_compare_int_float


func get_compare_symbol(is_equal):
	if(is_equal):
		return '=='
	else:
		return '!='

--- Start of ./addons/gut/compare_result.gd ---

var are_equal = null setget set_are_equal, get_are_equal
var summary = null setget set_summary, get_summary
var max_differences = 30 setget set_max_differences, get_max_differences
var differences = {} setget set_differences, get_differences

func _block_set(which, val):
	push_error(str('cannot set ', which, ', value [', val, '] ignored.'))

func _to_string():
	return str(get_summary()) # could be null, gotta str it.

func get_are_equal():
	return are_equal

func set_are_equal(r_eq):
	are_equal = r_eq

func get_summary():
	return summary

func set_summary(smry):
	summary = smry

func get_total_count():
	pass

func get_different_count():
	pass

func get_short_summary():
	return summary

func get_max_differences():
	return max_differences

func set_max_differences(max_diff):
	max_differences = max_diff

func get_differences():
	return differences

func set_differences(diffs):
	_block_set('differences', diffs)

func get_brackets():
	return null

--- Start of ./addons/gut/diff_formatter.gd ---

var _utils = load('res://addons/gut/utils.gd').get_instance()
var _strutils = _utils.Strutils.new()
const INDENT = '    '
var _max_to_display = 30
const ABSOLUTE_MAX_DISPLAYED = 10000
const UNLIMITED = -1


func _single_diff(diff, depth=0):
	var to_return = ""
	var brackets = diff.get_brackets()

	if(brackets != null and !diff.are_equal):
		to_return = ''
		to_return += str(brackets.open, "\n",
			_strutils.indent_text(differences_to_s(diff.differences, depth), depth+1, INDENT), "\n",
			brackets.close)
	else:
		to_return = str(diff)

	return to_return


func make_it(diff):
	var to_return = ''
	if(diff.are_equal):
		to_return = diff.summary
	else:
		if(_max_to_display ==  ABSOLUTE_MAX_DISPLAYED):
			to_return = str(diff.get_value_1(), ' != ', diff.get_value_2())
		else:
			to_return = diff.get_short_summary()
		to_return +=  str("\n", _strutils.indent_text(_single_diff(diff, 0), 1, '  '))
	return to_return


func differences_to_s(differences, depth=0):
	var to_return = ''
	var keys = differences.keys()
	keys.sort()
	var limit = min(_max_to_display, differences.size())

	for i in range(limit):
		var key = keys[i]
		to_return += str(key, ":  ", _single_diff(differences[key], depth))

		if(i != limit -1):
			to_return += "\n"

	if(differences.size() > _max_to_display):
		to_return += str("\n\n... ", differences.size() - _max_to_display, " more.")

	return to_return


func get_max_to_display():
	return _max_to_display


func set_max_to_display(max_to_display):
	_max_to_display = max_to_display
	if(_max_to_display == UNLIMITED):
		_max_to_display = ABSOLUTE_MAX_DISPLAYED

--- Start of ./addons/gut/diff_tool.gd ---

extends 'res://addons/gut/compare_result.gd'
const INDENT = '    '
enum {
	DEEP,
	SHALLOW,
	SIMPLE
}

var _utils = load('res://addons/gut/utils.gd').get_instance()
var _strutils = _utils.Strutils.new()
var _compare = _utils.Comparator.new()
var DiffTool = load('res://addons/gut/diff_tool.gd')

var _value_1 = null
var _value_2 = null
var _total_count = 0
var _diff_type = null
var _brackets = null
var _valid = true
var _desc_things = 'somethings'

# -------- comapre_result.gd "interface" ---------------------
func set_are_equal(val):
	_block_set('are_equal', val)

func get_are_equal():
	return are_equal()

func set_summary(val):
	_block_set('summary', val)

func get_summary():
	return summarize()

func get_different_count():
	return differences.size()

func  get_total_count():
	return _total_count

func get_short_summary():
	var text = str(_strutils.truncate_string(str(_value_1), 50),
		' ', _compare.get_compare_symbol(are_equal()), ' ',
		_strutils.truncate_string(str(_value_2), 50))
	if(!are_equal()):
		text += str('  ', get_different_count(), ' of ', get_total_count(),
			' ', _desc_things, ' do not match.')
	return text

func get_brackets():
	return _brackets
# -------- comapre_result.gd "interface" ---------------------


func _invalidate():
	_valid = false
	differences = null


func _init(v1, v2, diff_type=DEEP):
	_value_1 = v1
	_value_2 = v2
	_diff_type = diff_type
	_compare.set_should_compare_int_to_float(false)
	_find_differences(_value_1, _value_2)


func _find_differences(v1, v2):
	if(_utils.are_datatypes_same(v1, v2)):
		if(typeof(v1) == TYPE_ARRAY):
			_brackets = {'open':'[', 'close':']'}
			_desc_things = 'indexes'
			_diff_array(v1, v2)
		elif(typeof(v2) == TYPE_DICTIONARY):
			_brackets = {'open':'{', 'close':'}'}
			_desc_things = 'keys'
			_diff_dictionary(v1, v2)
		else:
			_invalidate()
			_utils.get_logger().error('Only Arrays and Dictionaries are supported.')
	else:
		_invalidate()
		_utils.get_logger().error('Only Arrays and Dictionaries are supported.')


func _diff_array(a1, a2):
	_total_count = max(a1.size(), a2.size())
	for i in range(a1.size()):
		var result = null
		if(i < a2.size()):
			if(_diff_type == DEEP):
				result = _compare.deep(a1[i], a2[i])
			else:
				result = _compare.simple(a1[i], a2[i])
		else:
			result = _compare.simple(a1[i], _compare.MISSING, 'index')

		if(!result.are_equal):
			differences[i] = result

	if(a1.size() < a2.size()):
		for i in range(a1.size(), a2.size()):
			differences[i] = _compare.simple(_compare.MISSING, a2[i], 'index')


func _diff_dictionary(d1, d2):
	var d1_keys = d1.keys()
	var d2_keys = d2.keys()

	# Process all the keys in d1
	_total_count += d1_keys.size()
	for key in d1_keys:
		if(!d2.has(key)):
			differences[key] = _compare.simple(d1[key], _compare.MISSING, 'key')
		else:
			d2_keys.remove(d2_keys.find(key))

			var result = null
			if(_diff_type == DEEP):
				result = _compare.deep(d1[key], d2[key])
			else:
				result = _compare.simple(d1[key], d2[key])

			if(!result.are_equal):
				differences[key] = result

	# Process all the keys in d2 that didn't exist in d1
	_total_count += d2_keys.size()
	for i in range(d2_keys.size()):
		differences[d2_keys[i]] = _compare.simple(_compare.MISSING, d2[d2_keys[i]], 'key')


func summarize():
	var summary = ''

	if(are_equal()):
		summary = get_short_summary()
	else:
		var formatter = load('res://addons/gut/diff_formatter.gd').new()
		formatter.set_max_to_display(max_differences)
		summary = formatter.make_it(self)

	return summary


func are_equal():
	if(!_valid):
		return null
	else:
		return differences.size() == 0


func get_diff_type():
	return _diff_type


func get_value_1():
	return _value_1


func get_value_2():
	return _value_2

--- Start of ./addons/gut/doubler.gd ---

# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# Description
# -----------
# ##############################################################################

# ------------------------------------------------------------------------------
# Utility class to hold the local and built in methods separately.  Add all local
# methods FIRST, then add built ins.
# ------------------------------------------------------------------------------
class ScriptMethods:
	# List of methods that should not be overloaded when they are not defined
	# in the class being doubled.  These either break things if they are
	# overloaded or do not have a "super" equivalent so we can't just pass
	# through.
	var _blacklist = [
		'has_method',
		'get_script',
		'get',
		'_notification',
		'get_path',
		'_enter_tree',
		'_exit_tree',
		'_process',
		'_draw',
		'_physics_process',
		'_input',
		'_unhandled_input',
		'_unhandled_key_input',
		'_set',
		'_get', # probably
		'emit_signal', # can't handle extra parameters to be sent with signal.
		'draw_mesh', # issue with one parameter, value is `Null((..), (..), (..))``
		'_to_string', # nonexistant function ._to_string
		'_get_minimum_size', # Nonexistent function _get_minimum_size
	]


	var built_ins = []
	var local_methods = []
	var _method_names = []

	func is_blacklisted(method_meta):
		return _blacklist.find(method_meta.name) != -1

	func _add_name_if_does_not_have(method_name):
		var should_add = _method_names.find(method_name) == -1
		if(should_add):
			_method_names.append(method_name)
		return should_add

	func add_built_in_method(method_meta):
		var did_add = _add_name_if_does_not_have(method_meta.name)
		if(did_add and !is_blacklisted(method_meta)):
			built_ins.append(method_meta)

	func add_local_method(method_meta):
		var did_add = _add_name_if_does_not_have(method_meta.name)
		if(did_add):
			local_methods.append(method_meta)

	func to_s():
		var text = "Locals\n"
		for i in range(local_methods.size()):
			text += str("  ", local_methods[i].name, "\n")
		text += "Built-Ins\n"
		for i in range(built_ins.size()):
			text += str("  ", built_ins[i].name, "\n")
		return text

# ------------------------------------------------------------------------------
# Helper class to deal with objects and inner classes.
# ------------------------------------------------------------------------------
class ObjectInfo:
	var _path = null
	var _subpaths = []
	var _utils = load('res://addons/gut/utils.gd').get_instance()
	var _lgr = _utils.get_logger()
	var _method_strategy = null
	var make_partial_double = false
	var scene_path = null
	var _native_class = null
	var _native_class_name = null
	var _singleton_instance = null
	var _singleton_name = null

	func _init(path, subpath=null):
		_path = path
		if(subpath != null):
			_subpaths = Array(subpath.split('/'))

	# Returns an instance of the class/inner class
	func instantiate():
		var to_return = null

		if(_singleton_instance != null):
			to_return = _singleton_instance
		elif(is_native()):
			to_return = _native_class.new()
		else:
			to_return = get_loaded_class().new()

		return to_return


	# Can't call it get_class because that is reserved so it gets this ugly name.
	# Loads up the class and then any inner classes to give back a reference to
	# the desired Inner class (if there is any)
	func get_loaded_class():
		var LoadedClass = load(_path)
		for i in range(_subpaths.size()):
			LoadedClass = LoadedClass.get(_subpaths[i])
		return LoadedClass


	func to_s():
		return str(_path, '[', get_subpath(), ']')


	func get_path():
		return _path


	func get_subpath():
		return PoolStringArray(_subpaths).join('/')


	func has_subpath():
		return _subpaths.size() != 0


	func get_method_strategy():
		return _method_strategy


	func set_method_strategy(method_strategy):
		_method_strategy = method_strategy


	func is_native():
		return _native_class != null


	func set_native_class(native_class):
		_native_class = native_class
		var inst = native_class.new()
		_native_class_name = inst.get_class()
		_path = _native_class_name
		if(!inst is Reference):
			inst.free()


	func get_native_class_name():
		return _native_class_name


	func get_singleton_instance():
		return _singleton_instance


	func get_singleton_name():
		return _singleton_name


	func set_singleton_name(singleton_name):
		_singleton_name = singleton_name
		_singleton_instance = _utils.get_singleton_by_name(_singleton_name)


	func is_singleton():
		return _singleton_instance != null


	func get_extends_text():
		var extend = null
		if(is_singleton()):
			extend = str("# Double of singleton ", _singleton_name, ", base class is Reference")
		elif(is_native()):
			var native = get_native_class_name()
			if(native.begins_with('_')):
				native = native.substr(1)
			extend = str("extends ", native)
		else:
			extend = str("extends '", get_path(), "'")

		if(has_subpath()):
			extend += str('.', get_subpath().replace('/', '.'))

		return extend


	func get_constants_text():
		if(!is_singleton()):
			return ""

		# do not include constants defined in the super class which for
		# singletons stubs is Reference.
		var exclude_constants = Array(ClassDB.class_get_integer_constant_list("Reference"))
		var text = str("# -----\n# ", _singleton_name, " Constants\n# -----\n")
		var constants = ClassDB.class_get_integer_constant_list(_singleton_name)
		for c in constants:
			if(!exclude_constants.has(c)):
				var value = ClassDB.class_get_integer_constant(_singleton_name, c)
				text += str("const ", c, " = ", value, "\n")

		return text

	func get_properties_text():
		if(!is_singleton()):
			return ""

		var text = str("# -----\n# ", _singleton_name, " Properties\n# -----\n")
		var props = ClassDB.class_get_property_list(_singleton_name)
		for prop in props:
			var accessors = {"setter":null, "getter":null}
			var prop_text = str("var ", prop["name"])

			var getter_name = "get_" + prop["name"]
			if(ClassDB.class_has_method(_singleton_name, getter_name)):
				accessors.getter = getter_name
			else:
				getter_name = "is_" + prop["name"]
				if(ClassDB.class_has_method(_singleton_name, getter_name)):
					accessors.getter = getter_name

			var setter_name = "set_" + prop["name"]
			if(ClassDB.class_has_method(_singleton_name, setter_name)):
				accessors.setter = setter_name

			var setget_text = ""
			if(accessors.setter != null and accessors.getter != null):
				setget_text = str("setget ", accessors.setter, ", ", accessors.getter)
			else:
				# never seen this message show up, but it should show up if we
				# get misbehaving singleton.
				_lgr.error(str("Could not find setget methods for property:  ",
					_singleton_name, ".",  prop["name"]))

			text += str(prop_text, " ", setget_text, "\n")

		return text


# ------------------------------------------------------------------------------
# Allows for interacting with a file but only creating a string.  This was done
# to ease the transition from files being created for doubles to loading
# doubles from a string.  This allows the files to be created for debugging
# purposes since reading a file is easier than reading a dumped out string.
# ------------------------------------------------------------------------------
class FileOrString:
	extends File

	var _do_file = false
	var _contents  = ''
	var _path = null

	func open(path, mode):
		_path = path
		if(_do_file):
			return .open(path, mode)
		else:
			return OK

	func close():
		if(_do_file):
			return .close()

	func store_string(s):
		if(_do_file):
			.store_string(s)
		_contents += s

	func get_contents():
		return _contents

	func get_path():
		return _path

	func load_it():
		if(_contents != ''):
			var script = GDScript.new()
			script.set_source_code(get_contents())
			script.reload()
			return script
		else:
			return load(_path)

# ------------------------------------------------------------------------------
# A stroke of genius if I do say so.  This allows for doubling a scene without
# having  to write any files.  By overloading the "instance" method  we can
# make whatever we want.
# ------------------------------------------------------------------------------
class PackedSceneDouble:
	extends PackedScene
	var _script =  null
	var _scene = null

	func set_script_obj(obj):
		_script = obj

	func instance(edit_state=0):
		var inst = _scene.instance(edit_state)
		var export_props = []
		var script_export_flag = (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_SCRIPT_VARIABLE)

		if(_script !=  null):
			if(inst.get_script() != null):
				# Get all the exported props and values so we can set them again
				for prop in inst.get_property_list():
					var is_export = prop.usage & (script_export_flag) == script_export_flag
					if(is_export):
						export_props.append([prop.name, inst.get(prop.name)])

			inst.set_script(_script)
			for exported_value in export_props:
				print('setting ', exported_value)
				inst.set(exported_value[0], exported_value[1])


		# if(_script !=  null):
		# 	inst.set_script(_script)
		return inst

	func load_scene(path):
		_scene = load(path)




# ------------------------------------------------------------------------------
# START Doubler
# ------------------------------------------------------------------------------
var _utils = load('res://addons/gut/utils.gd').get_instance()

var _ignored_methods = _utils.OneToMany.new()
var _stubber = _utils.Stubber.new()
var _lgr = _utils.get_logger()
var _method_maker = _utils.MethodMaker.new()

var _output_dir = 'user://gut_temp_directory'
var _double_count = 0 # used in making files names unique
var _spy = null
var _gut = null
var _strategy = null
var _base_script_text = _utils.get_file_as_text('res://addons/gut/double_templates/script_template.txt')
var _make_files = false
# used by tests for debugging purposes.
var _print_source = false

func _init(strategy=_utils.DOUBLE_STRATEGY.PARTIAL):
	set_logger(_utils.get_logger())
	_strategy = strategy

# ###############
# Private
# ###############
func _get_indented_line(indents, text):
	var to_return = ''
	for _i in range(indents):
		to_return += "\t"
	return str(to_return, text, "\n")


func _stub_to_call_super(obj_info, method_name):
	if(_utils.non_super_methods.has(method_name)):
		return

	var path = obj_info.get_path()
	if(obj_info.is_singleton()):
		path = obj_info.get_singleton_name()
	elif(obj_info.scene_path != null):
		path = obj_info.scene_path

	var params = _utils.StubParams.new(path, method_name, obj_info.get_subpath())
	params.to_call_super()
	_stubber.add_stub(params)


func _get_base_script_text(obj_info, override_path, script_methods):
	var path = obj_info.get_path()
	if(override_path != null):
		path = override_path

	var stubber_id = -1
	if(_stubber != null):
		stubber_id = _stubber.get_instance_id()

	var spy_id = -1
	if(_spy != null):
		spy_id = _spy.get_instance_id()

	var gut_id = -1
	if(_gut != null):
		gut_id = _gut.get_instance_id()

	var values = {
		# Top  sections
		"extends":obj_info.get_extends_text(),
		"constants":obj_info.get_constants_text(),
		"properties":obj_info.get_properties_text(),

		# metadata values
		"path":path,
		"subpath":obj_info.get_subpath(),
		"stubber_id":stubber_id,
		"spy_id":spy_id,
		"gut_id":gut_id,
		"singleton_name":_utils.nvl(obj_info.get_singleton_name(), ''),
		"is_partial":str(obj_info.make_partial_double).to_lower()
	}

	return _base_script_text.format(values)


func _write_file(obj_info, dest_path, override_path=null):
	var script_methods = _get_methods(obj_info)
	var base_script = _get_base_script_text(obj_info, override_path, script_methods)
	var super_name = ""
	var path = ""

	if(obj_info.is_singleton()):
		super_name = obj_info.get_singleton_name()
	else:
		path = obj_info.get_path()

	var f = FileOrString.new()
	f._do_file = _make_files
	var f_result = f.open(dest_path, f.WRITE)

	if(f_result != OK):
		_lgr.error(str('Error creating file ', dest_path))
		_lgr.error(str('Could not create double for :', obj_info.to_s()))
		return

	f.store_string(base_script)

	for i in range(script_methods.local_methods.size()):
		f.store_string(_get_func_text(script_methods.local_methods[i], path, super_name))

	for i in range(script_methods.built_ins.size()):
		_stub_to_call_super(obj_info, script_methods.built_ins[i].name)
		f.store_string(_get_func_text(script_methods.built_ins[i], path, super_name))

	f.close()
	if(_print_source):
		print(f.get_contents())
	return f


func _double_scene_and_script(scene_info):
	var to_return = PackedSceneDouble.new()
	to_return.load_scene(scene_info.get_path())

	var inst = load(scene_info.get_path()).instance()
	var script_path = null
	if(inst.get_script()):
		script_path = inst.get_script().get_path()
	inst.free()

	if(script_path):
		var oi = ObjectInfo.new(script_path)
		oi.set_method_strategy(scene_info.get_method_strategy())
		oi.make_partial_double = scene_info.make_partial_double
		oi.scene_path = scene_info.get_path()
		to_return.set_script_obj(_double(oi, scene_info.get_path()).load_it())

	return to_return


func _get_methods(object_info):
	var obj = object_info.instantiate()
	# any method in the script or super script
	var script_methods = ScriptMethods.new()
	var methods = obj.get_method_list()

	if(!object_info.is_singleton() and !(obj is Reference)):
		obj.free()

	# first pass is for local methods only
	for i in range(methods.size()):
		if(object_info.is_singleton()):
			#print(methods[i].name, " :: ", methods[i].flags, " :: ", methods[i].id)
			#print("    ", methods[i])

			# It appears that the ID for methods upstream from a singleton are
			# below 200.  Initially it was thought that singleton specific methods
			# were above 1000.  This was true for Input but not for OS.  I've
			# changed the condition to be > 200 instead of > 1000.  It will take
			# some investigation to figure out if this is right, but it works
			# for now.  Someone either find an issue and open a bug, or this will
			# just exist like this.  Sorry future me (or someone else).
			if(methods[i].id > 200 and methods[i].flags in [1, 9]):
				script_methods.add_local_method(methods[i])

		# 65 is a magic number for methods in script, though documentation
		# says 64.  This picks up local overloads of base class methods too.
		# See MethodFlags in @GlobalScope
		elif(methods[i].flags == 65 and !_ignored_methods.has(object_info.get_path(), methods[i]['name'])):
			script_methods.add_local_method(methods[i])

	if(object_info.get_method_strategy() == _utils.DOUBLE_STRATEGY.FULL):
		# second pass is for anything not local
		for j in range(methods.size()):
			# 65 is a magic number for methods in script, though documentation
			# says 64.  This picks up local overloads of base class methods too.
			if(methods[j].flags != 65 and !_ignored_methods.has(object_info.get_path(), methods[j]['name'])):
				script_methods.add_built_in_method(methods[j])

	return script_methods


func _get_inst_id_ref_str(inst):
	var ref_str = 'null'
	if(inst):
		ref_str = str('instance_from_id(', inst.get_instance_id(),')')
	return ref_str


func _get_func_text(method_hash, path, super=""):
	var override_count = null;
	if(_stubber != null):
		override_count = _stubber.get_parameter_count(path, method_hash.name)

	var text = _method_maker.get_function_text(method_hash, path, override_count, super) + "\n"

	return text

# returns the path to write the double file to
func _get_temp_path(object_info):
	var file_name = null
	var extension = null

	if(object_info.is_singleton()):
		file_name = str(object_info.get_singleton_instance())
		extension = "gd"
	elif(object_info.is_native()):
		file_name = object_info.get_native_class_name()
		extension = 'gd'
	else:
		file_name = object_info.get_path().get_file().get_basename()
		extension = object_info.get_path().get_extension()

	if(object_info.has_subpath()):
		file_name += '__' + object_info.get_subpath().replace('/', '__')

	file_name += str('__dbl', _double_count, '__.', extension)

	var to_return = _output_dir.plus_file(file_name)
	return to_return


func _double(obj_info, override_path=null):
	var temp_path = _get_temp_path(obj_info)
	var result = _write_file(obj_info, temp_path, override_path)
	_double_count += 1
	return result


func _double_script(path, make_partial, strategy):
	var oi = ObjectInfo.new(path)
	oi.make_partial_double = make_partial
	oi.set_method_strategy(strategy)
	return _double(oi).load_it()


func _double_inner(path, subpath, make_partial, strategy):
	var oi = ObjectInfo.new(path, subpath)
	oi.set_method_strategy(strategy)
	oi.make_partial_double = make_partial
	return _double(oi).load_it()


func _double_scene(path, make_partial, strategy):
	var oi = ObjectInfo.new(path)
	oi.set_method_strategy(strategy)
	oi.make_partial_double = make_partial
	return _double_scene_and_script(oi)


func _double_gdnative(native_class, make_partial, strategy):
	var oi = ObjectInfo.new(null)
	oi.set_native_class(native_class)
	oi.set_method_strategy(strategy)
	oi.make_partial_double = make_partial
	return _double(oi).load_it()


func _double_singleton(singleton_name, make_partial, strategy):
	var oi = ObjectInfo.new(null)
	oi.set_singleton_name(singleton_name)
	oi.set_method_strategy(_utils.DOUBLE_STRATEGY.PARTIAL)
	oi.make_partial_double = make_partial
	return _double(oi).load_it()

# ###############
# Public
# ###############
func get_output_dir():
	return _output_dir


func set_output_dir(output_dir):
	if(output_dir !=  null):
		_output_dir = output_dir
		if(_make_files):
			var d = Directory.new()
			d.make_dir_recursive(output_dir)


func get_spy():
	return _spy


func set_spy(spy):
	_spy = spy


func get_stubber():
	return _stubber


func set_stubber(stubber):
	_stubber = stubber


func get_logger():
	return _lgr


func set_logger(logger):
	_lgr = logger
	_method_maker.set_logger(logger)


func get_strategy():
	return _strategy


func set_strategy(strategy):
	_strategy = strategy


func get_gut():
	return _gut


func set_gut(gut):
	_gut = gut


func partial_double_scene(path, strategy=_strategy):
	return _double_scene(path, true, strategy)


# double a scene
func double_scene(path, strategy=_strategy):
	return _double_scene(path, false, strategy)


# double a script/object
func double(path, strategy=_strategy):
	return _double_script(path, false, strategy)


func partial_double(path, strategy=_strategy):
	return _double_script(path, true, strategy)


func partial_double_inner(path, subpath, strategy=_strategy):
	return _double_inner(path, subpath, true, strategy)


# double an inner class in a script
func double_inner(path, subpath, strategy=_strategy):
	return _double_inner(path, subpath, false, strategy)


# must always use FULL strategy since this is a native class and you won't get
# any methods if you don't use FULL
func double_gdnative(native_class):
	return _double_gdnative(native_class, false, _utils.DOUBLE_STRATEGY.FULL)


# must always use FULL strategy since this is a native class and you won't get
# any methods if you don't use FULL
func partial_double_gdnative(native_class):
	return _double_gdnative(native_class, true, _utils.DOUBLE_STRATEGY.FULL)


func double_singleton(name):
	return _double_singleton(name, false, _utils.DOUBLE_STRATEGY.PARTIAL)


func partial_double_singleton(name):
	return _double_singleton(name, true, _utils.DOUBLE_STRATEGY.PARTIAL)


func clear_output_directory():
	if(!_make_files):
		return false

	var did = false
	if(_output_dir.find('user://') == 0):
		var d = Directory.new()
		var result = d.open(_output_dir)
		# BIG GOTCHA HERE.  If it cannot open the dir w/ erro 31, then the
		# directory becomes res:// and things go on normally and gut clears out
		# out res:// which is SUPER BAD.
		if(result == OK):
			d.list_dir_begin(true)
			var f = d.get_next()
			while(f != ''):
				d.remove(f)
				f = d.get_next()
				did = true
	return did

func delete_output_directory():
	var did = clear_output_directory()
	if(did):
		var d = Directory.new()
		d.remove(_output_dir)


func add_ignored_method(path, method_name):
	_ignored_methods.add(path, method_name)


func get_ignored_methods():
	return _ignored_methods


func get_make_files():
	return _make_files


func set_make_files(make_files):
	_make_files = make_files
	set_output_dir(_output_dir)

func get_method_maker():
	return _method_maker

--- Start of ./addons/gut/get_native_script.gd ---

# Since NativeScript does not exist if GDNative is not included in the build
# of Godot this script is conditionally loaded only when NativeScript exists.
# You can then get a reference to NativeScript for use in `is` checks by calling
# get_it.
static func get_it():
	return NativeScript

--- Start of ./addons/gut/gui/BottomPanelShortcuts.gd ---

tool
extends WindowDialog

onready var _ctrls = {
	run_all = $Layout/CRunAll/ShortcutButton,
	run_current_script = $Layout/CRunCurrentScript/ShortcutButton,
	run_current_inner = $Layout/CRunCurrentInner/ShortcutButton,
	run_current_test = $Layout/CRunCurrentTest/ShortcutButton,
	panel_button = $Layout/CPanelButton/ShortcutButton,
}

func _ready():
	for key in _ctrls:
		var sc_button = _ctrls[key]
		sc_button.connect('start_edit', self, '_on_edit_start', [sc_button])
		sc_button.connect('end_edit', self, '_on_edit_end')


	# show dialog when running scene from editor.
	if(get_parent() == get_tree().root):
		popup_centered()

# ------------
# Events
# ------------
func _on_Hide_pressed():
	hide()

func _on_edit_start(which):
	for key in _ctrls:
		var sc_button = _ctrls[key]
		if(sc_button != which):
			sc_button.disable_set(true)
			sc_button.disable_clear(true)

func _on_edit_end():
	for key in _ctrls:
		var sc_button = _ctrls[key]
		sc_button.disable_set(false)
		sc_button.disable_clear(false)

# ------------
# Public
# ------------
func get_run_all():
	return _ctrls.run_all.get_shortcut()

func get_run_current_script():
	return _ctrls.run_current_script.get_shortcut()

func get_run_current_inner():
	return _ctrls.run_current_inner.get_shortcut()

func get_run_current_test():
	return _ctrls.run_current_test.get_shortcut()

func get_panel_button():
	return _ctrls.panel_button.get_shortcut()


func save_shortcuts(path):
	var f = ConfigFile.new()

	f.set_value('main', 'run_all', _ctrls.run_all.get_shortcut())
	f.set_value('main', 'run_current_script', _ctrls.run_current_script.get_shortcut())
	f.set_value('main', 'run_current_inner', _ctrls.run_current_inner.get_shortcut())
	f.set_value('main', 'run_current_test', _ctrls.run_current_test.get_shortcut())
	f.set_value('main', 'panel_button', _ctrls.panel_button.get_shortcut())

	f.save(path)


func load_shortcuts(path):
	var emptyShortcut = ShortCut.new()
	var f = ConfigFile.new()
	f.load(path)

	_ctrls.run_all.set_shortcut(f.get_value('main', 'run_all', emptyShortcut))
	_ctrls.run_current_script.set_shortcut(f.get_value('main', 'run_current_script', emptyShortcut))
	_ctrls.run_current_inner.set_shortcut(f.get_value('main', 'run_current_inner', emptyShortcut))
	_ctrls.run_current_test.set_shortcut(f.get_value('main', 'run_current_test', emptyShortcut))
	_ctrls.panel_button.set_shortcut(f.get_value('main', 'panel_button', emptyShortcut))

--- Start of ./addons/gut/gui/GutBottomPanel.gd ---

tool
extends Control

const RUNNER_JSON_PATH = 'res://.gut_editor_config.json'
const RESULT_FILE = 'user://.gut_editor.bbcode'
const RESULT_JSON = 'user://.gut_editor.json'
const SHORTCUTS_PATH = 'res://.gut_editor_shortcuts.cfg'

var TestScript = load('res://addons/gut/test.gd')
var GutConfigGui = load('res://addons/gut/gui/gut_config_gui.gd')
var ScriptTextEditors = load('res://addons/gut/gui/script_text_editor_controls.gd')

var _interface = null;
var _is_running = false;
var _gut_config = load('res://addons/gut/gut_config.gd').new()
var _gut_config_gui = null
var _gut_plugin = null
var _light_color = Color(0, 0, 0, .5)
var _panel_button = null
var _last_selected_path = null


onready var _ctrls = {
	output = $layout/RSplit/CResults/Tabs/OutputText.get_rich_text_edit(),
	output_ctrl = $layout/RSplit/CResults/Tabs/OutputText,
	run_button = $layout/ControlBar/RunAll,
	shortcuts_button = $layout/ControlBar/Shortcuts,

	settings_button = $layout/ControlBar/Settings,
	run_results_button = $layout/ControlBar/RunResultsBtn,
	output_button = $layout/ControlBar/OutputBtn,

	settings = $layout/RSplit/sc/Settings,
	shortcut_dialog = $BottomPanelShortcuts,
	light = $layout/RSplit/CResults/ControlBar/Light,
	results = {
		bar = $layout/RSplit/CResults/ControlBar,
		passing = $layout/RSplit/CResults/ControlBar/Passing/value,
		failing = $layout/RSplit/CResults/ControlBar/Failing/value,
		pending = $layout/RSplit/CResults/ControlBar/Pending/value,
		errors = $layout/RSplit/CResults/ControlBar/Errors/value,
		warnings = $layout/RSplit/CResults/ControlBar/Warnings/value,
		orphans = $layout/RSplit/CResults/ControlBar/Orphans/value
	},
	run_at_cursor = $layout/ControlBar/RunAtCursor,
	run_results = $layout/RSplit/CResults/Tabs/RunResults
}


func _init():
	_gut_config.load_panel_options(RUNNER_JSON_PATH)


func _ready():
	_ctrls.results.bar.connect('draw', self, '_on_results_bar_draw', [_ctrls.results.bar])
	hide_settings(!_ctrls.settings_button.pressed)
	_gut_config_gui = GutConfigGui.new(_ctrls.settings)
	_gut_config_gui.set_options(_gut_config.options)

	_apply_options_to_controls()

	_ctrls.shortcuts_button.icon = get_icon('ShortCut', 'EditorIcons')
	_ctrls.settings_button.icon = get_icon('Tools', 'EditorIcons')
	_ctrls.run_results_button.icon = get_icon('AnimationTrackGroup', 'EditorIcons') # Tree
	_ctrls.output_button.icon = get_icon('Font', 'EditorIcons')

	_ctrls.run_results.set_output_control(_ctrls.output_ctrl)
	_ctrls.run_results.set_font(
		_gut_config.options.panel_options.font_name,
		_gut_config.options.panel_options.font_size)

	var check_import = load('res://addons/gut/images/red.png')
	if(check_import == null):
		_ctrls.run_results.add_centered_text("GUT got some new images that are not imported yet.  Please restart Godot.")
		print('GUT got some new images that are not imported yet.  Please restart Godot.')
	else:
		_ctrls.run_results.add_centered_text("Let's run some tests!")


func _apply_options_to_controls():
	hide_settings(_gut_config.options.panel_options.hide_settings)
	hide_result_tree(_gut_config.options.panel_options.hide_result_tree)
	hide_output_text(_gut_config.options.panel_options.hide_output_text)

	_ctrls.output_ctrl.set_use_colors(_gut_config.options.panel_options.use_colors)
	_ctrls.output_ctrl.set_all_fonts(_gut_config.options.panel_options.font_name)
	_ctrls.output_ctrl.set_font_size(_gut_config.options.panel_options.font_size)

	_ctrls.run_results.set_font(
		_gut_config.options.panel_options.font_name,
		_gut_config.options.panel_options.font_size)
	_ctrls.run_results.set_show_orphans(!_gut_config.options.hide_orphans)


func _process(delta):
	if(_is_running):
		if(!_interface.is_playing_scene()):
			_is_running = false
			_ctrls.output_ctrl.add_text("\ndone")
			load_result_output()
			_gut_plugin.make_bottom_panel_item_visible(self)

# ---------------
# Private
# ---------------

func load_shortcuts():
	_ctrls.shortcut_dialog.load_shortcuts(SHORTCUTS_PATH)
	_apply_shortcuts()


func _is_test_script(script):
	var from = script.get_base_script()
	while(from and from.resource_path != 'res://addons/gut/test.gd'):
		from = from.get_base_script()

	return from != null


func _show_errors(errs):
	_ctrls.output_ctrl.clear()
	var text = "Cannot run tests, you have a configuration error:\n"
	for e in errs:
		text += str('*  ', e, "\n")
	text += "Check your settings ----->"
	_ctrls.output_ctrl.add_text(text)
	hide_output_text(false)
	hide_settings(false)


func _save_config():
	_gut_config.options = _gut_config_gui.get_options(_gut_config.options)
	_gut_config.options.panel_options.hide_settings = !_ctrls.settings_button.pressed
	_gut_config.options.panel_options.hide_result_tree = !_ctrls.run_results_button.pressed
	_gut_config.options.panel_options.hide_output_text = !_ctrls.output_button.pressed
	_gut_config.options.panel_options.use_colors = _ctrls.output_ctrl.get_use_colors()

	var w_result = _gut_config.write_options(RUNNER_JSON_PATH)
	if(w_result != OK):
		push_error(str('Could not write options to ', RUNNER_JSON_PATH, ': ', w_result))
		return;


func _run_tests():
	var issues = _gut_config_gui.get_config_issues()
	if(issues.size() > 0):
		_show_errors(issues)
		return

	write_file(RESULT_FILE, 'Run in progress')
	_save_config()
	_apply_options_to_controls()

	_ctrls.output_ctrl.clear()
	_ctrls.run_results.clear()
	_ctrls.run_results.add_centered_text('Running...')

	_interface.play_custom_scene('res://addons/gut/gui/GutRunner.tscn')
	_is_running = true
	_ctrls.output_ctrl.add_text('Running...')


func _apply_shortcuts():
	_ctrls.run_button.shortcut = _ctrls.shortcut_dialog.get_run_all()

	_ctrls.run_at_cursor.get_script_button().shortcut = \
		_ctrls.shortcut_dialog.get_run_current_script()
	_ctrls.run_at_cursor.get_inner_button().shortcut = \
		_ctrls.shortcut_dialog.get_run_current_inner()
	_ctrls.run_at_cursor.get_test_button().shortcut = \
		_ctrls.shortcut_dialog.get_run_current_test()

	_panel_button.shortcut = _ctrls.shortcut_dialog.get_panel_button()


func _run_all():
	_gut_config.options.selected = null
	_gut_config.options.inner_class = null
	_gut_config.options.unit_test_name = null

	_run_tests()


# ---------------
# Events
# ---------------
func _on_results_bar_draw(bar):
	bar.draw_rect(Rect2(Vector2(0, 0), bar.rect_size), Color(0, 0, 0, .2))


func _on_Light_draw():
	var l = _ctrls.light
	l.draw_circle(Vector2(l.rect_size.x / 2, l.rect_size.y / 2), l.rect_size.x / 2, _light_color)


func _on_editor_script_changed(script):
	if(script):
		set_current_script(script)


func _on_RunAll_pressed():
	_run_all()


func _on_Shortcuts_pressed():
	_ctrls.shortcut_dialog.popup_centered()


func _on_BottomPanelShortcuts_popup_hide():
	_apply_shortcuts()
	_ctrls.shortcut_dialog.save_shortcuts(SHORTCUTS_PATH)


func _on_RunAtCursor_run_tests(what):
	_gut_config.options.selected = what.script
	_gut_config.options.inner_class = what.inner_class
	_gut_config.options.unit_test_name = what.test_method

	_run_tests()


func _on_Settings_pressed():
	hide_settings(!_ctrls.settings_button.pressed)
	_save_config()


func _on_OutputBtn_pressed():
	hide_output_text(!_ctrls.output_button.pressed)
	_save_config()


func _on_RunResultsBtn_pressed():
	hide_result_tree(! _ctrls.run_results_button.pressed)
	_save_config()


# Currently not used, but will be when I figure out how to put
# colors into the text results
func _on_UseColors_pressed():
	pass

# ---------------
# Public
# ---------------
func hide_result_tree(should):
	_ctrls.run_results.visible = !should
	_ctrls.run_results_button.pressed = !should


func hide_settings(should):
	var s_scroll = _ctrls.settings.get_parent()
	s_scroll.visible = !should

	# collapse only collapses the first control, so we move
	# settings around to be the collapsed one
	if(should):
		s_scroll.get_parent().move_child(s_scroll, 0)
	else:
		s_scroll.get_parent().move_child(s_scroll, 1)

	$layout/RSplit.collapsed = should
	_ctrls.settings_button.pressed = !should


func hide_output_text(should):
	$layout/RSplit/CResults/Tabs/OutputText.visible = !should
	_ctrls.output_button.pressed = !should


func load_result_output():
	_ctrls.output_ctrl.load_file(RESULT_FILE)

	var summary = get_file_as_text(RESULT_JSON)
	var results = JSON.parse(summary)
	if(results.error != OK):
		return

	_ctrls.run_results.load_json_results(results.result)

	var summary_json = results.result['test_scripts']['props']
	_ctrls.results.passing.text = str(summary_json.passing)
	_ctrls.results.passing.get_parent().visible = true

	_ctrls.results.failing.text = str(summary_json.failures)
	_ctrls.results.failing.get_parent().visible = true

	_ctrls.results.pending.text = str(summary_json.pending)
	_ctrls.results.pending.get_parent().visible = _ctrls.results.pending.text != '0'

	_ctrls.results.errors.text = str(summary_json.errors)
	_ctrls.results.errors.get_parent().visible = _ctrls.results.errors.text != '0'

	_ctrls.results.warnings.text = str(summary_json.warnings)
	_ctrls.results.warnings.get_parent().visible = _ctrls.results.warnings.text != '0'

	_ctrls.results.orphans.text = str(summary_json.orphans)
	_ctrls.results.orphans.get_parent().visible = _ctrls.results.orphans.text != '0' and !_gut_config.options.hide_orphans

	if(summary_json.tests == 0):
		_light_color = Color(1, 0, 0, .75)
	elif(summary_json.failures != 0):
		_light_color = Color(1, 0, 0, .75)
	elif(summary_json.pending != 0):
		_light_color = Color(1, 1, 0, .75)
	else:
		_light_color = Color(0, 1, 0, .75)
	_ctrls.light.visible = true
	_ctrls.light.update()


func set_current_script(script):
	if(script):
		if(_is_test_script(script)):
			var file = script.resource_path.get_file()
			_last_selected_path = script.resource_path.get_file()
			_ctrls.run_at_cursor.activate_for_script(script.resource_path)


func set_interface(value):
	_interface = value
	_interface.get_script_editor().connect("editor_script_changed", self, '_on_editor_script_changed')

	var ste = ScriptTextEditors.new(_interface.get_script_editor())
	_ctrls.run_results.set_interface(_interface)
	_ctrls.run_results.set_script_text_editors(ste)
	_ctrls.run_at_cursor.set_script_text_editors(ste)
	set_current_script(_interface.get_script_editor().get_current_script())


func set_plugin(value):
	_gut_plugin = value


func set_panel_button(value):
	_panel_button = value

# ------------------------------------------------------------------------------
# Write a file.
# ------------------------------------------------------------------------------
func write_file(path, content):
	var f = File.new()
	var result = f.open(path, f.WRITE)
	if(result == OK):
		f.store_string(content)
		f.close()
	return result


# ------------------------------------------------------------------------------
# Returns the text of a file or an empty string if the file could not be opened.
# ------------------------------------------------------------------------------
func get_file_as_text(path):
	var to_return = ''
	var f = File.new()
	var result = f.open(path, f.READ)
	if(result == OK):
		to_return = f.get_as_text()
		f.close()
	return to_return


# ------------------------------------------------------------------------------
# return if_null if value is null otherwise return value
# ------------------------------------------------------------------------------
func nvl(value, if_null):
	if(value == null):
		return if_null
	else:
		return value

--- Start of ./addons/gut/gui/gut_config_gui.gd ---

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
class DirectoryCtrl:
	extends HBoxContainer

	var text = '' setget set_text, get_text
	var _txt_path = LineEdit.new()
	var _btn_dir = Button.new()
	var _dialog = FileDialog.new()

	func _init():
		_btn_dir.text = '...'
		_btn_dir.connect('pressed', self, '_on_dir_button_pressed')

		_txt_path.size_flags_horizontal = _txt_path.SIZE_EXPAND_FILL

		_dialog.mode = _dialog.MODE_OPEN_DIR
		_dialog.resizable = true
		_dialog.connect("dir_selected", self, '_on_selected')
		_dialog.connect("file_selected", self, '_on_selected')
		_dialog.rect_size = Vector2(1000, 700)

	func _on_selected(path):
		set_text(path)


	func _on_dir_button_pressed():
		_dialog.current_dir = _txt_path.text
		_dialog.popup_centered()


	func _ready():
		add_child(_txt_path)
		add_child(_btn_dir)
		add_child(_dialog)

	func get_text():
		return _txt_path.text

	func set_text(t):
		text = t
		_txt_path.text = text

	func get_line_edit():
		return _txt_path

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
class FileCtrl:
	extends DirectoryCtrl

	func _init():
		_dialog.mode = _dialog.MODE_OPEN_FILE

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
class Vector2Ctrl:
	extends VBoxContainer

	var value = Vector2(-1, -1) setget set_value, get_value
	var disabled = false setget set_disabled, get_disabled
	var x_spin = SpinBox.new()
	var y_spin = SpinBox.new()

	func _init():
		add_child(_make_one('x:  ', x_spin))
		add_child(_make_one('y:  ', y_spin))

	func _make_one(txt, spinner):
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = txt
		hbox.add_child(lbl)
		hbox.add_child(spinner)
		spinner.min_value = -1
		spinner.max_value = 10000
		spinner.size_flags_horizontal = spinner.SIZE_EXPAND_FILL
		return hbox

	func set_value(v):
		if(v != null):
			x_spin.value = v[0]
			y_spin.value = v[1]

	# Returns array instead of vector2 b/c that is what is stored in
	# in the dictionary and what is expected everywhere else.
	func get_value():
		return [x_spin.value, y_spin.value]

	func set_disabled(should):
		get_parent().visible = !should
		x_spin.visible = !should
		y_spin.visible = !should

	func get_disabled():
		pass



# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
var _base_container = null
var _base_control = null
const DIRS_TO_LIST = 6
var _cfg_ctrls = {}
var _avail_fonts = ['AnonymousPro', 'CourierPrime', 'LobsterTwo', 'Default']


func _init(cont):
	_base_container = cont

	_base_control = HBoxContainer.new()
	_base_control.size_flags_horizontal = _base_control.SIZE_EXPAND_FILL
	_base_control.mouse_filter = _base_control.MOUSE_FILTER_PASS

	# I don't remember what this is all about at all.  Could be
	# garbage.  Decided to spend more time typing this message
	# than figuring it out.
	var lbl = Label.new()
	lbl.size_flags_horizontal = lbl.SIZE_EXPAND_FILL
	lbl.mouse_filter = lbl.MOUSE_FILTER_STOP
	_base_control.add_child(lbl)


# ------------------
# Private
# ------------------
func _new_row(key, disp_text, value_ctrl, hint):
	var ctrl = _base_control.duplicate()
	var lbl = ctrl.get_node("Label")

	lbl.hint_tooltip = hint
	lbl.text = disp_text
	_base_container.add_child(ctrl)

	_cfg_ctrls[key] = value_ctrl
	ctrl.add_child(value_ctrl)

	var rpad = CenterContainer.new()
	rpad.rect_min_size.x = 5
	ctrl.add_child(rpad)

	return ctrl


func _add_title(text):
	var row = _base_control.duplicate()
	var lbl = row.get_node('Label')

	lbl.text = text
	lbl.align = Label.ALIGN_CENTER
	_base_container.add_child(row)

	row.connect('draw', self, '_on_title_cell_draw', [row])


func _add_number(key, value, disp_text, v_min, v_max, hint=''):
	var value_ctrl = SpinBox.new()
	value_ctrl.value = value
	value_ctrl.size_flags_horizontal = value_ctrl.SIZE_EXPAND_FILL
	value_ctrl.min_value = v_min
	value_ctrl.max_value = v_max
	_wire_select_on_focus(value_ctrl.get_line_edit())

	_new_row(key, disp_text, value_ctrl, hint)


func _add_select(key, value, values, disp_text, hint=''):
	var value_ctrl = OptionButton.new()
	var select_idx = 0
	for i in range(values.size()):
		value_ctrl.add_item(values[i])
		if(value == values[i]):
			select_idx = i
	value_ctrl.selected = select_idx
	value_ctrl.size_flags_horizontal = value_ctrl.SIZE_EXPAND_FILL

	_new_row(key, disp_text, value_ctrl, hint)


func _add_value(key, value, disp_text, hint=''):
	var value_ctrl = LineEdit.new()
	value_ctrl.size_flags_horizontal = value_ctrl.SIZE_EXPAND_FILL
	value_ctrl.text = value
	_wire_select_on_focus(value_ctrl)

	_new_row(key, disp_text, value_ctrl, hint)


func _add_boolean(key, value, disp_text, hint=''):
	var value_ctrl = CheckBox.new()
	value_ctrl.pressed = value

	_new_row(key, disp_text, value_ctrl, hint)


func _add_directory(key, value, disp_text, hint=''):
	var value_ctrl = DirectoryCtrl.new()
	value_ctrl.size_flags_horizontal = value_ctrl.SIZE_EXPAND_FILL
	value_ctrl.text = value
	_wire_select_on_focus(value_ctrl.get_line_edit())

	_new_row(key, disp_text, value_ctrl, hint)


func _add_file(key, value, disp_text, hint=''):
	var value_ctrl = FileCtrl.new()
	value_ctrl.size_flags_horizontal = value_ctrl.SIZE_EXPAND_FILL
	value_ctrl.text = value
	_wire_select_on_focus(value_ctrl.get_line_edit())

	_new_row(key, disp_text, value_ctrl, hint)


func _add_color(key, value, disp_text, hint=''):
	var value_ctrl = ColorPickerButton.new()
	value_ctrl.size_flags_horizontal = value_ctrl.SIZE_EXPAND_FILL
	value_ctrl.color = value

	_new_row(key, disp_text, value_ctrl, hint)


func _add_vector2(key, value, disp_text, hint=''):
	var value_ctrl = Vector2Ctrl.new()
	value_ctrl.size_flags_horizontal = value_ctrl.SIZE_EXPAND_FILL
	value_ctrl.value = value
	_wire_select_on_focus(value_ctrl.x_spin.get_line_edit())
	_wire_select_on_focus(value_ctrl.y_spin.get_line_edit())

	_new_row(key, disp_text, value_ctrl, hint)
# -----------------------------


# ------------------
# Events
# ------------------
func _wire_select_on_focus(which):
	which.connect('focus_entered', self, '_on_ctrl_focus_highlight', [which])
	which.connect('focus_exited', self, '_on_ctrl_focus_unhighlight', [which])


func _on_ctrl_focus_highlight(which):
	if(which.has_method('select_all')):
		which.call_deferred('select_all')


func _on_ctrl_focus_unhighlight(which):
	if(which.has_method('select')):
		which.select(0, 0)


func _on_title_cell_draw(which):
	which.draw_rect(Rect2(Vector2(0, 0), which.rect_size), Color(0, 0, 0, .15))


# ------------------
# Public
# ------------------
func get_config_issues():
	var to_return = []
	var has_directory = false
	var dir = Directory.new()

	for i in range(DIRS_TO_LIST):
		var key = str('directory_', i)
		var path = _cfg_ctrls[key].text
		if(path != null and path != ''):
			has_directory = true
			if(!dir.dir_exists(path)):
				to_return.append(str('Test directory ', path, ' does not exist.'))

	if(!has_directory):
		to_return.append('You do not have any directories set.')

	if(!_cfg_ctrls['suffix'].text.ends_with('.gd')):
		to_return.append("Script suffix must end in '.gd'")

	return to_return


func set_options(options):
	_add_title("Settings")
	_add_number("log_level", options.log_level, "Log Level", 0, 3,
		"Detail level for log messages.\n" + \
		"\t0: Errors and failures only.\n" + \
		"\t1: Adds all test names + warnings + info\n" + \
		"\t2: Shows all asserts\n" + \
		"\t3: Adds more stuff probably, maybe not.")
	_add_boolean('ignore_pause', options.ignore_pause, 'Ignore Pause',
		"Ignore calls to pause_before_teardown")
	_add_boolean('hide_orphans', options.hide_orphans, 'Hide Orphans',
		'Do not display orphan counts in output.')
	_add_boolean('should_exit', options.should_exit, 'Exit on Finish',
		"Exit when tests finished.")
	_add_boolean('should_exit_on_success', options.should_exit_on_success, 'Exit on Success',
		"Exit if there are no failures.  Does nothing if 'Exit on Finish' is enabled.")


	_add_title("Panel Output")
	_add_select('output_font_name', options.panel_options.font_name, _avail_fonts, 'Font',
		"The name of the font to use when running tests and in the output panel to the left.")
	_add_number('output_font_size', options.panel_options.font_size, 'Font Size', 5, 100,
		"The font size to use when running tests and in the output panel to the left.")


	_add_title('Runner Window')
	_add_boolean("gut_on_top", options.gut_on_top, "On Top",
		"The GUT Runner appears above children added during tests.")
	_add_number('opacity', options.opacity, 'Opacity', 0, 100,
		"The opacity of GUT when tests are running.")
	_add_boolean('should_maximize', options.should_maximize, 'Maximize',
		"Maximize GUT when tests are being run.")
	_add_boolean('compact_mode', options.compact_mode, 'Compact Mode',
		'The runner will be in compact mode.  This overrides Maximize.')

	_add_title('Runner Appearance')
	_add_select('font_name', options.font_name, _avail_fonts, 'Font',
		"The font to use for text output in the Gut Runner.")
	_add_number('font_size', options.font_size, 'Font Size', 5, 100,
		"The font size for text output in the Gut Runner.")
	_add_color('font_color', options.font_color, 'Font Color',
		"The font color for text output in the Gut Runner.")
	_add_color('background_color', options.background_color, 'Background Color',
		"The background color for text output in the Gut Runner.")
	_add_boolean('disable_colors', options.disable_colors, 'Disable Formatting',
		'Disable formatting and colors used in the Runner.  Does not affect panel output.')

	_add_title('Test Directories')
	_add_boolean('include_subdirs', options.include_subdirs, 'Include Subdirs',
		"Include subdirectories of the directories configured below.")
	for i in range(DIRS_TO_LIST):
		var value = ''
		if(options.dirs.size() > i):
			value = options.dirs[i]

		_add_directory(str('directory_', i), value, str('Directory ', i))

	_add_title("XML Output")
	_add_value("junit_xml_file", options.junit_xml_file, "Output Path",
		"Path and filename where GUT should create a JUnit compliant XML file.  " +
		"This file will contain the results of the last test run.  To avoid " +
		"overriding the file use Include Timestamp.")
	_add_boolean("junit_xml_timestamp", options.junit_xml_timestamp, "Include Timestamp",
		"Include a timestamp in the filename so that each run gets its own xml file.")


	_add_title('Hooks')
	_add_file('pre_run_script', options.pre_run_script, 'Pre-Run Hook',
		'This script will be run by GUT before any tests are run.')
	_add_file('post_run_script', options.post_run_script, 'Post-Run Hook',
		'This script will be run by GUT after all tests are run.')


	_add_title('Misc')
	_add_value('prefix', options.prefix, 'Script Prefix',
		"The filename prefix for all test scripts.")
	_add_value('suffix', options.suffix, 'Script Suffix',
		"Script suffix, including .gd extension.  For example '_foo.gd'.")


func get_options(base_opts):
	var to_return = base_opts.duplicate()

	# Settings
	to_return.log_level = _cfg_ctrls.log_level.value
	to_return.ignore_pause = _cfg_ctrls.ignore_pause.pressed
	to_return.hide_orphans = _cfg_ctrls.hide_orphans.pressed
	to_return.should_exit = _cfg_ctrls.should_exit.pressed
	to_return.should_exit_on_success = _cfg_ctrls.should_exit_on_success.pressed

	#Output
	to_return.panel_options.output_font_name = _cfg_ctrls.output_font_name.get_item_text(
		_cfg_ctrls.output_font_name.selected)
	to_return.panel_options.output_font_size = _cfg_ctrls.output_font_size.value

	# Runner Appearance
	to_return.font_name = _cfg_ctrls.font_name.get_item_text(
		_cfg_ctrls.font_name.selected)
	to_return.font_size = _cfg_ctrls.font_size.value
	to_return.should_maximize = _cfg_ctrls.should_maximize.pressed
	to_return.compact_mode = _cfg_ctrls.compact_mode.pressed
	to_return.opacity = _cfg_ctrls.opacity.value
	to_return.background_color = _cfg_ctrls.background_color.color.to_html()
	to_return.font_color = _cfg_ctrls.font_color.color.to_html()
	to_return.disable_colors = _cfg_ctrls.disable_colors.pressed
	to_return.gut_on_top = _cfg_ctrls.gut_on_top.pressed


	# Directories
	to_return.include_subdirs = _cfg_ctrls.include_subdirs.pressed
	var dirs = []
	for i in range(DIRS_TO_LIST):
		var key = str('directory_', i)
		var val = _cfg_ctrls[key].text
		if(val != '' and val != null):
			dirs.append(val)
	to_return.dirs = dirs

	# XML Output
	to_return.junit_xml_file = _cfg_ctrls.junit_xml_file.text
	to_return.junit_xml_timestamp = _cfg_ctrls.junit_xml_timestamp.pressed

	# Hooks
	to_return.pre_run_script = _cfg_ctrls.pre_run_script.text
	to_return.post_run_script = _cfg_ctrls.post_run_script.text

	# Misc
	to_return.prefix = _cfg_ctrls.prefix.text
	to_return.suffix = _cfg_ctrls.suffix.text

	return to_return

--- Start of ./addons/gut/gui/GutRunner.gd ---

extends Node2D

var Gut = load('res://addons/gut/gut.gd')
var ResultExporter = load('res://addons/gut/result_exporter.gd')
var GutConfig = load('res://addons/gut/gut_config.gd')

const RUNNER_JSON_PATH = 'res://.gut_editor_config.json'
const RESULT_FILE = 'user://.gut_editor.bbcode'
const RESULT_JSON = 'user://.gut_editor.json'

var _gut_config = null
var _gut = null;
var _wrote_results = false
# Flag for when this is being used at the command line.  Otherwise it is
# assumed this is being used by the panel and being launched with
# play_custom_scene
var _cmdln_mode = false

onready var _gut_layer = $GutLayer


func _ready():
	if(_gut_config == null):
		_gut_config = GutConfig.new()
		_gut_config.load_panel_options(RUNNER_JSON_PATH)

	# The command line will call run_tests on its own.  When used from the panel
	# we have to kick off the tests ourselves b/c there's no way I know of to
	# interact with the scene that was run via play_custom_scene.
	if(!_cmdln_mode):
		call_deferred('run_tests')


func run_tests():
	if(_gut == null):
		_gut = Gut.new()

	_gut.set_add_children_to(self)
	if(_gut_config.options.gut_on_top):
		_gut_layer.add_child(_gut)
	else:
		add_child(_gut)

	if(!_cmdln_mode):
		_gut.connect('tests_finished', self, '_on_tests_finished',
			[_gut_config.options.should_exit, _gut_config.options.should_exit_on_success])

	_gut_config.config_gut(_gut)
	if(_gut_config.options.gut_on_top):
		_gut.get_gui().goto_bottom_right_corner()

	var run_rest_of_scripts = _gut_config.options.unit_test_name == ''
	_gut.test_scripts(run_rest_of_scripts)


func _write_results():
	var content = _gut.get_logger().get_gui_bbcode()

	var f = File.new()
	var result = f.open(RESULT_FILE, f.WRITE)
	if(result == OK):
		f.store_string(content)
		f.close()
	else:
		print('ERROR Could not save bbcode, result = ', result)

	var exporter = ResultExporter.new()
	var f_result = exporter.write_json_file(_gut, RESULT_JSON)
	_wrote_results = true


func _exit_tree():
	if(!_wrote_results and !_cmdln_mode):
		_write_results()


func _on_tests_finished(should_exit, should_exit_on_success):
	_write_results()

	if(should_exit):
		get_tree().quit()
	elif(should_exit_on_success and _gut.get_fail_count() == 0):
		get_tree().quit()


func get_gut():
	if(_gut == null):
		_gut = Gut.new()
	return _gut

func set_gut_config(which):
	_gut_config = which

func set_cmdln_mode(is_it):
	_cmdln_mode = is_it

--- Start of ./addons/gut/gui/OutputText.gd ---

extends VBoxContainer
tool

class SearchResults:
	const L = TextEdit.SEARCH_RESULT_LINE
	const C = TextEdit.SEARCH_RESULT_COLUMN

	var positions = []
	var te = null
	var _last_term = ''

	func _search_te(text, start_position, flags=0):
		var start_pos = start_position
		if(start_pos[L] < 0 or start_pos[L] > te.get_line_count()):
			start_pos[L] = 0
		if(start_pos[C] < 0):
			start_pos[L] = 0

		var result = te.search(text, flags, start_pos[L], start_pos[C])
		if(result.size() == 2 and result[L] == start_position[L] and
			result[C] == start_position[C] and text == _last_term):
			if(flags == TextEdit.SEARCH_BACKWARDS):
				result[C] -= 1
			else:
				result[C] += 1
			result = _search_te(text, result, flags)
		elif(result.size() == 2):
			te.scroll_vertical = result[L]
			te.select(result[L], result[C], result[L], result[C] + text.length())
			te.cursor_set_column(result[C])
			te.cursor_set_line(result[L])
			te.center_viewport_to_cursor()

		_last_term = text
		te.center_viewport_to_cursor()
		return result

	func _cursor_to_pos():
		var to_return = [0, 0]
		to_return[L] = te.cursor_get_line()
		to_return[C] = te.cursor_get_column()
		return to_return

	func find_next(term):
		return _search_te(term, _cursor_to_pos())

	func find_prev(term):
		var new_pos = _search_te(term, _cursor_to_pos(), TextEdit.SEARCH_BACKWARDS)
		return new_pos

	func get_next_pos():
		pass

	func get_prev_pos():
		pass

	func clear():
		pass

	func find_all(text):
		var c_pos = [0, 0]
		var found = true
		var last_pos = [0, 0]
		positions.clear()

		while(found):
			c_pos = te.search(text, 0, c_pos[L], c_pos[C])

			if(c_pos.size() > 0 and
				(c_pos[L] > last_pos[L] or
					(c_pos[L] == last_pos[L] and c_pos[C] > last_pos[C]))):
				positions.append([c_pos[L], c_pos[C]])
				c_pos[C] += 1
				last_pos = c_pos
			else:
				found = false



onready var _ctrls = {
	output = $Output,

	copy_button = $Toolbar/CopyButton,
	use_colors = $Toolbar/UseColors,
	clear_button = $Toolbar/ClearButton,
	word_wrap = $Toolbar/WordWrap,
	show_search = $Toolbar/ShowSearch,

	search_bar = {
		bar = $Search,
		search_term = $Search/SearchTerm,
	}
}
var _sr = SearchResults.new()

func _test_running_setup():
	_ctrls.use_colors.text = 'use colors'
	_ctrls.show_search.text = 'search'
	_ctrls.word_wrap.text = 'ww'

	set_all_fonts("CourierPrime")
	set_font_size(20)

	load_file('user://.gut_editor.bbcode')


func _ready():
	_sr.te = _ctrls.output
	_ctrls.use_colors.icon = get_icon('RichTextEffect', 'EditorIcons')
	_ctrls.show_search.icon = get_icon('Search', 'EditorIcons')
	_ctrls.word_wrap.icon = get_icon('Loop', 'EditorIcons')

	_setup_colors()
	if(get_parent() == get_tree().root):
		_test_running_setup()


# ------------------
# Private
# ------------------
func _setup_colors():
	_ctrls.output.clear_colors()
	var keywords = [
		['Failed', Color.red],
		['Passed', Color.green],
		['Pending', Color.yellow],
		['Orphans', Color.yellow],
		['WARNING', Color.yellow],
		['ERROR', Color.red]
	]

	for keyword in keywords:
		_ctrls.output.add_keyword_color(keyword[0], keyword[1])

	var f_color = _ctrls.output.get_color("font_color")
	_ctrls.output.add_color_override("font_color_readonly", f_color)
	_ctrls.output.add_color_override("function_color", f_color)
	_ctrls.output.add_color_override("member_variable_color", f_color)
	_ctrls.output.update()


func _set_font(font_name, custom_name):
	var rtl = _ctrls.output
	if(font_name == null):
		rtl.set('custom_fonts/' + custom_name, null)
	else:
		var dyn_font = DynamicFont.new()
		var font_data = DynamicFontData.new()
		font_data.font_path = 'res://addons/gut/fonts/' + font_name + '.ttf'
		font_data.antialiased = true
		dyn_font.font_data = font_data
		rtl.set('custom_fonts/' + custom_name, dyn_font)


# ------------------
# Events
# ------------------
func _on_CopyButton_pressed():
	copy_to_clipboard()


func _on_UseColors_pressed():
	_ctrls.output.syntax_highlighting = _ctrls.use_colors.pressed


func _on_ClearButton_pressed():
	clear()


func _on_ShowSearch_pressed():
	show_search(_ctrls.show_search.pressed)


func _on_SearchTerm_focus_entered():
	_ctrls.search_bar.search_term.call_deferred('select_all')

func _on_SearchNext_pressed():
	_sr.find_next(_ctrls.search_bar.search_term.text)


func _on_SearchPrev_pressed():
	_sr.find_prev(_ctrls.search_bar.search_term.text)


func _on_SearchTerm_text_changed(new_text):
	if(new_text == ''):
		_ctrls.output.deselect()
	else:
		_sr.find_next(new_text)


func _on_SearchTerm_text_entered(new_text):
	if(Input.is_physical_key_pressed(KEY_SHIFT)):
		_sr.find_prev(new_text)
	else:
		_sr.find_next(new_text)


func _on_SearchTerm_gui_input(event):
	if(event is InputEventKey and !event.pressed and event.scancode == KEY_ESCAPE):
		show_search(false)

func _on_WordWrap_pressed():
	_ctrls.output.wrap_enabled = _ctrls.word_wrap.pressed
	_ctrls.output.update()

# ------------------
# Public
# ------------------
func show_search(should):
	_ctrls.search_bar.bar.visible = should
	if(should):
		_ctrls.search_bar.search_term.grab_focus()
		_ctrls.search_bar.search_term.select_all()
	_ctrls.show_search.pressed = should


func search(text, start_pos, highlight=true):
	return _sr.find_next(text)


func copy_to_clipboard():
	var selected = _ctrls.output.get_selection_text()
	if(selected != ''):
		OS.clipboard = selected
	else:
		OS.clipboard = _ctrls.output.text


func clear():
	_ctrls.output.text = ''


func set_all_fonts(base_name):
	if(base_name == 'Default'):
		_set_font(null, 'font')
#		_set_font(null, 'normal_font')
#		_set_font(null, 'bold_font')
#		_set_font(null, 'italics_font')
#		_set_font(null, 'bold_italics_font')
	else:
		_set_font(base_name + '-Regular', 'font')
#		_set_font(base_name + '-Regular', 'normal_font')
#		_set_font(base_name + '-Bold', 'bold_font')
#		_set_font(base_name + '-Italic', 'italics_font')
#		_set_font(base_name + '-BoldItalic', 'bold_italics_font')


func set_font_size(new_size):
	var rtl = _ctrls.output
	if(rtl.get('custom_fonts/font') != null):
		rtl.get('custom_fonts/font').size = new_size
#		rtl.get('custom_fonts/bold_italics_font').size = new_size
#		rtl.get('custom_fonts/bold_font').size = new_size
#		rtl.get('custom_fonts/italics_font').size = new_size
#		rtl.get('custom_fonts/normal_font').size = new_size


func set_use_colors(value):
	pass


func get_use_colors():
	return false;


func get_rich_text_edit():
	return _ctrls.output


func load_file(path):
	var f = File.new()
	var result = f.open(path, f.READ)
	if(result != OK):
		return

	var t = f.get_as_text()
	f.close()
	_ctrls.output.text = t
	_ctrls.output.scroll_vertical = _ctrls.output.get_line_count()
	_ctrls.output.set_deferred('scroll_vertical', _ctrls.output.get_line_count())


func add_text(text):
	if(is_inside_tree()):
		_ctrls.output.text += text


func scroll_to_line(line):
	_ctrls.output.scroll_vertical = line
	_ctrls.output.cursor_set_line(line)

--- Start of ./addons/gut/gui/RunAtCursor.gd ---

tool
extends Control


var ScriptTextEditors = load('res://addons/gut/gui/script_text_editor_controls.gd')

onready var _ctrls = {
	btn_script = $HBox/BtnRunScript,
	btn_inner = $HBox/BtnRunInnerClass,
	btn_method = $HBox/BtnRunMethod,
	lbl_none = $HBox/LblNoneSelected,
	arrow_1 = $HBox/Arrow1,
	arrow_2 = $HBox/Arrow2
}

var _editors = null
var _cur_editor = null
var _last_line = -1
var _cur_script_path = null
var _last_info = null

signal run_tests(what)


func _ready():
	_ctrls.lbl_none.visible = true
	_ctrls.btn_script.visible = false
	_ctrls.btn_inner.visible = false
	_ctrls.btn_method.visible = false

# ----------------
# Private
# ----------------
func _set_editor(which):
	_last_line = -1
	if(_cur_editor != null and _cur_editor.get_ref()):
		_cur_editor.get_ref().disconnect('cursor_changed', self, '_on_cursor_changed')

	if(which != null):
		_cur_editor = weakref(which)
		which.connect('cursor_changed', self, '_on_cursor_changed', [which])

		_last_line = which.cursor_get_line()
		_last_info = _editors.get_line_info()
		_update_buttons(_last_info)


func _update_buttons(info):
	_ctrls.lbl_none.visible = _cur_script_path == null
	_ctrls.btn_script.visible = _cur_script_path != null

	_ctrls.btn_inner.visible = info.inner_class != null
	_ctrls.arrow_1.visible = info.inner_class != null
	_ctrls.btn_inner.text = str(info.inner_class)
	_ctrls.btn_inner.hint_tooltip = str("Run all tests in Inner-Test-Class ", info.inner_class)

	_ctrls.btn_method.visible = info.test_method != null
	_ctrls.arrow_2.visible = info.test_method != null
	_ctrls.btn_method.text = str(info.test_method)
	_ctrls.btn_method.hint_tooltip = str("Run test ", info.test_method)

	# The button's new size won't take effect until the next frame.
	# This appears to be what was causing the button to not be clickable the
	# first time.
	call_deferred("_update_rect_size")


func _update_rect_size():
	rect_min_size.x = _ctrls.btn_method.rect_size.x + _ctrls.btn_method.rect_position.x

# ----------------
# Events
# ----------------
func _on_cursor_changed(which):
	if(which.cursor_get_line() != _last_line):
		_last_line = which.cursor_get_line()
		_last_info = _editors.get_line_info()
		_update_buttons(_last_info)


func _on_BtnRunScript_pressed():
	var info = _last_info.duplicate()
	info.script = _cur_script_path.get_file()
	info.inner_class = null
	info.test_method = null
	emit_signal("run_tests", info)


func _on_BtnRunInnerClass_pressed():
	var info = _last_info.duplicate()
	info.script = _cur_script_path.get_file()
	info.test_method = null
	emit_signal("run_tests", info)


func _on_BtnRunMethod_pressed():
	var info = _last_info.duplicate()
	info.script = _cur_script_path.get_file()
	emit_signal("run_tests", info)


# ----------------
# Public
# ----------------
func set_script_text_editors(value):
	_editors = value


func activate_for_script(path):
	_ctrls.btn_script.visible = true
	_ctrls.btn_script.text = path.get_file()
	_ctrls.btn_script.hint_tooltip = str("Run all tests in script ", path)
	_cur_script_path = path
	_editors.refresh()
	_set_editor(_editors.get_current_text_edit())


func get_script_button():
	return _ctrls.btn_script


func get_inner_button():
	return _ctrls.btn_inner


func get_test_button():
	return _ctrls.btn_method


# not used, thought was configurable but it's just the script prefix
func set_method_prefix(value):
	_editors.set_method_prefix(value)


# not used, thought was configurable but it's just the script prefix
func set_inner_class_prefix(value):
	_editors.set_inner_class_prefix(value)


# Mashed this function in here b/c it has _editors.  Probably should be
# somewhere else (possibly in script_text_editor_controls).
func search_current_editor_for_text(txt):
	var te = _editors.get_current_text_edit()
	var result = te.search(txt, 0, 0, 0)
	var to_return = -1

	if result.size() > 0:
		to_return = result[TextEdit.SEARCH_RESULT_LINE]

	return to_return

--- Start of ./addons/gut/gui/RunResults.gd ---

extends Control
tool

var _interface = null
var _utils = load('res://addons/gut/utils.gd').new()
var _hide_passing = true
var _font = null
var _font_size = null
var _root = null
var _max_icon_width = 10
var _editors = null # script_text_editor_controls.gd
var _show_orphans = true
var _output_control = null

const _col_1_bg_color = Color(0, 0, 0, .1)

var 	_icons = {
	red = load('res://addons/gut/images/red.png'),
	green = load('res://addons/gut/images/green.png'),
	yellow = load('res://addons/gut/images/yellow.png'),
}

signal search_for_text(text)

onready var _ctrls = {
	tree = $VBox/Output/Scroll/Tree,
	lbl_overlay = $VBox/Output/OverlayMessage,
	chk_hide_passing = $VBox/Toolbar/HidePassing,
	toolbar = {
		toolbar = $VBox/Toolbar,
		collapse = $VBox/Toolbar/Collapse,
		collapse_all = $VBox/Toolbar/CollapseAll,
		expand = $VBox/Toolbar/Expand,
		expand_all = $VBox/Toolbar/ExpandAll,
		hide_passing = $VBox/Toolbar/HidePassing,
		show_script = $VBox/Toolbar/ShowScript,
		scroll_output = $VBox/Toolbar/ScrollOutput
	}
}

func _test_running_setup():
	_hide_passing = true
	_show_orphans = true
	var _gut_config = load('res://addons/gut/gut_config.gd').new()
	_gut_config.load_panel_options('res://.gut_editor_config.json')
	set_font(
		_gut_config.options.panel_options.font_name,
		_gut_config.options.panel_options.font_size)

	_ctrls.toolbar.hide_passing.text = '[hp]'
	load_json_file('user://.gut_editor.json')


func _set_toolbutton_icon(btn, icon_name, text):
	if(Engine.editor_hint):
		btn.icon = get_icon(icon_name, 'EditorIcons')
	else:
		btn.text = str('[', text, ']')


func _ready():
	var f = $FontSampler.get_font("font")
	var s_size = f.get_string_size("000 of 000 passed")
	_root = _ctrls.tree.create_item()
	_ctrls.tree.set_hide_root(true)
	_ctrls.tree.columns = 2
	_ctrls.tree.set_column_expand(0, true)
	_ctrls.tree.set_column_expand(1, false)
	_ctrls.tree.set_column_min_width(1, s_size.x)

	_set_toolbutton_icon(_ctrls.toolbar.collapse, 'CollapseTree', 'c')
	_set_toolbutton_icon(_ctrls.toolbar.collapse_all, 'CollapseTree', 'c')
	_set_toolbutton_icon(_ctrls.toolbar.expand, 'ExpandTree', 'e')
	_set_toolbutton_icon(_ctrls.toolbar.expand_all, 'ExpandTree', 'e')
	_set_toolbutton_icon(_ctrls.toolbar.show_script, 'Script', 'ss')
	_set_toolbutton_icon(_ctrls.toolbar.scroll_output, 'Font', 'so')

	_ctrls.toolbar.hide_passing.set('custom_icons/checked', get_icon('GuiVisibilityHidden', 'EditorIcons'))
	_ctrls.toolbar.hide_passing.set('custom_icons/unchecked', get_icon('GuiVisibilityVisible', 'EditorIcons'))

	if(get_parent() == get_tree().root):
		_test_running_setup()

	call_deferred('_update_min_width')

func _update_min_width():
	rect_min_size.x = _ctrls.toolbar.toolbar.rect_size.x

func _open_file(path, line_number):
	if(_interface == null):
		print('Too soon, wait a bit and try again.')
		return

	var r = load(path)
	if(line_number != -1):
		_interface.edit_script(r, line_number)
	else:
		_interface.edit_script(r)

	if(_ctrls.toolbar.show_script.pressed):
		_interface.set_main_screen_editor('Script')


func _add_script_tree_item(script_path, script_json):
	var path_info = _get_path_and_inner_class_name_from_test_path(script_path)
	# print('* adding script ', path_info)
	var item_text = script_path
	var parent = _root

	if(path_info.inner_class != ''):
		parent = _find_script_item_with_path(path_info.path)
		item_text = path_info.inner_class
		if(parent == null):
			parent = _add_script_tree_item(path_info.path, {})

	var item = _ctrls.tree.create_item(parent)
	item.set_text(0, item_text)
	var meta = {
		"type":"script",
		"path":path_info.path,
		"inner_class":path_info.inner_class,
		"json":script_json}
	item.set_metadata(0, meta)
	item.set_custom_bg_color(1, _col_1_bg_color)

	return item


func _add_assert_item(text, icon, parent_item):
	# print('        * adding assert')
	var assert_item = _ctrls.tree.create_item(parent_item)
	assert_item.set_icon_max_width(0, _max_icon_width)
	assert_item.set_text(0, text)
	assert_item.set_metadata(0, {"type":"assert"})
	assert_item.set_icon(0, icon)
	assert_item.set_custom_bg_color(1, _col_1_bg_color)

	return assert_item


func _add_test_tree_item(test_name, test_json, script_item):
	# print('    * adding test ', test_name)
	var no_orphans_to_show = !_show_orphans or (_show_orphans and test_json.orphans == 0)
	if(_hide_passing and test_json['status'] == 'pass' and no_orphans_to_show):
		return

	var item = _ctrls.tree.create_item(script_item)
	var status = test_json['status']
	var meta = {"type":"test", "json":test_json}

	item.set_text(0, test_name)
	item.set_text(1, status)
	item.set_text_align(1, TreeItem.ALIGN_RIGHT)
	item.set_custom_bg_color(1, _col_1_bg_color)

	item.set_metadata(0, meta)
	item.set_icon_max_width(0, _max_icon_width)

	var orphan_text = 'orphans'
	if(test_json.orphans == 1):
		orphan_text = 'orphan'
	orphan_text = str(test_json.orphans, ' ', orphan_text)


	if(status == 'pass' and no_orphans_to_show):
		item.set_icon(0, _icons.green)
	elif(status == 'pass' and !no_orphans_to_show):
		item.set_icon(0, _icons.yellow)
		item.set_text(1, orphan_text)
	elif(status == 'fail'):
		item.set_icon(0, _icons.red)
	else:
		item.set_icon(0, _icons.yellow)

	if(!_hide_passing):
		for passing in test_json.passing:
			_add_assert_item('pass: ' + passing, _icons.green, item)

	for failure in test_json.failing:
		_add_assert_item("fail:  " + failure.replace("\n", ''), _icons.red, item)

	for pending in test_json.pending:
		_add_assert_item("pending:  " + pending.replace("\n", ''), _icons.yellow, item)

	if(status != 'pass' and !no_orphans_to_show):
		_add_assert_item(orphan_text, _icons.yellow, item)

	return item


func _load_result_tree(j):
	var scripts = j['test_scripts']['scripts']
	var script_keys = scripts.keys()
	# if we made it here, the json is valid and we did something, otherwise the
	# 'nothing to see here' should be visible.
	clear_centered_text()

	var _last_script_item = null
	for key in script_keys:
		var tests = scripts[key]['tests']
		var test_keys = tests.keys()
		var s_item = _add_script_tree_item(key, scripts[key])
		var bad_count = 0

		for test_key in test_keys:
			var t_item = _add_test_tree_item(test_key, tests[test_key], s_item)
			if(tests[test_key].status != 'pass'):
				bad_count += 1
			elif(t_item != null):
				t_item.collapsed = true

		# get_children returns the first child or null.  its a dumb name.
		if(s_item.get_children() == null):
			# var m = s_item.get_metadata(0)
			# print('!! Deleting ', m.path, ' ', m.inner_class)
			s_item.free()
		else:
			var total_text = str(test_keys.size(), ' passed')
			s_item.set_text_align(1, s_item.ALIGN_LEFT)
			if(bad_count == 0):
				s_item.collapsed = true
			else:
				total_text = str(test_keys.size() - bad_count, ' of ', test_keys.size(), ' passed')
			s_item.set_text(1, total_text)

	_free_childless_scripts()
	_show_all_passed()


func _free_childless_scripts():
	var item = _root.get_children()
	while(item != null):
		var next_item = item.get_next()
		if(item.get_children() == null):
			item.free()
		item = next_item


func _find_script_item_with_path(path):
	var item = _root.get_children()
	var to_return = null

	while(item != null and to_return == null):
		if(item.get_metadata(0).path == path):
			to_return = item
		else:
			item = item.get_next()

	return to_return


func _get_line_number_from_assert_msg(msg):
	var line = -1
	if(msg.find('at line') > 0):
		line = int(msg.split("at line")[-1].split(" ")[-1])
	return line


func _get_path_and_inner_class_name_from_test_path(path):
	var to_return = {
		path = '',
		inner_class = ''
	}

	to_return.path = path
	if !path.ends_with('.gd'):
		var loc = path.find('.gd')
		to_return.inner_class = path.split('.')[-1]
		to_return.path = path.substr(0, loc + 3)
	return to_return


func _handle_tree_item_select(item, force_scroll):
	var item_type = item.get_metadata(0).type

	var path = '';
	var line = -1;
	var method_name = ''
	var inner_class = ''

	if(item_type == 'test'):
		var s_item = item.get_parent()
		path = s_item.get_metadata(0)['path']
		inner_class = s_item.get_metadata(0)['inner_class']
		line = -1
		method_name = item.get_text(0)
	elif(item_type == 'assert'):
		var s_item = item.get_parent().get_parent()
		path = s_item.get_metadata(0)['path']
		inner_class = s_item.get_metadata(0)['inner_class']

		line = _get_line_number_from_assert_msg(item.get_text(0))
		method_name = item.get_parent().get_text(0)
	elif(item_type == 'script'):
		path = item.get_metadata(0)['path']
		if(item.get_parent() != _root):
			inner_class = item.get_text(0)
		line = -1
		method_name = ''
	else:
		return

	var path_info = _get_path_and_inner_class_name_from_test_path(path)
	if(force_scroll or _ctrls.toolbar.show_script.pressed):
		_goto_code(path, line, method_name, inner_class)
	if(force_scroll or _ctrls.toolbar.scroll_output.pressed):
		_goto_output(path, method_name, inner_class)


# starts at beginning of text edit and searches for each search term, moving
# through the text as it goes; ensuring that, when done, it found the first
# occurance of the last srting that happend after the first occurance of
# each string before it.  (Generic way of searching for a method name in an
# inner class that may have be a duplicate of a method name in a different
# inner class)
func _get_line_number_for_seq_search(search_strings, te):
#	var te = _editors.get_current_text_edit()
	var result = null
	var to_return = -1
	var start_line = 0
	var start_col = 0
	var s_flags = 0

	var i = 0
	var string_found = true
	while(i < search_strings.size() and string_found):
		result = te.search(search_strings[i], s_flags, start_line, start_col)
		if(result.size() > 0):
			start_line = result[TextEdit.SEARCH_RESULT_LINE]
			start_col = result[TextEdit.SEARCH_RESULT_COLUMN]
			to_return = start_line
		else:
			string_found = false
		i += 1

	return to_return


func _goto_code(path, line, method_name='', inner_class =''):
	if(_interface == null):
		print('going to ', [path, line, method_name, inner_class])
		return

	_open_file(path, line)
	if(line == -1):
		var search_strings = []
		if(inner_class != ''):
			search_strings.append(inner_class)

		if(method_name != ''):
			search_strings.append(method_name)

		line = _get_line_number_for_seq_search(search_strings, _editors.get_current_text_edit())
		if(line != -1):
			_interface.get_script_editor().goto_line(line)


func _goto_output(path, method_name, inner_class):
	if(_output_control == null):
		return

	var search_strings = [path]

	if(inner_class != ''):
		search_strings.append(inner_class)

	if(method_name != ''):
		search_strings.append(method_name)

	var line = _get_line_number_for_seq_search(search_strings, _output_control.get_rich_text_edit())
	if(line != -1):
		_output_control.scroll_to_line(line)


func _show_all_passed():
	if(_root.get_children() == null):
		add_centered_text('Everything passed!')


func _set_collapsed_on_all(item, value):
	if(item == _root):
		var node = _root.get_children()
		while(node != null):
			node.call_recursive('set_collapsed', value)
			node = node.get_next()
	else:
		item.call_recursive('set_collapsed', value)

# --------------
# Events
# --------------
func _on_Tree_item_selected():
	# do not force scroll
	var item = _ctrls.tree.get_selected()
	_handle_tree_item_select(item, false)
	# it just looks better if the left is always selected.
	if(item.is_selected(1)):
		item.deselect(1)
		item.select(0)


func _on_Tree_item_activated():
	# force scroll
	print('double clicked')
	_handle_tree_item_select(_ctrls.tree.get_selected(), true)

func _on_Collapse_pressed():
	collapse_selected()


func _on_Expand_pressed():
	expand_selected()


func _on_CollapseAll_pressed():
	collapse_all()


func _on_ExpandAll_pressed():
	expand_all()


func _on_Hide_Passing_pressed():
	_hide_passing = _ctrls.toolbar.hide_passing.pressed

# --------------
# Public
# --------------
func load_json_file(path):
	var text = _utils.get_file_as_text(path)
	if(text != ''):
		var result = JSON.parse(text)
		if(result.error != OK):
			add_centered_text(str(path, " has invalid json in it \n",
				'Error ', result.error, "@", result.error_line, "\n",
				result.error_string))
			return

		load_json_results(result.result)
	else:
		add_centered_text(str(path, ' was empty or does not exist.'))


func load_json_results(j):
	clear()
	add_centered_text('Nothing Here')
	_load_result_tree(j)


func add_centered_text(t):
	_ctrls.lbl_overlay.text = t


func clear_centered_text():
	_ctrls.lbl_overlay.text = ''


func clear():
	_ctrls.tree.clear()
	_root = _ctrls.tree.create_item()
	clear_centered_text()


func set_interface(which):
	_interface = which


func set_script_text_editors(value):
	_editors = value


func collapse_all():
	_set_collapsed_on_all(_root, true)


func expand_all():
	_set_collapsed_on_all(_root, false)


func collapse_selected():
	var item = _ctrls.tree.get_selected()
	if(item != null):
		_set_collapsed_on_all(item, true)

func expand_selected():
	var item = _ctrls.tree.get_selected()
	if(item != null):
		_set_collapsed_on_all(item, false)


func set_show_orphans(should):
	_show_orphans = should


func set_font(font_name, size):
	pass
#	var dyn_font = DynamicFont.new()
#	var font_data = DynamicFontData.new()
#	font_data.font_path = 'res://addons/gut/fonts/' + font_name + '-Regular.ttf'
#	font_data.antialiased = true
#	dyn_font.font_data = font_data
#
#	_font = dyn_font
#	_font.size = size
#	_font_size = size


func set_output_control(value):
	_output_control = value

--- Start of ./addons/gut/gui/script_text_editor_controls.gd ---

# Holds weakrefs to a ScriptTextEditor and related children nodes
# that might be useful.  Though the TextEdit is really the only one, but
# since the tree may change, the first TextEdit under a CodeTextEditor is
# the one we use...so we hold a ref to the CodeTextEditor too.
class ScriptEditorControlRef:
	var _text_edit = null
	var _script_editor = null
	var _code_editor = null

	func _init(script_edit):
		_script_editor = weakref(script_edit)
		_populate_controls()


	func _populate_controls():
		# who knows if the tree will change so get the first instance of each
		# type of control we care about.  Chances are there won't be more than
		# one of these in the future, but their position in the tree may change.
		_code_editor = weakref(_get_first_child_named('CodeTextEditor', _script_editor.get_ref()))
		_text_edit = weakref(_get_first_child_named("TextEdit", _code_editor.get_ref()))


	func _get_first_child_named(obj_name, parent_obj):
		if(parent_obj == null):
			return null

		var kids = parent_obj.get_children()
		var index = 0
		var to_return = null

		while(index < kids.size() and to_return == null):
			if(str(kids[index]).find(str("[", obj_name)) != -1):
				to_return = kids[index]
			else:
				to_return = _get_first_child_named(obj_name, kids[index])
				if(to_return == null):
					index += 1

		return to_return


	func get_script_text_edit():
		return _script_editor.get_ref()


	func get_text_edit():
		# ScriptTextEditors that are loaded when the project is opened
		# do not have their children populated yet.  So if we may have to
		# _populate_controls again if we don't have one.
		if(_text_edit == null):
			_populate_controls()
		return _text_edit.get_ref()


	func get_script_editor():
		return _script_editor


	func is_visible():
		var to_return = false
		if(_script_editor.get_ref()):
			to_return = _script_editor.get_ref().visible
		return to_return

# ##############################################################################
#
# ##############################################################################

# Used to make searching for the controls easier and faster.
var _script_editors_parent = null
# reference the ScriptEditor instance
var _script_editor = null
# Array of ScriptEditorControlRef containing all the opened ScriptTextEditors
# and related controls at the time of the last refresh.
var _script_editor_controls = []

var _method_prefix = 'test_'
var _inner_class_prefix = 'Test'

func _init(script_edit):
	_script_editor = script_edit
	refresh()


func _is_script_editor(obj):
	return str(obj).find('[ScriptTextEditor') != -1


# Find the first ScriptTextEditor and then get its parent.  Done this way
# because who knows if the parent object will change.  This is somewhat
# future proofed.
func _find_script_editors_parent():
	var _first_editor = _get_first_child_of_type_name("ScriptTextEditor", _script_editor)
	if(_first_editor != null):
		_script_editors_parent = _first_editor.get_parent()


func _populate_editors():
	if(_script_editors_parent == null):
		return

	_script_editor_controls.clear()
	for child in _script_editors_parent.get_children():
		if(_is_script_editor(child)):
			var ref = ScriptEditorControlRef.new(child)
			_script_editor_controls.append(ref)

# Yes, this is the same as the one above but with a different name.  This was
# easier than trying to find a place where it could be used by both.
func _get_first_child_of_type_name(obj_name, parent_obj):
	if(parent_obj == null):
		return null

	var kids = parent_obj.get_children()
	var index = 0
	var to_return = null

	while(index < kids.size() and to_return == null):
		if(str(kids[index]).find(str("[", obj_name)) != -1):
			to_return = kids[index]
		else:
			to_return = _get_first_child_of_type_name(obj_name, kids[index])
			if(to_return == null):
				index += 1

	return to_return


func _get_func_name_from_line(text):
	text = text.strip_edges()
	var left = text.split("(")[0]
	var func_name = left.split(" ")[1]
	return func_name


func _get_class_name_from_line(text):
	text = text.strip_edges()
	var right = text.split(" ")[1]
	var the_name = right.rstrip(":")
	return the_name

func refresh():
	if(_script_editors_parent == null):
		_find_script_editors_parent()

	if(_script_editors_parent != null):
		_populate_editors()


func get_current_text_edit():
	var cur_script_editor = null
	var idx = 0

	while(idx < _script_editor_controls.size() and cur_script_editor == null):
		if(_script_editor_controls[idx].is_visible()):
			cur_script_editor = _script_editor_controls[idx]
		else:
			idx += 1

	var to_return = null
	if(cur_script_editor != null):
		to_return = cur_script_editor.get_text_edit()

	return to_return


func get_script_editor_controls():
	var to_return = []
	for ctrl_ref in _script_editor_controls:
		to_return.append(ctrl_ref.get_script_text_edit())

	return to_return


func get_line_info():
	var editor = get_current_text_edit()
	if(editor == null):
		return

	var info = {
		script = null,
		inner_class = null,
		test_method = null
	}

	var line = editor.cursor_get_line()
	var done_func = false
	var done_inner = false
	while(line > 0 and (!done_func or !done_inner)):
		if(editor.can_fold(line)):
			var text = editor.get_line(line)
			var strip_text = text.strip_edges(true, false) # only left

			if(!done_func and strip_text.begins_with("func ")):
				var func_name = _get_func_name_from_line(text)
				if(func_name.begins_with(_method_prefix)):
					info.test_method = func_name
				done_func = true
				# If the func line is left justified then there won't be any
				# inner classes above it.
				if(strip_text == text):
					done_inner = true

			if(!done_inner and strip_text.begins_with("class")):
				var inner_name = _get_class_name_from_line(text)
				if(inner_name.begins_with(_inner_class_prefix)):
					info.inner_class = inner_name
					done_inner = true
					# if we found an inner class then we are already past
					# any test the cursor could be in.
					done_func = true
		line -= 1

	return info


func get_method_prefix():
	return _method_prefix


func set_method_prefix(method_prefix):
	_method_prefix = method_prefix


func get_inner_class_prefix():
	return _inner_class_prefix


func set_inner_class_prefix(inner_class_prefix):
	_inner_class_prefix = inner_class_prefix

--- Start of ./addons/gut/gui/ShortcutButton.gd ---

tool
extends Control


onready var _ctrls = {
	shortcut_label = $Layout/lblShortcut,
	set_button = $Layout/SetButton,
	save_button = $Layout/SaveButton,
	cancel_button = $Layout/CancelButton,
	clear_button = $Layout/ClearButton
}

signal changed
signal start_edit
signal end_edit

const NO_SHORTCUT = '<None>'

var _source_event = InputEventKey.new()
var _pre_edit_event = null
var _key_disp = NO_SHORTCUT

var _modifier_keys = [KEY_ALT, KEY_CONTROL, KEY_META, KEY_SHIFT]

# Called when the node enters the scene tree for the first time.
func _ready():
	set_process_unhandled_key_input(false)


func _display_shortcut():
	_ctrls.shortcut_label.text = to_s()


func _is_shift_only_modifier():
	return _source_event.shift and \
		!(_source_event.meta or _source_event.control or _source_event.alt)


func _has_modifier():
	return _source_event.alt or _source_event.control or _source_event.meta or _source_event.shift


func _is_modifier(scancode):
	return _modifier_keys.has(scancode)


func _edit_mode(should):
	set_process_unhandled_key_input(should)
	_ctrls.set_button.visible = !should
	_ctrls.save_button.visible = should
	_ctrls.save_button.disabled = should
	_ctrls.cancel_button.visible = should
	_ctrls.clear_button.visible = !should

	if(should and to_s() == ''):
		_ctrls.shortcut_label.text = 'press buttons'
	else:
		_ctrls.shortcut_label.text = to_s()

	if(should):
		emit_signal("start_edit")
	else:
		emit_signal("end_edit")

# ---------------
# Events
# ---------------
func _unhandled_key_input(event):
	if(event is InputEventKey):
		if(event.pressed):
			_source_event.alt = event.alt or event.scancode == KEY_ALT
			_source_event.control = event.control or event.scancode == KEY_CONTROL
			_source_event.meta = event.meta or event.scancode == KEY_META
			_source_event.shift = event.shift or event.scancode == KEY_SHIFT

			if(_has_modifier() and !_is_modifier(event.scancode)):
				_source_event.scancode = event.scancode
				_key_disp = OS.get_scancode_string(event.scancode)
			else:
#				_source_event.set_scancode = null
				_key_disp = NO_SHORTCUT
			_display_shortcut()
			_ctrls.save_button.disabled = !is_valid()


func _on_SetButton_pressed():
	_pre_edit_event = _source_event.duplicate(true)
	_edit_mode(true)


func _on_SaveButton_pressed():
	_edit_mode(false)
	_pre_edit_event = null
	emit_signal('changed')


func _on_CancelButton_pressed():
	_edit_mode(false)
	_source_event = _pre_edit_event
	_key_disp = OS.get_scancode_string(_source_event.scancode)
	if(_key_disp == ''):
		_key_disp = NO_SHORTCUT
	_display_shortcut()


func _on_ClearButton_pressed():
	clear_shortcut()

# ---------------
# Public
# ---------------
func to_s():
	var modifiers = []
	if(_source_event.alt):
		modifiers.append('alt')
	if(_source_event.control):
		modifiers.append('ctrl')
	if(_source_event.meta):
		modifiers.append('meta')
	if(_source_event.shift):
		modifiers.append('shift')

	if(_source_event.scancode != null):
		modifiers.append(_key_disp)

	var mod_text = ''
	for i in range(modifiers.size()):
		mod_text += modifiers[i]
		if(i != modifiers.size() - 1):
			mod_text += ' + '

	return mod_text


func is_valid():
	return _has_modifier() and _key_disp != NO_SHORTCUT and !_is_shift_only_modifier()


func get_shortcut():
	var to_return = ShortCut.new()
	to_return.shortcut = _source_event
	return to_return


func set_shortcut(sc):
	if(sc == null or sc.shortcut == null):
		clear_shortcut()
	else:
		_source_event = sc.shortcut
		_key_disp = OS.get_scancode_string(_source_event.scancode)
		_display_shortcut()


func clear_shortcut():
	_source_event = InputEventKey.new()
	_key_disp = NO_SHORTCUT
	_display_shortcut()


func disable_set(should):
	_ctrls.set_button.disabled = should

func disable_clear(should):
	_ctrls.clear_button.disabled = should

--- Start of ./addons/gut/gut_cmdln.gd ---

# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# Description
# -----------
# Command line interface for the GUT unit testing tool.  Allows you to run tests
# from the command line instead of running a scene.  Place this script along with
# gut.gd into your scripts directory at the root of your project.  Once there you
# can run this script (from the root of your project) using the following command:
# 	godot -s -d test/gut/gut_cmdln.gd
#
# See the readme for a list of options and examples.  You can also use the -gh
# option to get more information about how to use the command line interface.
# ##############################################################################
extends SceneTree

var Optparse = load('res://addons/gut/optparse.gd')
var Gut = load('res://addons/gut/gut.gd')
var GutRunner = load('res://addons/gut/gui/GutRunner.tscn')

# ------------------------------------------------------------------------------
# Helper class to resolve the various different places where an option can
# be set.  Using the get_value method will enforce the order of precedence of:
# 	1.  command line value
#	2.  config file value
#	3.  default value
#
# The idea is that you set the base_opts.  That will get you a copies of the
# hash with null values for the other types of values.  Lower precedented hashes
# will punch through null values of higher precedented hashes.
# ------------------------------------------------------------------------------
class OptionResolver:
	var base_opts = null
	var cmd_opts = null
	var config_opts = null


	func get_value(key):
		return _nvl(cmd_opts[key], _nvl(config_opts[key], base_opts[key]))

	func set_base_opts(opts):
		base_opts = opts
		cmd_opts = _null_copy(opts)
		config_opts = _null_copy(opts)

	# creates a copy of a hash with all values null.
	func _null_copy(h):
		var new_hash = {}
		for key in h:
			new_hash[key] = null
		return new_hash

	func _nvl(a, b):
		if(a == null):
			return b
		else:
			return a
	func _string_it(h):
		var to_return = ''
		for key in h:
			to_return += str('(',key, ':', _nvl(h[key], 'NULL'), ')')
		return to_return

	func to_s():
		return str("base:\n", _string_it(base_opts), "\n", \
				   "config:\n", _string_it(config_opts), "\n", \
				   "cmd:\n", _string_it(cmd_opts), "\n", \
				   "resolved:\n", _string_it(get_resolved_values()))

	func get_resolved_values():
		var to_return = {}
		for key in base_opts:
			to_return[key] = get_value(key)
		return to_return

	func to_s_verbose():
		var to_return = ''
		var resolved = get_resolved_values()
		for key in base_opts:
			to_return += str(key, "\n")
			to_return += str('  default: ', _nvl(base_opts[key], 'NULL'), "\n")
			to_return += str('  config:  ', _nvl(config_opts[key], ' --'), "\n")
			to_return += str('  cmd:     ', _nvl(cmd_opts[key], ' --'), "\n")
			to_return += str('  final:   ', _nvl(resolved[key], 'NULL'), "\n")

		return to_return

# ------------------------------------------------------------------------------
# Here starts the actual script that uses the Options class to kick off Gut
# and run your tests.
# ------------------------------------------------------------------------------
var _utils = load('res://addons/gut/utils.gd').get_instance()
var _gut_config = load('res://addons/gut/gut_config.gd').new()
# instance of gut
var _tester = null
# array of command line options specified
var _final_opts = []


func setup_options(options, font_names):
	var opts = Optparse.new()
	opts.set_banner(('This is the command line interface for the unit testing tool Gut.  With this ' +
					'interface you can run one or more test scripts from the command line.  In order ' +
					'for the Gut options to not clash with any other godot options, each option starts ' +
					'with a "g".  Also, any option that requires a value will take the form of ' +
					'"-g<name>=<value>".  There cannot be any spaces between the option, the "=", or ' +
					'inside a specified value or godot will think you are trying to run a scene.'))
	opts.add('-gtest', [], 'Comma delimited list of full paths to test scripts to run.')
	opts.add('-gdir', options.dirs, 'Comma delimited list of directories to add tests from.')
	opts.add('-gprefix', options.prefix, 'Prefix used to find tests when specifying -gdir.  Default "[default]".')
	opts.add('-gsuffix', options.suffix, 'Test script suffix, including .gd extension.  Default "[default]".')
	opts.add('-ghide_orphans', false, 'Display orphan counts for tests and scripts.  Default "[default]".')
	opts.add('-gmaximize', false, 'Maximizes test runner window to fit the viewport.')
	opts.add('-gcompact_mode', false, 'The runner will be in compact mode.  This overrides -gmaximize.')
	opts.add('-gexit', false, 'Exit after running tests.  If not specified you have to manually close the window.')
	opts.add('-gexit_on_success', false, 'Only exit if all tests pass.')
	opts.add('-glog', options.log_level, 'Log level.  Default [default]')
	opts.add('-gignore_pause', false, 'Ignores any calls to gut.pause_before_teardown.')
	opts.add('-gselect', '', ('Select a script to run initially.  The first script that ' +
							'was loaded using -gtest or -gdir that contains the specified ' +
							'string will be executed.  You may run others by interacting ' +
							'with the GUI.'))
	opts.add('-gunit_test_name', '', ('Name of a test to run.  Any test that contains the specified ' +
								'text will be run, all others will be skipped.'))
	opts.add('-gh', false, 'Print this help, then quit')
	opts.add('-gconfig', 'res://.gutconfig.json', 'A config file that contains configuration information.  Default is res://.gutconfig.json')
	opts.add('-ginner_class', '', 'Only run inner classes that contain this string')
	opts.add('-gopacity', options.opacity, 'Set opacity of test runner window. Use range 0 - 100. 0 = transparent, 100 = opaque.')
	opts.add('-gpo', false, 'Print option values from all sources and the value used, then quit.')
	opts.add('-ginclude_subdirs', false, 'Include subdirectories of -gdir.')
	opts.add('-gdouble_strategy', 'partial', 'Default strategy to use when doubling.  Valid values are [partial, full].  Default "[default]"')
	opts.add('-gdisable_colors', false, 'Disable command line colors.')
	opts.add('-gpre_run_script', '', 'pre-run hook script path')
	opts.add('-gpost_run_script', '', 'post-run hook script path')
	opts.add('-gprint_gutconfig_sample', false, 'Print out json that can be used to make a gutconfig file then quit.')

	opts.add('-gfont_name', options.font_name, str('Valid values are:  ', font_names, '.  Default "[default]"'))
	opts.add('-gfont_size', options.font_size, 'Font size, default "[default]"')
	opts.add('-gbackground_color', options.background_color, 'Background color as an html color, default "[default]"')
	opts.add('-gfont_color',options.font_color, 'Font color as an html color, default "[default]"')

	opts.add('-gjunit_xml_file', options.junit_xml_file, 'Export results of run to this file in the Junit XML format.')
	opts.add('-gjunit_xml_timestamp', options.junit_xml_timestamp, 'Include a timestamp in the -gjunit_xml_file, default [default]')
	return opts


# Parses options, applying them to the _tester or setting values
# in the options struct.
func extract_command_line_options(from, to):
	to.config_file = from.get_value('-gconfig')
	to.dirs = from.get_value('-gdir')
	to.disable_colors =  from.get_value('-gdisable_colors')
	to.double_strategy = from.get_value('-gdouble_strategy')
	to.ignore_pause = from.get_value('-gignore_pause')
	to.include_subdirs = from.get_value('-ginclude_subdirs')
	to.inner_class = from.get_value('-ginner_class')
	to.log_level = from.get_value('-glog')
	to.opacity = from.get_value('-gopacity')
	to.post_run_script = from.get_value('-gpost_run_script')
	to.pre_run_script = from.get_value('-gpre_run_script')
	to.prefix = from.get_value('-gprefix')
	to.selected = from.get_value('-gselect')
	to.should_exit = from.get_value('-gexit')
	to.should_exit_on_success = from.get_value('-gexit_on_success')
	to.should_maximize = from.get_value('-gmaximize')
	to.compact_mode = from.get_value('-gcompact_mode')
	to.hide_orphans = from.get_value('-ghide_orphans')
	to.suffix = from.get_value('-gsuffix')
	to.tests = from.get_value('-gtest')
	to.unit_test_name = from.get_value('-gunit_test_name')

	to.font_size = from.get_value('-gfont_size')
	to.font_name = from.get_value('-gfont_name')
	to.background_color = from.get_value('-gbackground_color')
	to.font_color = from.get_value('-gfont_color')

	to.junit_xml_file = from.get_value('-gjunit_xml_file')
	to.junit_xml_timestamp = from.get_value('-gjunit_xml_timestamp')



func _print_gutconfigs(values):
	var header = """Here is a sample of a full .gutconfig.json file.
You do not need to specify all values in your own file.  The values supplied in
this sample are what would be used if you ran gut w/o the -gprint_gutconfig_sample
option (option priority:  command-line, .gutconfig, default)."""
	print("\n", header.replace("\n", ' '), "\n\n")
	var resolved = values

	# remove some options that don't make sense to be in config
	resolved.erase("config_file")
	resolved.erase("show_help")

	print("Here's a config with all the properties set based off of your current command and config.")
	print(JSON.print(resolved, '  '))

	for key in resolved:
		resolved[key] = null

	print("\n\nAnd here's an empty config for you fill in what you want.")
	print(JSON.print(resolved, ' '))


# parse options and run Gut
func _run_gut():
	var opt_resolver = OptionResolver.new()
	opt_resolver.set_base_opts(_gut_config.default_options)

	print("\n\n", ' ---  Gut  ---')
	var o = setup_options(_gut_config.default_options, _gut_config.valid_fonts)

	var all_options_valid = o.parse()
	extract_command_line_options(o, opt_resolver.cmd_opts)

	var load_result = _gut_config.load_options_no_defaults(
		opt_resolver.get_value('config_file'))

	# SHORTCIRCUIT
	if(!all_options_valid or load_result == -1):
		quit(1)
	else:
		opt_resolver.config_opts = _gut_config.options

		if(o.get_value('-gh')):
			print(_utils.get_version_text())
			o.print_help()
			quit()
		elif(o.get_value('-gpo')):
			print('All command line options and where they are specified.  ' +
				'The "final" value shows which value will actually be used ' +
				'based on order of precedence (default < .gutconfig < cmd line).' + "\n")
			print(opt_resolver.to_s_verbose())
			quit()
		elif(o.get_value('-gprint_gutconfig_sample')):
			_print_gutconfigs(opt_resolver.get_resolved_values())
			quit()
		else:
			_final_opts = opt_resolver.get_resolved_values();
			_gut_config.options = _final_opts

			var runner = GutRunner.instance()
			runner.set_cmdln_mode(true)
			runner.set_gut_config(_gut_config)

			_tester = runner.get_gut()
			_tester.connect('tests_finished', self, '_on_tests_finished',
				[_final_opts.should_exit, _final_opts.should_exit_on_success])

			get_root().add_child(runner)
			run_tests(runner)


func run_tests(runner):
	runner.run_tests()



# exit if option is set.
func _on_tests_finished(should_exit, should_exit_on_success):
	if(_final_opts.dirs.size() == 0):
		if(_tester.get_summary().get_totals().scripts == 0):
			var lgr = _tester.get_logger()
			lgr.error('No directories configured.  Add directories with options or a .gutconfig.json file.  Use the -gh option for more information.')

	if(_tester.get_fail_count()):
		OS.exit_code = 1

	# Overwrite the exit code with the post_script
	var post_inst = _tester.get_post_run_script_instance()
	if(post_inst != null and post_inst.get_exit_code() != null):
		OS.exit_code = post_inst.get_exit_code()

	if(should_exit or (should_exit_on_success and _tester.get_fail_count() == 0)):
		quit()
	else:
		print("Tests finished, exit manually")

# ------------------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------------------
func _init():
	if(!_utils.is_version_ok()):
		print("\n\n", _utils.get_version_text())
		push_error(_utils.get_bad_version_text())
		OS.exit_code = 1
		quit()
	else:
		_run_gut()

--- Start of ./addons/gut/gut_config.gd ---

var Gut = load('res://addons/gut/gut.gd')

# Do not want a ref to _utils here due to use by editor plugin.
# _utils needs to be split so that constants and what not do not
# have to rely on the weird singleton thing I made.
enum DOUBLE_STRATEGY{
	FULL,
	PARTIAL
}


var valid_fonts = ['AnonymousPro', 'CourierPro', 'LobsterTwo', 'Default']
var default_options = {
	background_color = Color(.15, .15, .15, 1).to_html(),
	config_file = 'res://.gutconfig.json',
	dirs = [],
	disable_colors = false,
	double_strategy = 'partial',
	font_color = Color(.8, .8, .8, 1).to_html(),
	font_name = 'CourierPrime',
	font_size = 16,
	hide_orphans = false,
	ignore_pause = false,
	include_subdirs = false,
	inner_class = '',
	junit_xml_file = '',
	junit_xml_timestamp = false,
	log_level = 1,
	opacity = 100,
	post_run_script = '',
	pre_run_script = '',
	prefix = 'test_',
	selected = '',
	should_exit = false,
	should_exit_on_success = false,
	should_maximize = false,
	compact_mode = false,
	show_help = false,
	suffix = '.gd',
	tests = [],
	unit_test_name = '',

	gut_on_top = true,
}

var default_panel_options = {
	font_name = 'CourierPrime',
	font_size = 30,
	hide_result_tree = false,
	hide_output_text = false,
	hide_settings = false,
	use_colors = true
}

var options = default_options.duplicate()


func _null_copy(h):
	var new_hash = {}
	for key in h:
		new_hash[key] = null
	return new_hash


func _load_options_from_config_file(file_path, into):
	# SHORTCIRCUIT
	var f = File.new()
	if(!f.file_exists(file_path)):
		if(file_path != 'res://.gutconfig.json'):
			print('ERROR:  Config File "', file_path, '" does not exist.')
			return -1
		else:
			return 1

	var result = f.open(file_path, f.READ)
	if(result != OK):
		push_error(str("Could not load data ", file_path, ' ', result))
		return result

	var json = f.get_as_text()
	f.close()

	var results = JSON.parse(json)
	# SHORTCIRCUIT
	if(results.error != OK):
		print("\n\n",'!! ERROR parsing file:  ', file_path)
		print('    at line ', results.error_line, ':')
		print('    ', results.error_string)
		return -1

	# Get all the options out of the config file using the option name.  The
	# options hash is now the default source of truth for the name of an option.
	_load_dict_into(results.result, into)

	return 1

func _load_dict_into(source, dest):
	for key in dest:
		if(source.has(key)):
			if(source[key] != null):
				if(typeof(source[key]) == TYPE_DICTIONARY):
					_load_dict_into(source[key], dest[key])
				else:
					dest[key] = source[key]




func write_options(path):
	var content = JSON.print(options, ' ')

	var f = File.new()
	var result = f.open(path, f.WRITE)
	if(result == OK):
		f.store_string(content)
		f.close()
	return result


# Apply all the options specified to _tester.  This is where the rubber meets
# the road.
func _apply_options(opts, _tester):
	_tester.set_yield_between_tests(true)
	_tester.set_modulate(Color(1.0, 1.0, 1.0, min(1.0, float(opts.opacity) / 100)))
	_tester.show()

	_tester.set_include_subdirectories(opts.include_subdirs)

	if(opts.should_maximize):
		_tester.maximize()

	if(opts.compact_mode):
		_tester.get_gui().compact_mode(true)

	if(opts.inner_class != ''):
		_tester.set_inner_class_name(opts.inner_class)
	_tester.set_log_level(opts.log_level)
	_tester.set_ignore_pause_before_teardown(opts.ignore_pause)

	if(opts.selected != ''):
		_tester.select_script(opts.selected)
		# _run_single = true

	for i in range(opts.dirs.size()):
		_tester.add_directory(opts.dirs[i], opts.prefix, opts.suffix)

	for i in range(opts.tests.size()):
		_tester.add_script(opts.tests[i])


	if(opts.double_strategy == 'full'):
		_tester.set_double_strategy(DOUBLE_STRATEGY.FULL)
	elif(opts.double_strategy == 'partial'):
		_tester.set_double_strategy(DOUBLE_STRATEGY.PARTIAL)

	_tester.set_unit_test_name(opts.unit_test_name)
	_tester.set_pre_run_script(opts.pre_run_script)
	_tester.set_post_run_script(opts.post_run_script)
	_tester.set_color_output(!opts.disable_colors)
	_tester.show_orphans(!opts.hide_orphans)
	_tester.set_junit_xml_file(opts.junit_xml_file)
	_tester.set_junit_xml_timestamp(opts.junit_xml_timestamp)

	_tester.get_gui().set_font_size(opts.font_size)
	_tester.get_gui().set_font(opts.font_name)
	if(opts.font_color != null and opts.font_color.is_valid_html_color()):
		_tester.get_gui().set_default_font_color(Color(opts.font_color))
	if(opts.background_color != null and opts.background_color.is_valid_html_color()):
		_tester.get_gui().set_background_color(Color(opts.background_color))

	return _tester


func config_gut(gut):
	return _apply_options(options, gut)


func load_options(path):
	return _load_options_from_config_file(path, options)

func load_panel_options(path):
	options['panel_options'] = default_panel_options.duplicate()
	return _load_options_from_config_file(path, options)

func load_options_no_defaults(path):
	options = _null_copy(default_options)
	return _load_options_from_config_file(path, options)

func apply_options(gut):
	_apply_options(options, gut)

--- Start of ./addons/gut/gut.gd ---

# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# View the readme at https://github.com/bitwes/Gut/blob/master/README.md for usage details.
# You should also check out the github wiki at: https://github.com/bitwes/Gut/wiki
# ##############################################################################
extends Control

# -- Settings --
var _select_script = ''
var _tests_like = ''
var _inner_class_name = ''
var _should_maximize = false setget set_should_maximize, get_should_maximize
var _log_level = 1 setget set_log_level, get_log_level
var _disable_strict_datatype_checks = false setget disable_strict_datatype_checks, is_strict_datatype_checks_disabled
var _inner_class_prefix = 'Test'
var _temp_directory = 'user://gut_temp_directory'
var _export_path = '' setget set_export_path, get_export_path
var _include_subdirectories = false setget set_include_subdirectories, get_include_subdirectories
var _double_strategy = 1  setget set_double_strategy, get_double_strategy
var _pre_run_script = '' setget set_pre_run_script, get_pre_run_script
var _post_run_script = '' setget set_post_run_script, get_post_run_script
var _color_output = false setget set_color_output, get_color_output
var _junit_xml_file = '' setget set_junit_xml_file, get_junit_xml_file
var _junit_xml_timestamp = false setget set_junit_xml_timestamp, get_junit_xml_timestamp
var _add_children_to = self setget set_add_children_to, get_add_children_to
# -- End Settings --


# ###########################
# Other Vars
# ###########################
const LOG_LEVEL_FAIL_ONLY = 0
const LOG_LEVEL_TEST_AND_FAILURES = 1
const LOG_LEVEL_ALL_ASSERTS = 2
const WAITING_MESSAGE = '/# waiting #/'
const PAUSE_MESSAGE = '/# Pausing.  Press continue button...#/'
const COMPLETED = 'completed'

# use a class as a sentinel value since it can be used in expressions that require a const value
class YIELD_FROM_OBJ:
	pass

var _utils = load('res://addons/gut/utils.gd').get_instance()
var _lgr = _utils.get_logger()
var _strutils = _utils.Strutils.new()
# Used to prevent multiple messages for deprecated setup/teardown messages
var _deprecated_tracker = _utils.ThingCounter.new()

# The instance that is created from _pre_run_script.  Accessible from
# get_pre_run_script_instance.
var _pre_run_script_instance = null
var _post_run_script_instance = null # This is not used except in tests.


var _script_name = null
var _test_collector = _utils.TestCollector.new()

# The instanced scripts.  This is populated as the scripts are run.
var _test_script_objects = []

var _waiting = false
var _done = false
var _is_running = false

var _current_test = null
var _log_text = ""

var _pause_before_teardown = false
# when true _pause_before_teardown will be ignored.  useful
# when batch processing and you don't want to watch.
var _ignore_pause_before_teardown = false
var _wait_timer = Timer.new()

var _yield_between = {
	should = false,
	timer = Timer.new(),
	after_x_tests = 5,
	tests_since_last_yield = 0
}

var _was_yield_method_called = false
# used when yielding to gut instead of some other
# signal.  Start with set_yield_time()
var _yield_timer = Timer.new()
var _yield_frames = 0

var _unit_test_name = ''
var _new_summary = null

var _yielding_to = {
	obj = null,
	signal_name = ''
}

var _stubber = _utils.Stubber.new()
var _doubler = _utils.Doubler.new()
var _spy = _utils.Spy.new()
var _gui = null
var _orphan_counter =  _utils.OrphanCounter.new()
var _autofree = _utils.AutoFree.new()

# This is populated by test.gd each time a paramterized test is encountered
# for the first time.
var _parameter_handler = null

# Used to cancel importing scripts if an error has occurred in the setup.  This
# prevents tests from being run if they were exported and ensures that the
# error displayed is seen since importing generates a lot of text.
var _cancel_import = false

# Used for proper assert tracking and printing during before_all
var _before_all_test_obj = load('res://addons/gut/test_collector.gd').Test.new()
# Used for proper assert tracking and printing during after_all
var _after_all_test_obj = load('res://addons/gut/test_collector.gd').Test.new()


var _file_prefix = 'test_'
const SIGNAL_TESTS_FINISHED = 'tests_finished'
const SIGNAL_STOP_YIELD_BEFORE_TEARDOWN = 'stop_yield_before_teardown'

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
var  _should_print_versions = true # used to cut down on output in tests.


func _init():
	_before_all_test_obj.name = 'before_all'
	_after_all_test_obj.name = 'after_all'
	# When running tests for GUT itself, _utils has been setup to always return
	# a new logger so this does not set the gut instance on the base logger
	# when creating test instances of GUT.
	_lgr.set_gut(self)

	add_user_signal(SIGNAL_TESTS_FINISHED)
	add_user_signal('test_finished')
	add_user_signal(SIGNAL_STOP_YIELD_BEFORE_TEARDOWN)
	add_user_signal('timeout')

	_doubler.set_output_dir(_temp_directory)
	_doubler.set_stubber(_stubber)
	_doubler.set_spy(_spy)
	_doubler.set_gut(self)

	# TODO remove these, universal logger should fix this.
	_doubler.set_logger(_lgr)
	_spy.set_logger(_lgr)
	_stubber.set_logger(_lgr)
	_test_collector.set_logger(_lgr)

	_gui = load('res://addons/gut/GutScene.tscn').instance()


func _physics_process(delta):
	if(_yield_frames > 0):
		_yield_frames -= 1

		if(_yield_frames <= 0):
			emit_signal('timeout')

# ------------------------------------------------------------------------------
# Initialize controls
# ------------------------------------------------------------------------------
func _ready():
	if(!_utils.is_version_ok()):
		_print_versions()
		push_error(_utils.get_bad_version_text())
		print('Error:  ', _utils.get_bad_version_text())
		get_tree().quit()
		return

	if(_should_print_versions):
		_lgr.info(str('using [', OS.get_user_data_dir(), '] for temporary output.'))

	set_process_input(true)

	add_child(_wait_timer)
	_wait_timer.set_wait_time(1)
	_wait_timer.set_one_shot(true)

	add_child(_yield_between.timer)
	_wait_timer.set_one_shot(true)

	add_child(_yield_timer)
	_yield_timer.set_one_shot(true)
	_yield_timer.connect('timeout', self, '_yielding_callback')

	_setup_gui()

	if(_select_script != null):
		select_script(_select_script)

	if(_tests_like != null):
		set_unit_test_name(_tests_like)

	if(_should_maximize):
		# GUI checks for is_in_tree will not pass yet.
		call_deferred('maximize')

	# hide the panel that IS gut so that only the GUI is seen
	self.self_modulate = Color(1,1,1,0)
	show()
	_print_versions()

# ------------------------------------------------------------------------------
# Runs right before free is called.  Can't override `free`.
# ------------------------------------------------------------------------------
func _notification(what):
	if(what == NOTIFICATION_PREDELETE):
		for test_script in _test_script_objects:
			if(is_instance_valid(test_script)):
				test_script.free()

		_test_script_objects = []

		if(is_instance_valid(_gui)):
			_gui.free()

func _print_versions(send_all = true):
	if(!_should_print_versions):
		return

	var info = _utils.get_version_text()

	if(send_all):
		p(info)
	else:
		var printer = _lgr.get_printer('gui')
		printer.send(info + "\n")


# ##############################################################################
#
# GUI Events and setup
#
# ##############################################################################
func _setup_gui():
	# This is how we get the size of the control to translate to the gui when
	# the scene is run.  This is also another reason why the min_rect_size
	# must match between both gut and the gui.
	_gui.rect_size = self.rect_size
	add_child(_gui)
	_gui.set_anchor(MARGIN_RIGHT, ANCHOR_END)
	_gui.set_anchor(MARGIN_BOTTOM, ANCHOR_END)
	_gui.connect('run_single_script', self, '_on_run_one')
	_gui.connect('run_script', self, '_on_new_gui_run_script')
	_gui.connect('end_pause', self, '_on_new_gui_end_pause')
	_gui.connect('ignore_pause', self, '_on_new_gui_ignore_pause')
	_gui.connect('log_level_changed', self, '_on_log_level_changed')
	var _foo = connect('tests_finished', _gui, 'end_run')

func _add_scripts_to_gui():
	var scripts = []
	for i in range(_test_collector.scripts.size()):
		var s = _test_collector.scripts[i]
		var txt = ''
		if(s.has_inner_class()):
			txt = str(' - ', s.inner_class_name, ' (', s.tests.size(), ')')
		else:
			txt = str(s.get_full_name(), '  (', s.tests.size(), ')')
		scripts.append(txt)
	_gui.set_scripts(scripts)

func _on_run_one(index):
	clear_text()
	var indexes = [index]
	if(!_test_collector.scripts[index].has_inner_class()):
		indexes = _get_indexes_matching_path(_test_collector.scripts[index].path)
	_test_the_scripts(indexes)

func _on_new_gui_run_script(index):
	var indexes = []
	clear_text()
	for i in range(index, _test_collector.scripts.size()):
		indexes.append(i)
	_test_the_scripts(indexes)

func _on_new_gui_end_pause():
	_pause_before_teardown = false
	emit_signal(SIGNAL_STOP_YIELD_BEFORE_TEARDOWN)

func _on_new_gui_ignore_pause(should):
	_ignore_pause_before_teardown = should

func _on_log_level_changed(value):
	set_log_level(value)

#####################
#
# Events
#
#####################

# ------------------------------------------------------------------------------
# Timeout for the built in timer.  emits the timeout signal.  Start timer
# with set_yield_time()
#
# signal_watcher._on_watched_signal supports up to 9 additional arguments.
# This is the most number of parameters GUT supports on signals.  The comment
# on _on_watched_signal explains reasoning.
# ------------------------------------------------------------------------------
func _yielding_callback(
		__arg1=null, __arg2=null, __arg3=null,
		__arg4=null, __arg5=null, __arg6=null,
		__arg7=null, __arg8=null, __arg9=null,
		# one extra for the sentinel
		__arg10=null):
	var args = [
		__arg1, __arg2, __arg3, __arg4, __arg5,
		__arg6, __arg7, __arg8, __arg9, __arg10
	]
	var from_obj = YIELD_FROM_OBJ in args

	_lgr.end_yield()
	if(_yielding_to.obj):
		_yielding_to.obj.call_deferred(
			"disconnect",
			_yielding_to.signal_name, self,
			'_yielding_callback')
		_yielding_to.obj = null
		_yielding_to.signal_name = ''

	_yield_timer.stop()

	if(from_obj):
		# we must yield for a little longer after the signal is emitted so that
		# the signal can propagate to other objects.  This was discovered trying
		# to assert that obj/signal_name was emitted.  Without this extra delay
		# the yield returns and processing finishes before the rest of the
		# objects can get the signal.  This works b/c the timer will timeout
		# and come back into this method but from_obj will be false.
		_yield_timer.set_wait_time(.1)
		_yield_timer.start()
	else:
		emit_signal('timeout')

# ------------------------------------------------------------------------------
# completed signal for GDScriptFucntionState returned from a test script that
# has yielded
# ------------------------------------------------------------------------------
func _on_test_script_yield_completed():
	_waiting = false

#####################
#
# Private
#
#####################
func _log_test_children_warning(test_script):
	if(!_lgr.is_type_enabled(_lgr.types.orphan)):
		return

	var kids = test_script.get_children()
	if(kids.size() > 0):
		var msg = ''
		if(_log_level == 2):
			msg = "Test script still has children when all tests finisehd.\n"
			for i in range(kids.size()):
				msg += str("  ", _strutils.type2str(kids[i]), "\n")
			msg += "You can use autofree, autoqfree, add_child_autofree, or add_child_autoqfree to automatically free objects."
		else:
			msg = str("Test script has ", kids.size(), " unfreed children.  Increase log level for more details.")


		_lgr.warn(msg)

# ------------------------------------------------------------------------------
# Convert the _summary dictionary into text
# ------------------------------------------------------------------------------
func _print_summary():
	_lgr.log("\n\n*** Run Summary ***", _lgr.fmts.yellow)

	_new_summary.log_summary_text(_lgr)

	var logger_text = ''
	if(_lgr.get_errors().size() > 0):
		logger_text += str("\n* ", _lgr.get_errors().size(), ' Errors.')
	if(_lgr.get_warnings().size() > 0):
		logger_text += str("\n* ", _lgr.get_warnings().size(), ' Warnings.')
	if(_lgr.get_deprecated().size() > 0):
		logger_text += str("\n* ", _lgr.get_deprecated().size(), ' Deprecated calls.')
	if(logger_text != ''):
		logger_text = "\nWarnings/Errors:" + logger_text + "\n\n"
	_lgr.log(logger_text)

	if(_new_summary.get_totals().tests > 0):
		var fmt = _lgr.fmts.green
		var msg = str(_new_summary.get_totals().passing_tests) + ' passed ' + str(_new_summary.get_totals().failing_tests) + ' failed.  ' + \
			str("Tests finished in ", _gui.elapsed_time_as_str())
		if(_new_summary.get_totals().failing > 0):
			fmt = _lgr.fmts.red
		elif(_new_summary.get_totals().pending > 0):
			fmt = _lgr.fmts.yellow

		_lgr.log(msg, fmt)
	else:
		_lgr.log('No tests ran', _lgr.fmts.red)


func _validate_hook_script(path):
	var result = {
		valid = true,
		instance = null
	}

	# empty path is valid but will have a null instance
	if(path == ''):
		return result

	var f = File.new()
	if(f.file_exists(path)):
		var inst = load(path).new()
		if(inst and inst is _utils.HookScript):
			result.instance = inst
			result.valid = true
		else:
			result.valid = false
			_lgr.error('The hook script [' + path + '] does not extend GutHookScript')
	else:
		result.valid = false
		_lgr.error('The hook script [' + path + '] does not exist.')

	return result


# ------------------------------------------------------------------------------
# Runs a hook script.  Script must exist, and must extend
# res://addons/gut/hook_script.gd
# ------------------------------------------------------------------------------
func _run_hook_script(inst):
	if(inst != null):
		inst.gut = self
		inst.run()
	return inst

# ------------------------------------------------------------------------------
# Initialize variables for each run of a single test script.
# ------------------------------------------------------------------------------
func _init_run():
	var valid = true
	_test_collector.set_test_class_prefix(_inner_class_prefix)
	_test_script_objects = []
	_new_summary = _utils.Summary.new()

	_log_text = ""

	_current_test = null

	_is_running = true

	_yield_between.tests_since_last_yield = 0

	var pre_hook_result = _validate_hook_script(_pre_run_script)
	_pre_run_script_instance = pre_hook_result.instance
	var post_hook_result = _validate_hook_script(_post_run_script)
	_post_run_script_instance  = post_hook_result.instance

	valid = pre_hook_result.valid and  post_hook_result.valid

	return valid


# ------------------------------------------------------------------------------
# Print out run information and close out the run.
# ------------------------------------------------------------------------------
func _end_run():
	_gui.end_run()
	_print_summary()
	p("\n")

	# Do not count any of the _test_script_objects since these will be released
	# when GUT is released.
	_orphan_counter._counters.total += _test_script_objects.size()
	if(_orphan_counter.get_counter('total') > 0 and _lgr.is_type_enabled('orphan')):
		_orphan_counter.print_orphans('total', _lgr)
		p("Note:  This count does not include GUT objects that will be freed upon exit.")
		p("       It also does not include any orphans created by global scripts")
		p("       loaded before tests were ran.")
		p(str("Total orphans = ", _orphan_counter.orphan_count()))

	if(!_utils.is_null_or_empty(_select_script)):
		p('Ran Scripts matching "' + _select_script + '"')
	if(!_utils.is_null_or_empty(_unit_test_name)):
		p('Ran Tests matching "' + _unit_test_name + '"')
	if(!_utils.is_null_or_empty(_inner_class_name)):
		p('Ran Inner Classes matching "' + _inner_class_name + '"')

	# For some reason the text edit control isn't scrolling to the bottom after
	# the summary is printed.  As a workaround, yield for a short time and
	# then move the cursor.  I found this workaround through trial and error.
	_yield_between.timer.set_wait_time(0.1)
	_yield_between.timer.start()
	yield(_yield_between.timer, 'timeout')
	_gui.scroll_to_bottom()

	_is_running = false
	update()
	_run_hook_script(_post_run_script_instance)
	_export_results()
	emit_signal(SIGNAL_TESTS_FINISHED)

	if _utils.should_display_latest_version:
		p("")
		p(str("GUT version ",_utils.latest_version," is now available."))

	_gui.set_title("Finished.")
	_gui.compact_mode(false)


# ------------------------------------------------------------------------------
# Add additional export types here.
# ------------------------------------------------------------------------------
func _export_results():
	if(_junit_xml_file != ''):
		_export_junit_xml()

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func _export_junit_xml():
	var exporter = _utils.JunitXmlExport.new()
	var output_file = _junit_xml_file

	if(_junit_xml_timestamp):
		var ext = "." + output_file.get_extension()
		output_file = output_file.replace(ext, str("_", OS.get_unix_time(), ext))

	var f_result = exporter.write_file(self, output_file)
	if(f_result == OK):
		p(str("Results saved to ", output_file))



# ------------------------------------------------------------------------------
# Checks the passed in thing to see if it is a "function state" object that gets
# returned when a function yields.
# ------------------------------------------------------------------------------
func _is_function_state(script_result):
	return script_result != null and \
		   typeof(script_result) == TYPE_OBJECT and \
		   script_result is GDScriptFunctionState and \
		   script_result.is_valid()

# ------------------------------------------------------------------------------
# Print out the heading for a new script
# ------------------------------------------------------------------------------
func _print_script_heading(script):
	if(_does_class_name_match(_inner_class_name, script.inner_class_name)):
		var fmt = _lgr.fmts.underline
		var divider = '-----------------------------------------'

		var text = ''
		if(script.inner_class_name == null):
			text = script.path
		else:
			text = script.path + '.' + script.inner_class_name
		_lgr.log("\n\n" + text, fmt)


# ------------------------------------------------------------------------------
# Just gets more logic out of _test_the_scripts.  Decides if we should yield after
# this test based on flags and counters.
# ------------------------------------------------------------------------------
func _should_yield_now():
	var should = _yield_between.should and \
				 _yield_between.tests_since_last_yield == _yield_between.after_x_tests
	if(should):
		_yield_between.tests_since_last_yield = 0
	else:
		_yield_between.tests_since_last_yield += 1
	return should

# ------------------------------------------------------------------------------
# Yes if the class name is null or the script's class name includes class_name
# ------------------------------------------------------------------------------
func _does_class_name_match(the_class_name, script_class_name):
	return (the_class_name == null or the_class_name == '') or (script_class_name != null and script_class_name.findn(the_class_name) != -1)

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func _setup_script(test_script):
	test_script.gut = self
	test_script.set_logger(_lgr)
	_add_children_to.add_child(test_script)
	_test_script_objects.append(test_script)


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func _do_yield_between(frames=2):
	_yield_frames = frames
	return self


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func _wait_for_done(result):
	# callback method sets waiting to false.
	result.connect(COMPLETED, self, '_on_test_script_yield_completed')
	if(!_was_yield_method_called):
		_lgr.yield_msg('-- Yield detected, waiting --')

	_was_yield_method_called = false
	_waiting = true

	var cycles_per_dot = 500
	var cycles = 0
	var dots = ''

	while(_waiting):
		yield(get_tree(), 'idle_frame')
		cycles += 1

		if(cycles >= cycles_per_dot):
			cycles = 0
			dots += '.'
			if(dots.length() > 5):
				dots = ''
			_lgr.yield_text('waiting' + dots)

	_lgr.end_yield()


# ------------------------------------------------------------------------------
# returns self so it can be integrated into the yield call.
# ------------------------------------------------------------------------------
func _wait_for_continue_button():
	p(PAUSE_MESSAGE, 0)
	_waiting = true
	return self


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func _call_deprecated_script_method(script, method, alt):
	if(script.has_method(method)):
		var txt = str(script, '-', method)
		if(!_deprecated_tracker.has(txt)):
			# Removing the deprecated line.  I think it's still too early to
			# start bothering people with this.  Left everything here though
			# because I don't want to remember how I did this last time.
			_lgr.deprecated(str('The method ', method, ' has been deprecated, use ', alt, ' instead.'))
			_deprecated_tracker.add(txt)
		script.call(method)

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func _get_indexes_matching_script_name(name):
	var indexes = [] # empty runs all
	for i in range(_test_collector.scripts.size()):
		if(_test_collector.scripts[i].get_filename().find(name) != -1):
			indexes.append(i)
	return indexes

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func _get_indexes_matching_path(path):
	var indexes = []
	for i in range(_test_collector.scripts.size()):
		if(_test_collector.scripts[i].path == path):
			indexes.append(i)
	return indexes

# ------------------------------------------------------------------------------
# Execute all calls of a parameterized test.
# ------------------------------------------------------------------------------
func _run_parameterized_test(test_script, test_name):
	var script_result = _run_test(test_script, test_name)
	if(_current_test.assert_count == 0 and !_current_test.pending):
		_lgr.warn('Test did not assert')

	if(_is_function_state(script_result)):
		# _run_tests does _wait_for_done so just wait on it to  complete
		yield(script_result, COMPLETED)

	if(_parameter_handler == null):
		_lgr.error(str('Parameterized test ', _current_test.name, ' did not call use_parameters for the default value of the parameter.'))
		_fail(str('Parameterized test ', _current_test.name, ' did not call use_parameters for the default value of the parameter.'))
	else:
		while(!_parameter_handler.is_done()):
			var cur_assert_count = _current_test.assert_count
			script_result = _run_test(test_script, test_name)
			if(_is_function_state(script_result)):
				# _run_tests does _wait_for_done so just wait on it to  complete
				yield(script_result, COMPLETED)

			if(_current_test.assert_count == cur_assert_count and !_current_test.pending):
				_lgr.warn('Test did not assert')


	_parameter_handler = null


# ------------------------------------------------------------------------------
# Runs a single test given a test.gd instance and the name of the test to run.
# ------------------------------------------------------------------------------
func _run_test(script_inst, test_name):
	_lgr.log_test_name()
	_lgr.set_indent_level(1)
	_orphan_counter.add_counter('test')
	var script_result = null

	_call_deprecated_script_method(script_inst, 'setup', 'before_each')
	var before_each_result = script_inst.before_each()
	if(_is_function_state(before_each_result)):
		yield(_wait_for_done(before_each_result), COMPLETED)

	# When the script yields it will return a GDScriptFunctionState object
	script_result = script_inst.call(test_name)
	var test_summary = _new_summary.add_test(test_name)

	# Cannot detect future yields since we never tell the method to resume.  If
	# there was some way to tell the method to resume we could use what comes
	# back from that to detect additional yields.  I don't think this is
	# possible since we only know what the yield was for except when yield_for
	# and yield_to are used.
	if(_is_function_state(script_result)):
		yield(_wait_for_done(script_result), COMPLETED)

	# if the test called pause_before_teardown then yield until
	# the continue button is pressed.
	if(_pause_before_teardown and !_ignore_pause_before_teardown):
		_gui.pause()
		yield(_wait_for_continue_button(), SIGNAL_STOP_YIELD_BEFORE_TEARDOWN)

	script_inst.clear_signal_watcher()

	# call each post-each-test method until teardown is removed.
	_call_deprecated_script_method(script_inst, 'teardown', 'after_each')
	var after_each_result = script_inst.after_each()
	if(_is_function_state(after_each_result)):
		yield(_wait_for_done(after_each_result), COMPLETED)

	# Free up everything in the _autofree.  Yield for a bit if we
	# have anything with a queue_free so that they have time to
	# free and are not found by the orphan counter.
	var aqf_count = _autofree.get_queue_free_count()
	_autofree.free_all()
	if(aqf_count > 0):
		yield(_do_yield_between(), 'timeout')

	test_summary.orphans = _orphan_counter.get_counter('test')
	if(_log_level > 0):
		_orphan_counter.print_orphans('test', _lgr)

	_doubler.get_ignored_methods().clear()

# ------------------------------------------------------------------------------
# Calls after_all on the passed in test script and takes care of settings so all
# logger output appears indented and with a proper heading
#
# Calls both pre-all-tests methods until prerun_setup is removed
# ------------------------------------------------------------------------------
func _call_before_all(test_script):
	_current_test = _before_all_test_obj
	_current_test.has_printed_name = false
	_lgr.inc_indent()

	# Next 3 lines can be removed when prerun_setup removed.
	_current_test.name = 'prerun_setup'
	_call_deprecated_script_method(test_script, 'prerun_setup', 'before_all')
	_current_test.name = 'before_all'

	var result = test_script.before_all()
	if(_is_function_state(result)):
		yield(_wait_for_done(result), COMPLETED)

	_lgr.dec_indent()
	_current_test = null

# ------------------------------------------------------------------------------
# Calls after_all on the passed in test script and takes care of settings so all
# logger output appears indented and with a proper heading
#
# Calls both post-all-tests methods until postrun_teardown is removed.
# ------------------------------------------------------------------------------
func _call_after_all(test_script):
	_current_test = _after_all_test_obj
	_current_test.has_printed_name = false
	_lgr.inc_indent()

	# Next 3 lines can be removed when postrun_teardown removed.
	_current_test.name = 'postrun_teardown'
	_call_deprecated_script_method(test_script, 'postrun_teardown', 'after_all')
	_current_test.name = 'after_all'

	var result = test_script.after_all()
	if(_is_function_state(result)):
		yield(_wait_for_done(result), COMPLETED)


	_lgr.dec_indent()
	_current_test = null

# ------------------------------------------------------------------------------
# Run all tests in a script.  This is the core logic for running tests.
# ------------------------------------------------------------------------------
func _test_the_scripts(indexes=[]):
	_orphan_counter.add_counter('total')

	_print_versions(false)
	var is_valid = _init_run()
	if(!is_valid):
		_lgr.error('Something went wrong and the run was aborted.')
		return

	_run_hook_script(_pre_run_script_instance)
	if(_pre_run_script_instance!= null and _pre_run_script_instance.should_abort()):
		_lgr.error('pre-run abort')
		emit_signal(SIGNAL_TESTS_FINISHED)
		return

	_gui.run_mode()

	var indexes_to_run = []
	if(indexes.size()==0):
		for i in range(_test_collector.scripts.size()):
			indexes_to_run.append(i)
	else:
		indexes_to_run = indexes

	_gui.set_progress_script_max(indexes_to_run.size()) # New way
	_gui.set_progress_script_value(0)

	if(_doubler.get_strategy() == _utils.DOUBLE_STRATEGY.FULL):
		_lgr.info("Using Double Strategy FULL as default strategy.  Keep an eye out for weirdness, this is still experimental.")

	# loop through scripts
	for test_indexes in range(indexes_to_run.size()):
		var the_script = _test_collector.scripts[indexes_to_run[test_indexes]]
		_orphan_counter.add_counter('script')

		if(the_script.tests.size() > 0):
			_gui.set_script_path(the_script.get_full_name())
			_lgr.set_indent_level(0)
			_print_script_heading(the_script)
		_new_summary.add_script(the_script.get_full_name())

		var test_script = the_script.get_new()
		var script_result = null
		_setup_script(test_script)
		_doubler.set_strategy(_double_strategy)

		# yield between test scripts so things paint
		if(_yield_between.should):
			yield(_do_yield_between(), 'timeout')

		# !!!
		# Hack so there isn't another indent to this monster of a method.  if
		# inner class is set and we do not have a match then empty the tests
		# for the current test.
		# !!!
		if(!_does_class_name_match(_inner_class_name, the_script.inner_class_name)):
			the_script.tests = []
		else:
			var before_all_result = _call_before_all(test_script)
			if(_is_function_state(before_all_result)):
				# _call_before_all calls _wait for done, just wait for that to finish
				yield(before_all_result, COMPLETED)


		_gui.set_progress_test_max(the_script.tests.size()) # New way

		# Each test in the script
		for i in range(the_script.tests.size()):
			_stubber.clear()
			_spy.clear()
			_doubler.clear_output_directory()
			_current_test = the_script.tests[i]
			script_result = null

			if((_unit_test_name != '' and _current_test.name.find(_unit_test_name) > -1) or
				(_unit_test_name == '')):

				# yield so things paint
				if(_should_yield_now()):
					yield(_do_yield_between(), 'timeout')

				if(_current_test.arg_count > 1):
					_lgr.error(str('Parameterized test ', _current_test.name,
						' has too many parameters:  ', _current_test.arg_count, '.'))
				elif(_current_test.arg_count == 1):
					script_result = _run_parameterized_test(test_script, _current_test.name)
				else:
					script_result = _run_test(test_script, _current_test.name)

				if(_is_function_state(script_result)):
					# _run_test calls _wait for done, just wait for that to finish
					yield(script_result, COMPLETED)

				if(!_current_test.did_assert()):
					_lgr.warn('Test did not assert')

				_gui.add_test(_current_test.did_pass())

				_current_test.has_printed_name = false
				_gui.set_progress_test_value(i + 1)
				emit_signal('test_finished')


		_current_test = null
		_lgr.dec_indent()
		_orphan_counter.print_orphans('script', _lgr)

		if(_does_class_name_match(_inner_class_name, the_script.inner_class_name)):
			var after_all_result = _call_after_all(test_script)
			if(_is_function_state(after_all_result)):
				# _call_after_all calls _wait for done, just wait for that to finish
				yield(after_all_result, COMPLETED)


		_log_test_children_warning(test_script)
		# This might end up being very resource intensive if the scripts
		# don't clean up after themselves.  Might have to consolidate output
		# into some other structure and kill the script objects with
		# test_script.free() instead of remove child.
		_add_children_to.remove_child(test_script)

		_lgr.set_indent_level(0)
		if(test_script.get_assert_count() > 0):
			var script_sum = str(test_script.get_pass_count(), '/', test_script.get_assert_count(), ' passed.')
			_lgr.log(script_sum, _lgr.fmts.bold)

		_gui.set_progress_script_value(test_indexes + 1) # new way
		# END TEST SCRIPT LOOP

	_lgr.set_indent_level(0)
	_end_run()


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func _pass(text=''):
	_gui.add_passing() # increments counters
	if(_current_test):
		_current_test.assert_count += 1
		_new_summary.add_pass(_current_test.name, text)
	else:
		if(_new_summary != null): # b/c of tests.
			_new_summary.add_pass('script level', text)


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func _fail(text=''):
	_gui.add_failing() # increments counters
	if(_current_test != null):
		var line_number = _extract_line_number(_current_test)
		var line_text = '  at line ' + str(line_number)
		p(line_text, LOG_LEVEL_FAIL_ONLY)
		# format for summary
		line_text =  "\n    " + line_text
		var call_count_text = ''
		if(_parameter_handler != null):
			call_count_text = str('(call #', _parameter_handler.get_call_count(), ') ')
		_new_summary.add_fail(_current_test.name, call_count_text + text + line_text)
		_current_test.passed = false
		_current_test.assert_count += 1
		_current_test.line_number = line_number
	else:
		if(_new_summary != null): # b/c of tests.
			_new_summary.add_fail('script level', text)


# ------------------------------------------------------------------------------
# Extracts the line number from curren stacktrace by matching the test case name
# ------------------------------------------------------------------------------
func _extract_line_number(current_test):
	var line_number = -1
	# if stack trace available than extraxt the test case line number
	var stackTrace = get_stack()
	if(stackTrace!=null):
		for index in stackTrace.size():
			var line = stackTrace[index]
			var function = line.get("function")
			if function == current_test.name:
				line_number = line.get("line")
	return line_number


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func _pending(text=''):
	if(_current_test):
		_current_test.pending = true
		_new_summary.add_pending(_current_test.name, text)


# ------------------------------------------------------------------------------
# Gets all the files in a directory and all subdirectories if get_include_subdirectories
# is true.  The files returned are all sorted by name.
# ------------------------------------------------------------------------------
func _get_files(path, prefix, suffix):
	var files = []
	var directories = []
	# ignore addons/gut per issue 294
	if(path == 'res://addons/gut'):
		return [];

	var d = Directory.new()
	d.open(path)
	# true parameter tells list_dir_begin not to include "." and ".." directories.
	d.list_dir_begin(true)

	# Traversing a directory is kinda odd.  You have to start the process of listing
	# the contents of a directory with list_dir_begin then use get_next until it
	# returns an empty string.  Then I guess you should end it.
	var fs_item = d.get_next()
	var full_path = ''
	while(fs_item != ''):
		full_path = path.plus_file(fs_item)

		#file_exists returns fasle for directories
		if(d.file_exists(full_path)):
			if(fs_item.begins_with(prefix) and fs_item.ends_with(suffix)):
				files.append(full_path)
		elif(get_include_subdirectories() and d.dir_exists(full_path)):
			directories.append(full_path)

		fs_item = d.get_next()
	d.list_dir_end()

	for dir in range(directories.size()):
		var dir_files = _get_files(directories[dir], prefix, suffix)
		for i in range(dir_files.size()):
			files.append(dir_files[i])

	files.sort()
	return files


#########################
#
# public
#
#########################

# ------------------------------------------------------------------------------
# Conditionally prints the text to the console/results variable based on the
# current log level and what level is passed in.  Whenever currently in a test,
# the text will be indented under the test.  It can be further indented if
# desired.
#
# The first time output is generated when in a test, the test name will be
# printed.
#
# NOT_USED_ANYMORE was indent level.  This was deprecated in 7.0.0.
# ------------------------------------------------------------------------------
func p(text, level=0, NOT_USED_ANYMORE=-123):
	if(NOT_USED_ANYMORE != -123):
		_lgr.deprecated('gut.p no longer supports the optional 3rd parameter for indent_level parameter.')
	var str_text = str(text)

	if(level <= _utils.nvl(_log_level, 0)):
		_lgr.log(str_text)

################
#
# RUN TESTS/ADD SCRIPTS
#
################
func get_minimum_size():
	return Vector2(810, 380)


# ------------------------------------------------------------------------------
# Runs all the scripts that were added using add_script
# ------------------------------------------------------------------------------
func test_scripts(run_rest=false):
	clear_text()

	if(_script_name != null and _script_name != ''):
		var indexes = _get_indexes_matching_script_name(_script_name)
		if(indexes == []):
			_lgr.error(str(
				"Could not find script matching '", _script_name, "'.\n",
				"Check your directory settings and Script Prefix/Suffix settings."))
		else:
			_test_the_scripts(indexes)
	else:
		_test_the_scripts([])

# alias
func run_tests(run_rest=false):
	test_scripts(run_rest)


# ------------------------------------------------------------------------------
# Runs a single script passed in.
# ------------------------------------------------------------------------------
func test_script(script):
	_test_collector.set_test_class_prefix(_inner_class_prefix)
	_test_collector.clear()
	_test_collector.add_script(script)
	_test_the_scripts()


# ------------------------------------------------------------------------------
# Adds a script to be run when test_scripts called.
# ------------------------------------------------------------------------------
func add_script(script):
	if(!Engine.is_editor_hint()):
		_test_collector.set_test_class_prefix(_inner_class_prefix)
		_test_collector.add_script(script)
		_add_scripts_to_gui()


# ------------------------------------------------------------------------------
# Add all scripts in the specified directory that start with the prefix and end
# with the suffix.  Does not look in sub directories.  Can be called multiple
# times.
# ------------------------------------------------------------------------------
func add_directory(path, prefix=_file_prefix, suffix=".gd"):
	# check for '' b/c the calls to addin the exported directories 1-6 will pass
	# '' if the field has not been populated.  This will cause res:// to be
	# processed which will include all files if include_subdirectories is true.
	if(path == '' or path == null):
		return

	var d = Directory.new()
	if(!d.dir_exists(path)):
		_lgr.error(str('The path [', path, '] does not exist.'))
		OS.exit_code = 1
	else:
		var files = _get_files(path, prefix, suffix)
		for i in range(files.size()):
			if(_script_name == null or _script_name == '' or \
					(_script_name != null and files[i].findn(_script_name) != -1)):
				add_script(files[i])


# ------------------------------------------------------------------------------
# This will try to find a script in the list of scripts to test that contains
# the specified script name.  It does not have to be a full match.  It will
# select the first matching occurrence so that this script will run when run_tests
# is called.  Works the same as the select_this_one option of add_script.
#
# returns whether it found a match or not
# ------------------------------------------------------------------------------
func select_script(script_name):
	_script_name = script_name
	_select_script = script_name


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func export_tests(path=_export_path):
	if(path == null):
		_lgr.error('You must pass a path or set the export_path before calling export_tests')
	else:
		var result = _test_collector.export_tests(path)
		if(result):
			p(_test_collector.to_s())
			p("Exported to " + path)


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func import_tests(path=_export_path):
	if(!_utils.file_exists(path)):
		_lgr.error(str('Cannot import tests:  the path [', path, '] does not exist.'))
	else:
		_test_collector.clear()
		var result = _test_collector.import_tests(path)
		if(result):
			p(_test_collector.to_s())
			p("Imported from " + path)
			_add_scripts_to_gui()


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func import_tests_if_none_found():
	if(!_cancel_import and _test_collector.scripts.size() == 0):
		import_tests()


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func export_if_tests_found():
	if(_test_collector.scripts.size() > 0):
		export_tests()

################
#
# MISC
#
################


# ------------------------------------------------------------------------------
# Maximize test runner window to fit the viewport.
# ------------------------------------------------------------------------------
func set_should_maximize(should):
	_should_maximize = should

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_should_maximize():
	return _should_maximize

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func maximize():
	_gui.maximize()

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func disable_strict_datatype_checks(should):
	_disable_strict_datatype_checks = should

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func is_strict_datatype_checks_disabled():
	return _disable_strict_datatype_checks

# ------------------------------------------------------------------------------
# Pauses the test and waits for you to press a confirmation button.  Useful when
# you want to watch a test play out onscreen or inspect results.
# ------------------------------------------------------------------------------
func end_yielded_test():
	_lgr.deprecated('end_yielded_test is no longer necessary, you can remove it.')

# ------------------------------------------------------------------------------
# Clears the text of the text box.  This resets all counters.
# ------------------------------------------------------------------------------
func clear_text():
	_gui.clear_text()
	update()

# ------------------------------------------------------------------------------
# Get the number of tests that were ran
# ------------------------------------------------------------------------------
func get_test_count():
	return _new_summary.get_totals().tests

# ------------------------------------------------------------------------------
# Get the number of assertions that were made
# ------------------------------------------------------------------------------
func get_assert_count():
	var t = _new_summary.get_totals()
	return t.passing + t.failing

# ------------------------------------------------------------------------------
# Get the number of assertions that passed
# ------------------------------------------------------------------------------
func get_pass_count():
	return _new_summary.get_totals().passing

# ------------------------------------------------------------------------------
# Get the number of assertions that failed
# ------------------------------------------------------------------------------
func get_fail_count():
	return _new_summary.get_totals().failing

# ------------------------------------------------------------------------------
# Get the number of tests flagged as pending
# ------------------------------------------------------------------------------
func get_pending_count():
	return _new_summary.get_totals().pending

# ------------------------------------------------------------------------------
# Get the results of all tests ran as text.  This string is the same as is
# displayed in the text box, and similar to what is printed to the console.
# ------------------------------------------------------------------------------
func get_result_text():
	return _log_text

# ------------------------------------------------------------------------------
# Set the log level.  Use one of the various LOG_LEVEL_* constants.
# ------------------------------------------------------------------------------
func set_log_level(level):
	_log_level = max(level, 0)

	# Level 0 settings
	_lgr.set_less_test_names(level == 0)
	# Explicitly always enabled
	_lgr.set_type_enabled(_lgr.types.normal, true)
	_lgr.set_type_enabled(_lgr.types.error, true)
	_lgr.set_type_enabled(_lgr.types.pending, true)

	# Level 1 types
	_lgr.set_type_enabled(_lgr.types.warn, level > 0)
	_lgr.set_type_enabled(_lgr.types.deprecated, level > 0)

	# Level 2 types
	_lgr.set_type_enabled(_lgr.types.passed, level > 1)
	_lgr.set_type_enabled(_lgr.types.info, level > 1)
	_lgr.set_type_enabled(_lgr.types.debug, level > 1)

	if(!Engine.is_editor_hint()):
		_gui.set_log_level(level)

# ------------------------------------------------------------------------------
# Get the current log level.
# ------------------------------------------------------------------------------
func get_log_level():
	return _log_level

# ------------------------------------------------------------------------------
# Call this method to make the test pause before teardown so that you can inspect
# anything that you have rendered to the screen.
# ------------------------------------------------------------------------------
func pause_before_teardown():
	_pause_before_teardown = true;

# ------------------------------------------------------------------------------
# For batch processing purposes, you may want to ignore any calls to
# pause_before_teardown that you forgot to remove.
# ------------------------------------------------------------------------------
func set_ignore_pause_before_teardown(should_ignore):
	_ignore_pause_before_teardown = should_ignore
	_gui.set_ignore_pause(should_ignore)

func get_ignore_pause_before_teardown():
	return _ignore_pause_before_teardown

# ------------------------------------------------------------------------------
# Set to true so that painting of the screen will occur between tests.  Allows you
# to see the output as tests occur.  Especially useful with long running tests that
# make it appear as though it has humg.
#
# NOTE:  not compatible with 1.0 so this is disabled by default.  This will
# change in future releases.
# ------------------------------------------------------------------------------
func set_yield_between_tests(should):
	_yield_between.should = should

func get_yield_between_tests():
	return _yield_between.should

# ------------------------------------------------------------------------------
# Simulate a number of frames by calling '_process' and '_physics_process' (if
# the methods exist) on an object and all of its descendents. The specified frame
# time, 'delta', will be passed to each simulated call.
#
# NOTE: Objects can disable their processing methods using 'set_process(false)' and
# 'set_physics_process(false)'. This is reflected in the 'Object' methods
# 'is_processing()' and 'is_physics_processing()', respectively. To make 'simulate'
# respect this status, for example if you are testing an object which toggles
# processing, pass 'check_is_processing' as 'true'.
# ------------------------------------------------------------------------------
func simulate(obj, times, delta, check_is_processing: bool = false):
	for _i in range(times):
		if (
			obj.has_method("_process")
			and (
				not check_is_processing
				or obj.is_processing()
			)
		):
			obj._process(delta)
		if(
			obj.has_method("_physics_process")
			and (
				not check_is_processing
				or obj.is_physics_processing()
			)
		):
			obj._physics_process(delta)

		for kid in obj.get_children():
			simulate(kid, 1, delta, check_is_processing)

# ------------------------------------------------------------------------------
# Starts an internal timer with a timeout of the passed in time.  A 'timeout'
# signal will be sent when the timer ends.  Returns itself so that it can be
# used in a call to yield...cutting down on lines of code.
#
# Example, yield to the Gut object for 10 seconds:
#  yield(gut.set_yield_time(10), 'timeout')
# ------------------------------------------------------------------------------
func set_yield_time(time, text=''):
	_yield_timer.set_wait_time(time)
	_yield_timer.start()
	var msg = '-- Yielding (' + str(time) + 's)'
	if(text == ''):
		msg += ' --'
	else:
		msg +=  ':  ' + text + ' --'
	_lgr.yield_msg(msg)
	_was_yield_method_called = true
	return self

# ------------------------------------------------------------------------------
# Sets a counter that is decremented each time _process is called.  When the
# counter reaches 0 the 'timeout' signal is emitted.
#
# This actually results in waiting N+1 frames since that appears to be what is
# required for _process in test.gd scripts to count N frames.
# ------------------------------------------------------------------------------
func set_yield_frames(frames, text=''):
	var msg = '-- Yielding (' + str(frames) + ' frames)'
	if(text == ''):
		msg += ' --'
	else:
		msg +=  ':  ' + text + ' --'
	_lgr.yield_msg(msg)

	_was_yield_method_called = true
	_yield_frames = max(frames + 1, 1)
	return self

# ------------------------------------------------------------------------------
# This method handles yielding to a signal from an object or a maximum
# number of seconds, whichever comes first.
# ------------------------------------------------------------------------------
func set_yield_signal_or_time(obj, signal_name, max_wait, text=''):
	obj.connect(signal_name, self, '_yielding_callback', [YIELD_FROM_OBJ])
	_yielding_to.obj = obj
	_yielding_to.signal_name = signal_name

	_yield_timer.set_wait_time(max_wait)
	_yield_timer.start()
	_was_yield_method_called = true
	_lgr.yield_msg(str('-- Yielding to signal "', signal_name, '" or for ', max_wait, ' seconds -- ', text))
	return self

# ------------------------------------------------------------------------------
# get the specific unit test that should be run
# ------------------------------------------------------------------------------
func get_unit_test_name():
	return _unit_test_name

# ------------------------------------------------------------------------------
# set the specific unit test that should be run.
# ------------------------------------------------------------------------------
func set_unit_test_name(test_name):
	_unit_test_name = test_name

# ------------------------------------------------------------------------------
# Creates an empty file at the specified path
# ------------------------------------------------------------------------------
func file_touch(path):
	var f = File.new()
	f.open(path, f.WRITE)
	f.close()

# ------------------------------------------------------------------------------
# deletes the file at the specified path
# ------------------------------------------------------------------------------
func file_delete(path):
	var d = Directory.new()
	var result = d.open(path.get_base_dir())
	if(result == OK):
		d.remove(path)

# ------------------------------------------------------------------------------
# Checks to see if the passed in file has any data in it.
# ------------------------------------------------------------------------------
func is_file_empty(path):
	var f = File.new()
	f.open(path, f.READ)
	var empty = f.get_len() == 0
	f.close()
	return empty

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_file_as_text(path):
	return _utils.get_file_as_text(path)

# ------------------------------------------------------------------------------
# deletes all files in a given directory
# ------------------------------------------------------------------------------
func directory_delete_files(path):
	var d = Directory.new()
	var result = d.open(path)

	# SHORTCIRCUIT
	if(result != OK):
		return

	# Traversing a directory is kinda odd.  You have to start the process of listing
	# the contents of a directory with list_dir_begin then use get_next until it
	# returns an empty string.  Then I guess you should end it.
	d.list_dir_begin()
	var thing = d.get_next() # could be a dir or a file or something else maybe?
	var full_path = ''
	while(thing != ''):
		full_path = path + "/" + thing
		#file_exists returns fasle for directories
		if(d.file_exists(full_path)):
			d.remove(full_path)
		thing = d.get_next()
	d.list_dir_end()

# ------------------------------------------------------------------------------
# Returns the instantiated script object that is currently being run.
# ------------------------------------------------------------------------------
func get_current_script_object():
	var to_return = null
	if(_test_script_objects.size() > 0):
		to_return = _test_script_objects[-1]
	return to_return

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_current_test_object():
	return _current_test

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_stubber():
	return _stubber

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_doubler():
	return _doubler

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_spy():
	return _spy

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_temp_directory():
	return _temp_directory

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func set_temp_directory(temp_directory):
	_temp_directory = temp_directory

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_inner_class_name():
	return _inner_class_name

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func set_inner_class_name(inner_class_name):
	_inner_class_name = inner_class_name

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_summary():
	return _new_summary

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_double_strategy():
	return _double_strategy

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func set_double_strategy(double_strategy):
	_double_strategy = double_strategy
	_doubler.set_strategy(double_strategy)

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_include_subdirectories():
	return _include_subdirectories

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_logger():
	return _lgr

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func set_logger(logger):
	_lgr = logger
	_lgr.set_gut(self)

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func set_include_subdirectories(include_subdirectories):
	_include_subdirectories = include_subdirectories

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_test_collector():
	return _test_collector

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_export_path():
	return _export_path

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func set_export_path(export_path):
	_export_path = export_path

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_version():
	return _utils.version

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_pre_run_script():
	return _pre_run_script

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func set_pre_run_script(pre_run_script):
	_pre_run_script = pre_run_script

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_post_run_script():
	return _post_run_script

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func set_post_run_script(post_run_script):
	_post_run_script = post_run_script

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_pre_run_script_instance():
	return _pre_run_script_instance

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_post_run_script_instance():
	return _post_run_script_instance

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_color_output():
	return _color_output

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func set_color_output(color_output):
	_color_output = color_output
	_lgr.disable_formatting(!color_output)

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_parameter_handler():
	return _parameter_handler

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func set_parameter_handler(parameter_handler):
	_parameter_handler = parameter_handler
	_parameter_handler.set_logger(_lgr)

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_gui():
	return _gui

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_orphan_counter():
	return _orphan_counter

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func show_orphans(should):
	_lgr.set_type_enabled(_lgr.types.orphan, should)

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_autofree():
	return _autofree


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_junit_xml_file():
	return _junit_xml_file

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func set_junit_xml_file(junit_xml_file):
	_junit_xml_file = junit_xml_file


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_junit_xml_timestamp():
	return _junit_xml_timestamp

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func set_junit_xml_timestamp(junit_xml_timestamp):
	_junit_xml_timestamp = junit_xml_timestamp

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func get_add_children_to():
	return _add_children_to

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func set_add_children_to(add_children_to):
	_add_children_to = add_children_to

--- Start of ./addons/gut/gut_plugin.gd ---

tool
extends EditorPlugin

var _bottom_panel = null


func _enter_tree():
	_bottom_panel = preload('res://addons/gut/gui/GutBottomPanel.tscn').instance()
	# Initialization of the plugin goes here
	# Add the new type with a name, a parent type, a script and an icon
	add_custom_type("Gut", "Control", preload("plugin_control.gd"), preload("icon.png"))

	var button = add_control_to_bottom_panel(_bottom_panel, 'GUT')
	button.shortcut_in_tooltip = true

	yield(get_tree().create_timer(3), 'timeout')
	_bottom_panel.set_interface(get_editor_interface())
	_bottom_panel.set_plugin(self)
	_bottom_panel.set_panel_button(button)
	_bottom_panel.load_shortcuts()


func _exit_tree():
	# Clean-up of the plugin goes here
	# Always remember to remove it from the engine when deactivated
	remove_custom_type("Gut")
	remove_control_from_bottom_panel(_bottom_panel)
	_bottom_panel.free()

--- Start of ./addons/gut/GutScene.gd ---

extends Panel

onready var _script_list = $ScriptsList
onready var _nav_container = $VBox/BottomPanel/VBox/HBox/Navigation
onready var _nav = {
	container = _nav_container,
	prev = _nav_container.get_node('VBox/HBox/Previous'),
	next = _nav_container.get_node('VBox/HBox/Next'),
	run =  _nav_container.get_node('VBox/HBox/Run'),
	current_script = _nav_container.get_node('VBox/CurrentScript'),
	run_single = _nav_container.get_node('VBox/HBox/RunSingleScript')
}

onready var _progress_container = $VBox/BottomPanel/VBox/HBox/Progress
onready var _progress = {
	script = _progress_container.get_node("ScriptProgress"),
	script_xy = _progress_container.get_node("ScriptProgress/xy"),
	test = _progress_container.get_node("TestProgress"),
	test_xy = _progress_container.get_node("TestProgress/xy")
}
onready var _summary = {
	control = $VBox/TitleBar/HBox/Summary,
	failing = $VBox/TitleBar/HBox/Summary/Failing, # defunct?
	passing = $VBox/TitleBar/HBox/Summary/Passing, # defunct?
	asserts = $VBox/TitleBar/HBox/Summary/AssertCount,
	fail_count = 0, # defunct?
	pass_count = 0, # defunct?
	test_count = 0,
	passing_test_count = 0
}

onready var _extras = $ExtraOptions
onready var _ignore_pauses = $ExtraOptions/IgnorePause
onready var _continue_button = $VBox/BottomPanel/VBox/HBox/Continue/Continue
onready var _text_box = $VBox/TextDisplay/RichTextLabel
onready var _text_box_container = $VBox/TextDisplay
onready var _log_level_slider = $VBox/BottomPanel/VBox/HBox2/LogLevelSlider
onready var _resize_handle = $ResizeHandle
onready var _current_script = $VBox/BottomPanel/VBox/HBox2/CurrentScriptLabel
onready var _title_replacement = $VBox/TitleBar/HBox/TitleReplacement

onready var _titlebar = {
	bar = $VBox/TitleBar,
	time = $VBox/TitleBar/HBox/Time,
	label = $VBox/TitleBar/HBox/Title
}

onready var _user_files = $UserFileViewer

var _mouse = {
	down = false,
	in_title = false,
	down_pos = null,
	in_handle = false
}

var _is_running = false
var _start_time = 0.0
var _time = 0.0

const DEFAULT_TITLE = 'GUT'
var _pre_maximize_rect = null
var _font_size = 20
var _compact_mode = false

var min_sizes = {
	compact = Vector2(330, 100),
	full = Vector2(740, 300),
}

signal end_pause
signal ignore_pause
signal log_level_changed
signal run_script
signal run_single_script

func _ready():
	if(Engine.editor_hint):
		return

	_current_script.text = ''
	_pre_maximize_rect = get_rect()
	_hide_scripts()
	_update_controls()
	_nav.current_script.set_text("No scripts available")
	set_title()
	clear_summary()
	_titlebar.time.set_text("t: 0.0")

	_extras.visible = false
	update()

	set_font_size(_font_size)
	set_font('CourierPrime')

	_user_files.set_position(Vector2(10, 30))

func elapsed_time_as_str():
	return str("%.1f" % (_time / 1000.0), 's')

func _process(_delta):
	if(_is_running):
		_time = OS.get_ticks_msec() - _start_time
		_titlebar.time.set_text(str('t: ', elapsed_time_as_str()))

func _draw(): # needs get_size()
	# Draw the lines in the corner to show where you can
	# drag to resize the dialog
	var grab_margin = 3
	var line_space = 3
	var grab_line_color = Color(.4, .4, .4)
	if(_resize_handle.visible):
		for i in range(1, 10):
			var x = rect_size - Vector2(i * line_space, grab_margin)
			var y = rect_size - Vector2(grab_margin, i * line_space)
			draw_line(x, y, grab_line_color, 1, true)

func _on_Maximize_draw():
	# draw the maximize square thing.
	var btn = $VBox/TitleBar/HBox/Maximize
	btn.set_text('')
	var w = btn.get_size().x
	var h = btn.get_size().y
	btn.draw_rect(Rect2(0, 2, w, h -2), Color(0, 0, 0, 1))
	btn.draw_rect(Rect2(2, 6, w - 4, h - 8), Color(1,1,1,1))

func _on_ShowExtras_draw():
	var btn = $VBox/BottomPanel/VBox/HBox/Continue/ShowExtras
	btn.set_text('')
	var start_x = 20
	var start_y = 15
	var pad = 5
	var color = Color(.1, .1, .1, 1)
	var width = 2
	for i in range(3):
		var y = start_y + pad * i
		btn.draw_line(Vector2(start_x, y), Vector2(btn.get_size().x - start_x, y), color, width, true)

# ####################
# GUI Events
# ####################
func _on_Run_pressed():
	_run_mode()
	emit_signal('run_script', get_selected_index())

func _on_CurrentScript_pressed():
	_toggle_scripts()

func _on_Previous_pressed():
	_select_script(get_selected_index() - 1)

func _on_Next_pressed():
	_select_script(get_selected_index() + 1)

func _on_LogLevelSlider_value_changed(_value):
	emit_signal('log_level_changed', _log_level_slider.value)

func _on_Continue_pressed():
	_continue_button.disabled = true
	emit_signal('end_pause')

func _on_IgnorePause_pressed():
	var checked = _ignore_pauses.is_pressed()
	emit_signal('ignore_pause', checked)
	if(checked):
		emit_signal('end_pause')
		_continue_button.disabled = true

func _on_RunSingleScript_pressed():
	_run_mode()
	emit_signal('run_single_script', get_selected_index())

func _on_ScriptsList_item_selected(index):
	var tmr = $ScriptsList/DoubleClickTimer
	if(!tmr.is_stopped()):
		_run_mode()
		emit_signal('run_single_script', get_selected_index())
		tmr.stop()
	else:
		tmr.start()

	_select_script(index)

func _on_TitleBar_mouse_entered():
	_mouse.in_title = true

func _on_TitleBar_mouse_exited():
	_mouse.in_title = false

func _input(event):
	if(event is InputEventMouseButton):
		if(event.button_index == 1):
			_mouse.down = event.pressed
			if(_mouse.down):
				_mouse.down_pos = event.position

	if(_mouse.in_title):
		if(event is InputEventMouseMotion and _mouse.down):
			set_position(get_position() + (event.position - _mouse.down_pos))
			_mouse.down_pos = event.position
			_pre_maximize_rect = get_rect()

	if(_mouse.in_handle):
		if(event is InputEventMouseMotion and _mouse.down):
			var new_size = rect_size + event.position - _mouse.down_pos
			var new_mouse_down_pos = event.position
			rect_size = new_size
			_mouse.down_pos = new_mouse_down_pos
			_pre_maximize_rect = get_rect()

func _on_ResizeHandle_mouse_entered():
	_mouse.in_handle = true

func _on_ResizeHandle_mouse_exited():
	_mouse.in_handle = false

func _on_RichTextLabel_gui_input(ev):
	pass
	# leaving this b/c it is wired up and might have to send
	# more signals through

func _on_Copy_pressed():
	OS.clipboard = _text_box.text

func _on_ShowExtras_toggled(button_pressed):
	_extras.visible = button_pressed

func _on_Maximize_pressed():
	if(get_rect() == _pre_maximize_rect):
		compact_mode(false)
		maximize()
	else:
		compact_mode(false)
		rect_size = _pre_maximize_rect.size
		rect_position = _pre_maximize_rect.position
func _on_Minimize_pressed():

	compact_mode(!_compact_mode)


func _on_Minimize_draw():
	# draw the maximize square thing.
	var btn = $VBox/TitleBar/HBox/Minimize
	btn.set_text('')
	var w = btn.get_size().x
	var h = btn.get_size().y
	btn.draw_rect(Rect2(0, h-3, w, 3), Color(0, 0, 0, 1))

func _on_UserFiles_pressed():
	_user_files.show_open()


# ####################
# Private
# ####################
func _run_mode(is_running=true):
	if(is_running):
		_start_time = OS.get_ticks_msec()
		_time = 0.0
		clear_summary()
	_is_running = is_running

	_hide_scripts()
	_nav.prev.disabled = is_running
	_nav.next.disabled = is_running
	_nav.run.disabled = is_running
	_nav.current_script.disabled = is_running
	_nav.run_single.disabled = is_running

func _select_script(index):
	var text = _script_list.get_item_text(index)
	var max_len = 50
	if(text.length() > max_len):
		text = '...' + text.right(text.length() - (max_len - 5))
	_nav.current_script.set_text(text)
	_script_list.select(index)
	_update_controls()

func _toggle_scripts():
	if(_script_list.visible):
		_hide_scripts()
	else:
		_show_scripts()

func _show_scripts():
	_script_list.show()

func _hide_scripts():
	_script_list.hide()

func _update_controls():
	var is_empty = _script_list.get_selected_items().size() == 0
	if(is_empty):
		_nav.next.disabled = true
		_nav.prev.disabled = true
	else:
		var index = get_selected_index()
		_nav.prev.disabled = index <= 0
		_nav.next.disabled = index >= _script_list.get_item_count() - 1

	_nav.run.disabled = is_empty
	_nav.current_script.disabled = is_empty
	_nav.run_single.disabled = is_empty

func _update_summary():
	if(!_summary):
		return

	var total = _summary.fail_count + _summary.pass_count
	_summary.control.visible = !total == 0
	# this now shows tests but I didn't rename everything
	_summary.asserts.text = str(_summary.passing_test_count, '/', _summary.test_count, ' tests passed')
# ####################
# Public
# ####################
func run_mode(is_running=true):
	_run_mode(is_running)

func set_scripts(scripts):
	_script_list.clear()
	for i in range(scripts.size()):
		_script_list.add_item(scripts[i])
	_select_script(0)
	_update_controls()

func select_script(index):
	_select_script(index)

func get_selected_index():
	return _script_list.get_selected_items()[0]

func get_log_level():
	return _log_level_slider.value

func set_log_level(value):
	var new_value = value
	if(new_value == null):
		new_value = 0
	# !! For some reason, _log_level_slider was null, but this wasn't, so
	# here's another hardcoded node path.
	$VBox/BottomPanel/VBox/HBox2/LogLevelSlider.value = new_value

func set_ignore_pause(should):
	_ignore_pauses.pressed = should

func get_ignore_pause():
	return _ignore_pauses.pressed

func get_text_box():
	# due to some timing issue, this cannot return _text_box but can return
	# this.
	return $VBox/TextDisplay/RichTextLabel

func end_run():
	_run_mode(false)
	_update_controls()

func set_progress_script_max(value):
	var max_val = max(value, 1)
	_progress.script.set_max(max_val)
	_progress.script_xy.set_text(str('0/', max_val))

func set_progress_script_value(value):
	_progress.script.set_value(value)
	var txt = str(value, '/', _progress.test.get_max())
	_progress.script_xy.set_text(txt)

func set_progress_test_max(value):
	var max_val = max(value, 1)
	_progress.test.set_max(max_val)
	_progress.test_xy.set_text(str('0/', max_val))

func set_progress_test_value(value):
	_progress.test.set_value(value)
	var txt = str(value, '/', _progress.test.get_max())
	_progress.test_xy.set_text(txt)

func clear_progress():
	_progress.test.set_value(0)
	_progress.script.set_value(0)

func pause():
	_continue_button.disabled = false

func set_title(title=null):
	if(title == null):
		_titlebar.label.set_text(DEFAULT_TITLE)
	else:
		_titlebar.label.set_text(title)

func add_passing(amount=1):
	if(!_summary):
		return
	_summary.pass_count += amount
	_update_summary()

func add_failing(amount=1):
	if(!_summary):
		return
	_summary.fail_count += amount
	_update_summary()

func add_test(passing):
	if(!_summary):
		return
	_summary.test_count += 1
	if(passing):
		_summary.passing_test_count += 1
	_update_summary()

func clear_summary():
	_summary.fail_count = 0
	_summary.pass_count = 0
	_update_summary()

func maximize():
	if(is_inside_tree()):
		var vp_size_offset = get_tree().root.get_viewport().get_visible_rect().size
		rect_size = vp_size_offset / get_scale()
		set_position(Vector2(0, 0))

func clear_text():
	_text_box.bbcode_text = ''

func scroll_to_bottom():
	pass
	#_text_box.cursor_set_line(_gui.get_text_box().get_line_count())

func _set_font_size_for_rtl(rtl, new_size):
	if(rtl.get('custom_fonts/normal_font') != null):
		rtl.get('custom_fonts/bold_italics_font').size = new_size
		rtl.get('custom_fonts/bold_font').size = new_size
		rtl.get('custom_fonts/italics_font').size = new_size
		rtl.get('custom_fonts/normal_font').size = new_size


func _set_fonts_for_rtl(rtl, base_font_name):
	pass


func set_font_size(new_size):
	_font_size = new_size
	_set_font_size_for_rtl(_text_box, new_size)
	_set_font_size_for_rtl(_user_files.get_rich_text_label(), new_size)


func _set_font(rtl, font_name, custom_name):
	if(font_name == null):
		rtl.set('custom_fonts/' + custom_name, null)
	else:
		var dyn_font = DynamicFont.new()
		var font_data = DynamicFontData.new()
		font_data.font_path = 'res://addons/gut/fonts/' + font_name + '.ttf'
		font_data.antialiased = true
		dyn_font.font_data = font_data
		rtl.set('custom_fonts/' + custom_name, dyn_font)

func _set_all_fonts_in_ftl(ftl, base_name):
	if(base_name == 'Default'):
		_set_font(ftl, null, 'normal_font')
		_set_font(ftl, null, 'bold_font')
		_set_font(ftl, null, 'italics_font')
		_set_font(ftl, null, 'bold_italics_font')
	else:
		_set_font(ftl, base_name + '-Regular', 'normal_font')
		_set_font(ftl, base_name + '-Bold', 'bold_font')
		_set_font(ftl, base_name + '-Italic', 'italics_font')
		_set_font(ftl, base_name + '-BoldItalic', 'bold_italics_font')
	set_font_size(_font_size)

func set_font(base_name):
	_set_all_fonts_in_ftl(_text_box, base_name)
	_set_all_fonts_in_ftl(_user_files.get_rich_text_label(), base_name)

func set_default_font_color(color):
	_text_box.set('custom_colors/default_color', color)

func set_background_color(color):
	_text_box_container.color = color

func get_waiting_label():
	return $VBox/TextDisplay/WaitingLabel

func compact_mode(should):
	if(_compact_mode == should):
		return

	_compact_mode = should
	_text_box_container.visible = !should
	_nav.container.visible = !should
	_log_level_slider.visible = !should
	$VBox/BottomPanel/VBox/HBox/Continue/ShowExtras.visible = !should
	_titlebar.label.visible = !should
	_resize_handle.visible = !should
	_current_script.visible = !should
	_title_replacement.visible = should

	if(should):
		rect_min_size = min_sizes.compact
		rect_size = rect_min_size
	else:
		rect_min_size = min_sizes.full
		rect_size = min_sizes.full

	goto_bottom_right_corner()


func set_script_path(text):
	_current_script.text = text


func goto_bottom_right_corner():
	rect_position = get_tree().root.get_viewport().get_visible_rect().size - rect_size

--- Start of ./addons/gut/gut_vscode_debugger.gd ---

# ------------------------------------------------------------------------------
# Entry point for using the debugger through VSCode.  The gut-extension for
# VSCode launches this instead of gut_cmdln.gd when running tests through the
# debugger.
#
# This could become more complex overtime, but right now all we have to do is
# to make sure the console printer is enabled or you do not get any output.
# ------------------------------------------------------------------------------
extends 'res://addons/gut/gut_cmdln.gd'

func run_tests(runner):
	runner.get_gut().get_logger().disable_printer('console', false)
	runner.run_tests()


# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2023 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################

--- Start of ./addons/gut/hook_script.gd ---

class_name GutHookScript
# ------------------------------------------------------------------------------
# This script is the base for custom scripts to be used in pre and post
# run hooks.
#
# To use, inherit from this script and then implement the run method.
# ------------------------------------------------------------------------------
var JunitXmlExport = load('res://addons/gut/junit_xml_export.gd')

# This is the instance of GUT that is running the tests.  You can get
# information about the run from this object.  This is set by GUT when the
# script is instantiated.
var gut  = null

# the exit code to be used by gut_cmdln.  See set method.
var _exit_code = null

var _should_abort =  false

# Virtual method that will be called by GUT after instantiating
# this script.
func run():
	gut.get_logger().error("Run method not overloaded.  Create a 'run()' method in your hook script to run your code.")


# Set the exit code when running from the command line.  If not set then the
# default exit code will be returned (0 when no tests fail, 1 when any tests
# fail).
func set_exit_code(code):
	_exit_code  = code

func get_exit_code():
	return _exit_code

# Usable by pre-run script to cause the run to end AFTER the run() method
# finishes.  post-run script will not be ran.
func abort():
	_should_abort = true

func should_abort():
	return _should_abort

--- Start of ./addons/gut/input_factory.gd ---

# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# Description
# -----------
# ##############################################################################


# Implemented InputEvent* convenience methods
# 	InputEventAction
# 	InputEventKey
# 	InputEventMouseButton
# 	InputEventMouseMotion

# Yet to implement InputEvents
# 	InputEventJoypadButton
# 	InputEventJoypadMotion
# 	InputEventMagnifyGesture
# 	InputEventMIDI
# 	InputEventPanGesture
# 	InputEventScreenDrag
# 	InputEventScreenTouch


static func _to_scancode(which):
	var key_code = which
	if(typeof(key_code) == TYPE_STRING):
		key_code = key_code.to_upper().to_ascii()[0]
	return key_code


static func new_mouse_button_event(position, global_position, pressed, button_index):
    var event = InputEventMouseButton.new()
    event.position = position
    if(global_position != null):
        event.global_position = global_position
    event.pressed = pressed
    event.button_index = button_index

    return event


static func key_up(which):
	var event = InputEventKey.new()
	event.scancode = _to_scancode(which)
	event.pressed = false
	return event


static func key_down(which):
	var event = InputEventKey.new()
	event.scancode = _to_scancode(which)
	event.pressed = true
	return event


static func action_up(which, strength=1.0):
	var event  = InputEventAction.new()
	event.action = which
	event.strength = strength
	return event


static func action_down(which, strength=1.0):
	var event  = InputEventAction.new()
	event.action = which
	event.strength = strength
	event.pressed = true
	return event


static func mouse_left_button_down(position, global_position=null):
	var event = new_mouse_button_event(position, global_position, true, BUTTON_LEFT)
	return event


static func mouse_left_button_up(position, global_position=null):
	var event = new_mouse_button_event(position, global_position, false, BUTTON_LEFT)
	return event


static func mouse_double_click(position, global_position=null):
	var event = new_mouse_button_event(position, global_position, false, BUTTON_LEFT)
	event.doubleclick = true
	return event


static func mouse_right_button_down(position, global_position=null):
	var event = new_mouse_button_event(position, global_position, true, BUTTON_RIGHT)
	return event


static func mouse_right_button_up(position, global_position=null):
	var event = new_mouse_button_event(position, global_position, false, BUTTON_RIGHT)
	return event


static func mouse_motion(position, global_position=null):
	var event = InputEventMouseMotion.new()
	event.position = position
	if(global_position != null):
		event.global_position = global_position
	return event


static func mouse_relative_motion(offset, last_motion_event=null, speed=Vector2(0, 0)):
	var event = null
	if(last_motion_event == null):
		event = mouse_motion(offset)
		event.speed = speed
	else:
		event = last_motion_event.duplicate()
		event.position += offset
		event.global_position += offset
		event.relative = offset
		event.speed = speed
	return event

--- Start of ./addons/gut/input_sender.gd ---

# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# Description
# -----------
# This class sends input to one or more recievers.  The receivers' _input,
# _unhandled_input, and _gui_input are called sending InputEvent* events.
# InputEvents can be sent via the helper methods or a custom made InputEvent
# can be sent via send_event(...)
#
# ##############################################################################
#extends "res://addons/gut/input_factory.gd"

# Implemented InputEvent* convenience methods
# 	InputEventAction
# 	InputEventKey
# 	InputEventMouseButton
#	InputEventMouseMotion

# Yet to implement InputEvents
# 	InputEventJoypadButton
# 	InputEventJoypadMotion
# 	InputEventMagnifyGesture
# 	InputEventMIDI
# 	InputEventPanGesture
# 	InputEventScreenDrag
# 	InputEventScreenTouch

class InputQueueItem:
	extends Node

	var events = []
	var time_delay = null
	var frame_delay = null
	var _waited_frames = 0
	var _is_ready = false
	var _delay_started = false

	signal event_ready

	# TODO should this be done in _physics_process instead or should it be
	# configurable?
	func _physics_process(delta):
		if(frame_delay > 0 and _delay_started):
			_waited_frames += 1
			if(_waited_frames >= frame_delay):
				emit_signal("event_ready")

	func _init(t_delay, f_delay):
		time_delay = t_delay
		frame_delay = f_delay
		_is_ready = time_delay == 0 and frame_delay == 0

	func _on_time_timeout():
		_is_ready = true
		emit_signal("event_ready")

	func _delay_timer(t):
		return Engine.get_main_loop().root.get_tree().create_timer(t)

	func is_ready():
		return _is_ready

	func start():
		_delay_started = true
		if(time_delay > 0):
			var t = _delay_timer(time_delay)
			t.connect("timeout", self, "_on_time_timeout")


# ##############################################################################
#
# ##############################################################################
var _utils = load('res://addons/gut/utils.gd').get_instance()
var InputFactory = load("res://addons/gut/input_factory.gd")

const INPUT_WARN = 'If using Input as a reciever it will not respond to *_down events until a *_up event is recieved.  Call the appropriate *_up event or use .hold_for(...) to automatically release after some duration.'

var _lgr = _utils.get_logger()
var _receivers = []
var _input_queue = []
var _next_queue_item = null
# used by mouse_relative_motion.  These use this instead of _last_event since
# it is logical to have a series of events happen between mouse motions.
var _last_mouse_motion = null
# used by hold_for and echo.
var _last_event = null

# indexed by scancode, each entry contains a boolean value indicating the
# last emitted "pressed" value for that scancode.
var _pressed_keys = {}
var _pressed_actions = {}
var _pressed_mouse_buttons = {}

var _auto_flush_input = false

signal idle


func _init(r=null):
	if(r != null):
		add_receiver(r)


func _send_event(event):
	if(event is InputEventKey):
		if((event.pressed and !event.echo) and is_key_pressed(event.scancode)):
			_lgr.warn(str("InputSender:  key_down called for ", event.as_text(), " when that key is already pressed.  ", INPUT_WARN))
		_pressed_keys[event.scancode] = event.pressed
	elif(event is InputEventAction):
		if(event.pressed and is_action_pressed(event.action)):
			_lgr.warn(str("InputSender:  action_down called for ", event.action, " when that action is already pressed.  ", INPUT_WARN))
		_pressed_actions[event.action] = event.pressed
	elif(event is InputEventMouseButton):
		if(event.pressed and is_mouse_button_pressed(event.button_index)):
			_lgr.warn(str("InputSender:  mouse_button_down called for ", event.button_index, " when that mouse button is already pressed.  ", INPUT_WARN))
		_pressed_mouse_buttons[event.button_index] = event

	for r in _receivers:
		if(r == Input):
			Input.parse_input_event(event)
			if(_auto_flush_input):
				Input.flush_buffered_events()
		else:
			if(r.has_method("_input")):
				r._input(event)

			if(r.has_method("_gui_input")):
				r._gui_input(event)

			if(r.has_method("_unhandled_input")):
				r._unhandled_input(event)


func _send_or_record_event(event):
	_last_event = event
	if(_next_queue_item != null):
		_next_queue_item.events.append(event)
	else:
		_send_event(event)


func _on_queue_item_ready(item):
	for event in item.events:
		_send_event(event)

	var done_event = _input_queue.pop_front()
	done_event.queue_free()

	if(_input_queue.size() == 0):
		_next_queue_item = null
		emit_signal("idle")
	else:
		_input_queue[0].start()


func _add_queue_item(item):
	item.connect("event_ready", self, "_on_queue_item_ready", [item])
	_next_queue_item = item
	_input_queue.append(item)
	Engine.get_main_loop().root.add_child(item)
	if(_input_queue.size() == 1):
		item.start()


func add_receiver(obj):
	_receivers.append(obj)


func get_receivers():
	return _receivers


func wait(t):
	if(typeof(t) == TYPE_STRING):
		var suffix = t.substr(t.length() -1, 1)
		var val = float(t.rstrip('s').rstrip('f'))

		if(suffix.to_lower() == 's'):
			wait_secs(val)
		elif(suffix.to_lower() == 'f'):
			wait_frames(val)
	else:
		wait_secs(t)

	return self


func wait_frames(num_frames):
	var item = InputQueueItem.new(0, num_frames)
	_add_queue_item(item)
	return self


func wait_secs(num_secs):
	var item = InputQueueItem.new(num_secs, 0)
	_add_queue_item(item)
	return self


# ------------------------------
# Event methods
# ------------------------------
func key_up(which):
	var event = InputFactory.key_up(which)
	_send_or_record_event(event)
	return self


func key_down(which):
	var event = InputFactory.key_down(which)
	_send_or_record_event(event)
	return self


func key_echo():
	if(_last_event != null and _last_event is InputEventKey):
		var new_key = _last_event.duplicate()
		new_key.echo = true
		_send_or_record_event(new_key)
	return self


func action_up(which, strength=1.0):
	var event  = InputFactory.action_up(which, strength)
	_send_or_record_event(event)
	return self


func action_down(which, strength=1.0):
	var event  = InputFactory.action_down(which, strength)
	_send_or_record_event(event)
	return self


func mouse_left_button_down(position, global_position=null):
	var event = InputFactory.mouse_left_button_down(position, global_position)
	_send_or_record_event(event)
	return self


func mouse_left_button_up(position, global_position=null):
	var event = InputFactory.mouse_left_button_up(position, global_position)
	_send_or_record_event(event)
	return self


func mouse_double_click(position, global_position=null):
	var event = InputFactory.mouse_double_click(position, global_position)
	event.doubleclick = true
	_send_or_record_event(event)
	return self


func mouse_right_button_down(position, global_position=null):
	var event = InputFactory.mouse_right_button_down(position, global_position)
	_send_or_record_event(event)
	return self


func mouse_right_button_up(position, global_position=null):
	var event = InputFactory.mouse_right_button_up(position, global_position)
	_send_or_record_event(event)
	return self


func mouse_motion(position, global_position=null):
	var event = InputFactory.mouse_motion(position, global_position)
	_last_mouse_motion = event
	_send_or_record_event(event)
	return self


func mouse_relative_motion(offset, speed=Vector2(0, 0)):
	var event = InputFactory.mouse_relative_motion(offset, _last_mouse_motion, speed)
	_last_mouse_motion = event
	_send_or_record_event(event)
	return self


func mouse_set_position(position, global_position=null):
	_last_mouse_motion = InputFactory.mouse_motion(position, global_position)
	return self


func send_event(event):
	_send_or_record_event(event)
	return self


func release_all():
	for key in _pressed_keys:
		if(_pressed_keys[key]):
			_send_event(InputFactory.key_up(key))
	_pressed_keys.clear()

	for key in _pressed_actions:
		if(_pressed_actions[key]):
			_send_event(InputFactory.action_up(key))
	_pressed_actions.clear()

	for key in _pressed_mouse_buttons:
		var event = _pressed_mouse_buttons[key].duplicate()
		if(event.pressed):
			event.pressed = false
			_send_event(event)
	_pressed_mouse_buttons.clear()


func hold_for(duration):
	if(_last_event != null and _last_event.pressed):
		var next_event = _last_event.duplicate()
		next_event.pressed = false
		wait(duration)
		send_event(next_event)
	return self


func clear():
	pass

	_last_event = null
	_last_mouse_motion = null
	_next_queue_item = null

	for item in _input_queue:
		item.free()
	_input_queue.clear()

	_pressed_keys.clear()
	_pressed_actions.clear()
	_pressed_mouse_buttons.clear()

func is_idle():
	return _input_queue.size() == 0

func is_key_pressed(which):
	var event = InputFactory.key_up(which)
	return _pressed_keys.has(event.scancode) and _pressed_keys[event.scancode]

func is_action_pressed(which):
	return _pressed_actions.has(which) and _pressed_actions[which]

func is_mouse_button_pressed(which):
	return _pressed_mouse_buttons.has(which) and _pressed_mouse_buttons[which]


func get_auto_flush_input():
	return _auto_flush_input


func set_auto_flush_input(val):
	_auto_flush_input = val

--- Start of ./addons/gut/junit_xml_export.gd ---

# ------------------------------------------------------------------------------
# Creates an export of a test run in the JUnit XML format.
# ------------------------------------------------------------------------------
var _utils = load('res://addons/gut/utils.gd').get_instance()

var _exporter = _utils.ResultExporter.new()

func indent(s, ind):
	var to_return = ind + s
	to_return = to_return.replace("\n", "\n" + ind)
	return to_return


func add_attr(name, value):
	return str(name, '="', value, '" ')

func _export_test_result(test):
	var to_return = ''

	# Right now the pending and failure messages won't fit in the message
	# attribute because they can span multiple lines and need to be escaped.
	if(test.status == 'pending'):
		var skip_tag = str("<skipped message=\"pending\">", test.pending[0], "</skipped>")
		to_return += skip_tag
	elif(test.status == 'fail'):
		var fail_tag = str("<failure message=\"failed\">", test.failing[0], "</failure>")
		to_return += fail_tag

	return to_return


func _export_tests(script_result, classname):
	var to_return = ""

	for key in script_result.keys():
		var test = script_result[key]
		var assert_count = test.passing.size() + test.failing.size()
		to_return += "<testcase "
		to_return += add_attr("name", key)
		to_return += add_attr("assertions", assert_count)
		to_return += add_attr("status", test.status)
		to_return += add_attr("classname", classname)
		to_return += ">\n"

		to_return += _export_test_result(test)

		to_return += "</testcase>\n"

	return to_return


func _export_scripts(exp_results):
	var to_return = ""
	for key in exp_results.test_scripts.scripts.keys():
		var s = exp_results.test_scripts.scripts[key]
		to_return += "<testsuite "
		to_return += add_attr("name", key)
		to_return += add_attr("tests", s.props.tests)
		to_return += add_attr("failures", s.props.failures)
		to_return += add_attr("skipped", s.props.pending)
		to_return += ">\n"

		to_return += indent(_export_tests(s.tests, key), "    ")

		to_return += "</testsuite>\n"

	return to_return


func get_results_xml(gut):
	var exp_results = _exporter.get_results_dictionary(gut)
	var to_return = '<?xml version="1.0" encoding="UTF-8"?>' + "\n"
	to_return += '<testsuites '
	to_return += add_attr("name", 'GutTests')
	to_return += add_attr("failures", exp_results.test_scripts.props.failures)
	to_return += add_attr('tests', exp_results.test_scripts.props.tests)
	to_return += ">\n"

	to_return += indent(_export_scripts(exp_results), "  ")

	to_return += '</testsuites>'
	return to_return


func write_file(gut, path):
	var xml = get_results_xml(gut)

	var f_result = _utils.write_file(path, xml)
	if(f_result != OK):
		var msg = str("Error:  ", f_result, ".  Could not create export file ", path)
		_utils.get_logger().error(msg)

	return f_result

--- Start of ./addons/gut/logger.gd ---

# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# This class wraps around the various printers and supplies formatting for the
# various message types (error, warning, etc).
# ##############################################################################
var types = {
	debug = 'debug',
	deprecated = 'deprecated',
	error = 'error',
	failed = 'failed',
	info = 'info',
	normal = 'normal',
	orphan = 'orphan',
	passed = 'passed',
	pending = 'pending',
	warn ='warn',
}

var fmts = {
	red = 'red',
	yellow = 'yellow',
	green = 'green',

	bold = 'bold',
	underline = 'underline',

	none = null
}

var _type_data = {
	types.debug:		{disp='DEBUG', 		enabled=true, fmt=fmts.none},
	types.deprecated:	{disp='DEPRECATED', enabled=true, fmt=fmts.none},
	types.error:		{disp='ERROR', 		enabled=true, fmt=fmts.red},
	types.failed:		{disp='Failed', 	enabled=true, fmt=fmts.red},
	types.info:			{disp='INFO', 		enabled=true, fmt=fmts.bold},
	types.normal:		{disp='NORMAL', 	enabled=true, fmt=fmts.none},
	types.orphan:		{disp='Orphans',	enabled=true, fmt=fmts.yellow},
	types.passed:		{disp='Passed', 	enabled=true, fmt=fmts.green},
	types.pending:		{disp='Pending',	enabled=true, fmt=fmts.yellow},
	types.warn:			{disp='WARNING', 	enabled=true, fmt=fmts.yellow},
}

var _logs = {
	types.warn: [],
	types.error: [],
	types.info: [],
	types.debug: [],
	types.deprecated: [],
}

var _printers = {
	terminal = null,
	gui = null,
	console = null
}

var _gut = null
var _utils = null
var _indent_level = 0
var _indent_string = '    '
var _skip_test_name_for_testing = false
var _less_test_names = false
var _yield_calls = 0
var _last_yield_text = ''


func _init():
	_utils = load('res://addons/gut/utils.gd').get_instance()
	_printers.terminal = _utils.Printers.TerminalPrinter.new()
	_printers.console = _utils.Printers.ConsolePrinter.new()
	# There were some problems in the timing of disabling this at the right
	# time in gut_cmdln so it is disabled by default.  This is enabled
	# by plugin_control.gd based on settings.
	_printers.console.set_disabled(true)

func get_indent_text():
	var pad = ''
	for i in range(_indent_level):
		pad += _indent_string

	return pad

func _indent_text(text):
	var to_return = text
	var ending_newline = ''

	if(text.ends_with("\n")):
		ending_newline = "\n"
		to_return = to_return.left(to_return.length() -1)

	var pad = get_indent_text()
	to_return = to_return.replace("\n", "\n" + pad)
	to_return += ending_newline

	return pad + to_return

func _should_print_to_printer(key_name):
	return _printers[key_name] != null and !_printers[key_name].get_disabled()

func _print_test_name():
	if(_gut == null):
		return
	var cur_test = _gut.get_current_test_object()
	if(cur_test == null):
		return false

	if(!cur_test.has_printed_name):
		_output('* ' + cur_test.name + "\n")
		cur_test.has_printed_name = true

func _output(text, fmt=null):
	for key in _printers:
		if(_should_print_to_printer(key)):
			var info = ''#str(self, ':', key, ':', _printers[key], '|  ')
			_printers[key].send(info + text, fmt)

func _log(text, fmt=fmts.none):
	_print_test_name()
	var indented = _indent_text(text)
	_output(indented, fmt)

# ---------------
# Get Methods
# ---------------
func get_warnings():
	return get_log_entries(types.warn)

func get_errors():
	return get_log_entries(types.error)

func get_infos():
	return get_log_entries(types.info)

func get_debugs():
	return get_log_entries(types.debug)

func get_deprecated():
	return get_log_entries(types.deprecated)

func get_count(log_type=null):
	var count = 0
	if(log_type == null):
		for key in _logs:
			count += _logs[key].size()
	else:
		count = _logs[log_type].size()
	return count

func get_log_entries(log_type):
	return _logs[log_type]

# ---------------
# Log methods
# ---------------
func _output_type(type, text):
	var td = _type_data[type]
	if(!td.enabled):
		return

	_print_test_name()
	if(type != types.normal):
		if(_logs.has(type)):
			_logs[type].append(text)

		var start = str('[', td.disp, ']')
		if(text != null and text != ''):
			start += ':  '
		else:
			start += ' '
		var indented_start = _indent_text(start)
		var indented_end = _indent_text(text)
		indented_end = indented_end.lstrip(_indent_string)
		_output(indented_start, td.fmt)
		_output(indented_end + "\n")

func debug(text):
	_output_type(types.debug, text)

# supply some text or the name of the deprecated method and the replacement.
func deprecated(text, alt_method=null):
	var msg = text
	if(alt_method):
		msg = str('The method ', text, ' is deprecated, use ', alt_method , ' instead.')
	return _output_type(types.deprecated, msg)

func error(text):
	_output_type(types.error, text)

func failed(text):
	_output_type(types.failed, text)

func info(text):
	_output_type(types.info, text)

func orphan(text):
	_output_type(types.orphan, text)

func passed(text):
	_output_type(types.passed, text)

func pending(text):
	_output_type(types.pending, text)

func warn(text):
	_output_type(types.warn, text)

func log(text='', fmt=fmts.none):
	end_yield()
	if(text == ''):
		_output("\n")
	else:
		_log(text + "\n", fmt)
	return null

func lograw(text, fmt=fmts.none):
	return _output(text, fmt)

# Print the test name if we aren't skipping names of tests that pass (basically
# what _less_test_names means))
func log_test_name():
	# suppress output if we haven't printed the test name yet and
	# what to print is the test name.
	if(!_less_test_names):
		_print_test_name()

# ---------------
# Misc
# ---------------
func get_gut():
	return _gut

func set_gut(gut):
	_gut = gut
	if(_gut == null):
		_printers.gui = null
	else:
		if(_printers.gui == null):
			_printers.gui = _utils.Printers.GutGuiPrinter.new()
		_printers.gui.set_gut(gut)

func get_indent_level():
	return _indent_level

func set_indent_level(indent_level):
	_indent_level = indent_level

func get_indent_string():
	return _indent_string

func set_indent_string(indent_string):
	_indent_string = indent_string

func clear():
	for key in _logs:
		_logs[key].clear()

func inc_indent():
	_indent_level += 1

func dec_indent():
	_indent_level = max(0, _indent_level -1)

func is_type_enabled(type):
	return _type_data[type].enabled

func set_type_enabled(type, is_enabled):
	_type_data[type].enabled = is_enabled

func get_less_test_names():
	return _less_test_names

func set_less_test_names(less_test_names):
	_less_test_names = less_test_names

func disable_printer(name, is_disabled):
	_printers[name].set_disabled(is_disabled)

func is_printer_disabled(name):
	return _printers[name].get_disabled()

func disable_formatting(is_disabled):
	for key in _printers:
		_printers[key].set_format_enabled(!is_disabled)

func get_printer(printer_key):
	return _printers[printer_key]

func _yield_text_terminal(text):
	var printer = _printers['terminal']
	if(_yield_calls != 0):
		printer.clear_line()
		printer.back(_last_yield_text.length())
	printer.send(text, fmts.yellow)

func _end_yield_terminal():
	var printer = _printers['terminal']
	printer.clear_line()
	printer.back(_last_yield_text.length())

func _yield_text_gui(text):
	var lbl = _gut.get_gui().get_waiting_label()
	lbl.visible = true
	lbl.set_bbcode('[color=yellow]' + text + '[/color]')

func _end_yield_gui():
	var lbl = _gut.get_gui().get_waiting_label()
	lbl.visible = false
	lbl.set_text('')

# This is used for displaying the "yield detected" and "yielding to" messages.
func yield_msg(text):
	if(_type_data.warn.enabled):
		self.log(text, fmts.yellow)

# This is used for the animated "waiting" message
func yield_text(text):
	_yield_text_terminal(text)
	_yield_text_gui(text)
	_last_yield_text = text
	_yield_calls += 1

# This is used for the animated "waiting" message
func end_yield():
	if(_yield_calls == 0):
		return
	_end_yield_terminal()
	_end_yield_gui()
	_yield_calls = 0
	_last_yield_text = ''

func get_gui_bbcode():
	return _printers.gui.get_bbcode()

--- Start of ./addons/gut/method_maker.gd ---

class CallParameters:
	var p_name = null
	var default = null

	func _init(n, d):
		p_name = n
		default = d


# ------------------------------------------------------------------------------
# This class will generate method declaration lines based on method meta
# data.  It will create defaults that match the method data.
#
# --------------------
# function meta data
# --------------------
# name:
# flags:
# args: [{
# 	(class_name:),
# 	(hint:0),
# 	(hint_string:),
# 	(name:),
# 	(type:4),
# 	(usage:7)
# }]
# default_args []

var _utils = load('res://addons/gut/utils.gd').get_instance()
var _lgr = _utils.get_logger()
const PARAM_PREFIX = 'p_'

# ------------------------------------------------------
# _supported_defaults
#
# This array contains all the data types that are supported for default values.
# If a value is supported it will contain either an empty string or a prefix
# that should be used when setting the parameter default value.
# For example int, real, bool do not need anything func(p1=1, p2=2.2, p3=false)
# but things like Vectors and Colors do since only the parameters to create a
# new Vector or Color are included in the metadata.
# ------------------------------------------------------
	# TYPE_NIL = 0 — Variable is of type nil (only applied for null).
	# TYPE_BOOL = 1 — Variable is of type bool.
	# TYPE_INT = 2 — Variable is of type int.
	# TYPE_REAL = 3 — Variable is of type float/real.
	# TYPE_STRING = 4 — Variable is of type String.
	# TYPE_VECTOR2 = 5 — Variable is of type Vector2.
	# TYPE_RECT2 = 6 — Variable is of type Rect2.
	# TYPE_VECTOR3 = 7 — Variable is of type Vector3.
	# TYPE_COLOR = 14 — Variable is of type Color.
	# TYPE_OBJECT = 17 — Variable is of type Object.
	# TYPE_DICTIONARY = 18 — Variable is of type Dictionary.
	# TYPE_ARRAY = 19 — Variable is of type Array.
	# TYPE_VECTOR2_ARRAY = 24 — Variable is of type PoolVector2Array.
	# TYPE_TRANSFORM = 13 — Variable is of type Transform.
	# TYPE_TRANSFORM2D = 8 — Variable is of type Transform2D.
	# TYPE_RID = 16 — Variable is of type RID.
	# TYPE_INT_ARRAY = 21 — Variable is of type PoolIntArray.
	# TYPE_REAL_ARRAY = 22 — Variable is of type PoolRealArray.
	# TYPE_STRING_ARRAY = 23 — Variable is of type PoolStringArray.


# TYPE_PLANE = 9 — Variable is of type Plane.
# TYPE_QUAT = 10 — Variable is of type Quat.
# TYPE_AABB = 11 — Variable is of type AABB.
# TYPE_BASIS = 12 — Variable is of type Basis.
# TYPE_NODE_PATH = 15 — Variable is of type NodePath.
# TYPE_RAW_ARRAY = 20 — Variable is of type PoolByteArray.
# TYPE_VECTOR3_ARRAY = 25 — Variable is of type PoolVector3Array.
# TYPE_COLOR_ARRAY = 26 — Variable is of type PoolColorArray.
# TYPE_MAX = 27 — Marker for end of type constants.
# ------------------------------------------------------
var _supported_defaults = []

func _init():
	for _i in range(TYPE_MAX):
		_supported_defaults.append(null)

	# These types do not require a prefix for defaults
	_supported_defaults[TYPE_NIL] = ''
	_supported_defaults[TYPE_BOOL] = ''
	_supported_defaults[TYPE_INT] = ''
	_supported_defaults[TYPE_REAL] = ''
	_supported_defaults[TYPE_OBJECT] = ''
	_supported_defaults[TYPE_ARRAY] = ''
	_supported_defaults[TYPE_STRING] = ''
	_supported_defaults[TYPE_DICTIONARY] = ''
	_supported_defaults[TYPE_VECTOR2_ARRAY] = ''
	_supported_defaults[TYPE_RID] = ''

	# These require a prefix for whatever default is provided
	_supported_defaults[TYPE_VECTOR2] = 'Vector2'
	_supported_defaults[TYPE_RECT2] = 'Rect2'
	_supported_defaults[TYPE_VECTOR3] = 'Vector3'
	_supported_defaults[TYPE_COLOR] = 'Color'
	_supported_defaults[TYPE_TRANSFORM2D] = 'Transform2D'
	_supported_defaults[TYPE_TRANSFORM] = 'Transform'
	_supported_defaults[TYPE_INT_ARRAY] = 'PoolIntArray'
	_supported_defaults[TYPE_REAL_ARRAY] = 'PoolRealArray'
	_supported_defaults[TYPE_STRING_ARRAY] = 'PoolStringArray'

# ###############
# Private
# ###############
var _func_text = _utils.get_file_as_text('res://addons/gut/double_templates/function_template.txt')
var _init_text = _utils.get_file_as_text('res://addons/gut/double_templates/init_template.txt')

func _is_supported_default(type_flag):
	return type_flag >= 0 and type_flag < _supported_defaults.size() and _supported_defaults[type_flag] != null


func _make_stub_default(method, index):
	return str('__gut_default_val("', method, '",', index, ')')

func _make_arg_array(method_meta, override_size):
	var to_return = []

	var has_unsupported_defaults = false
	var dflt_start = method_meta.args.size() - method_meta.default_args.size()

	for i in range(method_meta.args.size()):
		var pname = method_meta.args[i].name
		var dflt_text = ''

		if(i < dflt_start):
			dflt_text = _make_stub_default(method_meta.name, i)
		else:
			var dflt_idx = i - dflt_start
			var t = method_meta.args[i]['type']
			if(_is_supported_default(t)):
				# strings are special, they need quotes around the value
				if(t == TYPE_STRING):
					dflt_text = str("'", str(method_meta.default_args[dflt_idx]), "'")
				# Colors need the parens but things like Vector2 and Rect2 don't
				elif(t == TYPE_COLOR):
					dflt_text = str(_supported_defaults[t], '(', str(method_meta.default_args[dflt_idx]), ')')
				elif(t == TYPE_OBJECT):
					if(str(method_meta.default_args[dflt_idx]) == "[Object:null]"):
						dflt_text = str(_supported_defaults[t], 'null')
					else:
						dflt_text = str(_supported_defaults[t], str(method_meta.default_args[dflt_idx]).to_lower())
				elif(t == TYPE_TRANSFORM):
					# value will be 4 Vector3 and look like: 1, 0, 0, 0, 1, 0, 0, 0, 1 - 0, 0, 0
					var sections = str(method_meta.default_args[dflt_idx]).split("-")
					var vecs = sections[0].split(",")
					vecs.append_array(sections[1].split(","))
					var v1 = str("Vector3(", vecs[0], ", ", vecs[1], ", ", vecs[2], ")")
					var v2 = str("Vector3(", vecs[3], ", ", vecs[4], ", ", vecs[5], ")")
					var v3 = str("Vector3(", vecs[6], ", ", vecs[7], ", ", vecs[8], ")")
					var v4 = str("Vector3(", vecs[9], ", ", vecs[10], ", ", vecs[11], ")")
					dflt_text = str(_supported_defaults[t], "(", v1, ", ", v2, ", ", v3, ", ", v4, ")")
				elif(t == TYPE_TRANSFORM2D):
					# value will look like:  ((1, 0), (0, 1), (0, 0))
					var vectors = str(method_meta.default_args[dflt_idx])
					vectors = vectors.replace("((", "(")
					vectors = vectors.replace("))", ")")
					vectors = vectors.replace("(", "Vector2(")
					dflt_text = str(_supported_defaults[t], "(", vectors, ")")
				elif(t == TYPE_RID):
					dflt_text = str(_supported_defaults[t], 'null')
				elif(t in [TYPE_REAL_ARRAY, TYPE_INT_ARRAY, TYPE_STRING_ARRAY]):
					dflt_text = str(_supported_defaults[t], "()")
				# Everything else puts the prefix (if one is there) from _supported_defaults
				# in front.  The to_lower is used b/c for some reason the defaults for
				# null, true, false are all "Null", "True", "False".
				else:
					dflt_text = str(_supported_defaults[t], str(method_meta.default_args[dflt_idx]).to_lower())
			else:
				_lgr.error(str(
					'Unsupported default param type:  ',method_meta.name, '-', method_meta.args[i].name, ' ', t, ' = ', method_meta.default_args[dflt_idx]))
				dflt_text = str('unsupported=',t)
				has_unsupported_defaults = true

		# Finally add in the parameter
		to_return.append(CallParameters.new(PARAM_PREFIX + pname, dflt_text))

	# Add in extra parameters from stub settings.
	if(override_size != null):
		for i in range(method_meta.args.size(), override_size):
			var pname = str(PARAM_PREFIX, 'arg', i)
			var dflt_text = _make_stub_default(method_meta.name, i)
			to_return.append(CallParameters.new(pname, dflt_text))

	return [has_unsupported_defaults, to_return];


# Creates a list of parameters with defaults of null unless a default value is
# found in the metadata.  If a default is found in the meta then it is used if
# it is one we know how support.
#
# If a default is found that we don't know how to handle then this method will
# return null.
func _get_arg_text(arg_array):
	var text = ''

	for i in range(arg_array.size()):
		text += str(arg_array[i].p_name, '=', arg_array[i].default)
		if(i != arg_array.size() -1):
			text += ', '

	return text


# creates a call to the function in meta in the super's class.
func _get_super_call_text(method_name, args, super_name=""):
	var params = ''
	for i in range(args.size()):
		params += args[i].p_name
		if(i != args.size() -1):
			params += ', '

	return str(super_name, '.', method_name, '(', params, ')')


func _get_spy_call_parameters_text(args):
	var called_with = 'null'

	if(args.size() > 0):
		called_with = '['
		for i in range(args.size()):
			called_with += args[i].p_name
			if(i < args.size() - 1):
				called_with += ', '
		called_with += ']'

	return called_with


# ###############
# Public
# ###############

func _get_init_text(meta, args, method_params, param_array):
	var text = null

	var decleration = str('func ', meta.name, '(', method_params, ')')
	var super_params = ''
	if(args.size() > 0):
		super_params = '.('
		for i in range(args.size()):
			super_params += args[i].p_name
			if(i != args.size() -1):
				super_params += ', '
		super_params += ')'

	text = _init_text.format({
		"func_decleration":decleration,
		"super_params":super_params,
		"param_array":param_array,
		"method_name":meta.name
	})

	return text


# Creates a delceration for a function based off of function metadata.  All
# types whose defaults are supported will have their values.  If a datatype
# is not supported and the parameter has a default, a warning message will be
# printed and the declaration will return null.
#
# path is no longer used
func get_function_text(meta, path=null, override_size=null, super_name=""):
	var method_params = ''
	var text = null
	var result = _make_arg_array(meta, override_size)
	var has_unsupported = result[0]
	var args = result[1]

	var param_array = _get_spy_call_parameters_text(args)

	if(has_unsupported):
		# This will cause a runtime error.  This is the most convenient way to
		# to stop running before the error gets more obscure.  _make_arg_array
		# generates a gut error when unsupported defaults are found.
		method_params = null
	else:
		method_params = _get_arg_text(args);

	if(param_array == 'null'):
		param_array = '[]'

	if(method_params != null):
		if(meta.name == '_init'):
			text =  _get_init_text(meta, args, method_params, param_array)
		else:
			var decleration = str('func ', meta.name, '(', method_params, '):')
			text = _func_text.format({
				"func_decleration":decleration,
				"method_name":meta.name,
				"param_array":param_array,
				"super_call":_get_super_call_text(meta.name, args, super_name)
			})

	return text




func get_logger():
	return _lgr

func set_logger(logger):
	_lgr = logger

--- Start of ./addons/gut/one_to_many.gd ---

# ------------------------------------------------------------------------------
# This datastructure represents a simple one-to-many relationship.  It manages
# a dictionary of value/array pairs.  It ignores duplicates of both the "one"
# and the "many".
# ------------------------------------------------------------------------------
var _items = {}

# return the size of _items or the size of an element in _items if "one" was
# specified.
func size(one=null):
	var to_return = 0
	if(one == null):
		to_return = _items.size()
	elif(_items.has(one)):
		to_return = _items[one].size()
	return to_return

# Add an element to "one" if it does not already exist
func add(one, many_item):
	if(_items.has(one) and !_items[one].has(many_item)):
		_items[one].append(many_item)
	else:
		_items[one] = [many_item]

func clear():
	_items.clear()

func has(one, many_item):
	var to_return = false
	if(_items.has(one)):
		to_return = _items[one].has(many_item)
	return to_return

func to_s():
	var to_return = ''
	for key in _items:
		to_return += str(key, ":  ", _items[key], "\n")
	return to_return

--- Start of ./addons/gut/optparse.gd ---

# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# Description
# -----------
# Command line interface for the GUT unit testing tool.  Allows you to run tests
# from the command line instead of running a scene.  Place this script along with
# gut.gd into your scripts directory at the root of your project.  Once there you
# can run this script (from the root of your project) using the following command:
# 	godot -s -d test/gut/gut_cmdln.gd
#
# See the readme for a list of options and examples.  You can also use the -gh
# option to get more information about how to use the command line interface.
# ##############################################################################

#-------------------------------------------------------------------------------
# Parses the command line arguments supplied into an array that can then be
# examined and parsed based on how the gut options work.
#-------------------------------------------------------------------------------
class CmdLineParser:
	var _used_options = []
	# an array of arrays.  Each element in this array will contain an option
	# name and if that option contains a value then it will have a sedond
	# element.  For example:
	# 	[[-gselect, test.gd], [-gexit]]
	var _opts = []

	func _init():
		for i in range(OS.get_cmdline_args().size()):
			var opt_val = OS.get_cmdline_args()[i].split('=')
			_opts.append(opt_val)

	# Parse out multiple comma delimited values from a command line
	# option.  Values are separated from option name with "=" and
	# additional values are comma separated.
	func _parse_array_value(full_option):
		var value = _parse_option_value(full_option)
		var split = value.split(',')
		return split

	# Parse out the value of an option.  Values are separated from
	# the option name with "="
	func _parse_option_value(full_option):
		if(full_option.size() > 1):
			return full_option[1]
		else:
			return null

	# Search _opts for an element that starts with the option name
	# specified.
	func find_option(name):
		var found = false
		var idx = 0

		while(idx < _opts.size() and !found):
			if(_opts[idx][0] == name):
				found = true
			else:
				idx += 1

		if(found):
			return idx
		else:
			return -1

	func get_array_value(option):
		_used_options.append(option)
		var to_return = []
		var opt_loc = find_option(option)
		if(opt_loc != -1):
			to_return = _parse_array_value(_opts[opt_loc])
			_opts.remove(opt_loc)

		return to_return

	# returns the value of an option if it was specified, null otherwise.  This
	# used to return the default but that became problemnatic when trying to
	# punch through the different places where values could be specified.
	func get_value(option):
		_used_options.append(option)
		var to_return = null
		var opt_loc = find_option(option)
		if(opt_loc != -1):
			to_return = _parse_option_value(_opts[opt_loc])
			_opts.remove(opt_loc)

		return to_return

	# returns true if it finds the option, false if not.
	func was_specified(option):
		_used_options.append(option)
		return find_option(option) != -1

	# Returns any unused command line options.  I found that only the -s and
	# script name come through from godot, all other options that godot uses
	# are not sent through OS.get_cmdline_args().
	#
	# This is a onetime thing b/c i kill all items in _used_options
	func get_unused_options():
		var to_return = []
		for i in range(_opts.size()):
			to_return.append(_opts[i][0])

		var script_option = to_return.find('-s')
		if script_option != -1:
			to_return.remove(script_option + 1)
			to_return.remove(script_option)

		while(_used_options.size() > 0):
			var index = to_return.find(_used_options[0].split("=")[0])
			if(index != -1):
				to_return.remove(index)
			_used_options.remove(0)

		return to_return

#-------------------------------------------------------------------------------
# Simple class to hold a command line option
#-------------------------------------------------------------------------------
class Option:
	var value = null
	var option_name = ''
	var default = null
	var description = ''

	func _init(name, default_value, desc=''):
		option_name = name
		default = default_value
		description = desc
		value = null#default_value

	func pad(to_pad, size, pad_with=' '):
		var to_return = to_pad
		for _i in range(to_pad.length(), size):
			to_return += pad_with

		return to_return

	func to_s(min_space=0):
		var subbed_desc = description
		if(subbed_desc.find('[default]') != -1):
			subbed_desc = subbed_desc.replace('[default]', str(default))
		return pad(option_name, min_space) + subbed_desc

#-------------------------------------------------------------------------------
# The high level interface between this script and the command line options
# supplied.  Uses Option class and CmdLineParser to extract information from
# the command line and make it easily accessible.
#-------------------------------------------------------------------------------
var options = []
var _opts = []
var _banner = ''

func add(name, default, desc):
	options.append(Option.new(name, default, desc))

func get_value(name):
	var found = false
	var idx = 0

	while(idx < options.size() and !found):
		if(options[idx].option_name == name):
			found = true
		else:
			idx += 1

	if(found):
		return options[idx].value
	else:
		print("COULD NOT FIND OPTION " + name)
		return null

func set_banner(banner):
	_banner = banner

func print_help():
	var longest = 0
	for i in range(options.size()):
		if(options[i].option_name.length() > longest):
			longest = options[i].option_name.length()

	print('---------------------------------------------------------')
	print(_banner)

	print("\nOptions\n-------")
	for i in range(options.size()):
		print('  ' + options[i].to_s(longest + 2))
	print('---------------------------------------------------------')

func print_options():
	for i in range(options.size()):
		print(options[i].option_name + '=' + str(options[i].value))

func parse():
	var parser = CmdLineParser.new()

	for i in range(options.size()):
		var t = typeof(options[i].default)
		# only set values that were specified at the command line so that
		# we can punch through default and config values correctly later.
		# Without this check, you can't tell the difference between the
		# defaults and what was specified, so you can't punch through
		# higher level options.
		if(parser.was_specified(options[i].option_name)):
			if(t == TYPE_INT):
				options[i].value = int(parser.get_value(options[i].option_name))
			elif(t == TYPE_STRING):
				options[i].value = parser.get_value(options[i].option_name)
			elif(t == TYPE_ARRAY):
				options[i].value = parser.get_array_value(options[i].option_name)
			elif(t == TYPE_BOOL):
				options[i].value = parser.was_specified(options[i].option_name)
			elif(t == TYPE_NIL):
				print(options[i].option_name + ' cannot be processed, it has a nil datatype')
			else:
				print(options[i].option_name + ' cannot be processed, it has unknown datatype:' + str(t))

	var unused = parser.get_unused_options()
	if(unused.size() > 0):
		print("Unrecognized options:  ", unused)
		return false

	return true

--- Start of ./addons/gut/orphan_counter.gd ---

# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# This is a utility for tracking changes in the orphan count.  Each time
# add_counter is called it adds/resets the value in the dictionary to the
# current number of orphans.  Each call to get_counter will return the change
# in orphans since add_counter was last called.
# ##############################################################################
var _counters = {}

func orphan_count():
	return Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

func add_counter(name):
	_counters[name] = orphan_count()

# Returns the number of orphans created since add_counter was last called for
# the name.  Returns -1 to avoid blowing up with an invalid name but still
# be somewhat visible that we've done something wrong.
func get_counter(name):
	return orphan_count() - _counters[name] if _counters.has(name) else -1

func print_orphans(name, lgr):
	var count = get_counter(name)

	if(count > 0):
		var o = 'orphan'
		if(count > 1):
			o = 'orphans'
		lgr.orphan(str(count, ' new ', o, ' in ', name, '.'))

--- Start of ./addons/gut/parameter_factory.gd ---

# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# This is the home for all parameter creation helpers.  These functions should
# all return an array of values to be used as parameters for parameterized
# tests.
# ##############################################################################

# ------------------------------------------------------------------------------
# Creates an array of dictionaries.  It pairs up the names array with each set
# of values in values.  If more names than values are specified then the missing
# values will be filled with nulls.  If more values than names are specified
# those values will be ignored.
#
# Example:
# 	create_named_parameters(['a', 'b'], [[1, 2], ['one', 'two']]) returns
#		[{a:1, b:2}, {a:'one', b:'two'}]
#
# 	This allows you to increase readability of your parameterized tests:
#	var params = create_named_parameters(['a', 'b'], [[1, 2], ['one', 'two']])
#	func test_foo(p = use_parameters(params)):
#		assert_eq(p.a, p.b)
#
# Parameters:
# 	names:  an array of names to be used as keys in the dictionaries
#   values:  an array of arrays of values.
# ------------------------------------------------------------------------------
static func named_parameters(names, values):
	var named = []
	for i in range(values.size()):
		var entry = {}

		var parray = values[i]
		if(typeof(parray) != TYPE_ARRAY):
			parray = [values[i]]

		for j in range(names.size()):
			if(j >= parray.size()):
				entry[names[j]] = null
			else:
				entry[names[j]] = parray[j]
		named.append(entry)

	return named

# Additional Helper Ideas
# * File.  IDK what it would look like.  csv maybe.
# * Random values within a range?
# * All int values in a range or add an optioanal step.
# *

--- Start of ./addons/gut/parameter_handler.gd ---

var _utils = load('res://addons/gut/utils.gd').get_instance()
var _params = null
var _call_count = 0
var _logger = null

func _init(params=null):
	_params = params
	_logger = _utils.get_logger()
	if(typeof(_params) != TYPE_ARRAY):
		_logger.error('You must pass an array to parameter_handler constructor.')
		_params = null


func next_parameters():
	_call_count += 1
	return _params[_call_count -1]

func get_current_parameters():
	return _params[_call_count]

func is_done():
	var done = true
	if(_params != null):
		done = _call_count == _params.size()
	return done

func get_logger():
	return _logger

func set_logger(logger):
	_logger = logger

func get_call_count():
	return _call_count

func get_parameter_count():
	return _params.size()

--- Start of ./addons/gut/plugin_control.gd ---

# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# This is the control that is added via the editor.  It exposes GUT settings
# through the editor and delays the creation of the GUT instance until
# Engine.get_main_loop() works as expected.
# ##############################################################################
tool
extends Control

# ------------------------------------------------------------------------------
# GUT Settings
# ------------------------------------------------------------------------------
export(String, 'AnonymousPro', 'CourierPrime', 'LobsterTwo', 'Default') var _font_name = 'AnonymousPro'
export(int) var _font_size = 20
export(Color) var _font_color = Color(.8, .8, .8, 1)
export(Color) var _background_color = Color(.15, .15, .15, 1)
# Enable/Disable coloring of output.
export(bool) var _color_output = true
# The full/partial name of a script to select upon startup
export(String) var _select_script = ''
# The full/partial name of a test.  All tests that contain the string will be
# run
export(String) var _tests_like = ''
# The full/partial name of an Inner Class to be run.  All Inner Classes that
# contain the string will be run.
export(String) var _inner_class_name = ''
# Start running tests when the scene finishes loading
export var _run_on_load = false
# Maximize the GUT control on startup
export var _should_maximize = false
# Print output to the consol as well
export var _should_print_to_console = true
# Display orphan counts at the end of tests/scripts.
export var _show_orphans = true
# The log level.
export(int, 'Fail/Errors', 'Errors/Warnings/Test Names', 'Everything') var _log_level = 1
# When enabled GUT will yield between tests to give the GUI time to paint.
# Disabling this can make the program appear to hang and can have some
# unwanted consequences with the timing of freeing objects
export var _yield_between_tests = true
# When GUT compares values it first checks the types to prevent runtime errors.
# This behavior can be disabled if desired.  This flag was added early in
# development to prevent any breaking changes and will likely be removed in
# the future.
export var _disable_strict_datatype_checks = false
# The prefix used to find test scripts.
export var _file_prefix = 'test_'
# The suffix used to find test scripts.
export var _file_suffix = '.gd'
# The prefix used to find Inner Test Classes.
export var _inner_class_prefix = 'Test'
# The directory GUT will use to write any temporary files.  This isn't used
# much anymore since there was a change to the double creation implementation.
# This will be removed in a later release.
export(String) var _temp_directory = 'user://gut_temp_directory'
# The path and filename for exported test information.
export(String) var _export_path = ''
# When enabled, any directory added will also include its subdirectories when
# GUT looks for test scripts.
export var _include_subdirectories = false
# Allow user to add test directories via editor.  This is done with strings
# instead of an array because the interface for editing arrays is really
# cumbersome and complicates testing because arrays set through the editor
# apply to ALL instances.  This also allows the user to use the built in
# dialog to pick a directory.
export(String, DIR) var _directory1 = ''
export(String, DIR) var _directory2 = ''
export(String, DIR) var _directory3 = ''
export(String, DIR) var _directory4 = ''
export(String, DIR) var _directory5 = ''
export(String, DIR) var _directory6 = ''
# Must match the types in _utils for double strategy
export(int, 'FULL', 'PARTIAL') var _double_strategy = 1
# Path and filename to the script to run before all tests are run.
export(String, FILE) var _pre_run_script = ''
# Path and filename to the script to run after all tests are run.
export(String, FILE) var _post_run_script = ''
# Path to the file that gut will export results to in the junit xml format
export(String, FILE) var _junit_xml_file = ''
# Flag to include a timestamp in the filename of _junit_xml_file
export(bool) var _junit_xml_timestamp = false
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
# Emitted when all the tests have finished running.
signal tests_finished
# Emitted when GUT is ready to be interacted with, and before any tests are run.
signal gut_ready


# ------------------------------------------------------------------------------
# Private stuff.
# ------------------------------------------------------------------------------
var _gut = null
var _lgr = null
var _cancel_import = false
var _placeholder = null

func _init():
	# This min size has to be what the min size of the GutScene's min size is
	# but it has to be set here and not inferred i think.
	rect_min_size = Vector2(740, 250)

func _ready():
	# Must call this deferred so that there is enough time for
	# Engine.get_main_loop() is populated and the psuedo singleton utils.gd
	# can be setup correctly.
	if(Engine.editor_hint):
		_placeholder = load('res://addons/gut/GutScene.tscn').instance()
		call_deferred('add_child', _placeholder)
		_placeholder.rect_size = rect_size
	else:
		call_deferred('_setup_gut')

	connect('resized', self,  '_on_resized')

func _on_resized():
	if(_placeholder != null):
		_placeholder.rect_size = rect_size


# Templates can be missing if tests are exported and the export config for the
# project does not include '*.txt' files.  This check and related flags make
# sure GUT does not blow up and that the error is not lost in all the import
# output that is generated as well as ensuring that no tests are run.
#
# Assumption:  This is only a concern when running from the scene since you
# cannot run GUT from the command line in an exported game.
func _check_for_templates():
	var f = File.new()
	if(!f.file_exists('res://addons/gut/double_templates/function_template.txt')):
		_lgr.error('Templates are missing.  Make sure you are exporting "*.txt" or "addons/gut/double_templates/*.txt".')
		_run_on_load = false
		_cancel_import = true
		return false
	return true

func _setup_gut():
	var _utils = load('res://addons/gut/utils.gd').get_instance()

	_lgr = _utils.get_logger()
	_gut = load('res://addons/gut/gut.gd').new()
	_gut.connect('tests_finished', self, '_on_tests_finished')

	if(!_check_for_templates()):
		return

	_gut._select_script = _select_script
	_gut._tests_like = _tests_like
	_gut._inner_class_name = _inner_class_name

	_gut._file_prefix = _file_prefix
	_gut._inner_class_prefix = _inner_class_prefix
	_gut._temp_directory = _temp_directory

	_gut.set_should_maximize(_should_maximize)
	_gut.set_yield_between_tests(_yield_between_tests)
	_gut.disable_strict_datatype_checks(_disable_strict_datatype_checks)
	_gut.set_export_path(_export_path)
	_gut.set_include_subdirectories(_include_subdirectories)
	_gut.set_double_strategy(_double_strategy)
	_gut.set_pre_run_script(_pre_run_script)
	_gut.set_post_run_script(_post_run_script)
	_gut.set_color_output(_color_output)
	_gut.show_orphans(_show_orphans)
	_gut.set_junit_xml_file(_junit_xml_file)
	_gut.set_junit_xml_timestamp(_junit_xml_timestamp)

	get_parent().add_child(_gut)

	if(!_utils.is_version_ok()):
		return

	_gut.set_log_level(_log_level)

	_gut.add_directory(_directory1)
	_gut.add_directory(_directory2)
	_gut.add_directory(_directory3)
	_gut.add_directory(_directory4)
	_gut.add_directory(_directory5)
	_gut.add_directory(_directory6)

	_gut.get_logger().disable_printer('console', !_should_print_to_console)
	# When file logging enabled then the log will contain terminal escape
	# strings.  So when running the scene this is disabled.  Also if enabled
	# this may cause duplicate entries into the logs.
	_gut.get_logger().disable_printer('terminal', true)

	_gut.get_gui().set_font_size(_font_size)
	_gut.get_gui().set_font(_font_name)
	_gut.get_gui().set_default_font_color(_font_color)
	_gut.get_gui().set_background_color(_background_color)
	_gut.get_gui().rect_size =  rect_size
	emit_signal('gut_ready')

	if(_run_on_load):
		# Run the test scripts.  If one has been selected then only run that one
		# otherwise all tests will be run.
		var run_rest_of_scripts = _select_script == null
		_gut.test_scripts(run_rest_of_scripts)

func _is_ready_to_go(action):
	if(_gut == null):
		push_error(str('GUT is not ready for ', action, ' yet.  Perform actions on GUT in/after the gut_ready signal.'))
	return _gut != null

func _on_tests_finished():
	emit_signal('tests_finished')

func get_gut():
	return _gut

func export_if_tests_found():
	if(_is_ready_to_go('export_if_tests_found')):
		_gut.export_if_tests_found()

func import_tests_if_none_found():
	if(_is_ready_to_go('import_tests_if_none_found') and !_cancel_import):
		_gut.import_tests_if_none_found()

--- Start of ./addons/gut/printers.gd ---

# ------------------------------------------------------------------------------
# Interface and some basic functionality for all printers.
# ------------------------------------------------------------------------------
class Printer:
	var _format_enabled = true
	var _disabled = false
	var _printer_name = 'NOT SET'
	var _show_name = false # used for debugging, set manually

	func get_format_enabled():
		return _format_enabled

	func set_format_enabled(format_enabled):
		_format_enabled = format_enabled

	func send(text, fmt=null):
		if(_disabled):
			return

		var formatted = text
		if(fmt != null and _format_enabled):
			formatted = format_text(text, fmt)

		if(_show_name):
			formatted = str('(', _printer_name, ')') + formatted

		_output(formatted)

	func get_disabled():
		return _disabled

	func set_disabled(disabled):
		_disabled = disabled

	# --------------------
	# Virtual Methods (some have some default behavior)
	# --------------------
	func _output(text):
		pass

	func format_text(text, fmt):
		return text

# ------------------------------------------------------------------------------
# Responsible for sending text to a GUT gui.
# ------------------------------------------------------------------------------
class GutGuiPrinter:
	extends Printer
	var _gut = null

	var _colors = {
			red = Color.red,
			yellow = Color.yellow,
			green = Color.green
	}

	func _init():
		_printer_name = 'gui'

	func _wrap_with_tag(text, tag):
		return str('[', tag, ']', text, '[/', tag, ']')

	func _color_text(text, c_word):
		return '[color=' + c_word + ']' + text + '[/color]'

	# Remember, we have to use push and pop because the output from the tests
	# can contain [] in it which can mess up the formatting.  There is no way
	# as of 3.4 that you can get the bbcode out of RTL when using push and pop.
	#
	# The only way we could get around this is by adding in non-printable
	# whitespace after each "[" that is in the text.  Then we could maybe do
	# this another way and still be able to get the bbcode out, or generate it
	# at the same time in a buffer (like we tried that one time).
	#
	# Since RTL doesn't have good search and selection methods, and those are
	# really handy in the editor, it isn't worth making bbcode that can be used
	# there as well.
	#
	# You'll try to get it so the colors can be the same in the editor as they
	# are in the output.  Good luck, and I hope I typed enough to not go too
	# far that rabbit hole before finding out it's not worth it.
	func format_text(text, fmt):
		var box = _gut.get_gui().get_text_box()

		if(fmt == 'bold'):
			box.push_bold()
		elif(fmt == 'underline'):
			box.push_underline()
		elif(_colors.has(fmt)):
			box.push_color(_colors[fmt])
		else:
			# just pushing something to pop.
			box.push_normal()

		box.add_text(text)
		box.pop()

		return ''

	func _output(text):
		_gut.get_gui().get_text_box().add_text(text)

	func get_gut():
		return _gut

	func set_gut(gut):
		_gut = gut

	# This can be very very slow when the box has a lot of text.
	func clear_line():
		var box = _gut.get_gui().get_text_box()
		box.remove_line(box.get_line_count() - 1)
		box.update()

	func get_bbcode():
		return _gut.get_gui().get_text_box().text

# ------------------------------------------------------------------------------
# This AND TerminalPrinter should not be enabled at the same time since it will
# result in duplicate output.  printraw does not print to the console so i had
# to make another one.
# ------------------------------------------------------------------------------
class ConsolePrinter:
	extends Printer
	var _buffer = ''

	func _init():
		_printer_name = 'console'

	# suppresses output until it encounters a newline to keep things
	# inline as much as possible.
	func _output(text):
		if(text.ends_with("\n")):
			print(_buffer + text.left(text.length() -1))
			_buffer = ''
		else:
			_buffer += text

# ------------------------------------------------------------------------------
# Prints text to terminal, formats some words.
# ------------------------------------------------------------------------------
class TerminalPrinter:
	extends Printer

	var escape = PoolByteArray([0x1b]).get_string_from_ascii()
	var cmd_colors  = {
		red = escape + '[31m',
		yellow = escape + '[33m',
		green = escape + '[32m',

		underline = escape + '[4m',
		bold = escape + '[1m',

		default = escape + '[0m',

		clear_line = escape + '[2K'
	}

	func _init():
		_printer_name = 'terminal'

	func _output(text):
		# Note, printraw does not print to the console.
		printraw(text)

	func format_text(text, fmt):
		return cmd_colors[fmt] + text + cmd_colors.default

	func clear_line():
		send(cmd_colors.clear_line)

	func back(n):
		send(escape + str('[', n, 'D'))

	func forward(n):
		send(escape + str('[', n, 'C'))

--- Start of ./addons/gut/result_exporter.gd ---

# ------------------------------------------------------------------------------
# Creates a structure that contains all the data about the results of running
# tests.  This was created to make an intermediate step organizing the result
# of a run and exporting it in a specific format.  This can also serve as a
# unofficial GUT export format.
# ------------------------------------------------------------------------------
var _utils = load('res://addons/gut/utils.gd').get_instance()

func _export_tests(summary_script):
	var to_return = {}
	var tests = summary_script.get_tests()
	for key in tests.keys():
		to_return[key] = {
			"status":tests[key].get_status(),
			"passing":tests[key].pass_texts,
			"failing":tests[key].fail_texts,
			"pending":tests[key].pending_texts,
			"orphans":tests[key].orphans
		}

	return to_return

# TODO
#	errors
func _export_scripts(summary):
	if(summary == null):
		return {}

	var scripts = {}

	for s in summary.get_scripts():
		scripts[s.name] = {
			'props':{
				"tests":s._tests.size(),
				"pending":s.get_pending_count(),
				"failures":s.get_fail_count(),
			},
			"tests":_export_tests(s)
		}
	return scripts

func _make_results_dict():
	var result =  {
		'test_scripts':{
			"props":{
				"pending":0,
				"failures":0,
				"passing":0,
				"tests":0,
				"time":0,
				"orphans":0,
				"errors":0,
				"warnings":0
			},
			"scripts":[]
		}
	}
	return result


# TODO
#	time
#	errors
func get_results_dictionary(gut, include_scripts=true):
	var summary = gut.get_summary()
	var scripts = []

	if(include_scripts):
		scripts = _export_scripts(summary)

	var result =  _make_results_dict()
	if(summary != null):
		var totals = summary.get_totals()

		var props = result.test_scripts.props
		props.pending = totals.pending
		props.failures = totals.failing
		props.passing = totals.passing_tests
		props.tests = totals.tests
		props.errors = gut.get_logger().get_errors().size()
		props.warnings = gut.get_logger().get_warnings().size()
		props.time = gut.get_gui().elapsed_time_as_str().replace('s', '')
		props.orphans = gut.get_orphan_counter().get_counter('total')
		result.test_scripts.scripts = scripts

	return result


func write_json_file(gut, path):
	var dict = get_results_dictionary(gut)
	var json = JSON.print(dict, ' ')

	var f_result = _utils.write_file(path, json)
	if(f_result != OK):
		var msg = str("Error:  ", f_result, ".  Could not create export file ", path)
		_utils.get_logger().error(msg)

	return f_result



func write_summary_file(gut, path):
	var dict = get_results_dictionary(gut, false)
	var json = JSON.print(dict, ' ')

	var f_result = _utils.write_file(path, json)
	if(f_result != OK):
		var msg = str("Error:  ", f_result, ".  Could not create export file ", path)
		_utils.get_logger().error(msg)

	return f_result

--- Start of ./addons/gut/signal_watcher.gd ---

# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################

# Some arbitrary string that should never show up by accident.  If it does, then
# shame on  you.
const ARG_NOT_SET = "_*_argument_*_is_*_not_set_*_"

# This hash holds the objects that are being watched, the signals that are being
# watched, and an array of arrays that contains arguments that were passed
# each time the signal was emitted.
#
# For example:
#	_watched_signals => {
#		ref1 => {
#			'signal1' => [[], [], []],
#			'signal2' => [[p1, p2]],
#			'signal3' => [[p1]]
#		},
#		ref2 => {
#			'some_signal' => [],
#			'other_signal' => [[p1, p2, p3], [p1, p2, p3], [p1, p2, p3]]
#		}
#	}
#
# In this sample:
#	- signal1 on the ref1 object was emitted 3 times and each time, zero
#	  parameters were passed.
#	- signal3 on ref1 was emitted once and passed a single parameter
#	- some_signal on ref2 was never emitted.
#	- other_signal on ref2 was emitted 3 times, each time with 3 parameters.
var _watched_signals = {}
var _utils = load("res://addons/gut/utils.gd").get_instance()


func _add_watched_signal(obj, name):
	# SHORTCIRCUIT - ignore dupes
	if _watched_signals.has(obj) and _watched_signals[obj].has(name):
		return

	if !_watched_signals.has(obj):
		_watched_signals[obj] = {name: []}
	else:
		_watched_signals[obj][name] = []
	obj.connect(name, self, "_on_watched_signal", [obj, name])


# This handles all the signals that are watched.  It supports up to 9 parameters
# which could be emitted by the signal and the two parameters used when it is
# connected via watch_signal.  I chose 9 since you can only specify up to 9
# parameters when dynamically calling a method via call (per the Godot
# documentation, i.e. some_object.call('some_method', 1, 2, 3...)).
#
# Based on the documentation of emit_signal, it appears you can only pass up
# to 4 parameters when firing a signal.  I haven't verified this, but this should
# future proof this some if the value ever grows.
func _on_watched_signal(
	arg1 = ARG_NOT_SET,
	arg2 = ARG_NOT_SET,
	arg3 = ARG_NOT_SET,
	arg4 = ARG_NOT_SET,
	arg5 = ARG_NOT_SET,
	arg6 = ARG_NOT_SET,
	arg7 = ARG_NOT_SET,
	arg8 = ARG_NOT_SET,
	arg9 = ARG_NOT_SET,
	arg10 = ARG_NOT_SET,
	arg11 = ARG_NOT_SET
):
	var args = [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11]

	# strip off any unused vars.
	var idx = args.size() - 1
	while str(args[idx]) == ARG_NOT_SET:
		args.remove(idx)
		idx -= 1

	# retrieve object and signal name from the array and remove them.  These
	# will always be at the end since they are added when the connect happens.
	var signal_name = args[args.size() - 1]
	args.pop_back()
	var object = args[args.size() - 1]
	args.pop_back()

	_watched_signals[object][signal_name].append(args)


func does_object_have_signal(object, signal_name):
	var signals = object.get_signal_list()
	for i in range(signals.size()):
		if signals[i]["name"] == signal_name:
			return true
	return false


func watch_signals(object):
	var signals = object.get_signal_list()
	for i in range(signals.size()):
		_add_watched_signal(object, signals[i]["name"])


func watch_signal(object, signal_name):
	var did = false
	if does_object_have_signal(object, signal_name):
		_add_watched_signal(object, signal_name)
		did = true
	return did


func get_emit_count(object, signal_name):
	var to_return = -1
	if is_watching(object, signal_name):
		to_return = _watched_signals[object][signal_name].size()
	return to_return


func did_emit(object, signal_name):
	var did = false
	if is_watching(object, signal_name):
		did = get_emit_count(object, signal_name) != 0
	return did


func print_object_signals(object):
	var list = object.get_signal_list()
	for i in range(list.size()):
		print(list[i].name, "\n  ", list[i])


func get_signal_parameters(object, signal_name, index = -1):
	var params = null
	if is_watching(object, signal_name):
		var all_params = _watched_signals[object][signal_name]
		if all_params.size() > 0:
			if index == -1:
				index = all_params.size() - 1
			params = all_params[index]
	return params


func is_watching_object(object):
	return _watched_signals.has(object)


func is_watching(object, signal_name):
	return _watched_signals.has(object) and _watched_signals[object].has(signal_name)


func clear():
	for obj in _watched_signals:
		if _utils.is_not_freed(obj):
			for signal_name in _watched_signals[obj]:
				obj.disconnect(signal_name, self, "_on_watched_signal")
	_watched_signals.clear()


# Returns a list of all the signal names that were emitted by the object.
# If the object is not being watched then an empty list is returned.
func get_signals_emitted(obj):
	var emitted = []
	if is_watching_object(obj):
		for signal_name in _watched_signals[obj]:
			if _watched_signals[obj][signal_name].size() > 0:
				emitted.append(signal_name)

	return emitted

--- Start of ./addons/gut/spy.gd ---

# {
#   instance_id_or_path1:{
#       method1:[ [p1, p2], [p1, p2] ],
#       method2:[ [p1, p2], [p1, p2] ]
#   },
#   instance_id_or_path1:{
#       method1:[ [p1, p2], [p1, p2] ],
#       method2:[ [p1, p2], [p1, p2] ]
#   },
# }
var _calls = {}
var _utils = load('res://addons/gut/utils.gd').get_instance()
var _lgr = _utils.get_logger()
var _compare = _utils.Comparator.new()

func _find_parameters(call_params, params_to_find):
	var found = false
	var idx = 0
	while(idx < call_params.size() and !found):
		var result = _compare.deep(call_params[idx], params_to_find)
		if(result.are_equal):
			found = true
		else:
			idx += 1
	return found

func _get_params_as_string(params):
	var to_return = ''
	if(params == null):
		return ''

	for i in range(params.size()):
		if(params[i] == null):
			to_return += 'null'
		else:
			if(typeof(params[i]) == TYPE_STRING):
				to_return += str('"', params[i], '"')
			else:
				to_return += str(params[i])
		if(i != params.size() -1):
			to_return += ', '
	return to_return

func add_call(variant, method_name, parameters=null):
	if(!_calls.has(variant)):
		_calls[variant] = {}

	if(!_calls[variant].has(method_name)):
		_calls[variant][method_name] = []

	_calls[variant][method_name].append(parameters)

func was_called(variant, method_name, parameters=null):
	var to_return = false
	if(_calls.has(variant) and _calls[variant].has(method_name)):
		if(parameters):
			to_return = _find_parameters(_calls[variant][method_name], parameters)
		else:
			to_return = true
	return to_return

func get_call_parameters(variant, method_name, index=-1):
	var to_return = null
	var get_index = -1

	if(_calls.has(variant) and _calls[variant].has(method_name)):
		var call_size = _calls[variant][method_name].size()
		if(index == -1):
			# get the most recent call by default
			get_index =  call_size -1
		else:
			get_index = index

		if(get_index < call_size):
			to_return = _calls[variant][method_name][get_index]
		else:
			_lgr.error(str('Specified index ', index, ' is outside range of the number of registered calls:  ', call_size))

	return to_return

func call_count(instance, method_name, parameters=null):
	var to_return = 0

	if(was_called(instance, method_name)):
		if(parameters):
			for i in range(_calls[instance][method_name].size()):
				if(_calls[instance][method_name][i] == parameters):
					to_return += 1
		else:
			to_return = _calls[instance][method_name].size()
	return to_return

func clear():
	_calls = {}

func get_call_list_as_string(instance):
	var to_return = ''
	if(_calls.has(instance)):
		for method in _calls[instance]:
			for i in range(_calls[instance][method].size()):
				to_return += str(method, '(', _get_params_as_string(_calls[instance][method][i]), ")\n")
	return to_return

func get_logger():
	return _lgr

func set_logger(logger):
	_lgr = logger

--- Start of ./addons/gut/strutils.gd ---


var _utils = load('res://addons/gut/utils.gd').get_instance()
# Hash containing all the built in types in Godot.  This provides an English
# name for the types that corosponds with the type constants defined in the
# engine.
var types = {}
var NativeScriptClass = null

func _init_types_dictionary():
	types[TYPE_NIL] = 'TYPE_NIL'
	types[TYPE_BOOL] = 'Bool'
	types[TYPE_INT] = 'Int'
	types[TYPE_REAL] = 'Float/Real'
	types[TYPE_STRING] = 'String'
	types[TYPE_VECTOR2] = 'Vector2'
	types[TYPE_RECT2] = 'Rect2'
	types[TYPE_VECTOR3] = 'Vector3'
	#types[8] = 'Matrix32'
	types[TYPE_PLANE] = 'Plane'
	types[TYPE_QUAT] = 'QUAT'
	types[TYPE_AABB] = 'AABB'
	#types[12] = 'Matrix3'
	types[TYPE_TRANSFORM] = 'Transform'
	types[TYPE_COLOR] = 'Color'
	#types[15] = 'Image'
	types[TYPE_NODE_PATH] = 'Node Path'
	types[TYPE_RID] = 'RID'
	types[TYPE_OBJECT] = 'TYPE_OBJECT'
	#types[19] = 'TYPE_INPUT_EVENT'
	types[TYPE_DICTIONARY] = 'Dictionary'
	types[TYPE_ARRAY] = 'Array'
	types[TYPE_RAW_ARRAY] = 'TYPE_RAW_ARRAY'
	types[TYPE_INT_ARRAY] = 'TYPE_INT_ARRAY'
	types[TYPE_REAL_ARRAY] = 'TYPE_REAL_ARRAY'
	types[TYPE_STRING_ARRAY] = 'TYPE_STRING_ARRAY'
	types[TYPE_VECTOR2_ARRAY] = 'TYPE_VECTOR2_ARRAY'
	types[TYPE_VECTOR3_ARRAY] = 'TYPE_VECTOR3_ARRAY'
	types[TYPE_COLOR_ARRAY] = 'TYPE_COLOR_ARRAY'
	types[TYPE_MAX] = 'TYPE_MAX'

# Types to not be formatted when using _str
var _str_ignore_types = [
	TYPE_INT, TYPE_REAL, TYPE_STRING,
	TYPE_NIL, TYPE_BOOL
]

func _init():
	_init_types_dictionary()
	# NativeScript does not exist when GDNative is not included in the build
	if(type_exists('NativeScript')):
		var getter = load('res://addons/gut/get_native_script.gd')
		NativeScriptClass = getter.get_it()

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func _get_filename(path):
	return path.split('/')[-1]

# ------------------------------------------------------------------------------
# Gets the filename of an object passed in.  This does not return the
# full path to the object, just the filename.
# ------------------------------------------------------------------------------
func _get_obj_filename(thing):
	var filename = null

	if(thing == null or
		!is_instance_valid(thing) or
		str(thing) == '[Object:null]' or
		typeof(thing) != TYPE_OBJECT or
		thing.has_method('__gut_instance_from_id')):
		return

	if(thing.get_script() == null):
		if(thing is PackedScene):
			filename = _get_filename(thing.resource_path)
		else:
			# If it isn't a packed scene and it doesn't have a script then
			# we do nothing.  This just read better.
			pass
	elif(NativeScriptClass != null and thing.get_script() is NativeScriptClass):
		# Work with GDNative scripts:
		# inst2dict fails with "Not a script with an instance" on GDNative script instances
		filename = _get_filename(thing.get_script().resource_path)
	elif(!_utils.is_native_class(thing)):
		var dict = inst2dict(thing)
		filename = _get_filename(dict['@path'])
		if(dict['@subpath'] != ''):
			filename += str('/', dict['@subpath'])

	return filename

# ------------------------------------------------------------------------------
# Better object/thing to string conversion.  Includes extra details about
# whatever is passed in when it can/should.
# ------------------------------------------------------------------------------
func type2str(thing):
	var filename = _get_obj_filename(thing)
	var str_thing = str(thing)

	if(thing == null):
		# According to str there is a difference between null and an Object
		# that is somehow null.  To avoid getting '[Object:null]' as output
		# always set it to str(null) instead of str(thing).  A null object
		# will pass typeof(thing) == TYPE_OBJECT check so this has to be
		# before that.
		str_thing = str(null)
	elif(typeof(thing) == TYPE_REAL):
		if(!'.' in str_thing):
			str_thing += '.0'
	elif(typeof(thing) == TYPE_STRING):
		str_thing = str('"', thing, '"')
	elif(typeof(thing) in _str_ignore_types):
		# do nothing b/c we already have str(thing) in
		# to_return.  I think this just reads a little
		# better this way.
		pass
	elif(typeof(thing) ==  TYPE_OBJECT):
		if(_utils.is_native_class(thing)):
			str_thing = _utils.get_native_class_name(thing)
		elif(_utils.is_double(thing)):
			var double_path = _get_filename(thing.__gut_metadata_.path)
			if(thing.__gut_metadata_.subpath != ''):
				double_path += str('/', thing.__gut_metadata_.subpath)
			elif(thing.__gut_metadata_.from_singleton != ''):
				double_path = thing.__gut_metadata_.from_singleton + " Singleton"

			var double_type = "double"
			if(thing.__gut_metadata_.is_partial):
				double_type = "partial-double"

			str_thing += str("(", double_type, " of ", double_path, ")")

			filename = null
	elif(types.has(typeof(thing))):
		if(!str_thing.begins_with('(')):
			str_thing = '(' + str_thing + ')'
		str_thing = str(types[typeof(thing)], str_thing)

	if(filename != null):
		str_thing += str('(', filename, ')')
	return str_thing

# ------------------------------------------------------------------------------
# Returns the string truncated with an '...' in it.  Shows the start and last
# 10 chars.  If the string is  smaller than max_size the entire string is
# returned.  If max_size is -1 then truncation is skipped.
# ------------------------------------------------------------------------------
func truncate_string(src, max_size):
	var to_return = src
	if(src.length() > max_size - 10 and max_size != -1):
		to_return = str(src.substr(0, max_size - 10), '...',  src.substr(src.length() - 10, src.length()))
	return to_return


func _get_indent_text(times, pad):
	var to_return = ''
	for i in range(times):
		to_return += pad

	return to_return

func indent_text(text, times, pad):
	if(times == 0):
		return text

	var to_return = text
	var ending_newline = ''

	if(text.ends_with("\n")):
		ending_newline = "\n"
		to_return = to_return.left(to_return.length() -1)

	var padding = _get_indent_text(times, pad)
	to_return = to_return.replace("\n", "\n" + padding)
	to_return += ending_newline

	return padding + to_return

--- Start of ./addons/gut/stubber.gd ---

# -------------
# returns{} and parameters {} have the followin structure
# -------------
# {
# 	inst_id_or_path1:{
# 		method_name1: [StubParams, StubParams],
# 		method_name2: [StubParams, StubParams]
# 	},
# 	inst_id_or_path2:{
# 		method_name1: [StubParams, StubParams],
# 		method_name2: [StubParams, StubParams]
# 	}
# }
var returns = {}
var _utils = load('res://addons/gut/utils.gd').get_instance()
var _lgr = _utils.get_logger()
var _strutils = _utils.Strutils.new()


func _make_key_from_metadata(doubled):
	var to_return = doubled.__gut_metadata_.path

	if(doubled.__gut_metadata_.from_singleton != ''):
		to_return = str(doubled.__gut_metadata_.from_singleton)
	elif(doubled.__gut_metadata_.subpath != ''):
		to_return += str('-', doubled.__gut_metadata_.subpath)

	return to_return


# Creates they key for the returns hash based on the type of object passed in
# obj could be a string of a path to a script with an optional subpath or
# it could be an instance of a doubled object.
func _make_key_from_variant(obj, subpath=null):
	var to_return = null

	match typeof(obj):
		TYPE_STRING:
			# this has to match what is done in _make_key_from_metadata
			to_return = obj
			if(subpath != null and subpath != ''):
				to_return += str('-', subpath)
		TYPE_OBJECT:
			if(_utils.is_instance(obj)):
				to_return = _make_key_from_metadata(obj)
			elif(_utils.is_native_class(obj)):
				to_return = _utils.get_native_class_name(obj)
			else:
				to_return = obj.resource_path

	return to_return


func _add_obj_method(obj, method, subpath=null):
	var key = _make_key_from_variant(obj, subpath)
	if(_utils.is_instance(obj)):
		key = obj

	if(!returns.has(key)):
		returns[key] = {}
	if(!returns[key].has(method)):
		returns[key][method] = []

	return key

# ##############
# Public
# ##############

# Searches returns for an entry that matches the instance or the class that
# passed in obj is.
#
# obj can be an instance, class, or a path.
func _find_stub(obj, method, parameters=null, find_overloads=false):
	var key = _make_key_from_variant(obj)
	var to_return = null

	if(_utils.is_instance(obj)):
		if(returns.has(obj) and returns[obj].has(method)):
			key = obj
		elif(obj.get('__gut_metadata_')):
			key = _make_key_from_metadata(obj)

	if(returns.has(key) and returns[key].has(method)):
		var param_match = null
		var null_match = null
		var overload_match = null

		for i in range(returns[key][method].size()):
			if(returns[key][method][i].parameters == parameters):
				param_match = returns[key][method][i]

			if(returns[key][method][i].parameters == null):
				null_match = returns[key][method][i]

			if(returns[key][method][i].has_param_override()):
				overload_match = returns[key][method][i]

		if(find_overloads and overload_match != null):
			to_return = overload_match
		# We have matching parameter values so return the stub value for that
		elif(param_match != null):
			to_return = param_match
		# We found a case where the parameters were not specified so return
		# parameters for that.  Only do this if the null match is not *just*
		# a paramerter override stub.
		elif(null_match != null and !null_match.is_param_override_only()):
			to_return = null_match



	return to_return


func add_stub(stub_params):
	stub_params._lgr = _lgr
	var key = _add_obj_method(stub_params.stub_target, stub_params.stub_method, stub_params.target_subpath)
	returns[key][stub_params.stub_method].append(stub_params)


# Gets a stubbed return value for the object and method passed in.  If the
# instance was stubbed it will use that, otherwise it will use the path and
# subpath of the object to try to find a value.
#
# It will also use the optional list of parameter values to find a value.  If
# the object was stubbed with no parameters than any parameters will match.
# If it was stubbed with specific parameter values then it will try to match.
# If the parameters do not match BUT there was also an empty parameter list stub
# then it will return those.
# If it cannot find anything that matches then null is returned.for
#
# Parameters
# obj:  this should be an instance of a doubled object.
# method:  the method called
# parameters:  optional array of parameter vales to find a return value for.
func get_return(obj, method, parameters=null):
	var stub_info = _find_stub(obj, method, parameters)

	if(stub_info != null):
		return stub_info.return_val
	else:
		_lgr.warn(str('Call to [', method, '] was not stubbed for the supplied parameters ', parameters, '.  Null was returned.'))
		return null


func should_call_super(obj, method, parameters=null):
	if(_utils.non_super_methods.has(method)):
		return false

	var stub_info = _find_stub(obj, method, parameters)

	var is_partial = false
	if(typeof(obj) != TYPE_STRING): # some stubber tests test with strings
		is_partial = obj.__gut_metadata_.is_partial
	var should = is_partial

	if(stub_info != null):
		should = stub_info.call_super
	elif(!is_partial):
		# this log message is here because of how the generated doubled scripts
		# are structured.  With this log msg here, you will only see one
		# "unstubbed" info instead of multiple.
		_lgr.info('Unstubbed call to ' + method + '::' + _strutils.type2str(obj))
		should = false

	return should


func get_parameter_count(obj, method):
	var to_return = null
	var stub_info = _find_stub(obj, method, null, true)

	if(stub_info != null and stub_info.has_param_override()):
		to_return = stub_info.parameter_count

	return to_return


func get_default_value(obj, method, p_index):
	var to_return = null
	var stub_info = _find_stub(obj, method, null, true)

	if(stub_info != null and
		stub_info.parameter_defaults != null and
		stub_info.parameter_defaults.size() > p_index):

		to_return = stub_info.parameter_defaults[p_index]

	return to_return


func clear():
	returns.clear()


func get_logger():
	return _lgr


func set_logger(logger):
	_lgr = logger


func to_s():
	var text = ''
	for thing in returns:
		text += str("-- ", thing, " --\n")
		for method in returns[thing]:
			text += str("\t", method, "\n")
			for i in range(returns[thing][method].size()):
				text += "\t\t" + returns[thing][method][i].to_s() + "\n"

	if(text == ''):
		text = 'Stubber is empty';

	return text

--- Start of ./addons/gut/stub_params.gd ---

var _utils = load('res://addons/gut/utils.gd').get_instance()
var _lgr = _utils.get_logger()

var return_val = null
var stub_target = null
var target_subpath = null
# the parameter values to match method call on.
var parameters = null
var stub_method = null
var call_super = false

# -- Paramter Override --
# Parmater overrides are stored in here along with all the other stub info
# so that you can chain stubbing parameter overrides along with all the
# other stubbing.  This adds some complexity to the logic that tries to
# find the correct stub for a call by a double.  Since an instance of this
# class could be just a parameter override, or it could have been chained
# we have to have _paramter_override_only so that we know when to tell the
# difference.
var parameter_count = -1
var parameter_defaults = null
# Anything that would make this stub not just an override of paramters
# must set this flag to false.  This must be private bc the actual logic
# to determine if this stub is only an override is more complicated.
var _parameter_override_only = true
# --

const NOT_SET = '|_1_this_is_not_set_1_|'

func _init(target=null, method=null, subpath=null):
	stub_target = target
	stub_method = method
	target_subpath = subpath


func to_return(val):
	if(stub_method == '_init'):
		_lgr.error("You cannot stub _init to do nothing.  Super's _init is always called.")
	else:
		return_val = val
		call_super = false
		_parameter_override_only = false
	return self


func to_do_nothing():
	to_return(null)
	return self


func to_call_super():
	if(stub_method == '_init'):
		_lgr.error("You cannot stub _init to call super.  Super's _init is always called.")
	else:
		call_super = true
		_parameter_override_only = false
	return self


func when_passed(p1=NOT_SET,p2=NOT_SET,p3=NOT_SET,p4=NOT_SET,p5=NOT_SET,p6=NOT_SET,p7=NOT_SET,p8=NOT_SET,p9=NOT_SET,p10=NOT_SET):
	parameters = [p1,p2,p3,p4,p5,p6,p7,p8,p9,p10]
	var idx = 0
	while(idx < parameters.size()):
		if(str(parameters[idx]) == NOT_SET):
			parameters.remove(idx)
		else:
			idx += 1
	return self


func param_count(x):
	parameter_count = x
	return self


func param_defaults(values):
	parameter_count = values.size()
	parameter_defaults = values
	return self


func has_param_override():
	return parameter_count != -1


func is_param_override_only():
	var to_return = false
	if(has_param_override()):
		to_return = _parameter_override_only
	return to_return


func to_s():
	var base_string = str(stub_target)
	if(target_subpath != null):
		base_string += str('[', target_subpath, '].')
	else:
		base_string += '.'
	base_string += stub_method

	if(has_param_override()):
		base_string += str(' (param count override=', parameter_count, ' defaults=', parameter_defaults)
		if(is_param_override_only()):
			base_string += " ONLY"
		base_string += ') '

	if(call_super):
		base_string += " to call SUPER"

	if(parameters != null):
		base_string += str(' with params (', parameters, ') returns ', return_val)

	return base_string

--- Start of ./addons/gut/summary.gd ---

# ------------------------------------------------------------------------------
# Contains all the results of a single test.  Allows for multiple asserts results
# and pending calls.
#
# When determining the status of a test, check for failing then passing then
# pending.
# ------------------------------------------------------------------------------
class Test:
	var pass_texts = []
	var fail_texts = []
	var pending_texts = []
	var orphans = 0
	var line_number = 0

	# must have passed an assert and not have any other status to be passing
	func is_passing():
		return pass_texts.size() > 0 and fail_texts.size() == 0 and pending_texts.size() == 0

	# failing takes precedence over everything else, so any failures makes the
	# test a failure.
	func is_failing():
		return fail_texts.size() > 0

	# test is only pending if pending was called and the test is not failing.
	func is_pending():
		return pending_texts.size() > 0 and fail_texts.size() == 0

	func did_something():
		return is_passing() or is_failing() or is_pending()


	# NOTE:  The "failed" and "pending" text must match what is outputted by
	# the logger in order for text highlighting to occur in summary.
	func to_s():
		var pad = '     '
		var to_return = ''
		for i in range(fail_texts.size()):
			to_return += str(pad, '[Failed]:  ', fail_texts[i], "\n")
		for i in range(pending_texts.size()):
			to_return += str(pad, '[Pending]:  ', pending_texts[i], "\n")
		return to_return

	func get_status():
		var to_return = 'no asserts'
		if(pending_texts.size() > 0):
			to_return = 'pending'
		elif(fail_texts.size() > 0):
			to_return = 'fail'
		elif(pass_texts.size() > 0):
			to_return = 'pass'

		return to_return

# ------------------------------------------------------------------------------
# Contains all the results for a single test-script/inner class.  Persists the
# names of the tests and results and the order in which  the tests were run.
# ------------------------------------------------------------------------------
class TestScript:
	var name = 'NOT_SET'
	var _tests = {}
	var _test_order = []

	func _init(script_name):
		name = script_name

	func get_pass_count():
		var count = 0
		for key in _tests:
			count += _tests[key].pass_texts.size()
		return count

	func get_fail_count():
		var count = 0
		for key in _tests:
			count += _tests[key].fail_texts.size()
		return count

	func get_pending_count():
		var count = 0
		for key in _tests:
			count += _tests[key].pending_texts.size()
		return count

	func get_passing_test_count():
		var count = 0
		for key in _tests:
			if(_tests[key].is_passing()):
				count += 1
		return count

	func get_failing_test_count():
		var count = 0
		for key in _tests:
			if(_tests[key].is_failing()):
				count += 1
		return count

	func get_risky_count():
		var count = 0
		for key in _tests:
			if(!_tests[key].did_something()):
				count += 1
		return count


	func get_test_obj(obj_name):
		if(!_tests.has(obj_name)):
			_tests[obj_name] = Test.new()
			_test_order.append(obj_name)
		return _tests[obj_name]

	func add_pass(test_name, reason):
		var t = get_test_obj(test_name)
		t.pass_texts.append(reason)

	func add_fail(test_name, reason):
		var t = get_test_obj(test_name)
		t.fail_texts.append(reason)

	func add_pending(test_name, reason):
		var t = get_test_obj(test_name)
		t.pending_texts.append(reason)

	func get_tests():
		return _tests

# ------------------------------------------------------------------------------
# Summary Class
#
# This class holds the results of all the test scripts and Inner Classes that
# were run.
# ------------------------------------------------------------------------------
var _scripts = []

func add_script(name):
	_scripts.append(TestScript.new(name))

func get_scripts():
	return _scripts

func get_current_script():
	return _scripts[_scripts.size() - 1]

func add_test(test_name):
	return get_current_script().get_test_obj(test_name)

func add_pass(test_name, reason = ''):
	get_current_script().add_pass(test_name, reason)

func add_fail(test_name, reason = ''):
	get_current_script().add_fail(test_name, reason)

func add_pending(test_name, reason = ''):
	get_current_script().add_pending(test_name, reason)

func get_test_text(test_name):
	return test_name + "\n" + get_current_script().get_test_obj(test_name).to_s()

# Gets the count of unique script names minus the .<Inner Class Name> at the
# end.  Used for displaying the number of scripts without including all the
# Inner Classes.
func get_non_inner_class_script_count():
	var unique_scripts = {}
	for i in range(_scripts.size()):
		var ext_loc = _scripts[i].name.find_last('.gd.')
		if(ext_loc == -1):
			unique_scripts[_scripts[i].name] = 1
		else:
			unique_scripts[_scripts[i].name.substr(0, ext_loc + 3)] = 1
	return unique_scripts.keys().size()

func get_totals():
	var totals = {
		passing = 0,
		pending = 0,
		failing = 0,
		risky = 0,
		tests = 0,
		scripts = 0,
		passing_tests = 0,
		failing_tests = 0
	}

	for i in range(_scripts.size()):
		# assert totals
		totals.passing += _scripts[i].get_pass_count()
		totals.pending += _scripts[i].get_pending_count()
		totals.failing += _scripts[i].get_fail_count()

		# test totals
		totals.tests += _scripts[i]._test_order.size()
		totals.passing_tests += _scripts[i].get_passing_test_count()
		totals.failing_tests += _scripts[i].get_failing_test_count()
		totals.risky += _scripts[i].get_risky_count()

	totals.scripts = get_non_inner_class_script_count()

	return totals

func log_summary_text(lgr):
	var orig_indent = lgr.get_indent_level()
	var found_failing_or_pending = false

	for s in range(_scripts.size()):
		lgr.set_indent_level(0)
		if(_scripts[s].get_fail_count() > 0 or _scripts[s].get_pending_count() > 0):
			lgr.log(_scripts[s].name, lgr.fmts.underline)


		for t in range(_scripts[s]._test_order.size()):
			var tname = _scripts[s]._test_order[t]
			var test = _scripts[s].get_test_obj(tname)
			if(!test.is_passing()):
				found_failing_or_pending = true
				lgr.log(str('- ', tname))
				lgr.inc_indent()

				for i in range(test.fail_texts.size()):
					lgr.failed(test.fail_texts[i])
				for i in range(test.pending_texts.size()):
					lgr.pending(test.pending_texts[i])
				if(!test.did_something()):
					lgr.log('[Did not assert]', lgr.fmts.yellow)
				lgr.dec_indent()

	lgr.set_indent_level(0)
	if(!found_failing_or_pending):
		lgr.log('All tests passed', lgr.fmts.green)

	# just picked a non-printable char, dunno if it is a good or bad choice.
	var npws = PoolByteArray([31]).get_string_from_ascii()

	lgr.log()
	var _totals = get_totals()
	lgr.log("Totals", lgr.fmts.yellow)
	lgr.log(str('Scripts:          ', get_non_inner_class_script_count()))
	lgr.log(str('Passing tests     ', _totals.passing_tests))
	lgr.log(str('Failing tests     ', _totals.failing_tests))
	lgr.log(str('Risky tests       ', _totals.risky))
	var pnd=str('Pending:          ', _totals.pending)
	# add a non printable character so this "pending" isn't highlighted in the
	# editor's output panel.
	lgr.log(str(npws, pnd))
	lgr.log(str('Asserts:          ', _totals.passing, ' of ', _totals.passing + _totals.failing, ' passed'))

	lgr.set_indent_level(orig_indent)

--- Start of ./addons/gut/test_collector.gd ---

# ------------------------------------------------------------------------------
# Used to keep track of info about each test ran.
# ------------------------------------------------------------------------------
class Test:
	# indicator if it passed or not.  defaults to true since it takes only
	# one failure to make it not pass.  _fail in gut will set this.
	var passed = true
	# the name of the function
	var name = ""
	# flag to know if the name has been printed yet.
	var has_printed_name = false
	# the number of arguments the method has
	var arg_count = 0
	# The number of asserts in the test
	var assert_count = 0
	# if the test has been marked pending at anypont during
	# execution.
	var pending = false
	# the line number when the  test fails
	var line_number = -1

	func did_pass():
		return passed and !pending and assert_count > 0

	func did_assert():
		return assert_count > 0 or pending


# ------------------------------------------------------------------------------
# This holds all the meta information for a test script.  It contains the
# name of the inner class and an array of Test "structs".
#
# This class also facilitates all the exporting and importing of tests.
# ------------------------------------------------------------------------------
class TestScript:
	var inner_class_name = null
	var tests = []
	var path = null
	var _utils = null
	var _lgr = null

	func _init(utils=null, logger=null):
		_utils = utils
		_lgr = logger

	func to_s():
		var to_return = path
		if(inner_class_name != null):
			to_return += str('.', inner_class_name)
		to_return += "\n"
		for i in range(tests.size()):
			to_return += str('  ', tests[i].name, "\n")
		return to_return

	func get_new():
		return load_script().new()

	func load_script():
		#print('loading:  ', get_full_name())
		var to_return = load(path)
		if(inner_class_name != null):
			# If we wanted to do inner classes in inner classses
			# then this would have to become some kind of loop or recursive
			# call to go all the way down the chain or this class would
			# have to change to hold onto the loaded class instead of
			# just path information.
			to_return = to_return.get(inner_class_name)
		return to_return

	func get_filename_and_inner():
		var to_return = get_filename()
		if(inner_class_name != null):
			to_return += '.' + inner_class_name
		return to_return

	func get_full_name():
		var to_return = path
		if(inner_class_name != null):
			to_return += '.' + inner_class_name
		return to_return

	func get_filename():
		return path.get_file()

	func has_inner_class():
		return inner_class_name != null

	# Note:  although this no longer needs to export the inner_class names since
	#        they are pulled from metadata now, it is easier to leave that in
	#        so we don't have to cut the export down to unique script names.
	func export_to(config_file, section):
		config_file.set_value(section, 'path', path)
		config_file.set_value(section, 'inner_class', inner_class_name)
		var names = []
		for i in range(tests.size()):
			names.append(tests[i].name)
		config_file.set_value(section, 'tests', names)

	func _remap_path(source_path):
		var to_return = source_path
		if(!_utils.file_exists(source_path)):
			_lgr.debug('Checking for remap for:  ' + source_path)
			var remap_path = source_path.get_basename() + '.gd.remap'
			if(_utils.file_exists(remap_path)):
				var cf = ConfigFile.new()
				cf.load(remap_path)
				to_return = cf.get_value('remap', 'path')
			else:
				_lgr.warn('Could not find remap file ' + remap_path)
		return to_return

	func import_from(config_file, section):
		path = config_file.get_value(section, 'path')
		path = _remap_path(path)
		# Null is an acceptable value, but you can't pass null as a default to
		# get_value since it thinks you didn't send a default...then it spits
		# out red text.  This works around that.
		var inner_name = config_file.get_value(section, 'inner_class', 'Placeholder')
		if(inner_name != 'Placeholder'):
			inner_class_name = inner_name
		else: # just being explicit
			inner_class_name = null

	func get_test_named(name):
		return _utils.search_array(tests, 'name', name)

# ------------------------------------------------------------------------------
# start test_collector, I don't think I like the name.
# ------------------------------------------------------------------------------
var scripts = []
var _test_prefix = 'test_'
var _test_class_prefix = 'Test'

var _utils = load('res://addons/gut/utils.gd').get_instance()
var _lgr = _utils.get_logger()

func _does_inherit_from_test(thing):
	var base_script = thing.get_base_script()
	var to_return = false
	if(base_script != null):
		var base_path = base_script.get_path()
		if(base_path == 'res://addons/gut/test.gd'):
			to_return = true
		else:
			to_return = _does_inherit_from_test(base_script)
	return to_return

func _populate_tests(test_script):
	var methods = test_script.load_script().get_script_method_list()
	for i in range(methods.size()):
		var name = methods[i]['name']
		if(name.begins_with(_test_prefix)):
			var t = Test.new()
			t.name = name
			t.arg_count = methods[i]['args'].size()
			test_script.tests.append(t)

func _get_inner_test_class_names(loaded):
	var inner_classes = []
	var const_map = loaded.get_script_constant_map()
	for key in const_map:
		var thing = const_map[key]
		if(_utils.is_gdscript(thing)):
			if(key.begins_with(_test_class_prefix)):
				if(_does_inherit_from_test(thing)):
					inner_classes.append(key)
				else:
					_lgr.warn(str('Ignoring Inner Class ', key,
						' because it does not extend GutTest'))

			# This could go deeper and find inner classes within inner classes
			# but requires more experimentation.  Right now I'm keeping it at
			# one level since that is what the previous version did and there
			# has been no demand for deeper nesting.
			# _populate_inner_test_classes(thing)
	return inner_classes

func _parse_script(test_script):
	var inner_classes = []
	var scripts_found = []

	var loaded = load(test_script.path)
	if(_does_inherit_from_test(loaded)):
		_populate_tests(test_script)
		scripts_found.append(test_script.path)
		inner_classes = _get_inner_test_class_names(loaded)
	else:
		return []

	for i in range(inner_classes.size()):
		var loaded_inner = loaded.get(inner_classes[i])
		if(_does_inherit_from_test(loaded_inner)):
			var ts = TestScript.new(_utils, _lgr)
			ts.path = test_script.path
			ts.inner_class_name = inner_classes[i]
			_populate_tests(ts)
			scripts.append(ts)
			scripts_found.append(test_script.path + '[' + inner_classes[i] +']')

	return scripts_found

# -----------------
# Public
# -----------------
func add_script(path):
	# SHORTCIRCUIT
	if(has_script(path)):
		return []

	var f = File.new()
	# SHORTCIRCUIT
	if(!f.file_exists(path)):
		_lgr.error('Could not find script:  ' + path)
		return

	var ts = TestScript.new(_utils, _lgr)
	ts.path = path
	# Append right away because if we don't test_doubler.gd.TestInitParameters
	# will HARD crash.  I couldn't figure out what was causing the issue but
	# appending right away, and then removing if it's not valid seems to fix
	# things.  It might have to do with the ordering of the test classes in
	# the test collecter.  I'm not really sure.
	scripts.append(ts)
	var parse_results = _parse_script(ts)

	if(parse_results.find(path) == -1):
		_lgr.warn(str('Ignoring script ', path, ' because it does not extend GutTest'))
		scripts.remove(scripts.find(ts))

	return parse_results


func clear():
	scripts.clear()

func has_script(path):
	var found = false
	var idx = 0
	while(idx < scripts.size() and !found):
		if(scripts[idx].get_full_name() == path):
			found = true
		else:
			idx += 1
	return found

func export_tests(path):
	var success = true
	var f = ConfigFile.new()
	for i in range(scripts.size()):
		scripts[i].export_to(f, str('TestScript-', i))
	var result = f.save(path)
	if(result != OK):
		_lgr.error(str('Could not save exported tests to [', path, '].  Error code:  ', result))
		success = false
	return success

func import_tests(path):
	var success = false
	var f = ConfigFile.new()
	var result = f.load(path)
	if(result != OK):
		_lgr.error(str('Could not load exported tests from [', path, '].  Error code:  ', result))
	else:
		var sections = f.get_sections()
		for key in sections:
			var ts = TestScript.new(_utils, _lgr)
			ts.import_from(f, key)
			_populate_tests(ts)
			scripts.append(ts)
		success = true
	return success

func get_script_named(name):
	return _utils.search_array(scripts, 'get_filename_and_inner', name)

func get_test_named(script_name, test_name):
	var s = get_script_named(script_name)
	if(s != null):
		return s.get_test_named(test_name)
	else:
		return null

func to_s():
	var to_return = ''
	for i in range(scripts.size()):
		to_return += scripts[i].to_s() + "\n"
	return to_return

# ---------------------
# Accessors
# ---------------------
func get_logger():
	return _lgr

func set_logger(logger):
	_lgr = logger

func get_test_prefix():
	return _test_prefix

func set_test_prefix(test_prefix):
	_test_prefix = test_prefix

func get_test_class_prefix():
	return _test_class_prefix

func set_test_class_prefix(test_class_prefix):
	_test_class_prefix = test_class_prefix

--- Start of ./addons/gut/test.gd ---

class_name GutTest
# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# View readme for usage details.
#
# Version - see gut.gd
# ##############################################################################
# Class that all test scripts must extend.
#
# This provides all the asserts and other testing features.  Test scripts are
# run by the Gut class in gut.gd
# ##############################################################################
extends Node


# ------------------------------------------------------------------------------
# Helper class to hold info for objects to double.  This extracts info and has
# some convenience methods.  This is key in being able to make the "smart double"
# method which makes doubling much easier for the user.
# -----------------------------------------------------------------------------
class DoubleInfo:
	var path
	var subpath
	var strategy
	var make_partial
	var extension
	var _utils = load("res://addons/gut/utils.gd").get_instance()
	var _is_native = false
	var is_valid = false

	# Flexible init method.  p2 can be subpath or stategy unless p3 is
	# specified, then p2 must be subpath and p3 is strategy.
	#
	# Examples:
	#   (object_to_double)
	#   (object_to_double, subpath)
	#   (object_to_double, strategy)
	#   (object_to_double, subpath, strategy)
	func _init(thing, p2 = null, p3 = null):
		strategy = p2

		# short-circuit and ensure that is_valid
		# is not set to true.
		if _utils.is_instance(thing):
			return

		if typeof(p2) == TYPE_STRING:
			strategy = p3
			subpath = p2

		if typeof(thing) == TYPE_OBJECT:
			if _utils.is_native_class(thing):
				path = thing
				_is_native = true
				extension = "native_class_not_used"
			else:
				path = thing.resource_path
		else:
			path = thing

		if !_is_native:
			extension = path.get_extension()

		is_valid = true

	func is_scene():
		return extension == "tscn"

	func is_script():
		return extension == "gd"

	func is_native():
		return _is_native


# ------------------------------------------------------------------------------
# Begin test.gd
# ------------------------------------------------------------------------------
var _utils = load("res://addons/gut/utils.gd").get_instance()
var _compare = _utils.Comparator.new()

# constant for signal when calling yield_for
const YIELD = "timeout"

# Need a reference to the instance that is running the tests.  This
# is set by the gut class when it runs the tests.  This gets you
# access to the asserts in the tests you write.
var gut = null

var _disable_strict_datatype_checks = false
# Holds all the text for a test's fail/pass.  This is used for testing purposes
# to see the text of a failed sub-test in test_test.gd
var _fail_pass_text = []

const EDITOR_PROPERTY = PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_DEFAULT
const VARIABLE_PROPERTY = PROPERTY_USAGE_SCRIPT_VARIABLE

# Used with assert_setget
enum { DEFAULT_SETTER_GETTER, SETTER_ONLY, GETTER_ONLY }

# Summary counts for the test.
var _summary = {asserts = 0, passed = 0, failed = 0, tests = 0, pending = 0}

# This is used to watch signals so we can make assertions about them.
var _signal_watcher = load("res://addons/gut/signal_watcher.gd").new()

# Convenience copy of _utils.DOUBLE_STRATEGY
var DOUBLE_STRATEGY = null
var _lgr = _utils.get_logger()
var _strutils = _utils.Strutils.new()

# syntax sugar
var ParameterFactory = _utils.ParameterFactory
var CompareResult = _utils.CompareResult
var InputFactory = _utils.InputFactory
var InputSender = _utils.InputSender


func _init():
	DOUBLE_STRATEGY = _utils.DOUBLE_STRATEGY  # yes, this is right


func _str(thing):
	return _strutils.type2str(thing)


# ------------------------------------------------------------------------------
# Fail an assertion.  Causes test and script to fail as well.
# ------------------------------------------------------------------------------
func _fail(text):
	_summary.asserts += 1
	_summary.failed += 1
	_fail_pass_text.append("failed:  " + text)
	if gut:
		_lgr.failed(text)
		gut._fail(text)


# ------------------------------------------------------------------------------
# Pass an assertion.
# ------------------------------------------------------------------------------
func _pass(text):
	_summary.asserts += 1
	_summary.passed += 1
	_fail_pass_text.append("passed:  " + text)
	if gut:
		_lgr.passed(text)
		gut._pass(text)


# ------------------------------------------------------------------------------
# Checks if the datatypes passed in match.  If they do not then this will cause
# a fail to occur.  If they match then TRUE is returned, FALSE if not.  This is
# used in all the assertions that compare values.
# ------------------------------------------------------------------------------
func _do_datatypes_match__fail_if_not(got, expected, text):
	var did_pass = true

	if !_disable_strict_datatype_checks:
		var got_type = typeof(got)
		var expect_type = typeof(expected)
		if got_type != expect_type and got != null and expected != null:
			# If we have a mismatch between float and int (types 2 and 3) then
			# print out a warning but do not fail.
			if [2, 3].has(got_type) and [2, 3].has(expect_type):
				_lgr.warn(
					str(
						"Warn:  Float/Int comparison.  Got ",
						_strutils.types[got_type],
						" but expected ",
						_strutils.types[expect_type]
					)
				)
			else:
				_fail(
					(
						"Cannot compare "
						+ _strutils.types[got_type]
						+ "["
						+ _str(got)
						+ "] to "
						+ _strutils.types[expect_type]
						+ "["
						+ _str(expected)
						+ "].  "
						+ text
					)
				)
				did_pass = false

	return did_pass


# ------------------------------------------------------------------------------
# Create a string that lists all the methods that were called on an spied
# instance.
# ------------------------------------------------------------------------------
func _get_desc_of_calls_to_instance(inst):
	var BULLET = "  * "
	var calls = gut.get_spy().get_call_list_as_string(inst)
	# indent all the calls
	calls = BULLET + calls.replace("\n", "\n" + BULLET)
	# remove trailing newline and bullet
	calls = calls.substr(0, calls.length() - BULLET.length() - 1)
	return "Calls made on " + str(inst) + "\n" + calls


# ------------------------------------------------------------------------------
# Signal assertion helper.  Do not call directly, use _can_make_signal_assertions
# ------------------------------------------------------------------------------
func _fail_if_does_not_have_signal(object, signal_name):
	var did_fail = false
	if !_signal_watcher.does_object_have_signal(object, signal_name):
		_fail(str("Object ", object, " does not have the signal [", signal_name, "]"))
		did_fail = true
	return did_fail


# ------------------------------------------------------------------------------
# Signal assertion helper.  Do not call directly, use _can_make_signal_assertions
# ------------------------------------------------------------------------------
func _fail_if_not_watching(object):
	var did_fail = false
	if !_signal_watcher.is_watching_object(object):
		_fail(
			str(
				"Cannot make signal assertions because the object ",
				object,
				" is not being watched.  Call watch_signals(some_object) to be able to make assertions about signals."
			)
		)
		did_fail = true
	return did_fail


# ------------------------------------------------------------------------------
# Returns text that contains original text and a list of all the signals that
# were emitted for the passed in object.
# ------------------------------------------------------------------------------
func _get_fail_msg_including_emitted_signals(text, object):
	return str(text, " (Signals emitted: ", _signal_watcher.get_signals_emitted(object), ")")


# ------------------------------------------------------------------------------
# This validates that parameters is an array and generates a specific error
# and a failure with a specific message
# ------------------------------------------------------------------------------
func _fail_if_parameters_not_array(parameters):
	var invalid = parameters != null and typeof(parameters) != TYPE_ARRAY
	if invalid:
		_lgr.error('The "parameters" parameter must be an array of expected parameter values.')
		_fail("Cannot compare paramter values because an array was not passed.")
	return invalid


func _create_obj_from_type(type):
	var obj = null
	if type.is_class("PackedScene"):
		obj = type.instance()
		add_child(obj)
	else:
		obj = type.new()
	return obj


# #######################
# Virtual Methods
# #######################


# alias for prerun_setup
func before_all():
	pass


# alias for setup
func before_each():
	pass


# alias for postrun_teardown
func after_all():
	pass


# alias for teardown
func after_each():
	pass


# #######################
# Public
# #######################


func get_logger():
	return _lgr


func set_logger(logger):
	_lgr = logger


# #######################
# Asserts
# #######################


# ------------------------------------------------------------------------------
# Asserts that the expected value equals the value got.
# ------------------------------------------------------------------------------
func assert_eq(got, expected, text = ""):
	if _do_datatypes_match__fail_if_not(got, expected, text):
		var disp = "[" + _str(got) + "] expected to equal [" + _str(expected) + "]:  " + text
		var result = null

		if typeof(got) == TYPE_ARRAY:
			result = _compare.shallow(got, expected)
		else:
			result = _compare.simple(got, expected)

		if typeof(got) in [TYPE_ARRAY, TYPE_DICTIONARY]:
			disp = str(result.summary, "  ", text)

		if result.are_equal:
			_pass(disp)
		else:
			_fail(disp)


# ------------------------------------------------------------------------------
# Asserts that the value got does not equal the "not expected" value.
# ------------------------------------------------------------------------------
func assert_ne(got, not_expected, text = ""):
	if _do_datatypes_match__fail_if_not(got, not_expected, text):
		var disp = (
			"["
			+ _str(got)
			+ "] expected to not equal ["
			+ _str(not_expected)
			+ "]:  "
			+ text
		)
		var result = null

		if typeof(got) == TYPE_ARRAY:
			result = _compare.shallow(got, not_expected)
		else:
			result = _compare.simple(got, not_expected)

		if typeof(got) in [TYPE_ARRAY, TYPE_DICTIONARY]:
			disp = str(result.summary, "  ", text)

		if result.are_equal:
			_fail(disp)
		else:
			_pass(disp)


# ------------------------------------------------------------------------------
# Asserts that the expected value almost equals the value got.
# ------------------------------------------------------------------------------
func assert_almost_eq(got, expected, error_interval, text = ""):
	var disp = (
		"["
		+ _str(got)
		+ "] expected to equal ["
		+ _str(expected)
		+ "] +/- ["
		+ str(error_interval)
		+ "]:  "
		+ text
	)
	if (
		_do_datatypes_match__fail_if_not(got, expected, text)
		and _do_datatypes_match__fail_if_not(got, error_interval, text)
	):
		if not _is_almost_eq(got, expected, error_interval):
			_fail(disp)
		else:
			_pass(disp)


# ------------------------------------------------------------------------------
# Asserts that the expected value does not almost equal the value got.
# ------------------------------------------------------------------------------
func assert_almost_ne(got, not_expected, error_interval, text = ""):
	var disp = (
		"["
		+ _str(got)
		+ "] expected to not equal ["
		+ _str(not_expected)
		+ "] +/- ["
		+ str(error_interval)
		+ "]:  "
		+ text
	)
	if (
		_do_datatypes_match__fail_if_not(got, not_expected, text)
		and _do_datatypes_match__fail_if_not(got, error_interval, text)
	):
		if _is_almost_eq(got, not_expected, error_interval):
			_fail(disp)
		else:
			_pass(disp)


# ------------------------------------------------------------------------------
# Helper function which correctly compares two variables,
# while properly handling vector2/3 types
# ------------------------------------------------------------------------------
func _is_almost_eq(got, expected, error_interval) -> bool:
	var result = false
	if typeof(got) == TYPE_VECTOR2:
		if got.x >= (expected.x - error_interval.x) and got.x <= (expected.x + error_interval.x):
			if (
				got.y >= (expected.y - error_interval.y)
				and got.y <= (expected.y + error_interval.y)
			):
				result = true
	elif typeof(got) == TYPE_VECTOR3:
		if got.x >= (expected.x - error_interval.x) and got.x <= (expected.x + error_interval.x):
			if (
				got.y >= (expected.y - error_interval.y)
				and got.y <= (expected.y + error_interval.y)
			):
				if (
					got.z >= (expected.z - error_interval.z)
					and got.z <= (expected.z + error_interval.z)
				):
					result = true
	elif got >= (expected - error_interval) and got <= (expected + error_interval):
		result = true
	return result


# ------------------------------------------------------------------------------
# Asserts got is greater than expected
# ------------------------------------------------------------------------------
func assert_gt(got, expected, text = ""):
	var disp = "[" + _str(got) + "] expected to be > than [" + _str(expected) + "]:  " + text
	if _do_datatypes_match__fail_if_not(got, expected, text):
		if got > expected:
			_pass(disp)
		else:
			_fail(disp)


# ------------------------------------------------------------------------------
# Asserts got is less than expected
# ------------------------------------------------------------------------------
func assert_lt(got, expected, text = ""):
	var disp = "[" + _str(got) + "] expected to be < than [" + _str(expected) + "]:  " + text
	if _do_datatypes_match__fail_if_not(got, expected, text):
		if got < expected:
			_pass(disp)
		else:
			_fail(disp)


# ------------------------------------------------------------------------------
# asserts that got is true
# ------------------------------------------------------------------------------
func assert_true(got, text = ""):
	if typeof(got) == TYPE_BOOL:
		if got:
			_pass(text)
		else:
			_fail(text)
	else:
		var msg = str("Cannot convert ", _strutils.type2str(got), " to boolean")
		_fail(msg)


# ------------------------------------------------------------------------------
# Asserts that got is false
# ------------------------------------------------------------------------------
func assert_false(got, text = ""):
	if typeof(got) == TYPE_BOOL:
		if got:
			_fail(text)
		else:
			_pass(text)
	else:
		var msg = str("Cannot convert ", _strutils.type2str(got), " to boolean")
		_fail(msg)


# ------------------------------------------------------------------------------
# Asserts value is between (inclusive) the two expected values.
# ------------------------------------------------------------------------------
func assert_between(got, expect_low, expect_high, text = ""):
	var disp = (
		"["
		+ _str(got)
		+ "] expected to be between ["
		+ _str(expect_low)
		+ "] and ["
		+ str(expect_high)
		+ "]:  "
		+ text
	)

	if (
		_do_datatypes_match__fail_if_not(got, expect_low, text)
		and _do_datatypes_match__fail_if_not(got, expect_high, text)
	):
		if expect_low > expect_high:
			disp = (
				"INVALID range.  ["
				+ str(expect_low)
				+ "] is not less than ["
				+ str(expect_high)
				+ "]"
			)
			_fail(disp)
		else:
			if got < expect_low or got > expect_high:
				_fail(disp)
			else:
				_pass(disp)


# ------------------------------------------------------------------------------
# Asserts value is not between (exclusive) the two expected values.
# ------------------------------------------------------------------------------
func assert_not_between(got, expect_low, expect_high, text = ""):
	var disp = (
		"["
		+ _str(got)
		+ "] expected not to be between ["
		+ _str(expect_low)
		+ "] and ["
		+ str(expect_high)
		+ "]:  "
		+ text
	)

	if (
		_do_datatypes_match__fail_if_not(got, expect_low, text)
		and _do_datatypes_match__fail_if_not(got, expect_high, text)
	):
		if expect_low > expect_high:
			disp = (
				"INVALID range.  ["
				+ str(expect_low)
				+ "] is not less than ["
				+ str(expect_high)
				+ "]"
			)
			_fail(disp)
		else:
			if got > expect_low and got < expect_high:
				_fail(disp)
			else:
				_pass(disp)


# ------------------------------------------------------------------------------
# Uses the 'has' method of the object passed in to determine if it contains
# the passed in element.
# ------------------------------------------------------------------------------
func assert_has(obj, element, text = ""):
	var disp = str("Expected [", _str(obj), "] to contain value:  [", _str(element), "]:  ", text)
	if obj.has(element):
		_pass(disp)
	else:
		_fail(disp)


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func assert_does_not_have(obj, element, text = ""):
	var disp = str(
		"Expected [", _str(obj), "] to NOT contain value:  [", _str(element), "]:  ", text
	)
	if obj.has(element):
		_fail(disp)
	else:
		_pass(disp)


# ------------------------------------------------------------------------------
# Asserts that a file exists
# ------------------------------------------------------------------------------
func assert_file_exists(file_path):
	var disp = "expected [" + file_path + "] to exist."
	var f = File.new()
	if f.file_exists(file_path):
		_pass(disp)
	else:
		_fail(disp)


# ------------------------------------------------------------------------------
# Asserts that a file should not exist
# ------------------------------------------------------------------------------
func assert_file_does_not_exist(file_path):
	var disp = "expected [" + file_path + "] to NOT exist"
	var f = File.new()
	if !f.file_exists(file_path):
		_pass(disp)
	else:
		_fail(disp)


# ------------------------------------------------------------------------------
# Asserts the specified file is empty
# ------------------------------------------------------------------------------
func assert_file_empty(file_path):
	var disp = "expected [" + file_path + "] to be empty"
	var f = File.new()
	if f.file_exists(file_path) and gut.is_file_empty(file_path):
		_pass(disp)
	else:
		_fail(disp)


# ------------------------------------------------------------------------------
# Asserts the specified file is not empty
# ------------------------------------------------------------------------------
func assert_file_not_empty(file_path):
	var disp = "expected [" + file_path + "] to contain data"
	if !gut.is_file_empty(file_path):
		_pass(disp)
	else:
		_fail(disp)


# ------------------------------------------------------------------------------
# Asserts the object has the specified method
# ------------------------------------------------------------------------------
func assert_has_method(obj, method, text = ""):
	var disp = _str(obj) + " should have method: " + method
	if text != "":
		disp = _str(obj) + " " + text
	assert_true(obj.has_method(method), disp)


# Old deprecated method name
func assert_get_set_methods(obj, property, default, set_to):
	_lgr.deprecated("assert_get_set_methods", "assert_accessors")
	assert_accessors(obj, property, default, set_to)


# ------------------------------------------------------------------------------
# Verifies the object has get and set methods for the property passed in.  The
# property isn't tied to anything, just a name to be appended to the end of
# get_ and set_.  Asserts the get_ and set_ methods exist, if not, it stops there.
# If they exist then it asserts get_ returns the expected default then calls
# set_ and asserts get_ has the value it was set to.
# ------------------------------------------------------------------------------
func assert_accessors(obj, property, default, set_to):
	var fail_count = _summary.failed
	var get_func = "get_" + property
	var set_func = "set_" + property

	if obj.has_method("is_" + property):
		get_func = "is_" + property

	assert_has_method(obj, get_func, "should have getter starting with get_ or is_")
	assert_has_method(obj, set_func)
	# SHORT CIRCUIT
	if _summary.failed > fail_count:
		return
	assert_eq(obj.call(get_func), default, "It should have the expected default value.")
	obj.call(set_func, set_to)
	assert_eq(obj.call(get_func), set_to, "The set value should have been returned.")


# ---------------------------------------------------------------------------
# Property search helper.  Used to retrieve Dictionary of specified property
# from passed object. Returns null if not found.
# If provided, property_usage constrains the type of property returned by
# passing either:
# EDITOR_PROPERTY for properties defined as: export(int) var some_value
# VARIABLE_PROPERTY for properties defined as: var another_value
# ---------------------------------------------------------------------------
func _find_object_property(obj, property_name, property_usage = null):
	var result = null
	var found = false
	var properties = obj.get_property_list()

	while !found and !properties.empty():
		var property = properties.pop_back()
		if property["name"] == property_name:
			if property_usage == null or property["usage"] == property_usage:
				result = property
				found = true
	return result


# ------------------------------------------------------------------------------
# Asserts a class exports a variable.
# ------------------------------------------------------------------------------
func assert_exports(obj, property_name, type):
	var disp = "expected %s to have editor property [%s]" % [_str(obj), property_name]
	var property = _find_object_property(obj, property_name, EDITOR_PROPERTY)
	if property != null:
		disp += (
			" of type [%s]. Got type [%s]."
			% [_strutils.types[type], _strutils.types[property["type"]]]
		)
		if property["type"] == type:
			_pass(disp)
		else:
			_fail(disp)
	else:
		_fail(disp)


# ------------------------------------------------------------------------------
# Signal assertion helper.
#
# Verifies that the object and signal are valid for making signal assertions.
# This will fail with specific messages that indicate why they are not valid.
# This returns true/false to indicate if the object and signal are valid.
# ------------------------------------------------------------------------------
func _can_make_signal_assertions(object, signal_name):
	return !(_fail_if_not_watching(object) or _fail_if_does_not_have_signal(object, signal_name))


# ------------------------------------------------------------------------------
# Check if an object is connected to a signal on another object. Returns True
# if it is and false otherwise
# ------------------------------------------------------------------------------
func _is_connected(signaler_obj, connect_to_obj, signal_name, method_name = ""):
	if method_name != "":
		return signaler_obj.is_connected(signal_name, connect_to_obj, method_name)
	else:
		var connections = signaler_obj.get_signal_connection_list(signal_name)
		for conn in connections:
			if (conn.source == signaler_obj) and (conn.target == connect_to_obj):
				return true
		return false


# ------------------------------------------------------------------------------
# Watch the signals for an object.  This must be called before you can make
# any assertions about the signals themselves.
# ------------------------------------------------------------------------------
func watch_signals(object):
	_signal_watcher.watch_signals(object)


# ------------------------------------------------------------------------------
# Asserts that an object is connected to a signal on another object
#
# This will fail with specific messages if the target object is not connected
# to the specified signal on the source object.
# ------------------------------------------------------------------------------
func assert_connected(signaler_obj, connect_to_obj, signal_name, method_name = ""):
	pass
	var method_disp = ""
	if method_name != "":
		method_disp = str(" using method: [", method_name, "] ")
	var disp = str(
		"Expected object ",
		_str(signaler_obj),
		" to be connected to signal: [",
		signal_name,
		"] on ",
		_str(connect_to_obj),
		method_disp
	)
	if _is_connected(signaler_obj, connect_to_obj, signal_name, method_name):
		_pass(disp)
	else:
		_fail(disp)


# ------------------------------------------------------------------------------
# Asserts that an object is not connected to a signal on another object
#
# This will fail with specific messages if the target object is connected
# to the specified signal on the source object.
# ------------------------------------------------------------------------------
func assert_not_connected(signaler_obj, connect_to_obj, signal_name, method_name = ""):
	var method_disp = ""
	if method_name != "":
		method_disp = str(" using method: [", method_name, "] ")
	var disp = str(
		"Expected object ",
		_str(signaler_obj),
		" to not be connected to signal: [",
		signal_name,
		"] on ",
		_str(connect_to_obj),
		method_disp
	)
	if _is_connected(signaler_obj, connect_to_obj, signal_name, method_name):
		_fail(disp)
	else:
		_pass(disp)


# ------------------------------------------------------------------------------
# Asserts that a signal has been emitted at least once.
#
# This will fail with specific messages if the object is not being watched or
# the object does not have the specified signal
# ------------------------------------------------------------------------------
func assert_signal_emitted(object, signal_name, text = ""):
	var disp = str(
		"Expected object ", _str(object), " to have emitted signal [", signal_name, "]:  ", text
	)
	if _can_make_signal_assertions(object, signal_name):
		if _signal_watcher.did_emit(object, signal_name):
			_pass(disp)
		else:
			_fail(_get_fail_msg_including_emitted_signals(disp, object))


# ------------------------------------------------------------------------------
# Asserts that a signal has not been emitted.
#
# This will fail with specific messages if the object is not being watched or
# the object does not have the specified signal
# ------------------------------------------------------------------------------
func assert_signal_not_emitted(object, signal_name, text = ""):
	var disp = str(
		"Expected object ", _str(object), " to NOT emit signal [", signal_name, "]:  ", text
	)
	if _can_make_signal_assertions(object, signal_name):
		if _signal_watcher.did_emit(object, signal_name):
			_fail(disp)
		else:
			_pass(disp)


# ------------------------------------------------------------------------------
# Asserts that a signal was fired with the specified parameters.  The expected
# parameters should be passed in as an array.  An optional index can be passed
# when a signal has fired more than once.  The default is to retrieve the most
# recent emission of the signal.
#
# This will fail with specific messages if the object is not being watched or
# the object does not have the specified signal
# ------------------------------------------------------------------------------
func assert_signal_emitted_with_parameters(object, signal_name, parameters, index = -1):
	if typeof(parameters) != TYPE_ARRAY:
		_lgr.error(
			"The expected parameters must be wrapped in an array, you passed:  " + _str(parameters)
		)
		_fail("Bad Parameters")
		return

	var disp = str(
		"Expected object ",
		_str(object),
		" to emit signal [",
		signal_name,
		"] with parameters ",
		parameters,
		", got "
	)
	if _can_make_signal_assertions(object, signal_name):
		if _signal_watcher.did_emit(object, signal_name):
			var parms_got = _signal_watcher.get_signal_parameters(object, signal_name, index)
			var diff_result = _compare.deep(parameters, parms_got)
			if diff_result.are_equal():
				_pass(str(disp, parms_got))
			else:
				_fail(
					str(
						"Expected object ",
						_str(object),
						" to emit signal [",
						signal_name,
						"] with parameters ",
						diff_result.summarize()
					)
				)
		else:
			var text = str("Object ", object, " did not emit signal [", signal_name, "]")
			_fail(_get_fail_msg_including_emitted_signals(text, object))


# ------------------------------------------------------------------------------
# Assert that a signal has been emitted a specific number of times.
#
# This will fail with specific messages if the object is not being watched or
# the object does not have the specified signal
# ------------------------------------------------------------------------------
func assert_signal_emit_count(object, signal_name, times, text = ""):
	if _can_make_signal_assertions(object, signal_name):
		var count = _signal_watcher.get_emit_count(object, signal_name)
		var disp = str(
			"Expected the signal [",
			signal_name,
			"] emit count of [",
			count,
			"] to equal [",
			times,
			"]: ",
			text
		)
		if count == times:
			_pass(disp)
		else:
			_fail(_get_fail_msg_including_emitted_signals(disp, object))


# ------------------------------------------------------------------------------
# Assert that the passed in object has the specified signal
# ------------------------------------------------------------------------------
func assert_has_signal(object, signal_name, text = ""):
	var disp = str("Expected object ", _str(object), " to have signal [", signal_name, "]:  ", text)
	if _signal_watcher.does_object_have_signal(object, signal_name):
		_pass(disp)
	else:
		_fail(disp)


# ------------------------------------------------------------------------------
# Returns the number of times a signal was emitted.  -1 returned if the object
# is not being watched.
# ------------------------------------------------------------------------------
func get_signal_emit_count(object, signal_name):
	return _signal_watcher.get_emit_count(object, signal_name)


# ------------------------------------------------------------------------------
# Get the parmaters of a fired signal.  If the signal was not fired null is
# returned.  You can specify an optional index (use get_signal_emit_count to
# determine the number of times it was emitted).  The default index is the
# latest time the signal was fired (size() -1 insetead of 0).  The parameters
# returned are in an array.
# ------------------------------------------------------------------------------
func get_signal_parameters(object, signal_name, index = -1):
	return _signal_watcher.get_signal_parameters(object, signal_name, index)


# ------------------------------------------------------------------------------
# Get the parameters for a method call to a doubled object.  By default it will
# return the most recent call.  You can optionally specify an index.
#
# Returns:
# * an array of parameter values if a call the method was found
# * null when a call to the method was not found or the index specified was
#   invalid.
# ------------------------------------------------------------------------------
func get_call_parameters(object, method_name, index = -1):
	var to_return = null
	if _utils.is_double(object):
		to_return = gut.get_spy().get_call_parameters(object, method_name, index)
	else:
		_lgr.error("You must pass a doulbed object to get_call_parameters.")

	return to_return


# ------------------------------------------------------------------------------
# Returns the call count for a method with optional paramter matching.
# ------------------------------------------------------------------------------
func get_call_count(object, method_name, parameters = null):
	return gut.get_spy().call_count(object, method_name, parameters)


# ------------------------------------------------------------------------------
# Deprecated. Use assert_is.
# ------------------------------------------------------------------------------
func assert_extends(object, a_class, text = ""):
	_lgr.deprecated("assert_extends", "assert_is")
	assert_is(object, a_class, text)


# ------------------------------------------------------------------------------
# Assert that object is an instance of a_class
# ------------------------------------------------------------------------------
func assert_is(object, a_class, text = ""):
	var disp = ""  #var disp = str('Expected [', _str(object), '] to be type of [', a_class, ']: ', text)
	var NATIVE_CLASS = "GDScriptNativeClass"
	var GDSCRIPT_CLASS = "GDScript"
	var bad_param_2 = "Parameter 2 must be a Class (like Node2D or Label).  You passed "

	if typeof(object) != TYPE_OBJECT:
		_fail(str("Parameter 1 must be an instance of an object.  You passed:  ", _str(object)))
	elif typeof(a_class) != TYPE_OBJECT:
		_fail(str(bad_param_2, _str(a_class)))
	else:
		var a_str = _str(a_class)
		disp = str("Expected [", _str(object), "] to extend [", a_str, "]: ", text)
		if a_class.get_class() != NATIVE_CLASS and a_class.get_class() != GDSCRIPT_CLASS:
			_fail(str(bad_param_2, a_str))
		else:
			if object is a_class:
				_pass(disp)
			else:
				_fail(disp)


func _get_typeof_string(the_type):
	var to_return = ""
	if _strutils.types.has(the_type):
		to_return += str(the_type, "(", _strutils.types[the_type], ")")
	else:
		to_return += str(the_type)
	return to_return


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func assert_typeof(object, type, text = ""):
	var disp = str("Expected [typeof(", object, ") = ")
	disp += _get_typeof_string(typeof(object))
	disp += "] to equal ["
	disp += _get_typeof_string(type) + "]"
	disp += ".  " + text
	if typeof(object) == type:
		_pass(disp)
	else:
		_fail(disp)


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func assert_not_typeof(object, type, text = ""):
	var disp = str("Expected [typeof(", object, ") = ")
	disp += _get_typeof_string(typeof(object))
	disp += "] to not equal ["
	disp += _get_typeof_string(type) + "]"
	disp += ".  " + text
	if typeof(object) != type:
		_pass(disp)
	else:
		_fail(disp)


# ------------------------------------------------------------------------------
# Assert that text contains given search string.
# The match_case flag determines case sensitivity.
# ------------------------------------------------------------------------------
func assert_string_contains(text, search, match_case = true):
	var empty_search = "Expected text and search strings to be non-empty. You passed '%s' and '%s'."
	var disp = "Expected '%s' to contain '%s', match_case=%s" % [text, search, match_case]
	if text == "" or search == "":
		_fail(empty_search % [text, search])
	elif match_case:
		if text.find(search) == -1:
			_fail(disp)
		else:
			_pass(disp)
	else:
		if text.to_lower().find(search.to_lower()) == -1:
			_fail(disp)
		else:
			_pass(disp)


# ------------------------------------------------------------------------------
# Assert that text starts with given search string.
# match_case flag determines case sensitivity.
# ------------------------------------------------------------------------------
func assert_string_starts_with(text, search, match_case = true):
	var empty_search = "Expected text and search strings to be non-empty. You passed '%s' and '%s'."
	var disp = "Expected '%s' to start with '%s', match_case=%s" % [text, search, match_case]
	if text == "" or search == "":
		_fail(empty_search % [text, search])
	elif match_case:
		if text.find(search) == 0:
			_pass(disp)
		else:
			_fail(disp)
	else:
		if text.to_lower().find(search.to_lower()) == 0:
			_pass(disp)
		else:
			_fail(disp)


# ------------------------------------------------------------------------------
# Assert that text ends with given search string.
# match_case flag determines case sensitivity.
# ------------------------------------------------------------------------------
func assert_string_ends_with(text, search, match_case = true):
	var empty_search = "Expected text and search strings to be non-empty. You passed '%s' and '%s'."
	var disp = "Expected '%s' to end with '%s', match_case=%s" % [text, search, match_case]
	var required_index = len(text) - len(search)
	if text == "" or search == "":
		_fail(empty_search % [text, search])
	elif match_case:
		if text.find(search) == required_index:
			_pass(disp)
		else:
			_fail(disp)
	else:
		if text.to_lower().find(search.to_lower()) == required_index:
			_pass(disp)
		else:
			_fail(disp)


# ------------------------------------------------------------------------------
# Assert that a method was called on an instance of a doubled class.  If
# parameters are supplied then the params passed in when called must match.
# TODO make 3rd parameter "param_or_text" and add fourth parameter of "text" and
#      then work some magic so this can have a "text" parameter without being
#      annoying.
# ------------------------------------------------------------------------------
func assert_called(inst, method_name, parameters = null):
	var disp = str("Expected [", method_name, "] to have been called on ", _str(inst))

	if _fail_if_parameters_not_array(parameters):
		return

	if !_utils.is_double(inst):
		_fail(
			"You must pass a doubled instance to assert_called.  Check the wiki for info on using double."
		)
	else:
		if gut.get_spy().was_called(inst, method_name, parameters):
			_pass(disp)
		else:
			if parameters != null:
				disp += str(" with parameters ", parameters)
			_fail(str(disp, "\n", _get_desc_of_calls_to_instance(inst)))


# ------------------------------------------------------------------------------
# Assert that a method was not called on an instance of a doubled class.  If
# parameters are specified then this will only fail if it finds a call that was
# sent matching parameters.
# ------------------------------------------------------------------------------
func assert_not_called(inst, method_name, parameters = null):
	var disp = str("Expected [", method_name, "] to NOT have been called on ", _str(inst))

	if _fail_if_parameters_not_array(parameters):
		return

	if !_utils.is_double(inst):
		_fail(
			"You must pass a doubled instance to assert_not_called.  Check the wiki for info on using double."
		)
	else:
		if gut.get_spy().was_called(inst, method_name, parameters):
			if parameters != null:
				disp += str(" with parameters ", parameters)
			_fail(str(disp, "\n", _get_desc_of_calls_to_instance(inst)))
		else:
			_pass(disp)


# ------------------------------------------------------------------------------
# Assert that a method on an instance of a doubled class was called a number
# of times.  If parameters are specified then only calls with matching
# parameter values will be counted.
# ------------------------------------------------------------------------------
func assert_call_count(inst, method_name, expected_count, parameters = null):
	var count = gut.get_spy().call_count(inst, method_name, parameters)

	if _fail_if_parameters_not_array(parameters):
		return

	var param_text = ""
	if parameters:
		param_text = " with parameters " + str(parameters)
	var disp = "Expected [%s] on %s to be called [%s] times%s.  It was called [%s] times."
	disp = disp % [method_name, _str(inst), expected_count, param_text, count]

	if !_utils.is_double(inst):
		_fail(
			"You must pass a doubled instance to assert_call_count.  Check the wiki for info on using double."
		)
	else:
		if count == expected_count:
			_pass(disp)
		else:
			_fail(str(disp, "\n", _get_desc_of_calls_to_instance(inst)))


# ------------------------------------------------------------------------------
# Asserts the passed in value is null
# ------------------------------------------------------------------------------
func assert_null(got, text = ""):
	var disp = str("Expected [", _str(got), "] to be NULL:  ", text)
	if got == null:
		_pass(disp)
	else:
		_fail(disp)


# ------------------------------------------------------------------------------
# Asserts the passed in value is null
# ------------------------------------------------------------------------------
func assert_not_null(got, text = ""):
	var disp = str("Expected [", _str(got), "] to be anything but NULL:  ", text)
	if got == null:
		_fail(disp)
	else:
		_pass(disp)


# -----------------------------------------------------------------------------
# Asserts object has been freed from memory
# We pass in a title (since if it is freed, we lost all identity data)
# -----------------------------------------------------------------------------
func assert_freed(obj, title = "something"):
	var disp = title
	if is_instance_valid(obj):
		disp = _strutils.type2str(obj) + title
	assert_true(not is_instance_valid(obj), "Expected [%s] to be freed" % disp)


# ------------------------------------------------------------------------------
# Asserts Object has not been freed from memory
# -----------------------------------------------------------------------------
func assert_not_freed(obj, title):
	var disp = title
	if is_instance_valid(obj):
		disp = _strutils.type2str(obj) + title
	assert_true(is_instance_valid(obj), "Expected [%s] to not be freed" % disp)


# ------------------------------------------------------------------------------
# Asserts that the current test has not introduced any new orphans.  This only
# applies to the test code that preceedes a call to this method so it should be
# the last thing your test does.
# ------------------------------------------------------------------------------
func assert_no_new_orphans(text = ""):
	var count = gut.get_orphan_counter().get_counter("test")
	var msg = ""
	if text != "":
		msg = ":  " + text
	# Note that get_counter will return -1 if the counter does not exist.  This
	# can happen with a misplaced assert_no_new_orphans.  Checking for > 0
	# ensures this will not cause some weird failure.
	if count > 0:
		_fail(str("Expected no orphans, but found ", count, msg))
	else:
		_pass("No new orphans found." + msg)


# ------------------------------------------------------------------------------
# Returns a dictionary that contains
# - an is_valid flag whether validation was successful or not and
# - a message that gives some information about the validation errors.
# ------------------------------------------------------------------------------
func _validate_assert_setget_called_input(type, name_property, name_setter, name_getter):
	var obj = null
	var result = {"is_valid": true, "msg": ""}

	if null == type or typeof(type) != TYPE_OBJECT or not type.is_class("Resource"):
		result.is_valid = false
		result.msg = str("The type parameter should be a ressource, ", _str(type), " was passed.")
		return result

	if null == double(type):
		result.is_valid = false
		result.msg = str(
			"Attempt to double the type parameter failed. The type parameter should be a ressource that can be doubled."
		)
		return result

	obj = _create_obj_from_type(type)
	var property = _find_object_property(obj, str(name_property))

	if null == property:
		result.is_valid = false
		result.msg += str("The property %s does not exist." % _str(name_property))
	if name_setter == "" and name_getter == "":
		result.is_valid = false
		result.msg += str("Either setter or getter method must be specified.")
	if name_setter != "" and not obj.has_method(str(name_setter)):
		result.is_valid = false
		result.msg += str("Setter method %s does not exist.  " % _str(name_setter))
	if name_getter != "" and not obj.has_method(str(name_getter)):
		result.is_valid = false
		result.msg += str("Getter method %s does not exist.  " % _str(name_getter))

	obj.free()
	return result


# ------------------------------------------------------------------------------
# Validates the singleton_name is a string and exists.  Errors when conditions
# are not met.  Returns true/false if singleton_name is valid or not.
# ------------------------------------------------------------------------------
func _validate_singleton_name(singleton_name):
	var is_valid = true
	if typeof(singleton_name) != TYPE_STRING:
		_lgr.error(
			"double_singleton requires a Godot singleton name, you passed " + _str(singleton_name)
		)
		is_valid = false
	# Sometimes they have underscores in front of them, sometimes they do not.
	# The doubler is smart enought of ind the right thing, so this has to be
	# that smart as well.
	elif !ClassDB.class_exists(singleton_name) and !ClassDB.class_exists("_" + singleton_name):
		var txt = str(
			"The singleton [",
			singleton_name,
			"] could not be found.  ",
			"Check the GlobalScope page for a list of singletons."
		)
		_lgr.error(txt)
		is_valid = false
	return is_valid


# ------------------------------------------------------------------------------
# Asserts the given setter and getter methods are called when the given property
# is accessed.
# ------------------------------------------------------------------------------
func _assert_setget_called(type, name_property, setter = "", getter = ""):
	var name_setter = _utils.nvl(setter, "")
	var name_getter = _utils.nvl(getter, "")

	var validation = _validate_assert_setget_called_input(
		type, name_property, str(name_setter), str(name_getter)
	)
	if not validation.is_valid:
		_fail(validation.msg)
		return

	var message = ""
	var amount_calls_setter = 0
	var amount_calls_getter = 0
	var expected_calls_setter = 0
	var expected_calls_getter = 0
	var obj = _create_obj_from_type(double(type))

	if name_setter != "":
		expected_calls_setter = 1
		stub(obj, name_setter).to_do_nothing()
		obj.set(name_property, null)
		amount_calls_setter = gut.get_spy().call_count(obj, str(name_setter))

	if name_getter != "":
		expected_calls_getter = 1
		stub(obj, name_getter).to_do_nothing()
		var __new_property = obj.get(name_property)
		amount_calls_getter = gut.get_spy().call_count(obj, str(name_getter))

	obj.free()

	# assert

	if (
		amount_calls_setter == expected_calls_setter
		and amount_calls_getter == expected_calls_getter
	):
		_pass(str("setget for %s is correctly configured." % _str(name_property)))
	else:
		if amount_calls_setter < expected_calls_setter:
			message += " The setter was not called."
		elif amount_calls_setter > expected_calls_setter:
			message += " The setter was called but should not have been."
		if amount_calls_getter < expected_calls_getter:
			message += " The getter was not called."
		elif amount_calls_getter > expected_calls_getter:
			message += " The getter was called but should not have been."
		_fail(str(message))


# ------------------------------------------------------------------------------
# Wrapper: invokes assert_setget_called but provides a slightly more convenient
# signature
# ------------------------------------------------------------------------------
func assert_setget(
	instance, name_property, const_or_setter = DEFAULT_SETTER_GETTER, getter = "__not_set__"
):
	var getter_name = null
	if getter != "__not_set__":
		getter_name = getter

	var setter_name = null
	if typeof(const_or_setter) == TYPE_INT:
		if const_or_setter in [SETTER_ONLY, DEFAULT_SETTER_GETTER]:
			setter_name = str("set_", name_property)

		if const_or_setter in [GETTER_ONLY, DEFAULT_SETTER_GETTER]:
			getter_name = str("get_", name_property)
	else:
		setter_name = const_or_setter

	var resource = null
	if instance.is_class("Resource"):
		resource = instance
	else:
		resource = instance.get_script()

	_assert_setget_called(resource, str(name_property), setter_name, getter_name)


# ------------------------------------------------------------------------------
# Wrapper: asserts if the property exists, the accessor methods exist and the
# setget keyword is set for accessor methods
# ------------------------------------------------------------------------------
func assert_property(instance, name_property, default_value, new_value) -> void:
	var free_me = []
	var resource = null
	var obj = null
	if instance.is_class("Resource"):
		resource = instance
		obj = _create_obj_from_type(resource)
		free_me.append(obj)
	else:
		resource = instance.get_script()
		obj = instance

	var name_setter = "set_" + str(name_property)
	var name_getter = "get_" + str(name_property)

	var pre_fail_count = get_fail_count()
	assert_accessors(obj, str(name_property), default_value, new_value)
	_assert_setget_called(resource, str(name_property), name_setter, name_getter)

	for entry in free_me:
		entry.free()

	# assert
	if get_fail_count() == pre_fail_count:
		_pass(str("The property is set up as expected."))
	else:
		_fail(str("The property is not set up as expected. Examine subtests to see what failed."))


# ------------------------------------------------------------------------------
# Mark the current test as pending.
# ------------------------------------------------------------------------------
func pending(text = ""):
	_summary.pending += 1
	if gut:
		_lgr.pending(text)
		gut._pending(text)


# ------------------------------------------------------------------------------
# Returns the number of times a signal was emitted.  -1 returned if the object
# is not being watched.
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Yield for the time sent in.  The optional message will be printed when
# Gut detects the yield.  When the time expires the YIELD signal will be
# emitted.
# ------------------------------------------------------------------------------
func yield_for(time, msg = ""):
	return gut.set_yield_time(time, msg)


# ------------------------------------------------------------------------------
# Yield to a signal or a maximum amount of time, whichever comes first.  When
# the conditions are met the YIELD signal will be emitted.
# ------------------------------------------------------------------------------
func yield_to(obj, signal_name, max_wait, msg = ""):
	watch_signals(obj)
	gut.set_yield_signal_or_time(obj, signal_name, max_wait, msg)

	return gut


# ------------------------------------------------------------------------------
# Yield for a number of frames.  The optional message will be printed. when
# Gut detects a yield.  When the number of frames have elapsed (counted in gut's
# _process function) the YIELD signal will be emitted.
# ------------------------------------------------------------------------------
func yield_frames(frames, msg = ""):
	if frames <= 0:
		var text = str(
			"yeild_frames:  frames must be > 0, you passed  ", frames, ".  0 frames waited."
		)
		_lgr.error(text)
		frames = 0

	gut.set_yield_frames(frames, msg)
	return gut


# ------------------------------------------------------------------------------
# Ends a test that had a yield in it.  You only need to use this if you do
# not make assertions after a yield.
# ------------------------------------------------------------------------------
func end_test():
	_lgr.deprecated("end_test is no longer necessary, you can remove it.")
	#gut.end_yielded_test()


func get_summary():
	return _summary


func get_fail_count():
	return _summary.failed


func get_pass_count():
	return _summary.passed


func get_pending_count():
	return _summary.pending


func get_assert_count():
	return _summary.asserts


func clear_signal_watcher():
	_signal_watcher.clear()


func get_double_strategy():
	return gut.get_doubler().get_strategy()


func set_double_strategy(double_strategy):
	gut.get_doubler().set_strategy(double_strategy)


func pause_before_teardown():
	gut.pause_before_teardown()


# ------------------------------------------------------------------------------
# Convert the _summary dictionary into text
# ------------------------------------------------------------------------------
func get_summary_text():
	var to_return = get_script().get_path() + "\n"
	to_return += str("  ", _summary.passed, " of ", _summary.asserts, " passed.")
	if _summary.pending > 0:
		to_return += str("\n  ", _summary.pending, " pending")
	if _summary.failed > 0:
		to_return += str("\n  ", _summary.failed, " failed.")
	return to_return


# ------------------------------------------------------------------------------
# Double a script, inner class, or scene using a path or a loaded script/scene.
#
#
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func _smart_double(double_info):
	var override_strat = _utils.nvl(double_info.strategy, gut.get_doubler().get_strategy())
	var to_return = null

	if double_info.is_scene():
		if double_info.make_partial:
			to_return = gut.get_doubler().partial_double_scene(double_info.path, override_strat)
		else:
			to_return = gut.get_doubler().double_scene(double_info.path, override_strat)

	elif double_info.is_native():
		if double_info.make_partial:
			to_return = gut.get_doubler().partial_double_gdnative(double_info.path)
		else:
			to_return = gut.get_doubler().double_gdnative(double_info.path)

	elif double_info.is_script():
		if double_info.subpath == null:
			if double_info.make_partial:
				to_return = gut.get_doubler().partial_double(double_info.path, override_strat)
			else:
				to_return = gut.get_doubler().double(double_info.path, override_strat)
		else:
			if double_info.make_partial:
				to_return = gut.get_doubler().partial_double_inner(
					double_info.path, double_info.subpath, override_strat
				)
			else:
				to_return = gut.get_doubler().double_inner(
					double_info.path, double_info.subpath, override_strat
				)
	return to_return


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func double(thing, p2 = null, p3 = null):
	var double_info = DoubleInfo.new(thing, p2, p3)
	if !double_info.is_valid:
		_lgr.error("double requires a class or path, you passed an instance:  " + _str(thing))
		return null

	double_info.make_partial = false

	return _smart_double(double_info)


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
func partial_double(thing, p2 = null, p3 = null):
	var double_info = DoubleInfo.new(thing, p2, p3)
	if !double_info.is_valid:
		_lgr.error(
			"partial_double requires a class or path, you passed an instance:  " + _str(thing)
		)
		return null

	double_info.make_partial = true

	return _smart_double(double_info)


# ------------------------------------------------------------------------------
# Doubles a Godot singleton
# ------------------------------------------------------------------------------
func double_singleton(singleton_name):
	return null
	# var to_return = null
	# if(_validate_singleton_name(singleton_name)):
	# 	to_return = gut.get_doubler().double_singleton(singleton_name)
	# return to_return


# ------------------------------------------------------------------------------
# Partial Doubles a Godot singleton
# ------------------------------------------------------------------------------
func partial_double_singleton(singleton_name):
	return null
	# var to_return = null
	# if(_validate_singleton_name(singleton_name)):
	# 	to_return = gut.get_doubler().partial_double_singleton(singleton_name)
	# return to_return


# ------------------------------------------------------------------------------
# Specifically double a scene
# ------------------------------------------------------------------------------
func double_scene(path, strategy = null):
	var override_strat = _utils.nvl(strategy, gut.get_doubler().get_strategy())
	return gut.get_doubler().double_scene(path, override_strat)


# ------------------------------------------------------------------------------
# Specifically double a script
# ------------------------------------------------------------------------------
func double_script(path, strategy = null):
	var override_strat = _utils.nvl(strategy, gut.get_doubler().get_strategy())
	return gut.get_doubler().double(path, override_strat)


# ------------------------------------------------------------------------------
# Specifically double an Inner class in a a script
# ------------------------------------------------------------------------------
func double_inner(path, subpath, strategy = null):
	var override_strat = _utils.nvl(strategy, gut.get_doubler().get_strategy())
	return gut.get_doubler().double_inner(path, subpath, override_strat)


# ------------------------------------------------------------------------------
# Add a method that the doubler will ignore.  You can pass this the path to a
# script or scene or a loaded script or scene.  When running tests, these
# ignores are cleared after every test.
# ------------------------------------------------------------------------------
func ignore_method_when_doubling(thing, method_name):
	var double_info = DoubleInfo.new(thing)
	var path = double_info.path

	if double_info.is_scene():
		var inst = thing.instance()
		if inst.get_script():
			path = inst.get_script().get_path()

	gut.get_doubler().add_ignored_method(path, method_name)


# ------------------------------------------------------------------------------
# Stub something.
#
# Parameters
# 1: the thing to stub, a file path or a instance or a class
# 2: either an inner class subpath or the method name
# 3: the method name if an inner class subpath was specified
# NOTE:  right now we cannot stub inner classes at the path level so this should
#        only be called with two parameters.  I did the work though so I'm going
#        to leave it but not update the wiki.
# ------------------------------------------------------------------------------
func stub(thing, p2, p3 = null):
	if _utils.is_instance(thing) and !_utils.is_double(thing):
		_lgr.error(str("You cannot use stub on ", _str(thing), " because it is not a double."))
		return _utils.StubParams.new()

	var method_name = p2
	var subpath = null
	if p3 != null:
		subpath = p2
		method_name = p3

	var sp = _utils.StubParams.new(thing, method_name, subpath)
	gut.get_stubber().add_stub(sp)
	return sp


# ------------------------------------------------------------------------------
# convenience wrapper.
# ------------------------------------------------------------------------------
func simulate(obj, times, delta, check_is_processing: bool = false):
	gut.simulate(obj, times, delta, check_is_processing)


# ------------------------------------------------------------------------------
# Replace the node at base_node.get_node(path) with with_this.  All references
# to the node via $ and get_node(...) will now return with_this.  with_this will
# get all the groups that the node that was replaced had.
#
# The node that was replaced is queued to be freed.
#
# TODO see replace_by method, this could simplify the logic here.
# ------------------------------------------------------------------------------
func replace_node(base_node, path_or_node, with_this):
	var path = path_or_node

	if typeof(path_or_node) != TYPE_STRING:
		# This will cause an engine error if it fails.  It always returns a
		# NodePath, even if it fails.  Checking the name count is the only way
		# I found to check if it found something or not (after it worked I
		# didn't look any farther).
		path = base_node.get_path_to(path_or_node)
		if path.get_name_count() == 0:
			_lgr.error("You passed an object that base_node does not have.  Cannot replace node.")
			return

	if !base_node.has_node(path):
		_lgr.error(str("Could not find node at path [", path, "]"))
		return

	var to_replace = base_node.get_node(path)
	var parent = to_replace.get_parent()
	var replace_name = to_replace.get_name()

	parent.remove_child(to_replace)
	parent.add_child(with_this)
	with_this.set_name(replace_name)
	with_this.set_owner(parent)

	var groups = to_replace.get_groups()
	for i in range(groups.size()):
		with_this.add_to_group(groups[i])

	to_replace.queue_free()


# ------------------------------------------------------------------------------
# This method does a somewhat complicated dance with Gut.  It assumes that Gut
# will clear its parameter handler after it finishes calling a parameterized test
# enough times.
# ------------------------------------------------------------------------------
func use_parameters(params):
	var ph = gut.get_parameter_handler()
	if ph == null:
		ph = _utils.ParameterHandler.new(params)
		gut.set_parameter_handler(ph)

	var output = str(
		"(call #", ph.get_call_count() + 1, ") with parameters:  ", ph.get_current_parameters()
	)
	_lgr.log(output)
	_lgr.inc_indent()
	return ph.next_parameters()


# ------------------------------------------------------------------------------
# Marks whatever is passed in to be freed after the test finishes.  It also
# returns what is passed in so you can save a line of code.
#   var thing = autofree(Thing.new())
# ------------------------------------------------------------------------------
func autofree(thing):
	gut.get_autofree().add_free(thing)
	return thing


# ------------------------------------------------------------------------------
# Works the same as autofree except queue_free will be called on the object
# instead.  This also imparts a brief pause after the test finishes so that
# the queued object has time to free.
# ------------------------------------------------------------------------------
func autoqfree(thing):
	gut.get_autofree().add_queue_free(thing)
	return thing


# ------------------------------------------------------------------------------
# The same as autofree but it also adds the object as a child of the test.
# ------------------------------------------------------------------------------
func add_child_autofree(node, legible_unique_name = false):
	gut.get_autofree().add_free(node)
	# Explicitly calling super here b/c add_child MIGHT change and I don't want
	# a bug sneaking its way in here.
	.add_child(node, legible_unique_name)
	return node


# ------------------------------------------------------------------------------
# The same as autoqfree but it also adds the object as a child of the test.
# ------------------------------------------------------------------------------
func add_child_autoqfree(node, legible_unique_name = false):
	gut.get_autofree().add_queue_free(node)
	# Explicitly calling super here b/c add_child MIGHT change and I don't want
	# a bug sneaking its way in here.
	.add_child(node, legible_unique_name)
	return node


# ------------------------------------------------------------------------------
# Returns true if the test is passing as of the time of this call.  False if not.
# ------------------------------------------------------------------------------
func is_passing():
	if (
		gut.get_current_test_object() != null
		and !["before_all", "after_all"].has(gut.get_current_test_object().name)
	):
		return (
			gut.get_current_test_object().passed
			and gut.get_current_test_object().assert_count > 0
		)
	else:
		_lgr.error("No current test object found.  is_passing must be called inside a test.")
		return null


# ------------------------------------------------------------------------------
# Returns true if the test is failing as of the time of this call.  False if not.
# ------------------------------------------------------------------------------
func is_failing():
	if (
		gut.get_current_test_object() != null
		and !["before_all", "after_all"].has(gut.get_current_test_object().name)
	):
		return !gut.get_current_test_object().passed
	else:
		_lgr.error("No current test object found.  is_failing must be called inside a test.")
		return null


# ------------------------------------------------------------------------------
# Marks the test as passing.  Does not override any failing asserts or calls to
# fail_test.  Same as a passing assert.
# ------------------------------------------------------------------------------
func pass_test(text):
	_pass(text)


# ------------------------------------------------------------------------------
# Marks the test as failing.  Same as a failing assert.
# ------------------------------------------------------------------------------
func fail_test(text):
	_fail(text)


# ------------------------------------------------------------------------------
# Peforms a deep compare on both values, a CompareResult instnace is returned.
# The optional max_differences paramter sets the max_differences to be displayed.
# ------------------------------------------------------------------------------
func compare_deep(v1, v2, max_differences = null):
	var result = _compare.deep(v1, v2)
	if max_differences != null:
		result.max_differences = max_differences
	return result


# ------------------------------------------------------------------------------
# Peforms a shallow compare on both values, a CompareResult instnace is returned.
# The optional max_differences paramter sets the max_differences to be displayed.
# ------------------------------------------------------------------------------
func compare_shallow(v1, v2, max_differences = null):
	var result = _compare.shallow(v1, v2)
	if max_differences != null:
		result.max_differences = max_differences
	return result


# ------------------------------------------------------------------------------
# Performs a deep compare and asserts the  values are equal
# ------------------------------------------------------------------------------
func assert_eq_deep(v1, v2):
	var result = compare_deep(v1, v2)
	if result.are_equal:
		_pass(result.get_short_summary())
	else:
		_fail(result.summary)


# ------------------------------------------------------------------------------
# Performs a deep compare and asserts the values are not equal
# ------------------------------------------------------------------------------
func assert_ne_deep(v1, v2):
	var result = compare_deep(v1, v2)
	if !result.are_equal:
		_pass(result.get_short_summary())
	else:
		_fail(result.get_short_summary())


# ------------------------------------------------------------------------------
# Performs a shallow compare and asserts the values are equal
# ------------------------------------------------------------------------------
func assert_eq_shallow(v1, v2):
	var result = compare_shallow(v1, v2)
	if result.are_equal:
		_pass(result.get_short_summary())
	else:
		_fail(result.summary)


# ------------------------------------------------------------------------------
# Performs a shallow compare and asserts the values are not equal
# ------------------------------------------------------------------------------
func assert_ne_shallow(v1, v2):
	var result = compare_shallow(v1, v2)
	if !result.are_equal:
		_pass(result.get_short_summary())
	else:
		_fail(result.get_short_summary())


# ------------------------------------------------------------------------------
# Checks the passed in version string (x.x.x) against the engine version to see
# if the engine version is less than the expected version.  If it is then the
# test is mareked as passed (for a lack of anything better to do).  The result
# of the check is returned.
#
# Example:
# if(skip_if_godot_version_lt('3.5.0')):
# 	return
# ------------------------------------------------------------------------------
func skip_if_godot_version_lt(expected):
	var should_skip = !_utils.is_godot_version_gte(expected)
	if should_skip:
		_pass(str("Skipping ", _utils.godot_version(), " is less than ", expected))
	return should_skip


# ------------------------------------------------------------------------------
# Checks if the passed in version matches the engine version.  The passed in
# version can contain just the major, major.minor or major.minor.path.  If
# the version is not the same then the test is marked as passed.  The result of
# the check is returned.
#
# Example:
# if(skip_if_godot_version_ne('3.4')):
# 	return
# ------------------------------------------------------------------------------
func skip_if_godot_version_ne(expected):
	var should_skip = !_utils.is_godot_version(expected)
	if should_skip:
		_pass(str("Skipping ", _utils.godot_version(), " is not ", expected))
	return should_skip

--- Start of ./addons/gut/thing_counter.gd ---

var things = {}

func get_unique_count():
	return things.size()

func add(thing):
	if(things.has(thing)):
		things[thing] += 1
	else:
		things[thing] = 1

func has(thing):
	return things.has(thing)

func get(thing):
	var to_return = 0
	if(things.has(thing)):
		to_return = things[thing]
	return to_return

func sum():
	var count = 0
	for key in things:
		count += things[key]
	return count

func to_s():
	var to_return = ""
	for key in things:
		to_return += str(key, ":  ", things[key], "\n")
	to_return += str("sum: ", sum())
	return to_return

func get_max_count():
	var max_val = null
	for key in things:
		if(max_val == null or things[key] > max_val):
			max_val = things[key]
	return max_val

func add_array_items(array):
	for i in range(array.size()):
		add(array[i])

--- Start of ./addons/gut/UserFileViewer.gd ---

extends WindowDialog

onready var rtl = $TextDisplay/RichTextLabel
var _has_opened_file = false

func _get_file_as_text(path):
	var to_return = null
	var f = File.new()
	var result = f.open(path, f.READ)
	if(result == OK):
		to_return = f.get_as_text()
		f.close()
	else:
		to_return = str('ERROR:  Could not open file.  Error code ', result)
	return to_return

func _ready():
	rtl.clear()

func _on_OpenFile_pressed():
	$FileDialog.popup_centered()

func _on_FileDialog_file_selected(path):
	show_file(path)

func _on_Close_pressed():
	self.hide()

func show_file(path):
	var text = _get_file_as_text(path)
	if(text == ''):
		text = '<Empty File>'
	rtl.set_text(text)
	self.window_title = path

func show_open():
	self.popup_centered()
	$FileDialog.popup_centered()

func _on_FileDialog_popup_hide():
	if(rtl.text.length() == 0):
		self.hide()

func get_rich_text_label():
	return $TextDisplay/RichTextLabel

func _on_Home_pressed():
	rtl.scroll_to_line(0)

func _on_End_pressed():
	rtl.scroll_to_line(rtl.get_line_count() -1)


func _on_Copy_pressed():
	OS.clipboard = rtl.text

--- Start of ./addons/gut/utils.gd ---

# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# Description
# -----------
# This class is a PSUEDO SINGLETON.  You should not make instances of it but use
# the get_instance static method.
# ##############################################################################
extends Node

# ------------------------------------------------------------------------------
# The instance name as a function since you can't have static variables.
# ------------------------------------------------------------------------------
static func INSTANCE_NAME():
	return '__GutUtilsInstName__'

# ------------------------------------------------------------------------------
# Gets the root node without having to be in the tree and pushing out an error
# if we don't have a main loop ready to go yet.
# ------------------------------------------------------------------------------
static func get_root_node():
	var to_return = null
	var main_loop = Engine.get_main_loop()
	if(main_loop != null):
		return main_loop.root
	else:
		push_error('No Main Loop Yet')
		return null

# ------------------------------------------------------------------------------
# Get the ONE instance of utils
# ------------------------------------------------------------------------------
static func get_instance():
	var the_root = get_root_node()
	var inst = null
	if(the_root.has_node(INSTANCE_NAME())):
		inst = the_root.get_node(INSTANCE_NAME())
	else:
		inst = load('res://addons/gut/utils.gd').new()
		inst.set_name(INSTANCE_NAME())
		the_root.add_child(inst)
	return inst

var Logger = load('res://addons/gut/logger.gd') # everything should use get_logger
var _lgr = null

var _test_mode = false

var AutoFree = load('res://addons/gut/autofree.gd')
var Comparator = load('res://addons/gut/comparator.gd')
var CompareResult = load('res://addons/gut/compare_result.gd')
var DiffTool = load('res://addons/gut/diff_tool.gd')
var Doubler = load('res://addons/gut/doubler.gd')
var Gut = load('res://addons/gut/gut.gd')
var HookScript = load('res://addons/gut/hook_script.gd')
var InputFactory = load("res://addons/gut/input_factory.gd")
var InputSender = load("res://addons/gut/input_sender.gd")
var JunitXmlExport = load('res://addons/gut/junit_xml_export.gd')
var MethodMaker = load('res://addons/gut/method_maker.gd')
var OneToMany = load('res://addons/gut/one_to_many.gd')
var OrphanCounter = load('res://addons/gut/orphan_counter.gd')
var ParameterFactory = load('res://addons/gut/parameter_factory.gd')
var ParameterHandler = load('res://addons/gut/parameter_handler.gd')
var Printers = load('res://addons/gut/printers.gd')
var ResultExporter = load('res://addons/gut/result_exporter.gd')
var Spy = load('res://addons/gut/spy.gd')
var Strutils = load('res://addons/gut/strutils.gd')
var Stubber = load('res://addons/gut/stubber.gd')
var StubParams = load('res://addons/gut/stub_params.gd')
var Summary = load('res://addons/gut/summary.gd')
var Test = load('res://addons/gut/test.gd')
var TestCollector = load('res://addons/gut/test_collector.gd')
var ThingCounter = load('res://addons/gut/thing_counter.gd')

# Source of truth for the GUT version
var version = '7.4.3'
# The required Godot version as an array.
var req_godot = [3, 2, 0]
# Used for doing file manipulation stuff so as to not keep making File instances.
# could be a bit of overkill but who cares.
var _file_checker = File.new()
# Online fetch of the latest version available on github
var latest_version = null
var should_display_latest_version = false


# These methods all call super implicitly.  Stubbing them to call super causes
# super to be called twice.
var non_super_methods = [
	"_init",
	"_ready",
	"_notification",
	"_enter_world",
	"_exit_world",
	"_process",
	"_physics_process",
	"_exit_tree",
	"_gui_input	",
]


func _ready() -> void:
	_http_request_latest_version()

func _http_request_latest_version() -> void:
	var http_request = HTTPRequest.new()
	http_request.name = "http_request"
	add_child(http_request)
	http_request.connect("request_completed", self, "_on_http_request_latest_version_completed")
	# Perform a GET request. The URL below returns JSON as of writing.
	var error = http_request.request("https://api.github.com/repos/bitwes/Gut/releases/latest")

func _on_http_request_latest_version_completed(result, response_code, headers, body):
	if not result == HTTPRequest.RESULT_SUCCESS:
		return

	var response = parse_json(body.get_string_from_utf8())
	# Will print the user agent string used by the HTTPRequest node (as recognized by httpbin.org).
	if response:
		if response.get("html_url"):
			latest_version = Array(response.html_url.split("/")).pop_back().right(1)
			if latest_version != version:
				should_display_latest_version = true



const GUT_METADATA = '__gut_metadata_'

enum DOUBLE_STRATEGY{
	FULL,
	PARTIAL
}

enum DIFF {
	DEEP,
	SHALLOW,
	SIMPLE
}

# ------------------------------------------------------------------------------
# Blurb of text with GUT and Godot versions.
# ------------------------------------------------------------------------------
func get_version_text():
	var v_info = Engine.get_version_info()
	var gut_version_info =  str('GUT version:  ', version)
	var godot_version_info  = str('Godot version:  ', v_info.major,  '.',  v_info.minor,  '.',  v_info.patch)
	return godot_version_info + "\n" + gut_version_info


# ------------------------------------------------------------------------------
# Returns a nice string for erroring out when we have a bad Godot version.
# ------------------------------------------------------------------------------
func get_bad_version_text():
	var ver = PoolStringArray(req_godot).join('.')
	var info = Engine.get_version_info()
	var gd_version = str(info.major, '.', info.minor, '.', info.patch)
	return 'GUT ' + version + ' requires Godot ' + ver + ' or greater.  Godot version is ' + gd_version


# ------------------------------------------------------------------------------
# Checks the Godot version against req_godot array.
# ------------------------------------------------------------------------------
func is_version_ok(engine_info=Engine.get_version_info(),required=req_godot):
	var is_ok = null
	var engine_array = [engine_info.major, engine_info.minor, engine_info.patch]

	var idx = 0
	while(is_ok == null and idx < engine_array.size()):
		if(int(engine_array[idx]) > int(required[idx])):
			is_ok = true
		elif(int(engine_array[idx]) < int(required[idx])):
			is_ok = false

		idx += 1

	# still null means each index was the same.
	return nvl(is_ok, true)


func godot_version(engine_info=Engine.get_version_info()):
	return str(engine_info.major, '.', engine_info.minor, '.', engine_info.patch)


func is_godot_version(expected, engine_info=Engine.get_version_info()):
	var engine_array = [engine_info.major, engine_info.minor, engine_info.patch]
	var expected_array = expected.split('.')

	if(expected_array.size() > engine_array.size()):
		return false

	var is_version = true
	var i = 0
	while(i < expected_array.size() and i < engine_array.size() and is_version):
		if(expected_array[i] == str(engine_array[i])):
			i += 1
		else:
			is_version = false

	return is_version


func is_godot_version_gte(expected, engine_info=Engine.get_version_info()):
	return is_version_ok(engine_info, expected.split('.'))


# ------------------------------------------------------------------------------
# Everything should get a logger through this.
#
# When running in test mode this will always return a new logger so that errors
# are not caused by getting bad warn/error/etc counts.
# ------------------------------------------------------------------------------
func get_logger():
	if(_test_mode):
		return Logger.new()
	else:
		if(_lgr == null):
			_lgr = Logger.new()
		return _lgr



# ------------------------------------------------------------------------------
# return if_null if value is null otherwise return value
# ------------------------------------------------------------------------------
func nvl(value, if_null):
	if(value == null):
		return if_null
	else:
		return value


# ------------------------------------------------------------------------------
# returns true if the object has been freed, false if not
#
# From what i've read, the weakref approach should work.  It seems to work most
# of the time but sometimes it does not catch it.  The str comparison seems to
# fill in the gaps.  I've not seen any errors after adding that check.
# ------------------------------------------------------------------------------
func is_freed(obj):
	var wr = weakref(obj)
	return !(wr.get_ref() and str(obj) != '[Deleted Object]')


# ------------------------------------------------------------------------------
# Pretty self explanitory.
# ------------------------------------------------------------------------------
func is_not_freed(obj):
	return !is_freed(obj)


# ------------------------------------------------------------------------------
# Checks if the passed in object is a GUT Double or Partial Double.
# ------------------------------------------------------------------------------
func is_double(obj):
	var to_return = false
	if(typeof(obj) == TYPE_OBJECT and is_instance_valid(obj)):
		to_return = obj.has_method('__gut_instance_from_id')
	return to_return


# ------------------------------------------------------------------------------
# Checks if the passed in is an instance of a class
# ------------------------------------------------------------------------------
func is_instance(obj):
	return typeof(obj) == TYPE_OBJECT and !obj.has_method('new') and !obj.has_method('instance')

# ------------------------------------------------------------------------------
# Checks if the passed in is a GDScript
# ------------------------------------------------------------------------------
func is_gdscript(obj):
	return typeof(obj) == TYPE_OBJECT and str(obj).begins_with('[GDScript:')

# ------------------------------------------------------------------------------
# Returns an array of values by calling get(property) on each element in source
# ------------------------------------------------------------------------------
func extract_property_from_array(source, property):
	var to_return = []
	for i in (source.size()):
		to_return.append(source[i].get(property))
	return to_return


# ------------------------------------------------------------------------------
# true if file exists, false if not.
# ------------------------------------------------------------------------------
func file_exists(path):
	return _file_checker.file_exists(path)


# ------------------------------------------------------------------------------
# Write a file.
# ------------------------------------------------------------------------------
func write_file(path, content):
	var f = File.new()
	var result = f.open(path, f.WRITE)
	if(result == OK):
		f.store_string(content)
		f.close()

	return result

# ------------------------------------------------------------------------------
# true if what is passed in is null or an empty string.
# ------------------------------------------------------------------------------
func is_null_or_empty(text):
	return text == null or text == ''


# ------------------------------------------------------------------------------
# Get the name of a native class or null if the object passed in is not a
# native class.
# ------------------------------------------------------------------------------
func get_native_class_name(thing):
	var to_return = null
	if(is_native_class(thing)):
		var newone = thing.new()
		to_return = newone.get_class()
		if(!newone is Reference):
			newone.free()
	return to_return


# ------------------------------------------------------------------------------
# Checks an object to see if it is a GDScriptNativeClass
# ------------------------------------------------------------------------------
func is_native_class(thing):
	var it_is = false
	if(typeof(thing) == TYPE_OBJECT):
		it_is = str(thing).begins_with("[GDScriptNativeClass:")
	return it_is


# ------------------------------------------------------------------------------
# Returns the text of a file or an empty string if the file could not be opened.
# ------------------------------------------------------------------------------
func get_file_as_text(path):
	var to_return = ''
	var f = File.new()
	var result = f.open(path, f.READ)
	if(result == OK):
		to_return = f.get_as_text()
		f.close()
	return to_return


# ------------------------------------------------------------------------------
# Loops through an array of things and calls a method or checks a property on
# each element until it finds the returned value.  The item in the array is
# returned or null if it is not found.
# ------------------------------------------------------------------------------
func search_array(ar, prop_method, value):
	var found = false
	var idx = 0

	while(idx < ar.size() and !found):
		var item = ar[idx]
		if(item.get(prop_method) != null):
			if(item.get(prop_method) == value):
				found = true
		elif(item.has_method(prop_method)):
			if(item.call(prop_method) == value):
				found = true

		if(!found):
			idx += 1

	if(found):
		return ar[idx]
	else:
		return null


func are_datatypes_same(got, expected):
	return !(typeof(got) != typeof(expected) and got != null and expected != null)


func pretty_print(dict):
	print(str(JSON.print(dict, ' ')))


func get_script_text(obj):
	return obj.get_script().get_source_code()


func get_singleton_by_name(name):
	var source = str("var singleton = ", name)
	var script = GDScript.new()
	script.set_source_code(source)
	script.reload()
	return script.new().singleton

--- Start of ./database/definitions/action_template.gd ---

# File: core/resources/action_template.gd
# Purpose: Defines the data structure for an agent action.
# Version: 1.1 - Added properties for Action Checks.

extends Template
class_name ActionTemplate

export var action_name: String = "Unnamed Action"
export var tu_cost: int = 1
export var base_attribute: String = "int" # stub
export var associated_skill: String = "computers" # stub

--- Start of ./database/definitions/agent_template.gd ---

# File: core/resource/agent_template.gd
# Resource Definition for Agent.
# Version: 2.0 - Reworked Agent to be a more abstract entity.
# Only needed for in-game simulation, not related to character or ship directly.

extends Template
class_name AgentTemplate 

export var agent_type: String = "npc" # Defines whether it is controlled by AI or player.
var agent_uid: int = 0 # Assigned dynamically by agent spawner to link characters, ships, assets to specific agent in space.

--- Start of ./database/definitions/asset_commodity_template.gd ---

# File: core/resource/commodity_template.gd
# Purpose: Defines commodity.
# Version: 1.0

extends AssetTemplate
class_name CommodityTemplate

export var commodity_name: String = "Unnamed Commodity"
export var base_value: int = 10 # Base value in WP for one unit

--- Start of ./database/definitions/asset_module_template.gd ---

# File: core/resource/module_template.gd
# Purpose: Defines equipment.
# Version: 1.0

extends AssetTemplate
class_name ModuleTemplate

export var module_name: String = "Unnamed Module"
export var base_value: int = 10 # Base value in WP for one unit

--- Start of ./database/definitions/asset_ship_template.gd ---

# File: core/resource/ship_template.gd
# Purpose: Defines ships.
# Version: 1.0

extends AssetTemplate
class_name ShipTemplate

export var ship_model_name: String = "Default Ship Model" 
export var hull_integrity: int = 100
export var armor_integrity: int = 100
export var cargo_capacity: int = 100
export var interaction_radius: float = 15.0

export var ship_quirks: Array = [] # De-buffs or narrative elements
export var ship_upgrades: Array = [] # Buffs

# --- Weapon Mounts ---
export var weapon_slots_small: int = 2  # Number of small weapon mounts
export var weapon_slots_medium: int = 0  # Number of medium weapon mounts
export var weapon_slots_large: int = 0  # Number of large weapon mounts
export var equipped_weapons: Array = []  # Array of weapon template_ids

# --- Power ---
export var power_capacity: float = 100.0
export var power_regen: float = 10.0  # Per second

export var max_move_speed: float = Constants.DEFAULT_MAX_MOVE_SPEED
export var acceleration: float = Constants.DEFAULT_ACCELERATION
export var deceleration: float = Constants.DEFAULT_DECELERATION
export var max_turn_speed: float = Constants.DEFAULT_MAX_TURN_SPEED
export var alignment_threshold_angle_deg: float = Constants.DEFAULT_ALIGNMENT_ANGLE_THRESHOLD

# TODO: add fields which link to specific scenes that define each ship model?

--- Start of ./database/definitions/asset_template.gd ---

# File: core/resource/asset_template.gd
# Purpose: Defines a asset-wide fields.
# Is not meant to be standalone, acts as a base for differnt asset types.
# Version: 1.0

extends Template
class_name AssetTemplate

export var asset_type: String = "asset_type" # For categorization
export var asset_icon_id: String = "asset_default"

--- Start of ./database/definitions/character_template.gd ---

# File: core/resource/character_template.gd
# Purpose: Defines the data structure for a single character linked to an agent.
# Version: 1.0

extends Template
class_name CharacterTemplate

export var character_name: String = "Unnamed"
export var character_icon_id: String = "character_default_icon"
export var faction_id: String = "faction_default" # Affiliation

export var wealth_points: int = 0
export var focus_points: int = 0
export var active_ship_uid: int = -1

export var skills: Dictionary = {
	"piloting": 1,
	"combat": 1,
	"trading": 1
}

# --- Narrative Stubs ---
export var age: int = 30
export var reputation: int = 0
export var faction_standings: Dictionary = {} # e.g., {"pirates": -10, "corp": 5}
export var character_standings: Dictionary = {} # For relationships

--- Start of ./database/definitions/contract_template.gd ---

# contract_template.gd
# Data structure for contracts - delivery, combat, exploration missions
extends "res://database/definitions/template.gd"
class_name ContractTemplate

# Contract identification
export var contract_type: String = "delivery"  # delivery, combat, exploration
export var title: String = "Unnamed Contract"
export var description: String = ""

# Contract parties
export var issuer_id: String = ""      # Contact/NPC ID who gave the contract
export var faction_id: String = ""     # Faction associated with contract

# Location requirements
export var origin_location_id: String = ""       # Where contract was accepted
export var destination_location_id: String = ""  # Where to deliver/complete

# Delivery requirements (for delivery type)
export var required_commodity_id: String = ""
export var required_quantity: int = 0

# Combat requirements (for combat type)
export var target_type: String = ""    # e.g., "pirate", "hostile"
export var target_count: int = 0

# Rewards
export var reward_wp: int = 0
export var reward_reputation: int = 0
export var reward_items: Dictionary = {}  # template_id -> quantity

# Constraints
export var time_limit_tu: int = -1     # -1 = no limit
export var difficulty: int = 1         # 1-5 scale for filtering/matching

# Runtime state (set when contract is active)
export var accepted_at_tu: int = -1    # When player accepted
export var progress: Dictionary = {}   # Track partial completion


# Check if contract has expired based on current time
func is_expired(current_tu: int) -> bool:
	if time_limit_tu < 0:
		return false
	if accepted_at_tu < 0:
		return false
	return (current_tu - accepted_at_tu) >= time_limit_tu


# Get remaining time in TU, -1 if no limit
func get_remaining_time(current_tu: int) -> int:
	if time_limit_tu < 0:
		return -1
	if accepted_at_tu < 0:
		return time_limit_tu
	var elapsed = current_tu - accepted_at_tu
	return int(max(0, time_limit_tu - elapsed))


# Create a summary for UI display
func get_summary() -> Dictionary:
	return {
		"title": title,
		"type": contract_type,
		"destination": destination_location_id,
		"reward_wp": reward_wp,
		"difficulty": difficulty,
		"has_time_limit": time_limit_tu > 0
	}

--- Start of ./database/definitions/location_template.gd ---

# File: core/resource/location_template.gd
# Purpose: Defines the data structure for a location (station, outpost, etc.)
# Version: 1.0

extends Template
class_name LocationTemplate

export var location_name: String = "Unknown Station"
export var location_type: String = "station"  # station, outpost, debris_field, asteroid_field
export var position_in_zone: Vector3 = Vector3.ZERO
export var interaction_radius: float = 100.0  # How close player must be to dock

# Market inventory: commodity_template_id -> {price: int, quantity: int}
# Example: {"commodity_ore": {"price": 10, "quantity": 50}}
export var market_inventory: Dictionary = {}

# Services available at this location
export var available_services: Array = ["trade", "contracts"]

# Faction that controls this location
export var controlling_faction_id: String = ""

# Danger level affects encounter chances nearby (0 = safe, 10 = very dangerous)
export var danger_level: int = 0

# Contracts available at this location (contract_template_ids)
export var available_contract_ids: Array = []

--- Start of ./database/definitions/template.gd ---

# File: core/resources/template.gd
# Purpose: Defines top-most template data.
# Version: 1.0

extends Resource
class_name Template

export var template_id: String = "" # Is set manually for each new resource in assets/data/.

--- Start of ./database/definitions/utility_tool_template.gd ---

# File: core/resource/utility_tool_template.gd
# Purpose: Defines utility tools (weapons/industrial tools) for ships
# Version: 1.1 - Now extends Template for proper indexing

extends Template
class_name UtilityToolTemplate

# --- Identity ---
# template_id is inherited from Template
export var tool_name: String = "Unknown Tool"
export var description: String = ""
export var tool_type: String = "weapon"  # "weapon", "mining", "utility", "grapple"

# --- Combat Stats ---
export var damage: float = 10.0
export var range_effective: float = 100.0
export var range_max: float = 150.0
export var fire_rate: float = 1.0  # Shots per second
export var projectile_speed: float = 200.0  # 0 = hitscan
export var accuracy: float = 0.9  # Base hit chance at optimal range (0.0 - 1.0)
export var hull_damage_multiplier: float = 1.0
export var armor_damage_multiplier: float = 1.0

# --- Resource Costs ---
export var energy_per_shot: float = 5.0
export var ammo_type: String = ""  # Empty = unlimited/energy-based
export var ammo_per_shot: int = 1

# --- Timing ---
export var cooldown_time: float = 0.0  # Time between shots beyond fire_rate
export var charge_time: float = 0.0  # Time to charge before firing
export var warmup_time: float = 0.0  # Time to spin up

# --- Special Effects ---
export var effect_type: String = ""  # "disable", "grapple", "breach", etc.
export var effect_strength: float = 0.0
export var effect_duration: float = 0.0

# --- Mount Requirements ---
export var mount_size: String = "small"  # "small", "medium", "large", "turret"
export var power_draw: float = 10.0

# --- Visual/Audio ---
export var projectile_scene: String = ""
export var muzzle_effect: String = ""
export var impact_effect: String = ""
export var fire_sound: String = ""


func get_damage_at_range(distance: float) -> float:
	# Damage falls off beyond effective range
	if distance <= range_effective:
		return damage
	elif distance <= range_max:
		var falloff = 1.0 - ((distance - range_effective) / (range_max - range_effective))
		return damage * falloff
	return 0.0


func get_accuracy_at_range(distance: float) -> float:
	# Accuracy decreases at range
	if distance <= range_effective:
		return accuracy
	elif distance <= range_max:
		var falloff = 1.0 - ((distance - range_effective) / (range_max - range_effective)) * 0.5
		return accuracy * falloff
	return 0.0

--- Start of ./src/autoload/Constants.gd ---

# File: autoload/Constants.gd
# Autoload Singleton: Constants
# Version: 1.5 - Updated with new and removed the old.

extends Node

# --- Action Approach Enum ---
enum ActionApproach { CAUTIOUS, RISKY }

# --- Core Mechanics Thresholds ---
# Cautious approach has a wider success band.
const ACTION_CHECK_CRIT_THRESHOLD_CAUTIOUS = 14
const ACTION_CHECK_SWC_THRESHOLD_CAUTIOUS = 10

# Risky approach has a narrower success band but a higher critical chance.
const ACTION_CHECK_CRIT_THRESHOLD_RISKY = 16
const ACTION_CHECK_SWC_THRESHOLD_RISKY = 12

# --- Scene Paths ---
const PLAYER_AGENT_SCENE_PATH = "res://scenes/prefabs/agents/player_agent.tscn"
const NPC_AGENT_SCENE_PATH = "res://scenes/prefabs/agents/npc_agent.tscn"
const INITIAL_ZONE_SCENE_PATH = "res://scenes/levels/zones/zone1/basic_flight_zone.tscn"

# Agent Template Resource Paths
const PLAYER_DEFAULT_TEMPLATE_PATH = "res://database/registry/agents/player_default.tres"
const NPC_TRAFFIC_TEMPLATE_PATH = "res://database/registry/agents/npc_default.tres"
const NPC_HOSTILE_TEMPLATE_PATH = "res://database/registry/agents/npc_hostile_default.tres"

# Base UI Scenes
const MAIN_HUD_SCENE_PATH = "res://scenes/ui/hud/main_hud.tscn"
const MAIN_MENU_SCENE_PATH = "res://scenes/ui/menus/main_menu.tscn"

# --- Common Node Names ---
const CURRENT_ZONE_CONTAINER_NAME = "CurrentZoneContainer"
const AGENT_CONTAINER_NAME = "AgentContainer"
const AGENT_MODEL_CONTAINER_NAME = "Model"
const ENTRY_POINT_NAMES = ["EntryPointA", "EntryPointB", "EntryPointC"] # Placeholders
const AGENT_BODY_NODE_NAME = "AgentBody"
const AI_CONTROLLER_NODE_NAME = "AIController"
const PLAYER_INPUT_HANDLER_NAME = "PlayerInputHandler"

# --- Core Mechanics Parameters ---
const FOCUS_MAX_DEFAULT = 3
const FOCUS_BOOST_PER_POINT = 1
const DEFAULT_UPKEEP_COST = 5

# --- Default Simulation Values ---
const DEFAULT_MAX_MOVE_SPEED = 300.0
const DEFAULT_ACCELERATION = 0.5
const DEFAULT_DECELERATION = 0.5
const DEFAULT_MAX_TURN_SPEED = 0.75
const DEFAULT_ALIGNMENT_ANGLE_THRESHOLD = 45 # Degrees

# Time units to trigger world tick
const TIME_CLOCK_MAX_TU = 60
const TIME_TICK_INTERVAL_SECONDS = 1.0 # How often (in real seconds) to add a Time Unit.

# --- Gameplay / Physics Approximations ---
const ORBIT_FULL_SPEED_RADIUS = 2000.0
const TARGETING_RAY_LENGTH = 1e7

--- Start of ./src/autoload/CoreMechanicsAPI.gd ---

# File: autoload/CoreMechanicsAPI.gd
# Autoload Singleton: CoreMechanicsAPI
# Purpose: Provides globally accessible functions for core mechanic resolutions,
#          ensuring consistency across the game.
# Version: 1.1 - Updated to support ActionApproach and new signature.

extends Node

# Random Number Generator for dice rolls
var _rng = RandomNumberGenerator.new()


func _ready():
	# Seed the random number generator once when the game starts
	_rng.randomize()
	print("CoreMechanicsAPI Ready.")


# --- Core Action Resolution ---


# Performs the standard Action Check.
# - attribute_value: The character's core attribute value (e.g., INT 4).
# - skill_level: The character's relevant skill level (e.g., Computers 2).
# - focus_points_spent: How many FP the player chose to spend (0-3).
# - action_approach: The method used, from Constants.ActionApproach.
# Returns a Dictionary containing the detailed results of the check.
func perform_action_check(
	attribute_value: int, skill_level: int, focus_points_spent: int, action_approach: int
) -> Dictionary:
	# Clamp focus spent to be within a valid range.
	focus_points_spent = clamp(focus_points_spent, 0, Constants.FOCUS_MAX_DEFAULT)

	# --- Determine Thresholds based on Approach ---
	var crit_threshold: int
	var swc_threshold: int  # Success with Complication

	if action_approach == Constants.ActionApproach.RISKY:
		crit_threshold = Constants.ACTION_CHECK_CRIT_THRESHOLD_RISKY
		swc_threshold = Constants.ACTION_CHECK_SWC_THRESHOLD_RISKY
	else:  # Default to CAUTIOUS
		crit_threshold = Constants.ACTION_CHECK_CRIT_THRESHOLD_CAUTIOUS
		swc_threshold = Constants.ACTION_CHECK_SWC_THRESHOLD_CAUTIOUS

	# --- Roll Dice ---
	var d1 = _rng.randi_range(1, 6)
	var d2 = _rng.randi_range(1, 6)
	var d3 = _rng.randi_range(1, 6)
	var dice_sum = d1 + d2 + d3

	# --- Calculate Bonuses & Final Roll ---
	var module_modifier = attribute_value + skill_level
	var focus_bonus = focus_points_spent * Constants.FOCUS_BOOST_PER_POINT
	var total_roll = dice_sum + module_modifier + focus_bonus

	# --- Determine Outcome Tier & Focus Effects ---
	var result_tier: String
	var tier_name: String
	var focus_gain = 0
	var focus_loss_reset = false

	if total_roll >= crit_threshold:
		result_tier = "CritSuccess"
		tier_name = "Critical Success"
		focus_gain = 1
	elif total_roll >= swc_threshold:
		result_tier = "SwC"
		tier_name = "Success with Complication"
	else:
		result_tier = "Failure"
		tier_name = "Failure"
		focus_loss_reset = true

	# --- Assemble Results Dictionary ---
	var results = {
		"roll_total": total_roll,
		"dice_sum": dice_sum,
		"modifier": module_modifier,
		"focus_spent": focus_points_spent,
		"focus_bonus": focus_bonus,
		"result_tier": result_tier,
		"tier_name": tier_name,  # Added for user-facing display
		"focus_gain": focus_gain,
		"focus_loss_reset": focus_loss_reset
	}

	# print("Action Check: %d (3d6=%d, Mod=%d, FP=%d(+%d)) -> %s" % [total_roll, dice_sum, module_modifier, focus_points_spent, focus_bonus, tier_name]) # Debug

	return results

# --- Potential Future Core Mechanic Functions ---

# func update_focus_state(agent_stats_ref, focus_change: int):
#       # Central logic for applying focus gain/loss, respecting cap
#       pass

# func calculate_upkeep_cost(agent_assets_ref):
#       # Central logic for determining periodic WP upkeep cost
#       return 0 # Placeholder WP cost

# func advance_time_clock(agent_stats_ref_or_global, tu_amount: int):
#       # Central logic for adding TU and checking for World Event Tick trigger
#       pass

--- Start of ./src/autoload/EventBus.gd ---

# File: autoload/EventBus.gd
# Version: 1.2 - Added Phase 1 signals for combat, contracts, trading, docking, narrative.

extends Node

# --- Game State Signals ---
signal game_loaded(save_data)
signal game_state_loaded  # Emitted after GameStateManager restores state
# Sprint 10 integration signals
signal new_game_requested
signal main_menu_requested
# signal game_saving(slot_id)
# signal save_complete(slot_id, success)

# --- Agent Lifecycle Signals ---
# Emitted by WorldManager after agent initialized and added to tree
# init_data parameter is now Dictionary {"template": Res, "overrides": Dict}
signal agent_spawned(agent_body, init_data)
# Emitted by Agent's despawn() method via EventBus BEFORE queue_free
signal agent_despawning(agent_body)
# Emitted by AI Controller via EventBus when destination reached
signal agent_reached_destination(agent_body)
# Emitted by WorldManager after player specifically spawned
signal player_spawned(player_agent_body)

# --- Camera Control Signals ---
# Emitted by systems requesting camera target change
signal camera_set_target_requested(target_node)
# Emitted by input handlers requesting target cycle (KEEPING for potential future use)
signal camera_cycle_target_requested

# --- Player Interaction Signals --- ADDED SECTION
signal player_target_selected(target_node)
signal player_target_deselected
signal player_free_flight_toggled
signal player_stop_pressed
signal player_orbit_pressed
signal player_approach_pressed
signal player_flee_pressed
signal player_interact_pressed
signal player_dock_pressed  # Explicit dock button
signal player_attack_pressed  # Explicit attack button
signal player_camera_zoom_changed(value)
signal player_ship_speed_changed(value)
signal player_wp_changed(new_wp_value)
signal player_fp_changed(new_fp_value)

# --- Zone Loading Signals ---
# Emitted by WorldManager before unloading current zone instance
signal zone_unloading(zone_node)  # zone_node is the root of the scene being unloaded
# Emitted by WorldManager when starting to load a new zone path
signal zone_loading(zone_path)  # zone_path is path to the complete zone scene
# Emitted by WorldManager after new zone is instanced, added, container found
# zone_node is root of the new zone instance, agent_container_node is ref inside it
signal zone_loaded(zone_node, zone_path, agent_container_node)

# --- Core Mechanics / Gameplay Events ---
signal world_event_tick_triggered(tu_amount)
signal time_units_added(tu_added)  # Emitted every time TU increments (for UI updates)

# --- Combat Signals ---
signal combat_initiated(player_agent, enemy_agents)
signal combat_ended(result_dict)  # result_dict: {outcome: "victory"/"defeat"/"flee", ...}
signal agent_damaged(agent_body, damage_amount, source_agent)
signal agent_disabled(agent_body)  # When hull <= 0

# --- Contract Signals ---
signal contract_accepted(contract_id)
signal contract_completed(contract_id, success)  # success: bool
signal contract_abandoned(contract_id)
signal contract_failed(contract_id)  # e.g., time limit exceeded

# --- Trading Signals ---
signal trade_transaction_completed(transaction_dict)  # {type, commodity_id, quantity, price, ...}

# --- Docking Signals ---
signal dock_available(location_id)  # Player near dockable station
signal dock_unavailable
signal player_docked(location_id)
signal player_undocked
signal dock_action_feedback(success, message)  # Feedback from dock button press
signal attack_action_feedback(success, message)  # Feedback from attack button press

# --- Narrative Action Signals ---
signal narrative_action_requested(action_type, context)  # Shows Action Check UI
signal narrative_action_resolved(result_dict)  # Contains outcome, effects applied

# --- Goal System Events (Placeholders for Phase 2+) ---
# signal goal_progress_updated(agent_body, goal_id, new_progress)
# signal goal_completed(agent_body, goal_id, success_level)


func _ready():
	print("EventBus Ready.")

--- Start of ./src/autoload/GameState.gd ---

# File: autoload/GameState.gd
# Autoload Singleton: Game state
# Version: 1.1 - Extended with contracts, locations, and narrative state for Phase 1.

extends Node

# Global world seed
var world_seed: String = ""

# Global time counter
var current_tu: int = 0

# --- Character & Asset Instances ---
var characters: Dictionary = {}  # Key: character_uid, Value: CharacterTemplate instance

var active_actions: Dictionary = {}

var assets_ships: Dictionary = {}       # Key: ship_uid, Value: ShipTemplate instance
var assets_modules: Dictionary = {}     # Key: module_uid, Value: ModuleTemplate instance
var assets_commodities: Dictionary = {} # Key: commodity_id, Value: CommodityTemplate (master data)

# Key: Character UID, Value: An Inventory object/dictionary for that character.
var inventories: Dictionary = {}

# Defines which character is controlled by player.
var player_character_uid: int = -1

# Currently loaded zone.
var current_zone_instance: Node = null

# --- Player State ---
var player_docked_at: String = "" # Empty if in space, location_id if docked
var player_position: Vector3 = Vector3.ZERO  # Player position in zone
var player_rotation: Vector3 = Vector3.ZERO  # Player rotation (degrees)


# --- Locations (Stations, Points of Interest) ---
# Key: location_id (String), Value: LocationTemplate instance or Dictionary
var locations: Dictionary = {}

# --- Contract System ---
# Available contracts at locations. Key: contract_id, Value: ContractTemplate instance
var contracts: Dictionary = {}
# Player's accepted contracts. Key: contract_id, Value: Dictionary with progress info
var active_contracts: Dictionary = {}

# --- Narrative State (Player-Centric) ---
var narrative_state: Dictionary = {
	"reputation": 0,           # Overall professional standing (-100 to 100)
	"faction_standings": {},    # Key: faction_id, Value: standing int
	"known_contacts": [],       # Array of contact_ids the player has met
	"chronicle_entries": []     # Log of significant events
}

# --- Session Tracking ---
var session_stats: Dictionary = {
	"contracts_completed": 0,
	"total_wp_earned": 0,
	"total_wp_spent": 0,
	"enemies_disabled": 0,
	"time_played_tu": 0
}

--- Start of ./src/autoload/GameStateManager.gd ---

# File: autoload/GameStateManager.gd
# Autoload Singleton: GameStateManager
# Version: 2.4 - Fixed location serialization (Resources not plain dicts).

extends Node

const SAVE_DIR = "user://savegames/"
const SAVE_FILE_PREFIX = "save_"
const SAVE_FILE_EXT = ".sav"

# Preload the script to safely access its enums without relying on a live node.
const InventorySystem = preload("res://src/core/systems/inventory_system.gd")


# --- Public API ---

func reset_to_defaults() -> void:
	GameState.world_seed = ""
	GameState.current_tu = 0
	GameState.player_character_uid = -1
	GameState.player_docked_at = ""
	GameState.player_position = Vector3.ZERO
	GameState.player_rotation = Vector3.ZERO

	GameState.characters.clear()
	GameState.active_actions.clear()
	GameState.assets_ships.clear()
	GameState.assets_modules.clear()
	GameState.assets_commodities.clear()
	GameState.inventories.clear()
	GameState.locations.clear()
	GameState.contracts.clear()
	GameState.active_contracts.clear()

	GameState.narrative_state = {
		"reputation": 0,
		"faction_standings": {},
		"known_contacts": [],
		"chronicle_entries": []
	}
	GameState.session_stats = {
		"contracts_completed": 0,
		"total_wp_earned": 0,
		"total_wp_spent": 0,
		"enemies_disabled": 0,
		"time_played_tu": 0
	}

func save_game(slot_id: int = 0) -> bool:
	_ensure_save_dir_exists()
	
	# Capture current player position and rotation before serializing
	_capture_player_transform()
	
	var save_data = _serialize_game_state()
	if save_data.empty():
		printerr("GameStateManager Error: Failed to serialize game state.")
		return false

	var file = File.new()
	var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot_id) + SAVE_FILE_EXT
	var err = file.open(path, File.WRITE)

	if err == OK:
		file.store_var(save_data, true)
		file.close()
		print("Game saved successfully to: ", path)
		return true
	else:
		printerr("Error saving game to path: ", path, " Error code: ", err)
		file.close()
		return false


func _capture_player_transform() -> void:
	var player_body = GlobalRefs.player_agent_body
	if is_instance_valid(player_body):
		GameState.player_position = player_body.global_transform.origin
		GameState.player_rotation = player_body.rotation_degrees


func load_game(slot_id: int = 0) -> bool:
	var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot_id) + SAVE_FILE_EXT
	var file = File.new()

	if not file.file_exists(path):
		printerr("Load Error: Save file not found at path: ", path)
		return false

	var err = file.open(path, File.READ)
	if err != OK:
		printerr("Load Error: Failed to open file! Error code: ", err)
		return false

	var save_data = file.get_var(true)
	file.close()

	if not save_data is Dictionary:
		printerr("Load Error: Save data is not a Dictionary.")
		return false
	
	_deserialize_and_apply_game_state(save_data)
	
	EventBus.emit_signal("game_state_loaded")
	print("Game state loaded successfully. Emitted game_state_loaded signal.")
	return true


func has_save_file(slot_id: int = 0) -> bool:
	var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot_id) + SAVE_FILE_EXT
	var file = File.new()
	if not file.file_exists(path):
		return false

	# Treat corrupt/empty saves as non-existent for UI purposes.
	var err = file.open(path, File.READ)
	if err != OK:
		file.close()
		return false
	var save_data = file.get_var(true)
	file.close()
	if not (save_data is Dictionary):
		return false
	return _is_save_data_valid(save_data)


func _is_save_data_valid(save_data: Dictionary) -> bool:
	# Minimal validity checks so we don't offer "Load" when it can't restore a playable state.
	var player_uid := int(save_data.get("player_character_uid", -1))
	if player_uid < 0:
		return false
	var characters = save_data.get("characters", null)
	if not (characters is Dictionary) or characters.empty():
		return false
	var locations = save_data.get("locations", null)
	if not (locations is Dictionary) or locations.empty():
		return false
	return true


func _ensure_save_dir_exists() -> void:
	var dir = Directory.new()
	if not dir.dir_exists(SAVE_DIR):
		var err = dir.make_dir_recursive(SAVE_DIR)
		if err != OK:
			printerr("GameStateManager Error: Could not create save dir: ", SAVE_DIR, " (", err, ")")

# --- Serialization (Live State -> Dictionary) ---

func _serialize_game_state() -> Dictionary:
	var state_dict = {}
	
	state_dict["player_character_uid"] = GameState.player_character_uid
	state_dict["current_tu"] = GameState.current_tu
	state_dict["player_docked_at"] = GameState.player_docked_at
	
	# Save player position and rotation
	state_dict["player_position"] = _serialize_vector3(GameState.player_position)
	state_dict["player_rotation"] = _serialize_vector3(GameState.player_rotation)
	
	state_dict["characters"] = _serialize_resource_dict(GameState.characters)
	state_dict["assets_ships"] = _serialize_resource_dict(GameState.assets_ships)
	state_dict["assets_modules"] = _serialize_resource_dict(GameState.assets_modules)
	state_dict["inventories"] = _serialize_inventories(GameState.inventories)
	
	# Phase 1 additions - locations are Resources, need proper serialization
	state_dict["locations"] = _serialize_resource_dict_by_string_key(GameState.locations)
	state_dict["contracts"] = _serialize_resource_dict_by_string_key(GameState.contracts)
	state_dict["active_contracts"] = _serialize_resource_dict_by_string_key(GameState.active_contracts)
	state_dict["narrative_state"] = GameState.narrative_state.duplicate(true)
	state_dict["session_stats"] = GameState.session_stats.duplicate(true)
	
	return state_dict

func _serialize_resource(res: Resource) -> Dictionary:
	var dict = {}
	if not is_instance_valid(res):
		return dict
		
	dict["template_id"] = res.template_id
	
	for prop in res.get_script().get_script_property_list():
		if prop.usage & PROPERTY_USAGE_STORAGE:
			dict[prop.name] = res.get(prop.name)
			
	return dict

func _serialize_resource_dict(res_dict: Dictionary) -> Dictionary:
	var serialized_dict = {}
	for uid in res_dict:
		serialized_dict[uid] = _serialize_resource(res_dict[uid])
	return serialized_dict

# Same as above but for dictionaries with String keys (like locations)
func _serialize_resource_dict_by_string_key(res_dict: Dictionary) -> Dictionary:
	var serialized_dict = {}
	for key in res_dict:
		var res = res_dict[key]
		if res is Resource:
			serialized_dict[key] = _serialize_resource(res)
		else:
			# Already a plain dict
			serialized_dict[key] = res.duplicate(true) if res is Dictionary else res
	return serialized_dict

func _serialize_inventories(inv_dict: Dictionary) -> Dictionary:
	var serialized_inventories = {}
	for char_uid in inv_dict:
		var original_inv = inv_dict[char_uid]
		serialized_inventories[char_uid] = {
			InventorySystem.InventoryType.SHIP: _serialize_resource_dict(original_inv[InventorySystem.InventoryType.SHIP]),
			InventorySystem.InventoryType.MODULE: _serialize_resource_dict(original_inv[InventorySystem.InventoryType.MODULE]),
			InventorySystem.InventoryType.COMMODITY: original_inv[InventorySystem.InventoryType.COMMODITY].duplicate(true)
		}
	return serialized_inventories

# --- Deserialization (Dictionary -> Live State) ---

func _deserialize_and_apply_game_state(save_data: Dictionary):
	# Clear current state
	GameState.characters.clear()
	GameState.assets_ships.clear()
	GameState.assets_modules.clear()
	GameState.inventories.clear()
	GameState.locations.clear()
	GameState.contracts.clear()
	GameState.active_contracts.clear()
	
	GameState.player_character_uid = save_data.get("player_character_uid", -1)
	GameState.current_tu = save_data.get("current_tu", 0)
	GameState.player_docked_at = save_data.get("player_docked_at", "")
	
	# Restore player position and rotation
	GameState.player_position = _deserialize_vector3(save_data.get("player_position", {}))
	GameState.player_rotation = _deserialize_vector3(save_data.get("player_rotation", {}))

	GameState.assets_ships = _deserialize_resource_dict(save_data.get("assets_ships", {}))
	GameState.assets_modules = _deserialize_resource_dict(save_data.get("assets_modules", {}))
	GameState.characters = _deserialize_resource_dict(save_data.get("characters", {}))
	GameState.inventories = _deserialize_inventories(save_data.get("inventories", {}))
	
	# Phase 1 additions - locations need to be deserialized back to Resources
	GameState.locations = _deserialize_resource_dict_by_string_key(save_data.get("locations", {}))
	GameState.contracts = _deserialize_resource_dict_by_string_key(save_data.get("contracts", {}))
	GameState.active_contracts = _deserialize_resource_dict_by_string_key(save_data.get("active_contracts", {}))
	
	# Restore narrative state with defaults if not present
	var default_narrative = {
		"reputation": 0,
		"faction_standings": {},
		"known_contacts": [],
		"chronicle_entries": []
	}
	var saved_narrative = save_data.get("narrative_state", {})
	for key in default_narrative:
		GameState.narrative_state[key] = saved_narrative.get(key, default_narrative[key])
	
	# Restore session stats with defaults if not present
	var default_stats = {
		"contracts_completed": 0,
		"total_wp_earned": 0,
		"total_wp_spent": 0,
		"enemies_disabled": 0,
		"time_played_tu": 0
	}
	var saved_stats = save_data.get("session_stats", {})
	for key in default_stats:
		GameState.session_stats[key] = saved_stats.get(key, default_stats[key])

func _deserialize_resource(res_data: Dictionary) -> Resource:
	if not res_data.has("template_id"):
		return null
	
	var template_id = res_data["template_id"]
	var template = _find_template_in_database(template_id)
	
	if not is_instance_valid(template):
		printerr("Deserialize Error: Could not find template with id '", template_id, "' in TemplateDatabase.")
		return null
		
	var instance = template.duplicate()
	for key in res_data:
		if key != "template_id":
			instance.set(key, res_data[key])
			
	return instance

func _deserialize_resource_dict(serialized_dict: Dictionary) -> Dictionary:
	var res_dict = {}
	for uid_str in serialized_dict:
		var uid = int(uid_str)
		res_dict[uid] = _deserialize_resource(serialized_dict[uid_str])
	return res_dict

# Same but for string-keyed dicts (like locations)
func _deserialize_resource_dict_by_string_key(serialized_dict: Dictionary) -> Dictionary:
	var res_dict = {}
	for key in serialized_dict:
		var data = serialized_dict[key]
		if data is Dictionary and data.has("template_id"):
			res_dict[key] = _deserialize_resource(data)
		else:
			# Plain dict, just duplicate
			res_dict[key] = data.duplicate(true) if data is Dictionary else data
	return res_dict

func _deserialize_inventories(serialized_inv: Dictionary) -> Dictionary:
	var inv_dict = {}
	for char_uid_str in serialized_inv:
		var char_uid = int(char_uid_str)
		var original_inv = serialized_inv[char_uid_str]
		
		# --- FIX: Use integer enum values directly as keys for lookup ---
		var ship_key = InventorySystem.InventoryType.SHIP
		var module_key = InventorySystem.InventoryType.MODULE
		var commodity_key = InventorySystem.InventoryType.COMMODITY
		
		inv_dict[char_uid] = {
			InventorySystem.InventoryType.SHIP: _deserialize_resource_dict(original_inv.get(ship_key, {})),
			InventorySystem.InventoryType.MODULE: _deserialize_resource_dict(original_inv.get(module_key, {})),
			InventorySystem.InventoryType.COMMODITY: original_inv.get(commodity_key, {}).duplicate(true)
		}
		# --- END FIX ---
	return inv_dict

# Helper to find a template by its ID across all categories in the database.
func _find_template_in_database(template_id: String) -> Resource:
	if TemplateDatabase.characters.has(template_id):
		return TemplateDatabase.characters[template_id]
	if TemplateDatabase.assets_ships.has(template_id):
		return TemplateDatabase.assets_ships[template_id]
	if TemplateDatabase.assets_modules.has(template_id):
		return TemplateDatabase.assets_modules[template_id]
	if TemplateDatabase.locations.has(template_id):
		return TemplateDatabase.locations[template_id]
	if TemplateDatabase.contracts.has(template_id):
		return TemplateDatabase.contracts[template_id]
	# Add other template types here as needed...
	return null


# --- Vector3 Serialization Helpers ---
func _serialize_vector3(vec: Vector3) -> Dictionary:
	return {"x": vec.x, "y": vec.y, "z": vec.z}

func _deserialize_vector3(data) -> Vector3:
	if data is Dictionary:
		return Vector3(
			float(data.get("x", 0.0)),
			float(data.get("y", 0.0)),
			float(data.get("z", 0.0))
		)
	return Vector3.ZERO

--- Start of ./src/autoload/GlobalRefs.gd ---

# File: core/autoload/global_refs.gd
# Autoload Singleton: GlobalRefs
# Purpose: Holds easily accessible references to unique global nodes/managers.
# Nodes register themselves here via setter functions during their _ready() phase.
# Version: 1.1

extends Node

# --- Key Node & UI References ---
# Other scripts access these directly (e.g., GlobalRefs.player_agent_body)
# but should ALWAYS check if is_instance_valid() first!

var player_agent_body = null setget set_player_agent_body
var main_camera = null setget set_main_camera
var world_manager = null setget set_world_manager
var current_zone = null setget set_current_zone
var agent_container = null setget set_agent_container
var game_state_manager = null setget set_game_state_manager

# --- UI elements ---
var main_hud = null setget set_main_hud
var character_status = null setget set_character_status
var inventory_screen = null setget set_inventory_screen

# --- Core System References ---
var action_system = null setget set_action_system
var agent_spawner = null setget set_agent_spawner
var asset_system = null setget set_asset_system
var character_system = null setget set_character_system
var chronicle_system = null setget set_chronicle_system
var goal_system = null setget set_goal_system
var inventory_system = null setget set_inventory_system
var progression_system = null setget set_progression_system
var time_system = null setget set_time_system
var traffic_system = null setget set_traffic_system
var world_map_system = null setget set_world_map_system
var event_system = null setget set_event_system
var trading_system = null setget set_trading_system
var contract_system = null setget set_contract_system
var narrative_action_system = null setget set_narrative_action_system
var combat_system = null setget set_combat_system


func _ready():
	print("GlobalRefs Ready.")
	# This script is a passive container; references are set by other nodes.


# --- Setters (Provide controlled way to update references & add validation) ---

func set_player_agent_body(new_ref):
	if new_ref == player_agent_body: return
	if new_ref == null or is_instance_valid(new_ref):
		player_agent_body = new_ref
		print("GlobalRefs: Player Agent ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Player Agent ref: ", new_ref)

func set_main_camera(new_ref):
	if new_ref == main_camera: return
	if new_ref == null or is_instance_valid(new_ref):
		main_camera = new_ref
		print("GlobalRefs: Main Camera ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid Main Camera ref: ", new_ref)

func set_world_manager(new_ref):
	if new_ref == world_manager: return
	if new_ref == null or is_instance_valid(new_ref):
		world_manager = new_ref
		print("GlobalRefs: World Manager ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid World Manager ref: ", new_ref)

func set_current_zone(new_ref):
	if new_ref == current_zone: return
	if new_ref == null or is_instance_valid(new_ref):
		current_zone = new_ref
		print("GlobalRefs: Current Zone ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Current Zone ref: ", new_ref)

func set_agent_container(new_ref):
	if new_ref == agent_container: return
	if new_ref == null or is_instance_valid(new_ref):
		agent_container = new_ref
		print("GlobalRefs: Agent Container ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Agent Container ref: ", new_ref)

func set_game_state_manager(new_ref):
	if new_ref == game_state_manager: return
	if new_ref == null or is_instance_valid(new_ref):
		game_state_manager = new_ref
		print("GlobalRefs: GameStateManager ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid GameStateManager ref: ", new_ref)

# --- System Setters ---

func set_action_system(new_ref):
	if new_ref == action_system: return
	if new_ref == null or is_instance_valid(new_ref):
		action_system = new_ref
		print("GlobalRefs: ActionSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid ActionSystem ref: ", new_ref)

func set_agent_spawner(new_ref):
	if new_ref == agent_spawner: return
	if new_ref == null or is_instance_valid(new_ref):
		agent_spawner = new_ref
		print("GlobalRefs: AgentSpawner ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid AgentSpawner ref: ", new_ref)

func set_asset_system(new_ref):
	if new_ref == asset_system: return
	if new_ref == null or is_instance_valid(new_ref):
		asset_system = new_ref
		print("GlobalRefs: AssetSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid AssetSystem ref: ", new_ref)

func set_character_system(new_ref):
	if new_ref == character_system: return
	if new_ref == null or is_instance_valid(new_ref):
		character_system = new_ref
		print("GlobalRefs: CharacterSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid CharacterSystem ref: ", new_ref)

func set_chronicle_system(new_ref):
	if new_ref == chronicle_system: return
	if new_ref == null or is_instance_valid(new_ref):
		chronicle_system = new_ref
		print("GlobalRefs: ChronicleSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid ChronicleSystem ref: ", new_ref)

func set_goal_system(new_ref):
	if new_ref == goal_system: return
	if new_ref == null or is_instance_valid(new_ref):
		goal_system = new_ref
		print("GlobalRefs: GoalSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid GoalSystem ref: ", new_ref)

func set_inventory_system(new_ref):
	if new_ref == inventory_system: return
	if new_ref == null or is_instance_valid(new_ref):
		inventory_system = new_ref
		print("GlobalRefs: InventorySystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid InventorySystem ref: ", new_ref)

func set_progression_system(new_ref):
	if new_ref == progression_system: return
	if new_ref == null or is_instance_valid(new_ref):
		progression_system = new_ref
		print("GlobalRefs: ProgressionSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid ProgressionSystem ref: ", new_ref)

func set_time_system(new_ref):
	if new_ref == time_system: return
	if new_ref == null or is_instance_valid(new_ref):
		time_system = new_ref
		print("GlobalRefs: TimeSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid TimeSystem ref: ", new_ref)

func set_traffic_system(new_ref):
	if new_ref == traffic_system: return
	if new_ref == null or is_instance_valid(new_ref):
		traffic_system = new_ref
		print("GlobalRefs: TrafficSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid TrafficSystem ref: ", new_ref)

func set_world_map_system(new_ref):
	if new_ref == world_map_system: return
	if new_ref == null or is_instance_valid(new_ref):
		world_map_system = new_ref
		print("GlobalRefs: WorldMapSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid WorldMapSystem ref: ", new_ref)

func set_event_system(new_ref):
	if new_ref == event_system: return
	if new_ref == null or is_instance_valid(new_ref):
		event_system = new_ref
		print("GlobalRefs: EventSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid EventSystem ref: ", new_ref)

func set_trading_system(new_ref):
	if new_ref == trading_system: return
	if new_ref == null or is_instance_valid(new_ref):
		trading_system = new_ref
		print("GlobalRefs: TradingSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid TradingSystem ref: ", new_ref)

func set_contract_system(new_ref):
	if new_ref == contract_system: return
	if new_ref == null or is_instance_valid(new_ref):
		contract_system = new_ref
		print("GlobalRefs: ContractSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid ContractSystem ref: ", new_ref)


func set_narrative_action_system(new_ref):
	if new_ref == narrative_action_system: return
	if new_ref == null or is_instance_valid(new_ref):
		narrative_action_system = new_ref
		print("GlobalRefs: NarrativeActionSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid NarrativeActionSystem ref: ", new_ref)

func set_combat_system(new_ref):
	if new_ref == combat_system: return
	if new_ref == null or is_instance_valid(new_ref):
		combat_system = new_ref
		print("GlobalRefs: CombatSystem ref ", "set." if new_ref else "cleared.")
	else:
		printerr("GlobalRefs Error: Invalid CombatSystem ref: ", new_ref)


# --- UI ELEMENTS ---

func set_main_hud(new_ref):
	if new_ref == main_hud: return
	if new_ref == null or is_instance_valid(new_ref):
		main_hud = new_ref
		print("GlobalRefs: Main HUD UI ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Main HUD UI ref: ", new_ref)
		
func set_character_status(new_ref):
	if new_ref == character_status: return
	if new_ref == null or is_instance_valid(new_ref):
		character_status = new_ref
		print("GlobalRefs: Character Status UI window ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Character Status UI window ref: ", new_ref)

func set_inventory_screen(new_ref):
	if new_ref == inventory_screen: return
	if new_ref == null or is_instance_valid(new_ref):
		inventory_screen = new_ref
		print("GlobalRefs: Inventory Screen UI window ref set to ", new_ref.name if new_ref else "null")
	else:
		printerr("GlobalRefs Error: Invalid Inventory Screen UI window ref: ", new_ref)

--- Start of ./src/autoload/NarrativeOutcomes.gd ---

# File: autoload/NarrativeOutcomes.gd
# Autoload Singleton: NarrativeOutcomes
# Purpose: Centralized narrative outcome lookup tables for Narrative Actions.
# Version: 1.0

extends Node

# Outcome structure per action_type + tier
# Returns: {description: String, effects: Dictionary}
# effects keys: "add_quirk", "wp_cost", "wp_gain", "fp_gain", "reputation_change"

const OUTCOMES: Dictionary = {
	"contract_complete": {
		"CritSuccess": {
			"description": "Flawless delivery - client impressed.",
			"effects": {"wp_gain": 5, "reputation_change": 1}
		},
		"SwC": {
			"description": "Delivery complete with minor issues.",
			"effects": {}
		},
		"Failure": {
			"description": "Cargo damaged in transit.",
			"effects": {"wp_cost": 10, "add_quirk": "reputation_tarnished"}
		}
	},

	"dock_arrival": {
		"CritSuccess": {
			"description": "Perfect approach and docking. Your handling inspires confidence.",
			"effects": {"fp_gain": 1, "reputation_change": 1}
		},
		"SwC": {
			"description": "Docking successful, but you scrape the hull on the way in.",
			"effects": {"add_quirk": "scratched_hull"}
		},
		"Failure": {
			"description": "Rough landing. Repairs and paperwork cost you.",
			"effects": {"wp_cost": 2, "add_quirk": "jammed_landing_gear"}
		}
	},

	"trade_finalize": {
		"CritSuccess": {
			"description": "You spot a favorable clause and close the deal above market.",
			"effects": {"wp_gain": 2}
		},
		"SwC": {
			"description": "Deal goes through, but the station broker takes a cut.",
			"effects": {"wp_cost": 1}
		},
		"Failure": {
			"description": "You misread the market and take a loss finalizing the trade.",
			"effects": {"wp_cost": 3}
		}
	}
}


func get_outcome(action_type: String, tier_name: String) -> Dictionary:
	var normalized_tier = _normalize_tier_name(tier_name)
	var action_table = OUTCOMES.get(action_type, null)
	if action_table == null:
		return {"description": "No outcome defined.", "effects": {}}
	var outcome = action_table.get(normalized_tier, null)
	if outcome == null:
		return {"description": "No outcome defined.", "effects": {}}
	# Return a deep copy so callers can safely modify.
	return outcome.duplicate(true)


func get_available_action_types() -> Array:
	var keys = OUTCOMES.keys()
	keys.sort()
	return keys


func _normalize_tier_name(tier_name: String) -> String:
	# Supports both CoreMechanicsAPI keys (result_tier) and display strings (tier_name).
	match tier_name:
		"CritSuccess", "Critical Success":
			return "CritSuccess"
		"SwC", "Success with Complication":
			return "SwC"
		"Failure":
			return "Failure"
		_:
			# Best-effort: pass through; may already be correct.
			return tier_name

--- Start of ./src/autoload/TemplateDatabase.gd ---

# File: autoload/TemplateDatabase.gd
# Autoload Singleton: Scanned templates from /data/ are indexed and stored here
# Version: 1.3 - Added utility_tools dictionary and get_template method

extends Node

# Dictionaries to hold loaded templates, keyed by their template_id.
var actions: Dictionary = {}
var agents: Dictionary = {}
var characters: Dictionary = {}
var assets_ships: Dictionary = {}
var assets_modules: Dictionary = {}
var assets_commodities: Dictionary = {}
var locations: Dictionary = {}
var contracts: Dictionary = {}
var utility_tools: Dictionary = {}  # Weapons and other utility tools


# Generic getter that searches all template categories
func get_template(template_id: String) -> Resource:
	if characters.has(template_id):
		return characters[template_id]
	if assets_ships.has(template_id):
		return assets_ships[template_id]
	if assets_modules.has(template_id):
		return assets_modules[template_id]
	if assets_commodities.has(template_id):
		return assets_commodities[template_id]
	if locations.has(template_id):
		return locations[template_id]
	if contracts.has(template_id):
		return contracts[template_id]
	if utility_tools.has(template_id):
		return utility_tools[template_id]
	if agents.has(template_id):
		return agents[template_id]
	if actions.has(template_id):
		return actions[template_id]
	return null

--- Start of ./src/core/agents/agent.gd ---

# File: res://core/agents/agent.gd (Attached to AgentBody KinematicBody)
# Version: 3.40 - Ship stats now loaded from ShipTemplate via AssetSystem.

# Agent - this is a physical space vessel that exists in simulation space (ship).

extends KinematicBody

# --- Core State & Identity ---
var agent_type: String = ""
var template_id: String = ""
var agent_uid = -1
var character_uid: int = -1  # Links this agent to a character in GameState
var interaction_radius: float = 15.0
var is_hostile: bool = false  # True if this is a hostile NPC
var ship_template = null  # Cached ship template for combat registration

func is_player() -> bool:
	return character_uid == GameState.player_character_uid and character_uid != -1

# --- Physics State ---
var current_velocity: Vector3 = Vector3.ZERO

# --- Component References ---
var movement_system: Node = null
var navigation_system: Node = null


# --- Initialization ---
# Called externally (e.g., by WorldManager) after instancing and adding to tree
func initialize(template: AgentTemplate, overrides: Dictionary = {}, p_agent_uid: int = -1):
	if not template is AgentTemplate:
		printerr("AgentBody Initialize Error: Invalid template for ", self.name)
		return

	self.template_id = overrides.get("template_id")
	self.agent_type = overrides.get("agent_type")
	self.agent_uid = p_agent_uid
	self.character_uid = overrides.get("character_uid", -1)
	self.is_hostile = overrides.get("hostile", false)
	
	if is_player():
		print("AgentBody initialized as PLAYER. UID: ", self.agent_uid, " CharUID: ", self.character_uid)
	else:
		print("AgentBody initialized as NPC. UID: ", self.agent_uid, " CharUID: ", self.character_uid, " Hostile: ", self.is_hostile)

	movement_system = get_node_or_null("MovementSystem")
	navigation_system = get_node_or_null("NavigationSystem")

	if not is_instance_valid(movement_system) or not is_instance_valid(navigation_system):
		printerr(
			"AgentBody Initialize Error: Failed to get required component nodes for '",
			self.name,
			"'."
		)
		set_physics_process(false)
		return

	# Get movement parameters from the character's active ship
	var move_params = _get_movement_params_from_ship()
	var nav_params = {
		"orbit_kp": overrides.get("orbit_kp", 3.0),
		"orbit_ki": overrides.get("orbit_ki", 0.1),
		"orbit_kd": overrides.get("orbit_kd", 0.5)
	}

	movement_system.initialize_movement_params(move_params)
	navigation_system.initialize_navigation(nav_params, movement_system)
	
	# Register with combat system if we have a ship template
	# Defer to ensure CombatSystem is initialized in the scene tree.
	call_deferred("_register_with_combat_system")

	print(
		"AgentBody '",
		self.name,
		"' initialized with character_uid=",
		self.character_uid,
		" using template '",
		self.template_id,
		"'."
	)


# Retrieves movement parameters from the character's active ship template.
# Falls back to Constants defaults if ship data is unavailable.
# Also caches the ship_template for combat registration.
func _get_movement_params_from_ship() -> Dictionary:
	ship_template = null
	
	# Try to get ship via AssetSystem if character_uid is valid
	if character_uid != -1 and is_instance_valid(GlobalRefs.asset_system):
		ship_template = GlobalRefs.asset_system.get_ship_for_character(character_uid)
	
	# For hostile NPCs without character, load the default hostile ship
	if not is_instance_valid(ship_template) and is_hostile:
		ship_template = load("res://database/registry/assets/ships/ship_hostile_default.tres")
	
	if is_instance_valid(ship_template):
		interaction_radius = ship_template.interaction_radius
		return {
			"max_move_speed": ship_template.max_move_speed,
			"acceleration": ship_template.acceleration,
			"deceleration": ship_template.deceleration,
			"max_turn_speed": ship_template.max_turn_speed,
			"brake_strength": ship_template.deceleration,
			"alignment_threshold_angle_deg": ship_template.alignment_threshold_angle_deg
		}
	else:
		# Fallback to Constants defaults if no ship found (normal for hostile NPCs)
		if character_uid >= 0:
			printerr("AgentBody: No ship found for character_uid=", character_uid, ", using defaults.")
		return {
			"max_move_speed": Constants.DEFAULT_MAX_MOVE_SPEED,
			"acceleration": Constants.DEFAULT_ACCELERATION,
			"deceleration": Constants.DEFAULT_DECELERATION,
			"max_turn_speed": Constants.DEFAULT_MAX_TURN_SPEED,
			"brake_strength": Constants.DEFAULT_DECELERATION,
			"alignment_threshold_angle_deg": Constants.DEFAULT_ALIGNMENT_ANGLE_THRESHOLD
		}


# Registers this agent with the combat system using its ship template.
func _register_with_combat_system() -> void:
	if not is_instance_valid(GlobalRefs.combat_system):
		return
	if agent_uid < 0:
		return
	if not is_instance_valid(ship_template):
		return
	
	GlobalRefs.combat_system.register_combatant(agent_uid, ship_template)
	print("AgentBody '", self.name, "' registered with CombatSystem. Hull: ", ship_template.hull_integrity)


# --- Godot Lifecycle ---
func _ready():
	add_to_group("Agents")
	set_physics_process(true)


func _physics_process(delta: float):
	if not is_instance_valid(navigation_system) or not is_instance_valid(movement_system):
		if delta > 0:
			printerr("AgentBody _physics_process Error: Components invalid for '", self.name, "'!")
		set_physics_process(false)
		return

	if delta <= 0.0001:
		return

	# 1. Update Navigation & Movement Logic
	navigation_system.update_navigation(delta)

	# 2. Smoothly enforce the current speed limit before moving.
	movement_system.enforce_speed_limit(delta)

	# 3. Apply Physics Engine Movement
	current_velocity = move_and_slide(current_velocity, Vector3.UP)

	# 4. Apply Post-Movement Corrections (e.g., PID for orbit)
	navigation_system.apply_orbit_pid_correction(delta)


# --- Public Command API (Delegates to NavigationSystem) ---
func command_stop():
	if is_instance_valid(navigation_system):
		navigation_system.set_command_stopping()
	else:
		printerr("AgentBody: Cannot command_stop - NavigationSystem invalid.")


func command_move_to(position: Vector3):
	if is_instance_valid(navigation_system):
		navigation_system.set_command_move_to(position)
	else:
		printerr("AgentBody: Cannot command_move_to - NavigationSystem invalid.")


func command_move_direction(direction: Vector3):
	if is_instance_valid(navigation_system):
		navigation_system.set_command_move_direction(direction)
	else:
		printerr("AgentBody: Cannot command_move_direction - NavigationSystem invalid.")


func command_approach(target: Spatial):
	if is_instance_valid(navigation_system):
		navigation_system.set_command_approach(target)
	else:
		printerr("AgentBody: Cannot command_approach - NavigationSystem invalid.")


# MODIFIED: This function now captures the ship's current distance to the target
# as the desired orbit distance, preventing the navigation system from
# immediately trying to correct to a different, pre-calculated minimum.
func command_orbit(target: Spatial):
	if not is_instance_valid(target):
		printerr("AgentBody: command_orbit - Invalid target node provided.")
		if is_instance_valid(navigation_system):
			navigation_system.set_command_stopping()
		return

	if is_instance_valid(navigation_system):
		var vec_to_target_local = to_local(target.global_transform.origin)
		var orbit_clockwise = vec_to_target_local.x > 0.01

		# Always capture the current distance. The NavigationSystem will handle
		# gently pushing the agent out if this distance is too close.
		var captured_orbit_dist = global_transform.origin.distance_to(
			target.global_transform.origin
		)

		navigation_system.set_command_orbit(target, captured_orbit_dist, orbit_clockwise)
	else:
		printerr("AgentBody: Cannot command_orbit - NavigationSystem invalid.")


func command_flee(target: Spatial):
	if is_instance_valid(navigation_system):
		navigation_system.set_command_flee(target)
	else:
		printerr("AgentBody: Cannot command_flee - NavigationSystem invalid.")


func command_align_to(direction: Vector3):
	if is_instance_valid(navigation_system):
		navigation_system.set_command_align_to(direction)
	else:
		printerr("AgentBody: Cannot command_align_to - NavigationSystem invalid.")


# --- Public Getters ---
func get_interaction_radius() -> float:
	return interaction_radius


# --- Despawn ---
func despawn():
	print("AgentBody '", self.name, "' despawning...")
	EventBus.emit_signal("agent_despawning", self)
	set_physics_process(false)
	call_deferred("queue_free")

--- Start of ./src/core/agents/components/movement_system.gd ---

# File: res://core/agents/components/movement_system.gd
# Version: 1.4 - Added smooth deceleration when max_move_speed is lowered.
# Purpose: Handles the low-level execution of agent movement and rotation physics.
# Called by NavigationSystem.

extends Node

# --- Movement Capabilities (Set by AgentBody during initialize) ---
var max_move_speed: float = Constants.DEFAULT_MAX_MOVE_SPEED
var acceleration: float = Constants.DEFAULT_ACCELERATION
var deceleration: float = Constants.DEFAULT_DECELERATION
var brake_strength: float = Constants.DEFAULT_DECELERATION
var max_turn_speed: float = Constants.DEFAULT_MAX_TURN_SPEED
var alignment_threshold_angle_deg: float = 45.0
var _alignment_threshold_rad: float = deg2rad(alignment_threshold_angle_deg)

# --- Angular Velocity & Damping ---
var angular_velocity := Vector3.ZERO
var turn_damping := 5.0

# Reference to the parent AgentBody KinematicBody
var agent_body: KinematicBody = null


func _ready():
	agent_body = get_parent()
	if not agent_body is KinematicBody:
		printerr("MovementSystem Error: Parent is not a KinematicBody!")
		agent_body = null
		set_process(false)


func initialize_movement_params(params: Dictionary):
	max_move_speed = params.get("max_move_speed", max_move_speed)
	acceleration = params.get("acceleration", acceleration)
	deceleration = params.get("deceleration", deceleration)
	brake_strength = params.get("brake_strength", deceleration)
	max_turn_speed = params.get("max_turn_speed", max_turn_speed)
	alignment_threshold_angle_deg = params.get(
		"alignment_threshold_angle_deg", alignment_threshold_angle_deg
	)
	_alignment_threshold_rad = deg2rad(alignment_threshold_angle_deg)
	print(
		(
			"MovementSystem Initialized: Speed=%.1f, Accel=%.1f, Decel=%.1f, Turn=%.1f, Align=%.1f"
			% [
				max_move_speed,
				acceleration,
				deceleration,
				max_turn_speed,
				alignment_threshold_angle_deg
			]
		)
	)


# --- Public Methods Called by NavigationSystem & AgentBody ---


# Applies acceleration towards max_move_speed ONLY if aligned within threshold.
func apply_acceleration(target_direction: Vector3, delta: float):
	if not is_instance_valid(agent_body):
		return

	if target_direction.length_squared() < 0.001:
		apply_deceleration(delta)
		return

	var target_dir_norm = target_direction.normalized()
	var current_forward = -agent_body.global_transform.basis.z.normalized()
	var angle = current_forward.angle_to(target_dir_norm)

	if angle <= _alignment_threshold_rad:
		var target_velocity = target_dir_norm * max_move_speed
		agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
			target_velocity, acceleration * delta
		)
	else:
		# If not aligned, we just decelerate naturally instead of accelerating.
		apply_deceleration(delta)


# Applies natural deceleration (drag).
func apply_deceleration(delta: float):
	if not is_instance_valid(agent_body):
		return
	# We only apply natural deceleration if we are NOT over the speed limit.
	# If we are over, enforce_speed_limit() will handle the deceleration.
	if agent_body.current_velocity.length_squared() <= max_move_speed * max_move_speed:
		agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
			Vector3.ZERO, deceleration * delta
		)


# Applies active braking force.
func apply_braking(delta: float) -> bool:
	if not is_instance_valid(agent_body):
		return true
	agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
		Vector3.ZERO, brake_strength * delta
	)
	return agent_body.current_velocity.length_squared() < 0.5


# Handles rotation and calculates resulting angular velocity.
func apply_rotation(target_look_dir: Vector3, delta: float):
	if not is_instance_valid(agent_body):
		return

	var basis_before_rotation = agent_body.global_transform.basis

	if target_look_dir.length_squared() < 0.001:
		angular_velocity = Vector3.ZERO
		return

	var target_dir = target_look_dir.normalized()
	var current_basis = basis_before_rotation.orthonormalized()

	var up_vector = Vector3.UP
	if abs(target_dir.dot(Vector3.UP)) > 0.999:
		up_vector = Vector3.FORWARD

	var target_basis = Transform(Basis(), Vector3.ZERO).looking_at(target_dir, up_vector).basis.orthonormalized()

	if current_basis.is_equal_approx(target_basis):
		angular_velocity = Vector3.ZERO
		return

	var new_basis: Basis
	if max_turn_speed > 0.001:
		var turn_step = max_turn_speed * delta
		new_basis = current_basis.slerp(target_basis, turn_step)
	else:
		new_basis = target_basis

	agent_body.global_transform.basis = new_basis

	var rotation_diff_basis = new_basis * basis_before_rotation.inverse()
	var rotation_diff_quat = Quat(rotation_diff_basis)

	var angle = 2 * acos(rotation_diff_quat.w)
	var axis: Vector3
	var sin_half_angle = sin(angle / 2)

	if sin_half_angle > 0.0001:
		axis = (
			Vector3(rotation_diff_quat.x, rotation_diff_quat.y, rotation_diff_quat.z)
			/ sin_half_angle
		)
	else:
		axis = Vector3.UP

	if delta > 0.0001:
		angular_velocity = axis * (angle / delta)
	else:
		angular_velocity = Vector3.ZERO


# Smoothly dampens rotation to a stop.
func damp_rotation(delta: float):
	if not is_instance_valid(agent_body):
		return

	if angular_velocity.length_squared() > 0.0001:
		var rotation_axis = angular_velocity.normalized()
		var rotation_angle = angular_velocity.length() * delta
		agent_body.rotate(rotation_axis, rotation_angle)

		angular_velocity = angular_velocity.linear_interpolate(Vector3.ZERO, turn_damping * delta)


# NEW: Smoothly reduces speed if current velocity is over the max_move_speed limit.
func enforce_speed_limit(delta: float):
	if not is_instance_valid(agent_body):
		return

	var current_speed_sq = agent_body.current_velocity.length_squared()
	var max_speed_sq = max_move_speed * max_move_speed

	if current_speed_sq > max_speed_sq:
		# We are over the speed limit. Smoothly decelerate to the new cap.
		var direction = agent_body.current_velocity.normalized()
		var target_velocity = direction * max_move_speed

		# Use the existing deceleration property for a consistent feel.
		agent_body.current_velocity = agent_body.current_velocity.linear_interpolate(
			target_velocity, deceleration * delta
		)

--- Start of ./src/core/agents/components/navigation_system/command_align_to.gd ---

# File: core/agents/components/navigation_system/command_align_to.gd
extends Node

var _nav_sys: Node
var _agent_body: KinematicBody
var _movement_system: Node


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if is_instance_valid(_movement_system) and is_instance_valid(_agent_body):
		var target_dir = _nav_sys._current_command.target_dir
		_movement_system.apply_rotation(target_dir, delta)
		_movement_system.apply_deceleration(delta)
		var current_fwd = -_agent_body.global_transform.basis.z
		if current_fwd.dot(target_dir) > 0.999:
			_nav_sys.set_command_idle()

--- Start of ./src/core/agents/components/navigation_system/command_approach.gd ---

# File: core/agents/components/navigation_system/command_approach.gd
extends Node

var _nav_sys: Node
var _agent_body: KinematicBody
var _movement_system: Node
var _pid: PIDController


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system
	_pid = nav_system._pid_approach


func execute(delta: float):
	if not is_instance_valid(_pid):
		return

	var cmd = _nav_sys._current_command
	var target_node = cmd.target_node
	var target_pos = target_node.global_transform.origin
	var target_size = _nav_sys._get_target_effective_size(target_node)
	var desired_stop_dist = max(
		_nav_sys.APPROACH_MIN_DISTANCE, target_size * _nav_sys.APPROACH_DISTANCE_MULTIPLIER
	)

	var vector_to_target = target_pos - _agent_body.global_transform.origin
	var distance = vector_to_target.length()

	if distance < (desired_stop_dist + _nav_sys.ARRIVAL_DISTANCE_THRESHOLD):
		if not cmd.get("signaled_stop", false):
			EventBus.emit_signal("agent_reached_destination", _agent_body)
			cmd["signaled_stop"] = true
		_nav_sys.set_command_idle()
		_movement_system.apply_braking(delta)
		return

	var direction = vector_to_target.normalized() if distance > 0.01 else Vector3.ZERO
	_movement_system.apply_rotation(direction, delta)

	var deceleration_start_dist = (
		desired_stop_dist
		* _nav_sys.APPROACH_DECELERATION_START_DISTANCE_FACTOR
	)
	var target_velocity: Vector3

	if distance > deceleration_start_dist:
		target_velocity = direction * _movement_system.max_move_speed
		_pid.reset()
		cmd["signaled_stop"] = false
	else:
		var distance_error = distance - desired_stop_dist
		var pid_target_speed = _pid.update(distance_error, delta)
		pid_target_speed = clamp(
			pid_target_speed,
			-_movement_system.max_move_speed * 0.1,
			_movement_system.max_move_speed
		)
		target_velocity = direction * pid_target_speed

		if (
			abs(distance_error) < _nav_sys.ARRIVAL_DISTANCE_THRESHOLD
			and _agent_body.current_velocity.length_squared() < _nav_sys.ARRIVAL_SPEED_THRESHOLD_SQ
		):
			if not cmd.get("signaled_stop", false):
				EventBus.emit_signal("agent_reached_destination", _agent_body)
				cmd["signaled_stop"] = true
			_movement_system.apply_braking(delta)
			return
		else:
			cmd["signaled_stop"] = false

	_agent_body.current_velocity = _agent_body.current_velocity.linear_interpolate(
		target_velocity, _movement_system.acceleration * delta
	)

--- Start of ./src/core/agents/components/navigation_system/command_flee.gd ---

# File: core/agents/components/navigation_system/command_flee.gd
extends Node

var _nav_sys: Node
var _agent_body: KinematicBody
var _movement_system: Node


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if is_instance_valid(_movement_system) and is_instance_valid(_agent_body):
		var target_pos = _nav_sys._current_command.target_node.global_transform.origin
		var vector_away = _agent_body.global_transform.origin - target_pos
		var direction_away = (
			vector_away.normalized()
			if vector_away.length_squared() > 0.01
			else -_agent_body.global_transform.basis.z
		)
		_movement_system.apply_rotation(direction_away, delta)
		_movement_system.apply_acceleration(direction_away, delta)

--- Start of ./src/core/agents/components/navigation_system/command_idle.gd ---

# File: core/agents/components/navigation_system/command_idle.gd
extends Node

var _movement_system: Node


func initialize(nav_system):
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if is_instance_valid(_movement_system):
		_movement_system.apply_deceleration(delta)

--- Start of ./src/core/agents/components/navigation_system/command_move_direction.gd ---

# File: core/agents/components/navigation_system/command_move_direction.gd
extends Node

var _nav_sys: Node
var _movement_system: Node


func initialize(nav_system):
	_nav_sys = nav_system
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if is_instance_valid(_movement_system):
		var move_dir = _nav_sys._current_command.get("target_dir", Vector3.ZERO)
		if move_dir.length_squared() > 0.001:
			_movement_system.apply_rotation(move_dir, delta)
			_movement_system.apply_acceleration(move_dir, delta)
		else:
			_movement_system.apply_deceleration(delta)

--- Start of ./src/core/agents/components/navigation_system/command_move_to.gd ---

# File: core/agents/components/navigation_system/command_move_to.gd
extends Node

var _nav_sys: Node
var _agent_body: KinematicBody
var _movement_system: Node
var _pid: PIDController


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system
	_pid = nav_system._pid_move_to


func execute(delta: float):
	if not is_instance_valid(_pid):
		return

	var cmd = _nav_sys._current_command
	var target_pos = cmd.target_pos
	var vector_to_target = target_pos - _agent_body.global_transform.origin
	var distance = vector_to_target.length()

	var pid_target_speed = _pid.update(distance, delta)
	pid_target_speed = clamp(pid_target_speed, 0, _movement_system.max_move_speed)

	var direction = vector_to_target.normalized() if distance > 0.01 else Vector3.ZERO
	_movement_system.apply_rotation(direction, delta)

	var target_velocity = direction * pid_target_speed
	_agent_body.current_velocity = _agent_body.current_velocity.linear_interpolate(
		target_velocity, _movement_system.acceleration * delta
	)

	if (
		distance < _nav_sys.ARRIVAL_DISTANCE_THRESHOLD
		and _agent_body.current_velocity.length_squared() < _nav_sys.ARRIVAL_SPEED_THRESHOLD_SQ
	):
		if not cmd.get("signaled_stop", false):
			EventBus.emit_signal("agent_reached_destination", _agent_body)
			cmd["signaled_stop"] = true
		_movement_system.apply_braking(delta)
	else:
		cmd["signaled_stop"] = false

--- Start of ./src/core/agents/components/navigation_system/command_orbit.gd ---

# File: core/agents/components/navigation_system/command_orbit.gd
# Version: 1.4 - Added dynamic speed calculation for the spiral-out phase.
extends Node

var _nav_sys: Node
var _agent_body: KinematicBody
var _movement_system: Node

const SPIRAL_OUTWARD_FACTOR = 0.3
const ORBITAL_VELOCITY_LERP_WEIGHT = 2.5

var _current_orbital_velocity: Vector3 = Vector3.ZERO


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if not is_instance_valid(_movement_system) or not is_instance_valid(_agent_body):
		return

	var cmd = _nav_sys._current_command
	var target_node = cmd.target_node
	var target_pos = target_node.global_transform.origin
	var clockwise = cmd.get("clockwise", false)

	if cmd.get("is_new", false):
		_current_orbital_velocity = _agent_body.current_velocity
		cmd["is_new"] = false

	# --- Vector Calculations ---
	var vector_to_target = target_pos - _agent_body.global_transform.origin
	var distance = vector_to_target.length()
	if distance < 0.01:
		distance = 0.01
	var direction_to_target = vector_to_target / distance
	var tangent_dir = (direction_to_target.cross(Vector3.UP) if not clockwise else Vector3.UP.cross(direction_to_target)).normalized()

	# --- Determine Movement Direction & Ideal Speed ---
	var safe_dist = (
		_nav_sys._get_target_effective_size(target_node)
		* _nav_sys.CLOSE_ORBIT_DISTANCE_THRESHOLD_FACTOR
	)
	var ideal_move_dir: Vector3
	var speed_calc_dist: float  # The distance to use for speed calculation

	if distance < safe_dist:
		# TOO CLOSE: Spiral out and use CURRENT distance for speed calculation.
		var radial_dir_outward = -direction_to_target
		ideal_move_dir = (tangent_dir + radial_dir_outward * SPIRAL_OUTWARD_FACTOR).normalized()
		speed_calc_dist = distance  # Use current, closer distance for a slower speed.
	else:
		# SAFE DISTANCE: Normal orbit and use DESIRED distance for speed calculation.
		ideal_move_dir = tangent_dir
		speed_calc_dist = cmd.get("distance", 100.0)  # Use final, desired distance.

	# Calculate the ideal speed based on the appropriate distance (current or desired).
	var full_speed_radius = max(1.0, Constants.ORBIT_FULL_SPEED_RADIUS)
	var ideal_speed = _movement_system.max_move_speed
	if speed_calc_dist > 0 and speed_calc_dist < full_speed_radius:
		ideal_speed *= (speed_calc_dist / full_speed_radius)
	ideal_speed = clamp(ideal_speed, 0.0, _movement_system.max_move_speed)

	var ideal_orbital_velocity = ideal_move_dir * ideal_speed

	# --- Smoothly Transition & Apply ---
	_current_orbital_velocity = _current_orbital_velocity.linear_interpolate(
		ideal_orbital_velocity, ORBITAL_VELOCITY_LERP_WEIGHT * delta
	)

	_movement_system.apply_rotation(tangent_dir, delta)
	_agent_body.current_velocity = _current_orbital_velocity

--- Start of ./src/core/agents/components/navigation_system/command_stop.gd ---

# File: core/agents/components/navigation_system/command_stop.gd
# Version: 1.1 - Added call to damp_rotation for smooth rotational stops.
extends Node

var _nav_sys: Node
var _agent_body: KinematicBody
var _movement_system: Node


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if is_instance_valid(_movement_system) and is_instance_valid(_agent_body):
		# --- Dampen linear motion ---
		var stopped_moving = _movement_system.apply_braking(delta)

		# --- NEW: Dampen angular motion ---
		_movement_system.damp_rotation(delta)

		# Check if linear motion has stopped before signaling completion
		if stopped_moving and not _nav_sys._current_command.get("signaled_stop", false):
			EventBus.emit_signal("agent_reached_destination", _agent_body)
			_nav_sys._current_command["signaled_stop"] = true

--- Start of ./src/core/agents/components/navigation_system.gd ---

# File: res://core/agents/components/navigation_system.gd
# Version: 2.1 - Added 'is_new' flag to orbit command for stateful initialization.

extends Node

# --- Enums and Constants ---
enum CommandType { IDLE, STOPPING, MOVE_TO, MOVE_DIRECTION, APPROACH, ORBIT, FLEE, ALIGN_TO }
const APPROACH_DISTANCE_MULTIPLIER = 1.3
const APPROACH_MIN_DISTANCE = 50.0
const APPROACH_DECELERATION_START_DISTANCE_FACTOR = 50.0
const ARRIVAL_DISTANCE_THRESHOLD = 5.0
const ARRIVAL_SPEED_THRESHOLD_SQ = 1.0
const CLOSE_ORBIT_DISTANCE_THRESHOLD_FACTOR = 1.5

# --- References ---
var agent_body: KinematicBody = null
var movement_system: Node = null

# --- State ---
var _current_command = {}

# --- Child Components ---
var _pid_orbit: PIDController = null
var _pid_approach: PIDController = null
var _pid_move_to: PIDController = null
var _command_handlers = {}
const PIDControllerScript = preload("res://src/core/utils/pid_controller.gd")


# --- Initialization ---
func _ready():
	if not _current_command:
		set_command_idle()


func initialize_navigation(nav_params: Dictionary, move_sys_ref: Node):
	movement_system = move_sys_ref
	agent_body = get_parent()

	if not is_instance_valid(agent_body) or not is_instance_valid(movement_system):
		printerr("NavigationSystem Error: Invalid parent or movement system reference!")
		set_process(false)
		return

	_initialize_pids(nav_params)
	_initialize_command_handlers()

	print("NavigationSystem Initialized.")
	set_command_idle()


func _initialize_pids(nav_params: Dictionary):
	if not PIDControllerScript:
		printerr("NavigationSystem Error: Failed to load PIDController script!")
		return

	_pid_orbit = PIDControllerScript.new()
	_pid_approach = PIDControllerScript.new()
	_pid_move_to = PIDControllerScript.new()

	add_child(_pid_orbit)
	add_child(_pid_approach)
	add_child(_pid_move_to)

	var o_limit = movement_system.max_move_speed
	_pid_orbit.initialize(
		nav_params.get("orbit_kp", 0.5),
		nav_params.get("orbit_ki", 0.001),
		nav_params.get("orbit_kd", 1.0),
		1000.0,
		75.0
	)
	_pid_approach.initialize(
		nav_params.get("approach_kp", 0.5),
		nav_params.get("approach_ki", 0.001),
		nav_params.get("approach_kd", 1.0),
		1000.0,
		o_limit
	)
	_pid_move_to.initialize(
		nav_params.get("move_to_kp", 0.5),
		nav_params.get("move_to_ki", 0.001),
		nav_params.get("move_to_kd", 1.0),
		1000.0,
		o_limit
	)


func _initialize_command_handlers():
	var command_path = "res://src/core/agents/components/navigation_system/"
	_command_handlers = {
		CommandType.IDLE: load(command_path + "command_idle.gd").new(),
		CommandType.STOPPING: load(command_path + "command_stop.gd").new(),
		CommandType.MOVE_TO: load(command_path + "command_move_to.gd").new(),
		CommandType.MOVE_DIRECTION: load(command_path + "command_move_direction.gd").new(),
		CommandType.APPROACH: load(command_path + "command_approach.gd").new(),
		CommandType.ORBIT: load(command_path + "command_orbit.gd").new(),
		CommandType.FLEE: load(command_path + "command_flee.gd").new(),
		CommandType.ALIGN_TO: load(command_path + "command_align_to.gd").new(),
	}

	for handler_script in _command_handlers.values():
		add_child(handler_script)
		if handler_script.has_method("initialize"):
			handler_script.initialize(self)


# --- Public Command Setting Methods ---
func set_command_idle():
	_current_command = {"type": CommandType.IDLE}


func set_command_stopping():
	_current_command = {"type": CommandType.STOPPING}
	if is_instance_valid(_pid_orbit):
		_pid_orbit.reset()
	if is_instance_valid(_pid_approach):
		_pid_approach.reset()
	if is_instance_valid(_pid_move_to):
		_pid_move_to.reset()


func set_command_move_to(position: Vector3):
	_current_command = {"type": CommandType.MOVE_TO, "target_pos": position}
	if is_instance_valid(_pid_orbit):
		_pid_orbit.reset()
	if is_instance_valid(_pid_approach):
		_pid_approach.reset()
	if is_instance_valid(_pid_move_to):
		_pid_move_to.reset()


func set_command_move_direction(direction: Vector3):
	if direction.length_squared() < 0.001:
		set_command_stopping()
		return
	_current_command = {"type": CommandType.MOVE_DIRECTION, "target_dir": direction.normalized()}


func set_command_approach(target: Spatial):
	if not is_instance_valid(target):
		set_command_stopping()
		return
	_current_command = {"type": CommandType.APPROACH, "target_node": target}
	if is_instance_valid(_pid_orbit):
		_pid_orbit.reset()
	if is_instance_valid(_pid_approach):
		_pid_approach.reset()
	if is_instance_valid(_pid_move_to):
		_pid_move_to.reset()


# MODIFIED: Added "is_new" flag to signal the command handler to initialize its state.
func set_command_orbit(target: Spatial, distance: float, clockwise: bool):
	if not is_instance_valid(target):
		set_command_stopping()
		return
	_current_command = {
		"type": CommandType.ORBIT,
		"target_node": target,
		"distance": distance,
		"clockwise": clockwise,
		"is_new": true  # Flag for one-time setup in the command handler
	}
	if is_instance_valid(_pid_orbit):
		_pid_orbit.reset()
	if is_instance_valid(_pid_approach):
		_pid_approach.reset()
	if is_instance_valid(_pid_move_to):
		_pid_move_to.reset()


func set_command_flee(target: Spatial):
	if not is_instance_valid(target):
		set_command_stopping()
		return
	_current_command = {"type": CommandType.FLEE, "target_node": target}


func set_command_align_to(direction: Vector3):
	if direction.length_squared() < 0.001:
		set_command_idle()
		return
	_current_command = {"type": CommandType.ALIGN_TO, "target_dir": direction.normalized()}


# --- Main Update Logic ---
func update_navigation(delta: float):
	if not is_instance_valid(agent_body) or not is_instance_valid(movement_system):
		return

	var cmd_type = _current_command.get("type", CommandType.IDLE)
	var target_node = _current_command.get("target_node", null)

	var is_target_cmd = cmd_type in [CommandType.APPROACH, CommandType.ORBIT, CommandType.FLEE]
	if is_target_cmd and not is_instance_valid(target_node):
		set_command_stopping()
		cmd_type = CommandType.STOPPING

	if _command_handlers.has(cmd_type):
		var handler = _command_handlers[cmd_type]
		if handler.has_method("execute"):
			handler.execute(delta)
	else:
		_command_handlers[CommandType.IDLE].execute(delta)


# --- PID Correction & Helper Functions ---
func apply_orbit_pid_correction(delta: float):
	if _current_command.get("type") != CommandType.ORBIT:
		return
	if (
		not is_instance_valid(agent_body)
		or not is_instance_valid(movement_system)
		or not is_instance_valid(_pid_orbit)
	):
		return

	var target_node = _current_command.get("target_node", null)
	if is_instance_valid(target_node):
		var desired_orbit_dist = _current_command.get("distance", 100.0)
		var vector_to_target = (
			target_node.global_transform.origin
			- agent_body.global_transform.origin
		)
		var current_distance = vector_to_target.length()
		if current_distance < 0.01:
			return

		var distance_error = current_distance - desired_orbit_dist
		var pid_output = _pid_orbit.update(distance_error, delta)

		var close_orbit_threshold = APPROACH_MIN_DISTANCE * CLOSE_ORBIT_DISTANCE_THRESHOLD_FACTOR
		if distance_error < 0 and desired_orbit_dist < close_orbit_threshold:
			var max_outward_push_speed = movement_system.max_move_speed * 0.05
			pid_output = max(pid_output, -max_outward_push_speed)

		var radial_direction = vector_to_target.normalized()
		var velocity_correction = radial_direction * pid_output
		agent_body.current_velocity += velocity_correction


func _get_target_effective_size(target_node: Spatial) -> float:
	var calculated_size = 1.0
	var default_radius = 10.0

	if not is_instance_valid(target_node):
		return default_radius

	if target_node.has_method("get_interaction_radius"):
		var explicit_radius = target_node.get_interaction_radius()
		if (explicit_radius is float or explicit_radius is int) and explicit_radius > 0:
			return max(float(explicit_radius), 1.0)

	var model_node = target_node.get_node_or_null("Model")
	if is_instance_valid(model_node) and model_node is Spatial:
		var combined_aabb: AABB = AABB()
		var first_visual_found = false
		for child in model_node.get_children():
			if child is VisualInstance:
				var child_global_aabb = child.get_transformed_aabb()
				if not first_visual_found:
					combined_aabb = child_global_aabb
					first_visual_found = true
				else:
					combined_aabb = combined_aabb.merge(child_global_aabb)

		if first_visual_found:
			var longest_axis_size = combined_aabb.get_longest_axis_size()
			calculated_size = longest_axis_size / 2.0
			if calculated_size > 0.01:
				return max(calculated_size, 1.0)

	var node_scale = target_node.global_transform.basis.get_scale()
	calculated_size = max(node_scale.x, max(node_scale.y, node_scale.z)) / 2.0
	if calculated_size <= 0.01:
		return default_radius

	return max(calculated_size, 1.0)

--- Start of ./src/core/agents/components/weapon_controller.gd ---

# File: core/agents/components/weapon_controller.gd
# Purpose: Manages weapon firing and cooldowns for an agent.
# Attaches as child of AgentBody (KinematicBody).
extends Node

const UtilityToolTemplate = preload("res://database/definitions/utility_tool_template.gd")

signal weapon_fired(weapon_index, target_position)
signal weapon_cooldown_started(weapon_index, duration)
signal weapon_ready(weapon_index)

# --- References (set in _ready) ---
var _agent_body: KinematicBody = null  # Parent AgentBody
var _ship_template = null  # Linked ShipTemplate (via AssetSystem)
var _weapons: Array = []  # Loaded UtilityToolTemplate instances
var _cooldowns: Dictionary = {}  # weapon_index -> remaining_time


# --- Initialization ---
func _ready() -> void:
	_agent_body = get_parent()
	if not _agent_body is KinematicBody:
		printerr("WeaponController: Parent must be KinematicBody")
		return
	# Defer weapon loading to allow agent initialization to complete first
	call_deferred("_load_weapons_from_ship")


func _load_weapons_from_ship() -> void:
	# Get character_uid from agent, then ship from AssetSystem
	var char_uid: int = -1
	var raw_char_uid = _agent_body.get("character_uid")
	if raw_char_uid != null:
		char_uid = int(raw_char_uid)
	
	# First try to get ship from character
	if char_uid >= 0 and is_instance_valid(GlobalRefs.asset_system):
		_ship_template = GlobalRefs.asset_system.get_ship_for_character(char_uid)
	
	# If no ship via character, try to get cached ship_template from agent body (for hostile NPCs)
	if not is_instance_valid(_ship_template):
		var agent_ship = _agent_body.get("ship_template")
		if is_instance_valid(agent_ship):
			_ship_template = agent_ship
	
	if not is_instance_valid(_ship_template):
		print("WeaponController: No ship template available for agent, cannot load weapons.")
		return  # No ship available

	# Load each equipped tool template
	var equipped_list = _ship_template.get("equipped_tools")
	if equipped_list == null:
		equipped_list = _ship_template.get("equipped_weapons")
	if equipped_list == null:
		equipped_list = []

	for tool_id in equipped_list:
		var tool_template = null
		if TemplateDatabase and TemplateDatabase.has_method("get_template"):
			tool_template = TemplateDatabase.callv("get_template", [tool_id])

		if tool_template and tool_template.get("tool_type") == "weapon":
			_weapons.append(tool_template)
			_cooldowns[_weapons.size() - 1] = 0.0
	
	if _weapons.size() > 0:
		print("WeaponController: Loaded ", _weapons.size(), " weapon(s) for agent")
	else:
		# Helpful during manual integration verification.
		print(
			"WeaponController: No weapons loaded for agent_uid=",
			_agent_body.get("agent_uid"),
			" ship=",
			_ship_template.get("template_id"),
			" equipped_weapons=",
			_ship_template.get("equipped_weapons"),
			" equipped_tools=",
			_ship_template.get("equipped_tools")
		)


func _physics_process(delta: float) -> void:
	# Keep CombatSystem cooldowns ticking (CombatSystem stores cooldowns per combatant).
	if is_instance_valid(GlobalRefs.combat_system) and GlobalRefs.combat_system.has_method("update_cooldowns"):
		GlobalRefs.combat_system.update_cooldowns(delta)

	# Update local cooldown timers.
	for idx in _cooldowns.keys():
		if _cooldowns[idx] > 0:
			_cooldowns[idx] -= delta
			if _cooldowns[idx] <= 0:
				_cooldowns[idx] = 0
				emit_signal("weapon_ready", idx)


# --- Public API ---

func get_weapon_count() -> int:
	return _weapons.size()


func get_weapon(index: int) -> Resource:
	if index >= 0 and index < _weapons.size():
		return _weapons[index]
	return null


func is_weapon_ready(index: int) -> bool:
	return _cooldowns.get(index, 0.0) <= 0.0


func get_cooldown_remaining(index: int) -> float:
	return _cooldowns.get(index, 0.0)


func fire_at_target(weapon_index: int, target_uid: int, target_position: Vector3) -> Dictionary:
	if weapon_index < 0 or weapon_index >= _weapons.size():
		return {"success": false, "reason": "Invalid weapon index"}

	if not is_weapon_ready(weapon_index):
		return {"success": false, "reason": "Weapon on cooldown", "cooldown": _cooldowns[weapon_index]}

	var weapon = _weapons[weapon_index]
	var shooter_uid: int = int(_agent_body.get("agent_uid"))
	var shooter_pos: Vector3 = _agent_body.global_transform.origin

	if not is_instance_valid(GlobalRefs.combat_system):
		return {"success": false, "reason": "CombatSystem unavailable"}

	# Ensure both combatants registered
	_ensure_combatant_registered(shooter_uid)
	_ensure_combatant_registered(target_uid)

	# Fire via CombatSystem
	var result = GlobalRefs.combat_system.fire_weapon(
		shooter_uid,
		target_uid,
		weapon,
		shooter_pos,
		target_position
	)

	if result.get("success", false):
		# Start cooldown
		var cooldown_seconds: float = 0.0
		if weapon and weapon is UtilityToolTemplate:
			var fire_rate: float = float(max(weapon.fire_rate, 0.0001))
			cooldown_seconds = (1.0 / fire_rate) + float(weapon.cooldown_time)
		_cooldowns[weapon_index] = cooldown_seconds
		emit_signal("weapon_cooldown_started", weapon_index, cooldown_seconds)
		emit_signal("weapon_fired", weapon_index, target_position)

	return result


func _ensure_combatant_registered(uid: int) -> void:
	if not is_instance_valid(GlobalRefs.combat_system):
		return
	# Don't confuse "in combat" (alive/active) with "registered" (has hull state).
	# We need registration even when combat hasn't started yet.
	if GlobalRefs.combat_system.has_method("get_combat_state"):
		var existing_state: Dictionary = GlobalRefs.combat_system.get_combat_state(uid)
		if not existing_state.empty():
			return
	else:
		# Fallback for older CombatSystem API.
		if GlobalRefs.combat_system.is_in_combat(uid):
			return

	var ship = null

	# Prefer current ship if this is the local agent.
	if _agent_body and int(_agent_body.get("agent_uid")) == uid and is_instance_valid(_ship_template):
		ship = _ship_template

	# Resolve uid -> AgentBody and use its cached ship_template.
	if not is_instance_valid(ship):
		var agent_body = null
		if is_instance_valid(GlobalRefs.world_manager) and GlobalRefs.world_manager.has_method("get_agent_by_uid"):
			agent_body = GlobalRefs.world_manager.get_agent_by_uid(uid)

		if not is_instance_valid(agent_body):
			var tree = get_tree()
			if tree:
				for node in tree.get_nodes_in_group("Agents"):
					if (
						is_instance_valid(node)
						and node.get("agent_uid") != null
						and int(node.get("agent_uid")) == uid
					):
						agent_body = node
						break

		if is_instance_valid(agent_body):
			var cached_ship = agent_body.get("ship_template")
			if is_instance_valid(cached_ship):
				ship = cached_ship
			else:
				# If this body has a character_uid, use AssetSystem mapping.
				var raw_char_uid = agent_body.get("character_uid")
				if raw_char_uid != null and int(raw_char_uid) >= 0 and is_instance_valid(GlobalRefs.asset_system):
					ship = GlobalRefs.asset_system.get_ship_for_character(int(raw_char_uid))

	# Try to interpret uid as character_uid.
	if not is_instance_valid(ship) and is_instance_valid(GlobalRefs.asset_system):
		ship = GlobalRefs.asset_system.get_ship_for_character(uid)

	# Fallback: interpret uid as ship_uid.
	if not is_instance_valid(ship) and is_instance_valid(GlobalRefs.asset_system):
		ship = GlobalRefs.asset_system.get_ship(uid)

	if is_instance_valid(ship):
		GlobalRefs.combat_system.register_combatant(uid, ship)

--- Start of ./src/core/systems/action_system.gd ---

# File: core/systems/action_system.gd
# Purpose: Manages the queueing, execution, and completion of character actions.
# Version: 2.0 - Reworked to match new templates.

extends Node

# Emitted when an action is completed, broadcasting the result.
# payload: The result dictionary from CoreMechanicsAPI.perform_action_check().
signal action_completed(character, action_resource, payload)

var _next_action_id: int = 1

func _ready():
	GlobalRefs.set_action_system(self)
	
	if not EventBus.is_connected("world_event_tick_triggered", self, "_on_world_event_tick"):
		EventBus.connect("world_event_tick_triggered", self, "_on_world_event_tick")
	print("ActionSystem Ready.")


# --- Public API ---

# Queues an action for a character.
# - action_approach: From Constants.ActionApproach (e.g., CAUTIOUS, RISKY).
func request_action(
	character_instance: CharacterTemplate, action_template: ActionTemplate, action_approach: int, target: Node = null
) -> bool:
	if not is_instance_valid(character_instance) or not action_template:
		return false

	var action_id = _get_new_action_id()

	GameState.active_actions[action_id] = {
		"character_instance": character_instance, 
		"action_template": action_template,
		"action_approach": action_approach,  # Store the approach for later.
		"target": target,
		"tu_progress": 0,
		"tu_cost": action_template.tu_cost
	}

	var approach_str = (
		"Cautious"
		if action_approach == Constants.ActionApproach.CAUTIOUS
		else "Risky"
	)
	print(
		(
			"ActionSystem: Queued action '%s' for %s (Approach: %s)"
			% [action_template.action_name, character_instance.character_name, approach_str]
		)
	)

	return true


# --- Signal Handlers ---
func _on_world_event_tick(tu_passed: int):
	for action_id in GameState.active_actions.keys().duplicate():
		var action = GameState.active_actions[action_id]
		action.tu_progress += tu_passed

		if action.tu_progress >= action.tu_cost:
			_process_action_completion(action_id)


# --- Private Logic ---
func _process_action_completion(action_id: int):
	if not GameState.active_actions.has(action_id):
		return

	var action_data = GameState.active_actions[action_id]
	var character_instance = action_data.character_instance
	var action_template = action_data.action_template
	var action_approach = action_data.action_approach

	# Perform the action check to get the result.
	# For now, we assume dummy values for attribute/skill levels.
	# A real implementation would get these from the character object.
	var character_attribute_value = 4  # Dummy value
	var character_skill_level = 2  # Dummy value
	var focus_spent = 0  # Dummy value

	var result_payload = CoreMechanicsAPI.perform_action_check(
		character_attribute_value, character_skill_level, focus_spent, action_approach
	)

	print(
		(
			"ActionSystem: Completed action '%s'. Result: %s"
			% [action_template.action_name, result_payload.tier_name]
		)
	)

	# Emit the signal with all relevant data.
	emit_signal("action_completed", character_instance, action_template, result_payload)

	GameState.active_actions.erase(action_id)


func _get_new_action_id() -> int:
	var id = _next_action_id
	_next_action_id += 1
	return id

--- Start of ./src/core/systems/agent_system.gd ---

# File: core/systems/agent_system.gd
# Purpose: Manages agent spawning in virtual space (ships). Assembles agents from
# character data and their inventory of assets.
# Version: 2.1 - Added character_uid linking for ship stats integration.

extends Node

var _player_agent_body: KinematicBody = null
var _next_agent_uid: int = 0  # Counter for generating unique agent UIDs


func _ready():
	GlobalRefs.set_agent_spawner(self)
	
	# Listen for the zone_loaded signal to know when it's safe to spawn.
	EventBus.connect("zone_loaded", self, "_on_Zone_Loaded")
	print("AgentSpawner Ready.")


func _on_Zone_Loaded(_zone_instance, _zone_path, agent_container_node):
	if is_instance_valid(agent_container_node):
		if not is_instance_valid(_player_agent_body):
			spawn_player()
	else:
		printerr("AgentSpawner Error: Agent container invalid. Cannot spawn agents.")


# Important: player's character and inventory of assets must exist and upon spawining an
# agent they should get linked to it.
func spawn_player():
	var container = GlobalRefs.agent_container
	if not is_instance_valid(container):
		printerr("AgentSpawner Error: GlobalRefs.agent_container invalid.")
		return

	var player_template = load(Constants.PLAYER_DEFAULT_TEMPLATE_PATH)
	if not player_template is AgentTemplate:
		printerr("AgentSpawner Error: Failed to load Player AgentTemplate.")
		return

	var player_spawn_pos = Vector3.ZERO
	var player_spawn_rot = Vector3.ZERO
	
	# Priority 1: Use saved position if it's not zero (loaded game)
	if GameState.player_position != Vector3.ZERO:
		player_spawn_pos = GameState.player_position
		player_spawn_rot = GameState.player_rotation
	# Priority 2: If docked, spawn at station
	elif GameState.player_docked_at != "":
		var dock_pos = _get_dock_position_in_zone(GameState.player_docked_at)
		if dock_pos != null:
			player_spawn_pos = dock_pos + Vector3(0, 5, 15)
	# Priority 3: Use zone entry point (new game)
	elif is_instance_valid(GlobalRefs.current_zone):
		var entry_node = null
		if Constants.ENTRY_POINT_NAMES.size() > 0:
			entry_node = GlobalRefs.current_zone.find_node(
				Constants.ENTRY_POINT_NAMES[0], true, false
			)
		if entry_node is Spatial:
			player_spawn_pos = entry_node.global_transform.origin + Vector3(0, 5, 15)

	# Get the player character UID from GameState
	var player_char_uid = GameState.player_character_uid
	
	# Overrides include agent_type, template_id, and character_uid for ship stats lookup
	var player_overrides = {
		"agent_type": "player", 
		"template_id": "player",
		"character_uid": player_char_uid
	}
	var agent_uid = _get_next_agent_uid()
	
	_player_agent_body = spawn_agent(
		Constants.PLAYER_AGENT_SCENE_PATH, player_spawn_pos, player_template, player_overrides, agent_uid
	)

	if is_instance_valid(_player_agent_body):
		# Apply saved rotation if available
		if player_spawn_rot != Vector3.ZERO:
			_player_agent_body.rotation_degrees = player_spawn_rot
		
		GlobalRefs.player_agent_body = _player_agent_body
		EventBus.emit_signal("camera_set_target_requested", _player_agent_body)
		EventBus.emit_signal("player_spawned", _player_agent_body)
	else:
		printerr("AgentSpawner Error: Failed to spawn player agent body!")


func _get_dock_position_in_zone(location_id: String):
	# Prefer the actual station instance position in the current zone.
	if location_id == "":
		return null
	if is_instance_valid(GlobalRefs.current_zone):
		var stations = get_tree().get_nodes_in_group("dockable_station")
		for station in stations:
			if not is_instance_valid(station):
				continue
			if not (station is Spatial):
				continue
			# Ensure this station belongs to the currently loaded zone.
			if not GlobalRefs.current_zone.is_a_parent_of(station):
				continue
			if station.get("location_id") == location_id:
				return station.global_transform.origin

	# Fallback: use template data if present.
	if GameState.locations.has(location_id):
		var loc = GameState.locations[location_id]
		if loc is Resource and loc.get("position_in_zone") is Vector3:
			return loc.position_in_zone
		if loc is Dictionary and loc.get("position_in_zone") is Vector3:
			return loc["position_in_zone"]

	return null


# Spawns an NPC agent linked to a specific character.
# character_uid: The UID of the character this NPC represents.
func spawn_npc(character_uid: int, position: Vector3 = Vector3.ZERO) -> KinematicBody:
	if not GameState.characters.has(character_uid):
		printerr("AgentSpawner Error: No character found with UID: ", character_uid)
		return null
	
	var npc_template = load(Constants.NPC_TRAFFIC_TEMPLATE_PATH)
	if not npc_template is AgentTemplate:
		printerr("AgentSpawner Error: Failed to load NPC AgentTemplate.")
		return null
	
	var npc_overrides = {
		"agent_type": "npc",
		"template_id": "npc_default",
		"character_uid": character_uid
	}
	var agent_uid = _get_next_agent_uid()
	
	var npc_body = spawn_agent(
		Constants.NPC_AGENT_SCENE_PATH, position, npc_template, npc_overrides, agent_uid
	)
	
	return npc_body


# Spawns an NPC using a specific AgentTemplate resource path.
# This is used for encounter-driven spawns where a fixed template is desired.
func spawn_npc_from_template(agent_template_path: String, position: Vector3 = Vector3.ZERO, overrides: Dictionary = {}) -> KinematicBody:
	if not agent_template_path or agent_template_path.empty():
		printerr("AgentSpawner Error: spawn_npc_from_template invalid template path.")
		return null

	var npc_template = load(agent_template_path)
	if not npc_template is AgentTemplate:
		printerr("AgentSpawner Error: Failed to load AgentTemplate at: ", agent_template_path)
		return null

	var npc_overrides := overrides.duplicate(true)
	if not npc_overrides.has("agent_type"):
		npc_overrides["agent_type"] = "npc"
	if not npc_overrides.has("template_id"):
		npc_overrides["template_id"] = "npc"
	if not npc_overrides.has("character_uid"):
		npc_overrides["character_uid"] = -1

	var agent_uid = _get_next_agent_uid()
	return spawn_agent(Constants.NPC_AGENT_SCENE_PATH, position, npc_template, npc_overrides, agent_uid)


# --- UID Generation ---
func _get_next_agent_uid() -> int:
	var uid = _next_agent_uid
	_next_agent_uid += 1
	return uid


# TODO: spawn NPC with proper overrides.
# Important: NPC's characters and their inventories of assets must exist and upon spawining an
# agent they should get linked to it.

func spawn_agent(
	agent_scene_path: String,
	position: Vector3,
	agent_template: AgentTemplate,
	overrides: Dictionary = {},
	agent_uid: int = -1
) -> KinematicBody:
	var container = GlobalRefs.agent_container
	if not is_instance_valid(container):
		printerr("AgentSpawner Spawn Error: Invalid GlobalRefs.agent_container.")
		return null
	if not agent_template is AgentTemplate:
		printerr("AgentSpawner Spawn Error: Invalid AgentTemplate Resource.")
		return null

	var agent_scene = load(agent_scene_path)
	if not agent_scene:
		printerr("AgentSpawner Spawn Error: Failed to load agent scene: ", agent_scene_path)
		return null

	var agent_root_instance = agent_scene.instance()
	# agent_node is the "AgentBody" KinematicBody within the scene instance
	var agent_node = agent_root_instance.get_node_or_null(Constants.AGENT_BODY_NODE_NAME)

	if not (agent_node and agent_node is KinematicBody):
		printerr("AgentSpawner Spawn Error: Invalid agent body node in scene: ", agent_scene_path)
		agent_root_instance.queue_free()
		return null

	var instance_name = agent_template.agent_type + "_" + str(agent_root_instance.get_instance_id())
	
	agent_root_instance.name = instance_name

	container.add_child(agent_root_instance)
	agent_node.global_transform.origin = position

	if agent_node.has_method("initialize"):
		agent_node.initialize(agent_template, overrides, agent_uid)

	EventBus.emit_signal(
		"agent_spawned", agent_node, {"template": agent_template, "overrides": overrides, "agent_uid": agent_uid}
	)

	# The controller is a child of the AgentBody (agent_node), not the scene root.
	# We also need to check for both AI and Player controllers.
	var ai_controller = agent_node.get_node_or_null(Constants.AI_CONTROLLER_NODE_NAME)
	var _player_controller = agent_node.get_node_or_null(Constants.PLAYER_INPUT_HANDLER_NAME)

	if ai_controller and ai_controller.has_method("initialize"):
		ai_controller.initialize(overrides) # Pass agent_uid?
	# The PlayerInputHandler does not have an initialize method, so we don't need to call it,
	# but by getting a reference to it, we ensure the test framework is aware of it.

	return agent_node

--- Start of ./src/core/systems/asset_system.gd ---

# File: core/systems/asset_system.gd
# Purpose: Provides a logical API for accessing asset data stored in GameState.
# This system is STATELESS. All data is read from the GameState autoload.
# Version: 3.1 - Added get_ship_for_character() helper.

extends Node

func _ready():
	GlobalRefs.set_asset_system(self)
	print("AssetSystem Ready.")


# --- Public API ---


func get_ship(ship_uid: int) -> ShipTemplate:
	return GameState.assets_ships.get(ship_uid)


# Convenience function to get the player's currently active ship.
func get_player_ship() -> ShipTemplate:
	var player_char = GlobalRefs.character_system.get_player_character()
	if not is_instance_valid(player_char):
		return null

	if player_char.active_ship_uid != -1:
		return get_ship(player_char.active_ship_uid)

	return null


# Gets the active ship for any character by their UID.
func get_ship_for_character(character_uid: int) -> ShipTemplate:
	if not GameState.characters.has(character_uid):
		return null
	
	var character = GameState.characters[character_uid]
	if not is_instance_valid(character):
		return null
	
	if character.active_ship_uid != -1:
		return get_ship(character.active_ship_uid)
	
	return null


# Gets all ships owned by a character (from their inventory).
func get_ships_for_character(character_uid: int) -> Array:
	var ships = []
	if not is_instance_valid(GlobalRefs.inventory_system):
		return ships
	
	var ship_inventory = GlobalRefs.inventory_system.get_inventory_by_type(
		character_uid, 
		GlobalRefs.inventory_system.InventoryType.SHIP
	)
	
	for ship_uid in ship_inventory.keys():
		var ship = get_ship(ship_uid)
		if is_instance_valid(ship):
			ships.append(ship)
	
	return ships

--- Start of ./src/core/systems/character_system.gd ---

# File: core/systems/character_system.gd
# Purpose: Provides a logical API for manipulating character data stored in GameState.
# This system is STATELESS. All data is read from and written to the GameState autoload.
# Version: 3.1 - Integrated character screen UI signals.

extends Node


func _ready():
	GlobalRefs.set_character_system(self)
	print("CharacterSystem Ready.")


# --- Public API ---


# Retrieves a character instance from the GameState.
func get_character(character_uid: int) -> CharacterTemplate:
	return GameState.characters.get(character_uid)


# Convenience function to get the player's character instance.
func get_player_character() -> CharacterTemplate:
	if GameState.player_character_uid != -1:
		return GameState.characters.get(GameState.player_character_uid)
	return null


# Convenience function to get the player's UID.
func get_player_character_uid() -> int:
	return GameState.player_character_uid


# --- Stat Modification API (Operates on GameState) ---


func add_wp(character_uid: int, amount: int):
	if GameState.characters.has(character_uid):
		GameState.characters[character_uid].wealth_points += amount
		# If this change was for the player, announce it.
		if character_uid == GameState.player_character_uid:
			EventBus.emit_signal("player_wp_changed", GameState.characters[character_uid].wealth_points)


func subtract_wp(character_uid: int, amount: int):
	if GameState.characters.has(character_uid):
		GameState.characters[character_uid].wealth_points -= amount
		# If this change was for the player, announce it.
		if character_uid == GameState.player_character_uid:
			EventBus.emit_signal("player_wp_changed", GameState.characters[character_uid].wealth_points)


func get_wp(character_uid: int) -> int:
	if GameState.characters.has(character_uid):
		return GameState.characters[character_uid].wealth_points
	return 0


func add_fp(character_uid: int, amount: int):
	if GameState.characters.has(character_uid):
		var character = GameState.characters[character_uid]
		character.focus_points += amount
		character.focus_points = clamp(character.focus_points, 0, Constants.FOCUS_MAX_DEFAULT)
		# If this change was for the player, announce it.
		if character_uid == GameState.player_character_uid:
			EventBus.emit_signal("player_fp_changed", character.focus_points)


func subtract_fp(character_uid: int, amount: int):
	if GameState.characters.has(character_uid):
		var character = GameState.characters[character_uid]
		character.focus_points -= amount
		character.focus_points = clamp(character.focus_points, 0, Constants.FOCUS_MAX_DEFAULT)
		# If this change was for the player, announce it.
		if character_uid == GameState.player_character_uid:
			EventBus.emit_signal("player_fp_changed", character.focus_points)


func get_fp(character_uid: int) -> int:
	if GameState.characters.has(character_uid):
		return GameState.characters[character_uid].focus_points
	return 0


func get_skill_level(character_uid: int, skill_name: String) -> int:
	if GameState.characters.has(character_uid):
		if GameState.characters[character_uid].skills.has(skill_name):
			return GameState.characters[character_uid].skills[skill_name]
	return 0


func apply_upkeep_cost(character_uid: int, cost: int):
	subtract_wp(character_uid, cost)

# NOTE: The get_player_save_data() and load_player_save_data() functions have been removed.
# This responsibility is now handled by the GameStateManager, which will serialize and
# deserialize the entire GameState.characters dictionary directly.

--- Start of ./src/core/systems/chronicle_system.gd ---

extends Node

func _ready():
	GlobalRefs.set_chronicle_system(self)
	print("ChronicleSystem Ready.")

--- Start of ./src/core/systems/combat_system.gd ---

# combat_system.gd
# Stateless API for combat mechanics - targeting, damage, disabling
# Phase 1: Hull-only targeting, basic weapon firing
extends Node

signal combat_started(attacker_uid, defender_uid)
signal combat_ended(result)
signal damage_dealt(target_uid, amount, source_uid)
signal ship_disabled(ship_uid)
signal weapon_fired(shooter_uid, weapon_id, target_pos)

const UtilityToolTemplate = preload("res://database/definitions/utility_tool_template.gd")

# Combat state tracking (per-encounter)
var _active_combatants: Dictionary = {}  # uid -> combat_state dict
var _combat_active: bool = false


func _ready():
	GlobalRefs.set_combat_system(self)
	print("CombatSystem Ready.")


# --- Public API ---

# Initialize combat state for an agent
func register_combatant(agent_uid: int, ship_template) -> void:
	if not ship_template:
		return
	
	_active_combatants[agent_uid] = {
		"current_hull": ship_template.hull_integrity,
		"max_hull": ship_template.hull_integrity,
		"current_armor": ship_template.armor_integrity,
		"max_armor": ship_template.armor_integrity,
		"is_disabled": false,
		"equipped_tools": [],
		"cooldowns": {}  # tool_id -> time_remaining
	}


func unregister_combatant(agent_uid: int) -> void:
	_active_combatants.erase(agent_uid)


func is_in_combat(agent_uid: int) -> bool:
	return _active_combatants.has(agent_uid) and not _active_combatants[agent_uid].is_disabled


func is_combat_active() -> bool:
	return _combat_active


func get_combat_state(agent_uid: int) -> Dictionary:
	return _active_combatants.get(agent_uid, {})


# Get hull percentage (0.0 - 1.0)
func get_hull_percent(agent_uid: int) -> float:
	var state = _active_combatants.get(agent_uid, {})
	if state.empty() or state.max_hull == 0:
		return 0.0
	return float(state.current_hull) / float(state.max_hull)


# Check if a target is within weapon range
func is_in_range(shooter_pos: Vector3, target_pos: Vector3, weapon: UtilityToolTemplate) -> bool:
	if not weapon:
		return false
	var distance = shooter_pos.distance_to(target_pos)
	return distance <= weapon.range_max


# Calculate damage based on weapon and distance
func calculate_damage(weapon: UtilityToolTemplate, distance: float) -> Dictionary:
	if not weapon:
		return {"hull_damage": 0, "armor_damage": 0}
	
	var base_damage = weapon.get_damage_at_range(distance)
	
	return {
		"hull_damage": base_damage * weapon.hull_damage_multiplier,
		"armor_damage": base_damage * weapon.armor_damage_multiplier
	}


# Attempt to fire a weapon at a target
func fire_weapon(shooter_uid: int, target_uid: int, weapon: UtilityToolTemplate, 
				 shooter_pos: Vector3, target_pos: Vector3) -> Dictionary:
	# Validate combatants
	if not _active_combatants.has(shooter_uid):
		return {"success": false, "reason": "Shooter not registered"}
	if not _active_combatants.has(target_uid):
		return {"success": false, "reason": "Target not registered"}
	if not weapon:
		return {"success": false, "reason": "No weapon provided"}
	
	var shooter_state = _active_combatants[shooter_uid]
	
	# Check cooldown
	var cooldown_remaining = shooter_state.cooldowns.get(weapon.template_id, 0.0)
	if cooldown_remaining > 0:
		return {"success": false, "reason": "Weapon on cooldown", "cooldown": cooldown_remaining}
	
	# Check range
	var distance = shooter_pos.distance_to(target_pos)
	if distance > weapon.range_max:
		return {"success": false, "reason": "Target out of range", "distance": distance}
	
	# Calculate hit chance
	var hit_chance = weapon.get_accuracy_at_range(distance)
	var roll = randf()
	var hit = roll <= hit_chance
	
	# Set cooldown
	var cooldown = (1.0 / weapon.fire_rate) + weapon.cooldown_time
	shooter_state.cooldowns[weapon.template_id] = cooldown
	
	# Emit weapon fired signal
	emit_signal("weapon_fired", shooter_uid, weapon.template_id, target_pos)
	
	if not hit:
		return {
			"success": true,
			"hit": false,
			"reason": "Missed",
			"accuracy": hit_chance,
			"roll": roll
		}
	
	# Calculate and apply damage
	var damage = calculate_damage(weapon, distance)
	var damage_result = apply_damage(target_uid, damage.hull_damage, damage.armor_damage, shooter_uid)

	# If the target is already disabled (or otherwise invalid), avoid crashing and report cleanly.
	if not damage_result.get("success", false):
		var already_disabled: bool = (damage_result.get("reason", "") == "Target already disabled")
		return {
			"success": true,
			"hit": true,
			"damage_dealt": damage,
			"target_disabled": already_disabled,
			"target_hull_remaining": 0,
			"warning": damage_result.get("reason", "Damage not applied")
		}
	
	return {
		"success": true,
		"hit": true,
		"damage_dealt": damage,
		"target_disabled": bool(damage_result.get("disabled", false)),
		"target_hull_remaining": damage_result.get("hull_remaining", 0)
	}


# Apply damage to a target
func apply_damage(target_uid: int, hull_damage: float, armor_damage: float = 0.0, source_uid: int = -1) -> Dictionary:
	if not _active_combatants.has(target_uid):
		return {"success": false, "reason": "Target not registered"}
	
	var state = _active_combatants[target_uid]
	
	if state.is_disabled:
		return {"success": false, "reason": "Target already disabled"}
	
	# Phase 1: Simple damage model - armor absorbs first, then hull
	var remaining_damage = hull_damage
	
	# Apply to armor first if present
	if armor_damage > 0 and state.current_armor > 0:
		var armor_absorbed = min(armor_damage, state.current_armor)
		state.current_armor -= armor_absorbed
	
	# Apply hull damage
	var hull_dealt = min(remaining_damage, state.current_hull)
	state.current_hull -= hull_dealt
	
	emit_signal("damage_dealt", target_uid, hull_dealt, source_uid)

	# Mirror gameplay-facing damage signals onto EventBus (HUD, AI, encounter logic).
	if EventBus:
		var target_body = _get_agent_body(target_uid)
		var source_body = _get_agent_body(source_uid)
		if is_instance_valid(target_body):
			EventBus.emit_signal("agent_damaged", target_body, hull_dealt, source_body)
	
	# Check for disable
	var disabled = state.current_hull <= 0
	if disabled:
		state.is_disabled = true
		state.current_hull = 0
		emit_signal("ship_disabled", target_uid)
		if EventBus:
			var disabled_body = _get_agent_body(target_uid)
			if is_instance_valid(disabled_body):
				EventBus.emit_signal("agent_disabled", disabled_body)
	
	return {
		"success": true,
		"hull_damage_dealt": hull_dealt,
		"hull_remaining": state.current_hull,
		"armor_remaining": state.current_armor,
		"disabled": disabled
	}


# Update cooldowns (call each frame or physics tick)
func update_cooldowns(delta: float) -> void:
	for uid in _active_combatants:
		var state = _active_combatants[uid]
		var to_remove = []
		for tool_id in state.cooldowns:
			state.cooldowns[tool_id] -= delta
			if state.cooldowns[tool_id] <= 0:
				to_remove.append(tool_id)
		for tool_id in to_remove:
			state.cooldowns.erase(tool_id)


# Check if all enemies are disabled
func check_combat_victory(player_uid: int) -> Dictionary:
	var player_alive = _active_combatants.has(player_uid) and not _active_combatants[player_uid].is_disabled
	
	if not player_alive:
		return {"victory": false, "reason": "player_disabled"}
	
	# Check if any non-player combatants are still active
	for uid in _active_combatants:
		if uid != player_uid and not _active_combatants[uid].is_disabled:
			return {"victory": false, "reason": "enemies_remain"}
	
	return {"victory": true, "reason": "all_enemies_disabled"}


# Start a combat encounter
func start_combat(participants: Array) -> void:
	_combat_active = true
	for participant in participants:
		var uid = participant.get("uid", -1)
		var ship = participant.get("ship_template", null)
		if uid >= 0 and ship:
			register_combatant(uid, ship)
	
	if participants.size() >= 2:
		emit_signal("combat_started", participants[0].get("uid", -1), participants[1].get("uid", -1))


# End combat and clean up
func end_combat(result: String = "ended") -> void:
	_combat_active = false
	_active_combatants.clear()
	emit_signal("combat_ended", result)


func _get_agent_body(agent_uid: int):
	if agent_uid < 0:
		return null

	if is_instance_valid(GlobalRefs.world_manager) and GlobalRefs.world_manager.has_method("get_agent_by_uid"):
		var from_world_manager = GlobalRefs.world_manager.get_agent_by_uid(agent_uid)
		if is_instance_valid(from_world_manager):
			return from_world_manager

	# Fallback: scan nodes in the Agents group.
	var tree = get_tree()
	if tree:
		for node in tree.get_nodes_in_group("Agents"):
			if is_instance_valid(node) and node.get("agent_uid") != null and int(node.get("agent_uid")) == agent_uid:
				return node

	return null


# --- Targeting Helpers ---

# Get closest enemy in range
func get_closest_target(_from_pos: Vector3, agent_uid: int, _max_range: float = -1.0) -> Dictionary:
	var closest_uid = -1
	var closest_dist = INF
	
	for uid in _active_combatants:
		if uid == agent_uid:
			continue
		if _active_combatants[uid].is_disabled:
			continue
		
		# Would need agent positions from another system
		# This is a placeholder - actual implementation needs position data
	
	return {"target_uid": closest_uid, "distance": closest_dist}


# --- Combat Resolution (Narrative Actions) ---

# Assess aftermath - Phase 1 narrative action after combat
func assess_aftermath(_char_uid: int, tactics_skill: int) -> Dictionary:
	# Uses CoreMechanicsAPI for action check
	var approach = Constants.ActionApproach.CAUTIOUS
	var result = CoreMechanicsAPI.perform_action_check(tactics_skill, 0, 0, approach)
	
	var success = result.result_tier in ["CritSuccess", "SuccessWithCost", "Success"]
	
	if success:
		# Could reveal faction info, salvage opportunities, etc.
		return {
			"success": true,
			"result": result,
			"findings": {
				"faction_revealed": randf() > 0.5,
				"salvage_quality": "standard" if result.result_tier != "CritSuccess" else "excellent"
			}
		}
	else:
		return {
			"success": false,
			"result": result,
			"consequence": "No useful information found"
		}


# Claim wreckage - Phase 1 narrative action
func claim_wreckage(_char_uid: int, tactics_skill: int, approach: int) -> Dictionary:
	var result = CoreMechanicsAPI.perform_action_check(tactics_skill, 0, 0, approach)
	
	var success = result.result_tier in ["CritSuccess", "SuccessWithCost", "Success"]
	var base_salvage = 50  # Base WP value
	
	if result.result_tier == "CritSuccess":
		return {
			"success": true,
			"result": result,
			"wp_gained": base_salvage * 2,
			"item_found": true
		}
	elif success:
		var wp = base_salvage
		if approach == Constants.ActionApproach.RISKY:
			wp = int(wp * 1.5)
		return {
			"success": true,
			"result": result,
			"wp_gained": wp,
			"item_found": false
		}
	else:
		return {
			"success": false,
			"result": result,
			"wp_gained": 0,
			"consequence": "Wreckage too unstable to salvage"
		}

--- Start of ./src/core/systems/contract_system.gd ---

# contract_system.gd
# Stateless API for contract management - accept, track, complete, abandon
extends Node

const InventorySystem = preload("res://src/core/systems/inventory_system.gd")
const MAX_ACTIVE_CONTRACTS = 3  # Phase 1 limit


func _ready():
	GlobalRefs.set_contract_system(self)
	print("ContractSystem Ready.")


# Get all contracts available at a specific location
func get_available_contracts(location_id: String) -> Array:
	var available = []
	for contract_id in GameState.contracts:
		var contract = GameState.contracts[contract_id]
		if contract and contract.origin_location_id == location_id:
			# Check not already active
			if not GameState.active_contracts.has(contract_id):
				available.append(contract)
	return available


# Get all contracts available at a location, filtered by player's active contracts
func get_available_contracts_for_character(_char_uid: int, location_id: String) -> Array:
	var available = get_available_contracts(location_id)
	# Filter out any that player already has active
	var result = []
	for contract in available:
		if not GameState.active_contracts.has(contract.template_id):
			result.append(contract)
	return result


# Accept a contract for a character
func accept_contract(char_uid: int, contract_id: String) -> Dictionary:
	# Validate contract exists
	if not GameState.contracts.has(contract_id):
		return {
			"success": false,
			"reason": "Contract not found: " + contract_id
		}
	
	# Check not already active
	if GameState.active_contracts.has(contract_id):
		return {
			"success": false,
			"reason": "Contract already active"
		}
	
	# Check active contract limit
	var active_count = _count_active_contracts_for_character(char_uid)
	if active_count >= MAX_ACTIVE_CONTRACTS:
		return {
			"success": false,
			"reason": "Maximum active contracts reached (" + str(MAX_ACTIVE_CONTRACTS) + ")"
		}
	
	# Get contract and mark as accepted
	var contract = GameState.contracts[contract_id]
	var contract_copy = contract.duplicate(true)
	contract_copy.accepted_at_tu = GameState.current_tu
	contract_copy.progress = {"character_uid": char_uid}
	
	# Add to active contracts
	GameState.active_contracts[contract_id] = contract_copy
	
	# Emit signal
	EventBus.emit_signal("contract_accepted", contract_id)
	
	return {
		"success": true,
		"contract": contract_copy
	}


# Get all active contracts for a character
func get_active_contracts(char_uid: int) -> Array:
	var active = []
	for contract_id in GameState.active_contracts:
		var contract = GameState.active_contracts[contract_id]
		if contract and contract.progress.get("character_uid", -1) == char_uid:
			active.append(contract)
	return active


# Check if a contract can be completed (player has requirements)
func check_contract_completion(char_uid: int, contract_id: String) -> Dictionary:
	# Validate contract is active
	if not GameState.active_contracts.has(contract_id):
		return {
			"can_complete": false,
			"reason": "Contract not active"
		}
	
	var contract = GameState.active_contracts[contract_id]
	
	# Check ownership
	if contract.progress.get("character_uid", -1) != char_uid:
		return {
			"can_complete": false,
			"reason": "Contract belongs to different character"
		}
	
	# Check expiration
	if contract.is_expired(GameState.current_tu):
		return {
			"can_complete": false,
			"reason": "Contract has expired"
		}
	
	# Type-specific completion checks
	match contract.contract_type:
		"delivery":
			return _check_delivery_completion(char_uid, contract)
		"combat":
			return _check_combat_completion(char_uid, contract)
		_:
			return {
				"can_complete": false,
				"reason": "Unknown contract type: " + contract.contract_type
			}


# Complete a contract and apply rewards
func complete_contract(char_uid: int, contract_id: String) -> Dictionary:
	# First check if completable
	var check = check_contract_completion(char_uid, contract_id)
	if not check.can_complete:
		return {
			"success": false,
			"reason": check.reason
		}
	
	var contract = GameState.active_contracts[contract_id]
	
	# Apply completion based on type
	var completion_result = {}
	match contract.contract_type:
		"delivery":
			completion_result = _complete_delivery(char_uid, contract)
		"combat":
			completion_result = _complete_combat(char_uid, contract)
		_:
			return {
				"success": false,
				"reason": "Cannot complete unknown contract type"
			}
	
	if not completion_result.get("success", false):
		return completion_result
	
	# Apply rewards
	_apply_rewards(char_uid, contract)
	
	# Remove from active contracts
	GameState.active_contracts.erase(contract_id)
	
	# Update session stats
	GameState.session_stats.contracts_completed += 1
	
	# Emit signal
	EventBus.emit_signal("contract_completed", contract_id, true)
	
	# Calculate total WP earned including cargo sale
	var cargo_sale_value: int = completion_result.get("cargo_sale_value", 0)
	
	return {
		"success": true,
		"contract": contract,
		"rewards": {
			"wp": contract.reward_wp,
			"cargo_sale_wp": cargo_sale_value,
			"total_wp": contract.reward_wp + cargo_sale_value,
			"reputation": contract.reward_reputation,
			"items": contract.reward_items
		}
	}


# Abandon a contract (no penalty in Phase 1)
func abandon_contract(char_uid: int, contract_id: String) -> Dictionary:
	if not GameState.active_contracts.has(contract_id):
		return {
			"success": false,
			"reason": "Contract not active"
		}
	
	var contract = GameState.active_contracts[contract_id]
	
	# Check ownership
	if contract.progress.get("character_uid", -1) != char_uid:
		return {
			"success": false,
			"reason": "Contract belongs to different character"
		}
	
	# Remove from active
	GameState.active_contracts.erase(contract_id)
	
	# Emit signal
	EventBus.emit_signal("contract_abandoned", contract_id)
	
	return {
		"success": true,
		"contract": contract
	}


# Check for expired contracts and handle them
func check_expired_contracts(char_uid: int) -> Array:
	var expired = []
	var to_fail = []
	
	for contract_id in GameState.active_contracts:
		var contract = GameState.active_contracts[contract_id]
		if contract.progress.get("character_uid", -1) != char_uid:
			continue
		if contract.is_expired(GameState.current_tu):
			to_fail.append(contract_id)
			expired.append(contract)
	
	# Fail expired contracts
	for contract_id in to_fail:
		_fail_contract(char_uid, contract_id)
	
	return expired


# Get contract by ID from active contracts
func get_contract(contract_id: String):
	return GameState.active_contracts.get(contract_id, null)


# ---- Private helpers ----

func _count_active_contracts_for_character(char_uid: int) -> int:
	var count = 0
	for contract_id in GameState.active_contracts:
		var contract = GameState.active_contracts[contract_id]
		if contract.progress.get("character_uid", -1) == char_uid:
			count += 1
	return count


func _check_delivery_completion(char_uid: int, contract) -> Dictionary:
	# Check player is at destination
	if GameState.player_docked_at != contract.destination_location_id:
		return {
			"can_complete": false,
			"reason": "Not at destination: " + contract.destination_location_id
		}
	
	# Check player has required cargo
	var inventory_system = GlobalRefs.inventory_system
	if not inventory_system:
		return {
			"can_complete": false,
			"reason": "Inventory system not available"
		}
	
	var cargo = inventory_system.get_inventory_by_type(char_uid, InventorySystem.InventoryType.COMMODITY)
	var owned_qty = cargo.get(contract.required_commodity_id, 0)
	
	if owned_qty < contract.required_quantity:
		return {
			"can_complete": false,
			"reason": "Insufficient cargo: need " + str(contract.required_quantity) + " " + contract.required_commodity_id + ", have " + str(owned_qty)
		}
	
	return {
		"can_complete": true,
		"reason": ""
	}


func _check_combat_completion(_char_uid: int, contract) -> Dictionary:
	# Check kill count in progress
	var kills = contract.progress.get("kills", 0)
	if kills < contract.target_count:
		return {
			"can_complete": false,
			"reason": "Targets remaining: " + str(contract.target_count - kills)
		}
	
	return {
		"can_complete": true,
		"reason": ""
	}


func _complete_delivery(char_uid: int, contract) -> Dictionary:
	# Remove cargo from player inventory
	var inventory_system = GlobalRefs.inventory_system
	if not inventory_system:
		return {
			"success": false,
			"reason": "Inventory system not available"
		}
	
	# Calculate cargo sale value at destination before removing
	var cargo_sale_value: int = 0
	var dest_location_id: String = contract.destination_location_id
	if GameState.locations.has(dest_location_id):
		var location = GameState.locations[dest_location_id]
		if location.market_inventory.has(contract.required_commodity_id):
			var sell_price: int = location.market_inventory[contract.required_commodity_id].get("sell_price", 0)
			cargo_sale_value = sell_price * contract.required_quantity
	
	var removed = inventory_system.remove_asset(
		char_uid,
		InventorySystem.InventoryType.COMMODITY,
		contract.required_commodity_id,
		contract.required_quantity
	)
	
	if not removed:
		return {
			"success": false,
			"reason": "Failed to remove cargo from inventory"
		}
	
	# Pay player for the delivered cargo at local sell price
	if cargo_sale_value > 0:
		var character_system = GlobalRefs.character_system
		if character_system:
			character_system.add_wp(char_uid, cargo_sale_value)
			GameState.session_stats.total_wp_earned += cargo_sale_value
	
	return {"success": true, "cargo_sale_value": cargo_sale_value}


func _complete_combat(_char_uid: int, _contract) -> Dictionary:
	# Combat contracts just need kill count met, no additional action
	return {"success": true}


func _apply_rewards(char_uid: int, contract) -> void:
	# Apply WP reward
	var character_system = GlobalRefs.character_system
	if character_system and contract.reward_wp > 0:
		character_system.add_wp(char_uid, contract.reward_wp)
		GameState.session_stats.total_wp_earned += contract.reward_wp
	
	# Apply reputation
	if contract.reward_reputation != 0:
		var current_rep = GameState.narrative_state.get("reputation", 0)
		GameState.narrative_state.reputation = current_rep + contract.reward_reputation
		
		# Track faction standing if faction specified
		if contract.faction_id != "":
			var standings = GameState.narrative_state.get("faction_standings", {})
			var current_faction_rep = standings.get(contract.faction_id, 0)
			standings[contract.faction_id] = current_faction_rep + contract.reward_reputation
			GameState.narrative_state.faction_standings = standings
	
	# Apply item rewards
	var inventory_system = GlobalRefs.inventory_system
	if inventory_system:
		for item_id in contract.reward_items:
			var qty = contract.reward_items[item_id]
			# Determine item type from template
			var template = TemplateDatabase.get_template(item_id)
			if template:
				var asset_type = InventorySystem.InventoryType.COMMODITY  # Default
				if template.template_type == "module":
					asset_type = InventorySystem.InventoryType.MODULE
				inventory_system.add_asset(char_uid, asset_type, item_id, qty)


func _fail_contract(_char_uid: int, contract_id: String) -> void:
	var contract = GameState.active_contracts.get(contract_id)
	if not contract:
		return
	
	# Remove from active
	GameState.active_contracts.erase(contract_id)
	
	# Emit failure signal
	EventBus.emit_signal("contract_failed", contract_id)

--- Start of ./src/core/systems/event_system.gd ---

## EventSystem manages combat encounter generation and tracking.
## Handles encounter triggering with cooldown, hostile spawning, and combat state management.
extends Node

# --- Configuration ---
const ENCOUNTER_COOLDOWN_TU: int = 5
const BASE_ENCOUNTER_CHANCE: float = 0.30
const SPAWN_DISTANCE_MIN: float = 600.0
const SPAWN_DISTANCE_MAX: float = 1000.0

# --- State ---
var _encounter_cooldown_tu: int = 0
var _active_hostiles: Array = []


## Initializes EventSystem and connects to EventBus signals.
func _ready() -> void:
	GlobalRefs.set_event_system(self)

	if EventBus:
		EventBus.connect("world_event_tick_triggered", self, "_on_world_event_tick_triggered")
		EventBus.connect("agent_disabled", self, "_on_agent_disabled")
		EventBus.connect("agent_despawning", self, "_on_agent_despawning")
	print("EventSystem Ready.")


## Processes world event ticks and manages encounter cooldown.
## Decrements cooldown, potentially triggers encounters if conditions are met.
func _on_world_event_tick_triggered(tu_amount: int) -> void:
	if tu_amount <= 0:
		return

	_encounter_cooldown_tu = int(max(0, _encounter_cooldown_tu - tu_amount))
	_prune_invalid_hostiles()

	if _encounter_cooldown_tu > 0:
		return
	if not _active_hostiles.empty():
		return

	_maybe_trigger_encounter()


## Handles agent disabled signal; removes from active hostiles and checks for combat end.
func _on_agent_disabled(agent_body: Node) -> void:
	if _active_hostiles.has(agent_body):
		_active_hostiles.erase(agent_body)
	_check_combat_end()


## Handles agent despawning signal; removes from active hostiles and checks for combat end.
func _on_agent_despawning(agent_body: Node) -> void:
	if _active_hostiles.has(agent_body):
		_active_hostiles.erase(agent_body)
	_check_combat_end()



## Determines whether to trigger an encounter based on danger level and probability.
## Rolls against BASE_ENCOUNTER_CHANCE and spawns hostiles if successful.
func _maybe_trigger_encounter() -> void:
	var danger_level: float = _get_current_danger_level()
	var chance: float = clamp(BASE_ENCOUNTER_CHANCE * danger_level, 0.0, 1.0)

	if randf() > chance:
		_encounter_cooldown_tu = ENCOUNTER_COOLDOWN_TU
		return

	_spawn_hostile_encounter()
	_encounter_cooldown_tu = ENCOUNTER_COOLDOWN_TU * 2


## Spawns hostile NPCs at calculated positions and emits combat_initiated signal.
func _spawn_hostile_encounter() -> void:
	var player: Node = GlobalRefs.player_agent_body
	if not is_instance_valid(player):
		return

	var spawner: Node = GlobalRefs.agent_spawner
	if not is_instance_valid(spawner) or not spawner.has_method("spawn_npc_from_template"):
		printerr("EventSystem: AgentSpawner missing spawn_npc_from_template().")
		return

	var player_pos: Vector3 = player.global_transform.origin
	var spawn_count: int = 1 + (randi() % 2)

	for _i in range(spawn_count):
		var spawn_pos: Vector3 = _calculate_spawn_position(player_pos)
		var overrides: Dictionary = {
			"agent_type": "npc",
			"template_id": "npc_hostile_default",
			"character_uid": -1,
			"hostile": true,
			"patrol_center": spawn_pos,
		}

		var npc: Node = spawner.spawn_npc_from_template(Constants.NPC_HOSTILE_TEMPLATE_PATH, spawn_pos, overrides)
		if is_instance_valid(npc):
			_active_hostiles.append(npc)

	_prune_invalid_hostiles()
	if not _active_hostiles.empty() and EventBus:
		EventBus.emit_signal("combat_initiated", player, _active_hostiles.duplicate())


## Calculates a random spawn position around the player within configured distance.
## Returns: Vector3 spawn position
func _calculate_spawn_position(player_pos: Vector3) -> Vector3:
	var angle: float = randf() * TAU
	var distance: float = rand_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)
	var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * distance
	return player_pos + offset


## Gets current danger level based on game state.
## Returns: float between 0 and 1 affecting encounter chance
func _get_current_danger_level() -> float:
	return 1.0


## Checks if all hostiles are defeated and emits combat_ended signal if so.
func _check_combat_end() -> void:
	_prune_invalid_hostiles()
	if _active_hostiles.empty() and EventBus:
		EventBus.emit_signal("combat_ended", {"outcome": "victory", "hostiles_defeated": true})


## Removes invalid (freed) nodes from active hostiles array.
func _prune_invalid_hostiles() -> void:
	if _active_hostiles.empty():
		return
	var still_valid: Array = []
	for hostile in _active_hostiles:
		if is_instance_valid(hostile):
			still_valid.append(hostile)
	_active_hostiles = still_valid


# --- Public API ---

## Returns a copy of the current active hostiles array.
## Returns: Array of active hostile nodes
func get_active_hostiles() -> Array:
	_prune_invalid_hostiles()
	return _active_hostiles.duplicate()


## Immediately forces an encounter to spawn (for testing/debugging).
func force_encounter() -> void:
	_encounter_cooldown_tu = 0
	_spawn_hostile_encounter()


## Clears all tracked hostiles from active list.
func clear_hostiles() -> void:
	_active_hostiles.clear()


## Cleanup on node deletion; disconnects signals and clears references.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if GlobalRefs and GlobalRefs.event_system == self:
			GlobalRefs.event_system = null
		if EventBus:
			if EventBus.is_connected("world_event_tick_triggered", self, "_on_world_event_tick_triggered"):
				EventBus.disconnect("world_event_tick_triggered", self, "_on_world_event_tick_triggered")
			if EventBus.is_connected("agent_disabled", self, "_on_agent_disabled"):
				EventBus.disconnect("agent_disabled", self, "_on_agent_disabled")
			if EventBus.is_connected("agent_despawning", self, "_on_agent_despawning"):
				EventBus.disconnect("agent_despawning", self, "_on_agent_despawning")

--- Start of ./src/core/systems/goal_system.gd ---

extends Node

func _ready():
	GlobalRefs.set_goal_system(self)
	print("GoalSystem Ready.")

--- Start of ./src/core/systems/inventory_system.gd ---

# File: core/systems/inventory_system.gd
# Purpose: Provides a unified, stateless API for managing all character inventories.
# Version: 4.0 - Reworked for a unified, asset-agnostic architecture.

extends Node

# Enum to define the different types of asset inventories a character can have.
enum InventoryType { SHIP, MODULE, COMMODITY }


func _ready():
	GlobalRefs.set_inventory_system(self)
	print("InventorySystem Ready.")


# --- Public API ---

# Ensures an inventory record exists for a character in the GameState.
# This should be called by the WorldGenerator when a character is created.
func create_inventory_for_character(character_uid: int):
	if not GameState.inventories.has(character_uid):
		GameState.inventories[character_uid] = {
			InventoryType.SHIP: {},      # Key: Asset UID, Value: Asset Instance
			InventoryType.MODULE: {},    # Key: Asset UID, Value: Asset Instance
			InventoryType.COMMODITY: {}  # Key: Template ID, Value: Quantity
		}

# Adds any type of asset to a character's inventory.
func add_asset(character_uid: int, inventory_type: int, asset_id, quantity: int = 1):
	if not GameState.inventories.has(character_uid):
		printerr("InventorySystem: No inventory for character UID: ", character_uid)
		return

	var inventory = GameState.inventories[character_uid]

	if inventory_type == InventoryType.COMMODITY:
		# Commodities are stored by template ID and quantity.
		if inventory[inventory_type].has(asset_id):
			inventory[inventory_type][asset_id] += quantity
		else:
			inventory[inventory_type][asset_id] = quantity
	else:
		# Ships and Modules are unique instances stored by their UID.
		var asset_instance = _get_master_asset_instance(inventory_type, asset_id)
		if is_instance_valid(asset_instance):
			inventory[inventory_type][asset_id] = asset_instance
		else:
			printerr("InventorySystem: Invalid asset UID provided: ", asset_id)

# Removes any type of asset from a character's inventory.
func remove_asset(character_uid: int, inventory_type: int, asset_id, quantity: int = 1) -> bool:
	if not GameState.inventories.has(character_uid):
		return false

	var inventory = GameState.inventories[character_uid]

	if not inventory[inventory_type].has(asset_id):
		return false # They don't have the asset.

	if inventory_type == InventoryType.COMMODITY:
		if inventory[inventory_type][asset_id] < quantity:
			return false # Not enough to remove.
		inventory[inventory_type][asset_id] -= quantity
		if inventory[inventory_type][asset_id] <= 0:
			inventory[inventory_type].erase(asset_id)
	else:
		# For unique assets, quantity doesn't matter; we just remove the entry.
		inventory[inventory_type].erase(asset_id)

	return true

# Gets the count of a specific asset.
func get_asset_count(character_uid: int, inventory_type: int, asset_id) -> int:
	if not GameState.inventories.has(character_uid):
		return 0
	
	if inventory_type == InventoryType.COMMODITY:
		return GameState.inventories[character_uid][inventory_type].get(asset_id, 0)
	else:
		return 1 if GameState.inventories[character_uid][inventory_type].has(asset_id) else 0

# Returns a dictionary of a specific type of asset from a character's inventory.
func get_inventory_by_type(character_uid: int, inventory_type: int) -> Dictionary:
	if GameState.inventories.has(character_uid):
		return GameState.inventories[character_uid][inventory_type].duplicate(true)
	return {}


# --- Private Helper ---

# Finds the master asset instance from the correct dictionary in GameState.
func _get_master_asset_instance(inventory_type: int, asset_uid: int) -> Resource:
	if inventory_type == InventoryType.SHIP:
		return GameState.assets_ships.get(asset_uid)
	elif inventory_type == InventoryType.MODULE:
		return GameState.assets_modules.get(asset_uid)
	return null

--- Start of ./src/core/systems/narrative_action_system.gd ---

# File: core/systems/narrative_action_system.gd
# Purpose: Orchestrates Narrative Actions: request → resolve → apply effects.
#          Bridges game events (contract completion, docking, trading) with
#          CoreMechanicsAPI (dice rolls) and NarrativeOutcomes (effect lookup).
# Version: 2.0 - Strict types, comprehensive docstrings, safe null checks.

extends Node

## Stores pending action state while awaiting UI player input.
var _pending_action: Dictionary = {}


func _ready() -> void:
	"""Register this system in GlobalRefs (if setter available)."""
	if GlobalRefs and GlobalRefs.has_method("set_narrative_action_system"):
		GlobalRefs.set_narrative_action_system(self)


func request_action(action_type: String, context: Dictionary) -> void:
	"""Request a narrative action (e.g., "contract_complete").
	
	Args:
		action_type: "contract_complete", "dock_arrival", or "trade_finalize".
		context: {char_uid, description, ...} passed through to UI.
	
	Behavior:
		Stores action data in _pending_action.
		Looks up skill/attribute for this action type.
		Emits EventBus.narrative_action_requested to show UI.
	"""
	var char_uid: int = int(context.get("char_uid", GameState.player_character_uid))
	_pending_action = {
		"action_type": action_type,
		"context": context,
		"char_uid": char_uid
	}

	# Determine which skill/attribute applies.
	var skill_info: Dictionary = _get_skill_for_action(action_type)
	_pending_action.merge(skill_info)

	# Cross-system/UI signal (global).
	# EventBus declares: signal narrative_action_requested(action_type, context)
	if EventBus:
		EventBus.emit_signal("narrative_action_requested", action_type, _pending_action)


func resolve_action(approach: int, fp_spent: int) -> Dictionary:
	"""Resolve pending action: roll, lookup outcome, apply effects.
	
	Args:
		approach: Constants.ActionApproach (CAUTIOUS=0 or RISKY=1).
		fp_spent: Focus Points player allocated (0-3 typically).
	
	Returns:
		{success: bool, roll_result: Dictionary, outcome: Dictionary, effects_applied: Dictionary}
		
	Behavior:
		1. Validates pending action exists.
		2. Gets character attribute & skill.
		3. Clamps fp_spent to available FP.
		4. Calls CoreMechanicsAPI.perform_action_check().
		5. Looks up narrative outcome by action_type + tier.
		6. Applies all effects (WP, FP, quirks, reputation).
		7. Emits EventBus.narrative_action_resolved.
		8. Clears _pending_action.
	"""
	if _pending_action.empty():
		return {"success": false, "reason": "No pending action"}

	var char_uid: int = int(_pending_action.get("char_uid", GameState.player_character_uid))
	if not is_instance_valid(GlobalRefs.character_system):
		return {"success": false, "reason": "CharacterSystem unavailable"}

	var attribute_name: String = str(_pending_action.get("attribute_name", "cunning"))
	var skill_name: String = str(_pending_action.get("skill_name", "general"))
	var attr_value: int = _get_attribute_value(char_uid, attribute_name)
	var skill_value: int = int(GlobalRefs.character_system.get_skill_level(char_uid, skill_name))

	# Clamp FP spent to available FP; CoreMechanicsAPI will clamp to max.
	var available_fp: int = int(GlobalRefs.character_system.get_fp(char_uid))
	fp_spent = int(fp_spent)
	if fp_spent < 0:
		fp_spent = 0
	if fp_spent > available_fp:
		fp_spent = available_fp

	# Perform the roll via CoreMechanicsAPI.
	var roll_result: Dictionary = CoreMechanicsAPI.perform_action_check(attr_value, skill_value, fp_spent, approach)

	# Get narrative outcome from tier.
	# CoreMechanicsAPI returns both result_tier ("CritSuccess"/"SwC"/"Failure") and tier_name.
	var tier_key: String = str(roll_result.get("result_tier", roll_result.get("tier_name", "Failure")))
	var action_type: String = str(_pending_action.get("action_type", ""))
	var outcome: Dictionary = _get_narrative_outcome(action_type, tier_key)

	# Apply effects.
	var applied: Dictionary = _apply_effects(char_uid, outcome.get("effects", {}))

	# Deduct FP spent.
	if fp_spent > 0:
		GlobalRefs.character_system.subtract_fp(char_uid, fp_spent)

	# Handle FP gain/loss from roll result.
	var focus_gain: int = int(roll_result.get("focus_gain", 0))
	if focus_gain > 0:
		GlobalRefs.character_system.add_fp(char_uid, focus_gain)
	if bool(roll_result.get("focus_loss_reset", false)):
		_reset_focus_points(char_uid)

	var result: Dictionary = {
		"success": true,
		"roll_result": roll_result,
		"outcome": outcome,
		"effects_applied": applied,
		"action_type": action_type,
		"char_uid": char_uid
	}

	# Cross-system/UI signal (global).
	if EventBus:
		EventBus.emit_signal("narrative_action_resolved", result)

	_pending_action = {}
	return result


func _get_narrative_outcome(action_type: String, tier_key: String) -> Dictionary:
	"""Look up outcome data from NarrativeOutcomes autoload.
	
	Args:
		action_type: e.g., "contract_complete".
		tier_key: "CritSuccess", "SwC", or "Failure".
		
	Returns:
		{description: String, effects: Dictionary} or empty dict if not found.
	"""
	var outcomes_node: Node = get_node_or_null("/root/NarrativeOutcomes")
	if outcomes_node and outcomes_node.has_method("get_outcome"):
		return outcomes_node.get_outcome(action_type, tier_key)
	return {"description": "No outcome defined.", "effects": {}}


func _get_skill_for_action(action_type: String) -> Dictionary:
	"""Map action_type to attribute & skill used in the check.
	
	Args:
		action_type: e.g., "contract_complete".
		
	Returns:
		{attribute_name: String, skill_name: String}.
	"""
	match action_type:
		"contract_complete":
			return {"attribute_name": "cunning", "skill_name": "negotiation"}
		"dock_arrival":
			return {"attribute_name": "reflex", "skill_name": "piloting"}
		"trade_finalize":
			return {"attribute_name": "cunning", "skill_name": "trading"}
		_:
			return {"attribute_name": "cunning", "skill_name": "general"}


func _apply_effects(char_uid: int, effects: Dictionary) -> Dictionary:
	"""Apply all outcome effects (WP, FP, quirks, reputation) to game state.
	
	Args:
		char_uid: Character UID.
		effects: {"wp_cost": int, "wp_gain": int, "fp_gain": int, "add_quirk": str, "reputation_change": int}.
		
	Returns:
		{"wp_lost": int, "wp_gained": int, "quirk_added": str, "reputation_changed": int}.
		Only includes effects that were actually applied.
	"""
	var applied: Dictionary = {}
	if effects == null:
		return applied

	# Ship quirks (best-effort: char ship if available, else player ship).
	if effects.has("add_quirk") and is_instance_valid(GlobalRefs.asset_system):
		var quirk_id: String = str(effects.get("add_quirk"))
		var ship: Object = null
		if GlobalRefs.asset_system.has_method("get_ship_for_character"):
			ship = GlobalRefs.asset_system.get_ship_for_character(char_uid)
		if ship == null and GlobalRefs.asset_system.has_method("get_player_ship"):
			ship = GlobalRefs.asset_system.get_player_ship()
		if is_instance_valid(ship):
			ship.ship_quirks.append(quirk_id)
			applied["quirk_added"] = quirk_id

	# WP adjustments.
	if effects.has("wp_cost"):
		var wp_cost: int = int(effects.get("wp_cost", 0))
		if wp_cost != 0 and is_instance_valid(GlobalRefs.character_system):
			GlobalRefs.character_system.subtract_wp(char_uid, wp_cost)
			applied["wp_lost"] = wp_cost

	if effects.has("wp_gain"):
		var wp_gain: int = int(effects.get("wp_gain", 0))
		if wp_gain != 0 and is_instance_valid(GlobalRefs.character_system):
			GlobalRefs.character_system.add_wp(char_uid, wp_gain)
			applied["wp_gained"] = wp_gain

	# FP gains from outcomes (separate from CoreMechanicsAPI focus_gain).
	if effects.has("fp_gain"):
		var fp_gain: int = int(effects.get("fp_gain", 0))
		if fp_gain != 0 and is_instance_valid(GlobalRefs.character_system):
			GlobalRefs.character_system.add_fp(char_uid, fp_gain)
			applied["fp_gained"] = fp_gain

	# Reputation change (GameState container).
	if effects.has("reputation_change"):
		var rep_delta: int = int(effects.get("reputation_change", 0))
		if not GameState.narrative_state.has("reputation"):
			GameState.narrative_state["reputation"] = 0
		GameState.narrative_state["reputation"] = int(GameState.narrative_state["reputation"]) + rep_delta
		applied["reputation_changed"] = rep_delta

	return applied


func _reset_focus_points(char_uid: int) -> void:
	"""Reset character's FP to 0 (used when focus_loss_reset from roll)."""
	if not is_instance_valid(GlobalRefs.character_system):
		return
	var current_fp: int = int(GlobalRefs.character_system.get_fp(char_uid))
	if current_fp > 0:
		GlobalRefs.character_system.subtract_fp(char_uid, current_fp)


func _get_attribute_value(char_uid: int, attribute_name: String) -> int:
	"""Get attribute value for character (Phase 1: always 0, placeholder for future expansion).
	
	Args:
		char_uid: Character UID.
		attribute_name: e.g., "cunning", "reflex".
		
	Returns:
		Attribute value (0 if not implemented).
	"""
	var character: Object = GameState.characters.get(char_uid, null)
	if character == null:
		return 0
	if character.has_method("get") and character.get("attributes") is Dictionary:
		return int(character.attributes.get(attribute_name, 0))
	return 0

--- Start of ./src/core/systems/progression_system.gd ---

extends Node

func _ready():
	GlobalRefs.set_progression_system(self)
	print("ProgressionSystem Ready.")

--- Start of ./src/core/systems/time_system.gd ---

# File: core/systems/time_system.gd
# Purpose: Manages the passage of abstract game time (TU) and triggers world events.
# Version: 2.0 - Refactored to be stateless and correctly apply player upkeep.

extends Node

func _ready():
	GlobalRefs.set_time_system(self)
	print("TimeSystem Ready.")


# --- Public API ---
func add_time_units(tu_to_add: int):
	if tu_to_add <= 0:
		return

	GameState.current_tu += tu_to_add

	# Emit signal for UI updates every time TU is added
	if EventBus and EventBus.has_signal("time_units_added"):
		EventBus.emit_signal("time_units_added", tu_to_add)

	while GameState.current_tu >= Constants.TIME_CLOCK_MAX_TU:
		_trigger_world_event_tick()


func get_current_tu() -> int:
	return GameState.current_tu


# --- Private Logic ---
func _trigger_world_event_tick():
	# 1. Decrement the clock by the max amount for one tick.
	GameState.current_tu -= Constants.TIME_CLOCK_MAX_TU

	#print("--- WORLD EVENT TICK TRIGGERED ---")

	# 2. Emit the global signal with the amount of TU that this tick represents.
	if EventBus:
		EventBus.emit_signal("world_event_tick_triggered", Constants.TIME_CLOCK_MAX_TU)

	# 3. Call the Character System to apply the WP Upkeep cost for the player character.
	if is_instance_valid(GlobalRefs.character_system):
		var player_uid = GlobalRefs.character_system.get_player_character_uid()
		if player_uid != -1:
			GlobalRefs.character_system.apply_upkeep_cost(player_uid, Constants.DEFAULT_UPKEEP_COST)

--- Start of ./src/core/systems/trading_system.gd ---

# File: core/systems/trading_system.gd
# Purpose: Provides a stateless API for trading commodities between characters and locations.
# Version: 1.0

extends Node


func _ready():
	GlobalRefs.set_trading_system(self)
	print("TradingSystem Ready.")


# --- Public API ---


# Checks if a character can buy a commodity from a location.
# Returns: {success: bool, reason: String, total_cost: int}
func can_buy(char_uid: int, location_id: String, commodity_id: String, quantity: int) -> Dictionary:
	var result = {"success": false, "reason": "", "total_cost": 0}
	
	# Validate inputs
	if quantity <= 0:
		result.reason = "Invalid quantity"
		return result
	
	# Check location exists
	if not GameState.locations.has(location_id):
		result.reason = "Location not found"
		return result
	
	var location = GameState.locations[location_id]
	
	# Check location has this commodity
	if not location.market_inventory.has(commodity_id):
		result.reason = "Commodity not available at this location"
		return result
	
	var market_entry = location.market_inventory[commodity_id]
	
	# Check sufficient quantity at market
	if market_entry.quantity < quantity:
		result.reason = "Insufficient stock (available: %d)" % market_entry.quantity
		return result
	
	# Calculate total cost (use buy_price if available, else price)
	var unit_price = market_entry.get("buy_price", market_entry.get("price", 0))
	var total_cost = unit_price * quantity
	result.total_cost = total_cost
	
	# Check character has enough WP
	if not is_instance_valid(GlobalRefs.character_system):
		result.reason = "Character system unavailable"
		return result
	
	var current_wp = GlobalRefs.character_system.get_wp(char_uid)
	if current_wp < total_cost:
		result.reason = "Insufficient funds (need: %d WP, have: %d WP)" % [total_cost, current_wp]
		return result
	
	# Check cargo capacity
	var cargo_check = _check_cargo_capacity(char_uid, quantity)
	if not cargo_check.has_space:
		result.reason = "Insufficient cargo space (need: %d, available: %d)" % [quantity, cargo_check.available]
		return result
	
	result.success = true
	result.reason = "OK"
	return result


# Executes a buy transaction.
# Returns: {success: bool, reason: String, wp_spent: int, quantity_bought: int}
func execute_buy(char_uid: int, location_id: String, commodity_id: String, quantity: int) -> Dictionary:
	var result = {"success": false, "reason": "", "wp_spent": 0, "quantity_bought": 0}
	
	# First check if we can buy
	var can_buy_result = can_buy(char_uid, location_id, commodity_id, quantity)
	if not can_buy_result.success:
		result.reason = can_buy_result.reason
		return result
	
	var total_cost = can_buy_result.total_cost
	var location = GameState.locations[location_id]
	
	# Execute transaction
	# 1. Deduct WP from character
	GlobalRefs.character_system.subtract_wp(char_uid, total_cost)
	
	# 2. Add commodity to character inventory
	GlobalRefs.inventory_system.add_asset(
		char_uid, 
		GlobalRefs.inventory_system.InventoryType.COMMODITY, 
		commodity_id, 
		quantity
	)
	
	# 3. Reduce market inventory
	location.market_inventory[commodity_id].quantity -= quantity
	
	# 4. Track session stats
	GameState.session_stats.total_wp_spent += total_cost
	
	# 5. Emit signal
	EventBus.emit_signal("trade_transaction_completed", {
		"type": "buy",
		"char_uid": char_uid,
		"location_id": location_id,
		"commodity_id": commodity_id,
		"quantity": quantity,
		"total_price": total_cost
	})
	
	result.success = true
	result.reason = "OK"
	result.wp_spent = total_cost
	result.quantity_bought = quantity
	return result


# Checks if a character can sell a commodity at a location.
# Returns: {success: bool, reason: String, total_value: int}
func can_sell(char_uid: int, location_id: String, commodity_id: String, quantity: int) -> Dictionary:
	var result = {"success": false, "reason": "", "total_value": 0}
	
	# Validate inputs
	if quantity <= 0:
		result.reason = "Invalid quantity"
		return result
	
	# Check location exists
	if not GameState.locations.has(location_id):
		result.reason = "Location not found"
		return result
	
	var location = GameState.locations[location_id]
	
	# Check location accepts this commodity (has a price for it)
	if not location.market_inventory.has(commodity_id):
		result.reason = "This location does not trade in this commodity"
		return result
	
	# Check character has the commodity
	if not is_instance_valid(GlobalRefs.inventory_system):
		result.reason = "Inventory system unavailable"
		return result
	
	var owned_quantity = GlobalRefs.inventory_system.get_asset_count(
		char_uid, 
		GlobalRefs.inventory_system.InventoryType.COMMODITY, 
		commodity_id
	)
	
	if owned_quantity < quantity:
		result.reason = "Insufficient cargo (have: %d, trying to sell: %d)" % [owned_quantity, quantity]
		return result
	
	# Calculate value (use sell_price if available, else price)
	var market_entry = location.market_inventory[commodity_id]
	var unit_price = market_entry.get("sell_price", market_entry.get("price", 0))
	var total_value = unit_price * quantity
	result.total_value = total_value
	
	result.success = true
	result.reason = "OK"
	return result


# Executes a sell transaction.
# Returns: {success: bool, reason: String, wp_earned: int, quantity_sold: int}
func execute_sell(char_uid: int, location_id: String, commodity_id: String, quantity: int) -> Dictionary:
	var result = {"success": false, "reason": "", "wp_earned": 0, "quantity_sold": 0}
	
	# First check if we can sell
	var can_sell_result = can_sell(char_uid, location_id, commodity_id, quantity)
	if not can_sell_result.success:
		result.reason = can_sell_result.reason
		return result
	
	var total_value = can_sell_result.total_value
	var location = GameState.locations[location_id]
	
	# Execute transaction
	# 1. Remove commodity from character inventory
	var removed = GlobalRefs.inventory_system.remove_asset(
		char_uid, 
		GlobalRefs.inventory_system.InventoryType.COMMODITY, 
		commodity_id, 
		quantity
	)
	
	if not removed:
		result.reason = "Failed to remove commodity from inventory"
		return result
	
	# 2. Add WP to character
	GlobalRefs.character_system.add_wp(char_uid, total_value)
	
	# 3. Increase market inventory
	location.market_inventory[commodity_id].quantity += quantity
	
	# 4. Track session stats
	GameState.session_stats.total_wp_earned += total_value
	
	# 5. Emit signal
	EventBus.emit_signal("trade_transaction_completed", {
		"type": "sell",
		"char_uid": char_uid,
		"location_id": location_id,
		"commodity_id": commodity_id,
		"quantity": quantity,
		"total_price": total_value
	})
	
	result.success = true
	result.reason = "OK"
	result.wp_earned = total_value
	result.quantity_sold = quantity
	return result


# Gets the market prices at a location.
# Returns: Dictionary of commodity_id -> {price: int, quantity: int}
func get_market_prices(location_id: String) -> Dictionary:
	if not GameState.locations.has(location_id):
		return {}
	
	var location = GameState.locations[location_id]
	# Return a copy to prevent external modification
	return location.market_inventory.duplicate(true)


# Gets all commodities the player owns.
# Returns: Dictionary of commodity_id -> quantity
func get_player_cargo(char_uid: int) -> Dictionary:
	if not is_instance_valid(GlobalRefs.inventory_system):
		return {}
	
	return GlobalRefs.inventory_system.get_inventory_by_type(
		char_uid,
		GlobalRefs.inventory_system.InventoryType.COMMODITY
	)


# --- Private Helpers ---


# Checks if character's ship has cargo space for additional items.
# Returns: {has_space: bool, available: int, capacity: int, used: int}
func _check_cargo_capacity(char_uid: int, additional_quantity: int) -> Dictionary:
	var result = {"has_space": false, "available": 0, "capacity": 0, "used": 0}
	
	# Get ship's cargo capacity
	if not is_instance_valid(GlobalRefs.asset_system):
		return result
	
	var ship = GlobalRefs.asset_system.get_ship_for_character(char_uid)
	if not is_instance_valid(ship):
		return result
	
	result.capacity = ship.cargo_capacity
	
	# Calculate current cargo usage
	var cargo = get_player_cargo(char_uid)
	var total_used = 0
	for commodity_id in cargo:
		total_used += cargo[commodity_id]
	
	result.used = total_used
	result.available = result.capacity - result.used
	result.has_space = result.available >= additional_quantity
	
	return result


# Gets cargo capacity info for UI display.
# Returns: {capacity: int, used: int, available: int}
func get_cargo_info(char_uid: int) -> Dictionary:
	return _check_cargo_capacity(char_uid, 0)

--- Start of ./src/core/systems/traffic_system.gd ---

extends Node

func _ready():
	GlobalRefs.set_traffic_system(self)
	print("TrafficSystem Ready.")

--- Start of ./src/core/systems/world_map_system.gd ---

extends Node

func _ready():
	GlobalRefs.set_world_map_system(self)
	print("WorldMapSystem Ready.")

--- Start of ./src/core/ui/action_check/action_check.gd ---

# File: core/ui/action_check/action_check.gd
# Purpose: Modal UI for resolving Narrative Actions (Risky/Cautious + FP spend).
# Version: 1.0

extends Control

onready var label_title = $Panel/VBoxContainer/LabelTitle
onready var label_description = $Panel/VBoxContainer/LabelDescription
onready var btn_cautious = $Panel/VBoxContainer/HBoxApproach/BtnCautious
onready var btn_risky = $Panel/VBoxContainer/HBoxApproach/BtnRisky
onready var spinbox_fp = $Panel/VBoxContainer/HBoxFP/SpinBoxFP
onready var label_current_fp = $Panel/VBoxContainer/LabelCurrentFP
onready var btn_confirm = $Panel/VBoxContainer/BtnConfirm
onready var vbox_result = $Panel/VBoxContainer/VBoxResult
onready var label_roll_result = $Panel/VBoxContainer/VBoxResult/LabelRollResult
onready var label_outcome_desc = $Panel/VBoxContainer/VBoxResult/LabelOutcomeDesc
onready var label_effects = $Panel/VBoxContainer/VBoxResult/LabelEffects
onready var btn_continue = $Panel/VBoxContainer/VBoxResult/BtnContinue

var _selected_approach: int = Constants.ActionApproach.CAUTIOUS
var _action_data: Dictionary = {}


func _ready():
	visible = false
	vbox_result.visible = false

	# Ensure approach buttons behave like a selection.
	btn_cautious.toggle_mode = true
	btn_risky.toggle_mode = true

	btn_cautious.connect("pressed", self, "_on_cautious_pressed")
	btn_risky.connect("pressed", self, "_on_risky_pressed")
	btn_confirm.connect("pressed", self, "_on_confirm_pressed")
	btn_continue.connect("pressed", self, "_on_continue_pressed")

	# EventBus signature is (action_type, context). We accept both args.
	EventBus.connect("narrative_action_requested", self, "_on_action_requested")


func _on_action_requested(action_type, action_data: Dictionary):
	# action_type is provided by EventBus; action_data should include full context.
	_action_data = action_data
	# Ensure action_type exists for UI title mapping.
	if not _action_data.has("action_type"):
		_action_data["action_type"] = str(action_type)
	_show_selection_ui()


func _show_selection_ui():
	visible = true
	vbox_result.visible = false
	btn_confirm.visible = true

	label_title.text = _get_action_title(str(_action_data.get("action_type", "")))
	var ctx: Dictionary = _action_data.get("context", {})
	label_description.text = str(ctx.get("description", "Resolve this action."))

	var char_uid = int(_action_data.get("char_uid", GameState.player_character_uid))
	var current_fp = 0
	if is_instance_valid(GlobalRefs.character_system):
		current_fp = int(GlobalRefs.character_system.get_fp(char_uid))

	label_current_fp.text = "Available: %d FP" % current_fp

	# SpinBox uses floats.
	var max_fp = min(Constants.FOCUS_MAX_DEFAULT, current_fp)
	spinbox_fp.max_value = float(max_fp)
	spinbox_fp.value = 0.0

	_select_approach(Constants.ActionApproach.CAUTIOUS)


func _select_approach(approach: int):
	_selected_approach = approach
	btn_cautious.pressed = (approach == Constants.ActionApproach.CAUTIOUS)
	btn_risky.pressed = (approach == Constants.ActionApproach.RISKY)


func _on_cautious_pressed():
	_select_approach(Constants.ActionApproach.CAUTIOUS)


func _on_risky_pressed():
	_select_approach(Constants.ActionApproach.RISKY)


func _on_confirm_pressed():
	var fp_spent = int(spinbox_fp.value)
	var narrative_system = _get_narrative_action_system()
	if narrative_system == null or not narrative_system.has_method("resolve_action"):
		_show_result({
			"success": false,
			"roll_result": {"roll_total": 0, "tier_name": "Failure"},
			"outcome": {"description": "NarrativeActionSystem unavailable.", "effects": {}},
			"effects_applied": {},
			"action_type": str(_action_data.get("action_type", ""))
		})
		return

	var result = narrative_system.resolve_action(_selected_approach, fp_spent)
	_show_result(result)


func _show_result(result: Dictionary):
	btn_confirm.visible = false
	vbox_result.visible = true

	if not result.get("success", true):
		label_roll_result.text = "Roll: 0 → Failure"
		label_outcome_desc.bbcode_text = "[i]%s[/i]" % str(result.get("reason", "Failed to resolve action."))
		label_effects.text = "No additional effects."
		return

	var roll = result.get("roll_result", {})
	label_roll_result.text = "Roll: %d → %s" % [int(roll.get("roll_total", 0)), str(roll.get("tier_name", ""))]

	var outcome = result.get("outcome", {})
	label_outcome_desc.bbcode_text = "[i]%s[/i]" % str(outcome.get("description", ""))

	var effects_text = _format_effects(result.get("effects_applied", {}))
	label_effects.text = effects_text if effects_text != "" else "No additional effects."


func _format_effects(effects: Dictionary) -> String:
	var parts = []
	if effects.has("wp_lost"):
		parts.append("-%d WP" % int(effects.get("wp_lost", 0)))
	if effects.has("wp_gained"):
		parts.append("+%d WP" % int(effects.get("wp_gained", 0)))
	if effects.has("fp_gained"):
		parts.append("+%d FP" % int(effects.get("fp_gained", 0)))
	if effects.has("quirk_added"):
		parts.append("Quirk: %s" % str(effects.get("quirk_added")))
	if effects.has("reputation_changed"):
		var rep = int(effects.get("reputation_changed", 0))
		parts.append("%+d Reputation" % rep)
	return PoolStringArray(parts).join(", ")


func _on_continue_pressed():
	visible = false
	_action_data = {}


func _get_action_title(action_type: String) -> String:
	match action_type:
		"contract_complete":
			return "Finalize Delivery"
		"dock_arrival":
			return "Execute Approach"
		"trade_finalize":
			return "Seal the Deal"
		_:
			return "Resolve Action"


func _get_narrative_action_system():
	# Task 7 will add GlobalRefs.narrative_action_system; until then use Object.get().
	var sys = null
	if GlobalRefs:
		sys = GlobalRefs.get("narrative_action_system")
	if is_instance_valid(sys):
		return sys
	return get_node_or_null("/root/NarrativeActionSystem")

--- Start of ./src/core/ui/character_status/character_status.gd ---

extends Control

onready var label_skill_piloting: Label = $Panel/VBoxContainer/HBoxContent/VBoxStats/LabelSkillPiloting
onready var label_skill_trading: Label = $Panel/VBoxContainer/HBoxContent/VBoxStats/LabelSkillTrading
onready var list_contracts: ItemList = $Panel/VBoxContainer/HBoxContent/VBoxContracts/ItemListContracts
onready var text_details: RichTextLabel = $Panel/VBoxContainer/HBoxContent/VBoxContracts/RichTextLabelDetails
onready var btn_close: Button = $Panel/VBoxContainer/ButtonClose
onready var btn_add_wp: Button = $Panel/VBoxContainer/HBoxContent/VBoxStats/ButtonAddWP
onready var btn_add_fp: Button = $Panel/VBoxContainer/HBoxContent/VBoxStats/ButtonAddFP
onready var btn_trigger_encounter: Button = $Panel/VBoxContainer/HBoxContent/VBoxStats/ButtonTriggerEncounter

func _ready():
	GlobalRefs.set_character_status(self)
	btn_close.connect("pressed", self, "_on_ButtonClose_pressed")
	btn_add_wp.connect("pressed", self, "_on_ButtonAddWP_pressed")
	btn_add_fp.connect("pressed", self, "_on_ButtonAddFP_pressed")
	btn_trigger_encounter.connect("pressed", self, "_on_ButtonTriggerEncounter_pressed")
	list_contracts.connect("item_selected", self, "_on_contract_selected")
	
	# Listen for contract updates to refresh if open
	EventBus.connect("contract_accepted", self, "_on_contract_update")
	EventBus.connect("contract_completed", self, "_on_contract_update")
	EventBus.connect("contract_failed", self, "_on_contract_update")
	EventBus.connect("contract_abandoned", self, "_on_contract_update")

func open_screen():
	update_display()
	self.show()

func update_display():
	# Update Skills
	if GlobalRefs.character_system:
		var char_data = GlobalRefs.character_system.get_player_character()
		if char_data:
			var piloting_skill = char_data.skills.get("piloting", 0)
			var trading_skill = char_data.skills.get("trading", 0)
			label_skill_piloting.text = "Piloting: " + str(piloting_skill)
			label_skill_trading.text = "Trading: " + str(trading_skill)
	
	# Update Contracts
	refresh_contracts()

func refresh_contracts():
	list_contracts.clear()
	text_details.text = "Select a contract to view details."
	
	if GlobalRefs.contract_system:
		var active_contracts = GlobalRefs.contract_system.get_active_contracts(GameState.player_character_uid)
		
		for contract in active_contracts:
			var text = "%s (%s)" % [contract.title, contract.contract_type]
			list_contracts.add_item(text)
			# Store contract_id (template_id) as metadata
			list_contracts.set_item_metadata(list_contracts.get_item_count() - 1, contract.template_id)

func _on_contract_selected(index):
	var contract_id = list_contracts.get_item_metadata(index)
	if GameState.active_contracts.has(contract_id):
		var contract = GameState.active_contracts[contract_id]
		_display_contract_details(contract)

func _display_contract_details(contract):
	var details = "Title: %s\n" % contract.title
	details += "Type: %s\n" % contract.contract_type
	details += "Reward: %d WP\n" % contract.reward_wp
	details += "Time Limit: %d TU\n" % contract.time_limit_tu
	
	# Calculate remaining time
	if contract.time_limit_tu > 0 and contract.accepted_at_tu >= 0:
		var elapsed = GameState.current_tu - contract.accepted_at_tu
		var remaining = contract.time_limit_tu - elapsed
		details += "Time Remaining: %d TU\n" % remaining
	
	details += "\nDescription:\n%s\n\n" % contract.description
	
	if contract.contract_type == "delivery":
		details += "Cargo Required: %s (Qty: %d)\n" % [contract.required_commodity_id, contract.required_quantity]
		details += "Destination: %s\n" % contract.destination_location_id
		
		# Check progress
		var inv_count = 0
		if GlobalRefs.inventory_system:
			inv_count = GlobalRefs.inventory_system.get_asset_count(
				GameState.player_character_uid, 
				GlobalRefs.inventory_system.InventoryType.COMMODITY, 
				contract.required_commodity_id
			)
		details += "Current Cargo: %d / %d\n" % [inv_count, contract.required_quantity]
	
	text_details.text = details

func _on_contract_update(_a = null, _b = null):
	if visible:
		refresh_contracts()

func _on_ButtonClose_pressed():
	self.hide()

func _on_ButtonAddWP_pressed():
	if GlobalRefs.character_system:
		GlobalRefs.character_system.add_wp(GameState.player_character_uid, 10)

func _on_ButtonAddFP_pressed():
	if GlobalRefs.character_system:
		GlobalRefs.character_system.add_fp(GameState.player_character_uid, 1)


func _on_ButtonTriggerEncounter_pressed():
	"""Debug button: Forces an immediate combat encounter spawn."""
	if GlobalRefs.event_system and GlobalRefs.event_system.has_method("force_encounter"):
		GlobalRefs.event_system.force_encounter()
		print("[CharacterStatus] Debug: Forced encounter triggered")
	else:
		printerr("[CharacterStatus] EventSystem not available or missing force_encounter method")

--- Start of ./src/core/ui/helpers/CenteredGrowingLabel.gd ---

# File: res://core/ui/ui_helper_classes/CenteredGrowingLabel.gd
# Makes labels center-aligned in parent at runtime.
# Version: 1.0

class_name CenteredGrowingLabel, "res://assets/art/ui/class_labels/class_centered_growing_label.svg"
extends Label

# --- Static Group Name ---
const AUTO_GROUP_NAME = "centered_growing_labels"

# --- Internal ---
var _is_ready_for_recenter = false


func _enter_tree():
	if not is_in_group(AUTO_GROUP_NAME):
		add_to_group(AUTO_GROUP_NAME)
	if not is_connected("resized", self, "_on_self_resized"):
		connect("resized", self, "_on_self_resized")
	call_deferred("_initial_setup_and_recenter")


func _initial_setup_and_recenter():
	_is_ready_for_recenter = true
	_recenter_in_parent()
	self.focus_mode = Control.FOCUS_NONE


func _exit_tree():
	if is_in_group(AUTO_GROUP_NAME):
		remove_from_group(AUTO_GROUP_NAME)
	if is_connected("resized", self, "_on_self_resized"):
		disconnect("resized", self, "_on_self_resized")


func _on_self_resized():
	_recenter_in_parent()


func _recenter_in_parent():
	if not _is_ready_for_recenter:
		return
	var parent_control = get_parent_control()
	if parent_control:
		var current_label_size = self.rect_size
		var parent_size = parent_control.rect_size
		var new_pos_x = (parent_size.x - current_label_size.x) / 2.0
		var new_pos_y = (parent_size.y - current_label_size.y) / 2.0
		if (
			not is_equal_approx(rect_position.x, new_pos_x)
			or not is_equal_approx(rect_position.y, new_pos_y)
		):
			self.rect_position = Vector2(new_pos_x, new_pos_y)


func get_parent_control() -> Control:
	var p = get_parent()
	if p is Control:
		return p
	return null

--- Start of ./src/core/ui/inventory_screen/inventory_screen.gd ---

# File: src/core/ui/inventory_screen/inventory_screen.gd
# Script for the player inventory UI.
# Version: 1.0 - Initial.

extends Control

# Preload the InventorySystem script to access its enums
const InventorySystem = preload("res://src/core/systems/inventory_system.gd")

# --- Node References ---
onready var ShipList = $Panel/VBoxMain/HBoxContent/VBoxCategories/CategoryTabs/Ships/ShipList
onready var ModuleList = $Panel/VBoxMain/HBoxContent/VBoxCategories/CategoryTabs/Modules/ModuleList
onready var CommodityList = $Panel/VBoxMain/HBoxContent/VBoxCategories/CategoryTabs/Commodities/CommodityList

# --- Detail Panel Node References ---
onready var LabelName = $Panel/VBoxMain/HBoxContent/VBoxDetails/LabelName
onready var LabelDescription = $Panel/VBoxMain/HBoxContent/VBoxDetails/ScrollContainer/LabelDescription
onready var LabelStat1 = $Panel/VBoxMain/HBoxContent/VBoxDetails/LabelStat1
onready var LabelStat2 = $Panel/VBoxMain/HBoxContent/VBoxDetails/LabelStat2
onready var LabelStat3 = $Panel/VBoxMain/HBoxContent/VBoxDetails/LabelStat3


func _ready():
	GlobalRefs.set_inventory_screen(self)

	# Connect the item selection signals for each list
	ShipList.connect("item_selected", self, "_on_ShipList_item_selected")
	ModuleList.connect("item_selected", self, "_on_ModuleList_item_selected")
	CommodityList.connect("item_selected", self, "_on_CommodityList_item_selected")


func open_screen():
	_clear_details()  # Clear details panel when opening
	_populate_all_lists()

	self.show()


# Populates all three asset lists with data from the GameState via the system APIs.
func _populate_all_lists():
	# 1. Get Player UID
	if (
		not is_instance_valid(GlobalRefs.character_system)
		or not is_instance_valid(GlobalRefs.inventory_system)
		or not is_instance_valid(GlobalRefs.asset_system)
	):
		printerr("HangarScreen Error: Core systems not available in GlobalRefs.")
		return

	var player_uid = GlobalRefs.character_system.get_player_character_uid()
	if player_uid == -1:
		printerr("HangarScreen Error: Could not get a valid player UID.")
		return

	# 2. Clear existing lists
	ShipList.clear()
	ModuleList.clear()
	CommodityList.clear()

	# --- 3. Populate Ship List ---
	var ship_inventory = GlobalRefs.inventory_system.get_inventory_by_type(
		player_uid, InventorySystem.InventoryType.SHIP
	)
	for ship_uid in ship_inventory:
		var ship_resource = GlobalRefs.asset_system.get_ship(ship_uid)
		if is_instance_valid(ship_resource):
			ShipList.add_item(ship_resource.ship_model_name)
			# Store the UID for when the item is selected
			ShipList.set_item_metadata(ShipList.get_item_count() - 1, ship_uid)
		else:
			printerr("HangarScreen Error: Could not find ship asset for UID: ", ship_uid)

	# --- 4. Populate Module List ---
	var module_inventory = GlobalRefs.inventory_system.get_inventory_by_type(
		player_uid, InventorySystem.InventoryType.MODULE
	)
	for module_uid in module_inventory:
		# AssetSystem API doesn't have a get_module, so we access GameState directly
		var module_resource = GameState.assets_modules.get(module_uid)
		if is_instance_valid(module_resource):
			ModuleList.add_item(module_resource.module_name)
			ModuleList.set_item_metadata(ModuleList.get_item_count() - 1, module_uid)
		else:
			printerr("HangarScreen Error: Could not find module asset for UID: ", module_uid)

	# --- 5. Populate Commodity List ---
	var commodity_inventory = GlobalRefs.inventory_system.get_inventory_by_type(
		player_uid, InventorySystem.InventoryType.COMMODITY
	)
	for template_id in commodity_inventory:
		if TemplateDatabase.assets_commodities.has(template_id):
			var commodity_template = TemplateDatabase.assets_commodities[template_id]
			var quantity = commodity_inventory[template_id]

			# Display name and quantity in the list
			var item_text = "%s (x%d)" % [commodity_template.commodity_name, quantity]
			CommodityList.add_item(item_text)
			# Store the template_id for when the item is selected
			CommodityList.set_item_metadata(CommodityList.get_item_count() - 1, template_id)
		else:
			printerr("HangarScreen Error: Could not find commodity template for ID: ", template_id)


# --- Signal Handlers ---


# Clears the details panel text.
func _clear_details():
	LabelName.text = "Select an item"
	LabelDescription.text = ""
	LabelStat1.text = ""
	LabelStat2.text = ""
	LabelStat3.text = ""


func _on_ShipList_item_selected(index):
	var ship_uid = ShipList.get_item_metadata(index)
	var ship_resource = GlobalRefs.asset_system.get_ship(ship_uid)

	if is_instance_valid(ship_resource):
		_clear_details()
		LabelName.text = ship_resource.ship_model_name
		LabelDescription.text = "Ship Hull"  # Placeholder description
		LabelStat1.text = "Hull: %d" % ship_resource.hull_integrity
		LabelStat2.text = "Armor: %d" % ship_resource.armor_integrity
		LabelStat3.text = "Cargo: %d" % ship_resource.cargo_capacity
	else:
		_clear_details()
		LabelName.text = "Error: Ship not found"


func _on_ModuleList_item_selected(index):
	var module_uid = ModuleList.get_item_metadata(index)
	var module_resource = GameState.assets_modules.get(module_uid)

	if is_instance_valid(module_resource):
		_clear_details()
		LabelName.text = module_resource.module_name
		LabelDescription.text = "Ship Module"  # Placeholder description
		LabelStat1.text = "Base Value: %d WP" % module_resource.base_value
	else:
		_clear_details()
		LabelName.text = "Error: Module not found"


func _on_CommodityList_item_selected(index):
	var template_id = CommodityList.get_item_metadata(index)
	var commodity_template = TemplateDatabase.assets_commodities.get(template_id)

	if is_instance_valid(commodity_template):
		var player_uid = GlobalRefs.character_system.get_player_character_uid()
		var quantity = GlobalRefs.inventory_system.get_asset_count(
			player_uid, InventorySystem.InventoryType.COMMODITY, template_id
		)

		_clear_details()
		LabelName.text = commodity_template.commodity_name
		LabelDescription.text = "Trade Good"  # Placeholder description
		LabelStat1.text = "Quantity: %d" % quantity
		LabelStat2.text = "Base Value: %d WP" % commodity_template.base_value
	else:
		_clear_details()
		LabelName.text = "Error: Commodity not found"


func _on_ButtonClose_pressed():
	self.hide()

--- Start of ./src/core/ui/main_hud/main_hud.gd ---

# File: res://core/ui/main_hud/main_hud.gd
# Script for the main HUD container. Handles displaying targeting info, etc.
# Version: 1.2 - Integrating systems.

extends Control

# --- Nodes ---
onready var targeting_indicator: Control = $TargetingIndicator
onready var label_wp: Label = $ScreenControls/TopLeftZone/LabelWP
onready var label_fp: Label = $ScreenControls/TopLeftZone/LabelFP
onready var label_tu: Label = $ScreenControls/TopLeftZone/LabelTU
onready var label_player_hull: Label = $ScreenControls/TopLeftZone/LabelPlayerHull
onready var player_hull_bar: ProgressBar = $ScreenControls/TopLeftZone/PlayerHullBar
onready var button_character: Button = $ScreenControls/TopLeftZone/ButtonCharacter
onready var button_menu: TextureButton = $ScreenControls/CenterLeftZone/ButtonMenu
onready var docking_prompt: Control = $ScreenControls/TopCenterZone/DockingPrompt
onready var docking_label: Label = $ScreenControls/TopCenterZone/DockingPrompt/Label

# --- Game Over UI ---
onready var game_over_overlay: Control = $GameOverOverlay
onready var button_return_to_menu: Button = $GameOverOverlay/CenterContainer/PanelContainer/VBoxContainer/ButtonReturnToMenu

# --- Combat HUD Nodes ---
onready var target_info_panel: PanelContainer = $ScreenControls/TopCenterZone/TargetInfoPanel
onready var label_target_name: Label = $ScreenControls/TopCenterZone/TargetInfoPanel/VBoxContainer/LabelTargetName
onready var target_hull_bar: ProgressBar = $ScreenControls/TopCenterZone/TargetInfoPanel/VBoxContainer/TargetHullBar

const StationMenuScene = preload("res://scenes/ui/menus/station_menu/StationMenu.tscn")
var station_menu_instance = null

const ActionCheckScene = preload("res://scenes/ui/screens/action_check.tscn")
var action_check_instance = null

# --- State ---
var _current_target: Spatial = null
var _main_camera: Camera = null
var _current_target_uid: int = -1  # UID of current combat target for hull tracking
var _player_uid: int = -1
var _is_game_over: bool = false
var _action_feedback_popup: AcceptDialog = null  # Popup for dock/attack feedback


# --- Initialization ---
func _ready():
	GlobalRefs.set_main_hud(self)
	
	# Instantiate Station Menu
	station_menu_instance = StationMenuScene.instance()
	add_child(station_menu_instance)
	# It starts hidden by default in its own _ready

	# Instantiate Action Check UI (hidden by default; shown via EventBus)
	action_check_instance = ActionCheckScene.instance()
	add_child(action_check_instance)

	# Ensure indicator starts hidden
	targeting_indicator.visible = false

	# Get camera reference once
	_main_camera = get_viewport().get_camera()  # Initial attempt
	if not is_instance_valid(_main_camera) and is_instance_valid(GlobalRefs.main_camera):
		_main_camera = GlobalRefs.main_camera  # Fallback via GlobalRefs

	if not is_instance_valid(_main_camera):
		printerr("MainHUD Error: Could not get a valid camera reference!")
		set_process(false)  # Disable processing if no camera

	# Connect to EventBus signals
	if EventBus:
		if not EventBus.is_connected("player_target_selected", self, "_on_Player_Target_Selected"):
			EventBus.connect("player_target_selected", self, "_on_Player_Target_Selected")

		if not EventBus.is_connected(
			"player_target_deselected", self, "_on_Player_Target_Deselected"
		):
			EventBus.connect("player_target_deselected", self, "_on_Player_Target_Deselected")

		if not EventBus.is_connected("player_wp_changed", self, "_on_player_wp_changed"):
			EventBus.connect("player_wp_changed", self, "_on_player_wp_changed")

		if not EventBus.is_connected("player_fp_changed", self, "_on_player_fp_changed"):
			EventBus.connect("player_fp_changed", self, "_on_player_fp_changed")

		if not EventBus.is_connected("world_event_tick_triggered", self, "_on_world_event_tick_triggered"):
			EventBus.connect("world_event_tick_triggered", self, "_on_world_event_tick_triggered")

		if EventBus.has_signal("time_units_added") and not EventBus.is_connected("time_units_added", self, "_on_time_units_added"):
			EventBus.connect("time_units_added", self, "_on_time_units_added")
			
		EventBus.connect("dock_available", self, "_on_dock_available")
		EventBus.connect("dock_unavailable", self, "_on_dock_unavailable")
		EventBus.connect("player_docked", self, "_on_player_docked")
		
		# Dock/Attack feedback signals
		EventBus.connect("dock_action_feedback", self, "_on_dock_action_feedback")
		EventBus.connect("attack_action_feedback", self, "_on_attack_action_feedback")

		# Combat flow (Phase 1: debug feedback)
		if not EventBus.is_connected("combat_initiated", self, "_on_combat_initiated"):
			EventBus.connect("combat_initiated", self, "_on_combat_initiated")
		if not EventBus.is_connected("combat_ended", self, "_on_combat_ended"):
			EventBus.connect("combat_ended", self, "_on_combat_ended")
		if not EventBus.is_connected("agent_damaged", self, "_on_agent_damaged"):
			EventBus.connect("agent_damaged", self, "_on_agent_damaged")
		if not EventBus.is_connected("agent_disabled", self, "_on_agent_disabled"):
			EventBus.connect("agent_disabled", self, "_on_agent_disabled")
		if not EventBus.is_connected("agent_despawning", self, "_on_agent_despawning"):
			EventBus.connect("agent_despawning", self, "_on_agent_despawning")
		if not EventBus.is_connected("new_game_requested", self, "_on_new_game_requested"):
			EventBus.connect("new_game_requested", self, "_on_new_game_requested")
		if not EventBus.is_connected("game_state_loaded", self, "_on_game_state_loaded"):
			EventBus.connect("game_state_loaded", self, "_on_game_state_loaded")

	else:
		printerr("MainHUD Error: EventBus not available!")

	# Connect to CombatSystem signals for hull updates (deferred to allow system init)
	call_deferred("_connect_combat_signals")
	call_deferred("_refresh_player_resources")
	call_deferred("_deferred_refresh_player_hull")
	
	# Ensure target info panel starts hidden
	if target_info_panel:
		target_info_panel.visible = false

	# Connect draw signal for custom drawing (optional, but good for style)
	targeting_indicator.connect("draw", self, "_draw_targeting_indicator")

	# Connect ButtonMenu to open main menu
	if is_instance_valid(button_menu):
		if not button_menu.is_connected("pressed", self, "_on_ButtonMenu_pressed"):
			button_menu.connect("pressed", self, "_on_ButtonMenu_pressed")

	# Initialize TU display
	_refresh_tu_display()


# --- Process Update ---
func _process(_delta):
	# If the selected target is gone, clear the UI state.
	if _current_target != null and not is_instance_valid(_current_target):
		_on_Player_Target_Deselected()
		return

	# Only update position if a target is selected and valid
	if is_instance_valid(_current_target) and is_instance_valid(_main_camera):
		# Project the target's 3D origin position to 2D screen coordinates
		var screen_pos: Vector2 = _main_camera.unproject_position(
			_current_target.global_transform.origin
		)

		# Check if the target is behind the camera
		var target_dir = (_current_target.global_transform.origin - _main_camera.global_transform.origin).normalized()
		var camera_fwd = -_main_camera.global_transform.basis.z.normalized()
		var is_in_front = target_dir.dot(camera_fwd) >= 0  # Use >= 0 to include exactly perpendicular

		# --- MODIFIED Visibility Logic ---
		# Set visibility based on whether the target is in front
		targeting_indicator.visible = is_in_front

		# Only update position and redraw if it's actually visible
		if targeting_indicator.visible:
			# Update the indicator's position
			targeting_indicator.rect_position = screen_pos - (targeting_indicator.rect_size / 2.0)
			targeting_indicator.update()  # Trigger redraw if using _draw
	else:
		# Ensure indicator is hidden if target becomes invalid or camera is invalid
		if targeting_indicator.visible:
			targeting_indicator.visible = false
		if target_info_panel and target_info_panel.visible:
			target_info_panel.visible = false


# --- Signal Handlers ---
func _on_Player_Target_Selected(target_node: Spatial):
	print(target_node)
	if is_instance_valid(target_node):
		_current_target = target_node
		# Visibility is now primarily handled in _process,
		# but we still need to ensure _process runs.
		# targeting_indicator.visible = true # This line can be removed or kept, _process will override
		set_process(true)  # Ensure _process runs
		
		# Update combat target info panel
		_update_target_info_panel(target_node)
	else:
		_on_Player_Target_Deselected()


func _on_Player_Target_Deselected():
	_current_target = null
	_current_target_uid = -1
	targeting_indicator.visible = false
	if target_info_panel:
		target_info_panel.visible = false
	set_process(false)  # Can disable processing if target is deselected
	_refresh_player_hull()


func _on_agent_despawning(agent_body) -> void:
	# If our selected target is being removed, clear target UI.
	if is_instance_valid(_current_target) and agent_body == _current_target:
		_on_Player_Target_Deselected()


func _on_new_game_requested() -> void:
	# World is about to be reset; clear any stale targeting UI.
	_on_Player_Target_Deselected()
	call_deferred("_deferred_refresh_player_hull")


func _on_game_state_loaded() -> void:
	# After load, clear stale UI and refresh player hull label/bar.
	_on_Player_Target_Deselected()
	call_deferred("_deferred_refresh_player_hull")


func _on_player_wp_changed(_new_wp_value = null):
	_refresh_player_resources()


func _on_player_fp_changed(_new_fp_value = null):
	_refresh_player_resources()


func _refresh_player_resources() -> void:
	if not is_instance_valid(label_wp) or not is_instance_valid(label_fp):
		return
	if not is_instance_valid(GlobalRefs.character_system):
		return
	var player_char = GlobalRefs.character_system.get_player_character()
	if not is_instance_valid(player_char):
		return
	label_wp.text = "Current WP: " + str(player_char.wealth_points)
	label_fp.text = "Current FP: " + str(player_char.focus_points)


func _refresh_tu_display() -> void:
	if not is_instance_valid(label_tu):
		return
	label_tu.text = "Time (TU): " + str(GameState.current_tu)


func _on_world_event_tick_triggered(_tu_amount: int = 0) -> void:
	_refresh_tu_display()
	_refresh_player_resources()


func _on_time_units_added(_tu_added: int = 0) -> void:
	_refresh_tu_display()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if EventBus:
			EventBus.emit_signal("main_menu_requested")
			get_tree().set_input_as_handled()


func _on_ButtonMenu_pressed() -> void:
	"""Handle menu button press - opens main menu."""
	if EventBus:
		EventBus.emit_signal("main_menu_requested")


# --- Custom Drawing (Optional but Recommended) ---
func _draw_targeting_indicator():
	# Example: Draw a simple white rectangle outline
	var _rect = Rect2(Vector2.ZERO, targeting_indicator.rect_size)
	var _line_color = Color.white
	var _line_width = 1.0  # Adjust thickness as needed
	#targeting_indicator.draw_rect(rect, line_color, false, line_width)

	# Example: Draw simple corner brackets
	var size = targeting_indicator.rect_size
	var corner_len = size.x * 0.25  # Length of corner lines
	var color = Color.cyan
	var width = 2.0
	# # Top-left
	targeting_indicator.draw_line(Vector2(0, 0), Vector2(corner_len, 0), color, width)
	targeting_indicator.draw_line(Vector2(0, 0), Vector2(0, corner_len), color, width)
	# # Top-right
	targeting_indicator.draw_line(Vector2(size.x, 0), Vector2(size.x - corner_len, 0), color, width)
	targeting_indicator.draw_line(Vector2(size.x, 0), Vector2(size.x, corner_len), color, width)
	# # Bottom-left
	targeting_indicator.draw_line(Vector2(0, size.y), Vector2(corner_len, size.y), color, width)
	targeting_indicator.draw_line(Vector2(0, size.y), Vector2(0, size.y - corner_len), color, width)
	# # Bottom-right
	targeting_indicator.draw_line(
		Vector2(size.x, size.y), Vector2(size.x - corner_len, size.y), color, width
	)
	targeting_indicator.draw_line(
		Vector2(size.x, size.y), Vector2(size.x, size.y - corner_len), color, width
	)


# --- Cleanup ---
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if EventBus:
			if EventBus.is_connected("player_target_selected", self, "_on_Player_Target_Selected"):
				EventBus.disconnect("player_target_selected", self, "_on_Player_Target_Selected")
			if EventBus.is_connected(
				"player_target_deselected", self, "_on_Player_Target_Deselected"
			):
				EventBus.disconnect(
					"player_target_deselected", self, "_on_Player_Target_Deselected"
				)
			if EventBus.is_connected("combat_initiated", self, "_on_combat_initiated"):
				EventBus.disconnect("combat_initiated", self, "_on_combat_initiated")
			if EventBus.is_connected("combat_ended", self, "_on_combat_ended"):
				EventBus.disconnect("combat_ended", self, "_on_combat_ended")
			if EventBus.is_connected("agent_damaged", self, "_on_agent_damaged"):
				EventBus.disconnect("agent_damaged", self, "_on_agent_damaged")
			if EventBus.is_connected("agent_disabled", self, "_on_agent_disabled"):
				EventBus.disconnect("agent_disabled", self, "_on_agent_disabled")


func _on_combat_initiated(_player_agent, enemy_agents: Array) -> void:
	print("[HUD] Combat initiated with ", enemy_agents.size(), " hostiles")


func _on_combat_ended(result_dict: Dictionary) -> void:
	var outcome = result_dict.get("outcome", "unknown")
	print("[HUD] Combat ended: ", outcome)


func _on_agent_damaged(agent_body, damage_amount: float, _source_agent) -> void:
	if agent_body == GlobalRefs.player_agent_body:
		print("[HUD] Player took ", damage_amount, " damage")
		_refresh_player_hull()


func _on_agent_disabled(agent_body) -> void:
	if _is_game_over:
		return
	if not is_instance_valid(agent_body):
		return
	if not is_instance_valid(GlobalRefs.player_agent_body):
		return
	if agent_body != GlobalRefs.player_agent_body:
		return
	_show_game_over_overlay()


func _show_game_over_overlay() -> void:
	_is_game_over = true
	if is_instance_valid(game_over_overlay):
		game_over_overlay.visible = true
		game_over_overlay.raise()
		if is_instance_valid(button_return_to_menu):
			button_return_to_menu.grab_focus()
	# Pause gameplay while the overlay is visible.
	get_tree().paused = true


func _on_ButtonReturnToMenu_pressed() -> void:
	# Unpause first so the menu and world manager can react normally.
	get_tree().paused = false
	_is_game_over = false
	if is_instance_valid(game_over_overlay):
		game_over_overlay.visible = false
	if EventBus:
		EventBus.emit_signal("main_menu_requested")


func _on_ButtonFreeFlight_pressed():
	if EventBus:
		EventBus.emit_signal("player_free_flight_toggled")


func _on_ButtonStop_pressed():
	if EventBus:
		EventBus.emit_signal("player_stop_pressed")


func _on_ButtonOrbit_pressed():
	if EventBus:
		EventBus.emit_signal("player_orbit_pressed")


func _on_ButtonApproach_pressed():
	if EventBus:
		EventBus.emit_signal("player_approach_pressed")


func _on_ButtonFlee_pressed():
	if EventBus:
		EventBus.emit_signal("player_flee_pressed")

func _on_ButtonInteract_pressed():
	if EventBus:
		EventBus.emit_signal("player_interact_pressed")


func _on_ButtonDock_pressed():
	if EventBus:
		EventBus.emit_signal("player_dock_pressed")


func _on_ButtonAttack_pressed():
	if EventBus:
		EventBus.emit_signal("player_attack_pressed")

func _on_SliderControlLeft_value_changed(value):
	# ZOOM camera slider
	if EventBus:
		EventBus.emit_signal("player_camera_zoom_changed", value)

# --- Docking UI Handlers ---
func _on_dock_available(location_id):
	print("MainHUD: Dock available signal received for ", location_id)
	if docking_prompt:
		docking_prompt.visible = true
		if docking_label:
			docking_label.text = "Docking Available - Press Interact"

func _on_dock_unavailable():
	print("MainHUD: Dock unavailable signal received")
	if docking_prompt:
		docking_prompt.visible = false

func _on_player_docked(_location_id):
	if docking_prompt:
		docking_prompt.visible = false


# --- Dock/Attack Feedback Handlers ---
func _on_dock_action_feedback(success: bool, message: String) -> void:
	_show_action_feedback_popup("Dock", success, message)


func _on_attack_action_feedback(success: bool, message: String) -> void:
	_show_action_feedback_popup("Attack", success, message)


func _show_action_feedback_popup(action_type: String, success: bool, message: String) -> void:
	if not is_instance_valid(_action_feedback_popup):
		_action_feedback_popup = AcceptDialog.new()
		_action_feedback_popup.pause_mode = Node.PAUSE_MODE_PROCESS
		add_child(_action_feedback_popup)
	
	if success:
		_action_feedback_popup.window_title = action_type
	else:
		_action_feedback_popup.window_title = action_type + " Failed"
	
	_action_feedback_popup.dialog_text = message
	_action_feedback_popup.popup_centered()
func _on_SliderControlRight_value_changed(value):
	# SPEED (maximum) limiter.
	# This slider is inverted (rotated by 180) for the sake of appearance.
	if EventBus:
		EventBus.emit_signal("player_ship_speed_changed", value)


func _on_ButtonCharacter_pressed():
	GlobalRefs.character_status.open_screen()


func _on_ButtonInventory_pressed():
	GlobalRefs.inventory_screen.open_screen()


# --- Combat HUD Functions ---

func _connect_combat_signals() -> void:
	"""Connect to CombatSystem signals for hull updates."""
	if is_instance_valid(GlobalRefs.combat_system):
		if not GlobalRefs.combat_system.is_connected("damage_dealt", self, "_on_damage_dealt"):
			GlobalRefs.combat_system.connect("damage_dealt", self, "_on_damage_dealt")
		if not GlobalRefs.combat_system.is_connected("ship_disabled", self, "_on_ship_disabled"):
			GlobalRefs.combat_system.connect("ship_disabled", self, "_on_ship_disabled")
		# If the player is involved, refresh the player hull display on damage events.
		if not GlobalRefs.combat_system.is_connected("damage_dealt", self, "_on_any_damage_dealt_refresh_player"):
			GlobalRefs.combat_system.connect("damage_dealt", self, "_on_any_damage_dealt_refresh_player")


func _refresh_player_hull() -> void:
	if not is_instance_valid(label_player_hull) or not is_instance_valid(player_hull_bar):
		return
	if not is_instance_valid(GlobalRefs.player_agent_body):
		label_player_hull.text = "Hull: --"
		player_hull_bar.value = 100.0
		return
	var raw_uid = GlobalRefs.player_agent_body.get("agent_uid")
	if raw_uid == null:
		label_player_hull.text = "Hull: --"
		player_hull_bar.value = 100.0
		return
	_player_uid = int(raw_uid)
	if _player_uid < 0:
		label_player_hull.text = "Hull: --"
		player_hull_bar.value = 100.0
		return
	if not is_instance_valid(GlobalRefs.combat_system):
		label_player_hull.text = "Hull: --"
		player_hull_bar.value = 100.0
		return

	# Avoid showing 0% when CombatSystem hasn't registered the player yet.
	var state: Dictionary = {}
	if GlobalRefs.combat_system.has_method("get_combat_state"):
		state = GlobalRefs.combat_system.get_combat_state(_player_uid)
	if state.empty():
		label_player_hull.text = "Hull: --"
		player_hull_bar.value = 100.0
		return

	var hull_pct: float = GlobalRefs.combat_system.get_hull_percent(_player_uid)
	player_hull_bar.value = hull_pct * 100.0
	label_player_hull.text = "Hull: " + str(int(round(hull_pct * 100.0))) + "%"


func _deferred_refresh_player_hull() -> void:
	# CombatSystem registration happens deferred from Agent initialization.
	# Retry briefly so we show player hull without requiring damage.
	for _i in range(20):
		_refresh_player_hull()
		yield(get_tree().create_timer(0.1), "timeout")


func _on_any_damage_dealt_refresh_player(_target_uid: int, _amount: float, _source_uid: int) -> void:
	# Keep player hull display current even if damage events come through CombatSystem only.
	_refresh_player_hull()


func _update_target_info_panel(target_node: Spatial) -> void:
	"""Update the target info panel with the selected target's info."""
	if not target_info_panel:
		return
	
	# Get target's agent_uid if available
	if target_node.get("agent_uid") != null:
		_current_target_uid = target_node.agent_uid
	else:
		_current_target_uid = -1
		target_info_panel.visible = false
		return
	
	# Set target name
	var target_name: String = "Unknown"
	if target_node.get("agent_name") != null:
		target_name = target_node.agent_name
	elif target_node.name:
		target_name = target_node.name
	
	if label_target_name:
		label_target_name.text = target_name
	
	# Update hull bar
	_update_target_hull_bar()
	
	target_info_panel.visible = true


func _update_target_hull_bar() -> void:
	"""Update the target hull progress bar from CombatSystem."""
	if not target_hull_bar or _current_target_uid < 0:
		return
	
	if is_instance_valid(GlobalRefs.combat_system):
		var hull_pct: float = GlobalRefs.combat_system.get_hull_percent(_current_target_uid)
		target_hull_bar.value = hull_pct * 100.0
	else:
		# CombatSystem not available, show full hull as fallback
		target_hull_bar.value = 100.0


func _on_damage_dealt(target_uid: int, _amount: float, _source_uid: int) -> void:
	"""Handle damage_dealt signal from CombatSystem to update hull bar."""
	if target_uid == _current_target_uid:
		_update_target_hull_bar()


func _on_ship_disabled(ship_uid: int) -> void:
	"""Handle ship_disabled signal - target destroyed."""
	if ship_uid == _current_target_uid:
		if target_hull_bar:
			target_hull_bar.value = 0.0
		# Optionally change display to show "DISABLED" or similar
		if label_target_name:
			label_target_name.text = label_target_name.text + " [DISABLED]"

--- Start of ./src/core/ui/main_menu/main_menu.gd ---

extends Control

onready var btn_new_game = $ScreenControls/MainButtonsHBoxContainer/ButtonStartNewGame
onready var btn_load_game = $ScreenControls/MainButtonsHBoxContainer/ButtonLoadGame
onready var btn_save_game = $ScreenControls/MainButtonsHBoxContainer/ButtonSaveGame
onready var btn_exit_game = $ScreenControls/MainButtonsHBoxContainer/ButtonExitgame

# Save notification popup (created dynamically)
var _save_popup: AcceptDialog = null


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

--- Start of ./src/core/utils/editor_object.gd ---

extends MeshInstance


func _ready():
	self.hide()

--- Start of ./src/core/utils/pid_controller.gd ---

# File: core/utils/pid_controller.gd
# Version: 1.0
# Purpose: A reusable PID controller class.

extends Node  # Or use 'extends Reference' if node features aren't needed
class_name PIDController

# --- Gains ---
var kp: float = 1.0 setget set_kp
var ki: float = 0.0 setget set_ki
var kd: float = 0.0 setget set_kd

# --- Limits ---
var integral_limit: float = 1000.0 setget set_integral_limit
var output_limit: float = 50.0 setget set_output_limit

# --- State ---
var integral: float = 0.0
var previous_error: float = 0.0


# --- Initialization ---
func initialize(
	p_gain: float, i_gain: float, d_gain: float, i_limit: float = 1000.0, o_limit: float = 50.0
):
	kp = p_gain
	ki = i_gain
	kd = d_gain
	integral_limit = abs(i_limit)  # Ensure positive limit
	output_limit = abs(o_limit)  # Ensure positive limit
	reset()  # Start with a clean state


# --- Update ---
# Calculates the PID output based on the current error and delta time.
# Returns the clamped PID output value.
func update(error: float, delta: float) -> float:
	if delta <= 0.0001:
		# Avoid division by zero or instability with tiny delta
		return 0.0

	# --- Proportional Term ---
	var p_term = kp * error

	# --- Integral Term ---
	integral += error * delta
	# Clamp integral to prevent windup
	integral = clamp(integral, -integral_limit, integral_limit)
	var i_term = ki * integral

	# --- Derivative Term ---
	var derivative = (error - previous_error) / delta
	var d_term = kd * derivative

	# --- Update State for Next Iteration ---
	previous_error = error

	# --- Calculate & Clamp Output ---
	var output = p_term + i_term + d_term
	output = clamp(output, -output_limit, output_limit)

	return output


# --- Reset ---
# Resets the integral and previous error state.
func reset():
	integral = 0.0
	previous_error = 0.0


# --- Setters (Optional, for runtime tweaking if needed) ---
func set_kp(value: float):
	kp = value


func set_ki(value: float):
	ki = value


func set_kd(value: float):
	kd = value


func set_integral_limit(value: float):
	integral_limit = abs(value)


func set_output_limit(value: float):
	output_limit = abs(value)

--- Start of ./src/core/utils/rotating_object.gd ---

extends MeshInstance

export var rotation_speed = 0.01


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	self.rotate(Vector3(0, 1, 0), delta * rotation_speed)

--- Start of ./src/modules/piloting/player_controller_ship.gd ---

# File: modules/piloting/scripts/player_controller_ship.gd
# Version: 4.2 - Added contextual interact popup for dock vs attack choice.

extends Node

# --- References ---
var agent_script: Node = null
var agent_body: KinematicBody = null
var movement_system: Node = null
var _main_camera: Camera = null
var _speed_slider: Slider = null
var _weapon_controller: Node = null

# --- Speed Control ---
var template_max_speed_actual: float = 300.0
var current_target_speed_normalized: float = 1.0
const KEY_SPEED_INCREMENT_NORMALIZED: float = 0.05

# --- State ---
var _current_input_state: InputState = null
var _states = {}
var _target_under_cursor: Spatial = null
var _selected_target: Spatial = null setget _set_selected_target
var _can_dock_at: String = ""

# --- Preload States ---
const StateBase = preload("res://src/modules/piloting/player_input_states/state_base.gd")
const StateDefault = preload("res://src/modules/piloting/player_input_states/state_default.gd")
const StateFreeFlight = preload(
	"res://src/modules/piloting/player_input_states/state_free_flight.gd"
)


func _ready():
	agent_body = get_parent()
	if not (agent_body is KinematicBody and agent_body.has_method("command_stop")):
		printerr("PlayerController Error: Parent is not a valid agent.")
		set_process(false)
		return

	agent_script = agent_body
	movement_system = agent_body.get_node_or_null("MovementSystem")
	if not is_instance_valid(movement_system):
		printerr("PlayerController Error: MovementSystem not found on agent.")
		set_process(false)
		return

	_weapon_controller = agent_body.get_node_or_null("WeaponController")

	_states = {"default": StateDefault.new(), "free_flight": StateFreeFlight.new()}

	EventBus.connect("dock_available", self, "_on_dock_available")
	EventBus.connect("dock_unavailable", self, "_on_dock_unavailable")
	EventBus.connect("player_docked", self, "_on_player_docked")
	EventBus.connect("player_undocked", self, "_on_player_undocked")
	EventBus.connect("player_dock_pressed", self, "_on_dock_button_pressed")
	EventBus.connect("player_attack_pressed", self, "_on_attack_button_pressed")

	call_deferred("_deferred_ready_setup")
	_change_state("default")


func _deferred_ready_setup():
	if not is_instance_valid(GlobalRefs.main_hud):
		yield(get_tree().create_timer(0.1), "timeout")
	_speed_slider = GlobalRefs.main_hud.get_node_or_null(
		"ScreenControls/CenterRightZone/SliderControlRight"
	)

	template_max_speed_actual = movement_system.max_move_speed
	current_target_speed_normalized = 1.0
	_update_agent_speed_cap_and_slider_visuals()

	_connect_eventbus_signals()
	call_deferred("_get_camera_reference")


func _get_camera_reference():
	yield(get_tree(), "idle_frame")
	_main_camera = GlobalRefs.main_camera if is_instance_valid(GlobalRefs.main_camera) else null
	if not is_instance_valid(_main_camera):
		# Camera may not be ready yet, retry a few times
		for _i in range(10):
			yield(get_tree().create_timer(0.1), "timeout")
			_main_camera = GlobalRefs.main_camera if is_instance_valid(GlobalRefs.main_camera) else null
			if is_instance_valid(_main_camera):
				return
		printerr("PlayerController Error: Could not find valid Main Camera after retries.")


func _change_state(new_state_name: String):
	if _current_input_state and _current_input_state.has_method("exit"):
		_current_input_state.exit()

	if _states.has(new_state_name):
		_current_input_state = _states[new_state_name]
		if _current_input_state.has_method("enter"):
			_current_input_state.enter(self)
	else:
		printerr("PlayerController Error: Attempted to change to unknown state: ", new_state_name)


func _physics_process(delta: float):
	if _current_input_state and _current_input_state.has_method("physics_update"):
		_current_input_state.physics_update(delta)


func _unhandled_input(event: InputEvent):
	# Global inputs that work in any state
	if event.is_action_pressed("ui_accept"):
		_handle_interact_input()
		get_viewport().set_input_as_handled()
		return

	# Combat input (key-based to avoid interfering with LMB targeting/drag)
	if event is InputEventKey and event.is_action_pressed("fire_weapon"):
		_fire_weapon_at_selected_target(false, "key")
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_just_pressed("toggle_free_flight"):
		var new_state = "default" if _current_input_state is StateFreeFlight else "free_flight"
		_change_state(new_state)
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_pressed("command_speed_up"):
		var change = KEY_SPEED_INCREMENT_NORMALIZED * event.get_action_strength("command_speed_up")
		current_target_speed_normalized = clamp(current_target_speed_normalized + change, 0.0, 1.0)
		_update_agent_speed_cap_and_slider_visuals()
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_pressed("command_speed_down"):
		var change = (
			KEY_SPEED_INCREMENT_NORMALIZED
			* event.get_action_strength("command_speed_down")
		)
		current_target_speed_normalized = clamp(current_target_speed_normalized - change, 0.0, 1.0)
		_update_agent_speed_cap_and_slider_visuals()
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_just_pressed("command_stop"):
		_issue_stop_command()
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_just_pressed("command_approach"):
		_issue_approach_command()
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_just_pressed("command_flee"):
		_issue_flee_command()
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_just_pressed("command_orbit"):
		_issue_orbit_command()
		get_viewport().set_input_as_handled()
		return

	# Delegate other inputs to the current state
	if _current_input_state and _current_input_state.has_method("handle_input"):
		_current_input_state.handle_input(event)


func _fire_weapon_at_selected_target(force: bool, source: String = "") -> void:
	if not is_instance_valid(_weapon_controller):
		print("PlayerController: Fire skipped (no WeaponController)")
		return
	if not _weapon_controller.has_method("fire_at_target"):
		print("PlayerController: Fire skipped (WeaponController missing fire_at_target)")
		return
	if not force and not Input.is_action_just_pressed("fire_weapon"):
		return

	var target_body: KinematicBody = _get_current_target()
	if not is_instance_valid(target_body):
		print("PlayerController: Fire skipped (no selected target)")
		return

	var raw_uid = target_body.get("agent_uid")
	if raw_uid == null:
		print("PlayerController: Fire skipped (target has no agent_uid)")
		return
	var target_uid: int = int(raw_uid)
	if target_uid < 0:
		print("PlayerController: Fire skipped (invalid target uid)")
		return

	var target_pos: Vector3 = target_body.global_transform.origin
	var result: Dictionary = _weapon_controller.call("fire_at_target", 0, target_uid, target_pos)
	if not result.get("success", false):
		print("PlayerController: Fire failed[", source, "]: ", result.get("reason", "Unknown"), " details=", result)
		return

	# Debug for manual verification
	var hit: bool = bool(result.get("hit", true))
	if hit:
		var damage_dict = result.get("damage_dealt", {})
		print(
			"PlayerController: Hit[",
			source,
			"] target_uid=",
			target_uid,
			" damage=",
			damage_dict,
			" hull_remaining=",
			result.get("target_hull_remaining", "?"),
			" disabled=",
			result.get("target_disabled", false)
		)
	else:
		print(
			"PlayerController: Miss[",
			source,
			"] target_uid=",
			target_uid,
			" accuracy=",
			result.get("accuracy", "?"),
			" roll=",
			result.get("roll", "?")
		)


func _get_current_target() -> KinematicBody:
	if is_instance_valid(_selected_target) and _selected_target is KinematicBody:
		return _selected_target as KinematicBody
	return null


# --- Contextual Interact ---
func _handle_interact_input() -> void:
	# Legacy keyboard interact - just dock if available
	if _can_dock_at != "":
		print("PlayerController: Attempting to dock at ", _can_dock_at)
		EventBus.emit_signal("player_docked", _can_dock_at)


# --- Dock/Attack Button Handlers ---
func _on_dock_button_pressed() -> void:
	if _can_dock_at != "":
		print("PlayerController: Dock button pressed, docking at ", _can_dock_at)
		EventBus.emit_signal("player_docked", _can_dock_at)
	else:
		# Emit signal to show "no dock available" popup on HUD
		if EventBus:
			EventBus.emit_signal("dock_action_feedback", false, "No station in range")


func _on_attack_button_pressed() -> void:
	var target = _get_current_target()
	if is_instance_valid(target):
		print("PlayerController: Attack button pressed, attacking target")
		_fire_weapon_at_selected_target(true, "button")
		# Emit signal to show "attacking" popup on HUD
		if EventBus:
			EventBus.emit_signal("attack_action_feedback", true, "Attacking!")
	else:
		# Emit signal to show "no target" popup on HUD
		if EventBus:
			EventBus.emit_signal("attack_action_feedback", false, "No target selected")


# --- Helper & Command Functions (Publicly callable by states) ---
func _update_target_under_cursor():
	_target_under_cursor = _raycast_for_target(get_viewport().get_mouse_position())


func _set_selected_target(new_target: Spatial):
	if _selected_target == new_target:
		return
	_selected_target = new_target
	if is_instance_valid(_selected_target):
		EventBus.emit_signal("player_target_selected", _selected_target)
	else:
		EventBus.emit_signal("player_target_deselected")


func _handle_single_click(_click_pos: Vector2):
	self._selected_target = _target_under_cursor


func _handle_double_click(click_pos: Vector2):
	if is_instance_valid(agent_script) and is_instance_valid(_main_camera):
		var ray_origin = _main_camera.project_ray_origin(click_pos)
		var ray_normal = _main_camera.project_ray_normal(click_pos)
		var target_point = ray_origin + ray_normal * Constants.TARGETING_RAY_LENGTH
		agent_script.command_move_to(target_point)


func _issue_stop_command():
	if not is_instance_valid(agent_script):
		return
	agent_script.command_stop()
	if _current_input_state is StateFreeFlight:
		_change_state("default")


func _issue_approach_command():
	if not is_instance_valid(agent_script):
		return
	if EventBus:
		EventBus.emit_signal("player_approach_pressed")
	if _current_input_state is StateFreeFlight:
		_change_state("default")


func _issue_flee_command():
	if not is_instance_valid(agent_script):
		return
	if EventBus:
		EventBus.emit_signal("player_flee_pressed")
	if _current_input_state is StateFreeFlight:
		_change_state("default")


func _issue_orbit_command():
	if not is_instance_valid(agent_script):
		return
	if EventBus:
		EventBus.emit_signal("player_orbit_pressed")
	if _current_input_state is StateFreeFlight:
		_change_state("default")


func _update_agent_speed_cap_and_slider_visuals():
	if not is_instance_valid(movement_system):
		return
	var new_cap = lerp(0.0, template_max_speed_actual, current_target_speed_normalized)
	movement_system.max_move_speed = new_cap

	if is_instance_valid(_speed_slider):
		var slider_val = 100.0 - (current_target_speed_normalized * 100.0)
		if not is_equal_approx(_speed_slider.value, slider_val):
			_speed_slider.value = slider_val


func _raycast_for_target(screen_pos: Vector2) -> Spatial:
	if not is_instance_valid(agent_body) or not is_instance_valid(_main_camera):
		return null
	var ray_origin = _main_camera.project_ray_origin(screen_pos)
	var ray_normal = _main_camera.project_ray_normal(screen_pos)
	var ray_end = ray_origin + ray_normal * Constants.TARGETING_RAY_LENGTH
	# --- FIX: Call get_world() from the agent_body node ---
	var space_state = agent_body.get_world().direct_space_state
	var result = space_state.intersect_ray(ray_origin, ray_end, [agent_body], 1)
	return result.collider if result else null


# --- Signal Handlers ---
func _on_Player_Free_Flight_Toggled():
	var new_state = "default" if _current_input_state is StateFreeFlight else "free_flight"
	_change_state(new_state)


func _on_Player_Stop_Pressed():
	_issue_stop_command()


func _on_Player_Orbit_Pressed():
	if is_instance_valid(_selected_target):
		agent_script.command_orbit(_selected_target)


func _on_Player_Approach_Pressed():
	if is_instance_valid(_selected_target):
		agent_script.command_approach(_selected_target)


func _on_Player_Flee_Pressed():
	if is_instance_valid(_selected_target):
		agent_script.command_flee(_selected_target)

func _on_Player_Interact_Pressed():
	if _can_dock_at != "":
		print("PlayerController: Interact button pressed. Attempting to dock at ", _can_dock_at)
		EventBus.emit_signal("player_docked", _can_dock_at)
	else:
		print("PlayerController: Interact button pressed but no dock available.")

func _on_Player_Ship_Speed_Slider_Changed_By_HUD(slider_ui_value: float):
	current_target_speed_normalized = (100.0 - slider_ui_value) / 100.0
	_update_agent_speed_cap_and_slider_visuals()


# --- Connections & Cleanup ---
func _connect_eventbus_signals():
	EventBus.connect("player_free_flight_toggled", self, "_on_Player_Free_Flight_Toggled")
	EventBus.connect("player_stop_pressed", self, "_on_Player_Stop_Pressed")
	EventBus.connect("player_orbit_pressed", self, "_on_Player_Orbit_Pressed")
	EventBus.connect("player_approach_pressed", self, "_on_Player_Approach_Pressed")
	EventBus.connect("player_flee_pressed", self, "_on_Player_Flee_Pressed")
	EventBus.connect("player_interact_pressed", self, "_on_Player_Interact_Pressed")
	EventBus.connect(
		"player_ship_speed_changed", self, "_on_Player_Ship_Speed_Slider_Changed_By_HUD"
	)


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if EventBus.is_connected(
			"player_free_flight_toggled", self, "_on_Player_Free_Flight_Toggled"
		):
			EventBus.disconnect(
				"player_free_flight_toggled", self, "_on_Player_Free_Flight_Toggled"
			)
		if EventBus.is_connected("player_stop_pressed", self, "_on_Player_Stop_Pressed"):
			EventBus.disconnect("player_stop_pressed", self, "_on_Player_Stop_Pressed")
		if EventBus.is_connected("player_orbit_pressed", self, "_on_Player_Orbit_Pressed"):
			EventBus.disconnect("player_orbit_pressed", self, "_on_Player_Orbit_Pressed")
		if EventBus.is_connected("player_approach_pressed", self, "_on_Player_Approach_Pressed"):
			EventBus.disconnect("player_approach_pressed", self, "_on_Player_Approach_Pressed")
		if EventBus.is_connected("player_flee_pressed", self, "_on_Player_Flee_Pressed"):
			EventBus.disconnect("player_flee_pressed", self, "_on_Player_Flee_Pressed")
		if EventBus.is_connected("player_interact_pressed", self, "_on_Player_Interact_Pressed"):
			EventBus.disconnect("player_interact_pressed", self, "_on_Player_Interact_Pressed")
		if EventBus.is_connected(
			"player_ship_speed_changed", self, "_on_Player_Ship_Speed_Slider_Changed_By_HUD"
		):
			EventBus.disconnect(
				"player_ship_speed_changed", self, "_on_Player_Ship_Speed_Slider_Changed_By_HUD"
			)

# --- Docking Handlers ---
func _on_dock_available(location_id):
	_can_dock_at = location_id
	print("PlayerController: Docking available at: ", location_id, ". Press Interact (Space/Enter) to dock.")
	# TODO: Show UI prompt

func _on_dock_unavailable():
	_can_dock_at = ""
	print("PlayerController: Docking unavailable.")
	# TODO: Hide UI prompt

func _on_player_docked(location_id):
	print("Player docked at: ", location_id)
	GameState.player_docked_at = location_id
	set_process_unhandled_input(false)
	set_physics_process(false)
	# Stop the ship
	if agent_script.has_method("command_stop"):
		agent_script.command_stop()

func _on_player_undocked():
	print("Player undocked")
	GameState.player_docked_at = ""
	set_process_unhandled_input(true)
	set_physics_process(true)

--- Start of ./src/modules/piloting/player_input_states/state_base.gd ---

# File: modules/piloting/scripts/player_input_states/state_base.gd
# Base class for all player input states.

class_name InputState
extends Node

var _controller: Node  # Reference to the main player_controller_ship.gd


func enter(controller: Node):
	"""Called when entering this state."""
	_controller = controller


func exit():
	"""Called when exiting this state."""
	pass


func handle_input(_event: InputEvent):
	"""Handles unhandled input events."""
	pass


func physics_update(_delta: float):
	"""Handles physics process logic for this state."""
	pass

--- Start of ./src/modules/piloting/player_input_states/state_default.gd ---

# File: src/modules/piloting/player_input_states/state_default.gd
# Handles standard flight, targeting, and camera drag input.

extends "res://src/modules/piloting/player_input_states/state_base.gd"

# --- Input Tracking State for this mode ---
var _lmb_pressed: bool = false
var _lmb_press_pos: Vector2 = Vector2.ZERO
var _last_tap_time: int = 0
var _is_dragging: bool = false

const DRAG_THRESHOLD_PX_SQ = 10 * 10
const DOUBLE_CLICK_TIME_MS = 400


func enter(controller: Node):
	.enter(controller)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if (
		is_instance_valid(_controller._main_camera)
		and _controller._main_camera.has_method("set_is_rotating")
	):
		_controller._main_camera.set_is_rotating(false)
	_lmb_pressed = false
	_is_dragging = false


func physics_update(_delta: float):
	_controller._update_target_under_cursor()


func handle_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			_lmb_pressed = true
			_is_dragging = false
			_lmb_press_pos = event.position
		else:  # Released
			if _lmb_pressed:
				if _is_dragging:
					# Stop camera rotation when drag is released
					if (
						is_instance_valid(_controller._main_camera)
						and _controller._main_camera.has_method("set_is_rotating")
					):
						_controller._main_camera.set_is_rotating(false)
				else:  # Tap/Click
					var time_now = OS.get_ticks_msec()
					if time_now - _last_tap_time <= DOUBLE_CLICK_TIME_MS:
						_controller._handle_double_click(event.position)
						_last_tap_time = 0
					else:
						_controller._handle_single_click(event.position)
						_last_tap_time = time_now
				_lmb_pressed = false
				_is_dragging = false
				_controller.get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _lmb_pressed and not _is_dragging:
		if event.position.distance_squared_to(_lmb_press_pos) > DRAG_THRESHOLD_PX_SQ:
			_is_dragging = true
			if (
				is_instance_valid(_controller._main_camera)
				and _controller._main_camera.has_method("set_is_rotating")
			):
				_controller._main_camera.set_is_rotating(true)
			_controller.get_viewport().set_input_as_handled()

--- Start of ./src/modules/piloting/player_input_states/state_free_flight.gd ---

# File: src/modules/piloting/player_input_states/state_free_flight.gd
# Handles direct ship orientation and movement input.

extends "res://src/modules/piloting/player_input_states/state_base.gd"


func enter(controller: Node):
	.enter(controller)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if (
		is_instance_valid(_controller._main_camera)
		and _controller._main_camera.has_method("set_rotation_input_active")
	):
		_controller._main_camera.set_rotation_input_active(true)


func exit():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if (
		is_instance_valid(_controller._main_camera)
		and _controller._main_camera.has_method("set_rotation_input_active")
	):
		_controller._main_camera.set_rotation_input_active(false)


func physics_update(_delta: float):
	if is_instance_valid(_controller._main_camera) and is_instance_valid(_controller.agent_script):
		var move_dir = -_controller._main_camera.global_transform.basis.z.normalized()
		_controller.agent_script.command_move_direction(move_dir)
	elif is_instance_valid(_controller.agent_script):
		_controller.agent_script.command_stop()

--- Start of ./src/modules/piloting/ship_controller_ai.gd ---


# File: modules/piloting/scripts/ship_controller_ai.gd
# Attach to Node child of AgentBody in npc_agent.tscn
# Version 3.0 - Sprint 9: Combat encounter AI state machine

extends Node

enum AIState { IDLE, PATROL, COMBAT, FLEE, DISABLED }

# --- Configuration ---
export var aggro_range: float = 800.0
export var weapon_range: float = 500.0
export var flee_hull_threshold: float = 0.2
export var patrol_radius: float = 200.0
export var is_hostile: bool = false

# --- References ---
var agent_script: Node = null

# --- State ---
var _current_state: int = AIState.IDLE
var _target_agent: KinematicBody = null
var _home_position: Vector3 = Vector3.ZERO
var _weapon_controller: Node = null

var _patrol_destination: Vector3 = Vector3.ZERO
var _has_patrol_destination: bool = false

var _repath_timer: float = 0.0
const _REPATH_INTERVAL: float = 0.5

var _halted_in_range: bool = false

var _fire_timer: float = 0.0
const AI_FIRE_INTERVAL: float = 1.5  # Seconds between fire attempts

var _weapon_range_initialized: bool = false


func _ready() -> void:
	var parent = get_parent()
	if parent is KinematicBody and parent.has_method("command_move_to"):
		agent_script = parent
		_weapon_controller = parent.get_node_or_null("WeaponController")
		_home_position = parent.global_transform.origin
		set_physics_process(true)
	else:
		printerr(
			"AI Controller Error: Parent node is not an Agent KinematicBody with command methods!"
		)
		set_physics_process(false)
		set_script(null)
		return

	if is_instance_valid(EventBus):
		if not EventBus.is_connected("agent_disabled", self, "_on_agent_disabled"):
			EventBus.connect("agent_disabled", self, "_on_agent_disabled")

	# WeaponController loads weapons deferred; retry a few times to sync AI weapon_range.
	call_deferred("_deferred_init_weapon_range")


func _deferred_init_weapon_range() -> void:
	for _i in range(20):
		if _try_init_weapon_range_from_weapon_controller():
			_weapon_range_initialized = true
			return
		yield(get_tree().create_timer(0.1), "timeout")


func _try_init_weapon_range_from_weapon_controller() -> bool:
	if not is_instance_valid(_weapon_controller) and is_instance_valid(agent_script):
		_weapon_controller = agent_script.get_node_or_null("WeaponController")
	if not is_instance_valid(_weapon_controller):
		return false
	if not _weapon_controller.has_method("get_weapon_count"):
		return false
	var count = int(_weapon_controller.call("get_weapon_count"))
	if count <= 0:
		return false
	if not _weapon_controller.has_method("get_weapon"):
		return false
	var weapon = _weapon_controller.call("get_weapon", 0)
	if not weapon:
		return false
	var raw_max = weapon.get("range_max")
	if raw_max == null:
		return false
	var max_range: float = float(raw_max)
	if max_range <= 0.0:
		return false
	# Keep a small safety buffer so we don't orbit exactly at max range.
	weapon_range = max(10.0, max_range * 0.9)
	return true


func initialize(config: Dictionary) -> void:
	if not is_instance_valid(agent_script):
		printerr("AI Initialize Error: Agent script invalid. Cannot configure AI.")
		return

	if config.has("patrol_center") and config.patrol_center is Vector3:
		_home_position = config.patrol_center
	elif config.has("initial_target") and config.initial_target is Vector3:
		_home_position = config.initial_target
	else:
		_home_position = agent_script.global_transform.origin

	is_hostile = bool(config.get("hostile", is_hostile))

	# If hostile: start patrolling/scanning immediately.
	if is_hostile:
		_change_state(AIState.PATROL)
		return

	# Preserve prior behavior for non-hostile NPCs: optionally move once.
	if config.has("initial_target") and config.initial_target is Vector3:
		agent_script.command_move_to(config.initial_target)


func _physics_process(delta: float) -> void:
	match _current_state:
		AIState.IDLE:
			_process_idle(delta)
		AIState.PATROL:
			_process_patrol(delta)
		AIState.COMBAT:
			_process_combat(delta)
		AIState.FLEE:
			_process_flee(delta)
		AIState.DISABLED:
			pass


func _change_state(new_state: int) -> void:
	if _current_state == new_state:
		return

	_current_state = new_state
	_halted_in_range = false
	_repath_timer = 0.0
	_fire_timer = 0.0

	match _current_state:
		AIState.IDLE:
			_target_agent = null
			_has_patrol_destination = false
			if is_instance_valid(agent_script) and agent_script.has_method("command_stop"):
				agent_script.command_stop()
		AIState.PATROL:
			_target_agent = null
			_has_patrol_destination = false
		AIState.COMBAT:
			# Entry action: start approaching target if possible.
			if is_instance_valid(agent_script) and is_instance_valid(_target_agent):
				if agent_script.has_method("command_approach"):
					agent_script.command_approach(_target_agent)
				else:
					agent_script.command_move_to(_target_agent.global_transform.origin)
		AIState.FLEE:
			# Entry action: flee from target if possible.
			if is_instance_valid(agent_script) and is_instance_valid(_target_agent):
				if agent_script.has_method("command_flee"):
					agent_script.command_flee(_target_agent)
				else:
					var flee_pos = _calculate_flee_position()
					agent_script.command_move_to(flee_pos)
		AIState.DISABLED:
			if is_instance_valid(agent_script) and agent_script.has_method("command_stop"):
				agent_script.command_stop()
			_target_agent = null
			_has_patrol_destination = false


func _process_idle(_delta: float) -> void:
	if not is_hostile:
		return
	var target = _scan_for_target()
	if is_instance_valid(target):
		_target_agent = target
		_change_state(AIState.COMBAT)


func _process_patrol(_delta: float) -> void:
	if not is_hostile:
		_change_state(AIState.IDLE)
		return

	var target = _scan_for_target()
	if is_instance_valid(target):
		_target_agent = target
		_change_state(AIState.COMBAT)
		return

	if not is_instance_valid(agent_script):
		return

	var current_pos = agent_script.global_transform.origin
	if not _has_patrol_destination or current_pos.distance_to(_patrol_destination) <= 10.0:
		_patrol_destination = _pick_patrol_destination()
		_has_patrol_destination = true
		agent_script.command_move_to(_patrol_destination)


func _process_combat(delta: float) -> void:
	if not is_hostile:
		_change_state(AIState.IDLE)
		return

	if not is_instance_valid(agent_script):
		_change_state(AIState.IDLE)
		return

	if not is_instance_valid(_target_agent):
		_change_state(AIState.PATROL)
		return

	var self_pos: Vector3 = agent_script.global_transform.origin
	var target_pos: Vector3 = _target_agent.global_transform.origin
	var distance: float = self_pos.distance_to(target_pos)

	# Drop combat if target out of aggro range.
	if distance > aggro_range:
		_target_agent = null
		_change_state(AIState.PATROL)
		return

	# Hull check only valid if CombatSystem has state for this agent.
	if is_instance_valid(GlobalRefs.combat_system) and GlobalRefs.combat_system.has_method("is_in_combat"):
		if GlobalRefs.combat_system.is_in_combat(int(agent_script.agent_uid)):
			var hull_pct: float = GlobalRefs.combat_system.get_hull_percent(int(agent_script.agent_uid))
			if hull_pct > 0.0 and hull_pct < flee_hull_threshold:
				_change_state(AIState.FLEE)
				return

	# Approach target until within weapon range.
	_repath_timer = max(0.0, _repath_timer - delta)
	if distance > weapon_range:
		_halted_in_range = false
		if _repath_timer <= 0.0:
			_repath_timer = _REPATH_INTERVAL
			if agent_script.has_method("command_approach"):
				agent_script.command_approach(_target_agent)
			else:
				agent_script.command_move_to(target_pos)
	else:
		# In weapon range: orbit the player instead of just stopping
		if not _halted_in_range:
			_halted_in_range = true
			if agent_script.has_method("command_orbit"):
				agent_script.command_orbit(_target_agent)

		_fire_timer = max(0.0, _fire_timer - delta)
		if _fire_timer <= 0.0 and _is_in_weapon_range():
			_try_fire_weapon()


func _try_fire_weapon() -> void:
	if not is_instance_valid(_weapon_controller) and is_instance_valid(agent_script):
		_weapon_controller = agent_script.get_node_or_null("WeaponController")

	if not is_instance_valid(_weapon_controller):
		return
	if not is_instance_valid(_target_agent):
		return

	var target_pos: Vector3 = _target_agent.global_transform.origin
	var raw_target_uid = _target_agent.get("agent_uid")
	var target_uid: int = -1
	if raw_target_uid != null:
		target_uid = int(raw_target_uid)

	var result: Dictionary = _weapon_controller.fire_at_target(0, target_uid, target_pos)

	if result.get("success", false):
		_fire_timer = AI_FIRE_INTERVAL
	elif result.get("reason") == "Weapon on cooldown":
		_fire_timer = float(result.get("cooldown", 0.5))


func _is_in_weapon_range() -> bool:
	if not is_instance_valid(_target_agent) or not is_instance_valid(agent_script):
		return false
	var distance = agent_script.global_transform.origin.distance_to(_target_agent.global_transform.origin)
	return distance <= weapon_range


func _process_flee(delta: float) -> void:
	if not is_instance_valid(agent_script):
		_change_state(AIState.IDLE)
		return

	if not is_instance_valid(_target_agent):
		_change_state(AIState.PATROL)
		return

	var self_pos: Vector3 = agent_script.global_transform.origin
	var target_pos: Vector3 = _target_agent.global_transform.origin
	var distance: float = self_pos.distance_to(target_pos)

	if distance > aggro_range * 2.0:
		# Don't despawn just because we fled far away; that makes encounters feel broken.
		# Instead, drop combat target and resume patrol.
		_target_agent = null
		_change_state(AIState.PATROL)
		return

	_repath_timer = max(0.0, _repath_timer - delta)
	if _repath_timer <= 0.0:
		_repath_timer = _REPATH_INTERVAL
		if agent_script.has_method("command_flee"):
			agent_script.command_flee(_target_agent)
		else:
			var flee_pos = _calculate_flee_position()
			agent_script.command_move_to(flee_pos)


func _scan_for_target() -> KinematicBody:
	if not is_hostile:
		return null
	var player = GlobalRefs.player_agent_body
	if not is_instance_valid(player) and is_instance_valid(GlobalRefs.world_manager):
		player = GlobalRefs.world_manager.get("player_agent")
	if not is_instance_valid(player):
		return null
	if not is_instance_valid(agent_script):
		return null

	var distance = agent_script.global_transform.origin.distance_to(player.global_transform.origin)
	if distance <= aggro_range:
		return player
	return null


func _pick_patrol_destination() -> Vector3:
	# Simple random offset within patrol_radius on XZ plane.
	var angle: float = randf() * TAU
	var radius: float = randf() * patrol_radius
	var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * radius
	return _home_position + offset


func _calculate_flee_position() -> Vector3:
	if not is_instance_valid(agent_script) or not is_instance_valid(_target_agent):
		return _home_position
	var self_pos: Vector3 = agent_script.global_transform.origin
	var target_pos: Vector3 = _target_agent.global_transform.origin
	var away: Vector3 = (self_pos - target_pos)
	if away.length() <= 0.001:
		away = Vector3(1, 0, 0)
	away = away.normalized()
	return self_pos + away * aggro_range


func _on_agent_disabled(agent_body) -> void:
	if is_instance_valid(agent_script) and agent_body == agent_script:
		_change_state(AIState.DISABLED)

--- Start of ./src/scenes/camera/components/camera_particles_controller.gd ---

# File: res://scenes/camera/camera_particles_controller.gd
# Purpose: Controls the space dust (CPUParticles) effect attached to the camera,
#          adjusting emission, velocity, and emitter position based on
#          the CAMERA's movement speed. (GLES2 Compatible)
extends CPUParticles  # Use CPUParticles for GLES2

# --- Tunable Parameters ---
# Camera speed threshold below which particles stop emitting strongly
export var min_camera_speed_threshold: float = 0.5
# Camera speed at which the effect reaches maximum intensity
export var max_camera_speed_for_effect: float = 50.0
# --- NEW: How much to shift emitter opposite to velocity vector ---
export var velocity_offset_scale: float = -250.0

# --- Node References ---
var _camera: Camera = null

# --- State ---
var _previous_camera_pos: Vector3 = Vector3.ZERO
var _initialized: bool = false


func _ready():
	# Get camera reference (assuming this node is a direct child of the camera)
	_camera = get_parent() as Camera
	if not _camera:
		printerr("CameraParticlesController Error: Parent node is not a Camera!")
		set_process(false)
		return

	# Set initial state directly on the node
	self.emitting = false
	self.gravity = Vector3.ZERO
	self.transform.origin = Vector3.ZERO  # Ensure offset starts at zero

	# Defer setting previous position until the first process frame
	# to ensure the camera has its initial position set.
	call_deferred("_initialize_position")


func _initialize_position():
	if is_instance_valid(_camera):
		_previous_camera_pos = _camera.global_transform.origin
		_initialized = true
		#print("CameraParticlesController Initialized.")
	else:
		printerr("CameraParticlesController Error: Camera invalid during deferred init.")
		set_process(false)


func _process(delta: float):
	# Ensure camera is valid and initialized
	if not _initialized or not is_instance_valid(_camera):
		# Keep particles off if camera isn't ready
		if self.emitting:
			self.emitting = false
		if self.gravity != Vector3.ZERO:
			self.gravity = Vector3.ZERO
		# Reset offset if camera becomes invalid
		if self.transform.origin != Vector3.ZERO:
			self.transform.origin = Vector3.ZERO
		return

	# --- Calculate Camera Movement ---
	var current_pos: Vector3 = _camera.global_transform.origin
	# Vector representing the camera's displacement over the last frame in global space
	var position_delta_global: Vector3 = current_pos - _previous_camera_pos
	var camera_speed: float = 0.0

	if delta > 0.0001:  # Avoid division by zero or large spikes on first frame/lag
		camera_speed = position_delta_global.length() / delta

	# Store current position for the next frame's calculation
	_previous_camera_pos = current_pos

	# --- Apply Velocity Offset ---
	# Calculate the desired offset in the opposite direction of the global movement.
	# Since this script/node is a child of the camera, we need to transform the global
	# offset direction into the camera's local space before applying it.
	var global_offset_vector = -position_delta_global * velocity_offset_scale
	# Transform the global offset vector into the camera's local coordinate system
	var local_offset_vector = _camera.global_transform.basis.xform_inv(global_offset_vector)

	# Set the local position offset of this CPUParticles node
	self.transform.origin = local_offset_vector

	# --- Control Emission (based on speed) ---
	if camera_speed > min_camera_speed_threshold:
		if not self.emitting:
			self.emitting = true
	else:
		if self.emitting:
			self.emitting = false

--- Start of ./src/scenes/camera/components/camera_position_controller.gd ---

# File: scenes/camera/components/camera_position_controller.gd
# Version: 1.1 - Added a smoothed target position to reduce jerk on rapid velocity changes.
# Purpose: Manages camera positioning, smoothing, and bobbing effect.

extends Node
class_name CameraPositionController

# --- References ---
var _camera: Camera = null
var _target: Spatial = null
var _rotation_controller: CameraRotationController = null
var _zoom_controller: CameraZoomController = null

# --- From Configuration ---
var position_smoothing_speed: float = 0
var rotation_smoothing_speed: float = 0
var bob_frequency: float = 0
var bob_amplitude: float = 0
# NEW: How quickly the camera's anchor point follows the ship. Lower values are smoother.
var target_smoothing_speed: float = 0

# --- State ---
var _bob_timer: float = 0.0
# NEW: This will be the point the camera actually tries to follow.
var _smoothed_target_pos: Vector3 = Vector3.ZERO


# --- Initialization ---
func initialize(camera_node: Camera, rot_ctrl: Node, zoom_ctrl: Node, config: Dictionary):
	_camera = camera_node
	_rotation_controller = rot_ctrl
	_zoom_controller = zoom_ctrl

	# Set configuration from the main camera script
	position_smoothing_speed = config.get("position_smoothing_speed", position_smoothing_speed)
	rotation_smoothing_speed = config.get("rotation_smoothing_speed", rotation_smoothing_speed)
	bob_frequency = config.get("bob_frequency", bob_frequency)
	bob_amplitude = config.get("bob_amplitude", bob_amplitude)
	target_smoothing_speed = config.get("target_smoothing_speed", target_smoothing_speed)


# --- Public Methods ---
func set_target(new_target: Spatial):
	_target = new_target
	# When the target changes, immediately snap the smoothed position to it.
	if is_instance_valid(_target):
		_smoothed_target_pos = _target.global_transform.origin


func physics_update(delta: float):
	_bob_timer += delta

	if not is_instance_valid(_target):
		# Detached Mode
		var new_basis = Basis().rotated(Vector3.UP, _rotation_controller.yaw).rotated(
			Basis().rotated(Vector3.UP, _rotation_controller.yaw).x, _rotation_controller.pitch
		)
		_camera.global_transform.basis = new_basis.orthonormalized()
		return

	# --- Attached Mode ---
	var actual_target_pos = _target.global_transform.origin

	# --- SMOOTHING LOGIC ---
	# Instead of using the actual target position directly, we lerp our
	# internal "smoothed" position towards it. This dampens any sudden jumps.
	_smoothed_target_pos = _smoothed_target_pos.linear_interpolate(
		actual_target_pos, target_smoothing_speed * delta
	)
	# --- END SMOOTHING LOGIC ---

	var bob_offset = (
		_camera.global_transform.basis.y
		* sin(_bob_timer * bob_frequency * TAU)
		* bob_amplitude
	)

	var desired_basis = Basis().rotated(Vector3.UP, _rotation_controller.yaw).rotated(
		Basis().rotated(Vector3.UP, _rotation_controller.yaw).x, _rotation_controller.pitch
	)

	# Calculate desired position relative to the SMOOTHED target position
	var position_offset = -desired_basis.z * _zoom_controller.current_distance
	var desired_position = _smoothed_target_pos + position_offset + bob_offset

	# Interpolate Camera's actual position
	_camera.global_transform.origin = _camera.global_transform.origin.linear_interpolate(
		desired_position, position_smoothing_speed * delta
	)

	# Interpolate Look At to point towards the SMOOTHED target position
	var target_look_transform = _camera.global_transform.looking_at(
		_smoothed_target_pos, Vector3.UP
	)
	_camera.global_transform.basis = _camera.global_transform.basis.slerp(
		target_look_transform.basis.orthonormalized(), rotation_smoothing_speed * delta
	)

--- Start of ./src/scenes/camera/components/camera_rotation_controller.gd ---

# File: src/scenes/camera/components/camera_rotation_controller.gd
# Purpose: Manages camera rotation, including PID-based smoothing and mouse input.
# This is a component of the main OrbitCamera.

extends Node
class_name CameraRotationController

# --- References ---
var _camera: Camera = null
var _yaw_pid: PIDController = null
var _pitch_pid: PIDController = null
const PIDControllerScript = preload("res://src/core/utils/pid_controller.gd")

# --- From Configuration ---
var pitch_min: float = 0.0
var pitch_max: float = 0.0
var pid_yaw_kp: float = 0.0
var pid_yaw_ki: float = 0.0
var pid_yaw_kd: float = 0.0
var pid_pitch_kp: float = 0.0
var pid_pitch_ki: float = 0.0
var pid_pitch_kd: float = 0.0
var pid_integral_limit: float = 0.0
var pid_output_limit_multiplier: float = 0.0
var _rotation_max_speed: float = 0.0
var _rotation_input_curve: float = 0.0

# --- State ---
var yaw: float = PI
var pitch: float = 0.25
var _rotation_input_active: bool = false
var _is_externally_rotating: bool = false
var _target_yaw_speed: float = 0.0
var _target_pitch_speed: float = 0.0
var _current_yaw_speed: float = 0.0
var _current_pitch_speed: float = 0.0


# --- Initialization ---
func initialize(camera_node: Camera, config: Dictionary):
	_camera = camera_node

	# Set configuration from the main camera script
	pitch_min = config.get("pitch_min", pitch_min)
	pitch_max = config.get("pitch_max", pitch_max)
	pid_yaw_kp = config.get("pid_yaw_kp", pid_yaw_kp)
	pid_yaw_ki = config.get("pid_yaw_ki", pid_yaw_ki)
	pid_yaw_kd = config.get("pid_yaw_kd", pid_yaw_kd)
	pid_pitch_kp = config.get("pid_pitch_kp", pid_pitch_kp)
	pid_pitch_ki = config.get("pid_pitch_ki", pid_pitch_ki)
	pid_pitch_kd = config.get("pid_pitch_kd", pid_pitch_kd)
	pid_integral_limit = config.get("pid_integral_limit", pid_integral_limit)
	pid_output_limit_multiplier = config.get(
		"pid_output_limit_multiplier", pid_output_limit_multiplier
	)
	_rotation_max_speed = config.get("_rotation_max_speed", _rotation_max_speed)
	_rotation_input_curve = config.get("_rotation_input_curve", _rotation_input_curve)

	yaw = config.get("initial_yaw", PI)
	pitch = config.get("initial_pitch", 0.25)

	# Instantiate and Initialize PID Controllers
	if PIDControllerScript:
		_yaw_pid = PIDControllerScript.new()
		_pitch_pid = PIDControllerScript.new()
		add_child(_yaw_pid)  # Ensure it's freed with the node
		add_child(_pitch_pid)

		var output_limit = _rotation_max_speed * pid_output_limit_multiplier
		_yaw_pid.initialize(pid_yaw_kp, pid_yaw_ki, pid_yaw_kd, pid_integral_limit, output_limit)
		_pitch_pid.initialize(
			pid_pitch_kp, pid_pitch_ki, pid_pitch_kd, pid_integral_limit, output_limit
		)
	else:
		printerr("CameraRotationController Error: Failed to preload PIDController script!")


# --- Public Methods ---
func handle_input(event: InputEvent):
	if event is InputEventMouseMotion:
		if _rotation_input_active or _is_externally_rotating:
			var input_x = event.relative.x
			var input_y = event.relative.y

			var strength_x = pow(abs(input_x), _rotation_input_curve) * sign(input_x)
			var strength_y = pow(abs(input_y), _rotation_input_curve) * sign(input_y)

			var input_scale_factor = 0.01
			_target_yaw_speed = -strength_x * input_scale_factor * _rotation_max_speed
			_target_pitch_speed = -strength_y * input_scale_factor * _rotation_max_speed

			_target_yaw_speed = clamp(_target_yaw_speed, -_rotation_max_speed, _rotation_max_speed)
			_target_pitch_speed = clamp(
				_target_pitch_speed, -_rotation_max_speed, _rotation_max_speed
			)

			get_viewport().set_input_as_handled()


func physics_update(delta: float):
	if not is_instance_valid(_yaw_pid) or not is_instance_valid(_pitch_pid):
		return

	var rot_active = _rotation_input_active or _is_externally_rotating
	if not rot_active:
		_target_yaw_speed = 0.0
		_target_pitch_speed = 0.0

	var error_yaw = _target_yaw_speed - _current_yaw_speed
	var error_pitch = _target_pitch_speed - _current_pitch_speed

	var yaw_accel = _yaw_pid.update(error_yaw, delta)
	var pitch_accel = _pitch_pid.update(error_pitch, delta)

	_current_yaw_speed += yaw_accel * delta
	_current_pitch_speed += pitch_accel * delta

	yaw += _current_yaw_speed * delta
	pitch -= _current_pitch_speed * delta
	pitch = clamp(pitch, pitch_min, pitch_max)

	_target_yaw_speed = 0.0
	_target_pitch_speed = 0.0


func set_rotation_input_active(is_active: bool):
	_rotation_input_active = is_active
	if is_active:
		_is_externally_rotating = false
	reset_pids()


func set_is_rotating(rotating: bool):
	if not _rotation_input_active:
		_is_externally_rotating = rotating
	reset_pids()


func reset_pids():
	if is_instance_valid(_yaw_pid):
		_yaw_pid.reset()
	if is_instance_valid(_pitch_pid):
		_pitch_pid.reset()
	_current_yaw_speed = 0.0
	_current_pitch_speed = 0.0

--- Start of ./src/scenes/camera/components/camera_zoom_controller.gd ---

# File: scenes/camera/components/camera_zoom_controller.gd
# Purpose: Manages camera zoom, distance from target, and FoV calculations.
# This is a component of the main OrbitCamera.

extends Node
class_name CameraZoomController

# --- References ---
var _camera: Camera = null
var _target: Spatial = null

# --- From Configuration ---
var distance: float = 0.0
var min_distance_multiplier: float = 0.0
var max_distance_multiplier: float = 0.0
var preferred_distance_multiplier: float = 0.0
var zoom_speed: float = 0.0
var _min_fov_deg: float = 0.0
var _max_fov_deg: float = 0.0

# --- Constants ---
const MIN_ABSOLUTE_DISTANCE = 1.0
const MAX_ABSOLUTE_DISTANCE = 500.0

# --- State ---
var current_distance: float = 0.0
var _target_radius: float = 0.0
var _is_programmatically_setting_slider: bool = false


# --- Initialization ---
func initialize(camera_node: Camera, config: Dictionary):
	_camera = camera_node

	# Set configuration from the main camera script
	distance = config.get("distance", distance)
	min_distance_multiplier = config.get("min_distance_multiplier", min_distance_multiplier)
	max_distance_multiplier = config.get("max_distance_multiplier", max_distance_multiplier)
	preferred_distance_multiplier = config.get(
		"preferred_distance_multiplier", preferred_distance_multiplier
	)
	zoom_speed = config.get("zoom_speed", zoom_speed)
	_min_fov_deg = config.get("min_fov_deg", _min_fov_deg)
	_max_fov_deg = config.get("max_fov_deg", _max_fov_deg)

	current_distance = distance

	# Connect to EventBus signals
	if (
		EventBus
		and not EventBus.is_connected(
			"player_camera_zoom_changed", self, "_on_player_camera_zoom_changed"
		)
	):
		EventBus.connect("player_camera_zoom_changed", self, "_on_player_camera_zoom_changed")


# --- Public Methods ---
func handle_input(event: InputEvent):
	if event is InputEventMouseButton and is_instance_valid(_target):
		var zoom_factor = 1.0 + (zoom_speed * 0.1)
		var input_handled = false
		var new_distance_candidate = current_distance

		if event.button_index == BUTTON_WHEEL_UP and event.pressed:
			new_distance_candidate = current_distance / zoom_factor
			input_handled = true
		elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
			new_distance_candidate = current_distance * zoom_factor
			input_handled = true

		if input_handled:
			_set_and_update_zoom_distance(new_distance_candidate, false)
			get_viewport().set_input_as_handled()


func physics_update():
	# Update FoV based on current distance
	if is_instance_valid(_target):
		_update_fov()


func set_target(new_target: Spatial):
	_target = new_target
	if is_instance_valid(_target):
		_target_radius = _get_target_effective_radius(_target)
		# Reset distance to preferred when target changes
		var dyn_min_dist = _get_dynamic_min_distance()
		var dyn_max_dist = _get_dynamic_max_distance()
		var preferred_dist = max(dyn_min_dist, _target_radius * preferred_distance_multiplier)
		_set_and_update_zoom_distance(clamp(preferred_dist, dyn_min_dist, dyn_max_dist), false)
	else:
		_target_radius = 10.0

	_update_fov()


# --- Signal Handlers ---
func _on_player_camera_zoom_changed(value):
	if _is_programmatically_setting_slider:
		return

	var dyn_min_dist = _get_dynamic_min_distance()
	var dyn_max_dist = _get_dynamic_max_distance()
	var target_distance = lerp(dyn_min_dist, dyn_max_dist, value / 100.0)

	_set_and_update_zoom_distance(target_distance, true)


# --- Private Helper Methods ---
func _set_and_update_zoom_distance(new_distance: float, from_slider_event: bool = false):
	var dyn_min_dist = _get_dynamic_min_distance() + 10 # Take into account near plane
	var dyn_max_dist = _get_dynamic_max_distance()

	current_distance = clamp(new_distance, dyn_min_dist, dyn_max_dist)

	if not from_slider_event and is_instance_valid(GlobalRefs.main_hud):
		var zoom_slider = GlobalRefs.main_hud.get_node(
			"ScreenControls/CenterLeftZone/SliderControlLeft"
		)
		if is_instance_valid(zoom_slider):
			var zoom_range = dyn_max_dist - dyn_min_dist
			var normalized_value = 0.0
			if zoom_range > 0.001:
				normalized_value = 100.0 * (current_distance - dyn_min_dist) / zoom_range

			_is_programmatically_setting_slider = true
			zoom_slider.value = clamp(normalized_value, 0.0, 100.0)
			_is_programmatically_setting_slider = false


func _update_fov():
	var dyn_min_dist = _get_dynamic_min_distance()
	var dyn_max_dist = _get_dynamic_max_distance()
	if is_equal_approx(dyn_max_dist, dyn_min_dist):
		_camera.fov = _max_fov_deg
		return
	var t = clamp((current_distance - dyn_min_dist) / (dyn_max_dist - dyn_min_dist), 0.0, 1.0)
	_camera.fov = lerp(_min_fov_deg, _max_fov_deg, t)


func _get_dynamic_min_distance() -> float:
	if not is_instance_valid(_target):
		return MIN_ABSOLUTE_DISTANCE
	return max(MIN_ABSOLUTE_DISTANCE, _target_radius * min_distance_multiplier)


func _get_dynamic_max_distance() -> float:
	if not is_instance_valid(_target):
		return MAX_ABSOLUTE_DISTANCE
	var dyn_min_dist = _get_dynamic_min_distance()
	var dyn_max_calc = max(dyn_min_dist + 1.0, _target_radius * max_distance_multiplier)
	return min(MAX_ABSOLUTE_DISTANCE, dyn_max_calc)


func _get_target_effective_radius(target_node: Spatial) -> float:
	var default_radius = 10.0
	if not is_instance_valid(target_node):
		return default_radius
	if target_node.has_method("get_interaction_radius"):
		var radius = target_node.get_interaction_radius()
		if (radius is float or radius is int) and radius > 0.0:
			return max(float(radius), 1.0)
	var node_scale = target_node.global_transform.basis.get_scale()
	var max_scale = max(node_scale.x, max(node_scale.y, node_scale.z))
	return max(max_scale / 2.0, default_radius)


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if (
			EventBus
			and EventBus.is_connected(
				"player_camera_zoom_changed", self, "_on_player_camera_zoom_changed"
			)
		):
			EventBus.disconnect(
				"player_camera_zoom_changed", self, "_on_player_camera_zoom_changed"
			)

--- Start of ./src/scenes/camera/orbit_camera.gd ---

# File: scenes/camera/orbit_camera.gd
# Version: 2.2 - Removed all export variables to internalize configuration.

extends Camera

# --- INTERNAL CONFIGURATION ---
# All tuning is now done directly in this script.

# --- General ---
var distance: float = 55.0
var position_smoothing_speed: float = 30.0
var rotation_smoothing_speed: float = 18.0
var target_smoothing_speed: float = 50.0
var bob_frequency: float = 0.1
var bob_amplitude: float = 0.2

# --- Zoom & FoV ---
var zoom_speed: float = 0.5
var min_distance_multiplier: float = 1.0
var max_distance_multiplier: float = 5.0
var preferred_distance_multiplier: float = 1.0
var min_fov_deg: float = 25.0
var max_fov_deg: float = 100.0

# --- Rotation & PID ---
var pitch_min_deg: float = -83.0
var pitch_max_deg: float = 83.0
var rotation_max_speed: float = 15.0
var rotation_input_curve: float = 1.1
var pid_yaw_kp: float = 10.0
var pid_yaw_ki: float = 0.01
var pid_yaw_kd: float = 0.1
var pid_pitch_kp: float = 10.0
var pid_pitch_ki: float = 0.01
var pid_pitch_kd: float = 0.1
var pid_integral_limit: float = 10.0
var pid_output_limit_multiplier: float = 100.0

# --- Component Script Paths ---
const RotationControllerScript = preload(
	"res://src/scenes/camera/components/camera_rotation_controller.gd"
)
const ZoomControllerScript = preload("res://src/scenes/camera/components/camera_zoom_controller.gd")
const PositionControllerScript = preload(
	"res://src/scenes/camera/components/camera_position_controller.gd"
)

# --- Component Instances ---
var _rotation_controller: Node = null
var _zoom_controller: Node = null
var _position_controller: Node = null


# --- Initialization ---
func _ready():
	set_as_toplevel(true)
	GlobalRefs.main_camera = self

	# --- Instantiate and Initialize Components ---
	_rotation_controller = RotationControllerScript.new()
	_zoom_controller = ZoomControllerScript.new()
	_position_controller = PositionControllerScript.new()

	_rotation_controller.name = "RotationController"
	_zoom_controller.name = "ZoomController"
	_position_controller.name = "PositionController"

	add_child(_rotation_controller)
	add_child(_zoom_controller)
	add_child(_position_controller)

	# Package all internal vars into a config dictionary to pass to components
	var config = {
		"distance": distance,
		"position_smoothing_speed": position_smoothing_speed,
		"rotation_smoothing_speed": rotation_smoothing_speed,
		"target_smoothing_speed": target_smoothing_speed,
		"bob_frequency": bob_frequency,
		"bob_amplitude": bob_amplitude,
		"zoom_speed": zoom_speed,
		"min_distance_multiplier": min_distance_multiplier,
		"max_distance_multiplier": max_distance_multiplier,
		"preferred_distance_multiplier": preferred_distance_multiplier,
		"min_fov_deg": min_fov_deg,
		"max_fov_deg": max_fov_deg,
		"pitch_min": deg2rad(pitch_min_deg),
		"pitch_max": deg2rad(pitch_max_deg),
		"_rotation_max_speed": rotation_max_speed,
		"_rotation_input_curve": rotation_input_curve,
		"pid_yaw_kp": pid_yaw_kp,
		"pid_yaw_ki": pid_yaw_ki,
		"pid_yaw_kd": pid_yaw_kd,
		"pid_pitch_kp": pid_pitch_kp,
		"pid_pitch_ki": pid_pitch_ki,
		"pid_pitch_kd": pid_pitch_kd,
		"pid_integral_limit": pid_integral_limit,
		"pid_output_limit_multiplier": pid_output_limit_multiplier,
		"initial_yaw": PI,
		"initial_pitch": 0.25
	}

	_rotation_controller.initialize(self, config)
	_zoom_controller.initialize(self, config)
	_position_controller.initialize(self, _rotation_controller, _zoom_controller, config)

	# --- Connect Signals ---
	if (
		EventBus
		and not EventBus.is_connected(
			"camera_set_target_requested", self, "_on_camera_set_target_requested"
		)
	):
		EventBus.connect("camera_set_target_requested", self, "_on_camera_set_target_requested")

	# Proactive player check
	if is_instance_valid(GlobalRefs.player_agent_body):
		set_target_node(GlobalRefs.player_agent_body)


# --- Delegate Godot Functions to Components ---
func _unhandled_input(event):
	_rotation_controller.handle_input(event)
	_zoom_controller.handle_input(event)


func _physics_process(delta):
	_rotation_controller.physics_update(delta)
	_zoom_controller.physics_update()
	_position_controller.physics_update(delta)


# --- Public Methods (Delegating to Components) ---
func set_target_node(new_target: Spatial):
	if not is_instance_valid(_zoom_controller) or not is_instance_valid(_position_controller):
		return
	# When the target changes, inform the relevant components.
	_zoom_controller.set_target(new_target)
	_position_controller.set_target(new_target)
	print("OrbitCamera target set to: ", new_target.name if new_target else "null")


func set_rotation_input_active(is_active: bool):
	if is_instance_valid(_rotation_controller):
		_rotation_controller.set_rotation_input_active(is_active)


func set_is_rotating(rotating: bool):
	if is_instance_valid(_rotation_controller):
		_rotation_controller.set_is_rotating(rotating)


# --- Signal Handlers ---
func _on_camera_set_target_requested(target_node):
	set_target_node(target_node)


# --- Cleanup ---
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if (
			EventBus
			and EventBus.is_connected(
				"camera_set_target_requested", self, "_on_camera_set_target_requested"
			)
		):
			EventBus.disconnect(
				"camera_set_target_requested", self, "_on_camera_set_target_requested"
			)
		if GlobalRefs and GlobalRefs.main_camera == self:
			GlobalRefs.main_camera = null

--- Start of ./src/scenes/game_world/station/dockable_station.gd ---

extends StaticBody

export var location_id: String = "station_alpha"
export var station_name: String = "Station Alpha"

onready var docking_zone = $DockingZone

func _ready():
	add_to_group("dockable_station")
	print("DockableStation ready: ", station_name, " at ", global_transform.origin)
	if docking_zone:
		docking_zone.monitoring = true
		docking_zone.monitorable = true
		docking_zone.collision_layer = 1
		docking_zone.collision_mask = 1
		docking_zone.connect("body_entered", self, "_on_body_entered")
		docking_zone.connect("body_exited", self, "_on_body_exited")
		
		# Check for overlapping bodies immediately in case player spawned inside
		var bodies = docking_zone.get_overlapping_bodies()
		for body in bodies:
			_on_body_entered(body)
	else:
		printerr("DockableStation Error: DockingZone not found!")

func _on_body_entered(body):
	# Ignore self (the station's own StaticBody)
	if body == self:
		return
	# Only care about KinematicBody (ships)
	if not body is KinematicBody:
		return
		
	print("Body entered docking zone: ", body.name)
	if body.has_method("is_player"):
		print("Body has is_player method. Result: ", body.is_player())
		if body.is_player():
			EventBus.emit_signal("dock_available", location_id)
			print("Dock available at: ", station_name)
	else:
		print("Body does NOT have is_player method.")

func _on_body_exited(body):
	if body == self:
		return
	if not body is KinematicBody:
		return
	if body.has_method("is_player") and body.is_player():
		EventBus.emit_signal("dock_unavailable")
		print("Dock unavailable at: ", station_name)

--- Start of ./src/scenes/game_world/world_manager.gd ---

# File: src/scenes/game_world/world_manager.gd
# Version: 5.0 - Abstracted template indexing to a component script.

extends Node

# --- Component Scripts ---
const TemplateIndexer = preload("res://src/scenes/game_world/world_manager/template_indexer.gd")
const WorldGenerator = preload("res://src/scenes/game_world/world_manager/world_generator.gd")

# --- State ---
var _spawned_agent_bodies = []

# --- Nodes ---
var _time_clock_timer: Timer = null
var _template_indexer: Node = null
var _world_generator: Node = null

# --- Initialization ---
func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	GlobalRefs.set_world_manager(self)
	
	# Step 1: Index all data templates into the TemplateDatabase.
	_template_indexer = TemplateIndexer.new()
	_template_indexer.name = "TemplateIndexer"
	add_child(_template_indexer)
	_template_indexer.index_all_templates()

	# Step 2: Boot to Main Menu. World generation/zone load happens only after
	# the player chooses New Game / Load Game.
	_show_boot_main_menu()
	
	# Connect to agent signals to keep the local list clean.
	EventBus.connect("agent_spawned", self, "_on_Agent_Spawned")
	EventBus.connect("agent_despawning", self, "_on_Agent_Despawning")
	if EventBus.has_signal("game_state_loaded"):
		if not EventBus.is_connected("game_state_loaded", self, "_on_game_state_loaded"):
			EventBus.connect("game_state_loaded", self, "_on_game_state_loaded")
	if EventBus.has_signal("new_game_requested"):
		if not EventBus.is_connected("new_game_requested", self, "_on_new_game_requested"):
			EventBus.connect("new_game_requested", self, "_on_new_game_requested")
	

	# --- NEW: Setup the Time Clock Timer ---
	_time_clock_timer = Timer.new()
	_time_clock_timer.name = "TimeClockTimer"
	_time_clock_timer.wait_time = Constants.TIME_TICK_INTERVAL_SECONDS
	_time_clock_timer.autostart = false
	_time_clock_timer.connect("timeout", self, "_on_Time_Clock_Timer_timeout")
	add_child(_time_clock_timer)
	
	randomize()
	# Do not load a zone at boot; wait for New Game / Load.


func _on_new_game_requested() -> void:
	# Ensure we don't inherit mouse/camera capture/rotation state from a prior session.
	_reset_camera_input_state()
	# Leaving the Main Menu; resume gameplay.
	get_tree().paused = false
	if is_instance_valid(_time_clock_timer):
		_time_clock_timer.stop()  # Stop timer during cleanup

	_cleanup_all_agents()
	_cleanup_current_zone()
	
	if is_instance_valid(GameStateManager) and GameStateManager.has_method("reset_to_defaults"):
		GameStateManager.reset_to_defaults()
	else:
		printerr("WorldManager: GameStateManager.reset_to_defaults() unavailable.")
	
	# Wait a frame for cleanup to complete before loading new zone
	yield(get_tree(), "idle_frame")
	
	_setup_new_game()
	load_zone(Constants.INITIAL_ZONE_SCENE_PATH)
	
	if is_instance_valid(_time_clock_timer):
		_time_clock_timer.start()


func _on_game_state_loaded() -> void:
	# Ensure we don't inherit mouse/camera capture/rotation state from a prior session.
	_reset_camera_input_state()
	# A saved state has been applied; we now need to load a zone so AgentSpawner can
	# spawn the player from the restored GameState.
	get_tree().paused = false
	if is_instance_valid(_time_clock_timer):
		_time_clock_timer.stop()  # Stop timer during cleanup

	_cleanup_all_agents()
	_cleanup_current_zone()
	
	# Wait a frame for cleanup to complete before loading new zone
	yield(get_tree(), "idle_frame")
	
	load_zone(Constants.INITIAL_ZONE_SCENE_PATH)
	call_deferred("_emit_loaded_dock_signal")
	call_deferred("_emit_loaded_resource_signals")
	
	if is_instance_valid(_time_clock_timer):
		_time_clock_timer.start()


func _emit_loaded_resource_signals() -> void:
	if not EventBus:
		return
	if not is_instance_valid(GlobalRefs.character_system):
		return
	var player_char = GlobalRefs.character_system.get_player_character()
	if not is_instance_valid(player_char):
		return
	EventBus.emit_signal("player_wp_changed", player_char.wealth_points)
	EventBus.emit_signal("player_fp_changed", player_char.focus_points)


func _emit_loaded_dock_signal() -> void:
	var retries := 0
	while retries < 30 and (not is_instance_valid(GlobalRefs.current_zone) or not is_instance_valid(GlobalRefs.player_agent_body)):
		yield(get_tree().create_timer(0.1), "timeout")
		retries += 1

	if GameState.player_docked_at == "":
		return
	EventBus.emit_signal("player_docked", GameState.player_docked_at)
	
	
# --- Game State Setup ---
func _initialize_game_state():
	print("WorldManager: Initializing game state...")
	# This is where the logic for choosing "New Game" vs "Load Game" will go.
	# For now, we default to creating a new game.
	_setup_new_game()


func _show_boot_main_menu() -> void:
	# Pause the game at boot so no simulation/UI actions occur until New Game.
	get_tree().paused = true
	# Ask the MainMenu UI to show itself.
	if is_instance_valid(EventBus) and EventBus.has_signal("main_menu_requested"):
		EventBus.emit_signal("main_menu_requested")


func _setup_new_game():
	if is_instance_valid(_world_generator):
		_world_generator.queue_free()
		_world_generator = null
	# Instantiate and run the world generator to populate GameState.
	_world_generator = WorldGenerator.new()
	_world_generator.name = "WorldGenerator"
	add_child(_world_generator)
	_world_generator.generate_new_world()


func _cleanup_all_agents() -> void:
	for agent in _spawned_agent_bodies:
		if is_instance_valid(agent):
			agent.queue_free()
	_spawned_agent_bodies.clear()


func _cleanup_current_zone() -> void:
	"""Clean up the current zone and all its children properly."""
	if is_instance_valid(GameState.current_zone_instance):
		EventBus.emit_signal("zone_unloading", GameState.current_zone_instance)
		GameState.current_zone_instance.queue_free()
		GameState.current_zone_instance = null
	
	GlobalRefs.player_agent_body = null
	GlobalRefs.current_zone = null
	GlobalRefs.agent_container = null
	# Note: main_camera is NOT part of the zone - it's in main_game_scene, so don't clear it


func _reset_camera_input_state() -> void:
	# If the previous session ended while free-flight was active or the mouse was held,
	# the PlayerController may not get a clean state exit during cleanup.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if is_instance_valid(GlobalRefs.main_camera):
		if GlobalRefs.main_camera.has_method("set_rotation_input_active"):
			GlobalRefs.main_camera.set_rotation_input_active(false)
		if GlobalRefs.main_camera.has_method("set_is_rotating"):
			GlobalRefs.main_camera.set_is_rotating(false)


# --- Zone Management ---
func load_zone(zone_scene_path: String):
	if not zone_scene_path or zone_scene_path.empty():
		printerr("WM Error: Invalid zone path provided.")
		return

	# 1. Cleanup Previous Zone (if not already cleaned up)
	if is_instance_valid(GameState.current_zone_instance):
		_cleanup_current_zone()
		yield(get_tree(), "idle_frame")

	# 2. Find Parent Container Node
	var zone_holder = get_parent().get_node_or_null(Constants.CURRENT_ZONE_CONTAINER_NAME)
	if not is_instance_valid(zone_holder):
		printerr("WM Error: Could not find valid zone holder node!")
		return

	# 3. Load and Instance the Zone Scene
	var zone_scene = load(zone_scene_path)
	if not zone_scene:
		printerr("WM Error: Failed to load Zone Scene Resource: ", zone_scene_path)
		return

	GameState.current_zone_instance = zone_scene.instance()
	zone_holder.add_child(GameState.current_zone_instance)
	GlobalRefs.current_zone = GameState.current_zone_instance

	# 4. Find Agent Container and emit signal that the zone is ready
	var agent_container = GameState.current_zone_instance.find_node(
		Constants.AGENT_CONTAINER_NAME, true, false
	)
	GlobalRefs.agent_container = agent_container

	EventBus.emit_signal("zone_loaded", GameState.current_zone_instance, zone_scene_path, agent_container)


# --- Time System Driver ---
func _on_Time_Clock_Timer_timeout():
	# This function is now called every TIME_TICK_INTERVAL_SECONDS.
	# It drives the core time-based loop of the game.
	if is_instance_valid(GlobalRefs.time_system):
		# For now, each tick adds 1 TU. This can be modified later (e.g., based on game speed).
		GlobalRefs.time_system.add_time_units(1)
		#print("Current TU: ", GameState.current_tu)
	else:
		printerr("WorldManager: Cannot advance time, TimeSystem not registered in GlobalRefs.")


# --- Signal Handlers to maintain agent list ---
func _on_Agent_Spawned(agent_body, _init_data):
	if not _spawned_agent_bodies.has(agent_body):
		_spawned_agent_bodies.append(agent_body)


func _on_Agent_Despawning(agent_body):
	if _spawned_agent_bodies.has(agent_body):
		_spawned_agent_bodies.erase(agent_body)


func get_agent_by_uid(agent_uid: int):
	for agent_body in _spawned_agent_bodies:
		if not is_instance_valid(agent_body):
			continue
		if agent_body.get("agent_uid") != null and int(agent_body.get("agent_uid")) == agent_uid:
			return agent_body
	return null


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if GlobalRefs and GlobalRefs.world_manager == self:
			GlobalRefs.world_manager = null
		if EventBus.is_connected("agent_spawned", self, "_on_Agent_Spawned"):
			EventBus.disconnect("agent_spawned", self, "_on_Agent_Spawned")
		if EventBus.is_connected("agent_despawning", self, "_on_Agent_Despawning"):
			EventBus.disconnect("agent_despawning", self, "_on_Agent_Despawning")

--- Start of ./src/scenes/game_world/world_manager/template_indexer.gd ---

# File: src/scenes/game_world/world_manager/template_indexer.gd
# Purpose: Scans the project's data directories to find and register all
#          .tres template files into the TemplateDatabase autoload.
# Version: 1.4 - Added UtilityToolTemplate support.

extends Node

# --- Public API ---

# Main entry point. Kicks off the recursive scan of the data directory.
func index_all_templates():
	print("TemplateIndexer: Indexing all data templates...")
	_scan_directory_for_templates("res://database/registry/")
	print("TemplateIndexer: Template indexing complete.")


# --- Private Logic ---

# Recursively scans a directory path for .tres files.
func _scan_directory_for_templates(path: String):
	var dir = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# --- FIX: Skip '.' and '..' to prevent infinite recursion ---
			if file_name == "." or file_name == "..":
				file_name = dir.get_next()
				continue # Move to the next item immediately
			# --- END FIX ---

			var full_path = path.plus_file(file_name)
			if dir.current_is_dir():
				# If it's a directory, scan it recursively.
				_scan_directory_for_templates(full_path + "/")
			elif file_name.ends_with(".tres"):
				# If it's a .tres file, load it and register it.
				var template = load(full_path)
				if is_instance_valid(template) and template is Template:
					_register_template(template)
			file_name = dir.get_next()
	else:
		printerr("TemplateIndexer Error: Could not open directory for indexing: ", path)


# Determines the type of a loaded template and adds it to the correct
# dictionary in the TemplateDatabase.
func _register_template(template: Template):
	if template.template_id == "":
		printerr("Template Error: Resource file has no template_id: ", template.resource_path)
		return

	if template is ActionTemplate:
		TemplateDatabase.actions[template.template_id] = template
	elif template is AgentTemplate:
		TemplateDatabase.agents[template.template_id] = template
	elif template is CharacterTemplate:
		TemplateDatabase.characters[template.template_id] = template
	elif template is ShipTemplate:
		TemplateDatabase.assets_ships[template.template_id] = template
	elif template is ModuleTemplate:
		TemplateDatabase.assets_modules[template.template_id] = template
	elif template is CommodityTemplate:
		TemplateDatabase.assets_commodities[template.template_id] = template
	elif template is LocationTemplate:
		TemplateDatabase.locations[template.template_id] = template
	elif template is ContractTemplate:
		TemplateDatabase.contracts[template.template_id] = template
	elif template is UtilityToolTemplate:
		TemplateDatabase.utility_tools[template.template_id] = template
	else:
		print("TemplateIndexer Warning: Unknown template type for resource: ", template.resource_path)

--- Start of ./src/scenes/game_world/world_manager/world_generator.gd ---

# File: src/scenes/game_world/world_manager/world_generator.gd
# Purpose: Uses indexed templates to procedurally generate the initial game state
#          for a new game, populating the GameState autoload.
# Version: 2.2 - Added contract loading into GameState.contracts.

extends Node

const InventorySystem = preload("res://src/core/systems/inventory_system.gd")

var _next_character_uid: int = 0
var _next_ship_uid: int = 0
var _next_module_uid: int = 0
# Commodity UIDs are no longer needed as they are not unique instances.

# --- Public API ---

# Main entry point. Generates all necessary data for a new game.
func generate_new_world():
	print("WorldGenerator: Generating new world state...")

	# Load all locations into GameState first (they are keyed by template_id).
	_load_locations()
	
	# Load all contracts into GameState.
	_load_contracts()

	# Create characters first.
	for template_id in TemplateDatabase.characters:
		var template = TemplateDatabase.characters[template_id]
		_create_character_from_template(template)

	# Then, generate and assign their starting assets and inventories.
	_generate_and_assign_assets()

	# Sprint 10: Start player docked at Station Alpha, with defined starting resources.
	GameState.player_docked_at = "station_alpha"
	_apply_player_starting_state()
	call_deferred("_emit_initial_dock_signal")

	print("WorldGenerator: New world state generated.")


func _apply_player_starting_state() -> void:
	var player_uid: int = int(GameState.player_character_uid)
	if player_uid < 0:
		return
	if GameState.characters.has(player_uid):
		var player_char = GameState.characters[player_uid]
		player_char.wealth_points = 50
		player_char.focus_points = 3
		if EventBus:
			EventBus.emit_signal("player_wp_changed", player_char.wealth_points)
			EventBus.emit_signal("player_fp_changed", player_char.focus_points)

	# Starting cargo should be empty for the player.
	if GameState.inventories.has(player_uid):
		var inv = GameState.inventories[player_uid]
		if inv is Dictionary and inv.has(InventorySystem.InventoryType.COMMODITY):
			inv[InventorySystem.InventoryType.COMMODITY] = {}


func _emit_initial_dock_signal() -> void:
	# Wait until the player agent exists and the zone is loaded, then dock.
	var retries := 0
	while retries < 30 and (not is_instance_valid(GlobalRefs.current_zone) or not is_instance_valid(GlobalRefs.player_agent_body)):
		yield(get_tree().create_timer(0.1), "timeout")
		retries += 1

	if GameState.player_docked_at == "":
		return

	# Move the player agent to the docked station position (so they truly spawn there).
	var dock_id: String = GameState.player_docked_at
	if is_instance_valid(GlobalRefs.player_agent_body):
		var dock_pos = _get_dock_position_in_zone(dock_id)
		if dock_pos != null:
			var spawn_pos: Vector3 = dock_pos + Vector3(0, 5, 15)
			var t: Transform = GlobalRefs.player_agent_body.global_transform
			t.origin = spawn_pos
			GlobalRefs.player_agent_body.global_transform = t

	if EventBus:
		EventBus.emit_signal("player_docked", GameState.player_docked_at)


func _get_dock_position_in_zone(location_id: String):
	if location_id == "":
		return null
	if is_instance_valid(GlobalRefs.current_zone):
		var stations = get_tree().get_nodes_in_group("dockable_station")
		for station in stations:
			if not is_instance_valid(station):
				continue
			if not (station is Spatial):
				continue
			if not GlobalRefs.current_zone.is_a_parent_of(station):
				continue
			if station.get("location_id") == location_id:
				return station.global_transform.origin

	if GameState.locations.has(location_id):
		var loc = GameState.locations[location_id]
		if loc and loc.get("position_in_zone") is Vector3:
			return loc.position_in_zone

	return null


# --- Private Logic ---

# Loads all location templates into GameState.locations.
# Locations are stored directly by their template_id (they don't have UIDs).
func _load_locations():
	print("WorldGenerator: Loading locations...")
	for template_id in TemplateDatabase.locations:
		var template = TemplateDatabase.locations[template_id]
		# Duplicate to allow runtime modifications (e.g., market price fluctuation).
		GameState.locations[template_id] = template.duplicate()
		print("... Loaded location: ", template.location_name)


# Loads all contract templates into GameState.contracts.
# Contracts are stored by their template_id (available pool).
func _load_contracts():
	print("WorldGenerator: Loading contracts...")
	for template_id in TemplateDatabase.contracts:
		var template = TemplateDatabase.contracts[template_id]
		# Duplicate to allow runtime state tracking.
		GameState.contracts[template_id] = template.duplicate()
		print("... Loaded contract: ", template.title)


# Creates a unique instance of a character from a template and registers it
# in the global GameState. It also creates their inventory.
func _create_character_from_template(template: CharacterTemplate):
	var new_character_instance = template.duplicate()
	var uid = _get_new_character_uid()

	# Populate the GameState with the new character.
	GameState.characters[uid] = new_character_instance

	# --- NEW: Create an inventory record for this character ---
	if is_instance_valid(GlobalRefs.inventory_system):
		GlobalRefs.inventory_system.create_inventory_for_character(uid)
	# --- END NEW ---

	# Designate the player character.
	if template.template_id == "character_default":
		GameState.player_character_uid = uid
		print("... Player character created with UID: ", uid)
	else:
		print("... NPC character created with UID: ", uid)


# Generates starting assets and assigns them to characters using the InventorySystem.
func _generate_and_assign_assets():
	print("WorldGenerator: Generating and assigning starting assets...")
	for char_uid in GameState.characters:
		var character = GameState.characters[char_uid]
		
		# Create and assign a starting ship.
		var ship_uid = _create_ship_instance("ship_default")
		if ship_uid != -1:
			# Add the ship to the character's inventory.
			GlobalRefs.inventory_system.add_asset(char_uid, GlobalRefs.inventory_system.InventoryType.SHIP, ship_uid)
			# Set this ship as the character's active vessel.
			character.active_ship_uid = ship_uid
			print("... Assigned ship (UID: %d) to character %s" % [ship_uid, character.character_name])

		# Create and assign a starting module.
		var module_uid = _create_module_instance("module_default")
		if module_uid != -1:
			GlobalRefs.inventory_system.add_asset(char_uid, GlobalRefs.inventory_system.InventoryType.MODULE, module_uid)
			print("... Assigned module (UID: %d) to character %s" % [module_uid, character.character_name])
			
		# Sprint 10: Player starting cargo should be empty.
		# (NPC starting cargo can be added later if needed for simulation.)


# Creates a unique instance of a ship and returns its UID.
func _create_ship_instance(ship_template_id: String) -> int:
	if not TemplateDatabase.assets_ships.has(ship_template_id):
		printerr("WorldGenerator Error: Cannot find ship template with id: ", ship_template_id)
		return -1

	var template = TemplateDatabase.assets_ships[ship_template_id]
	var new_ship_instance = template.duplicate()
	var uid = _get_new_ship_uid()
	GameState.assets_ships[uid] = new_ship_instance
	return uid


# Creates a unique instance of a module and returns its UID.
func _create_module_instance(module_template_id: String) -> int:
	if not TemplateDatabase.assets_modules.has(module_template_id):
		printerr("WorldGenerator Error: Cannot find module template with id: ", module_template_id)
		return -1
		
	var template = TemplateDatabase.assets_modules[module_template_id]
	var new_module_instance = template.duplicate()
	var uid = _get_new_module_uid()
	GameState.assets_modules[uid] = new_module_instance
	return uid


# --- UID Generation ---
func _get_new_character_uid() -> int:
	var id = _next_character_uid
	_next_character_uid += 1
	return id

func _get_new_ship_uid() -> int:
	var id = _next_ship_uid
	_next_ship_uid += 1
	return id

func _get_new_module_uid() -> int:
	var id = _next_module_uid
	_next_module_uid += 1
	return id

--- Start of ./src/scenes/game_world/world_rendering.gd ---

# File: scenes/game_world/world_rendering.gd
# Version: 1.0 - Handles rendering options for viewport as a whole.

extends Node

var viewport_downscale_factor = 1.0
var viewport_msaa = Viewport.MSAA_DISABLED
var viewport_fxaa = false
var viewport_disable_3d = false
var viewport_sharpen_intensity = 0.5
var viewport_keep_3d_linear = false


var _viewport_size = Vector2(1920, 1080)
var _prev_viewport_size = Vector2(1920, 1080)

func _ready():
	get_viewport().msaa = viewport_msaa
	get_viewport().fxaa = viewport_fxaa
	get_viewport().disable_3d = viewport_disable_3d
	get_viewport().sharpen_intensity = viewport_sharpen_intensity
	get_viewport().keep_3d_linear = viewport_keep_3d_linear
	print("Viewport: Is ready")

func _process(delta):
	# Handle each option via signal instead maybe.
	
	_viewport_size = get_viewport().size 
	if _viewport_size != _prev_viewport_size:
		get_viewport().size = _viewport_size / viewport_downscale_factor
		_prev_viewport_size = get_viewport().size
		print(_viewport_size)

--- Start of ./src/scenes/ui/station_menu/contract_interface.gd ---

extends Control

onready var list_contracts = $Panel/HBoxContainer/VBoxList/ItemListContracts
onready var text_details = $Panel/HBoxContainer/VBoxDetails/RichTextLabelDetails
onready var btn_accept = $Panel/HBoxControls/BtnAccept
onready var btn_close = $Panel/HBoxControls/BtnClose

var current_location_id: String = ""
var selected_contract_idx: int = -1

func _ready():
	btn_close.connect("pressed", self, "_on_close_pressed")
	btn_accept.connect("pressed", self, "_on_accept_pressed")
	list_contracts.connect("item_selected", self, "_on_contract_selected")

func open(location_id: String):
	current_location_id = location_id
	visible = true
	refresh_list()

func refresh_list():
	list_contracts.clear()
	text_details.text = "Select a contract to view details."
	selected_contract_idx = -1
	btn_accept.disabled = true
	
	if GlobalRefs.contract_system:
		var contracts = GlobalRefs.contract_system.get_available_contracts_for_character(GameState.player_character_uid, current_location_id)
		
		for contract in contracts:
			var text = "%s (%s)" % [contract.title, contract.contract_type]
			list_contracts.add_item(text)
			# Store template_id as metadata
			list_contracts.set_item_metadata(list_contracts.get_item_count() - 1, contract.template_id)

func _on_contract_selected(index):
	selected_contract_idx = index
	btn_accept.disabled = false
	
	var contract_id = list_contracts.get_item_metadata(index)
	if GameState.contracts.has(contract_id):
		var contract = GameState.contracts[contract_id]
		_display_contract_details(contract)

func _display_contract_details(contract):
	var details = "Title: %s\n" % contract.title
	details += "Type: %s\n" % contract.contract_type
	details += "Difficulty: %d\n" % contract.difficulty
	details += "Reward: %d WP\n" % contract.reward_wp
	details += "Time Limit: %d TU\n\n" % contract.time_limit_tu
	details += "Description:\n%s\n\n" % contract.description
	
	if contract.contract_type == "delivery":
		details += "Cargo Required: %s (Qty: %d)\n" % [contract.required_commodity_id, contract.required_quantity]
		details += "Destination: %s\n" % contract.destination_location_id
	
	text_details.text = details

func _on_accept_pressed():
	print("DEBUG: _on_accept_pressed called. Selected Idx: ", selected_contract_idx)
	if selected_contract_idx == -1: return
	var contract_id = list_contracts.get_item_metadata(selected_contract_idx)
	print("DEBUG: Contract ID from metadata: ", contract_id)
	
	if GlobalRefs.contract_system:
		print("DEBUG: ContractSystem found. Calling accept_contract...")
		var result = GlobalRefs.contract_system.accept_contract(GameState.player_character_uid, contract_id)
		if result.success:
			print("Accepted contract: ", contract_id)
			refresh_list()
		else:
			print("Failed to accept contract: ", result.reason)
			text_details.text += "\n\nERROR: " + result.reason
	else:
		print("DEBUG: GlobalRefs.contract_system is NULL")

func _on_close_pressed():
	visible = false

--- Start of ./src/scenes/ui/station_menu/station_menu.gd ---

extends Control

onready var label_station_name = $Panel/VBoxContainer/LabelStationName
onready var btn_trade = $Panel/VBoxContainer/BtnTrade
onready var btn_contracts = $Panel/VBoxContainer/BtnContracts
onready var btn_complete_contract = $Panel/VBoxContainer/BtnCompleteContract
onready var btn_undock = $Panel/VBoxContainer/BtnUndock

onready var contract_popup = $ContractCompletePopup
onready var label_popup_title = $ContractCompletePopup/VBoxContainer/LabelPopupTitle
onready var label_popup_info = $ContractCompletePopup/VBoxContainer/LabelPopupInfo
onready var btn_popup_ok = $ContractCompletePopup/VBoxContainer/BtnPopupOK

const TradeInterfaceScene = preload("res://scenes/ui/menus/station_menu/TradeInterface.tscn")
const ContractInterfaceScene = preload("res://scenes/ui/menus/station_menu/ContractInterface.tscn")
var trade_interface_instance = null
var contract_interface_instance = null

var current_location_id: String = ""
var completable_contract_id: String = ""
var completable_contract_title: String = ""

var _pending_contract_completion: String = ""
var _last_ready_popup_contract_id: String = ""

func _ready():
	visible = false
	EventBus.connect("player_docked", self, "_on_player_docked")
	EventBus.connect("player_undocked", self, "_on_player_undocked")
	EventBus.connect("narrative_action_resolved", self, "_on_narrative_resolved")
	EventBus.connect("contract_accepted", self, "_on_contract_accepted")
	EventBus.connect("contract_completed", self, "_on_contract_completed")
	EventBus.connect("trade_transaction_completed", self, "_on_trade_transaction_completed")
	
	btn_undock.connect("pressed", self, "_on_undock_pressed")
	btn_trade.connect("pressed", self, "_on_trade_pressed")
	btn_contracts.connect("pressed", self, "_on_contracts_pressed")
	btn_complete_contract.connect("pressed", self, "_on_complete_contract_pressed")
	btn_popup_ok.connect("pressed", self, "_on_popup_ok_pressed")
	
	trade_interface_instance = TradeInterfaceScene.instance()
	add_child(trade_interface_instance)
	trade_interface_instance.visible = false
	
	contract_interface_instance = ContractInterfaceScene.instance()
	add_child(contract_interface_instance)
	contract_interface_instance.visible = false

func _on_player_docked(location_id):
	# Ensure docked location is updated before we check contract completion.
	# PlayerController also sets this, but signal handler order is not guaranteed.
	GameState.player_docked_at = location_id
	current_location_id = location_id
	visible = true
	
	# Get station name from location data
	var station_name = location_id
	if GameState.locations.has(location_id):
		var loc = GameState.locations[location_id]
		if loc.location_name != "":
			station_name = loc.location_name
	
	if label_station_name:
		label_station_name.text = station_name
	
	print("Station Menu Opened for: ", location_id)
	_check_completable_contracts()

func _check_completable_contracts():
	btn_complete_contract.visible = false
	completable_contract_id = ""
	completable_contract_title = ""
	
	if not GlobalRefs.contract_system:
		print("StationMenu: ContractSystem not available")
		return
	
	print("StationMenu: Checking contracts for player uid: ", GameState.player_character_uid)
	print("StationMenu: Player docked at: '", GameState.player_docked_at, "'")
	
	var active_contracts = GlobalRefs.contract_system.get_active_contracts(GameState.player_character_uid)
	print("StationMenu: Found ", active_contracts.size(), " active contracts")
	
	for contract in active_contracts:
		print("StationMenu: Checking contract '", contract.title, "' - destination: '", contract.destination_location_id, "'")
		var result = GlobalRefs.contract_system.check_contract_completion(GameState.player_character_uid, contract.template_id)
		print("StationMenu: Can complete: ", result.can_complete, ", Reason: ", result.get("reason", ""))
		if result.can_complete:
			completable_contract_id = contract.template_id
			completable_contract_title = contract.title
			btn_complete_contract.text = "✓ Complete: " + contract.title
			btn_complete_contract.visible = true
			
			# Show a popup to notify player they can complete the contract
			if completable_contract_id != _last_ready_popup_contract_id:
				_last_ready_popup_contract_id = completable_contract_id
				_show_contract_ready_popup(contract)
			break

func _show_contract_ready_popup(contract):
	if contract_popup and label_popup_info:
		if label_popup_title:
			label_popup_title.text = "CONTRACT READY"
		label_popup_info.text = "You can complete:\n\n[%s]\n\nReward: %d WP" % [contract.title, contract.reward_wp]
		contract_popup.popup_centered()


func _show_contract_accepted_popup(contract_id: String) -> void:
	if not (contract_popup and label_popup_info):
		return
	if label_popup_title:
		label_popup_title.text = "CONTRACT ACCEPTED"
	var contract = GameState.active_contracts.get(contract_id, null)
	if contract:
		var info: String = "[%s]" % contract.title
		if contract.contract_type == "delivery":
			info += "\n\nDeliver: %s x%d" % [contract.required_commodity_id, contract.required_quantity]
			info += "\nTo: %s" % contract.destination_location_id
			info += "\n\nReward: %d WP" % contract.reward_wp
		label_popup_info.text = info
	else:
		label_popup_info.text = "Contract accepted: %s" % contract_id
	contract_popup.popup_centered()


func _on_contract_accepted(contract_id):
	# Only show a popup if we're currently docked (StationMenu is on screen).
	if not visible:
		return
	_show_contract_accepted_popup(str(contract_id))
	_check_completable_contracts()


func _on_contract_completed(_contract_id, _success = null):
	# After completion, clear ready-popup guard so other contracts can prompt.
	_last_ready_popup_contract_id = ""
	if visible:
		_check_completable_contracts()


func _on_trade_transaction_completed(_tx: Dictionary):
	# Cargo changes while docked can make a contract completable.
	if visible:
		_check_completable_contracts()

func _on_popup_ok_pressed():
	if contract_popup:
		contract_popup.hide()

func _on_complete_contract_pressed():
	if completable_contract_id == "":
		return

	_pending_contract_completion = completable_contract_id

	# Request narrative action instead of completing directly.
	var narrative_system = GlobalRefs.get("narrative_action_system")
	if is_instance_valid(narrative_system) and narrative_system.has_method("request_action"):
		narrative_system.request_action(
			"contract_complete",
			{
				"char_uid": GameState.player_character_uid,
				"contract_id": completable_contract_id,
				"description": "Finalize delivery of '%s'. How do you approach the handoff?" % completable_contract_title
			}
		)
	else:
		# Fallback: complete without narrative check.
		_finalize_contract_completion()
		_pending_contract_completion = ""


func _on_narrative_resolved(result: Dictionary):
	if _pending_contract_completion == "":
		return
	if str(result.get("action_type", "")) != "contract_complete":
		return
	_finalize_contract_completion()
	_pending_contract_completion = ""


func _finalize_contract_completion():
	if GlobalRefs.contract_system:
		var result = GlobalRefs.contract_system.complete_contract(
			GameState.player_character_uid,
			completable_contract_id
		)
		if result.success:
			print("Contract Completed: ", completable_contract_id)
			# Show completion popup
			if contract_popup and label_popup_info:
				if label_popup_title:
					label_popup_title.text = "CONTRACT COMPLETE!"
				var rewards = result.get("rewards", {})
				var wp_earned = rewards.get("wp", 0)
				label_popup_info.text = "Contract Complete!\n\n[%s]\n\nEarned: %d WP" % [completable_contract_title, wp_earned]
				contract_popup.popup_centered()
			_check_completable_contracts()
		else:
			print("Failed to complete contract: ", result.reason)

func _on_player_undocked():
	visible = false
	current_location_id = ""
	_pending_contract_completion = ""
	_last_ready_popup_contract_id = ""
	if trade_interface_instance:
		trade_interface_instance.visible = false
	if contract_interface_instance:
		contract_interface_instance.visible = false
	if contract_popup:
		contract_popup.hide()
	print("Station Menu Closed")

func _on_undock_pressed():
	EventBus.emit_signal("player_undocked")

func _on_trade_pressed():
	if trade_interface_instance:
		trade_interface_instance.open(current_location_id)

func _on_contracts_pressed():
	if contract_interface_instance:
		contract_interface_instance.open(current_location_id)

--- Start of ./src/scenes/ui/station_menu/trade_interface.gd ---

extends Control

onready var list_station = $Panel/VBoxMain/HBoxContent/VBoxStation/ItemListStation
onready var list_player = $Panel/VBoxMain/HBoxContent/VBoxPlayer/ItemListPlayer
onready var btn_buy = $Panel/VBoxMain/HBoxControls/BtnBuy
onready var btn_sell = $Panel/VBoxMain/HBoxControls/BtnSell
onready var spin_quantity = $Panel/VBoxMain/HBoxControls/SpinQuantity
onready var btn_close = $Panel/VBoxMain/HBoxControls/BtnClose
onready var label_wp = $Panel/VBoxMain/HBoxHeader/LabelWP
onready var label_status = $Panel/VBoxMain/LabelStatus
onready var rich_text_prices = $Panel/VBoxMain/HBoxContent/VBoxInfo/ScrollContainer/RichTextLabelPrices

var current_location_id: String = ""
var selected_station_item_idx: int = -1
var selected_player_item_idx: int = -1

var _selected_comm_id: String = ""
var _trade_mode: String = "" # "buy" | "sell" | ""

func _ready():
	btn_close.connect("pressed", self, "_on_close_pressed")
	btn_buy.connect("pressed", self, "_on_buy_pressed")
	btn_sell.connect("pressed", self, "_on_sell_pressed")
	if spin_quantity:
		spin_quantity.connect("value_changed", self, "_on_quantity_changed")
	
	list_station.connect("item_selected", self, "_on_station_item_selected")
	list_player.connect("item_selected", self, "_on_player_item_selected")

func open(location_id: String):
	current_location_id = location_id
	visible = true
	refresh_lists()
	_update_wp_display()
	_clear_price_comparison()
	_reset_quantity_selector()

func _update_wp_display():
	if label_wp and GlobalRefs.character_system:
		var wp = GlobalRefs.character_system.get_wp(GameState.player_character_uid)
		label_wp.text = "Wealth Points: %d WP" % wp

func _clear_price_comparison():
	if rich_text_prices:
		rich_text_prices.bbcode_text = "[center]Select an item to see prices at all stations.[/center]"

func refresh_lists():
	list_station.clear()
	list_player.clear()
	selected_station_item_idx = -1
	selected_player_item_idx = -1
	_selected_comm_id = ""
	_trade_mode = ""
	btn_buy.disabled = true
	btn_sell.disabled = true
	_reset_quantity_selector()
	if label_status:
		label_status.text = "Select an item to trade"
	
	# Populate Station Market
	if GameState.locations.has(current_location_id):
		var location = GameState.locations[current_location_id]
		var market_inventory = location.get("market_inventory")
		
		if market_inventory:
			for comm_id in market_inventory:
				var item = market_inventory[comm_id]
				var buy_price = item.get("buy_price", item.get("price", 0))
				var qty = item.get("quantity", 0)
				var display_name = _get_commodity_display_name(comm_id)
				var text = "%s x%d - %d WP" % [display_name, qty, buy_price]
				list_station.add_item(text)
				list_station.set_item_metadata(list_station.get_item_count() - 1, comm_id)
	
	# Populate Player Inventory
	var player_uid = GameState.player_character_uid
	if GlobalRefs.inventory_system:
		var commodities = GlobalRefs.inventory_system.get_inventory_by_type(player_uid, GlobalRefs.inventory_system.InventoryType.COMMODITY)
		
		for comm_id in commodities:
			var qty = commodities[comm_id]
			# Get sell price from market
			var sell_price = 0
			if GameState.locations.has(current_location_id):
				var loc = GameState.locations[current_location_id]
				var loc_market = loc.get("market_inventory")
				if loc_market and loc_market.has(comm_id):
					sell_price = loc_market[comm_id].get("sell_price", loc_market[comm_id].get("price", 0))
			
			var display_name = _get_commodity_display_name(comm_id)
			var text = "%s x%d - %d WP" % [display_name, qty, sell_price]
			list_player.add_item(text)
			list_player.set_item_metadata(list_player.get_item_count() - 1, comm_id)

func _get_commodity_display_name(comm_id: String) -> String:
	if TemplateDatabase.assets_commodities.has(comm_id):
		var template = TemplateDatabase.assets_commodities[comm_id]
		if template and template.get("commodity_name"):
			return template.commodity_name
	var display_name = comm_id.replace("commodity_", "").capitalize()
	return display_name

func _generate_price_comparison(comm_id: String):
	if not rich_text_prices:
		return
	
	var display_name = _get_commodity_display_name(comm_id)
	var text = "[center][b]%s[/b][/center]\n\n" % display_name
	text += "[u]Prices at All Stations:[/u]\n\n"
	
	# Loop through all locations
	for loc_id in GameState.locations:
		var location = GameState.locations[loc_id]
		var loc_name = location.location_name if location.location_name != "" else loc_id
		var market = location.market_inventory
		
		if market.has(comm_id):
			var item = market[comm_id]
			var buy_price = item.get("buy_price", item.get("price", 0))
			var sell_price = item.get("sell_price", item.get("price", 0))
			var qty = item.get("quantity", 0)
			
			# Highlight current location
			if loc_id == current_location_id:
				text += "[color=yellow]► %s[/color]\n" % loc_name
			else:
				text += "%s\n" % loc_name
			
			text += "  Buy: [color=red]%d WP[/color]\n" % buy_price
			text += "  Sell: [color=green]%d WP[/color]\n" % sell_price
			text += "  Stock: %d\n\n" % qty
		else:
			if loc_id == current_location_id:
				text += "[color=yellow]► %s[/color]\n" % loc_name
			else:
				text += "%s\n" % loc_name
			text += "  [i]Not available[/i]\n\n"
	
	rich_text_prices.bbcode_text = text

func _on_station_item_selected(index):
	selected_station_item_idx = index
	list_player.unselect_all()
	selected_player_item_idx = -1
	btn_buy.disabled = false
	btn_sell.disabled = true
	
	var comm_id = list_station.get_item_metadata(index)
	_selected_comm_id = str(comm_id)
	_trade_mode = "buy"
	_generate_price_comparison(comm_id)
	_configure_quantity_for_buy(_selected_comm_id)
	_update_trade_status_text()

func _on_player_item_selected(index):
	selected_player_item_idx = index
	list_station.unselect_all()
	selected_station_item_idx = -1
	btn_buy.disabled = true
	btn_sell.disabled = false
	
	var comm_id = list_player.get_item_metadata(index)
	_selected_comm_id = str(comm_id)
	_trade_mode = "sell"
	_generate_price_comparison(comm_id)
	_configure_quantity_for_sell(_selected_comm_id)
	_update_trade_status_text()


func _reset_quantity_selector() -> void:
	if not spin_quantity:
		return
	spin_quantity.editable = false
	spin_quantity.min_value = 1
	spin_quantity.max_value = 1
	spin_quantity.value = 1


func _configure_quantity_for_buy(comm_id: String) -> void:
	if not spin_quantity:
		return
	var max_qty := 1
	if GameState.locations.has(current_location_id):
		var loc = GameState.locations[current_location_id]
		var item = loc.market_inventory.get(comm_id, {})
		max_qty = int(item.get("quantity", 1))
	spin_quantity.min_value = 1
	spin_quantity.max_value = max(1, max_qty)
	spin_quantity.value = 1
	spin_quantity.editable = true


func _configure_quantity_for_sell(comm_id: String) -> void:
	if not spin_quantity:
		return
	var max_qty := 1
	if is_instance_valid(GlobalRefs.inventory_system):
		max_qty = int(GlobalRefs.inventory_system.get_asset_count(
			GameState.player_character_uid,
			GlobalRefs.inventory_system.InventoryType.COMMODITY,
			comm_id
		))
	spin_quantity.min_value = 1
	spin_quantity.max_value = max(1, max_qty)
	spin_quantity.value = 1
	spin_quantity.editable = true


func _on_quantity_changed(_value) -> void:
	_update_trade_status_text()


func _get_selected_quantity() -> int:
	if spin_quantity:
		return int(spin_quantity.value)
	return 1


func _update_trade_status_text() -> void:
	if not label_status:
		return
	if _selected_comm_id == "" or _trade_mode == "":
		label_status.text = "Select an item to trade"
		return
	if not GameState.locations.has(current_location_id):
		label_status.text = "Location not found"
		return

	var loc = GameState.locations[current_location_id]
	var item = loc.market_inventory.get(_selected_comm_id, {})
	var qty := _get_selected_quantity()
	if _trade_mode == "buy":
		var unit_price = int(item.get("buy_price", item.get("price", 0)))
		label_status.text = "Buy %d %s for %d WP" % [qty, _get_commodity_display_name(_selected_comm_id), unit_price * qty]
	elif _trade_mode == "sell":
		var unit_price = int(item.get("sell_price", item.get("price", 0)))
		label_status.text = "Sell %d %s for %d WP" % [qty, _get_commodity_display_name(_selected_comm_id), unit_price * qty]

func _on_buy_pressed():
	if selected_station_item_idx == -1:
		return
	var comm_id = list_station.get_item_metadata(selected_station_item_idx)
	var qty := _get_selected_quantity()
	
	if GlobalRefs.trading_system:
		var result = GlobalRefs.trading_system.execute_buy(GameState.player_character_uid, current_location_id, comm_id, qty)
		if result.success:
			refresh_lists()
			_update_wp_display()
			_generate_price_comparison(comm_id)
			label_status.text = "Bought %d %s" % [qty, _get_commodity_display_name(comm_id)]
		else:
			if label_status:
				label_status.text = result.reason

func _on_sell_pressed():
	if selected_player_item_idx == -1:
		return
	var comm_id = list_player.get_item_metadata(selected_player_item_idx)
	var qty := _get_selected_quantity()
	
	if GlobalRefs.trading_system:
		var result = GlobalRefs.trading_system.execute_sell(GameState.player_character_uid, current_location_id, comm_id, qty)
		if result.success:
			refresh_lists()
			_update_wp_display()
			_generate_price_comparison(comm_id)
			label_status.text = "Sold %d %s" % [qty, _get_commodity_display_name(comm_id)]
		else:
			if label_status:
				label_status.text = result.reason

func _on_close_pressed():
	visible = false

--- Start of ./src/tests/autoload/test_constants.gd ---

# File: tests/autoload/test_constants.gd
# GUT Test Script for Constants.gd Autoload
# Version: 1.1 - Updated for ActionApproach thresholds

extends GutTest


func test_action_check_thresholds_are_correct():
	# Test Cautious thresholds
	assert_eq(
		Constants.ACTION_CHECK_CRIT_THRESHOLD_CAUTIOUS, 14, "Cautious Crit threshold should be 14."
	)
	assert_eq(
		Constants.ACTION_CHECK_SWC_THRESHOLD_CAUTIOUS, 10, "Cautious SwC threshold should be 10."
	)

	# Test Risky thresholds
	assert_eq(Constants.ACTION_CHECK_CRIT_THRESHOLD_RISKY, 16, "Risky Crit threshold should be 16.")
	assert_eq(Constants.ACTION_CHECK_SWC_THRESHOLD_RISKY, 12, "Risky SwC threshold should be 12.")
	prints("Tested Action Check Thresholds")


func test_action_approach_enum_exists():
	# Test that the enum and its values exist and are correct.
	assert_not_null(Constants.ActionApproach, "ActionApproach enum should exist.")
	assert_eq(Constants.ActionApproach.CAUTIOUS, 0, "CAUTIOUS should be enum value 0.")
	assert_eq(Constants.ActionApproach.RISKY, 1, "RISKY should be enum value 1.")
	prints("Tested ActionApproach Enum")


func test_focus_constants():
	assert_eq(Constants.FOCUS_MAX_DEFAULT, 3, "Default Max Focus check")
	assert_eq(Constants.FOCUS_BOOST_PER_POINT, 1, "Focus boost per point check")
	prints("Tested Focus Constants")


func test_core_scene_paths_exist():
	# Check if the constants point to *something* - doesn't guarantee validity yet
	assert_ne(Constants.NPC_AGENT_SCENE_PATH, "", "NPC Agent Scene Path should not be empty")
	assert_ne(Constants.PLAYER_AGENT_SCENE_PATH, "", "Player Agent Scene Path should not be empty")
	assert_ne(Constants.INITIAL_ZONE_SCENE_PATH, "", "Initial Zone Scene Path should not be empty")
	prints("Tested Core Scene Paths Existence (basic check)")


func test_core_node_names_exist():
	assert_ne(Constants.AGENT_CONTAINER_NAME, "", "Agent Container Name check")
	assert_ne(Constants.AGENT_BODY_NODE_NAME, "", "Agent Body Node Name check")
	assert_true(Constants.ENTRY_POINT_NAMES is Array, "Entry Point Names should be an Array")
	assert_true(Constants.ENTRY_POINT_NAMES.size() > 0, "Entry Point Names should not be empty")
	prints("Tested Core Node Names Existence")

--- Start of ./src/tests/autoload/test_core_mechanics_api.gd ---

# File: tests/autoload/test_core_mechanics_api.gd
# GUT Test Script for CoreMechanicsAPI.gd Autoload
# Version 1.2 - Updated for new perform_action_check() signature and ActionApproach

extends GutTest

# --- Test Parameters ---
# Dummy values to be used in tests, improving readability.
const ATTR = 4
const SKILL = 2
const FOCUS = 1
const CAUTIOUS = Constants.ActionApproach.CAUTIOUS
const RISKY = Constants.ActionApproach.RISKY


func test_perform_action_check_return_structure():
	var result = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, FOCUS, CAUTIOUS)
	assert_typeof(result, TYPE_DICTIONARY, "Result should be a Dictionary.")
	assert_has(result, "roll_total", "Result must contain 'roll_total'.")
	assert_has(result, "result_tier", "Result must contain 'result_tier'.")
	assert_has(result, "tier_name", "Result must contain 'tier_name'.")  # New key
	assert_has(result, "focus_gain", "Result must contain 'focus_gain'.")
	assert_has(result, "focus_loss_reset", "Result must contain 'focus_loss_reset'.")
	prints("Tested Action Check: Return Structure")


func test_action_check_focus_bonus_calculation():
	# With 0 focus spent, bonus should be 0.
	var result_0fp = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, 0, CAUTIOUS)
	assert_eq(result_0fp.focus_spent, 0)
	assert_eq(result_0fp.focus_bonus, 0)
	assert_eq(result_0fp.roll_total, result_0fp.dice_sum + ATTR + SKILL)

	# With 2 focus spent, bonus should be 2.
	var result_2fp = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, 2, RISKY)
	assert_eq(result_2fp.focus_spent, 2)
	assert_eq(result_2fp.focus_bonus, 2 * Constants.FOCUS_BOOST_PER_POINT)
	assert_eq(result_2fp.roll_total, result_2fp.dice_sum + ATTR + SKILL + 2)
	prints("Tested Action Check: Focus Bonus Calculation")


func test_action_check_focus_spending_clamp():
	# Spending more than max should clamp down to max.
	var result_over = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, 5, CAUTIOUS)
	assert_eq(result_over.focus_spent, Constants.FOCUS_MAX_DEFAULT)

	# Spending negative should clamp up to 0.
	var result_neg = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, -2, RISKY)
	assert_eq(result_neg.focus_spent, 0)
	prints("Tested Action Check: Focus Spending Clamp")


func test_action_check_tier_boundaries_cautious():
	# To guarantee failure, max roll (18) + mod + bonus must be less than SwC threshold.
	# 18 + mod < 10  => mod < -8. We use -9.
	var result_fail = CoreMechanicsAPI.perform_action_check(-9, 0, 0, CAUTIOUS)
	assert_eq(result_fail.result_tier, "Failure", "[Cautious] Guaranteed failure check.")
	assert_true(result_fail.focus_loss_reset, "[Cautious] Failure should reset focus.")

	# To guarantee critical success, min roll (3) + mod + bonus must be >= Crit threshold.
	# 3 + mod >= 14 => mod >= 11. We use 11.
	var result_crit = CoreMechanicsAPI.perform_action_check(11, 0, 0, CAUTIOUS)
	assert_eq(
		result_crit.result_tier, "CritSuccess", "[Cautious] Guaranteed critical success check."
	)
	assert_eq(result_crit.focus_gain, 1, "[Cautious] Crit should grant focus.")
	prints("Tested Action Check: Cautious Tier Boundaries")


func test_action_check_tier_boundaries_risky():
	# To guarantee failure: 18 + mod < 12 => mod < -6. We use -7.
	var result_fail = CoreMechanicsAPI.perform_action_check(-7, 0, 0, RISKY)
	assert_eq(result_fail.result_tier, "Failure", "[Risky] Guaranteed failure check.")

	# To guarantee critical success: 3 + mod >= 16 => mod >= 13. We use 13.
	var result_crit = CoreMechanicsAPI.perform_action_check(13, 0, 0, RISKY)
	assert_eq(result_crit.result_tier, "CritSuccess", "[Risky] Guaranteed critical success check.")
	prints("Tested Action Check: Risky Tier Boundaries")

--- Start of ./src/tests/autoload/test_event_bus.gd ---

# File: tests/autoload/test_event_bus.gd
# GUT Test Script for EventBus.gd Autoload
# Version 1.3 - Adjusted for revised signal_catcher logic

extends GutTest

const SignalCatcher = preload("res://src/tests/helpers/signal_catcher.gd")
var listener = null


func before_each():
	listener = Node.new()
	listener.set_script(SignalCatcher)
	add_child_autofree(listener)
	listener.reset()


func after_each():
	# Disconnect signals manually if needed
	if EventBus.is_connected("agent_spawned", listener, "_on_signal_received"):
		EventBus.disconnect("agent_spawned", listener, "_on_signal_received")
	if EventBus.is_connected("camera_set_target_requested", listener, "_on_signal_received"):
		EventBus.disconnect("camera_set_target_requested", listener, "_on_signal_received")
	if EventBus.is_connected("agent_reached_destination", listener, "_on_signal_received"):
		EventBus.disconnect("agent_reached_destination", listener, "_on_signal_received")


# --- Test Methods ---


func test_agent_spawned_signal_emission_and_parameters():
	var connect_error = EventBus.connect("agent_spawned", listener, "_on_signal_received")
	assert_eq(connect_error, OK, "Connect agent_spawned.")
	watch_signals(EventBus)
	var dummy_agent_body = Node.new()
	add_child_autofree(dummy_agent_body)
	var dummy_init_data = {"name": "TestDummy", "speed": 100}

	EventBus.emit_signal("agent_spawned", dummy_agent_body, dummy_init_data)

	assert_signal_emitted(EventBus, "agent_spawned", "agent_spawned emitted.")
	var received_args_raw = listener.get_last_args()
	assert_true(received_args_raw != null, "Listener received signal.")

	if received_args_raw != null:
		# agent_spawned emits 2 args. Our catcher stores [arg1, arg2, null, null, null]
		# We only care about the first 2 elements.
		assert_true(
			received_args_raw.size() >= 2, "Listener should capture at least 2 potential args."
		)
		# Check the actual arguments passed
		assert_eq(received_args_raw[0], dummy_agent_body, "Listener arg 1 check.")
		assert_eq(received_args_raw[1], dummy_init_data, "Listener arg 2 check.")

	prints("Tested EventBus: agent_spawned signal")


func test_camera_set_target_requested_with_null():
	var connect_error = EventBus.connect(
		"camera_set_target_requested", listener, "_on_signal_received"
	)
	assert_eq(connect_error, OK, "Connect camera_set_target_requested.")
	watch_signals(EventBus)

	EventBus.emit_signal("camera_set_target_requested", null)  # Emit ONE argument: null

	assert_signal_emitted(EventBus, "camera_set_target_requested", "Signal should emit.")
	var received_args_raw = listener.get_last_args()
	assert_true(received_args_raw != null, "Listener received signal (null target).")

	if received_args_raw != null:
		# camera_set_target_requested emits 1 arg. Catcher stores [null, null, null, null, null]
		assert_true(
			received_args_raw.size() >= 1, "Listener should capture at least 1 potential arg."
		)
		# Check the actual first argument passed
		assert_eq(received_args_raw[0], null, "Listener arg 1 should be null.")

	prints("Tested EventBus: camera_set_target_requested (null)")


# ... (test_signal_not_emitted and test_signal_emit_count remain the same) ...


func test_signal_not_emitted_when_not_called():
	watch_signals(EventBus)
	assert_signal_not_emitted(
		EventBus, "zone_loaded", "zone_loaded should not have been emitted yet."
	)
	var received_args = listener.get_last_args()
	assert_true(received_args == null, "Listener should NOT have received signal data.")
	prints("Tested EventBus: assert_signal_not_emitted")


func test_signal_emit_count():
	var connect_error = EventBus.connect(
		"agent_reached_destination", listener, "_on_signal_received"
	)
	assert_eq(connect_error, OK, "Connect agent_reached_destination.")
	watch_signals(EventBus)
	var dummy_agent = Node.new()
	add_child_autofree(dummy_agent)
	var dummy_agent2 = Node.new()
	add_child_autofree(dummy_agent2)

	EventBus.emit_signal("agent_reached_destination", dummy_agent)
	EventBus.emit_signal("agent_reached_destination", dummy_agent2)
	EventBus.emit_signal("agent_reached_destination", dummy_agent)

	assert_signal_emit_count(
		EventBus, "agent_reached_destination", 3, "Signal should have emitted 3 times total."
	)
	prints("Tested EventBus: assert_signal_emit_count")

--- Start of ./src/tests/autoload/test_game_state_manager.gd ---

# File: tests/autoload/test_game_state_manager.gd
# GUT Test for the streamlined GameStateManager.
# Version: 2.1 - Corrected for private serialization methods.

extends GutTest

# --- Component Preloads ---
const TemplateIndexer = preload("res://src/scenes/game_world/world_manager/template_indexer.gd")
const WorldGenerator = preload("res://src/scenes/game_world/world_manager/world_generator.gd")
const InventorySystem = preload("res://src/core/systems/inventory_system.gd")

# --- Test State ---
const TEST_SLOT = 999
var _initial_game_state_copy = {}


func before_all():
	# Index templates once for all tests in this file.
	var indexer = TemplateIndexer.new()
	add_child_autofree(indexer)
	indexer.index_all_templates()

func before_each():
	# Set up a complete, known game state before each test.
	_clear_game_state()
	
	# The generator needs an inventory system to exist in GlobalRefs.
	var inv_sys = InventorySystem.new()
	add_child_autofree(inv_sys)
	GlobalRefs.inventory_system = inv_sys
	
	var generator = WorldGenerator.new()
	add_child_autofree(generator)
	generator.generate_new_world()
	
	# Take a deep copy of the freshly generated state for comparison later.
	_initial_game_state_copy = _deep_copy_game_state()

func after_each():
	_clear_game_state()
	GlobalRefs.inventory_system = null # Clean up the global ref
	var save_path = GameStateManager.SAVE_DIR + GameStateManager.SAVE_FILE_PREFIX + str(TEST_SLOT) + ".sav"
	var dir = Directory.new()
	if dir.file_exists(save_path):
		dir.remove(save_path)

# --- Test Cases ---

func test_save_and_load_restores_identical_state():
	# 1. Save the game
	var save_success = GameStateManager.save_game(TEST_SLOT)
	assert_true(save_success, "Game should save successfully.")

	# 2. Clear the live GameState to simulate a restart
	_clear_game_state()
	assert_eq(GameState.characters.size(), 0, "Pre-load check: GameState should be empty.")

	# 3. Load the game
	var load_success = GameStateManager.load_game(TEST_SLOT)
	assert_true(load_success, "Game should load successfully.")
	
	# 4. Compare the loaded state to the original state
	var loaded_state_copy = _deep_copy_game_state()

	# Use GUT's deep compare for detailed comparison
	var result = compare_deep(_initial_game_state_copy, loaded_state_copy)
	assert_true(result.are_equal(), "Loaded GameState should be identical to the pre-save state.\n" + result.summary)


func test_save_and_load_preserves_mutated_phase1_fields():
	# Mutate Phase 1 fields that change during gameplay and must persist.
	GameState.current_tu = 42
	GameState.player_docked_at = "station_beta"
	GameState.narrative_state["reputation"] = 7
	GameState.session_stats["contracts_completed"] = 2

	# Market inventory quantity mutation
	var station_alpha = GameState.locations.get("station_alpha", null)
	assert_not_null(station_alpha, "Precondition: station_alpha location should exist.")
	if station_alpha:
		assert_true(station_alpha.market_inventory.has("commodity_ore"), "Precondition: station_alpha should sell commodity_ore.")
		if station_alpha.market_inventory.has("commodity_ore"):
			station_alpha.market_inventory["commodity_ore"]["quantity"] = 123

	# Ship quirks mutation (grab player's first ship)
	var player_uid = GameState.player_character_uid
	assert_true(GameState.inventories.has(player_uid), "Precondition: player inventory should exist.")
	var ship_uid := -1
	if GameState.inventories.has(player_uid):
		var ship_inv = GameState.inventories[player_uid][InventorySystem.InventoryType.SHIP]
		assert_true(ship_inv.size() > 0, "Precondition: player should have at least one ship asset.")
		if ship_inv.size() > 0:
			ship_uid = ship_inv.keys()[0]
			ship_inv[ship_uid].ship_quirks = ["scratched_hull"]

	# Active contract mutation (simulate accepted contract with progress)
	var contract_ids = GameState.contracts.keys()
	assert_true(contract_ids.size() > 0, "Precondition: at least one contract template should exist.")
	if contract_ids.size() > 0:
		var contract_id: String = contract_ids[0]
		var active_contract = GameState.contracts[contract_id].duplicate(true)
		active_contract.accepted_at_tu = GameState.current_tu
		active_contract.progress = {"character_uid": player_uid, "test_flag": true}
		GameState.active_contracts[contract_id] = active_contract

	# Save -> clear -> load
	var save_success = GameStateManager.save_game(TEST_SLOT)
	assert_true(save_success, "Game should save successfully.")
	_clear_game_state()
	var load_success = GameStateManager.load_game(TEST_SLOT)
	assert_true(load_success, "Game should load successfully.")

	# Assertions
	assert_eq(GameState.current_tu, 42, "current_tu should persist.")
	assert_eq(GameState.player_docked_at, "station_beta", "player_docked_at should persist.")
	assert_eq(GameState.narrative_state.get("reputation", null), 7, "narrative_state.reputation should persist.")
	assert_eq(GameState.session_stats.get("contracts_completed", null), 2, "session_stats.contracts_completed should persist.")

	assert_eq(GameState.locations["station_alpha"].market_inventory["commodity_ore"]["quantity"], 123, "Market inventory quantity should persist.")
	if ship_uid != -1:
		var loaded_ship_inv = GameState.inventories[player_uid][InventorySystem.InventoryType.SHIP]
		assert_true(loaded_ship_inv.has(ship_uid), "Loaded player ship inventory should contain the mutated ship.")
		assert_eq(loaded_ship_inv[ship_uid].ship_quirks, ["scratched_hull"], "Ship quirks should persist.")

	if contract_ids.size() > 0:
		var contract_id_loaded: String = contract_ids[0]
		assert_true(GameState.active_contracts.has(contract_id_loaded), "Active contract should persist.")
		assert_eq(GameState.active_contracts[contract_id_loaded].progress.get("character_uid", -1), player_uid, "Active contract progress should persist.")
		assert_true(GameState.active_contracts[contract_id_loaded].progress.get("test_flag", false), "Active contract custom progress data should persist.")

# --- Helper Functions ---

func _clear_game_state():
	GameState.characters.clear()
	GameState.assets_ships.clear()
	GameState.assets_modules.clear()
	GameState.inventories.clear()
	GameState.locations.clear()
	GameState.contracts.clear()
	GameState.active_contracts.clear()
	# Reinitialize with defaults instead of just clearing
	GameState.narrative_state = {
		"reputation": 0,
		"faction_standings": {},
		"known_contacts": [],
		"chronicle_entries": []
	}
	GameState.session_stats = {
		"contracts_completed": 0,
		"total_wp_earned": 0,
		"total_wp_spent": 0,
		"enemies_disabled": 0,
		"time_played_tu": 0
	}
	GameState.player_character_uid = -1
	GameState.player_docked_at = ""
	GameState.current_tu = 0

# Creates a serializable copy of the GameState for comparison.
func _deep_copy_game_state() -> Dictionary:
	# We now call the private methods on the GameStateManager itself to get the
	# serialized copy, since it's the authority on serialization.
	return GameStateManager._serialize_game_state()

--- Start of ./src/tests/autoload/test_global_refs.gd ---

# File: tests/autoload/test_global_refs.gd
# GUT Test Script for GlobalRefs.gd Autoload
# Version: 1.2

extends GutTest

# Dummy nodes used for testing references
var test_node_player = null
var test_node_camera = null
var test_node_other = null
var test_system_node = null


# Setup before each test method
func before_each():
	# Create fresh dummy nodes for isolation
	test_node_player = Node.new()
	test_node_player.name = "DummyPlayer"
	test_node_camera = Camera.new()
	test_node_camera.name = "DummyCamera"
	test_node_other = Node.new()
	test_node_other.name = "DummyOther"
	test_system_node = Node.new()
	test_system_node.name = "DummySystem"

	# GUT's autofree will handle removal and freeing
	add_child_autofree(test_node_player)
	add_child_autofree(test_node_camera)
	add_child_autofree(test_node_other)
	add_child_autofree(test_system_node)

	# Reset all global refs to a known null state before each test
	reset_all_global_refs()


func after_each():
	# Reset global refs after test completion to avoid interfering with other tests
	reset_all_global_refs()
	# Dummy nodes are freed by autofree


# Helper function to reset all references
func reset_all_global_refs():
	GlobalRefs.player_agent_body = null
	GlobalRefs.main_camera = null
	GlobalRefs.world_manager = null
	GlobalRefs.main_hud = null
	GlobalRefs.current_zone = null
	GlobalRefs.agent_container = null
	GlobalRefs.game_state_manager = null
	GlobalRefs.action_system = null
	GlobalRefs.agent_spawner = null
	GlobalRefs.asset_system = null
	GlobalRefs.character_system = null
	GlobalRefs.chronicle_system = null
	GlobalRefs.goal_system = null
	GlobalRefs.inventory_system = null
	GlobalRefs.progression_system = null
	GlobalRefs.time_system = null
	GlobalRefs.traffic_system = null
	GlobalRefs.world_map_system = null


# --- Test Methods ---


func test_initial_references_are_null():
	assert_null(GlobalRefs.player_agent_body, "Player ref should start null.")
	assert_null(GlobalRefs.main_camera, "Camera ref should start null.")
	assert_null(GlobalRefs.world_manager, "World Manager ref should start null.")
	assert_null(GlobalRefs.action_system, "Action System ref should start null.")
	assert_null(GlobalRefs.time_system, "Time System ref should start null.")
	assert_null(GlobalRefs.character_system, "Character System ref should start null.")
	prints("Tested GlobalRefs: Initial Null State")


func test_can_set_and_get_valid_reference():
	assert_null(GlobalRefs.player_agent_body, "Pre-check: Player ref is null.")
	# Assign using the variable, which triggers the setter via setget
	GlobalRefs.player_agent_body = test_node_player
	assert_true(
		is_instance_valid(GlobalRefs.player_agent_body), "Player ref should be a valid instance."
	)
	assert_eq(
		GlobalRefs.player_agent_body,
		test_node_player,
		"Player ref should hold the assigned valid node."
	)
	prints("Tested GlobalRefs: Set/Get Valid Reference")


func test_can_set_and_get_system_references():
	assert_null(GlobalRefs.time_system, "Pre-check: TimeSystem ref is null.")
	GlobalRefs.time_system = test_system_node
	assert_true(is_instance_valid(GlobalRefs.time_system), "TimeSystem ref should be valid.")
	assert_eq(GlobalRefs.time_system, test_system_node, "TimeSystem ref holds the correct node.")
	prints("Tested GlobalRefs: Set/Get System References")


func test_setting_null_clears_reference():
	# Set a valid reference first
	GlobalRefs.main_camera = test_node_camera
	assert_true(is_instance_valid(GlobalRefs.main_camera), "Pre-check: Camera ref is set.")
	# Set back to null
	GlobalRefs.main_camera = null
	assert_null(GlobalRefs.main_camera, "Camera ref should be null after setting null.")
	prints("Tested GlobalRefs: Set Null Clears Reference")


func test_overwriting_reference_with_valid_node():
	GlobalRefs.world_manager = test_node_player # Assign Node type to Node var
	assert_eq(GlobalRefs.world_manager, test_node_player, "Check initial assignment.")
	# Assign a different valid node
	GlobalRefs.world_manager = test_node_other
	assert_true(is_instance_valid(GlobalRefs.world_manager), "New WM ref should be valid.")
	assert_eq(
		GlobalRefs.world_manager, test_node_other, "World Manager ref should hold the new node."
	)
	assert_ne(
		GlobalRefs.world_manager,
		test_node_player,
		"World Manager ref should no longer hold the old node."
	)
	prints("Tested GlobalRefs: Overwriting Reference")


func test_setting_invalid_freed_reference_is_handled():
	# Set a valid reference first
	GlobalRefs.player_agent_body = test_node_player
	assert_true(is_instance_valid(GlobalRefs.player_agent_body), "Pre-check: Player ref is valid.")

	# Create and free a temporary node *before* assigning it
	var freed_node = Node.new()
	freed_node.free() # Free it immediately

	# Attempt to assign the freed node via the setter (setget triggers this)
	GlobalRefs.player_agent_body = freed_node

	# Assert that the reference DID NOT change to the invalid node
	# It should have remained the previously valid node because the setter rejected the freed one.
	assert_true(
		is_instance_valid(GlobalRefs.player_agent_body), "Player ref should still be valid."
	)
	assert_eq(
		GlobalRefs.player_agent_body,
		test_node_player,
		"Player ref should remain the original valid node."
	)
	assert_ne(
		GlobalRefs.player_agent_body,
		freed_node,
		"Player ref should not be the freed node instance."
	)
	prints("Tested GlobalRefs: Ignore Setting Freed Reference")

--- Start of ./src/tests/core/agents/components/test_movement_system.gd ---

# tests/core/agents/components/test_movement_system.gd
extends GutTest

var MovementSystem = load("res://src/core/agents/components/movement_system.gd")
var agent_body
var movement_system


# Use a test-specific KinematicBody to add the `current_velocity` var
class TestAgentBody:
	extends KinematicBody
	var current_velocity = Vector3.ZERO


func before_each():
	# Create a mock agent body scene for the test
	agent_body = TestAgentBody.new()
	agent_body.name = "TestAgentBody"

	# The movement system must be a child of the body to work
	movement_system = MovementSystem.new()
	movement_system.name = "MovementSystem"
	agent_body.add_child(movement_system)

	# Add to tree so get_parent() works
	get_tree().get_root().add_child(agent_body)

	# Manually call ready to ensure parent references are set
	movement_system._ready()

	# Initialize with known test parameters
	var move_params = {
		"max_move_speed": 100.0,
		"acceleration": 0.5,
		"deceleration": 0.5,
		"max_turn_speed": 1.0,  # rad/s
		"brake_strength": 1.0,
		"alignment_threshold_angle_deg": 30.0
	}
	movement_system.initialize_movement_params(move_params)


func after_each():
	if is_instance_valid(agent_body):
		agent_body.queue_free()


func test_initialization():
	assert_eq(movement_system.max_move_speed, 100.0)
	assert_eq(movement_system.acceleration, 0.5)
	assert_almost_eq(movement_system._alignment_threshold_rad, deg2rad(30.0), 0.001)
	assert_true(
		is_instance_valid(movement_system.agent_body),
		"It should have a valid reference to its parent agent body."
	)


func test_accelerates_when_aligned():
	agent_body.current_velocity = Vector3.ZERO
	agent_body.transform = agent_body.transform.looking_at(Vector3.FORWARD, Vector3.UP)

	movement_system.apply_acceleration(Vector3.FORWARD, 0.1)

	assert_true(
		agent_body.current_velocity.length() > 0.0,
		"Velocity should increase when accelerating while aligned."
	)
	assert_true(
		agent_body.current_velocity.z < 0,
		"Velocity should be in the local forward direction (negative Z)."
	)


func test_does_not_accelerate_when_not_aligned():
	agent_body.current_velocity = Vector3.ZERO
	# Agent looks forward, but tries to accelerate to the right (90 deg diff > 30 deg threshold)
	agent_body.transform = agent_body.transform.looking_at(Vector3.FORWARD, Vector3.UP)

	movement_system.apply_acceleration(Vector3.RIGHT, 0.1)

	assert_almost_eq(
		agent_body.current_velocity.length(),
		0.0,
		0.001,
		"Velocity should not increase when not aligned."
	)


func test_deceleration_reduces_speed():
	agent_body.current_velocity = Vector3(0, 0, -100)
	var initial_speed = agent_body.current_velocity.length()

	movement_system.apply_deceleration(0.1)
	var final_speed = agent_body.current_velocity.length()

	assert_true(final_speed < initial_speed, "Deceleration should reduce the agent's speed.")


func test_braking_reduces_speed_faster_than_deceleration():
	agent_body.current_velocity = Vector3(0, 0, -100)
	movement_system.apply_deceleration(0.1)
	var speed_after_decel = agent_body.current_velocity.length()

	agent_body.current_velocity = Vector3(0, 0, -100)
	movement_system.apply_braking(0.1)
	var speed_after_brake = agent_body.current_velocity.length()

	assert_true(
		speed_after_brake < speed_after_decel,
		"Braking should be stronger than natural deceleration."
	)


func test_braking_reports_stopped():
	agent_body.current_velocity = Vector3(0, 0, -0.1)
	var stopped = movement_system.apply_braking(1.0)
	assert_true(stopped, "Braking should return true when velocity is near zero.")

	agent_body.current_velocity = Vector3(0, 0, -50)
	stopped = movement_system.apply_braking(0.01)
	assert_false(stopped, "Braking should return false when velocity is still high.")


func test_rotation_turns_towards_target():
	var target_dir = Vector3.RIGHT
	agent_body.transform = Transform().looking_at(Vector3.FORWARD, Vector3.UP)

	var initial_forward_vec = -agent_body.global_transform.basis.z
	var initial_dot = initial_forward_vec.dot(target_dir)

	movement_system.apply_rotation(target_dir, 0.1)

	var final_forward_vec = -agent_body.global_transform.basis.z
	var final_dot = final_forward_vec.dot(target_dir)

	assert_true(
		final_dot > initial_dot, "Agent should turn to be more aligned with the target direction."
	)

--- Start of ./src/tests/core/agents/components/test_navigation_system.gd ---

extends GutTest

var NavigationSystem = load("res://src/core/agents/components/navigation_system.gd")
var MovementSystem = load("res://src/core/agents/components/movement_system.gd")
const SignalCatcher = preload("res://src/tests/helpers/signal_catcher.gd")
const TestAgentBodyScript = preload("res://src/tests/helpers/test_agent_body.gd")

var agent_body
var nav_system
var mock_movement_system
var signal_catcher


func before_each():
	signal_catcher = SignalCatcher.new()
	EventBus.connect("agent_reached_destination", signal_catcher, "_on_signal_received")

	agent_body = partial_double(TestAgentBodyScript).new()
	agent_body.name = "TestAgent"

	mock_movement_system = double(MovementSystem).new()
	# CORRECTED: Stub methods to silence GUT warnings and provide default return values.
	stub(mock_movement_system, "_ready").to_return(null)
	stub(mock_movement_system, "apply_deceleration").to_return(null)
	stub(mock_movement_system, "apply_braking").to_return(false)
	stub(mock_movement_system, "apply_rotation").to_return(null)
	stub(mock_movement_system, "apply_acceleration").to_return(null)
	stub(mock_movement_system, "max_move_speed").to_return(100.0)

	nav_system = NavigationSystem.new()
	nav_system.name = "NavigationSystem"

	agent_body.add_child(mock_movement_system)
	agent_body.add_child(nav_system)

	get_tree().get_root().add_child(agent_body)

	nav_system._ready()
	nav_system.initialize_navigation({}, mock_movement_system)


func after_each():
	if EventBus.is_connected("agent_reached_destination", signal_catcher, "_on_signal_received"):
		EventBus.disconnect("agent_reached_destination", signal_catcher, "_on_signal_received")

	if is_instance_valid(agent_body):
		agent_body.queue_free()
	if is_instance_valid(signal_catcher):
		signal_catcher.free()


func test_initial_state_is_idle():
	signal_catcher.reset()
	assert_eq(
		nav_system._current_command.type,
		nav_system.CommandType.IDLE,
		"Default command should be IDLE."
	)
	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "apply_deceleration", [0.1])


func test_set_command_stopping():
	signal_catcher.reset()
	nav_system.set_command_stopping()
	assert_eq(nav_system._current_command.type, nav_system.CommandType.STOPPING)
	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "apply_braking", [0.1])


func test_stop_command_emits_reached_destination_signal():
	signal_catcher.reset()
	# This time we need apply_braking to return true to trigger the signal
	stub(mock_movement_system, "apply_braking").to_return(true)

	nav_system.set_command_stopping()
	nav_system.update_navigation(0.1)

	var captured_args = signal_catcher.get_last_args()
	assert_not_null(captured_args, "A signal should have been captured.")
	assert_eq(
		captured_args[0], agent_body, "The first argument of the signal should be the agent_body."
	)


func test_set_command_move_to():
	signal_catcher.reset()
	var target_pos = Vector3(100, 200, 300)
	nav_system.set_command_move_to(target_pos)

	assert_eq(nav_system._current_command.type, nav_system.CommandType.MOVE_TO)
	assert_eq(nav_system._current_command.target_pos, target_pos)

	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "apply_rotation")


func test_set_command_approach():
	signal_catcher.reset()
	var target_node = TestAgentBodyScript.new()
	agent_body.add_child(target_node)
	# CORRECTED: Move the target so the distance isn't zero.
	target_node.global_transform.origin = Vector3(0, 0, -1000)

	nav_system.set_command_approach(target_node)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.APPROACH)
	assert_eq(nav_system._current_command.target_node, target_node)

	nav_system.update_navigation(0.1)
	# This assertion will now pass because the distance is > arrival threshold.
	assert_called(mock_movement_system, "apply_rotation")


func test_set_command_orbit():
	signal_catcher.reset()
	var target_node = TestAgentBodyScript.new()
	agent_body.add_child(target_node)
	# Move the target so the distance isn't zero.
	target_node.global_transform.origin = Vector3(0, 0, -1000)

	nav_system.set_command_orbit(target_node, 500.0, true)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.ORBIT)

	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "apply_rotation")


func test_set_command_flee():
	signal_catcher.reset()
	var target_node = TestAgentBodyScript.new()
	agent_body.add_child(target_node)
	# Move the target so there is a direction to flee from.
	target_node.global_transform.origin = Vector3(0, 0, -1000)

	nav_system.set_command_flee(target_node)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.FLEE)

	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "apply_rotation")
	assert_called(mock_movement_system, "apply_acceleration")


func test_set_command_align_to():
	signal_catcher.reset()
	var direction = Vector3.BACK.normalized()
	nav_system.set_command_align_to(direction)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.ALIGN_TO)

	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "apply_rotation")
	assert_called(mock_movement_system, "apply_deceleration")


func test_invalid_target_in_update_switches_to_stopping():
	signal_catcher.reset()
	var target_node = TestAgentBodyScript.new()

	nav_system.set_command_approach(target_node)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.APPROACH)

	target_node.free()
	yield(get_tree(), "idle_frame")

	nav_system.update_navigation(0.1)

	assert_eq(nav_system._current_command.type, nav_system.CommandType.STOPPING)
	assert_called(mock_movement_system, "apply_braking")

--- Start of ./src/tests/core/agents/components/test_weapon_controller.gd ---

# test_weapon_controller.gd
# Unit tests for WeaponController - weapon firing, cooldowns, signal emissions
extends "res://addons/gut/test.gd"

const WeaponController = preload("res://src/core/agents/components/weapon_controller.gd")
const CombatSystem = preload("res://src/core/systems/combat_system.gd")
const UtilityToolTemplate = preload("res://database/definitions/utility_tool_template.gd")

var _weapon_controller: Node
var _mock_agent_body: KinematicBody
var _mock_combat_system: Node
var _test_weapon: UtilityToolTemplate

const SHOOTER_UID: int = 100
const TARGET_UID: int = 200


# --- Test Agent Body with required properties ---
class TestAgentBody:
	extends KinematicBody
	var agent_uid: int = 100
	var character_uid: int = 1


func before_each():
	# Create mock agent body
	_mock_agent_body = TestAgentBody.new()
	_mock_agent_body.name = "TestAgentBody"
	_mock_agent_body.agent_uid = SHOOTER_UID
	_mock_agent_body.character_uid = 1
	add_child(_mock_agent_body)
	
	# Create and register mock combat system
	_mock_combat_system = CombatSystem.new()
	add_child(_mock_combat_system)
	GlobalRefs.combat_system = _mock_combat_system
	
	# Create test weapon
	_test_weapon = UtilityToolTemplate.new()
	_test_weapon.template_id = "test_laser"
	_test_weapon.tool_name = "Test Laser"
	_test_weapon.tool_type = "weapon"
	_test_weapon.damage = 10.0
	_test_weapon.range_effective = 50.0
	_test_weapon.range_max = 100.0
	_test_weapon.fire_rate = 2.0  # 2 shots per second = 0.5s base cooldown
	_test_weapon.accuracy = 1.0
	_test_weapon.hull_damage_multiplier = 1.0
	_test_weapon.armor_damage_multiplier = 1.0
	_test_weapon.cooldown_time = 0.5  # Additional cooldown
	
	# Create weapon controller and add as child of agent body
	_weapon_controller = WeaponController.new()
	_weapon_controller.name = "WeaponController"
	_mock_agent_body.add_child(_weapon_controller)
	
	# Manually inject a weapon (bypassing asset system loading)
	_weapon_controller._weapons = [_test_weapon]
	_weapon_controller._cooldowns = {0: 0.0}
	
	# Register combatants for fire tests
	var shooter_ship = _create_mock_ship(100, 50)
	var target_ship = _create_mock_ship(100, 50)
	_mock_combat_system.register_combatant(SHOOTER_UID, shooter_ship)
	_mock_combat_system.register_combatant(TARGET_UID, target_ship)


func after_each():
	GlobalRefs.combat_system = null
	if is_instance_valid(_mock_agent_body):
		_mock_agent_body.queue_free()
	if is_instance_valid(_mock_combat_system):
		_mock_combat_system.queue_free()


func _create_mock_ship(hull: int, armor: int) -> Resource:
	var ship = Resource.new()
	ship.set_script(load("res://src/tests/helpers/mock_ship_template.gd"))
	ship.hull_integrity = hull
	ship.armor_integrity = armor
	return ship


# --- Weapon Loading Tests ---

func test_get_weapon_count():
	assert_eq(_weapon_controller.get_weapon_count(), 1, "Should have 1 weapon loaded")


func test_get_weapon_valid_index():
	var weapon = _weapon_controller.get_weapon(0)
	assert_not_null(weapon, "Weapon at index 0 should exist")
	assert_eq(weapon.template_id, "test_laser", "Should return correct weapon")


func test_get_weapon_invalid_index():
	var weapon = _weapon_controller.get_weapon(99)
	assert_null(weapon, "Invalid index should return null")
	
	weapon = _weapon_controller.get_weapon(-1)
	assert_null(weapon, "Negative index should return null")


# --- Weapon Ready State Tests ---

func test_is_weapon_ready_initially():
	assert_true(_weapon_controller.is_weapon_ready(0), "Weapon should be ready initially")


func test_is_weapon_ready_after_fire():
	var target_pos = Vector3(10, 0, 0)
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	assert_false(_weapon_controller.is_weapon_ready(0), "Weapon should not be ready after firing")


func test_get_cooldown_remaining_initially():
	var cooldown = _weapon_controller.get_cooldown_remaining(0)
	assert_eq(cooldown, 0.0, "Initial cooldown should be 0")


# --- Fire Weapon Tests ---

func test_fire_weapon_success():
	var target_pos = Vector3(10, 0, 0)  # Within range
	
	var result = _weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	assert_true(result.get("success", false), "Fire should succeed")


func test_fire_weapon_emits_weapon_fired_signal():
	watch_signals(_weapon_controller)
	var target_pos = Vector3(10, 0, 0)
	
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	assert_signal_emitted(_weapon_controller, "weapon_fired", "weapon_fired signal should emit")


func test_fire_weapon_emits_cooldown_started_signal():
	watch_signals(_weapon_controller)
	var target_pos = Vector3(10, 0, 0)
	
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	assert_signal_emitted(_weapon_controller, "weapon_cooldown_started", 
		"weapon_cooldown_started signal should emit")


func test_fire_weapon_starts_cooldown():
	var target_pos = Vector3(10, 0, 0)
	
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	var cooldown = _weapon_controller.get_cooldown_remaining(0)
	assert_gt(cooldown, 0.0, "Cooldown should be > 0 after firing")


func test_fire_weapon_invalid_index():
	var target_pos = Vector3(10, 0, 0)
	
	var result = _weapon_controller.fire_at_target(99, TARGET_UID, target_pos)
	
	assert_false(result.get("success", true), "Fire with invalid index should fail")
	assert_eq(result.get("reason"), "Invalid weapon index", "Should return correct error reason")


func test_fire_weapon_during_cooldown_fails():
	var target_pos = Vector3(10, 0, 0)
	
	# First fire should succeed
	var result1 = _weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	assert_true(result1.get("success", false), "First fire should succeed")
	
	# Second immediate fire should fail
	var result2 = _weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	assert_false(result2.get("success", true), "Second fire should fail due to cooldown")
	assert_eq(result2.get("reason"), "Weapon on cooldown", "Should report cooldown as reason")


# --- Cooldown Timer Tests ---

func test_cooldown_decrements_over_time():
	var target_pos = Vector3(10, 0, 0)
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	var initial_cooldown = _weapon_controller.get_cooldown_remaining(0)
	
	# Simulate physics frame
	_weapon_controller._physics_process(0.25)
	
	var new_cooldown = _weapon_controller.get_cooldown_remaining(0)
	assert_lt(new_cooldown, initial_cooldown, "Cooldown should decrease after physics process")


func test_cooldown_reaches_zero():
	var target_pos = Vector3(10, 0, 0)
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	# Simulate enough time to complete cooldown (fire_rate=2 -> 0.5s + cooldown_time=0.5s = 1.0s)
	_weapon_controller._physics_process(2.0)
	
	var final_cooldown = _weapon_controller.get_cooldown_remaining(0)
	assert_eq(final_cooldown, 0.0, "Cooldown should reach 0")
	assert_true(_weapon_controller.is_weapon_ready(0), "Weapon should be ready after cooldown")


func test_weapon_ready_signal_emitted_after_cooldown():
	watch_signals(_weapon_controller)
	var target_pos = Vector3(10, 0, 0)
	
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	# Simulate time to complete cooldown
	_weapon_controller._physics_process(2.0)
	
	assert_signal_emitted(_weapon_controller, "weapon_ready", 
		"weapon_ready signal should emit when cooldown ends")


# --- Edge Case Tests ---

func test_fire_without_combat_system():
	GlobalRefs.combat_system = null
	var target_pos = Vector3(10, 0, 0)
	
	var result = _weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	assert_false(result.get("success", true), "Fire should fail without combat system")
	assert_eq(result.get("reason"), "CombatSystem unavailable", "Should report system unavailable")


func test_multiple_physics_frames_decrement_cooldown():
	var target_pos = Vector3(10, 0, 0)
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	var cooldowns = []
	cooldowns.append(_weapon_controller.get_cooldown_remaining(0))
	
	for _i in range(4):
		_weapon_controller._physics_process(0.1)
		cooldowns.append(_weapon_controller.get_cooldown_remaining(0))
	
	# Verify strictly decreasing
	for i in range(1, cooldowns.size()):
		assert_lt(cooldowns[i], cooldowns[i-1], 
			"Cooldown should decrease each frame (frame %d)" % i)


func test_can_fire_again_after_cooldown_complete():
	var target_pos = Vector3(10, 0, 0)
	
	# First fire
	var result1 = _weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	assert_true(result1.get("success", false), "First fire should succeed")
	
	# Wait for cooldown
	_weapon_controller._physics_process(2.0)
	
	# Second fire after cooldown
	var result2 = _weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	assert_true(result2.get("success", false), "Fire after cooldown should succeed")

--- Start of ./src/tests/core/systems/test_action_system.gd ---

# File: tests/core/systems/test_action_system.gd
# GUT Test for the stateless ActionSystem.
# Version: 3.0 - Rewritten for GameState architecture.

extends GutTest

# --- Test Subjects ---
const ActionSystem = preload("res://src/core/systems/action_system.gd")
const CharacterTemplate = preload("res://database/definitions/character_template.gd")
const ActionTemplate = preload("res://database/definitions/action_template.gd")

# --- Test State ---
var action_system_instance = null
var mock_character: CharacterTemplate = null
var mock_action: ActionTemplate = null
const PLAYER_UID = 0


func before_each():
	# 1. Clean the global state
	GameState.characters.clear()
	GameState.active_actions.clear()
	GameState.player_character_uid = -1

	# 2. Create mock character and action data
	mock_character = CharacterTemplate.new()
	mock_character.character_name = "Test Character"
	GameState.characters[PLAYER_UID] = mock_character
	GameState.player_character_uid = PLAYER_UID

	mock_action = ActionTemplate.new()
	mock_action.action_name = "Test Action"
	mock_action.tu_cost = 5

	# 3. Instantiate the system we are testing
	action_system_instance = ActionSystem.new()
	add_child_autofree(action_system_instance)
	# Manually call _ready to connect signals for the test
	action_system_instance._ready()


func after_each():
	GameState.characters.clear()
	GameState.active_actions.clear()
	GameState.player_character_uid = -1
	action_system_instance = null


# --- Test Cases ---

func test_request_action_populates_game_state():
	assert_eq(GameState.active_actions.size(), 0, "Active actions should be empty initially.")

	var result = action_system_instance.request_action(
		mock_character, mock_action, Constants.ActionApproach.CAUTIOUS
	)

	assert_true(result, "request_action should return true on success.")
	assert_eq(GameState.active_actions.size(), 1, "There should be one active action in GameState.")

	var action_data = GameState.active_actions.values()[0]
	assert_eq(action_data.character_instance, mock_character, "Action data should store the correct character.")
	assert_eq(action_data.action_template, mock_action, "Action data should store the correct action template.")


func test_action_progresses_on_world_tick():
	action_system_instance.request_action(
		mock_character, mock_action, Constants.ActionApproach.CAUTIOUS
	)
	var action_id = GameState.active_actions.keys()[0]

	# Simulate a world tick that does NOT complete the action
	EventBus.emit_signal("world_event_tick_triggered", 2) # 2 TU passed

	assert_eq(GameState.active_actions[action_id].tu_progress, 2, "Action progress should be 2 TU.")


func test_action_completes_and_emits_signal():
	watch_signals(action_system_instance)
	action_system_instance.request_action(
		mock_character, mock_action, Constants.ActionApproach.RISKY
	)
	assert_eq(GameState.active_actions.size(), 1, "Pre-check: Action should be queued.")

	# Simulate a world tick that completes the action (action costs 5 TU)
	EventBus.emit_signal("world_event_tick_triggered", 10)

	assert_signal_emitted(action_system_instance, "action_completed", "action_completed signal should be emitted.")
	assert_eq(GameState.active_actions.size(), 0, "Action should be removed from GameState after completion.")

	# Verify the signal payload
	var params = get_signal_parameters(action_system_instance, "action_completed")
	assert_eq(params[0], mock_character, "Payload should contain the correct character.")
	assert_eq(params[1], mock_action, "Payload should contain the correct action template.")
	assert_has(params[2], "result_tier", "Payload should contain the result dictionary.")

--- Start of ./src/tests/core/systems/test_agent_spawner.gd ---

# File: tests/core/systems/test_agent_spawner.gd
# GUT Test for the AgentSystem (formerly AgentSpawner).
# Version: 2.1 - Corrected signal payload inspection.

extends GutTest

# --- Test Subjects ---
const AgentSystem = preload("res://src/core/systems/agent_system.gd")
const CharacterTemplate = preload("res://database/definitions/character_template.gd")
const AgentTemplate = preload("res://database/definitions/agent_template.gd")

# --- Helpers ---
const MOCK_AGENT_SCENE = "res://src/tests/helpers/mock_agent.tscn"
const SignalCatcher = preload("res://src/tests/helpers/signal_catcher.gd")

# --- Test State ---
var agent_system_instance = null
var mock_agent_container = null
var signal_catcher = null
const PLAYER_UID = 0


func before_each():
	# 1. Clean and set up the global state
	GameState.characters.clear()
	GameState.player_character_uid = -1

	# 2. Create mock scene nodes required by the AgentSystem
	mock_agent_container = Node.new()
	mock_agent_container.name = "MockAgentContainer"
	add_child_autofree(mock_agent_container)
	GlobalRefs.agent_container = mock_agent_container

	# 3. Create a mock player character in the GameState
	var player_char = CharacterTemplate.new()
	GameState.characters[PLAYER_UID] = player_char
	GameState.player_character_uid = PLAYER_UID

	# 4. Instantiate the system we are testing
	agent_system_instance = AgentSystem.new()
	add_child_autofree(agent_system_instance)

	# 5. Setup signal catcher
	signal_catcher = SignalCatcher.new()
	add_child_autofree(signal_catcher)
	EventBus.connect("agent_spawned", signal_catcher, "_on_signal_received")
	EventBus.connect("player_spawned", signal_catcher, "_on_signal_received")


func after_each():
	# Clean up global state and references
	GameState.characters.clear()
	GameState.player_character_uid = -1
	GlobalRefs.agent_container = null
	
	if EventBus.is_connected("agent_spawned", signal_catcher, "_on_signal_received"):
		EventBus.disconnect("agent_spawned", signal_catcher, "_on_signal_received")
	if EventBus.is_connected("player_spawned", signal_catcher, "_on_signal_received"):
		EventBus.disconnect("player_spawned", signal_catcher, "_on_signal_received")

	agent_system_instance = null


# --- Test Cases ---

func test_spawn_player_on_zone_loaded():
	watch_signals(EventBus) # Watch EventBus to inspect signal history
	
	# Simulate the zone_loaded signal being emitted
	agent_system_instance._on_Zone_Loaded(null, null, mock_agent_container)
	
	# Assert that a player agent was created in the container
	assert_eq(mock_agent_container.get_child_count(), 1, "AgentContainer should have one child after player spawn.")
	
	# Assert that the correct signals were fired
	assert_signal_emitted(EventBus, "agent_spawned")
	assert_signal_emitted(EventBus, "player_spawned")

	# --- FIX: Specifically get the parameters for the agent_spawned signal ---
	var captured_args = get_signal_parameters(EventBus, "agent_spawned")
	assert_not_null(captured_args, "Should have captured parameters for agent_spawned.")
	
	var spawned_body = captured_args[0]
	var init_data = captured_args[1]
	
	assert_true(is_instance_valid(spawned_body), "Signal should contain a valid agent body.")
	assert_eq(init_data["agent_uid"], PLAYER_UID, "Spawned agent should be linked to the player UID.")


func test_spawn_agent_with_overrides():
	var template = AgentTemplate.new()
	var overrides = {"agent_type": "test_npc", "template_id": "npc_fighter"}
	var npc_uid = 123
	
	var agent_body = agent_system_instance.spawn_agent(MOCK_AGENT_SCENE, Vector3.ZERO, template, overrides, npc_uid)

	assert_not_null(agent_body, "Spawner should return a valid KinematicBody instance.")
	assert_eq(agent_body.agent_type, "test_npc", "Agent type override should be applied.")
	assert_eq(agent_body.template_id, "npc_fighter", "Template ID override should be applied.")
	assert_eq(agent_body.agent_uid, npc_uid, "Agent UID should be set correctly.")

--- Start of ./src/tests/core/systems/test_asset_system.gd ---

# File: tests/core/systems/test_asset_system.gd
# GUT Test for the stateless AssetSystem.
# Version: 2.2 - Added tests for get_ship_for_character().

extends GutTest

# --- Test Subjects ---
const AssetSystem = preload("res://src/core/systems/asset_system.gd")
const CharacterSystem = preload("res://src/core/systems/character_system.gd") # To create a double
const CharacterTemplate = preload("res://database/definitions/character_template.gd")
const ShipTemplate = preload("res://database/definitions/asset_ship_template.gd")

# --- Test State ---
var asset_system_instance = null
var mock_character_system = null
const PLAYER_UID = 0
const NPC_UID = 1
const SHIP_UID = 100
const NPC_SHIP_UID = 101

func before_each():
	# 1. Clean the global state
	GameState.characters.clear()
	GameState.assets_ships.clear()
	GameState.player_character_uid = -1

	# 2. Create a mock CharacterSystem and stub its methods
	mock_character_system = double(CharacterSystem).new()
	add_child_autofree(mock_character_system)

	var player_char = CharacterTemplate.new()
	player_char.active_ship_uid = SHIP_UID # Link character to the ship
	stub(mock_character_system, "get_player_character").to_return(player_char)
	
	# 3. Set the mock system in GlobalRefs so AssetSystem can find it
	GlobalRefs.character_system = mock_character_system

	# 4. Create and register mock ship assets directly in GameState
	var ship_asset = ShipTemplate.new()
	ship_asset.ship_model_name = "Test Vessel"
	GameState.assets_ships[SHIP_UID] = ship_asset
	
	var npc_ship_asset = ShipTemplate.new()
	npc_ship_asset.ship_model_name = "NPC Vessel"
	npc_ship_asset.max_move_speed = 200.0
	GameState.assets_ships[NPC_SHIP_UID] = npc_ship_asset

	# 5. Create characters in GameState for get_ship_for_character tests
	GameState.characters[PLAYER_UID] = player_char
	GameState.player_character_uid = PLAYER_UID
	
	var npc_char = CharacterTemplate.new()
	npc_char.active_ship_uid = NPC_SHIP_UID
	GameState.characters[NPC_UID] = npc_char

	# 6. Instantiate the system we are testing
	asset_system_instance = AssetSystem.new()
	add_child_autofree(asset_system_instance)

func after_each():
	# Clean up global state to ensure test isolation
	GameState.characters.clear()
	GameState.assets_ships.clear()
	GameState.player_character_uid = -1
	GlobalRefs.character_system = null
	asset_system_instance = null

# --- Test Cases ---

func test_get_ship_by_uid():
	var ship = asset_system_instance.get_ship(SHIP_UID)
	assert_not_null(ship, "Should return a valid ship object for a valid UID.")
	assert_eq(ship.ship_model_name, "Test Vessel", "Should return the correct ship instance from GameState.")

	var non_existent_ship = asset_system_instance.get_ship(999)
	assert_null(non_existent_ship, "Should return null for a non-existent UID.")

func test_get_player_ship():
	var player_ship = asset_system_instance.get_player_ship()
	assert_not_null(player_ship, "Should find the player's active ship.")
	assert_eq(player_ship, GameState.assets_ships[SHIP_UID], "Should return the correct ship linked to the player.")

func test_get_player_ship_returns_null_if_no_player():
	stub(mock_character_system, "get_player_character").to_return(null) # Simulate no player
	var player_ship = asset_system_instance.get_player_ship()
	assert_null(player_ship, "Should return null if there is no player character.")

func test_get_player_ship_returns_null_if_no_ship_assigned():
	var player_char_no_ship = CharacterTemplate.new()
	player_char_no_ship.active_ship_uid = -1 # Simulate no assigned ship
	stub(mock_character_system, "get_player_character").to_return(player_char_no_ship)
	var player_ship = asset_system_instance.get_player_ship()
	assert_null(player_ship, "Should return null if the player has no active ship assigned.")


# --- Tests for get_ship_for_character() ---

func test_get_ship_for_character_valid():
	var ship = asset_system_instance.get_ship_for_character(NPC_UID)
	assert_not_null(ship, "Should return a valid ship for a valid character UID.")
	assert_eq(ship.ship_model_name, "NPC Vessel", "Should return the correct ship for the character.")
	assert_eq(ship.max_move_speed, 200.0, "Ship should have the correct stats.")

func test_get_ship_for_character_player():
	var ship = asset_system_instance.get_ship_for_character(PLAYER_UID)
	assert_not_null(ship, "Should return a valid ship for the player character.")
	assert_eq(ship.ship_model_name, "Test Vessel", "Should return the player's ship.")

func test_get_ship_for_character_invalid_uid():
	var ship = asset_system_instance.get_ship_for_character(999)
	assert_null(ship, "Should return null for non-existent character UID.")

func test_get_ship_for_character_no_active_ship():
	var char_no_ship = CharacterTemplate.new()
	char_no_ship.active_ship_uid = -1
	GameState.characters[99] = char_no_ship
	
	var ship = asset_system_instance.get_ship_for_character(99)
	assert_null(ship, "Should return null if character has no active ship.")

--- Start of ./src/tests/core/systems/test_character_system.gd ---

# File: tests/core/systems/test_character_system.gd
# GUT Test Script for the stateless CharacterSystem.
# Version: 2.0 - Rewritten for GameState architecture.

extends GutTest

# --- Test Subjects ---
const CharacterSystem = preload("res://src/core/systems/character_system.gd")
const CharacterTemplate = preload("res://database/definitions/character_template.gd")

# --- Test State ---
var character_system_instance = null
var default_char_template: CharacterTemplate = null
const PLAYER_UID = 0
const NPC_UID = 1


# Runs before each test. Sets up a clean GameState with known characters.
func before_each():
	# 1. Clean the global state
	GameState.characters.clear()
	GameState.player_character_uid = -1

	# 2. Load the base template resource
	default_char_template = load("res://database/registry/characters/character_default.tres")
	assert_true(is_instance_valid(default_char_template), "Pre-check: Default character template must load.")

	# 3. Create and register a player character instance in GameState
	var player_char_instance = default_char_template.duplicate()
	player_char_instance.wealth_points = 100 # Start with some money for tests
	GameState.characters[PLAYER_UID] = player_char_instance
	GameState.player_character_uid = PLAYER_UID

	# 4. Create and register an NPC character instance for multi-character tests
	var npc_char_instance = default_char_template.duplicate()
	npc_char_instance.character_name = "Test NPC"
	GameState.characters[NPC_UID] = npc_char_instance

	# 5. Instantiate the system we are testing
	character_system_instance = CharacterSystem.new()
	add_child_autofree(character_system_instance)


# Runs after each test to ensure a clean environment.
func after_each():
	GameState.characters.clear()
	GameState.player_character_uid = -1
	character_system_instance = null # autofree handles the instance


# --- Test Cases ---

func test_get_player_character():
	var player_char = character_system_instance.get_player_character()
	assert_not_null(player_char, "Should return a valid character object for the player.")
	assert_eq(player_char, GameState.characters[PLAYER_UID], "Should return the correct player character instance from GameState.")


func test_wp_management():
	# Test adding WP
	character_system_instance.add_wp(PLAYER_UID, 50)
	assert_eq(GameState.characters[PLAYER_UID].wealth_points, 150, "WP should be 150 after adding 50.")

	# Test subtracting WP
	character_system_instance.subtract_wp(PLAYER_UID, 25)
	assert_eq(GameState.characters[PLAYER_UID].wealth_points, 125, "WP should be 125 after subtracting 25.")

	# Test getting WP
	assert_eq(character_system_instance.get_wp(PLAYER_UID), 125, "get_wp should return the correct value.")


func test_fp_management():
	# Test adding FP
	character_system_instance.add_fp(PLAYER_UID, 2)
	assert_eq(GameState.characters[PLAYER_UID].focus_points, 2, "FP should be 2 after adding.")

	# Test subtracting FP
	character_system_instance.subtract_fp(PLAYER_UID, 1)
	assert_eq(GameState.characters[PLAYER_UID].focus_points, 1, "FP should be 1 after subtracting.")

	# Test clamping when adding too much
	character_system_instance.add_fp(PLAYER_UID, Constants.FOCUS_MAX_DEFAULT + 5)
	assert_eq(GameState.characters[PLAYER_UID].focus_points, Constants.FOCUS_MAX_DEFAULT, "FP should be clamped to max value.")

	# Test clamping when subtracting too much
	character_system_instance.subtract_fp(PLAYER_UID, Constants.FOCUS_MAX_DEFAULT + 5)
	assert_eq(GameState.characters[PLAYER_UID].focus_points, 0, "FP should be clamped to 0.")


func test_skill_retrieval():
	var piloting_level = character_system_instance.get_skill_level(PLAYER_UID, "piloting")
	assert_eq(piloting_level, 2, "Default piloting skill should be 2 (from character_default.tres).")

	var non_existent_skill = character_system_instance.get_skill_level(PLAYER_UID, "basket_weaving")
	assert_eq(non_existent_skill, 0, "A non-existent skill should return 0.")


func test_apply_upkeep_cost():
	var initial_wp = character_system_instance.get_wp(PLAYER_UID)
	character_system_instance.apply_upkeep_cost(PLAYER_UID, 10)
	var final_wp = character_system_instance.get_wp(PLAYER_UID)
	assert_eq(final_wp, initial_wp - 10, "Upkeep cost should correctly subtract WP.")

--- Start of ./src/tests/core/systems/test_combat_system.gd ---

# test_combat_system.gd
# Unit tests for CombatSystem - targeting, damage, weapon firing
extends "res://addons/gut/test.gd"

const CombatSystem = preload("res://src/core/systems/combat_system.gd")
const UtilityToolTemplate = preload("res://database/definitions/utility_tool_template.gd")
const MockAgentBody = preload("res://src/tests/helpers/mock_agent_body.gd")

var _combat_system: Node
var _test_weapon: UtilityToolTemplate
var _attacker_uid: int = 0
var _defender_uid: int = 1
var _attacker_body: KinematicBody
var _defender_body: KinematicBody


func before_each():
	# Create dummy AgentBody nodes so CombatSystem can resolve uid -> body for EventBus signals.
	_attacker_body = MockAgentBody.new()
	_attacker_body.agent_uid = _attacker_uid
	_attacker_body.add_to_group("Agents")
	add_child_autofree(_attacker_body)

	_defender_body = MockAgentBody.new()
	_defender_body.agent_uid = _defender_uid
	_defender_body.add_to_group("Agents")
	add_child_autofree(_defender_body)

	_combat_system = CombatSystem.new()
	add_child_autofree(_combat_system)
	
	# Create test weapon
	_test_weapon = UtilityToolTemplate.new()
	_test_weapon.template_id = "test_laser"
	_test_weapon.tool_name = "Test Laser"
	_test_weapon.damage = 10.0
	_test_weapon.range_effective = 50.0
	_test_weapon.range_max = 100.0
	_test_weapon.fire_rate = 2.0
	_test_weapon.accuracy = 1.0  # Always hit for testing
	_test_weapon.hull_damage_multiplier = 1.0
	_test_weapon.armor_damage_multiplier = 1.0
	_test_weapon.cooldown_time = 0.0
	
	# Create mock ship templates
	var attacker_ship = _create_mock_ship(100, 50)
	var defender_ship = _create_mock_ship(100, 50)
	
	_combat_system.register_combatant(_attacker_uid, attacker_ship)
	_combat_system.register_combatant(_defender_uid, defender_ship)


func after_each() -> void:
	_attacker_body = null
	_defender_body = null
	_combat_system = null


func _create_mock_ship(hull: int, armor: int) -> Resource:
	var ship = Resource.new()
	ship.set_meta("hull_integrity", hull)
	ship.set_meta("armor_integrity", armor)
	# Duck-type the properties
	ship.set_script(load("res://src/tests/helpers/mock_ship_template.gd"))
	return ship


# --- Registration Tests ---

func test_register_combatant():
	var state = _combat_system.get_combat_state(_attacker_uid)
	
	assert_false(state.empty(), "Combat state should exist for registered combatant")
	assert_eq(state.current_hull, 100, "Hull should be initialized from ship template")
	assert_eq(state.max_hull, 100, "Max hull should be set")
	assert_eq(state.is_disabled, false, "Should not be disabled initially")


func test_unregister_combatant():
	_combat_system.unregister_combatant(_attacker_uid)
	
	var state = _combat_system.get_combat_state(_attacker_uid)
	assert_true(state.empty(), "Combat state should be empty after unregister")


func test_is_in_combat():
	assert_true(_combat_system.is_in_combat(_attacker_uid), "Registered combatant should be in combat")
	
	_combat_system.unregister_combatant(_attacker_uid)
	assert_false(_combat_system.is_in_combat(_attacker_uid), "Unregistered combatant should not be in combat")


# --- Range Tests ---

func test_is_in_range_within_effective():
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(30, 0, 0)  # 30 units away, within 50 effective
	
	assert_true(_combat_system.is_in_range(shooter_pos, target_pos, _test_weapon), 
		"Target within effective range should be in range")


func test_is_in_range_within_max():
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(75, 0, 0)  # 75 units away, within 100 max
	
	assert_true(_combat_system.is_in_range(shooter_pos, target_pos, _test_weapon), 
		"Target within max range should be in range")


func test_is_in_range_out_of_range():
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(150, 0, 0)  # 150 units away, beyond 100 max
	
	assert_false(_combat_system.is_in_range(shooter_pos, target_pos, _test_weapon), 
		"Target beyond max range should not be in range")


# --- Damage Calculation Tests ---

func test_calculate_damage_at_effective_range():
	var damage = _combat_system.calculate_damage(_test_weapon, 30.0)
	
	assert_eq(damage.hull_damage, 10.0, "Should deal full damage within effective range")


func test_calculate_damage_at_max_range():
	var damage = _combat_system.calculate_damage(_test_weapon, 100.0)
	
	assert_eq(damage.hull_damage, 0.0, "Should deal zero damage at max range edge")


func test_calculate_damage_falloff():
	var damage = _combat_system.calculate_damage(_test_weapon, 75.0)  # Halfway through falloff
	
	assert_almost_eq(damage.hull_damage, 5.0, 0.1, "Should deal reduced damage in falloff zone")


# --- Fire Weapon Tests ---

func test_fire_weapon_hit():
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(30, 0, 0)
	
	var result = _combat_system.fire_weapon(_attacker_uid, _defender_uid, _test_weapon, shooter_pos, target_pos)
	
	assert_true(result.success, "Fire should succeed")
	assert_true(result.hit, "Should hit with 100% accuracy")
	assert_eq(result.damage_dealt.hull_damage, 10.0, "Should deal 10 damage")


func test_fire_weapon_out_of_range():
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(150, 0, 0)  # Beyond max range
	
	var result = _combat_system.fire_weapon(_attacker_uid, _defender_uid, _test_weapon, shooter_pos, target_pos)
	
	assert_false(result.success, "Fire should fail")
	assert_eq(result.reason, "Target out of range", "Should report out of range")


func test_fire_weapon_cooldown():
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(30, 0, 0)
	
	# Fire first shot
	_combat_system.fire_weapon(_attacker_uid, _defender_uid, _test_weapon, shooter_pos, target_pos)
	
	# Try to fire again immediately
	var result = _combat_system.fire_weapon(_attacker_uid, _defender_uid, _test_weapon, shooter_pos, target_pos)
	
	assert_false(result.success, "Second shot should fail due to cooldown")
	assert_eq(result.reason, "Weapon on cooldown", "Should report cooldown")


func test_cooldown_update():
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(30, 0, 0)
	
	# Fire first shot
	_combat_system.fire_weapon(_attacker_uid, _defender_uid, _test_weapon, shooter_pos, target_pos)
	
	# Update cooldowns past the fire_rate period (0.5s for 2 shots/sec)
	_combat_system.update_cooldowns(1.0)
	
	# Should be able to fire again
	var result = _combat_system.fire_weapon(_attacker_uid, _defender_uid, _test_weapon, shooter_pos, target_pos)
	
	assert_true(result.success, "Should be able to fire after cooldown")


# --- Damage Application Tests ---

func test_apply_damage_reduces_hull():
	_combat_system.apply_damage(_defender_uid, 25.0)
	
	var state = _combat_system.get_combat_state(_defender_uid)
	assert_eq(state.current_hull, 75, "Hull should be reduced by damage")


func test_apply_damage_disables_at_zero():
	_combat_system.apply_damage(_defender_uid, 100.0)
	
	var state = _combat_system.get_combat_state(_defender_uid)
	assert_eq(state.current_hull, 0, "Hull should be zero")
	assert_true(state.is_disabled, "Ship should be disabled")


func test_apply_damage_clamps_to_zero():
	_combat_system.apply_damage(_defender_uid, 150.0)  # More than hull
	
	var state = _combat_system.get_combat_state(_defender_uid)
	assert_eq(state.current_hull, 0, "Hull should clamp to zero")


func test_get_hull_percent():
	_combat_system.apply_damage(_defender_uid, 30.0)
	
	var percent = _combat_system.get_hull_percent(_defender_uid)
	assert_almost_eq(percent, 0.7, 0.01, "Hull percent should be 70%")


# --- Combat Victory Tests ---

func test_check_victory_player_wins():
	# Disable the defender (enemy)
	_combat_system.apply_damage(_defender_uid, 100.0)
	
	var result = _combat_system.check_combat_victory(_attacker_uid)
	assert_true(result.victory, "Player should win when all enemies disabled")


func test_check_victory_enemies_remain():
	var result = _combat_system.check_combat_victory(_attacker_uid)
	
	assert_false(result.victory, "Victory should be false while enemies remain")
	assert_eq(result.reason, "enemies_remain", "Reason should indicate enemies remain")


func test_check_victory_player_disabled():
	_combat_system.apply_damage(_attacker_uid, 100.0)
	
	var result = _combat_system.check_combat_victory(_attacker_uid)
	
	assert_false(result.victory, "Victory should be false if player disabled")
	assert_eq(result.reason, "player_disabled", "Reason should indicate player disabled")


# --- Signal Tests ---

func test_damage_dealt_signal():
	watch_signals(_combat_system)
	
	_combat_system.apply_damage(_defender_uid, 25.0)
	
	assert_signal_emitted(_combat_system, "damage_dealt", "damage_dealt signal should emit")


func test_ship_disabled_signal():
	watch_signals(_combat_system)
	
	_combat_system.apply_damage(_defender_uid, 100.0)
	
	assert_signal_emitted(_combat_system, "ship_disabled", "ship_disabled signal should emit")


func test_eventbus_agent_damaged_emits_for_damage():
	watch_signals(EventBus)
	_combat_system.apply_damage(_defender_uid, 10.0, 0.0, _attacker_uid)
	assert_signal_emitted(EventBus, "agent_damaged")


func test_eventbus_agent_disabled_emits_on_disable():
	watch_signals(EventBus)
	_combat_system.apply_damage(_defender_uid, 100.0, 0.0, _attacker_uid)
	assert_signal_emitted(EventBus, "agent_disabled")


func test_weapon_fired_signal():
	watch_signals(_combat_system)
	
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(30, 0, 0)
	_combat_system.fire_weapon(_attacker_uid, _defender_uid, _test_weapon, shooter_pos, target_pos)
	
	assert_signal_emitted(_combat_system, "weapon_fired", "weapon_fired signal should emit")


# --- Combat Start/End Tests ---

func test_start_combat():
	# Clear existing combatants
	_combat_system.end_combat()
	
	watch_signals(_combat_system)
	
	var ship1 = _create_mock_ship(100, 50)
	var ship2 = _create_mock_ship(80, 30)
	
	_combat_system.start_combat([
		{"uid": 10, "ship_template": ship1},
		{"uid": 11, "ship_template": ship2}
	])
	
	assert_signal_emitted(_combat_system, "combat_started", "combat_started signal should emit")
	assert_true(_combat_system.is_in_combat(10), "First participant should be in combat")
	assert_true(_combat_system.is_in_combat(11), "Second participant should be in combat")


func test_end_combat():
	watch_signals(_combat_system)
	
	_combat_system.end_combat("victory")
	
	assert_signal_emitted(_combat_system, "combat_ended", "combat_ended signal should emit")
	assert_false(_combat_system.is_in_combat(_attacker_uid), "Combatants should be cleared")

--- Start of ./src/tests/core/systems/test_contract_system.gd ---

# test_contract_system.gd
# Unit tests for ContractSystem - contract acceptance, completion, abandonment
extends "res://addons/gut/test.gd"

const ContractSystem = preload("res://src/core/systems/contract_system.gd")
const InventorySystem = preload("res://src/core/systems/inventory_system.gd")
const CharacterSystem = preload("res://src/core/systems/character_system.gd")

var _contract_system: Node
var _inventory_system: Node
var _character_system: Node
var _test_character_uid: int = 0
var _test_contract_id: String = "test_delivery_contract"


func before_each():
	# Clear GameState
	GameState.characters.clear()
	GameState.inventories.clear()
	GameState.contracts.clear()
	GameState.active_contracts.clear()
	GameState.current_tu = 0
	GameState.player_character_uid = _test_character_uid
	GameState.narrative_state = {
		"reputation": 0,
		"faction_standings": {},
		"known_contacts": [],
		"chronicle_entries": []
	}
	GameState.session_stats = {
		"contracts_completed": 0,
		"total_wp_earned": 0,
		"total_wp_spent": 0,
		"enemies_disabled": 0,
		"time_played_tu": 0
	}
	
	# Create systems
	_contract_system = ContractSystem.new()
	_inventory_system = InventorySystem.new()
	_character_system = CharacterSystem.new()
	add_child(_contract_system)
	add_child(_inventory_system)
	add_child(_character_system)
	
	# Register in GlobalRefs
	GlobalRefs.contract_system = _contract_system
	GlobalRefs.inventory_system = _inventory_system
	GlobalRefs.character_system = _character_system
	
	# Create test character with WP
	var char_template = CharacterTemplate.new()
	char_template.template_id = "test_character"
	char_template.wealth_points = 500
	GameState.characters[_test_character_uid] = char_template
	
	# Create inventory for character
	_inventory_system.create_inventory_for_character(_test_character_uid)
	
	# Create test contract
	var contract = _create_test_contract()
	GameState.contracts[_test_contract_id] = contract


func after_each():
	_contract_system.queue_free()
	_inventory_system.queue_free()
	_character_system.queue_free()
	GlobalRefs.contract_system = null
	GlobalRefs.inventory_system = null
	GlobalRefs.character_system = null
	
	# Reset session stats with defaults (avoid "Invalid get index" errors)
	GameState.session_stats = {
		"contracts_completed": 0,
		"total_wp_earned": 0,
		"total_wp_spent": 0,
		"enemies_disabled": 0,
		"time_played_tu": 0
	}
	GameState.narrative_state = {
		"reputation": 0,
		"faction_standings": {},
		"known_contacts": [],
		"chronicle_entries": []
	}
	GameState.player_docked_at = ""


func _create_test_contract() -> ContractTemplate:
	var contract = ContractTemplate.new()
	contract.template_id = _test_contract_id
	contract.contract_type = "delivery"
	contract.title = "Test Delivery"
	contract.description = "Deliver ore for testing"
	contract.origin_location_id = "station_alpha"
	contract.destination_location_id = "station_beta"
	contract.required_commodity_id = "commodity_ore"
	contract.required_quantity = 10
	contract.reward_wp = 100
	contract.reward_reputation = 5
	contract.faction_id = "test_faction"
	contract.time_limit_tu = -1  # No time limit
	contract.difficulty = 1
	return contract


# --- Test: Get Available Contracts ---

func test_get_available_contracts_at_location():
	var available = _contract_system.get_available_contracts("station_alpha")
	assert_eq(available.size(), 1, "Should find 1 contract at station_alpha")
	assert_eq(available[0].template_id, _test_contract_id, "Should find our test contract")


func test_get_available_contracts_wrong_location():
	var available = _contract_system.get_available_contracts("station_gamma")
	assert_eq(available.size(), 0, "Should find no contracts at wrong location")


func test_get_available_contracts_excludes_active():
	# Accept the contract first
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	
	var available = _contract_system.get_available_contracts("station_alpha")
	assert_eq(available.size(), 0, "Should not show already active contracts")


# --- Test: Accept Contract ---

func test_accept_contract_success():
	var result = _contract_system.accept_contract(_test_character_uid, _test_contract_id)
	
	assert_true(result.success, "Accept should succeed")
	assert_true(GameState.active_contracts.has(_test_contract_id), "Contract should be in active_contracts")
	assert_eq(GameState.active_contracts[_test_contract_id].accepted_at_tu, 0, "Should record accepted time")


func test_accept_contract_not_found():
	var result = _contract_system.accept_contract(_test_character_uid, "nonexistent_contract")
	
	assert_false(result.success, "Accept should fail")
	assert_true("not found" in result.reason.to_lower(), "Reason should mention not found")


func test_accept_contract_already_active():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	var result = _contract_system.accept_contract(_test_character_uid, _test_contract_id)
	
	assert_false(result.success, "Should not accept twice")
	assert_true("already active" in result.reason.to_lower(), "Reason should mention already active")


func test_accept_contract_max_limit():
	# Create and accept 3 contracts
	for i in range(3):
		var contract = _create_test_contract()
		contract.template_id = "contract_" + str(i)
		GameState.contracts[contract.template_id] = contract
		_contract_system.accept_contract(_test_character_uid, contract.template_id)
	
	# Try to accept 4th
	var result = _contract_system.accept_contract(_test_character_uid, _test_contract_id)
	
	assert_false(result.success, "Should not accept 4th contract")
	assert_true("maximum" in result.reason.to_lower(), "Reason should mention maximum")


# --- Test: Get Active Contracts ---

func test_get_active_contracts():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	
	var active = _contract_system.get_active_contracts(_test_character_uid)
	assert_eq(active.size(), 1, "Should have 1 active contract")
	assert_eq(active[0].template_id, _test_contract_id, "Should be our test contract")


func test_get_active_contracts_empty():
	var active = _contract_system.get_active_contracts(_test_character_uid)
	assert_eq(active.size(), 0, "Should have no active contracts initially")


# --- Test: Check Contract Completion ---

func test_check_completion_not_active():
	var result = _contract_system.check_contract_completion(_test_character_uid, _test_contract_id)
	
	assert_false(result.can_complete, "Should not complete inactive contract")
	assert_true("not active" in result.reason.to_lower(), "Reason should mention not active")


func test_check_completion_missing_cargo():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	GameState.player_docked_at = "station_beta"
	
	var result = _contract_system.check_contract_completion(_test_character_uid, _test_contract_id)
	
	assert_false(result.can_complete, "Should not complete without cargo")
	assert_true("insufficient" in result.reason.to_lower(), "Reason should mention insufficient cargo")


func test_check_completion_with_cargo():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	GameState.player_docked_at = "station_beta"
	
	# Add required cargo
	_inventory_system.add_asset(
		_test_character_uid,
		InventorySystem.InventoryType.COMMODITY,
		"commodity_ore",
		10
	)
	
	var result = _contract_system.check_contract_completion(_test_character_uid, _test_contract_id)
	
	assert_true(result.can_complete, "Should be able to complete with cargo")


func test_check_completion_partial_cargo():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	GameState.player_docked_at = "station_beta"
	
	# Add less than required
	_inventory_system.add_asset(
		_test_character_uid,
		InventorySystem.InventoryType.COMMODITY,
		"commodity_ore",
		5
	)
	
	var result = _contract_system.check_contract_completion(_test_character_uid, _test_contract_id)
	
	assert_false(result.can_complete, "Should not complete with partial cargo")


# --- Test: Complete Contract ---

func test_complete_contract_success():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	_inventory_system.add_asset(
		_test_character_uid,
		InventorySystem.InventoryType.COMMODITY,
		"commodity_ore",
		10
	)
	
	# Set player at destination
	GameState.player_docked_at = "station_beta"
	
	var initial_wp = _character_system.get_wp(_test_character_uid)
	var result = _contract_system.complete_contract(_test_character_uid, _test_contract_id)
	
	assert_true(result.success, "Complete should succeed")
	assert_eq(result.rewards.wp, 100, "Should report correct reward")
	
	# Check WP increased
	var final_wp = _character_system.get_wp(_test_character_uid)
	assert_eq(final_wp, initial_wp + 100, "WP should increase by reward amount")
	
	# Check cargo removed
	var cargo = _inventory_system.get_inventory_by_type(_test_character_uid, InventorySystem.InventoryType.COMMODITY)
	assert_eq(cargo.get("commodity_ore", 0), 0, "Cargo should be removed")
	
	# Check contract removed from active
	assert_false(GameState.active_contracts.has(_test_contract_id), "Contract should be removed from active")
	
	# Check stats updated
	assert_eq(GameState.session_stats.contracts_completed, 1, "Contracts completed should increment")


func test_complete_contract_applies_reputation():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	_inventory_system.add_asset(
		_test_character_uid,
		InventorySystem.InventoryType.COMMODITY,
		"commodity_ore",
		10
	)
	
	# Must be at destination for delivery completion
	GameState.player_docked_at = "station_beta"
	_contract_system.complete_contract(_test_character_uid, _test_contract_id)
	
	assert_eq(GameState.narrative_state.reputation, 5, "Reputation should increase")
	assert_eq(GameState.narrative_state.faction_standings.get("test_faction", 0), 5, "Faction standing should increase")


func test_complete_contract_fails_without_cargo():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	
	var result = _contract_system.complete_contract(_test_character_uid, _test_contract_id)
	
	assert_false(result.success, "Complete should fail without cargo")


# --- Test: Abandon Contract ---

func test_abandon_contract_success():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	
	var result = _contract_system.abandon_contract(_test_character_uid, _test_contract_id)
	
	assert_true(result.success, "Abandon should succeed")
	assert_false(GameState.active_contracts.has(_test_contract_id), "Contract should be removed")


func test_abandon_contract_not_active():
	var result = _contract_system.abandon_contract(_test_character_uid, _test_contract_id)
	
	assert_false(result.success, "Abandon should fail for inactive contract")
	assert_true("not active" in result.reason.to_lower(), "Reason should mention not active")


# --- Test: Contract Expiration ---

func test_contract_expiration_check():
	# Create time-limited contract
	var limited_contract = _create_test_contract()
	limited_contract.template_id = "limited_contract"
	limited_contract.time_limit_tu = 50
	GameState.contracts["limited_contract"] = limited_contract
	
	_contract_system.accept_contract(_test_character_uid, "limited_contract")
	
	# Advance time past limit
	GameState.current_tu = 60
	
	var expired = _contract_system.check_expired_contracts(_test_character_uid)
	
	assert_eq(expired.size(), 1, "Should find 1 expired contract")
	assert_false(GameState.active_contracts.has("limited_contract"), "Expired contract should be removed")


func test_contract_not_expired_within_limit():
	var limited_contract = _create_test_contract()
	limited_contract.template_id = "limited_contract"
	limited_contract.time_limit_tu = 50
	GameState.contracts["limited_contract"] = limited_contract
	
	_contract_system.accept_contract(_test_character_uid, "limited_contract")
	
	# Advance time but within limit
	GameState.current_tu = 30
	
	var check = _contract_system.check_contract_completion(_test_character_uid, "limited_contract")
	
	# Should not be expired (though still can't complete without cargo)
	assert_false("expired" in check.reason.to_lower(), "Should not be expired yet")

--- Start of ./src/tests/core/systems/test_docking_logic.gd ---

extends "res://addons/gut/test.gd"

var DockableStationScript = load("res://src/scenes/game_world/station/dockable_station.gd")
var PlayerControllerScript = load("res://src/modules/piloting/player_controller_ship.gd")

func test_docking_signals():
	var station = StaticBody.new()
	station.set_script(DockableStationScript)
	station.location_id = "test_station"
	
	var docking_zone = Area.new()
	docking_zone.name = "DockingZone"
	station.add_child(docking_zone)
	
	add_child(station)
	
	var player = KinematicBody.new()
	player.name = "Player"
	# Mock is_player method
	var script = GDScript.new()
	script.source_code = "extends KinematicBody\nfunc is_player(): return true"
	script.reload()
	player.set_script(script)
	add_child(player)
	
	watch_signals(EventBus)
	
	# Simulate enter
	station._on_body_entered(player)
	assert_signal_emitted_with_parameters(EventBus, "dock_available", ["test_station"])
	
	# Simulate exit
	station._on_body_exited(player)
	assert_signal_emitted(EventBus, "dock_unavailable")
	
	station.free()
	player.free()

func test_player_controller_docking():
	var agent = KinematicBody.new()
	# Mock command_stop
	var agent_script = GDScript.new()
	agent_script.source_code = "extends KinematicBody\nfunc command_stop(): pass"
	agent_script.reload()
	agent.set_script(agent_script)
	
	var movement_system = Node.new()
	movement_system.name = "MovementSystem"
	agent.add_child(movement_system)
	
	var controller = Node.new()
	controller.set_script(PlayerControllerScript)
	controller.name = "PlayerInputHandler"
	agent.add_child(controller)
	
	add_child(agent)
	
	# Simulate dock available
	controller._on_dock_available("station_beta")
	assert_eq(controller._can_dock_at, "station_beta")
	
	# Simulate dock unavailable
	controller._on_dock_unavailable()
	assert_eq(controller._can_dock_at, "")
	
	# Simulate docking
	controller._on_player_docked("station_gamma")
	assert_false(controller.is_processing_unhandled_input())
	assert_false(controller.is_physics_processing())
	
	# Simulate undocking
	controller._on_player_undocked()
	assert_true(controller.is_processing_unhandled_input())
	assert_true(controller.is_physics_processing())
	
	agent.free()

--- Start of ./src/tests/core/systems/test_event_system.gd ---

# File: tests/core/systems/test_event_system.gd
# Unit tests for EventSystem encounter triggering and hostile management (Sprint 9)
# Test coverage: spawn logic, cooldown management, signal emission, edge cases

extends "res://addons/gut/test.gd"

const EventSystem = preload("res://src/core/systems/event_system.gd")


## Mock spawner that simulates NPC spawning.
class DummySpawner:
	extends Node
	var spawn_count: int = 0

	func spawn_npc_from_template(_template_path: String, position: Vector3, _overrides: Dictionary = {}) -> KinematicBody:
		spawn_count += 1
		var npc: KinematicBody = KinematicBody.new()
		npc.set("agent_uid", 1000 + spawn_count)
		npc.translation = position
		return npc


## Mock player agent.
class DummyPlayer:
	extends KinematicBody
	var agent_uid: int = 1


var _event_system: Node
var _spawner: DummySpawner
var _player: DummyPlayer


## Setup before each test: initialize event system with mocks.
func before_each() -> void:
	_spawner = DummySpawner.new()
	add_child_autofree(_spawner)
	GlobalRefs.agent_spawner = _spawner

	_player = DummyPlayer.new()
	_player.translation = Vector3.ZERO
	add_child_autofree(_player)
	GlobalRefs.player_agent_body = _player

	_event_system = EventSystem.new()
	add_child_autofree(_event_system)
	_event_system._ready()


## Cleanup after each test: clear global references.
func after_each() -> void:
	GlobalRefs.agent_spawner = null
	GlobalRefs.player_agent_body = null
	_event_system = null
	_spawner = null
	_player = null


# ============ SUCCESS PATH TESTS ============

## Test: Tick decrements cooldown without triggering encounter.
func test_tick_decrements_cooldown_without_triggering() -> void:
	watch_signals(EventBus)
	_event_system._encounter_cooldown_tu = 5
	_event_system._on_world_event_tick_triggered(2)
	assert_eq(_event_system._encounter_cooldown_tu, 3, "Cooldown should decrement by tick amount")
	assert_signal_not_emitted(EventBus, "combat_initiated", "Should not trigger with active cooldown")


## Test: Cooldown doesn't go below zero.
func test_cooldown_does_not_go_negative() -> void:
	_event_system._active_hostiles = [Node.new()]
	add_child_autofree(_event_system._active_hostiles[0])
	_event_system._encounter_cooldown_tu = 2
	_event_system._on_world_event_tick_triggered(10)
	assert_eq(_event_system._encounter_cooldown_tu, 0, "Cooldown should clamp at zero")


## Test: Force encounter emits combat_initiated signal.
func test_force_encounter_emits_combat_initiated() -> void:
	watch_signals(EventBus)
	_event_system.force_encounter()
	assert_signal_emitted(EventBus, "combat_initiated", "Force encounter should emit combat_initiated")


## Test: Get active hostiles returns a copy, not reference.
func test_get_active_hostiles_returns_copy() -> void:
	var hostile: Node = Node.new()
	add_child_autofree(hostile)
	_event_system._active_hostiles = [hostile]
	var result: Array = _event_system.get_active_hostiles()
	result.clear()
	assert_eq(_event_system._active_hostiles.size(), 1, "Original array should remain unchanged")


# ============ SIGNAL EMISSION TESTS ============

## Test: Emits combat_ended when last hostile is disabled.
func test_emits_combat_ended_when_last_hostile_removed() -> void:
	watch_signals(EventBus)
	var hostile: Node = Node.new()
	add_child_autofree(hostile)
	_event_system._active_hostiles = [hostile]
	_event_system._on_agent_disabled(hostile)
	assert_signal_emitted(EventBus, "combat_ended", "Should emit combat_ended when all hostiles removed")
	assert_eq(_event_system._active_hostiles.size(), 0, "Hostiles should be empty after removal")


## Test: Handles agent despawning signal.
func test_handles_agent_despawning_signal() -> void:
	watch_signals(EventBus)
	var hostile: Node = Node.new()
	add_child_autofree(hostile)
	_event_system._active_hostiles = [hostile]
	_event_system._on_agent_despawning(hostile)
	assert_signal_emitted(EventBus, "combat_ended", "Should emit combat_ended on despawn")


## Test: Multiple hostiles must all be removed before combat_ended.
func test_multiple_hostiles_all_removed_for_combat_end() -> void:
	watch_signals(EventBus)
	var hostile1: Node = Node.new()
	var hostile2: Node = Node.new()
	add_child_autofree(hostile1)
	add_child_autofree(hostile2)
	_event_system._active_hostiles = [hostile1, hostile2]
	_event_system._on_agent_disabled(hostile1)
	assert_signal_not_emitted(EventBus, "combat_ended", "Should not end with hostiles remaining")
	_event_system._on_agent_disabled(hostile2)
	assert_signal_emitted(EventBus, "combat_ended", "Should end when all hostiles removed")


# ============ EDGE CASE TESTS ============

## Edge Case: Negative tick amount ignored.
func test_negative_tick_amount_ignored() -> void:
	var initial_cooldown: int = _event_system._encounter_cooldown_tu
	_event_system._on_world_event_tick_triggered(-5)
	assert_eq(_event_system._encounter_cooldown_tu, initial_cooldown, "Negative ticks should be ignored")


## Edge Case: Zero tick amount ignored.
func test_zero_tick_amount_ignored() -> void:
	var initial_cooldown: int = _event_system._encounter_cooldown_tu
	_event_system._on_world_event_tick_triggered(0)
	assert_eq(_event_system._encounter_cooldown_tu, initial_cooldown, "Zero ticks should be ignored")


## Edge Case: Pruning removes freed nodes from hostiles.
func test_prune_removes_freed_nodes() -> void:
	var valid_hostile: Node = Node.new()
	var freed_hostile: Node = Node.new()
	add_child_autofree(valid_hostile)
	add_child_autofree(freed_hostile)
	
	_event_system._active_hostiles = [valid_hostile, freed_hostile]
	freed_hostile.queue_free()
	yield(get_tree(), "idle_frame")
	
	_event_system._prune_invalid_hostiles()
	assert_eq(_event_system._active_hostiles.size(), 1, "Freed nodes should be pruned")
	assert_true(_event_system._active_hostiles.has(valid_hostile), "Valid node should remain")


## Edge Case: Remove non-existent hostile doesn't crash.
func test_remove_nonexistent_hostile_safe() -> void:
	var hostile1: Node = Node.new()
	var hostile2: Node = Node.new()
	add_child_autofree(hostile1)
	add_child_autofree(hostile2)
	
	_event_system._active_hostiles = [hostile1]
	_event_system._on_agent_disabled(hostile2)
	assert_eq(_event_system._active_hostiles.size(), 1, "Non-existent hostile removal should be safe")


## Edge Case: Force encounter with no active hostiles spawns immediately.
func test_force_encounter_with_no_hostiles() -> void:
	_event_system._active_hostiles.clear()
	_event_system._encounter_cooldown_tu = 100
	_event_system.force_encounter()
	assert_eq(_event_system._encounter_cooldown_tu, 0, "Force should reset cooldown")
	assert_true(_event_system._active_hostiles.size() > 0, "Should spawn hostiles")


## Edge Case: Spawn position calculation within expected bounds.
func test_spawn_position_within_bounds() -> void:
	var player_pos: Vector3 = Vector3.ZERO
	for _i in range(10):
		var spawn_pos: Vector3 = _event_system._calculate_spawn_position(player_pos)
		var distance: float = player_pos.distance_to(spawn_pos)
		assert_true(distance >= EventSystem.SPAWN_DISTANCE_MIN, "Spawn distance too close")
		assert_true(distance <= EventSystem.SPAWN_DISTANCE_MAX, "Spawn distance too far")

--- Start of ./src/tests/core/systems/test_inventory_system.gd ---

# File: tests/core/systems/test_inventory_system.gd
# GUT Test for the unified, stateless InventorySystem.
# Version: 3.0 - Rewritten for unified GameState architecture.

extends GutTest

# --- Test Subjects ---
const InventorySystem = preload("res://src/core/systems/inventory_system.gd")
const ShipTemplate = preload("res://database/definitions/asset_ship_template.gd")
const ModuleTemplate = preload("res://database/definitions/asset_module_template.gd")

# --- Test State ---
var inventory_system_instance = null
const PLAYER_UID = 0
const SHIP_UID = 100
const MODULE_UID = 200
const COMMODITY_ID = "commodity_default"


func before_each():
	# 1. Clean the global state
	GameState.characters.clear()
	GameState.inventories.clear()
	GameState.assets_ships.clear()
	GameState.assets_modules.clear()
	GameState.player_character_uid = PLAYER_UID

	# 2. Create mock assets in the master asset lists
	GameState.assets_ships[SHIP_UID] = ShipTemplate.new()
	GameState.assets_modules[MODULE_UID] = ModuleTemplate.new()

	# 3. Instantiate the system we are testing
	inventory_system_instance = InventorySystem.new()
	add_child_autofree(inventory_system_instance)

	# 4. Create an inventory for our test character
	inventory_system_instance.create_inventory_for_character(PLAYER_UID)


func after_each():
	# Clean up global state to ensure test isolation
	GameState.characters.clear()
	GameState.inventories.clear()
	GameState.assets_ships.clear()
	GameState.assets_modules.clear()
	GameState.player_character_uid = -1
	inventory_system_instance = null


# --- Test Cases ---

func test_create_inventory_for_character():
	assert_has(GameState.inventories, PLAYER_UID, "An inventory should be created for the character UID.")
	var inventory = GameState.inventories[PLAYER_UID]
	assert_has(inventory, inventory_system_instance.InventoryType.SHIP, "Inventory should have a SHIP dictionary.")
	assert_has(inventory, inventory_system_instance.InventoryType.MODULE, "Inventory should have a MODULE dictionary.")
	assert_has(inventory, inventory_system_instance.InventoryType.COMMODITY, "Inventory should have a COMMODITY dictionary.")


func test_add_and_remove_unique_asset():
	# Test adding a unique asset (ship)
	inventory_system_instance.add_asset(PLAYER_UID, inventory_system_instance.InventoryType.SHIP, SHIP_UID)
	var player_inventory = GameState.inventories[PLAYER_UID]
	assert_has(player_inventory[inventory_system_instance.InventoryType.SHIP], SHIP_UID, "Player's ship inventory should contain the ship UID.")
	assert_eq(inventory_system_instance.get_asset_count(PLAYER_UID, inventory_system_instance.InventoryType.SHIP, SHIP_UID), 1, "Ship count should be 1.")

	# Test removing the unique asset
	var result = inventory_system_instance.remove_asset(PLAYER_UID, inventory_system_instance.InventoryType.SHIP, SHIP_UID)
	assert_true(result, "Removing a unique asset should return true.")
	assert_false(player_inventory[inventory_system_instance.InventoryType.SHIP].has(SHIP_UID), "Ship should be removed from inventory.")
	assert_eq(inventory_system_instance.get_asset_count(PLAYER_UID, inventory_system_instance.InventoryType.SHIP, SHIP_UID), 0, "Ship count should be 0 after removal.")


func test_add_and_remove_commodity():
	# Test adding a new commodity
	inventory_system_instance.add_asset(PLAYER_UID, inventory_system_instance.InventoryType.COMMODITY, COMMODITY_ID, 10)
	var player_inventory = GameState.inventories[PLAYER_UID]
	assert_eq(player_inventory[inventory_system_instance.InventoryType.COMMODITY][COMMODITY_ID], 10, "Commodity count should be 10.")

	# Test adding to an existing stack
	inventory_system_instance.add_asset(PLAYER_UID, inventory_system_instance.InventoryType.COMMODITY, COMMODITY_ID, 5)
	assert_eq(player_inventory[inventory_system_instance.InventoryType.COMMODITY][COMMODITY_ID], 15, "Commodity count should be 15 after adding more.")

	# Test removing some
	var result = inventory_system_instance.remove_asset(PLAYER_UID, inventory_system_instance.InventoryType.COMMODITY, COMMODITY_ID, 3)
	assert_true(result, "Removing a partial stack should return true.")
	assert_eq(player_inventory[inventory_system_instance.InventoryType.COMMODITY][COMMODITY_ID], 12, "Commodity count should be 12 after removing some.")

	# Test removing all
	result = inventory_system_instance.remove_asset(PLAYER_UID, inventory_system_instance.InventoryType.COMMODITY, COMMODITY_ID, 12)
	assert_true(result, "Removing the rest of the stack should return true.")
	assert_false(player_inventory[inventory_system_instance.InventoryType.COMMODITY].has(COMMODITY_ID), "Commodity should be removed from inventory when count is zero.")


func test_get_inventory_by_type():
	# Add some assets to test with
	inventory_system_instance.add_asset(PLAYER_UID, inventory_system_instance.InventoryType.MODULE, MODULE_UID)
	inventory_system_instance.add_asset(PLAYER_UID, inventory_system_instance.InventoryType.COMMODITY, COMMODITY_ID, 50)

	# Get the module inventory
	var module_inventory = inventory_system_instance.get_inventory_by_type(PLAYER_UID, inventory_system_instance.InventoryType.MODULE)
	assert_eq(module_inventory.size(), 1, "Should return a dictionary with one module.")
	assert_has(module_inventory, MODULE_UID, "The returned dictionary should contain the correct module UID.")

	# Get the commodity inventory
	var commodity_inventory = inventory_system_instance.get_inventory_by_type(PLAYER_UID, inventory_system_instance.InventoryType.COMMODITY)
	assert_eq(commodity_inventory.size(), 1, "Should return a dictionary with one commodity type.")
	assert_eq(commodity_inventory[COMMODITY_ID], 50, "The returned dictionary should have the correct quantity.")

--- Start of ./src/tests/core/systems/test_narrative_action_system.gd ---

# File: tests/core/systems/test_narrative_action_system.gd
# GUT Test for NarrativeActionSystem.
# Version: 1.1 - Tests request/resolve flow, effect application, and edge cases.

extends GutTest

# --- Preloads ---
const NarrativeActionSystemPath = "res://src/core/systems/narrative_action_system.gd"
const CharacterSystemPath = "res://src/core/systems/character_system.gd"
const CharacterTemplate = preload("res://database/definitions/character_template.gd")

# --- Test State ---
var narrative_system = null
var character_system_instance = null
var default_char_template = null
const PLAYER_UID = 0


func before_each():
	"""Set up game state and instantiate the system."""
	# Clear global state
	GameState.characters.clear()
	GameState.narrative_state.clear()
	GameState.player_character_uid = PLAYER_UID

	# Load the base character template
	default_char_template = load("res://database/registry/characters/character_default.tres")
	assert_true(is_instance_valid(default_char_template), "Pre-check: Default character template must load.")

	# Create and register a player character instance
	var player_char_instance = default_char_template.duplicate()
	GameState.characters[PLAYER_UID] = player_char_instance
	GameState.player_character_uid = PLAYER_UID

	# Instantiate CharacterSystem and register in GlobalRefs
	var char_system_script = load(CharacterSystemPath)
	character_system_instance = char_system_script.new()
	add_child_autofree(character_system_instance)
	GlobalRefs.set_character_system(character_system_instance)

	# Instantiate the narrative system via load() to avoid cyclic reference error
	var script = load(NarrativeActionSystemPath)
	narrative_system = script.new()
	add_child_autofree(narrative_system)
	narrative_system._ready()


func after_each():
	"""Clean up."""
	GameState.characters.clear()
	GameState.narrative_state.clear()
	GameState.player_character_uid = -1
	GlobalRefs.set_character_system(null)
	narrative_system = null
	character_system_instance = null
	default_char_template = null


# --- Test Cases ---

func test_request_action_success():
	"""Test that request_action stores pending action and emits EventBus signal."""
	# Given: A narrative system and valid context
	var context = {
		"char_uid": PLAYER_UID,
		"description": "Execute a risky maneuver."
	}

	# When: We request an action
	narrative_system.request_action("dock_arrival", context)

	# Then: _pending_action should be populated
	assert_true(not narrative_system._pending_action.empty(), "Pending action should be set")
	assert_eq(narrative_system._pending_action.action_type, "dock_arrival", "Action type should match")
	assert_eq(narrative_system._pending_action.char_uid, PLAYER_UID, "Character UID should match")
	assert_eq(narrative_system._pending_action.skill_name, "piloting", "Skill for dock_arrival should be piloting")


func test_resolve_action_no_pending():
	"""Test that resolve_action fails gracefully when no pending action."""
	# Given: No pending action
	narrative_system._pending_action = {}

	# When: We attempt to resolve
	var result = narrative_system.resolve_action(0, 0)

	# Then: Should return failure
	assert_false(result.success, "Should fail when no pending action")
	assert_eq(result.reason, "No pending action", "Reason should indicate no pending action")


func test_resolve_action_character_unavailable():
	"""Test that resolve_action fails when CharacterSystem is unavailable."""
	# Given: A pending action but no CharacterSystem
	var old_char_system = GlobalRefs.character_system
	GlobalRefs.character_system = null

	narrative_system._pending_action = {
		"char_uid": PLAYER_UID,
		"action_type": "contract_complete",
		"attribute_name": "cunning",
		"skill_name": "negotiation"
	}

	# When: We attempt to resolve
	var result = narrative_system.resolve_action(0, 0)

	# Then: Should return failure
	assert_false(result.success, "Should fail when CharacterSystem unavailable")
	assert_eq(result.reason, "CharacterSystem unavailable", "Reason should indicate missing system")

	# Restore
	GlobalRefs.character_system = old_char_system


func test_resolve_action_fp_clamping():
	"""Test that resolve_action clamps fp_spent to available FP (EDGE CASE)."""
	# Given: A character with 2 available FP
	GameState.characters[PLAYER_UID].focus_points = 2

	narrative_system._pending_action = {
		"char_uid": PLAYER_UID,
		"action_type": "contract_complete",
		"attribute_name": "cunning",
		"skill_name": "negotiation"
	}

	# When: We attempt to spend 5 FP (more than available)
	var result = narrative_system.resolve_action(Constants.ActionApproach.CAUTIOUS, 5)

	# Then: Should succeed, but FP spent should be clamped to available
	assert_true(result.success, "Should succeed despite over-allocation")
	# The actual FP deduction is handled by character_system, verify it was called with clamped value
	assert_true(result.has("effects_applied"), "Should have effects")


func test_apply_effects_wp_gain():
	"""Test that _apply_effects correctly adds WP."""
	# Given: Effects with WP gain
	var effects = {
		"wp_gain": 50
	}

	var char_wp_before = int(GlobalRefs.character_system.get_wp(PLAYER_UID))

	# When: We apply effects
	var applied = narrative_system._apply_effects(PLAYER_UID, effects)

	# Then: WP should increase
	var char_wp_after = int(GlobalRefs.character_system.get_wp(PLAYER_UID))
	assert_eq(char_wp_after, char_wp_before + 50, "WP should increase by 50")
	assert_true(applied.has("wp_gained"), "Applied effects should record wp_gained")
	assert_eq(applied["wp_gained"], 50, "Applied wp_gained should be 50")


func test_apply_effects_wp_cost():
	"""Test that _apply_effects correctly subtracts WP."""
	# Given: Effects with WP cost
	var effects = {
		"wp_cost": 30
	}

	# Ensure character has enough WP
	GlobalRefs.character_system.add_wp(PLAYER_UID, 100)
	var char_wp_before = int(GlobalRefs.character_system.get_wp(PLAYER_UID))

	# When: We apply effects
	var applied = narrative_system._apply_effects(PLAYER_UID, effects)

	# Then: WP should decrease
	var char_wp_after = int(GlobalRefs.character_system.get_wp(PLAYER_UID))
	assert_eq(char_wp_after, char_wp_before - 30, "WP should decrease by 30")
	assert_true(applied.has("wp_lost"), "Applied effects should record wp_lost")


func test_apply_effects_reputation_change():
	"""Test that _apply_effects updates reputation correctly."""
	# Given: Effects with reputation change
	var effects = {
		"reputation_change": 5
	}

	var rep_before = GameState.narrative_state.get("reputation", 0)

	# When: We apply effects
	var applied = narrative_system._apply_effects(PLAYER_UID, effects)

	# Then: Reputation should increase
	var rep_after = GameState.narrative_state.get("reputation", 0)
	assert_eq(rep_after, rep_before + 5, "Reputation should increase by 5")
	assert_true(applied.has("reputation_changed"), "Applied effects should record reputation_changed")


func test_apply_effects_null_effects():
	"""Test that _apply_effects handles empty effects gracefully."""
	# Given: Empty effects dictionary
	var effects = {}

	# When: We apply empty effects
	var applied = narrative_system._apply_effects(PLAYER_UID, effects)

	# Then: Should return empty dict (no changes)
	assert_eq(applied.size(), 0, "Should return empty dict for empty effects")


func test_get_skill_for_action_contract_complete():
	"""Test that _get_skill_for_action returns correct skill for contract_complete."""
	var skill_info = narrative_system._get_skill_for_action("contract_complete")
	assert_eq(skill_info.attribute_name, "cunning", "Should use cunning attribute")
	assert_eq(skill_info.skill_name, "negotiation", "Should use negotiation skill")


func test_get_skill_for_action_dock_arrival():
	"""Test that _get_skill_for_action returns correct skill for dock_arrival."""
	var skill_info = narrative_system._get_skill_for_action("dock_arrival")
	assert_eq(skill_info.attribute_name, "reflex", "Should use reflex attribute")
	assert_eq(skill_info.skill_name, "piloting", "Should use piloting skill")


func test_get_skill_for_action_trade_finalize():
	"""Test that _get_skill_for_action returns correct skill for trade_finalize."""
	var skill_info = narrative_system._get_skill_for_action("trade_finalize")
	assert_eq(skill_info.attribute_name, "cunning", "Should use cunning attribute")
	assert_eq(skill_info.skill_name, "trading", "Should use trading skill")


func test_get_skill_for_action_unknown():
	"""Test that _get_skill_for_action defaults for unknown action type."""
	var skill_info = narrative_system._get_skill_for_action("unknown_action")
	assert_eq(skill_info.attribute_name, "cunning", "Should default to cunning")
	assert_eq(skill_info.skill_name, "general", "Should default to general skill")


func test_get_attribute_value_no_attributes():
	"""Test that _get_attribute_value returns 0 when attributes not implemented (EDGE CASE)."""
	# Phase 1: CharacterTemplate doesn't have attributes dict
	var attr_value = narrative_system._get_attribute_value(PLAYER_UID, "cunning")
	assert_eq(attr_value, 0, "Should return 0 for Phase 1 (no attributes)")


func test_reset_focus_points():
	"""Test that _reset_focus_points correctly resets FP to 0."""
	# Given: Character with 3 FP
	GameState.characters[PLAYER_UID].focus_points = 3
	assert_eq(GlobalRefs.character_system.get_fp(PLAYER_UID), 3, "Should start with 3 FP")

	# When: We reset FP
	narrative_system._reset_focus_points(PLAYER_UID)

	# Then: FP should be 0
	assert_eq(GlobalRefs.character_system.get_fp(PLAYER_UID), 0, "FP should be reset to 0")

--- Start of ./src/tests/core/systems/test_time_system.gd ---

# File: tests/core/systems/test_time_system.gd
# Version: 2.1 - Corrected GUT assertion syntax.

extends GutTest

# --- Test Subjects ---
const TimeSystem = preload("res://src/core/systems/time_system.gd")
const CharacterSystem = preload("res://src/core/systems/character_system.gd") # For mocking

# --- Test State ---
var time_system_instance = null
var mock_character_system = null
const PLAYER_UID = 0

func before_each():
	# 1. Clean and set up the global state for the test
	GameState.current_tu = 0
	GameState.player_character_uid = PLAYER_UID

	# 2. Create a mock CharacterSystem and set it in GlobalRefs
	mock_character_system = double(CharacterSystem).new()
	add_child_autofree(mock_character_system)
	GlobalRefs.character_system = mock_character_system

	# 3. Stub the methods that TimeSystem will call
	stub(mock_character_system, "get_player_character_uid").to_return(PLAYER_UID)
	stub(mock_character_system, "apply_upkeep_cost").to_do_nothing()

	# 4. Instantiate the system we are testing
	time_system_instance = TimeSystem.new()
	add_child_autofree(time_system_instance)

func after_each():
	# Clean up global state to ensure test isolation
	GameState.current_tu = 0
	GameState.player_character_uid = -1
	GlobalRefs.character_system = null
	time_system_instance = null

# --- Test Cases ---

func test_initialization():
	assert_eq(time_system_instance.get_current_tu(), 0, "Initial TU should be 0 from GameState.")

func test_add_time_units_below_threshold():
	watch_signals(EventBus)
	time_system_instance.add_time_units(5)
	assert_eq(GameState.current_tu, 5, "GameState.current_tu should be 5.")
	assert_signal_not_emitted(EventBus, "world_event_tick_triggered")
	assert_not_called(mock_character_system, "apply_upkeep_cost")

func test_add_time_units_exactly_at_threshold():
	watch_signals(EventBus)
	time_system_instance.add_time_units(Constants.TIME_CLOCK_MAX_TU)
	assert_eq(GameState.current_tu, 0, "TU should reset to 0 after a tick.")
	assert_signal_emitted(EventBus, "world_event_tick_triggered")
	assert_called(mock_character_system, "apply_upkeep_cost", [PLAYER_UID, Constants.DEFAULT_UPKEEP_COST])

func test_add_time_units_above_threshold():
	watch_signals(EventBus)
	time_system_instance.add_time_units(Constants.TIME_CLOCK_MAX_TU + 5)
	assert_eq(GameState.current_tu, 5, "TU should be 5 after one tick.")
	assert_signal_emitted(EventBus, "world_event_tick_triggered")
	assert_call_count(mock_character_system, "apply_upkeep_cost", 1, [PLAYER_UID, Constants.DEFAULT_UPKEEP_COST])

func test_add_time_units_triggers_multiple_ticks():
	watch_signals(EventBus)
	time_system_instance.add_time_units((Constants.TIME_CLOCK_MAX_TU * 2) + 5)
	assert_eq(GameState.current_tu, 5, "TU should be 5 after two ticks.")
	assert_signal_emit_count(EventBus, "world_event_tick_triggered", 2)
	assert_call_count(mock_character_system, "apply_upkeep_cost", 2, [PLAYER_UID, Constants.DEFAULT_UPKEEP_COST])

--- Start of ./src/tests/core/systems/test_trading_system.gd ---

# File: tests/core/systems/test_trading_system.gd
# Purpose: Tests for TradingSystem buy/sell API and validation logic.
# Version: 1.0

extends GutTest

var trading_system: Node
var inventory_system: Node
var character_system: Node
var asset_system: Node

const TEST_CHARACTER_UID = 999
const TEST_LOCATION_ID = "test_station"


func before_each():
	# Create TradingSystem under test.
	trading_system = load("res://src/core/systems/trading_system.gd").new()
	add_child(trading_system)
	
	# Create InventorySystem.
	inventory_system = Node.new()
	inventory_system.set_script(load("res://src/core/systems/inventory_system.gd"))
	add_child(inventory_system)
	GlobalRefs.inventory_system = inventory_system
	GlobalRefs.trading_system = trading_system
	
	# Create CharacterSystem (needed for WP operations).
	character_system = Node.new()
	character_system.set_script(load("res://src/core/systems/character_system.gd"))
	add_child(character_system)
	GlobalRefs.character_system = character_system
	
	# Create AssetSystem (needed for cargo capacity checks).
	asset_system = Node.new()
	asset_system.set_script(load("res://src/core/systems/asset_system.gd"))
	add_child(asset_system)
	GlobalRefs.asset_system = asset_system
	
	# Set up test character with wealth_points and cargo capacity.
	var character = CharacterTemplate.new()
	character.character_name = "Test Trader"
	character.wealth_points = 1000
	GameState.characters[TEST_CHARACTER_UID] = character
	GameState.player_character_uid = TEST_CHARACTER_UID
	
	# Create inventory for test character.
	inventory_system.create_inventory_for_character(TEST_CHARACTER_UID)
	
	# Set up test ship with cargo capacity.
	var ship = ShipTemplate.new()
	ship.cargo_capacity = 100
	var ship_uid = 1
	GameState.assets_ships[ship_uid] = ship
	character.active_ship_uid = ship_uid
	
	# Set up test location with market inventory.
	var location = LocationTemplate.new()
	location.template_id = TEST_LOCATION_ID
	location.location_name = "Test Station"
	location.market_inventory = {
		"commodity_ore": {"quantity": 50, "buy_price": 10, "sell_price": 8},
		"commodity_fuel": {"quantity": 20, "buy_price": 25, "sell_price": 20}
	}
	GameState.locations[TEST_LOCATION_ID] = location


func after_each():
	# Clean up.
	GlobalRefs.inventory_system = null
	GlobalRefs.trading_system = null
	GlobalRefs.character_system = null
	GlobalRefs.asset_system = null
	GameState.characters.clear()
	GameState.assets_ships.clear()
	GameState.locations.clear()
	GameState.inventories.clear()
	GameState.player_character_uid = -1
	# Reset session_stats with defaults (TradingSystem expects these keys)
	GameState.session_stats = {
		"contracts_completed": 0,
		"total_wp_earned": 0,
		"total_wp_spent": 0,
		"enemies_disabled": 0,
		"time_played_tu": 0
	}
	
	if is_instance_valid(trading_system):
		trading_system.queue_free()
	if is_instance_valid(inventory_system):
		inventory_system.queue_free()
	if is_instance_valid(character_system):
		character_system.queue_free()
	if is_instance_valid(asset_system):
		asset_system.queue_free()


# --- Buy Tests ---

func test_can_buy_within_budget():
	# Player has 1000 credits, ore costs 10 each.
	var result = trading_system.can_buy(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 5)
	assert_true(result.success, "Should be able to buy 5 ore for 50 credits")


func test_can_buy_insufficient_funds():
	# Try to buy 40 ore at 10 each = 400 WP. Set character to only have 100 WP.
	GameState.characters[TEST_CHARACTER_UID].wealth_points = 100
	var result = trading_system.can_buy(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 40)
	assert_false(result.success, "Should not be able to afford 40 ore with only 100 WP")
	assert_true("Insufficient funds" in result.reason, "Reason should mention insufficient funds")


func test_can_buy_exceeds_stock():
	# Station only has 50 ore, try to buy 100.
	var result = trading_system.can_buy(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 100)
	assert_false(result.success, "Should not be able to buy more than station stock")
	assert_true("Insufficient stock" in result.reason, "Reason should mention insufficient stock")


func test_can_buy_exceeds_cargo():
	# Ship has 100 cargo space, each commodity is 1 unit.
	# Try to buy 150 ore.
	var result = trading_system.can_buy(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 150)
	# This should fail due to stock (only 50 available) first.
	assert_false(result.success, "Should fail validation")


func test_execute_buy_success():
	var initial_wp = GameState.characters[TEST_CHARACTER_UID].wealth_points
	var result = trading_system.execute_buy(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 5)
	
	assert_true(result.success, "Buy should succeed")
	
	# Check WP deducted.
	var expected_wp = initial_wp - (5 * 10) # 5 ore at 10 each.
	assert_eq(GameState.characters[TEST_CHARACTER_UID].wealth_points, expected_wp, "WP should be deducted")
	
	# Check commodity added to inventory.
	var cargo = inventory_system.get_inventory_by_type(TEST_CHARACTER_UID, inventory_system.InventoryType.COMMODITY)
	assert_has(cargo, "commodity_ore", "Ore should be in cargo")
	assert_eq(cargo["commodity_ore"], 5, "Should have 5 ore in cargo")
	
	# Check station stock reduced.
	var location = GameState.locations[TEST_LOCATION_ID]
	assert_eq(location.market_inventory["commodity_ore"].quantity, 45, "Station should have 45 ore left")


func test_execute_buy_fails_validation():
	# Try to buy with insufficient WP: 40 ore at 10 each = 400 WP, but set to only 100.
	GameState.characters[TEST_CHARACTER_UID].wealth_points = 100
	var result = trading_system.execute_buy(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 40)
	assert_false(result.success, "Buy should fail validation")
	assert_true("Insufficient funds" in result.reason, "Reason should mention insufficient funds")


# --- Sell Tests ---

func test_can_sell_owned_commodity():
	# Give player some ore to sell.
	inventory_system.add_asset(TEST_CHARACTER_UID, inventory_system.InventoryType.COMMODITY, "commodity_ore", 10)
	
	var result = trading_system.can_sell(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 5)
	assert_true(result.success, "Should be able to sell owned ore")


func test_can_sell_non_owned_commodity():
	# Player has no ore.
	var result = trading_system.can_sell(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 5)
	assert_false(result.success, "Should not be able to sell commodity not owned")
	assert_true("Insufficient cargo" in result.reason, "Reason should mention insufficient cargo")


func test_can_sell_more_than_owned():
	# Give player 3 ore, try to sell 10.
	inventory_system.add_asset(TEST_CHARACTER_UID, inventory_system.InventoryType.COMMODITY, "commodity_ore", 3)
	
	var result = trading_system.can_sell(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 10)
	assert_false(result.success, "Should not be able to sell more than owned")
	assert_true("Insufficient cargo" in result.reason, "Reason should mention insufficient cargo")


func test_execute_sell_success():
	# Give player ore.
	inventory_system.add_asset(TEST_CHARACTER_UID, inventory_system.InventoryType.COMMODITY, "commodity_ore", 10)
	var initial_wp = GameState.characters[TEST_CHARACTER_UID].wealth_points
	
	var result = trading_system.execute_sell(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 5)
	
	assert_true(result.success, "Sell should succeed")
	
	# Check WP added (sell price is 8 for ore).
	var expected_wp = initial_wp + (5 * 8)
	assert_eq(GameState.characters[TEST_CHARACTER_UID].wealth_points, expected_wp, "WP should be added")
	
	# Check commodity removed from inventory.
	var cargo = inventory_system.get_inventory_by_type(TEST_CHARACTER_UID, inventory_system.InventoryType.COMMODITY)
	assert_eq(cargo.get("commodity_ore", 0), 5, "Should have 5 ore left")
	
	# Check station stock increased.
	var location = GameState.locations[TEST_LOCATION_ID]
	assert_eq(location.market_inventory["commodity_ore"].quantity, 55, "Station should have 55 ore now")


func test_execute_sell_fails_validation():
	# Try to sell without owning.
	var result = trading_system.execute_sell(TEST_CHARACTER_UID, TEST_LOCATION_ID, "commodity_ore", 5)
	assert_false(result.success, "Sell should fail validation")


# --- Market Info Tests ---

func test_get_market_prices():
	var prices = trading_system.get_market_prices(TEST_LOCATION_ID)
	
	assert_has(prices, "commodity_ore", "Should have ore prices")
	assert_eq(prices["commodity_ore"].buy_price, 10, "Ore buy price should be 10")
	assert_eq(prices["commodity_ore"].sell_price, 8, "Ore sell price should be 8")


func test_get_market_prices_invalid_location():
	var prices = trading_system.get_market_prices("nonexistent_station")
	assert_eq(prices.size(), 0, "Should return empty dict for invalid location")


func test_get_cargo_info():
	inventory_system.add_asset(TEST_CHARACTER_UID, inventory_system.InventoryType.COMMODITY, "commodity_ore", 10)
	
	var info = trading_system.get_cargo_info(TEST_CHARACTER_UID)
	
	# get_cargo_info returns {has_space, available, capacity, used}
	assert_true(info.has("capacity"), "Should have capacity key")
	assert_true(info.has("used"), "Should have used key")
	assert_true(info.has("available"), "Should have available key")
	assert_eq(info.used, 10, "Should have 10 units used")

--- Start of ./src/tests/core/utils/test_pid_controller.gd ---

# tests/core/utils/test_pid_controller.gd
extends GutTest

var PIDController = load("res://src/core/utils/pid_controller.gd")
var pid


func before_each():
	pid = PIDController.new()


func after_each():
	if is_instance_valid(pid):
		pid.free()


func test_initialization():
	pid.initialize(1.5, 0.5, 0.75, 50.0, 100.0)
	assert_eq(pid.kp, 1.5, "P gain should be set correctly.")
	assert_eq(pid.ki, 0.5, "I gain should be set correctly.")
	assert_eq(pid.kd, 0.75, "D gain should be set correctly.")
	assert_eq(pid.integral_limit, 50.0, "Integral limit should be set correctly.")
	assert_eq(pid.output_limit, 100.0, "Output limit should be set correctly.")
	assert_eq(pid.integral, 0.0, "Integral should be reset to 0 on initialization.")
	assert_eq(pid.previous_error, 0.0, "Previous error should be reset to 0 on initialization.")


func test_proportional_term():
	pid.initialize(2.0, 0.0, 0.0, 100.0, 100.0)
	var output = pid.update(10.0, 1.0)
	assert_almost_eq(output, 20.0, 0.001, "Output should be kp * error.")


func test_integral_term():
	pid.initialize(0.0, 3.0, 0.0, 100.0, 100.0)
	var output1 = pid.update(5.0, 1.0)  # integral = 5
	assert_almost_eq(output1, 15.0, 0.001, "Output should be ki * integral (1st step).")
	var output2 = pid.update(5.0, 1.0)  # integral = 10
	assert_almost_eq(output2, 30.0, 0.001, "Output should be ki * integral (2nd step).")


func test_integral_limit_clamping():
	pid.initialize(0.0, 1.0, 0.0, 10.0, 100.0)
	pid.update(12.0, 1.0)  # integral would be 12, but clamped to 10
	assert_almost_eq(pid.integral, 10.0, 0.001, "Integral should be clamped to its positive limit.")
	assert_almost_eq(
		pid.update(1.0, 1.0), 10.0, 0.001, "Output should use the clamped integral value."
	)
	pid.reset()
	pid.update(-15.0, 1.0)  # integral would be -15, but clamped to -10
	assert_almost_eq(
		pid.integral, -10.0, 0.001, "Integral should be clamped to its negative limit."
	)


func test_derivative_term():
	pid.initialize(0.0, 0.0, 4.0, 100.0, 100.0)
	pid.update(5.0, 1.0)  # previous_error is now 5
	var output = pid.update(7.0, 1.0)  # derivative = (7 - 5) / 1 = 2
	assert_almost_eq(output, 8.0, 0.001, "Output should be kd * derivative.")


func test_output_limit_clamping():
	pid.initialize(10.0, 0.0, 0.0, 100.0, 50.0)
	var output = pid.update(10.0, 1.0)  # P term would be 100
	assert_almost_eq(output, 50.0, 0.001, "Output should be clamped to positive output_limit.")

	pid.initialize(-10.0, 0.0, 0.0, 100.0, 50.0)
	output = pid.update(10.0, 1.0)  # P term would be -100
	assert_almost_eq(output, -50.0, 0.001, "Output should be clamped to negative output_limit.")


func test_reset_function():
	pid.initialize(1.0, 1.0, 1.0, 100.0, 100.0)
	pid.update(10.0, 1.0)
	assert_ne(pid.integral, 0.0, "Integral should not be zero after an update.")
	assert_ne(pid.previous_error, 0.0, "Previous error should not be zero after an update.")

	pid.reset()
	assert_eq(pid.integral, 0.0, "Integral should be zero after reset.")
	assert_eq(pid.previous_error, 0.0, "Previous error should be zero after reset.")


func test_zero_delta_returns_zero():
	pid.initialize(1.0, 1.0, 1.0, 100.0, 100.0)
	var output = pid.update(10.0, 0.0)
	assert_eq(output, 0.0, "Update with delta <= 0 should return 0 to prevent division by zero.")

--- Start of ./src/tests/helpers/mock_agent_body.gd ---

# File: tests/helpers/mock_agent_body.gd
# A minimal agent body for the spawner to instantiate in tests.
# Version: 2.0 - Updated to match agent.gd's properties and initialize signature.

extends KinematicBody

# --- Core State & Identity (to match agent.gd) ---
var agent_type: String = ""
var template_id: String = ""
var agent_uid = -1

# --- Test-specific variable ---
# This will be populated when initialize is called, so tests can inspect it.
var init_data = null


# This signature now exactly matches the one in `core/agents/agent.gd`.
# We will spy on this method to confirm the spawner called it.
func initialize(template: AgentTemplate, overrides: Dictionary = {}, agent_uid: int = -1):
	# Store the received data so tests can assert it's correct.
	init_data = {
		"template": template,
		"overrides": overrides,
		"agent_uid": agent_uid
	}

	# Also set the properties just like the real agent.gd does.
	self.template_id = overrides.get("template_id")
	self.agent_type = overrides.get("agent_type")
	self.agent_uid = agent_uid

--- Start of ./src/tests/helpers/mock_event_bus.gd ---

# tests/helpers/mock_event_bus.gd
## Mock EventBus for unit testing - forwards emit_signal to actual signal emission.
extends Node

# Define the signals we want to be able to test for.
signal agent_reached_destination(agent_body)
signal agent_damaged(agent_body, damage_amount, source_agent)
signal agent_disabled(agent_body)
signal combat_initiated(player, hostiles)
signal combat_ended(result)
signal world_event_tick_triggered(tu_amount)


## Routes emit_signal calls to actual Godot signal emission for proper test signal tracking.
func emit_signal(signal_name: String, arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> void:
	match signal_name:
		"agent_reached_destination":
			.emit_signal(signal_name, arg1)
		"agent_damaged":
			.emit_signal(signal_name, arg1, arg2, arg3)
		"agent_disabled":
			.emit_signal(signal_name, arg1)
		"combat_initiated":
			.emit_signal(signal_name, arg1, arg2)
		"combat_ended":
			.emit_signal(signal_name, arg1)
		"world_event_tick_triggered":
			.emit_signal(signal_name, arg1)
		_:
			printerr("MockEventBus: Unknown signal '%s'" % signal_name)

--- Start of ./src/tests/helpers/mock_ship_template.gd ---

# mock_ship_template.gd
# Test helper that mimics ShipTemplate properties without extending Resource
extends Resource

var hull_integrity: int = 100
var armor_integrity: int = 50


func _init(hull: int = 100, armor: int = 50):
	hull_integrity = hull
	armor_integrity = armor
	
	# Check for meta overrides (used by tests)
	if has_meta("hull_integrity"):
		hull_integrity = get_meta("hull_integrity")
	if has_meta("armor_integrity"):
		armor_integrity = get_meta("armor_integrity")

--- Start of ./src/tests/helpers/signal_catcher.gd ---

# File: tests/helpers/signal_catcher.gd
# Helper script for catching signals in GUT tests
# Version 1.2 - Reliably captures first few args, including nulls

extends Node

var _last_signal_args = null  # Store arguments from the last signal received


# Generic handler function. Connect signals expecting up to 5 args here.
# It captures the arguments as passed by Godot's signal system.
func _on_signal_received(p1 = null, p2 = null, p3 = null, p4 = null, p5 = null):
	# Store the arguments directly in an array.
	# The test script is responsible for knowing how many args were
	# actually emitted by a specific signal and checking only those.
	_last_signal_args = [p1, p2, p3, p4, p5]
	# print("Signal Catcher raw args captured: ", _last_signal_args) # For debugging


# Call this in test to get the captured arguments
func get_last_args():
	# Returns the array [p1, p2, p3, p4, p5] as captured
	return _last_signal_args


# Call this in test setup (e.g., before_each) to clear state
func reset():
	_last_signal_args = null

--- Start of ./src/tests/helpers/test_agent_body.gd ---

# tests/helpers/test_agent_body.gd
# A simple KinematicBody for use in tests that require an agent.
extends KinematicBody

var current_velocity = Vector3.ZERO


# The NavigationSystem's approach/orbit commands use this.
func get_interaction_radius():
	return 10.0

--- Start of ./src/tests/modules/piloting/test_ship_controller_ai.gd ---

# File: tests/modules/piloting/test_ship_controller_ai.gd
# Unit tests for ShipControllerAI (Sprint 9)

extends "res://addons/gut/test.gd"

const ShipControllerAI = preload("res://src/modules/piloting/ship_controller_ai.gd")

class DummyAgentBody:
	extends KinematicBody
	var agent_uid: int = 1
	var last_command: Dictionary = {}

	func command_stop():
		last_command = {"name": "stop"}

	func command_move_to(pos: Vector3):
		last_command = {"name": "move_to", "pos": pos}

	func command_approach(target: Spatial):
		last_command = {"name": "approach", "target": target}

	func command_flee(target: Spatial):
		last_command = {"name": "flee", "target": target}

	func despawn():
		last_command = {"name": "despawn"}


class DummyCombatSystem:
	extends Node
	var hull_percent_by_uid := {}
	var in_combat_by_uid := {}

	func is_in_combat(uid: int) -> bool:
		return bool(in_combat_by_uid.get(uid, false))

	func get_hull_percent(uid: int) -> float:
		return float(hull_percent_by_uid.get(uid, 1.0))


var _agent: DummyAgentBody
var _player: DummyAgentBody
var _ai: Node
var _combat: DummyCombatSystem


func before_each():
	_agent = DummyAgentBody.new()
	_agent.translation = Vector3.ZERO
	add_child_autofree(_agent)

	_ai = ShipControllerAI.new()
	_agent.add_child(_ai)
	_ai._ready()  # ensure parent references are cached

	_player = DummyAgentBody.new()
	_player.agent_uid = 999
	_player.translation = Vector3(10, 0, 0)
	add_child_autofree(_player)
	GlobalRefs.player_agent_body = _player

	_combat = DummyCombatSystem.new()
	add_child_autofree(_combat)
	GlobalRefs.combat_system = _combat


func after_each():
	GlobalRefs.player_agent_body = null
	GlobalRefs.combat_system = null
	_agent = null
	_player = null
	_ai = null
	_combat = null


func test_initial_state_is_idle():
	assert_eq(_ai._current_state, ShipControllerAI.AIState.IDLE)


func test_initialize_hostile_transitions_to_patrol():
	_ai.initialize({"hostile": true})
	assert_eq(_ai._current_state, ShipControllerAI.AIState.PATROL)


func test_scan_for_target_returns_player_when_in_range():
	_ai.is_hostile = true
	_ai.aggro_range = 50.0
	var found = _ai._scan_for_target()
	assert_true(is_instance_valid(found))
	assert_eq(found, _player)


func test_combat_transitions_to_flee_when_hull_critical():
	_ai.is_hostile = true
	_ai._target_agent = _player
	_ai._current_state = ShipControllerAI.AIState.COMBAT

	_combat.in_combat_by_uid[_agent.agent_uid] = true
	_combat.hull_percent_by_uid[_agent.agent_uid] = 0.1

	_ai._process_combat(0.1)
	assert_eq(_ai._current_state, ShipControllerAI.AIState.FLEE)
	assert_eq(_agent.last_command.get("name"), "flee")

--- Start of ./src/tests/scenes/game_world/world_manager/test_template_indexer.gd ---

# File: tests/scenes/game_world/world_manager/test_template_indexer.gd
# GUT Test Script for the TemplateIndexer component.
# Version: 1.0

extends GutTest

const TemplateIndexer = preload("res://src/scenes/game_world/world_manager/template_indexer.gd")
var indexer_instance = null

func before_each():
	# Ensure a clean slate before each test by clearing the database.
	TemplateDatabase.characters.clear()
	TemplateDatabase.assets_ships.clear()
	# ... clear other template dictionaries as they are added ...

	indexer_instance = TemplateIndexer.new()
	add_child_autofree(indexer_instance)

func test_indexing_populates_template_database():
	# Pre-check: Ensure the database is empty before the test.
	assert_eq(TemplateDatabase.characters.size(), 0, "Character templates should be empty initially.")
	assert_eq(TemplateDatabase.assets_ships.size(), 0, "Ship templates should be empty initially.")

	# Run the indexing process.
	indexer_instance.index_all_templates()

	# Post-check: Assert that the database now contains data.
	assert_gt(TemplateDatabase.characters.size(), 0, "Character templates should be populated after indexing.")
	assert_gt(TemplateDatabase.assets_ships.size(), 0, "Ship templates should be populated after indexing.")

func test_indexing_loads_known_templates_correctly():
	# Run the indexing process.
	indexer_instance.index_all_templates()

	# Check for a specific, known character template.
	var default_char_id = "character_default"
	assert_has(TemplateDatabase.characters, default_char_id, "Database should contain 'character_default'.")
	var char_template = TemplateDatabase.characters[default_char_id]
	assert_true(is_instance_valid(char_template), "'character_default' should be a valid instance.")
	assert_true(char_template is CharacterTemplate, "'character_default' should be of type CharacterTemplate.")

	# Check for a specific, known ship template.
	var default_ship_id = "ship_default"
	assert_has(TemplateDatabase.assets_ships, default_ship_id, "Database should contain 'ship_default'.")
	var ship_template = TemplateDatabase.assets_ships[default_ship_id]
	assert_true(is_instance_valid(ship_template), "'ship_default' should be a valid instance.")
	assert_true(ship_template is ShipTemplate, "'ship_default' should be of type ShipTemplate.")

--- Start of ./src/tests/scenes/game_world/world_manager/test_world_generator.gd ---

# File: tests/scenes/game_world/world_manager/test_world_generator.gd
# GUT Test Script for the WorldGenerator component.
# Version: 2.0 - Corrected to handle system dependencies properly.

extends GutTest

const TemplateIndexer = preload("res://src/scenes/game_world/world_manager/template_indexer.gd")
const WorldGenerator = preload("res://src/scenes/game_world/world_manager/world_generator.gd")
const InventorySystem = preload("res://src/core/systems/inventory_system.gd")

var indexer_instance = null
var generator_instance = null
var inventory_system_instance = null # We need an instance for the generator to use

func before_each():
	# 1. Index templates first, as this is a dependency.
	indexer_instance = TemplateIndexer.new()
	add_child_autofree(indexer_instance)
	indexer_instance.index_all_templates()

	# 2. Instantiate the InventorySystem and set it in GlobalRefs.
	# The WorldGenerator depends on this being valid.
	inventory_system_instance = InventorySystem.new()
	add_child_autofree(inventory_system_instance)
	GlobalRefs.inventory_system = inventory_system_instance

	# 3. Now, instantiate the WorldGenerator we are testing.
	generator_instance = WorldGenerator.new()
	add_child_autofree(generator_instance)

	# 4. Ensure a clean GameState for every test.
	GameState.characters.clear()
	GameState.inventories.clear()
	GameState.assets_ships.clear()
	GameState.assets_modules.clear()
	GameState.player_character_uid = -1

func after_each():
	# Clean up the global reference to prevent test bleed.
	GlobalRefs.inventory_system = null

func test_generates_characters_and_inventories():
	assert_eq(GameState.characters.size(), 0, "Characters should be empty before generation.")
	assert_eq(GameState.inventories.size(), 0, "Inventories should be empty before generation.")

	generator_instance.generate_new_world()

	assert_gt(GameState.characters.size(), 0, "Characters should be populated after generation.")
	assert_eq(GameState.inventories.size(), GameState.characters.size(), "Should create one inventory per character.")

func test_assigns_player_character_uid():
	assert_eq(GameState.player_character_uid, -1, "Player UID should be -1 before generation.")

	generator_instance.generate_new_world()

	assert_ne(GameState.player_character_uid, -1, "A valid player UID should be set.")
	assert_has(GameState.characters, GameState.player_character_uid, "The player UID must be a valid key.")

func test_generated_characters_have_assets():
	generator_instance.generate_new_world()
	
	var player_uid = GameState.player_character_uid
	var player_char = GameState.characters[player_uid]

	# Check for active ship assignment
	assert_ne(player_char.active_ship_uid, -1, "Player should have an active ship UID assigned.")
	assert_has(GameState.assets_ships, player_char.active_ship_uid, "The active ship should exist in the master asset list.")

	# Check inventory contents using the system
	var ship_count = inventory_system_instance.get_asset_count(player_uid, inventory_system_instance.InventoryType.SHIP, player_char.active_ship_uid)
	assert_eq(ship_count, 1, "Player inventory should contain 1 ship.")
	
	var module_inventory = inventory_system_instance.get_inventory_by_type(player_uid, inventory_system_instance.InventoryType.MODULE)
	assert_eq(module_inventory.size(), 1, "Player inventory should contain 1 module.")
	
	# Sprint 10: Player starts with empty commodity cargo
	var ore_count = inventory_system_instance.get_asset_count(player_uid, inventory_system_instance.InventoryType.COMMODITY, "commodity_ore")
	assert_eq(ore_count, 0, "Player inventory should contain 0 units of ore at game start.")
	
	var fuel_count = inventory_system_instance.get_asset_count(player_uid, inventory_system_instance.InventoryType.COMMODITY, "commodity_fuel")
	assert_eq(fuel_count, 0, "Player inventory should contain 0 units of fuel at game start.")

--- Start of ./src/tests/scenes/test_basic_flight_zone_docking.gd ---

extends "res://addons/gut/test.gd"

var ZoneScene = load("res://scenes/levels/zones/zone1/basic_flight_zone.tscn")
var PlayerAgentScene = load("res://src/core/agents/player_agent.tscn")

func test_station_exists_in_zone():
	var zone = ZoneScene.instance()
	add_child(zone)
	
	var system_1 = zone.get_node("SceneAssets/System_1")
	assert_not_null(system_1, "System_1 should exist")
	
	var station = system_1.get_node("Station_Alpha")
	assert_not_null(station, "Station_Alpha should exist under System_1")
	assert_eq(station.location_id, "station_alpha")
	
	zone.free()

func test_docking_in_zone():
	var zone = ZoneScene.instance()
	add_child(zone)
	
	var station = zone.get_node("SceneAssets/System_1/Station_Alpha")
	
	# Create a player mock
	var player = KinematicBody.new()
	player.name = "PlayerMock"
	var script = GDScript.new()
	script.source_code = "extends KinematicBody\nfunc is_player(): return true"
	script.reload()
	player.set_script(script)
	
	# Add player to zone
	zone.add_child(player)
	
	# Move player to station position (global)
	player.global_transform.origin = station.global_transform.origin
	
	# Force physics update or manually call signal
	# Since we are in a test, we can manually trigger the area overlap if we don't want to wait for physics
	# But let's try to use the area's monitoring
	
	watch_signals(EventBus)
	
	# Manually trigger for reliability in unit test without physics engine running full cycle
	station._on_body_entered(player)
	
	assert_signal_emitted_with_parameters(EventBus, "dock_available", ["station_alpha"])
	
	station._on_body_exited(player)
	assert_signal_emitted(EventBus, "dock_unavailable")
	
	zone.free()

--- Start of ./src/tests/scenes/test_docking_integration.gd ---

extends "res://addons/gut/test.gd"

var ZoneScene = load("res://scenes/levels/zones/zone1/basic_flight_zone.tscn")
var StationMenuScene = load("res://scenes/ui/menus/station_menu/StationMenu.tscn")
var PlayerControllerScript = load("res://src/modules/piloting/player_controller_ship.gd")
var ContractSystemScript = load("res://src/core/systems/contract_system.gd")
var InventorySystemScript = load("res://src/core/systems/inventory_system.gd")

func test_full_docking_loop():
	# Clear GameState to ensure clean slate
	GameState.active_contracts.clear()
	GameState.contracts.clear()
	GameState.locations.clear()
	
	# 1. Setup World
	var zone = ZoneScene.instance()
	add_child(zone)
	
	# Setup Systems
	var contract_system = ContractSystemScript.new()
	add_child(contract_system)
	GlobalRefs.contract_system = contract_system
	
	var inventory_system = InventorySystemScript.new()
	add_child(inventory_system)
	GlobalRefs.inventory_system = inventory_system
	
	# Ensure GameState has the station location loaded (WorldGenerator usually does this)
	if not GameState.locations.has("station_alpha"):
		var loc_template = LocationTemplate.new()
		loc_template.template_id = "station_alpha"
		loc_template.location_name = "Station Alpha"
		loc_template.market_inventory = {"commodity_ore": {"price": 10, "quantity": 100}}
		GameState.locations["station_alpha"] = loc_template
		
	# Ensure GameState has contracts loaded
	if not GameState.contracts.has("delivery_01"):
		var contract = ContractTemplate.new()
		contract.template_id = "delivery_01"
		contract.title = "Test Contract"
		contract.origin_location_id = "station_alpha"
		contract.destination_location_id = "station_beta"
		contract.contract_type = "delivery"
		contract.required_commodity_id = "commodity_ore"
		contract.required_quantity = 10
		contract.reward_wp = 100
		contract.time_limit_tu = -1
		GameState.contracts["delivery_01"] = contract
	
	# Also add station_beta location for delivery destination
	if not GameState.locations.has("station_beta"):
		var loc_beta = LocationTemplate.new()
		loc_beta.template_id = "station_beta"
		loc_beta.location_name = "Station Beta"
		GameState.locations["station_beta"] = loc_beta
	
	# 2. Setup Player & HUD
	var hud = load("res://scenes/ui/hud/main_hud.tscn").instance()
	add_child(hud)
	
	# 3. Simulate Docking Signal
	EventBus.emit_signal("dock_available", "station_alpha")
	yield(yield_for(0.1), YIELD)
	
	# Verify Prompt
	assert_true(hud.docking_prompt.visible, "Docking prompt should be visible")
	
	# 4. Simulate Interact Press
	EventBus.emit_signal("player_interact_pressed")
	# The controller usually emits player_docked, but here we simulate the signal chain
	EventBus.emit_signal("player_docked", "station_alpha")
	yield(yield_for(0.1), YIELD)
	
	# Verify Station Menu Open
	var station_menu = hud.station_menu_instance
	assert_true(station_menu.visible, "Station Menu should be visible")
	assert_eq(station_menu.current_location_id, "station_alpha")
	
	# 5. Test Trade Interface
	station_menu._on_trade_pressed()
	yield(yield_for(0.1), YIELD)
	assert_true(station_menu.trade_interface_instance.visible, "Trade Interface should be visible")
	station_menu.trade_interface_instance._on_close_pressed()
	
	# 6. Test Contract Interface
	station_menu._on_contracts_pressed()
	yield(yield_for(0.1), YIELD)
	var contract_ui = station_menu.contract_interface_instance
	assert_true(contract_ui.visible, "Contract Interface should be visible")
	
	# Verify contract list population
	assert_gt(contract_ui.list_contracts.get_item_count(), 0, "Should list at least one contract")
	
	# Select and Accept - save contract_id BEFORE accepting (refresh clears the list)
	contract_ui._on_contract_selected(0)
	var contract_id = contract_ui.list_contracts.get_item_metadata(0)
	contract_ui._on_accept_pressed()
	
	# Verify Contract Accepted in GameState
	if not GameState.active_contracts.has(contract_id):
		gut.p("Active Contracts: " + str(GameState.active_contracts.keys()))
		gut.p("Expected contract_id: " + contract_id)
		
	assert_true(GameState.active_contracts.has(contract_id), "Contract should be in active_contracts")
	
	contract_ui._on_close_pressed()
	
	# 7. Undock
	station_menu._on_undock_pressed()
	yield(yield_for(0.1), YIELD)
	assert_false(station_menu.visible, "Station Menu should be hidden after undock")
	
	# 8. Simulate Travel & Completion
	# Add required cargo
	var inv_sys = GlobalRefs.inventory_system
	inv_sys.add_asset(GameState.player_character_uid, inv_sys.InventoryType.COMMODITY, "commodity_ore", 10)
	
	# Dock at destination
	# We need to update GameState.player_docked_at manually as the signal usually does it via PlayerController
	GameState.player_docked_at = "station_beta"
	EventBus.emit_signal("player_docked", "station_beta")
	yield(yield_for(0.1), YIELD)
	
	# Verify Complete Button
	assert_true(station_menu.visible, "Station Menu should be visible at dest")
	assert_true(station_menu.btn_complete_contract.visible, "Complete Contract button should be visible")
	
	# Complete
	station_menu._on_complete_contract_pressed()
	
	# Verify
	assert_false(GameState.active_contracts.has(contract_id), "Contract should be removed from active")
	
	# Cleanup
	GlobalRefs.contract_system = null
	GlobalRefs.inventory_system = null
	contract_system.free()
	inventory_system.free()
	zone.free()
	hud.free()

--- Start of ./src/tests/scenes/test_full_game_loop.gd ---

# File: tests/scenes/test_full_game_loop.gd
# Purpose: GUT integration test for the Phase 1 player journey.
# Version: 1.0

extends "res://addons/gut/test.gd"

const MainHUDScene = preload("res://scenes/ui/hud/main_hud.tscn")
const ContractSystemScript = preload("res://src/core/systems/contract_system.gd")
const TradingSystemScript = preload("res://src/core/systems/trading_system.gd")
const InventorySystemScript = preload("res://src/core/systems/inventory_system.gd")
const CharacterSystemScript = preload("res://src/core/systems/character_system.gd")
const AssetSystemScript = preload("res://src/core/systems/asset_system.gd")

const PLAYER_UID := 0
const PLAYER_SHIP_UID := 1
const LOCATION_ALPHA := "station_alpha"
const LOCATION_BETA := "station_beta"
const CONTRACT_ID := "delivery_01"

var _hud = null
var _contract_system = null
var _trading_system = null
var _inventory_system = null
var _character_system = null
var _asset_system = null


func before_each():
	_reset_game_state()
	_setup_systems()
	_setup_world_data()
	_setup_player()
	_setup_hud()


func after_each():
	if is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null

	if is_instance_valid(_contract_system):
		_contract_system.queue_free()
	if is_instance_valid(_trading_system):
		_trading_system.queue_free()
	if is_instance_valid(_inventory_system):
		_inventory_system.queue_free()
	if is_instance_valid(_character_system):
		_character_system.queue_free()
	if is_instance_valid(_asset_system):
		_asset_system.queue_free()

	_contract_system = null
	_trading_system = null
	_inventory_system = null
	_character_system = null
	_asset_system = null

	GlobalRefs.contract_system = null
	GlobalRefs.trading_system = null
	GlobalRefs.inventory_system = null
	GlobalRefs.character_system = null
	GlobalRefs.asset_system = null

	_reset_game_state()


func test_full_game_loop_delivery_trade_and_complete():
	# Start docked at Station Alpha.
	GameState.player_docked_at = LOCATION_ALPHA
	EventBus.emit_signal("player_docked", LOCATION_ALPHA)
	yield(yield_for(0.05), YIELD)

	var station_menu = _hud.station_menu_instance
	assert_true(is_instance_valid(station_menu), "Station menu should exist under HUD")
	assert_true(station_menu.visible, "Station menu should be visible when docked")
	assert_eq(station_menu.current_location_id, LOCATION_ALPHA)

	# Sprint 10: Player starts with empty cargo.
	assert_eq(
		_inventory_system.get_asset_count(PLAYER_UID, _inventory_system.InventoryType.COMMODITY, "commodity_ore"),
		0,
		"Player should start with 0 ore"
	)

	# Accept a delivery contract at Station Alpha.
	var accept_result = _contract_system.accept_contract(PLAYER_UID, CONTRACT_ID)
	assert_true(accept_result.success, "Contract acceptance should succeed")
	assert_true(GameState.active_contracts.has(CONTRACT_ID), "Contract should be active")

	# Trade: buy required cargo at Station Alpha.
	var buy_qty := 10
	var buy_result = _trading_system.execute_buy(PLAYER_UID, LOCATION_ALPHA, "commodity_ore", buy_qty)
	assert_true(buy_result.success, "Buying ore should succeed")
	assert_eq(
		_inventory_system.get_asset_count(PLAYER_UID, _inventory_system.InventoryType.COMMODITY, "commodity_ore"),
		buy_qty,
		"Cargo should contain the purchased ore"
	)
	assert_eq(
		GameState.locations[LOCATION_ALPHA].market_inventory["commodity_ore"].quantity,
		90,
		"Market inventory should decrement"
	)

	# Undock.
	EventBus.emit_signal("player_undocked")
	yield(yield_for(0.05), YIELD)
	assert_false(station_menu.visible, "Station menu should hide on undock")

	# Dock at destination.
	GameState.player_docked_at = LOCATION_BETA
	EventBus.emit_signal("player_docked", LOCATION_BETA)
	yield(yield_for(0.05), YIELD)
	assert_true(station_menu.visible, "Station menu should be visible at destination")
	assert_eq(station_menu.current_location_id, LOCATION_BETA)
	assert_true(station_menu.btn_complete_contract.visible, "Complete Contract button should be visible")

	# Complete contract via station menu (falls back to direct completion if narrative system missing).
	var wp_before: int = int(_character_system.get_wp(PLAYER_UID))
	station_menu._on_complete_contract_pressed()
	yield(yield_for(0.05), YIELD)

	assert_false(GameState.active_contracts.has(CONTRACT_ID), "Contract should be removed from active")
	assert_eq(
		_inventory_system.get_asset_count(PLAYER_UID, _inventory_system.InventoryType.COMMODITY, "commodity_ore"),
		0,
		"Contract completion should remove delivery cargo"
	)
	assert_eq(
		_character_system.get_wp(PLAYER_UID),
		wp_before + 100,
		"Contract completion should reward WP"
	)


# ---- Helpers ----

func _reset_game_state() -> void:
	GameState.characters.clear()
	GameState.inventories.clear()
	GameState.assets_ships.clear()
	GameState.assets_modules.clear()
	GameState.locations.clear()
	GameState.contracts.clear()
	GameState.active_contracts.clear()
	GameState.current_tu = 0
	GameState.player_character_uid = PLAYER_UID
	GameState.player_docked_at = ""
	GameState.narrative_state = {
		"reputation": 0,
		"faction_standings": {},
		"known_contacts": [],
		"chronicle_entries": []
	}
	GameState.session_stats = {
		"contracts_completed": 0,
		"total_wp_earned": 0,
		"total_wp_spent": 0,
		"enemies_disabled": 0,
		"time_played_tu": 0
	}


func _setup_systems() -> void:
	_contract_system = ContractSystemScript.new()
	add_child(_contract_system)
	GlobalRefs.contract_system = _contract_system

	_trading_system = TradingSystemScript.new()
	add_child(_trading_system)
	GlobalRefs.trading_system = _trading_system

	_inventory_system = InventorySystemScript.new()
	add_child(_inventory_system)
	GlobalRefs.inventory_system = _inventory_system

	_character_system = Node.new()
	_character_system.set_script(CharacterSystemScript)
	add_child(_character_system)
	GlobalRefs.character_system = _character_system

	_asset_system = Node.new()
	_asset_system.set_script(AssetSystemScript)
	add_child(_asset_system)
	GlobalRefs.asset_system = _asset_system


func _setup_world_data() -> void:
	# Locations
	var loc_alpha = LocationTemplate.new()
	loc_alpha.template_id = LOCATION_ALPHA
	loc_alpha.location_name = "Station Alpha"
	loc_alpha.market_inventory = {
		"commodity_ore": {"quantity": 100, "buy_price": 10, "sell_price": 8}
	}
	GameState.locations[LOCATION_ALPHA] = loc_alpha

	var loc_beta = LocationTemplate.new()
	loc_beta.template_id = LOCATION_BETA
	loc_beta.location_name = "Station Beta"
	GameState.locations[LOCATION_BETA] = loc_beta

	# Contract
	var contract = ContractTemplate.new()
	contract.template_id = CONTRACT_ID
	contract.contract_type = "delivery"
	contract.title = "Deliver Ore"
	contract.origin_location_id = LOCATION_ALPHA
	contract.destination_location_id = LOCATION_BETA
	contract.required_commodity_id = "commodity_ore"
	contract.required_quantity = 10
	contract.reward_wp = 100
	contract.reward_reputation = 0
	contract.reward_items = {}
	contract.time_limit_tu = -1
	GameState.contracts[CONTRACT_ID] = contract


func _setup_player() -> void:
	var player = CharacterTemplate.new()
	player.template_id = "player_test"
	player.character_name = "Player"
	player.wealth_points = 1000
	player.focus_points = 3
	player.active_ship_uid = PLAYER_SHIP_UID
	GameState.characters[PLAYER_UID] = player

	var ship = ShipTemplate.new()
	ship.template_id = "ship_test"
	ship.ship_model_name = "Test Ship"
	ship.cargo_capacity = 100
	GameState.assets_ships[PLAYER_SHIP_UID] = ship

	_inventory_system.create_inventory_for_character(PLAYER_UID)
	_inventory_system.add_asset(PLAYER_UID, _inventory_system.InventoryType.SHIP, PLAYER_SHIP_UID, 1)


func _setup_hud() -> void:
	_hud = MainHUDScene.instance()
	add_child(_hud)
