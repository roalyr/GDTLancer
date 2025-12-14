extends StaticBody

export var location_id: String = "station_alpha"
export var station_name: String = "Station Alpha"

onready var docking_zone = $DockingZone

func _ready():
	print("DockableStation ready: ", station_name, " at ", global_transform.origin)
	if docking_zone:
		docking_zone.monitoring = true
		docking_zone.monitorable = true
		docking_zone.collision_layer = 1
		docking_zone.collision_mask = 1
		docking_zone.connect("body_entered", self, "_on_body_entered")
		docking_zone.connect("body_exited", self, "_on_body_exited")
		
		# Check for overlapping bodies immediately in case player spawned inside
		var bodies = docking_zone.get_overlapping_bodies()
		for body in bodies:
			_on_body_entered(body)
	else:
		printerr("DockableStation Error: DockingZone not found!")

func _on_body_entered(body):
	# Ignore self (the station's own StaticBody)
	if body == self:
		return
	# Only care about KinematicBody (ships)
	if not body is KinematicBody:
		return
		
	print("Body entered docking zone: ", body.name)
	if body.has_method("is_player"):
		print("Body has is_player method. Result: ", body.is_player())
		if body.is_player():
			EventBus.emit_signal("dock_available", location_id)
			print("Dock available at: ", station_name)
	else:
		print("Body does NOT have is_player method.")

func _on_body_exited(body):
	if body == self:
		return
	if not body is KinematicBody:
		return
	if body.has_method("is_player") and body.is_player():
		EventBus.emit_signal("dock_unavailable")
		print("Dock unavailable at: ", station_name)
