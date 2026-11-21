# Tests for the HUD's MAP window (MapWindow): what it shows of the sector (MapItems.sector: what the
# brackets would show, plus belts, fields, hazards, the play area), the sectors and their routes
# (MapItems.global), its view's maths (MapView), its filters, and the HUD button.

extends GutTest

const MainHUDScene = preload("res://scenes/ui/hud/main_hud.tscn")
const MapWindowScene = preload("res://scenes/ui/menus/map_window.tscn")
const MapItems = preload("res://src/core/ui/map_window/map_items.gd")
const MapView = preload("res://src/core/ui/map_window/map_view.gd")
const BeaconScript = preload("res://src/scenes/game_world/sector_layout/beacon.gd")
const HazardScript = preload("res://src/scenes/game_world/sector_layout/hazard.gd")

# Sees everything but what is named Hidden*, faces -z.
const PLAYER_SOURCE = "extends Spatial\nfunc detects(other):\n\treturn not str(other.name).begins_with(\"Hidden\")\n"
const SHIP_SOURCE = "extends Spatial\nvar faction = \"\"\nfunc get_faction_color():\n\treturn Color.white\n"


func after_each():
	GameState.reset_state()
	get_tree().paused = false


func _scripted(source: String) -> Spatial:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	var node := Spatial.new()
	node.set_script(script)
	return node


func _at(node: Spatial, parent: Node, name: String, x: float, z: float) -> Spatial:
	node.name = name
	parent.add_child(node)
	node.translation = Vector3(x, 0, z)
	return node


func _by_kind(items: Array, kind: String) -> Array:
	var out: Array = []
	for item in items:
		if item.kind == kind:
			out.append(item)
	return out


func test_the_sector_map_shows_what_the_brackets_would_and_the_geography():
	var zone := Spatial.new()
	add_child_autofree(zone)
	var player: Spatial = _at(_scripted(PLAYER_SOURCE), zone, "Player", 100, 200)
	var seen: Spatial = _at(_scripted(SHIP_SOURCE), zone, "Trader", 1000, 0)
	var hidden: Spatial = _at(_scripted(SHIP_SOURCE), zone, "HiddenRaider", -1000, 0)
	var station: Spatial = _at(Spatial.new(), zone, "Station", 0, 5000)
	station.add_to_group("dockable_station")
	var belt: Spatial = _at(Spatial.new(), zone, "Belt", 20000, 0)
	var rocks: Array = []
	for index in range(3):
		var rock: Spatial = _at(Spatial.new(), belt, "Rock%d" % index, 0, 300 * (index + 1))  # The farthest 900 m out
		rock.add_to_group("asteroid")
		rocks.append(rock)
	var field = _at(BeaconScript.new(), zone, "Field", -8000, 0)
	field.kind = "field"
	field.radius = 1500.0
	var hazard = _at(HazardScript.new(), zone, "Hazard", 0, 0)
	var targets: Array = [player, seen, hidden, station, field] + rocks
	var items: Array = MapItems.sector(zone, targets, player, null, 30000.0)
	var ships: Array = _by_kind(items, "ship")
	assert_eq(ships.size(), 1, "Only the ship the player detects is on the map, as only its bracket shows")
	assert_true(ships[0].ref == seen, "the one it sees")
	assert_eq(ships[0].at, Vector2(1000, 0), "Top-down: x across, z down")
	assert_eq(_by_kind(items, "station").size(), 1)
	assert_eq(_by_kind(items, "rock").size(), 3, "Each rock is a dot")
	var belts: Array = _by_kind(items, "belt")
	assert_eq(belts.size(), 2, "The belt's rocks make a circle, and the field beacon its ring")
	for item in belts:
		if item.ref == belt:
			assert_almost_eq(item.radius, 900.0, 0.01, "out to its farthest rock")
		else:
			assert_eq(item.ref, field)
			assert_eq(item.radius, 1500.0, "the field as its beacon covers it")
	assert_eq(_by_kind(items, "hazard").size(), 1)
	assert_eq(_by_kind(items, "hazard")[0].radius, hazard.radius)
	assert_eq(_by_kind(items, "area")[0].radius, 30000.0, "The play area")
	var me: Array = _by_kind(items, "player")
	assert_eq(me.size(), 1, "The player is drawn once, as the player")
	assert_eq(me[0].at, Vector2(100, 200))
	assert_eq(me[0].heading, Vector2(0, -1), "facing -z: up the map")


func _location(name: String, x: float, z: float, connections: Array) -> LocationTemplate:
	var location := LocationTemplate.new()
	location.location_name = name
	location.global_position = Vector3(x, 0, z)
	location.connections = PoolStringArray(connections)
	return location


func test_the_global_map_shows_the_sectors_and_each_route_once():
	var locations := {
		"sector_elace": _location("Elace", 0, 0, ["sector_vidr", "sector_cob"]),
		"sector_vidr": _location("Vidr", -100000, 0, ["sector_elace"]),
		"sector_cob": _location("Cob", 50000, 90000, []),  # One way
		Constants.EVO_SECTOR_ID: _location("Arena", 0, 0, []),
	}
	var known: Dictionary = MapItems.global(locations, "sector_elace")
	var ids: Array = []
	for item in known.sectors:
		ids.append(item.ref)
		if item.ref == "sector_elace":
			assert_true(item.here, "Where the player is")
	assert_has(ids, "sector_elace")
	assert_does_not_have(ids, Constants.EVO_SECTOR_ID, "Evolution's sector is not the player's to see")
	var pairs := {}
	for route in known.routes:
		assert_has(ids, route[0])
		assert_has(ids, route[1])
		var key: String = PoolStringArray([route[0], route[1]] if route[0] < route[1] else [route[1], route[0]]).join("|")
		assert_false(pairs.has(key), "A route both ways is one line: " + key)
		pairs[key] = true
	assert_eq(known.routes.size(), 2, "Elace-Vidr (both ways) and Elace-Cob")


func _button(pressed: bool, at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	return event


func _motion(at: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.relative = relative
	return event


func test_the_view_converts_zooms_about_a_point_and_picks():
	var view = MapView.new()
	add_child_autofree(view)
	view.rect_size = Vector2(800, 600)
	view.metres_per_px = 10.0
	view.centre = Vector2(1000, 0)
	assert_eq(view.to_px(Vector2(1000, 0)), Vector2(400, 300), "The centre is the middle")
	assert_eq(view.to_metres(view.to_px(Vector2(3000, -500))), Vector2(3000, -500))
	var pivot := Vector2(600, 100)
	var under: Vector2 = view.to_metres(pivot)
	view.zoom(2.0, pivot)
	assert_eq(view.metres_per_px, 5.0)
	assert_true(view.to_metres(pivot).distance_to(under) < 0.01, "What is under the pointer stays there")
	view.set_items([{"filter": "ships", "kind": "ship", "at": view.to_metres(Vector2(410, 300)), "radius": 0.0, "ref": "a"},
		{"filter": "planets", "kind": "planet", "at": view.to_metres(Vector2(100, 100)), "radius": 200.0, "ref": "b"}])
	assert_eq(view.item_at(Vector2(400, 300)).ref, "a", "A tap picks what is near")
	assert_eq(view.item_at(Vector2(130, 100)).ref, "b", "or inside a planet")
	assert_true(view.item_at(Vector2(700, 500)).empty(), "and nothing far from all")
	view.shown = {"ships": false}
	assert_true(view.item_at(Vector2(400, 300)).empty(), "A hidden kind is not picked")
	view.shown = {}
	view._gui_input(_button(true, Vector2(405, 300)))
	view._gui_input(_button(false, Vector2(405, 300)))
	assert_eq(view.selected.get("ref"), "a", "A press and release where it is picks it")
	var before: Vector2 = view.centre
	view._gui_input(_button(true, Vector2(200, 200)))
	view._gui_input(_motion(Vector2(260, 200), Vector2(60, 0)))
	view._gui_input(_button(false, Vector2(260, 200)))
	assert_eq(view.centre, before - Vector2(60, 0) * view.metres_per_px, "A drag moves the map with the pointer, once")
	assert_eq(view.selected.get("ref"), "a", "and picks nothing")
	assert_eq(MapView.nice_step(130.0), 200.0)
	assert_eq(MapView.nice_step(4100.0), 5000.0)
	assert_eq(MapView.distance_text(20000.0), "20 KM")
	assert_eq(MapView.distance_text(1500.0), "1.5 KM")
	assert_eq(MapView.distance_text(800.0), "800 M")
	assert_eq(MapView.units_text(200000.0), "200 UNITS", "The global map's distances")
	assert_eq(MapView.units_text(1000.0), "1 UNIT")
	assert_eq(MapView.units_text(2500.0), "2.5 UNITS")


func test_the_filters_hide_a_kind_and_are_kept():
	var window = MapWindowScene.instance()
	add_child_autofree(window)
	window.open()
	var button: Button = window.get_node("Panel/Layout/Body/Side/Filters/List/Filter_ships")
	assert_eq(button.text, "SHIPS: ON")
	button.emit_signal("pressed")
	button = window.get_node("Panel/Layout/Body/Side/Filters/List/Filter_ships")
	assert_eq(button.text, "SHIPS: OFF", "A filter flips")
	assert_false(window._view.is_shown({"filter": "ships"}), "and the map hides that kind")
	window.show_tab(window.GLOBAL)
	assert_true(window.get_node("Panel/Layout/Body/Side/Filters/List").has_node("Filter_routes"), "Each tab has its own filters")
	window.show_tab(window.SECTOR)
	assert_false(window._view.is_shown({"filter": "ships"}), "and they are kept from tab to tab")
	window.close()


func test_the_hud_map_button_opens_and_closes_the_map():
	var hud = MainHUDScene.instance()
	add_child_autofree(hud)
	yield(get_tree(), "idle_frame")
	var button = hud.get_node("ScreenControls/CenterRightZone/ButtonMap")
	assert_true(button.visible, "MAP is beside PILOT and SHIP")
	button.emit_signal("pressed")
	assert_true(hud.map_window.visible, "MAP opens the map")
	assert_true(get_tree().paused, "and pauses the game")
	hud.map_window.get_node("Panel/Layout/Header/TabGlobal").emit_signal("pressed")
	assert_eq(hud.map_window.tab, "global", "GLOBAL shows the sectors")
	assert_true(hud.map_window._view.units, "in UNITS")
	button.emit_signal("pressed")
	assert_false(hud.map_window.visible, "Pressed again, it shuts")
	assert_false(get_tree().paused, "and the game goes on.")
