extends Label

export var wrap_at_characters: int = 50
export var line_scale_factor = 1.0

var original_text = ""
var wrapped_text = ""

onready var ui_paths = get_node("/root/Main/UI_paths")

func _ready():
	# ============================ Connect signals ============================
	Signals.connect_checked("sig_viewport_update", self, "is_viewport_update")
	# =========================================================================

	# Disable buil-it autowrap.
	self.autowrap = false
	original_text = self.text
	text_wrap()


func wrap_text(text: String, wrap_at: int) -> String:
	var text_array = text.split(" ")
	var text_formatted = ""
	for word in text_array:
		var line_length = text_formatted.length() - text_formatted.find_last("\n")
		if line_length + word.length() < wrap_at:
			text_formatted += word + " "
		else:
			text_formatted += "\n" + word + " "

			
	return text_formatted

func is_viewport_update():
	if self.visible:
		text_wrap()
	
func text_wrap():
	var parent_width = get_parent().get_parent().rect_size.x
	var wrap_factored = wrap_at_characters * parent_width * line_scale_factor * 1e-3
	print(parent_width, " | " , wrap_factored)
	wrapped_text = wrap_text(original_text, wrap_factored)
	self.set_text(wrapped_text)
