extends Control

onready var label_skill_piloting: Label = $LabelSkillPiloting
onready var label_skill_trading: Label = $LabelSkillTrading


# --- Initialization ---
func _ready():
	GlobalRefs.set_character_status(self)


func _draw():
	update_display()


func update_display():
	var piloting_skill = GlobalRefs.character_system.get_player_character().skills["piloting"]
	var trading_skill = GlobalRefs.character_system.get_player_character().skills["trading"]
	label_skill_piloting.text = "Skill Piloting: " + str(piloting_skill)
	label_skill_trading.text = "Skill Trading: " + str(trading_skill)


func _on_ButtonClose_pressed():
	self.hide()


func _on_ButtonAddWP_pressed():
	# For testing
	GlobalRefs.character_system.add_wp(GlobalRefs.character_system.get_player_character_uid(), 10)
	EventBus.emit_signal("player_wp_changed")


func _on_ButtonAddFP_pressed():
	# For testing
	GlobalRefs.character_system.add_fp(GlobalRefs.character_system.get_player_character_uid(), 1)
	EventBus.emit_signal("player_fp_changed")
