# MapItems: what the map window (MapWindow) draws, as plain items, top-down (x to the right, z down,
# metres). The sector map shows what the HUD's brackets would show the player (the same targets,
# the same detection: an undetected ship is not on it, nor is a beacon only the NPCs know), each
# by its kind, plus the sector's geography: stars, planets, moons, the belts' circles, hazards and
# the play area. The global map shows the sectors (Locations) and their routes.
# An item: {"filter" (MapWindow's filter key), "kind" (TargetKinds.kind_of, or "player", "belt",
# "hazard", "area", "sector"), "at" (Vector2, m), "radius" (m; 0 for a mark), "color", "label",
# "ref" (the node or sector id), "hostile", "filled" (as the brackets' marks), "heading" (player)}.

extends Reference

const TargetKinds = preload("res://src/core/ui/main_hud/target_kinds.gd")

const BELT_MIN_ROCKS = 3  # Rocks under one node before it is drawn as a belt's circle
const FILTER_OF_KIND = {"ship": "ships", "station": "stations", "beacon": "beacons", "distress": "beacons", "rock": "rocks",
	"wreck": "wrecks", "pickup": "pickups"}


# The current sector's items. `targets`: what the HUD's brackets follow (HUDTargetProjector
# collect_world_projected_targets); `player` sees them as its brackets do (Agent.detects); `namer`
# names a target (MainHUD._resolve_target_display_name), or null for node names; `play_radius`: the
# layout's (INF: none).
static func sector(zone: Node, targets: Array, player: Node, namer: Object = null, play_radius: float = INF) -> Array:
	var out: Array = []
	if not is_instance_valid(zone):
		return out
	var to_sector: Transform = zone.global_transform.affine_inverse() if zone is Spatial else Transform.IDENTITY
	if play_radius < INF and play_radius > 0.0:
		out.append(_item("area", "area", Vector2.ZERO, play_radius, Color(1, 1, 1, 0.25), "", null))
	for hazard in zone.get_tree().get_nodes_in_group("hazard") if zone.is_inside_tree() else []:
		if zone.is_a_parent_of(hazard):
			var item := _item("hazards", "hazard", _flat(to_sector, hazard), float(hazard.radius), Constants.COLOR_UI_TARGET_HOSTILE,
				str(hazard.get("kind")).to_upper(), hazard)
			item["core"] = float(hazard.get("core")) if hazard.get("core") != null else 0.0
			out.append(item)
	var belts := {}  # Parent node -> its rocks
	for target in targets:
		if not is_instance_valid(target) or target == player:
			continue
		if is_instance_valid(player) and player.has_method("detects") and not player.detects(target):
			continue  # As its bracket: an undetected ship is not shown
		var kind: String = TargetKinds.kind_of(target)
		var at: Vector2 = _flat(to_sector, target)
		var name: String = namer.call("_resolve_target_display_name", target) if namer != null else str(target.name)
		if kind == "body":
			var star: bool = bool(target.get("is_star"))
			var moon: bool = not star and (str(target.name) + str(target.filename)).to_lower().find("moon") >= 0
			var radius: float = target.get_apparent_radius() if target.has_method("get_apparent_radius") else 0.0
			out.append(_item("stars" if star else ("moons" if moon else "planets"), "star" if star else ("moon" if moon else "planet"),
				at, radius, TargetKinds.graded(Constants.COLOR_UI_BODY), name, target))
			continue
		if kind == "rock":
			var parent: Node = target.get_parent()
			if not parent.is_in_group("sector_layout"):  # A field's rocks: its beacon draws the field
				if not belts.has(parent):
					belts[parent] = []
				belts[parent].append(at)
		elif kind == "beacon" and str(target.get("kind")) == "field" and float(target.get("radius")) > 0.0:
			var field := _item("belts", "belt", at, float(target.radius), TargetKinds.graded(Constants.COLOR_UI_ROCK), "", target)
			field["field"] = name  # Its beacon carries the name
			out.append(field)
		var item := _item(FILTER_OF_KIND.get(kind, "other"), kind, at, 0.0, TargetKinds.color_of(target, player),
			"" if kind == "rock" else name, target)
		if kind == "ship":
			item.hostile = TargetKinds.side_of(target, player) == "hostile"
			item.filled = not target.has_method("detects") or not is_instance_valid(player) or target.detects(player)  # Has seen the player
		out.append(item)
	for parent in belts:
		if belts[parent].size() >= BELT_MIN_ROCKS and parent != zone:
			out.append(_belt(belts[parent], parent, to_sector))
	if is_instance_valid(player) and player is Spatial:
		var item := _item("player", "player", _flat(to_sector, player), 0.0, Color.white, "YOU", player)
		var forward: Vector3 = to_sector.basis.xform(-player.global_transform.basis.z)
		item["heading"] = Vector2(forward.x, forward.z).normalized() if Vector2(forward.x, forward.z).length() > 0.001 else Vector2(0, -1)
		out.append(item)
	return out


# The global map: every sector at its place (Location global_position), the current one white, the
# others in their type's colour; and the routes, each pair once: [[from id, to id]]. Evolution's
# sector (Constants.EVO_SECTOR_ID: no route goes there) only while the player is in it.
static func global(locations: Dictionary, current_id: String) -> Dictionary:
	var sectors: Array = []
	var routes: Array = []
	for sector_id in locations:
		if sector_id == Constants.EVO_SECTOR_ID and sector_id != current_id:
			continue
		var template = locations[sector_id]
		var position: Vector3 = template.global_position
		var here: bool = sector_id == current_id
		var sector_type: String = TemplateDatabase.get_sector_type(sector_id)
		var item := _item("sectors", "sector", Vector2(position.x, position.z), 0.0,
			Color.white if here else Constants.get_jump_type_color(sector_type), str(template.location_name), sector_id)
		item["type"] = sector_type
		item["here"] = here
		item["routes"] = template.connections.size()
		sectors.append(item)
		for target_id in template.connections:
			var target = locations.get(target_id)
			if target == null or (target_id == Constants.EVO_SECTOR_ID and target_id != current_id) \
					or (sector_id > target_id and sector_id in target.connections):
				continue  # Both ways: once
			routes.append([sector_id, str(target_id)])
	return {"sectors": sectors, "routes": routes}


# A belt's circle: centred on its node, out to its farthest rock (as the development tool's map).
static func _belt(rocks: Array, parent: Node, to_sector: Transform) -> Dictionary:
	var centre: Vector2 = _flat(to_sector, parent) if parent is Spatial else Vector2.ZERO
	var reach := 0.0
	for at in rocks:
		reach = max(reach, centre.distance_to(at))
	var item := _item("belts", "belt", centre, reach, TargetKinds.graded(Constants.COLOR_UI_ROCK), str(parent.name), parent)
	item["rocks"] = rocks.size()
	return item


static func _item(filter: String, kind: String, at: Vector2, radius: float, color: Color, label: String, ref) -> Dictionary:
	return {"filter": filter, "kind": kind, "at": at, "radius": radius, "color": color, "label": label, "ref": ref,
		"hostile": false, "filled": false}


static func _flat(to_sector: Transform, node: Spatial) -> Vector2:
	var at: Vector3 = to_sector.xform(node.global_transform.origin)
	return Vector2(at.x, at.z)
