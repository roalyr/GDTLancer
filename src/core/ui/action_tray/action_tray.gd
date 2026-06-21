# PROJECT: GDTLancer
# MODULE: action_tray.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: STRATEGICAL-TODO.md § REV_015
# LOG_REF: 2026-06-22 00:37:00

extends Control

signal action_resolved(result)
signal closed

onready var option_approach = $Panel/VBox/HBoxApproach/OptionApproach
onready var label_modifiers = $Panel/VBox/HBoxModifiers/LabelModifiers
onready var button_roll = $Panel/VBox/ButtonRoll
onready var label_result = $Panel/VBox/LabelResult
onready var label_details = $Panel/VBox/LabelDetails
onready var button_close = $Panel/VBox/ButtonClose

var _current_wealth_mod: int = 0
var _current_health_mod: int = 0
var _current_morale_mod: int = 0

func _ready():
	visible = false
	if is_instance_valid(button_roll) and not button_roll.is_connected("pressed", self, "_on_ButtonRoll_pressed"):
		button_roll.connect("pressed", self, "_on_ButtonRoll_pressed")
	if is_instance_valid(button_close) and not button_close.is_connected("pressed", self, "_on_ButtonClose_pressed"):
		button_close.connect("pressed", self, "_on_ButtonClose_pressed")

func open_tray(wealth_mod: int = 0, health_mod: int = 0, morale_mod: int = 0):
	_current_wealth_mod = wealth_mod
	_current_health_mod = health_mod
	_current_morale_mod = morale_mod
	
	if is_instance_valid(label_modifiers):
		label_modifiers.text = "Modifiers: Wealth (%d), Health (%d), Morale (%d)" % [wealth_mod, health_mod, morale_mod]
	if is_instance_valid(label_result):
		label_result.text = "Result: -"
	if is_instance_valid(label_details):
		label_details.text = "Dice: -, Mod: -"
	if is_instance_valid(button_roll):
		button_roll.disabled = false
	visible = true

func _on_ButtonRoll_pressed():
	if is_instance_valid(button_roll):
		button_roll.disabled = true
	var approach = 0
	if is_instance_valid(option_approach):
		approach = option_approach.selected # 0: Cautious, 1: Neutral, 2: Risky
	
	# Map index to Constants.ActionApproach (Cautious=0, Neutral=1, Risky=2)
	var approach_enum = Constants.ActionApproach.CAUTIOUS
	if approach == 1:
		approach_enum = Constants.ActionApproach.NEUTRAL
	elif approach == 2:
		approach_enum = Constants.ActionApproach.RISKY
		
	# Placeholder for attribute/skill, assuming 0 for now as it's a narrative test
	var result = CoreMechanicsAPI.perform_action_check(0, 0, approach_enum, _current_wealth_mod, _current_health_mod, _current_morale_mod)
	
	if is_instance_valid(label_result):
		label_result.text = "Result: " + result.get("tier_name", "Unknown")
	if is_instance_valid(label_details):
		var mod_sum = result.get("modifier", 0) + result.get("wealth_modifier", 0) + result.get("health_modifier", 0) + result.get("morale_modifier", 0)
		label_details.text = "Roll: %d (Dice: %d, Mod: %d)" % [result.get("roll_total", 0), result.get("dice_sum", 0), mod_sum]
	
	emit_signal("action_resolved", result)

func _on_ButtonClose_pressed():
	visible = false
	emit_signal("closed")
