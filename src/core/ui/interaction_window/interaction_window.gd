# InteractionWindow (scenes/ui/menus/interaction_window.tscn): what the player may ask of the
# selected ship (Interactions), opened by the HUD's INTERACT button. One button per interaction that
# applies to that ship now or is going with it, tapped to start it (ON, highlighted as an active HUD
# button is) or to end it (OFF); a line under each says what it means. A ship offering nothing says
# why. A second tab, PILOT, lists what is public of the ship's pilot (PilotLevel.public_record: call
# sign, side, level, ship, bounties...). It opens on ASK, or on PILOT when there is nothing to ask.
# Open, it pauses the game, as the options window does; closing puts the pause back as it was. As
# every window that pauses the game, it fills the screen.

extends Control

const TabLook = preload("res://src/core/ui/helpers/tab_look.gd")

const Interactions = preload("res://src/core/systems/interactions.gd")
const TargetKinds = preload("res://src/core/ui/main_hud/target_kinds.gd")
const PilotLevel = preload("res://src/core/systems/pilot_level.gd")
const NOTE_ASK = "THE GAME IS PAUSED WHILE THIS IS OPEN. TAP AN OPTION TO ASK IT, AGAIN TO END IT."
const NOTE_PILOT = "THE GAME IS PAUSED WHILE THIS IS OPEN. WHAT ANYONE MAY KNOW OF THIS PILOT."

var target = null  # The ship asked
var _was_paused: bool = false
var tab: String = "ask"  # "ask" or "pilot"

onready var _title: Label = $Center/Panel/Overflow/Layout/Header/Title
onready var _side: Label = $Center/Panel/Overflow/Layout/Side
onready var _options: VBoxContainer = $Center/Panel/Overflow/Layout/Options
onready var _option_pattern: Button = $Center/Panel/Overflow/Layout/Options/Option
onready var _note_pattern: Label = $Center/Panel/Overflow/Layout/Options/OptionNote
onready var _ask_button: Button = $Center/Panel/Overflow/Layout/Tabs/ButtonAsk
onready var _pilot_button: Button = $Center/Panel/Overflow/Layout/Tabs/ButtonPilot
onready var _pilot: GridContainer = $Center/Panel/Overflow/Layout/Pilot
onready var _key_pattern: Label = $Center/Panel/Overflow/Layout/Pilot/Key
onready var _value_pattern: Label = $Center/Panel/Overflow/Layout/Pilot/Value
onready var _note: Label = $Center/Panel/Overflow/Layout/Note


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	$Center/Panel/Overflow/Layout/Header/ButtonClose.connect("pressed", self, "close")
	_ask_button.connect("pressed", self, "show_tab", ["ask"])
	_pilot_button.connect("pressed", self, "show_tab", ["pilot"])


func open(ship) -> void:
	target = ship
	if not visible:
		_was_paused = get_tree().paused
		get_tree().paused = true
		visible = true
	var asks: bool = Interactions.is_npc_ship(ship) and not Interactions.options(GlobalRefs.player_agent_body, ship).empty()
	show_tab("ask" if asks or not Interactions.is_npc_ship(ship) else "pilot")


func show_tab(which: String) -> void:
	tab = which
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	target = null
	get_tree().paused = _was_paused


func refresh() -> void:
	for child in _options.get_children():
		if child != _option_pattern and child != _note_pattern:
			_options.remove_child(child)
			child.queue_free()
	for child in _pilot.get_children():
		if child != _key_pattern and child != _value_pattern:
			_pilot.remove_child(child)
			child.queue_free()
	var player = GlobalRefs.player_agent_body
	TabLook.show(_ask_button, Strings.t("interact.tab.ask"), tab == "ask")
	TabLook.show(_pilot_button, Strings.t("interact.tab.pilot"), tab == "pilot")
	_options.visible = tab == "ask"
	_pilot.visible = tab == "pilot"
	_note.text = Strings.t("interact.note.pilot") if tab == "pilot" else Strings.t("interact.note.ask")
	if not Interactions.is_npc_ship(target):
		_title.text = Strings.t("hud.button.interact")
		_side.text = Strings.t("interact.no_ship")
		return
	_title.text = Interactions.name_of(target).to_upper()
	var side: String = TargetKinds.side_of(target, player)
	var activity: String = ""
	var ai = Interactions.ai_of(target)
	if ai != null and ai.has_method("get_activity_label"):
		activity = Strings.word(ai.get_activity_label())
	_side.text = Strings.word(side).to_upper() + ((" · " + activity) if activity != "" else "")
	_side.add_color_override("font_color", TargetKinds.side_color(side))
	if tab == "pilot":
		_fill_pilot(player)
		return
	var options: Array = Interactions.options(player, target)
	for option in options:
		var button: Button = _option_pattern.duplicate()
		button.name = "Option_%s" % option.kind
		button.text = "%s: %s" % [option.label, Strings.t("hud.on") if option.active else Strings.t("hud.off")]
		button.modulate = Constants.UI_SWITCH_ON_MODULATE if option.active else Constants.UI_SWITCH_OFF_MODULATE
		button.visible = true
		button.connect("pressed", self, "_on_option_pressed", [option.kind])
		_options.add_child(button)
		var note: Label = _note_pattern.duplicate()
		note.name = "Note_%s" % option.kind
		note.text = str(option.note).to_upper()
		note.visible = true
		_options.add_child(note)
	if options.empty():
		var note: Label = _note_pattern.duplicate()
		note.name = "Note_none"
		note.text = Strings.t("interact.nothing", [_why_nothing(player)]).to_upper()
		note.visible = true
		_options.add_child(note)


# The PILOT tab: one row per public fact, its name dim on the left.
func _fill_pilot(player) -> void:
	for row in PilotLevel.public_record(player, target):
		var key: Label = _key_pattern.duplicate()
		key.name = "Key_%s" % str(row[0]).replace(" ", "_")
		key.text = Strings.word(str(row[0]))  # The rows' captions and fixed words are English (their nodes' names)
		key.visible = true
		_pilot.add_child(key)
		var value: Label = _value_pattern.duplicate()
		value.name = "Value_%s" % str(row[0]).replace(" ", "_")
		value.text = Strings.word(str(row[1]))
		value.visible = true
		_pilot.add_child(value)


# The reasons the interactions give for not applying (hostile, not allied...), each once.
func _why_nothing(player) -> String:
	var reasons: Array = []
	for kind in Interactions.KINDS:
		var why: String = Interactions.why_not(player, target, kind)
		if why != "" and not why in reasons:
			reasons.append(why)
	return PoolStringArray(reasons).join("; ")


func _on_option_pressed(kind: String) -> void:
	var was: bool = Interactions.is_active(GlobalRefs.player_agent_body, target, kind)
	var line: String = Interactions.toggle(GlobalRefs.player_agent_body, target, kind)
	if Interactions.is_active(GlobalRefs.player_agent_body, target, kind) == was and line != "":
		EventBus.emit_signal("attack_action_feedback", false, line)  # Refused: why (the button shows the rest)
	refresh()
