extends Node

onready var object_aim_name = ""
onready var object_aim_origin = Player.global_transform.origin
var dist_aim_val = 0

onready var object_autopilot_name = ""
onready var object_autopilot_origin = Player.global_transform.origin
var dist_autopilot_val = 0

onready var player = Player.global_transform.origin

var target_autopilot_controls_hidden = true
var target_aim_controls_hidden = true

func _ready():
	# ============================= Connect signals ===========================
	Signals.connect("sig_target_aim_clear", self, "is_target_aim_clear")
	Signals.connect("sig_autopilot_start", self, "is_autopilot_start")
	Signals.connect("sig_autopilot_disable", self, "is_autopilot_disable")
	# =========================================================================
	# Hide targeting controls by default,
	is_autopilot_disable()
	is_target_aim_clear()

	
func _physics_process(_delta):
	
	#print(PlayerState.aim_target, " | ", PlayerState.autopilot_target )
	
	# AIM TARGET
	if  PlayerState.aim_target_locked:	
		
		var aim_target = PlayerState.aim_target
		
		# Unlock if target is lost.
		if not is_instance_valid(aim_target):
			Signals.emit_signal("sig_target_aim_clear")
			return
		
		if target_aim_controls_hidden:
			UiPaths.touch_readings_target_aim.show()
			UiPaths.desktop_readings_target_aim.show()
			target_aim_controls_hidden = false
		
		#if is_instance_valid(aim_target):
		object_aim_origin = aim_target.global_transform.origin
		object_aim_name = aim_target.get_name()
		
		# Player coords must be updated.
		player = Paths.camera_rig.global_transform.origin
		dist_aim_val = round(player.distance_to(object_aim_origin))
		
		# This is for UI.
		# Object visible, marker within range. Enable marker.

		
		# Multiply by scale factor of viewport to position properly.
		UiPaths.touch_readings_target_aim.visible = not Paths.camera.is_position_behind(object_aim_origin)
		UiPaths.touch_readings_target_aim.rect_position = Paths.camera.unproject_position(
			object_aim_origin)/GameOptions.render_res_factor*Paths.ui.reverse_scale
		
		UiPaths.desktop_readings_target_aim.visible = not Paths.camera.is_position_behind(object_aim_origin)
		UiPaths.desktop_readings_target_aim.rect_position = Paths.camera.unproject_position(
			object_aim_origin)/GameOptions.render_res_factor*Paths.ui.reverse_scale
		
		
		
		# Update marker.
		var result_d = UiPaths.common_readouts.get_magnitude_units(dist_aim_val)
		# Units. Also prevent crashing so there is a check.
		if result_d:
			UiPaths.touch_readings_target_aim.get_node("Text_distance").text = \
				str(result_d[0])+ " " + result_d[1]
			UiPaths.desktop_readings_target_aim.get_node("Text_distance").text = \
				str(result_d[0])+ " " + result_d[1]
			# Object name in bb code.
			#UiPaths.target_autopilot.get_node("Text_object").set_use_bbcode(true)
		UiPaths.touch_readings_target_aim.get_node("Text_object")
		UiPaths.touch_readings_target_aim.get_node("Text_object").text = object_aim_name
		
		UiPaths.desktop_readings_target_aim.get_node("Text_object")
		UiPaths.desktop_readings_target_aim.get_node("Text_object").text = object_aim_name
				
	elif not PlayerState.aim_target_locked and not target_aim_controls_hidden:
		is_target_aim_clear()
		
		# Also hide the controls to initiate AP. But keep AP target.
		
		target_aim_controls_hidden = true
	
	
	
	
	
	# AUTOPILOT TARGET
	if  PlayerState.autopilot_target_locked and PlayerState.autopilot:	
		
		if target_autopilot_controls_hidden:
			is_autopilot_start()
			target_autopilot_controls_hidden = false
		
		# Get coordinates and distance.
		# Fail-safety.
		if PlayerState.autopilot_target.is_class("GDScriptNativeClass"):
			Signals.emit_signal("sig_autopilot_disable")
			return
		
		# Unlock if target is lost.
		if not is_instance_valid(PlayerState.autopilot_target):
			Signals.emit_signal("sig_autopilot_disable")
			return	
		
		object_autopilot_origin = PlayerState.autopilot_target.global_transform.origin
		object_autopilot_name = PlayerState.autopilot_target.get_name()
		# Player coords must be updated.
		player = Paths.camera_rig.global_transform.origin
		dist_autopilot_val = round(player.distance_to(object_autopilot_origin))
		
		# This is for UI.
		# Object visible, marker within range. Enable marker.

		
		# Multiply by scale factor of viewport to position properly.
		UiPaths.touch_readings_target_autopilot.visible = not Paths.camera.is_position_behind(object_autopilot_origin)
		UiPaths.touch_readings_target_autopilot.rect_position = Paths.camera.unproject_position(
			object_autopilot_origin)/GameOptions.render_res_factor*Paths.ui.reverse_scale
		
		UiPaths.desktop_readings_target_autopilot.visible = not Paths.camera.is_position_behind(object_autopilot_origin)
		UiPaths.desktop_readings_target_autopilot.rect_position = Paths.camera.unproject_position(
			object_autopilot_origin)/GameOptions.render_res_factor*Paths.ui.reverse_scale
		
		# Update marker.
		var result_d = UiPaths.common_readouts.get_magnitude_units(dist_autopilot_val)
		# Units. Also prevent crashing so there is a check.
		if result_d:
			UiPaths.touch_readings_target_autopilot.get_node("Text_distance").text = \
				str(result_d[0])+ " " + result_d[1]
			UiPaths.desktop_readings_target_autopilot.get_node("Text_distance").text = \
				str(result_d[0])+ " " + result_d[1]
			# Object name in bb code.
			#UiPaths.target_autopilot.get_node("Text_object").set_use_bbcode(true)
		UiPaths.touch_readings_target_autopilot.get_node("Text_object")
		UiPaths.touch_readings_target_autopilot.get_node("Text_object").text = object_autopilot_name
				
				
		UiPaths.desktop_readings_target_autopilot.get_node("Text_object")
		UiPaths.desktop_readings_target_autopilot.get_node("Text_object").text = object_autopilot_name
				
	elif not PlayerState.autopilot_target_locked and not target_autopilot_controls_hidden:
		is_autopilot_disable()
		target_autopilot_controls_hidden = true

func is_target_aim_clear():
	UiPaths.ui_functions.target_controls_hide()

func is_autopilot_start():
	UiPaths.ui_functions.autopilot_controls_show()

func is_autopilot_disable():
	UiPaths.ui_functions.autopilot_controls_hide()
