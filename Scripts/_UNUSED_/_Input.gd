extends Node

# VARIABLES
var mouse_x = 0
var mouse_y = 0
var mouse_x_abs = 0
var mouse_y_abs = 0
var pad_x_abs = 0
var pad_y_abs = 0

var mouse_vector = Vector2(0,0)
var viewport_size = Vector2(1,1)

var LMB_held = false
var LMB_released = true
var mouse_on_viewport = true

onready var p = get_tree().get_root().get_node("Main/Paths")
onready var ui_controls_bar = p.ui.get_node("Controls/Control_bar")
onready var ui_main3d = p.ui.get_node("Main3D")
onready var ui_button_turret = p.ui.get_node("Controls/Control_bar/Button_turret")
onready var ui_mouse_area = p.ui.get_node("Controls/Mouse_area")

func _ready():
	# ============================ Connect signals ============================
	p.signals.connect("sig_mouse_on_viewport", self, "is_mouse_on_viewport")
	p.signals.connect("sig_viewport_update", self, "is_viewport_update")
	p.signals.connect("sig_quit_game", self, "is_quit_game")
	p.signals.connect("sig_turret_mode_on", self, "is_turret_mode_on")
	# =========================================================================
	
	# Initial value require for the mouse coords.
	viewport_size = OS.window_size
	
# TODO: Link a script for key shortcuts (like options).??????
func _input(event):

	# ==================== For events on mouse area (desktop) ==========================
	# Mouse over 3D viewport.
	if mouse_on_viewport and ui_mouse_area.visible:
		# TODO: Maybe there is a better way to handle mouse area capture?
		# =========================== For mouse ===============================
		# Track the mouse position in +/-1, +/-1 viewport coordinates.
		if event is InputEventMouseMotion:
			mouse_x_abs = event.global_position.x
			mouse_y_abs = event.global_position.y
			mouse_x = clamp(((mouse_x_abs-viewport_size.x/2) \
				/ viewport_size.x*2), -1, 1)
			mouse_y = clamp(((mouse_y_abs-viewport_size.y/2) \
				/ viewport_size.y*2), -1, 1)
			mouse_vector = Vector2(mouse_x, mouse_y)
		
		# Mouse button held check. LMB_released is to reduce calls number.
		if Input.is_mouse_button_pressed(BUTTON_LEFT) and LMB_released:
			LMB_released = false
			LMB_held = true
		
		# Mouse button released check. LMB_released is to reduce calls number.
		if not Input.is_mouse_button_pressed(BUTTON_LEFT) and not LMB_released:
			LMB_released = true
			LMB_held = false
		
		# Camera orbiting is in the camera script.
		
		# Camera zoom.
		if event is InputEventMouseButton and p.ship_state.turret_mode:
			p.camera_rig.zoom_camera(event)
		
		# ======================= For keyboard buttons =========================
		if event is InputEventKey:
			
			# ============================ UI Controls =========================
			# Mouse flight.
			if event.pressed and event.scancode == KEY_SPACE:
				if p.ship_state.mouse_flight:
					p.ship_state.mouse_flight = false
					p.signals.emit_signal("sig_mouse_flight_on", false)
				else:
					p.ship_state.mouse_flight = true
					p.signals.emit_signal("sig_mouse_flight_on", true)
			
			# TODO: Should also be accessible from other areas and windows.
			# Show toolbar.
			if event.pressed and event.scancode == KEY_BACKSPACE:
				if ui_controls_bar.visible:
					ui_controls_bar.visible = false
				else:
					ui_controls_bar.visible = true
					
				if ui_main3d.visible:
					ui_main3d.visible = false
				else:
					ui_main3d.visible = true
					
			
			# Turret mode. UI shortcut. Signal is emitted by UI.
			if event.pressed and event.scancode == KEY_H:
				if not p.ship_state.turret_mode: 
					ui_button_turret.pressed = true
				else: ui_button_turret.pressed = false
			
			# ============================= Ship controls ======================
			# Accelerate forward.
			# TODO: unique signals for simultaneous action.
			if event.pressed and event.scancode == KEY_UP:
				p.signals.emit_signal("sig_accelerate", true)

			# Accelerate backward.
			if event.pressed and event.scancode == KEY_DOWN:
				p.signals.emit_signal("sig_accelerate", false)
			
			# TODO: sort out acceleration WSAD keys
			# Accelerate up strafe.
			if event.pressed and event.scancode == KEY_W:
				p.signals.emit_signal("sig_accelerate", true)

			# Accelerate down strafe.
			if event.pressed and event.scancode == KEY_S:
				p.signals.emit_signal("sig_accelerate", false)
			
			# Accelerate down strafe.
			if event.pressed and event.scancode == KEY_Z:
				if not p.ship_state.engine_kill: 
					p.ship_state.engine_kill = true
					p.signals.emit_signal("sig_engine_kill", true)
				else: 
					p.ship_state.engine_kill = false
					p.signals.emit_signal("sig_engine_kill", false)
	# =================== For events on touchscreen stick held ===================
	elif p.ui.stick_held:
		# Track the mouse position in +/-1, +/-1 Pad base coordinates.
		if event is InputEventMouseMotion:
			pad_x_abs = event.global_position.x-p.ui.pad_base.rect_position.x
			pad_y_abs = event.global_position.y-p.ui.pad_base.rect_position.y
			var pad_x = clamp(((pad_x_abs-p.ui.pad_base.rect_size.x/2) \
				/ p.ui.pad_base.rect_size.x*2), -1, 1)
			var pad_y = clamp(((pad_y_abs-p.ui.pad_base.rect_size.y/2) \
				/ p.ui.pad_base.rect_size.y*2), -1, 1)
			mouse_vector = Vector2(pad_x, pad_y) 
			# TODO: rename mouse vector to joystick vector.
			
		# Mouse button held check. LMB_released is to reduce calls number.
		if Input.is_mouse_button_pressed(BUTTON_LEFT) and LMB_released:
			LMB_released = false
			LMB_held = true
		
		# Mouse button released check. LMB_released is to reduce calls number.
		if not Input.is_mouse_button_pressed(BUTTON_LEFT) and not LMB_released:
			LMB_released = true
			LMB_held = false
	
	# =================== For events outside of area (desktop) ===================
	else:
		pass
		
	# ========================= For events anywhere ===========================
	if event is InputEventKey:
		
		# Quit the game.
		if event.pressed and event.scancode == KEY_ESCAPE:
			get_tree().quit()

#func _process(delta):
#	pass

#func _physics_process(delta):
#	pass

# ================================== Other ====================================

# ============================ Signal processing ==============================
# Check if viewport resized and get new values. Required for mouse coordinates.
func is_viewport_update():
	# For mouse coords.
	viewport_size = OS.window_size

# Check if we are hovering mouse over the control bar.
func is_mouse_on_viewport(flag):
	if flag: mouse_on_viewport = true
	else: mouse_on_viewport = false

func is_quit_game():
	get_tree().quit()

func is_turret_mode_on(flag):
	p.ship_state.turret_mode = flag

