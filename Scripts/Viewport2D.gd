extends Viewport

var viewport_initiated = false

func _ready():
	# ============================ Connect signals ============================
	Signals.connect("sig_screen_filter_on", self, "is_screen_filter_on")
	Signals.connect("sig_viewport_update", self, "is_viewport_update")
	Signals.connect("sig_render_res_value_changed", self, "is_render_res_value_changed")
	# =========================================================================
	
	init_viewport_update()
	is_screen_filter_on(GameOptions.render_texture_filter)

func init_viewport_update():
	# Has to be called manually bc doesn't initiate at start.
	self.size = Vector2(1280, 720) * GameOptions.render_res_factor
	viewport_initiated = true
	#print("viewport updtated"); print(GameOptions.render_res_factor)
	#print(self.size)

# SIGNAL PROCESSING
func is_screen_filter_on(flag):
	if flag:
		GameOptions.render_texture_filter = true
		self.get_texture().flags = Texture.FLAG_FILTER
	else:
		GameOptions.render_texture_filter = false
		self.get_texture().flags = !Texture.FLAG_FILTER
		
func is_viewport_update():
	self.size = OS.window_size * GameOptions.render_res_factor
	
	
func is_render_res_value_changed(value):
	GameOptions.render_res_factor = value
	is_viewport_update()


func _on_Viewport_size_changed():
	if viewport_initiated:
		print("Viewport updated")
		Signals.emit_signal("sig_viewport_update")
