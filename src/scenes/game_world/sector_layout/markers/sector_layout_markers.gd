# SectorLayoutMarkers: the root of a sector's layout scene (scenes/levels/sectors/<sector>/layout.tscn):
# its play area and, under it, its markers (HavenMarker, BeaconMarker, HazardMarker, in any
# grouping nodes). Instanced inside the sector scene so the layout is placed among its planets in
# the editor; read without the sector (TemplateDatabase.sector_layouts, to_spec) and built in play
# by SectorLayout. Positions are in m from the sector's middle: keep the layout unmoved there.

tool
extends Spatial

const HavenMarker = preload("res://src/scenes/game_world/sector_layout/markers/haven_marker.gd")
const BeaconMarker = preload("res://src/scenes/game_world/sector_layout/markers/beacon_marker.gd")
const HazardMarker = preload("res://src/scenes/game_world/sector_layout/markers/hazard_marker.gd")

export var sector_id: String = ""
export var play_radius: float = 60000.0  # m from the middle: NPCs do not chase, salvage or patrol beyond it


# {"play_radius", "havens", "beacons", "hazards"} from the markers, in scene order.
func to_spec() -> Dictionary:
	var spec := {"play_radius": play_radius, "havens": [], "beacons": [], "hazards": []}
	var stack: Array = get_children()
	stack.invert()
	while not stack.empty():
		var node: Node = stack.pop_back()
		var children: Array = node.get_children()
		children.invert()
		stack += children
		if node is HavenMarker:
			spec.havens.append(node.to_spec(_position(node)))
		elif node is BeaconMarker:
			spec.beacons.append(node.to_spec(_position(node)))
		elif node is HazardMarker:
			spec.hazards.append(node.to_spec(_position(node)))
	return spec


# Where `node` is from this root (through any grouping nodes; works outside the tree).
func _position(node: Spatial) -> Vector3:
	var place: Transform = node.transform
	var parent: Node = node.get_parent()
	while parent != null and parent != self:
		if parent is Spatial:
			place = parent.transform * place
		parent = parent.get_parent()
	return place.origin
