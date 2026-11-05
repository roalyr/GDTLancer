# StationModel: the root of a station's model scene (a HavenMarker's `model`, or the Model of a
# station placed in a sector scene). What the game needs from a station model (CONTENT.md, "Models"):
# - Materials by their names in Blender (ModelLooks): "paint" takes the owner's station paint.
# - Any size: the station keeps the autopilot clear of its far corner, collides by its convex hull
#   and undocks ships above its top (DockableStation.fit_to_model).

tool
extends Spatial

const ModelLooks = preload("res://src/scenes/game_world/models/model_looks.gd")


func _notification(what: int) -> void:
	if what == NOTIFICATION_INSTANCED:
		ModelLooks.dress(self, null)


# Takes `material` on the painted surfaces (FactionTemplate.station_material).
func paint(material: Material) -> void:
	ModelLooks.dress(self, material)
