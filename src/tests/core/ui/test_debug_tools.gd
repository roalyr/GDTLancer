# Tests for DebugTools: jump list, places and typed coordinates, and refitting any slot on the spot.

extends GutTest

const DebugTools = preload("res://src/core/ui/debug_tools/debug_tools.gd")
const AgentScript = preload("res://src/core/agents/agent.gd")

var tools: Control = null
var ship: RigidBody = null
var _saved: Dictionary = {}


func before_each():
	GameState.reset_state()
	for category in ["utility_tools", "assets_modules"]:
		_saved[category] = TemplateDatabase.get(category)
	TemplateDatabase.utility_tools = {"t_small": _tool("t_small", "small"), "t_large": _tool("t_large", "large")}
	TemplateDatabase.assets_modules = {"m_plate": _module("m_plate")}
	var template := ShipTemplate.new()
	template.hull_integrity = 100
	template.mass = 6000.0
	template.tool_slots_small = 1
	template.module_slots = 1
	ship = AgentScript.new()
	ship.agent_type = "player"
	ship.ship_template = template
	ship.fit = {"tools": [""], "modules": [""]}
	add_child_autofree(ship)
	GlobalRefs.player_agent_body = ship
	tools = DebugTools.new()
	add_child_autofree(tools)


func after_each():
	for category in _saved:
		TemplateDatabase.set(category, _saved[category])
	GlobalRefs.player_agent_body = null
	GameState.reset_state()


func _tool(id: String, size: String) -> UtilityToolTemplate:
	var t = UtilityToolTemplate.new()
	t.template_id = id
	t.tool_type = "laser"
	t.mount_size = size
	t.mass = 100.0
	return t


func _module(id: String) -> ModuleTemplate:
	var m = ModuleTemplate.new()
	m.template_id = id
	m.mass = 100.0
	return m


func test_refit_offers_only_parts_that_fit_and_fits_them_at_once_without_docking():
	assert_eq(DebugTools.parts_for(ship, "tools", 0), ["t_small"], "A large tool does not fit a small slot")
	assert_eq(DebugTools.parts_for(ship, "modules", 0), ["m_plate"])
	tools.refit("tools", 0, "t_small")
	tools.refit("modules", 0, "m_plate")
	assert_eq(ship.fit.tools, ["t_small"])
	assert_eq(ship.fit.modules, ["m_plate"])
	assert_eq(GameState.player_docked_at, "", "Undocked all along")
	assert_true(GameState.player_storage.empty(), "Storage untouched")
	tools.refit("tools", 0, "")
	assert_eq(ship.fit.tools, [""], "And empties a slot")


func test_go_to_puts_the_ship_at_typed_coordinates_stopped():
	ship.linear_velocity = Vector3(100, 0, 0)
	tools.open_go_to()
	assert_true(tools.visible)
	tools._coord_edits[0].text = "12.5"
	tools._coord_edits[1].text = "-1"
	tools._coord_edits[2].text = "0"
	tools._go_to_typed()
	assert_eq(ship.global_transform.origin, Vector3(12500, -1000, 0))
	assert_eq(ship.linear_velocity, Vector3.ZERO)
	assert_false(tools.visible, "Closes on the way")


func test_go_to_lists_places_nearest_first_and_stops_short_of_them():
	var far := Spatial.new()
	far.add_to_group("arena_beacon")
	far.translation = Vector3(50000, 0, 0)
	add_child_autofree(far)
	var near := Spatial.new()
	near.add_to_group("jump_point")
	near.translation = Vector3(0, 0, 9000)
	add_child_autofree(near)
	var found: Array = tools.places()
	assert_eq(found.size(), 2)
	assert_eq(found[0].node, near)
	tools.go_to_place(far)
	assert_almost_eq(ship.global_transform.origin.distance_to(far.translation), DebugTools.STANDOFF_MIN, 1.0)


func test_jump_lists_every_sector():
	tools.open_jump()
	var sectors := 0
	for id in TemplateDatabase.locations:
		if TemplateDatabase.locations[id].get("connections") != null:
			sectors += 1
	assert_eq(tools._list.get_child_count(), sectors)


func test_to_target_puts_the_ship_beside_the_selected_target_at_its_speed():
	assert_false(tools.go_to_target(), "Nothing selected")
	var target := RigidBody.new()
	target.translation = Vector3(20000, 0, 0)
	add_child_autofree(target)
	target.linear_velocity = Vector3(0, 0, 50)
	EventBus.emit_signal("player_target_selected", target)
	assert_true(tools.go_to_target())
	assert_almost_eq(ship.global_transform.origin.distance_to(target.translation), DebugTools.TARGET_STANDOFF, 1.0)
	assert_eq(ship.linear_velocity, Vector3(0, 0, 50), "Moving with it")
	EventBus.emit_signal("player_target_deselected")
	assert_false(tools.go_to_target())
