extends Viewport

# VARIABLES
onready var p = get_tree().get_root().get_node("Main/Paths")

var viewport_initiated = false

func _ready():
	# ============================ Connect signals ============================
	p.signals.connect("sig_screen_filter_on", self, "is_screen_filter_on")
	p.signals.connect("sig_viewport_update", self, "is_viewport_update")
	p.signals.connect("sig_render_res_value_changed", self, "is_render_res_value_changed")
	# =========================================================================
	
	# Init 
	# TODO: sync UI elements.
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
		p.signals.emit_signal("sig_viewport_update")
