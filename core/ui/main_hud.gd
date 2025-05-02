# File: res://core/ui/main_hud.gd
# Script for the main HUD container. Handles displaying targeting info, etc.
# Version: 1.1 - Fixed targeting indicator visibility restoration

extends Control

# --- Nodes ---
onready var targeting_indicator: Control = $TargetingIndicator

# --- State ---
var _current_target: Spatial = null
var _main_camera: Camera = null

# --- Initialization ---
func _ready():
	# Ensure indicator starts hidden
	targeting_indicator.visible = false

	# Get camera reference once
	_main_camera = get_viewport().get_camera() # Initial attempt
	if not is_instance_valid(_main_camera) and is_instance_valid(GlobalRefs.main_camera):
		_main_camera = GlobalRefs.main_camera # Fallback via GlobalRefs

	if not is_instance_valid(_main_camera):
		printerr("MainHUD Error: Could not get a valid camera reference!")
		set_process(false) # Disable processing if no camera

	# Connect to EventBus signals
	if EventBus:
		if not EventBus.is_connected("player_target_selected", self, "_on_Player_Target_Selected"):
			EventBus.connect("player_target_selected", self, "_on_Player_Target_Selected")
		if not EventBus.is_connected("player_target_deselected", self, "_on_Player_Target_Deselected"):
			EventBus.connect("player_target_deselected", self, "_on_Player_Target_Deselected")
	else:
		printerr("MainHUD Error: EventBus not available!")

	# Connect draw signal for custom drawing (optional, but good for style)
	targeting_indicator.connect("draw", self, "_draw_targeting_indicator")


# --- Process Update ---
func _process(delta):
	# Only update position if a target is selected and valid
	if is_instance_valid(_current_target) and is_instance_valid(_main_camera):
		# Project the target's 3D origin position to 2D screen coordinates
		var screen_pos: Vector2 = _main_camera.unproject_position(_current_target.global_transform.origin)

		# Check if the target is behind the camera
		var target_dir = (_current_target.global_transform.origin - _main_camera.global_transform.origin).normalized()
		var camera_fwd = -_main_camera.global_transform.basis.z.normalized()
		var is_in_front = target_dir.dot(camera_fwd) >= 0 # Use >= 0 to include exactly perpendicular

		# --- MODIFIED Visibility Logic ---
		# Set visibility based on whether the target is in front
		targeting_indicator.visible = is_in_front

		# Only update position and redraw if it's actually visible
		if targeting_indicator.visible:
			# Update the indicator's position
			targeting_indicator.rect_position = screen_pos - (targeting_indicator.rect_size / 2.0)
			targeting_indicator.update() # Trigger redraw if using _draw
	else:
		# Ensure indicator is hidden if target becomes invalid or camera is invalid
		if targeting_indicator.visible:
			targeting_indicator.visible = false


# --- Signal Handlers ---
func _on_Player_Target_Selected(target_node: Spatial):
	print(target_node)
	if is_instance_valid(target_node):
		_current_target = target_node
		# Visibility is now primarily handled in _process,
		# but we still need to ensure _process runs.
		# targeting_indicator.visible = true # This line can be removed or kept, _process will override
		set_process(true) # Ensure _process runs
	else:
		_on_Player_Target_Deselected()

func _on_Player_Target_Deselected():
	_current_target = null
	targeting_indicator.visible = false
	set_process(false) # Can disable processing if target is deselected


# --- Custom Drawing (Optional but Recommended) ---
func _draw_targeting_indicator():
	# Example: Draw a simple white rectangle outline
	var rect = Rect2(Vector2.ZERO, targeting_indicator.rect_size)
	var line_color = Color.white
	var line_width = 1.0 # Adjust thickness as needed
	#targeting_indicator.draw_rect(rect, line_color, false, line_width)

	# Example: Draw simple corner brackets
	var size = targeting_indicator.rect_size
	var corner_len = size.x * 0.25 # Length of corner lines
	var color = Color.cyan
	var width = 2.0
	# # Top-left
	targeting_indicator.draw_line(Vector2(0,0), Vector2(corner_len, 0), color, width)
	targeting_indicator.draw_line(Vector2(0,0), Vector2(0, corner_len), color, width)
	# # Top-right
	targeting_indicator.draw_line(Vector2(size.x, 0), Vector2(size.x - corner_len, 0), color, width)
	targeting_indicator.draw_line(Vector2(size.x, 0), Vector2(size.x, corner_len), color, width)
	# # Bottom-left
	targeting_indicator.draw_line(Vector2(0, size.y), Vector2(corner_len, size.y), color, width)
	targeting_indicator.draw_line(Vector2(0, size.y), Vector2(0, size.y - corner_len), color, width)
	# # Bottom-right
	targeting_indicator.draw_line(Vector2(size.x, size.y), Vector2(size.x - corner_len, size.y), color, width)
	targeting_indicator.draw_line(Vector2(size.x, size.y), Vector2(size.x, size.y - corner_len), color, width)


# --- Cleanup ---
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if EventBus:
			if EventBus.is_connected("player_target_selected", self, "_on_Player_Target_Selected"):
				EventBus.disconnect("player_target_selected", self, "_on_Player_Target_Selected")
			if EventBus.is_connected("player_target_deselected", self, "_on_Player_Target_Deselected"):
				EventBus.disconnect("player_target_deselected", self, "_on_Player_Target_Deselected")


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
