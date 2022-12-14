extends ItemList

var pad_material = load("res://Assets/Themes/Default/Elements/Panel/Default_panel_mat_shader.tres")

func _ready():
	self.get_v_scroll().set_material(pad_material)
