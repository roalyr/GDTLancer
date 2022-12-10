extends Position3D

var marker_script = load("res://Scripts/Marker.gd")
var star_sprite = load("res://Scenes/Sprites/Star_sprite.tscn")
var star_blue = load("res://Scenes/Environment/Stellar/Stars/Star_blue.tscn")
var local_space_trigger_zone = load("res://Scenes/Zones/Local_space_triggers/Local_space_system.tscn")

onready var p = get_tree().get_root().get_node("Main/Paths")
var system_coords = Position3D
var system_scene = Position3D
var autopilot_target = Position3D

var system_scene_name = ""
var autopilot_target_name = ""
var trigger_zone = Area

var scene_autopilot_targeted = false
var scene_aim_targeted = false

func _ready():
	# ============================= Connect signals ===========================
	p.signals.connect("sig_system_coordinates_selected", self, "is_system_coordinates_selected")
	p.signals.connect("sig_entered_local_space_system", self, "is_entered_local_space_system")
	p.signals.connect("sig_autopilot_start", self, "is_autopilot_start")
	p.signals.connect("sig_autopilot_disable", self, "is_autopilot_disable")
	p.signals.connect("sig_target_aim_clear", self, "is_target_aim_clear")
	# =========================================================================

func is_autopilot_start():
	# Check if autopilot is set (target is a marker with data,
	autopilot_target = p.ship_state.autopilot_target
	autopilot_target_name = autopilot_target.marker_name
		

func is_system_coordinates_selected(coordinates):
	
	print(self.get_children())
	
	# Get the name of the system for later checks.
	system_scene_name = coordinates.get_name()

	# Despawn unneeded systems.
	despawn_systems()

	# If we select an entry that is not in the history list.
	if not self.has_node(system_scene_name):
		
		# Marker must be within Local space area in order to be re-located.
		system_scene = Position3D.new()
		
		# Get previously stored coordinates.
		system_coords = coordinates.duplicate()
		
		# Instance a zone trigger in the coordinates.
		trigger_zone = local_space_trigger_zone.instance()
		system_coords.add_child(trigger_zone)
		
		# Instance a system scene
		# TODO: make sure system's LOD2+ is set to "all hidden".
		system_scene.set_name(system_scene_name)
		system_scene.set_script(marker_script)
		system_scene.add_child(star_sprite.instance())
		system_scene.add_child(star_blue.instance())

		system_scene.autopilot_range = 5e10
		system_scene.marker_name = system_scene_name
		
		# Build a node tree and add it to the procedural space (self).
		trigger_zone.get_node("Scenes").add_child(system_scene)
		
		self.add_child(system_coords)
		
		# Emit a signal that everything has been done.
		p.signals.emit_signal("sig_system_spawned", system_scene)
	
	# This will work only when not in the zone. Otherwise look up local space.
	elif self.has_node(system_scene_name+"/Local_space_system/Scenes/"+system_scene_name):
		system_scene = self.get_node(system_scene_name+"/Local_space_system/Scenes/"+system_scene_name)
		p.signals.emit_signal("sig_system_spawned", system_scene)
		
	# If you are within zone, look up a scene in the local space.
	elif p.local_space_system.has_node("Scenes/"+system_scene_name):
		system_scene = p.local_space_system.get_node("Scenes/"+system_scene_name)
		p.signals.emit_signal("sig_system_spawned", system_scene)
		
	else:
		print("Can't find: ", system_scene_name)
		
	
func is_entered_local_space_system(zone):
		
	#self.add_child(system_coords)
	#p.signals.emit_signal("sig_system_spawned", system_scene)
	
	# Add a system to the visited history list.
	if not p.common_space_state.systems_visited.has(zone.get_parent()):
		p.common_space_state.systems_visited.push_back(zone.get_parent())
	#else:
		#print("Already visited: ", zone.get_parent())
	#print("Visited history: ", p.common_space_state.systems_visited)
	
	# Check if the list is full and has to be shrinked.
	# Keep removing the entries until the list is of a proper size (in case you target with autopilot).
	var to_be_despawned = p.common_space_state.systems_visited[0]
	var to_be_despawned_name = to_be_despawned.get_name()
	if not autopilot_target_name == to_be_despawned_name:
		if p.common_space_state.systems_visited.size() > p.common_constants.maximum_systems_spawned_on_visiting:
			#print("Removing from history: ", to_be_despawned_name)
			p.common_space_state.systems_visited.remove(0)
			#self.get_node(to_be_despawned_name).queue_free()
	#else:
		#print("Can't remove node from history, because it is used by AP: ", to_be_despawned_name)
	print("Visited history: ", p.common_space_state.systems_visited)

func despawn_systems():
	# Roll through coordinates.
	for procedural_space_coord in self.get_children():
		
		# Check if anything is used by autopilot.
		if p.ship_state.autopilot_target_locked: 
			# Check if AP target exists in procedural_space_coords.
			if p.ship_state.autopilot_target.get_name() == procedural_space_coord.get_name():
				scene_autopilot_targeted = true
			else:
				scene_autopilot_targeted = false
		
		# Check if anything is used by autopilot.
		if p.ship_state.aim_target_locked: 
			# Check if AP target exists in procedural_space_coords.
			if p.ship_state.aim_target.get_name() == procedural_space_coord.get_name():
				scene_aim_targeted = true
			else:
				scene_aim_targeted = false
		
		
		# Ignore scenes on visited history list.
		if p.common_space_state.systems_visited.has(procedural_space_coord):
			pass
		else:
			
			# Ignore scene which is both on AP and selected
			if scene_autopilot_targeted and scene_aim_targeted:
				pass
			
			# Ignore scenes on autopilot targeted list.
			elif scene_autopilot_targeted:
				# If aim is disabled and then AP is disabled - it trigger this with GDScriptNativeClass
				# Thus free such node and immediately return.
				if p.ship_state.autopilot_target.is_class("GDScriptNativeClass"):
					procedural_space_coord.free()
					return
			
			# Ignore scenes on selected targeted list.
			elif scene_aim_targeted:
				# If AP is disabled and then aim is disabled - it trigger this with GDScriptNativeClass
				# Thus free such node and immediately return.
				if p.ship_state.aim_target.is_class("GDScriptNativeClass"):
					procedural_space_coord.free()
					return
				
			# Cull whatever is left. Use free() instead of queue_free() in order to not to cause loops.
			else:
				procedural_space_coord.free()

func is_target_aim_clear():
	despawn_systems()
	# If both are disabled it causes a block in despawner, so have to despawn all.
	# This ignores visited list.
	#if not p.ship_state.autopilot_target_locked:
		#for child in self.get_children():
			#child.free()

func is_autopilot_disable():
	despawn_systems()
	# If both are disabled it causes a block in despawner, so have to despawn all.
	# This ignores visited list.
	#if not p.ship_state.aim_target_locked:
		#for child in self.get_children():
			#child.free()
