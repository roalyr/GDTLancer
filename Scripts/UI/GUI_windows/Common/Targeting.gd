extends Node

onready var p = get_tree().get_root().get_node("Main/Paths")

onready var object_aim_name = ""
onready var object_aim_origin = p.ship.global_transform.origin
var dist_aim_val = 0

onready var object_autopilot_name = ""
onready var object_autopilot_origin = p.ship.global_transform.origin
var dist_autopilot_val = 0

onready var player = p.camera_rig.global_transform.origin

var target_autopilot_controls_hidden = true
var target_aim_controls_hidden = true

func _ready():
	# ============================= Connect signals ===========================
	p.signals.connect("sig_target_aim_clear", self, "is_target_aim_clear")
	p.signals.connect("sig_autopilot_start", self, "is_autopilot_start")
	p.signals.connect("sig_autopilot_disable", self, "is_autopilot_disable")
	# =========================================================================
	# Hide targeting controls by default,
	is_autopilot_disable()
	is_target_aim_clear()

	
func _physics_process(_delta):
	
	#print(p.ship_state.aim_target, " | ", p.ship_state.autopilot_target )
	
	# AIM TARGET
	if  p.ship_state.aim_target_locked:	
		
		var aim_target = p.ship_state.aim_target
		
		if target_aim_controls_hidden:
			p.ui_paths.touch_readings_target_aim.show()
			target_aim_controls_hidden = false
		
		#if is_instance_valid(aim_target):
		object_aim_origin = aim_target.global_transform.origin
		object_aim_name = aim_target.get_name()
		
		# Player coords must be updated.
		player = p.camera_rig.global_transform.origin
		dist_aim_val = round(player.distance_to(object_aim_origin))
		
		# This is for UI.
		# Object visible, marker within range. Enable marker.

		
		# Multiply by scale factor of viewport to position properly.
		p.ui_paths.touch_readings_target_aim.visible = not p.viewport.get_camera().is_position_behind(object_aim_origin)
		p.ui_paths.touch_readings_target_aim.rect_position = p.viewport.get_camera().unproject_position(
			object_aim_origin)/p.common_game_options.render_res_factor*p.ui.reverse_scale
		
		# Update marker.
		var result_d = p.ui_paths.common_readouts.get_magnitude_units(dist_aim_val)
		# Units. Also prevent crashing so there is a check.
		if result_d:
			p.ui_paths.touch_readings_target_aim.get_node("Text_distance").text = \
				str(result_d[0])+ " " + result_d[1]
			# Object name in bb code.
			#p.ui_paths.target_autopilot.get_node("Text_object").set_use_bbcode(true)
		p.ui_paths.touch_readings_target_aim.get_node("Text_object")
		p.ui_paths.touch_readings_target_aim.get_node("Text_object").text = object_aim_name
				
	elif not p.ship_state.aim_target_locked and not target_aim_controls_hidden:
		is_target_aim_clear()
		
		# Also hide the controls to initiate AP. But keep AP target.
		
		target_aim_controls_hidden = true
	
	
	
	
	
	# AUTOPILOT TARGET
	if  p.ship_state.autopilot_target_locked and p.ship_state.autopilot:	
		
		if target_autopilot_controls_hidden:
			is_autopilot_start()
			target_autopilot_controls_hidden = false
		
		# Get coordinates and distance.
		# Fail-safety.
		if p.ship_state.autopilot_target.is_class("GDScriptNativeClass"):
			return
		object_autopilot_origin = p.ship_state.autopilot_target.global_transform.origin
		object_autopilot_name = p.ship_state.autopilot_target.get_name()
		# Player coords must be updated.
		player = p.camera_rig.global_transform.origin
		dist_autopilot_val = round(player.distance_to(object_autopilot_origin))
		
		# This is for UI.
		# Object visible, marker within range. Enable marker.

		
		# Multiply by scale factor of viewport to position properly.
		p.ui_paths.touch_readings_target_autopilot.visible = not p.viewport.get_camera().is_position_behind(object_autopilot_origin)
		p.ui_paths.touch_readings_target_autopilot.rect_position = p.viewport.get_camera().unproject_position(
			object_autopilot_origin)/p.common_game_options.render_res_factor*p.ui.reverse_scale
		
		# Update marker.
		var result_d = p.ui_paths.common_readouts.get_magnitude_units(dist_autopilot_val)
		# Units. Also prevent crashing so there is a check.
		if result_d:
			p.ui_paths.touch_readings_target_autopilot.get_node("Text_distance").text = \
				str(result_d[0])+ " " + result_d[1]
			# Object name in bb code.
			#p.ui_paths.target_autopilot.get_node("Text_object").set_use_bbcode(true)
		p.ui_paths.touch_readings_target_autopilot.get_node("Text_object")
		p.ui_paths.touch_readings_target_autopilot.get_node("Text_object").text = object_autopilot_name
				
	elif not p.ship_state.autopilot_target_locked and not target_autopilot_controls_hidden:
		is_autopilot_disable()
		target_autopilot_controls_hidden = true

func is_target_aim_clear():
	p.ui_paths.ui_functions.target_controls_hide()

func is_autopilot_start():
	p.ui_paths.ui_functions.autopilot_controls_show()

func is_autopilot_disable():
	p.ui_paths.ui_functions.autopilot_controls_hide()
