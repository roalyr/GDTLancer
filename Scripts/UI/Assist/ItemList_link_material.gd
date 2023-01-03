extends ItemList

var pad_material = load("res://Assets/Themes/Default/Elements/Panel/Default_panel_mat_shader.tres")

func _ready():
	self.get_v_scroll().set_material(pad_material)
	self.set_item_tooltip_enabled(0, false)
	self.set_item_tooltip_enabled(1, false)
	self.set_item_tooltip_enabled(2, false)
	self.set_item_tooltip_enabled(3, false)
	self.set_item_tooltip_enabled(4, false)
	
	
