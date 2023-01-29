extends Node

func _ready():
	# ============================ Connect signals ============================
	Signals.connect_checked("sig_turret_mode_on", self, "is_turret_mode_on")
	# =========================================================================

func handle_input(event):

	# Works in both desktop and touchscreen.
	if event is InputEventKey:
		
		# GUI CONTROLS (GENERIC) ==============================================
		
		# Mouse flight.
		if event.pressed and event.scancode == KEY_SPACE:
			if PlayerState.mouse_flight:
				PlayerState.mouse_flight = false
				Signals.emit_signal("sig_mouse_flight_on", false)
			else:
				PlayerState.mouse_flight = true
				Signals.emit_signal("sig_mouse_flight_on", true)

				
		# Turret mode.
		if event.pressed and event.scancode == KEY_H:
			if not PlayerState.turret_mode:
				Signals.emit_signal("sig_turret_mode_on", true)
				PlayerState.turret_mode = true
			else:
				Signals.emit_signal("sig_turret_mode_on", false) 
				PlayerState.turret_mode = false
		
		# Quit the game.
		# TODO: remove keyboard mapping later on.
		if event.pressed and event.scancode == KEY_ESCAPE:
			Signals.emit_signal("sig_switch_to_options_gui")
		
		# SHIP CONTROLS =======================================================
		
		# Accelerate forward.
		if event.pressed and event.scancode == KEY_UP:
			Signals.emit_signal("sig_accelerate", true)

		# Accelerate backward.
		if event.pressed and event.scancode == KEY_DOWN:
			Signals.emit_signal("sig_accelerate", false)
		
		# TODO: sort out acceleration WSAD keys
		# Accelerate up strafe (should be?)
		if event.pressed and event.scancode == KEY_W:
			Signals.emit_signal("sig_accelerate", true)

		# Accelerate down strafe (should be?)
		if event.pressed and event.scancode == KEY_S:
			Signals.emit_signal("sig_accelerate", false)
		
		# Engine kill.
		if event.pressed and event.scancode == KEY_Z:
			Signals.emit_signal("sig_engine_kill")



# SIGNAL PROCESSING
func is_turret_mode_on(flag):
	PlayerState.turret_mode = flag
