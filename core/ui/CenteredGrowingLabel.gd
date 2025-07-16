# File: res://ui_elements/CenteredGrowingLabel.gd (or your preferred path)

# class_name ClassName, path/to/icon.svg
class_name CenteredGrowingLabel, "res://assets/art/ui/class_labels/class_centered_growing_label.svg"
extends Label

# --- Static Group Name ---
const AUTO_GROUP_NAME = "centered_growing_labels"

# --- Internal ---
var _is_ready_for_recenter = false


func _enter_tree():
	if not is_in_group(AUTO_GROUP_NAME):
		add_to_group(AUTO_GROUP_NAME)
	if not is_connected("resized", self, "_on_self_resized"):
		connect("resized", self, "_on_self_resized")
	call_deferred("_initial_setup_and_recenter")


func _initial_setup_and_recenter():
	_is_ready_for_recenter = true
	_recenter_in_parent()
	self.focus_mode = Control.FOCUS_NONE


func _exit_tree():
	if is_in_group(AUTO_GROUP_NAME):
		remove_from_group(AUTO_GROUP_NAME)
	if is_connected("resized", self, "_on_self_resized"):
		disconnect("resized", self, "_on_self_resized")


func _on_self_resized():
	_recenter_in_parent()


func _recenter_in_parent():
	if not _is_ready_for_recenter:
		return
	var parent_control = get_parent_control()
	if parent_control:
		var current_label_size = self.rect_size
		var parent_size = parent_control.rect_size
		var new_pos_x = (parent_size.x - current_label_size.x) / 2.0
		var new_pos_y = (parent_size.y - current_label_size.y) / 2.0
		if (
			not is_equal_approx(rect_position.x, new_pos_x)
			or not is_equal_approx(rect_position.y, new_pos_y)
		):
			self.rect_position = Vector2(new_pos_x, new_pos_y)


func get_parent_control() -> Control:
	var p = get_parent()
	if p is Control:
		return p
	return null
