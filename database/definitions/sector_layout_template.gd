# SectorLayoutTemplate: a sector's layout (database/sectors/<sector id>.tres), built on load by
# SectorLayout: its havens (HavenTemplate files), beacons, rock fields and hazards. Positions are in
# m from the sector's middle; planets and moons stand in the sector scene, and havens and beacons are
# placed round them. Read as a Dictionary by sector id (TemplateDatabase.sector_layouts).
# Beacons, one Dictionary each: "kind" "patrol" (a faction's, "owner": its patrol ships go round
# them, its safe zone), "field" (a rock field to mine: "rocks" of them within "radius", "ring": only
# the outer share past it, round a planet) or "landmark" (a point routes go through; every planet
# and moon is one too; "player_visible" shows it on the HUD); "name", "at" (Vector3).
# Hazards: "kind" "radiation" round a star, from "core" (its surface) out to "radius"; hull damage a
# second rises from 0 at the edge to HAZARD_RADIATION_DPS at the surface, as the square of the depth.

extends Template
class_name SectorLayoutTemplate

export var play_radius: float = 60000.0  # m from the middle: NPCs do not chase, salvage or patrol beyond it
export(Array, String, FILE, "*.tres") var havens: Array = []  # HavenTemplate files
export var beacons: Array = []
export var hazards: Array = []


func to_spec() -> Dictionary:
	var built: Array = []
	for path in havens:
		var haven = load(path)
		if haven != null and haven.has_method("to_spec"):
			built.append(haven.to_spec())
		else:
			printerr("SectorLayoutTemplate %s: no haven at %s" % [template_id, path])
	return {"play_radius": play_radius, "havens": built, "beacons": beacons.duplicate(true), "hazards": hazards.duplicate(true)}
