extends Position3D

var marker_script = load("res://Scripts/Marker.gd")
var star_sprite = load("res://Scenes/Sprites/Star_sprite.tscn")
var star_blue = load("res://Scenes/Environment/Stellar/Stars/Star_blue.tscn")
var local_space_trigger_zone = load("res://Scenes/Zones/Local_space_triggers/Local_space_system.tscn")

onready var p = get_tree().get_root().get_node("Main/Paths")
var system_coords = Position3D

func _ready():
	# ============================= Connect signals ===========================
	p.signals.connect("sig_system_coordinates_selected", self, "is_system_coordinates_selected")
	p.signals.connect("sig_exited_local_space_system", self, "is_exited_local_space_system")
	p.signals.connect("sig_entered_local_space_system", self, "is_entered_local_space_system")
	# =========================================================================

func is_system_coordinates_selected(coordinates):
	
	# Marker must be within Local space area in order to be re-located.
	var system_scene = Position3D.new()
	var system_scene_name = coordinates.get_name()

	# Check if it already exists in the spawned state. Otherwise pick it.
	if not self.has_node(system_scene_name):
		
		# Get previously stored coordinates.
		system_coords = coordinates.duplicate()
		
		# Instance a zone trigger in the coordinates.
		var trigger_zone = local_space_trigger_zone.instance()
		
		# Instance a system scene
		# TODO: make sure system's LOD2+ is set to "all hidden".
		system_scene.set_name(system_scene_name)
		system_scene.set_script(marker_script)
		system_scene.add_child(star_sprite.instance())
		system_scene.add_child(star_blue.instance())
		system_scene.autopilot_range = 5e10
		
		# Build a node tree and add it to the procedural space (self).
		trigger_zone.get_node("Scenes").add_child(system_scene)
		#system_scene.set_owner(self)
		
		system_coords.add_child(trigger_zone)
		#trigger_zone.set_owner(self)
		
		self.add_child(system_coords)
		#system_coords.set_owner(self)
		
		# Emit a signal that everything has been done.
		p.signals.emit_signal("sig_system_spawned", system_scene)
		
		# Since a new system spawned - add it to queue, as well as check if queue should be freed.
		# Activate despawn only after moving out of zone of system.
		if not p.common_space_state.systems_spawned.has(system_coords):
			
			# Add new system into selected queue.
			p.common_space_state.systems_spawned.push_back(system_coords)
			
			#print(p.common_space_state.systems_spawned)
			
			# Pick the one that has to be removed if the queue is full.
			var to_be_despawned = p.common_space_state.systems_spawned[0]
			var to_be_despawned_name = to_be_despawned.get_name()
			
			# If desired node is locked - take second one.
			var to_be_despawned_otherwise = Position3D
			var to_be_despawned_otherwise_name = ""
			if p.common_space_state.systems_spawned.size() > 1:
				to_be_despawned_otherwise = p.common_space_state.systems_spawned[1]
				to_be_despawned_otherwise_name = to_be_despawned_otherwise.get_name()
			
			# Check if it is not currently used by AP.
			if not p.ship_state.aim_target == to_be_despawned:
				
				# Perform queue freeing.
				print("Selection list: ", p.common_space_state.systems_spawned)
				
				if p.common_space_state.systems_spawned.size() > p.common_constants.maximum_systems_spawned_on_targeting:
					
					if self.has_node(to_be_despawned_name): 
						
						# Do it if the node is in tree and is NOT in visited history.
						if not p.common_space_state.systems_visited.has(to_be_despawned):
							# Free the list and the tree from despawned object.
							self.get_node(to_be_despawned_name).queue_free()
							p.common_space_state.systems_spawned.pop_front()
						else:
							# If the node IS in the history, then roll through the selection list
							# and find the next node which isn't and can be popped.
							print("Can't remove node, because it is in history: ", to_be_despawned_name)
							# Invert array to loop backwards.
							#var array_inv = p.common_space_state.systems_spawned.invert()
							var j = 0
							# Taking size - 1 because the last entry is current, and must not be popped.
							for entry in p.common_space_state.systems_spawned:
								if not p.common_space_state.systems_visited.has(entry) and j < p.common_space_state.systems_spawned.size()-1:
									# Free the list and the tree from despawned object.
									print("Removing another one instead: ", entry.get_name())
									self.get_node(entry.get_name()).queue_free()
									p.common_space_state.systems_spawned.remove(j)
									break
								else: j += 1

			else:
				print("Can't remove node, because it is used by AP: ", to_be_despawned_name)

	else:
		
		var system_coords = self.get_node(coordinates.get_name())
		
		# This will work only when not in the zone. Otherwise look up local space.
		if system_coords.has_node("Local_space_system/Scenes"):
			system_scene = system_coords.get_node("Local_space_system/Scenes").get_node(system_scene_name)
			#print(system_scene)
			# Emit a signal that everything has been done.
			p.signals.emit_signal("sig_system_spawned", system_scene)
			
			
		# If you are within zone, look up a scene in the local space.
		elif p.local_space_system.has_node("Scenes/"+system_scene_name):
			system_scene = p.local_space_system.get_node("Scenes").get_node(system_scene_name)
			#print("Already at: ",system_scene)
			# Emit a signal that everything has been done.
			p.signals.emit_signal("sig_system_spawned", system_scene)
			
	
func is_entered_local_space_system(zone):
	if not p.common_space_state.systems_visited.has(zone.get_parent()):
		p.common_space_state.systems_visited.push_back(zone.get_parent())
	#else:
		#print("Already visited: ", zone.get_parent())
	#print("Visited history: ", p.common_space_state.systems_visited)

func is_exited_local_space_system(zone):
	# Keep removing the entries until the list is of a proper size (in case you target with autopilot).
	var to_be_despawned = p.common_space_state.systems_visited[0]
	var to_be_despawned_name = to_be_despawned.get_name()
	if not p.ship_state.aim_target == to_be_despawned:
		if p.common_space_state.systems_visited.size() > p.common_constants.maximum_systems_spawned_on_visiting:
			# Free the list and the tree from despawned object.
			self.get_node(to_be_despawned_name).queue_free()
			p.common_space_state.systems_visited.remove(0)
	else:
		print("Can't remove node from history, because it is used by AP: ", to_be_despawned_name)
	print("Visited history: ", p.common_space_state.systems_visited)

