extends ItemList

onready var p = get_tree().get_root().get_node("Main/Paths")
#onready var coordinates_bank = p.common_resources.systems_coordinates_bank_1
onready var coordinates_bank = p.common_space_state.markers_stars

var selected = 0
var targeted_scene = Position3D

# Fetch a fresh list of markers whenever nav button is pressed.
func _ready():
	# ============================= Connect signals ===========================
	p.signals.connect("sig_fetch_markers", self, "is_fetch_markers")
	p.signals.connect("sig_target_aim_clear", self, "is_target_aim_clear")
	p.signals.connect("sig_autopilot_start", self, "is_autopilot_start")
	p.signals.connect("sig_autopilot_disable", self, "is_autopilot_disable")
	p.signals.connect("sig_system_spawned", self, "is_system_spawned")
	# =========================================================================
	
	self.ensure_current_is_visible()


# Update markers every time you open a nav list.
func is_fetch_markers():
	# First clear the list of previous items.
	self.clear()
			
	# Fetch a fresh list of markers.
	# TODO: add custom / temporary coordinates for local space.

	for coordinates in coordinates_bank:
		if coordinates.targetable:
			
			# Count ID.
			var id = self.get_item_count()
				
			# Add item with the node name.
			self.add_item(coordinates.get_name(), null, true)
			
			# Icon (same as script class).
#			var texture = ImageTexture.new()
#			var image = Image.new()
#			image.load("res://Assets/UI_images/SVG/icons/nebula_marker.svg")
#			texture.create_from_image(image)
#			self.set_fixed_icon_size(Vector2(15,15))
#			self.set_item_icon(id, texture)
			
			# Disable tooltips.
			self.set_item_tooltip_enabled(id, false)
			
			# Attach data to the item.
			self.set_item_metadata(id, coordinates)
	
	# Sort the list by name
	self.sort_items_by_text()


func _on_ItemList_nav_visibility_changed():
	# Preserve apparent selection even when the list is hidden and called again.
	if self.visible and p.ship_state.aim_target_locked:
		self.select(selected)

	# TODO: Also clear selection when target lock is removed.



func _on_ItemList_nav_item_selected(index):
	selected = index
	var coordinates = self.get_item_metadata(index)
	print(coordinates)
	p.signals.emit_signal("sig_system_coordinates_selected", coordinates)
	# TODO: sort out markers vs dyn. spawned objects.
	var marker_scene = coordinates
	p.signals.emit_signal("sig_system_spawned", marker_scene)
	
func is_system_spawned(system_scene):
	# Save currently selected scene reference in memory
	targeted_scene = system_scene
	
	# Update aim target.
	p.ship_state.aim_target = targeted_scene
	p.ship_state.aim_target_locked = true
	
func is_autopilot_start():
	# When AP starts, update and use this target.
	p.ship_state.autopilot_target = targeted_scene
	p.ship_state.autopilot_target_locked = true
	
# If aim is disable and then AUP immediately after that - it prevents systems from despawning.
# It happens when target is the same for both modes and is consequtively disabled.
func is_target_aim_clear():
	# Clear list selection.
	self.unselect_all()
	# Clear aim target.
	p.ship_state.aim_target_locked = false
	p.ship_state.aim_target = Position3D

func is_autopilot_disable():
	# Update markers
	# TODO: keep it for local markers which will be in the future.
	#is_fetch_markers()
	# Clear AP target.
	p.ship_state.autopilot_target_locked = false
	p.ship_state.autopilot_target = Position3D
