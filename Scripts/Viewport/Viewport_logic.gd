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
	is_screen_filter_on(p.common_game_options.render_texture_filter)

func init_viewport_update():
	# Has to be called manually bc doesn't initiate at start.
	var common_game_options = get_node("/root/Main/Common/Game_options")
	self.size = Vector2(1280, 720) * p.common_game_options.render_res_factor
	viewport_initiated = true
	#print("viewport updtated"); print(common_game_options.render_res_factor)
	#print(self.size)

# SIGNAL PROCESSING
func is_screen_filter_on(flag):
	if flag:
		p.common_game_options.render_texture_filter = true
		self.get_texture().flags = Texture.FLAG_FILTER
	else:
		p.common_game_options.render_texture_filter = false
		self.get_texture().flags = !Texture.FLAG_FILTER
		
func is_viewport_update():
	# Has to be called manually bc doesn't initiate at start.
	var common_game_options = get_node("/root/Main/Common/Game_options")
	self.size = OS.window_size * common_game_options.render_res_factor
	#print("viewport updtated"); print(common_game_options.render_res_factor)
	#print(self.size)
	
func is_render_res_value_changed(value):
	p.common_game_options.render_res_factor = value
	is_viewport_update()


func _on_Viewport_size_changed():
	if viewport_initiated:
		print("Viewport updated")
		p.signals.emit_signal("sig_viewport_update")
