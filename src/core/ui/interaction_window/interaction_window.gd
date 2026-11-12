# InteractionWindow (scenes/ui/menus/interaction_window.tscn): what the player may ask of the
# selected ship (Interactions), opened by the HUD's INTERACT button. One button per interaction that
# applies to that ship now or is going with it, tapped to start it (ON, highlighted as an active HUD
# button is) or to end it (OFF); a line under each says what it means. A ship offering nothing says
# why. Open, it pauses the game, as the options window does; closing puts the pause back as it was.

extends Control

const Interactions = preload("res://src/core/systems/interactions.gd")
const TargetKinds = preload("res://src/core/ui/main_hud/target_kinds.gd")
const ACTIVE_MODULATE = Color8(255, 230, 89, 255)  # As MainHUD.BUTTON_ACTIVE_MODULATE

var target = null  # The ship asked
var _was_paused: bool = false

onready var _title: Label = $Center/Panel/Layout/Header/Title
onready var _side: Label = $Center/Panel/Layout/Side
onready var _options: VBoxContainer = $Center/Panel/Layout/Options
onready var _option_pattern: Button = $Center/Panel/Layout/Options/Option
onready var _note_pattern: Label = $Center/Panel/Layout/Options/OptionNote


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	$Center/Panel/Layout/Header/ButtonClose.connect("pressed", self, "close")


func open(ship) -> void:
	target = ship
	if not visible:
		_was_paused = get_tree().paused
		get_tree().paused = true
		visible = true
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
	var player = GlobalRefs.player_agent_body
	if not Interactions.is_npc_ship(target):
		_title.text = "INTERACT"
		_side.text = "NO SHIP SELECTED"
		return
	_title.text = Interactions.name_of(target).to_upper()
	var side: String = TargetKinds.side_of(target, player)
	var activity: String = ""
	var ai = Interactions.ai_of(target)
	if ai != null and ai.has_method("get_activity_label"):
		activity = ai.get_activity_label()
	_side.text = side.to_upper() + ((" · " + activity) if activity != "" else "")
	_side.add_color_override("font_color", TargetKinds.side_color(side))
	var options: Array = Interactions.options(player, target)
	for option in options:
		var button: Button = _option_pattern.duplicate()
		button.name = "Option_%s" % option.kind
		button.text = "%s: %s" % [option.label, "ON" if option.active else "OFF"]
		button.modulate = ACTIVE_MODULATE if option.active else Color.white
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
		note.text = ("NOTHING TO ASK OF IT: %s" % _why_nothing(player)).to_upper()
		note.visible = true
		_options.add_child(note)


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
