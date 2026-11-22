# Tests for DebugTools: jump list, places and typed coordinates, refitting any slot and swapping the hull on the spot.

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
	TemplateDatabase.utility_tools = {"preset_laser_light": _tool("preset_laser_light", "small"), "preset_cannon_heavy": _tool("preset_cannon_heavy", "large")}
	TemplateDatabase.assets_modules = {"preset_plating_light": _module("preset_plating_light")}
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
	assert_eq(DebugTools.parts_for(ship, "tools", 0), ["preset_laser_light"], "A large tool does not fit a small slot")
	assert_eq(DebugTools.parts_for(ship, "modules", 0), ["preset_plating_light"])
	tools.refit("tools", 0, "preset_laser_light")
	tools.refit("modules", 0, "preset_plating_light")
	assert_eq(ship.fit.tools, ["preset_laser_light"])
	assert_eq(ship.fit.modules, ["preset_plating_light"])
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
	far.add_to_group("beacon")
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


func test_dev_options_change_what_happens_not_what_npcs_read():
	ship.hull_max = 100.0
	ship.hull = 100.0
	ship.power = 10.0
	var signature: float = ship.get_signature()
	tools.open_dev()
	assert_eq(tools._list.get_child_count(), DebugTools.CHEATS.size(), "A switch each")
	tools.toggle_cheat("no_damage")
	tools.toggle_cheat("infinite_energy")
	ship.apply_damage(30.0)
	assert_eq(ship.hull, 100.0, "No damage")
	assert_true(ship.try_spend_power(5.0))
	assert_eq(ship.power, 10.0, "Infinite energy")
	assert_eq(ship.get_signature(), signature, "Signature as it was")
	var npc = AgentScript.new()
	add_child_autofree(npc)
	npc.global_transform.origin = Vector3(0, 0, -100)
	tools.toggle_cheat("invisible")
	assert_false(npc.detects(ship), "Invisible to NPCs")
	tools.toggle_cheat("no_damage")
	ship.apply_damage(30.0)
	assert_eq(ship.hull, 70.0, "Off again: damage as ever")
	GameState.dev_cheats.clear()


# A stand-in for AgentSystem.replace_player: a new body of the hull GameState now names.
class FakeSpawner:
	extends Node
	var calls: int = 0
	var parent: Node = null

	func replace_player() -> void:
		calls += 1
		var old = GlobalRefs.player_agent_body
		if is_instance_valid(old):
			old.get_parent().remove_child(old)
			old.free()
		var body = load("res://src/core/agents/agent.gd").new()
		body.agent_type = "player"
		body.ship_template = TemplateDatabase.get_template(GameState.player_ship_template_id)
		body.fit = GameState.player_fit.duplicate(true)
		parent.add_child(body)
		GlobalRefs.player_agent_body = body


func test_refit_has_a_hull_tab_and_an_equipment_tab():
	tools.open_refit()
	assert_true(tools._tabs.visible, "REFIT shows its tabs")
	assert_eq(tools._tabs.get_node("Tab_equipment").text, "[EQUIPMENT]", "Equipment first open: the slots, as before")
	assert_eq(tools._list.get_child_count(), 2, "A tool slot and a module slot")
	tools.show_refit_tab("hull")
	assert_eq(tools._tabs.get_node("Tab_hull").text, "[HULL]")
	assert_eq(tools._tabs.get_node("Tab_hull").theme_type_variation, "TabButtonOpen")
	assert_eq(tools._list.get_child_count(), DebugTools.hulls().size(), "A button a hull")
	tools.open_jump()
	assert_false(tools._tabs.visible, "Other pages have none")


func test_the_hull_list_is_the_store_s_then_the_stock_hulls():
	var saved_presets: Dictionary = TemplateDatabase.presets
	var saved_ships: Dictionary = TemplateDatabase.assets_ships
	TemplateDatabase.presets = {"preset_ship_archetype_trader_light": ShipTemplate.new(), "preset_ship_archetype_fighter_light": ShipTemplate.new(), "preset_laser_light": UtilityToolTemplate.new()}
	TemplateDatabase.assets_ships = {"ship_default": ShipTemplate.new(), "ship_hostile_default": ShipTemplate.new()}
	assert_eq(DebugTools.hulls(), ["preset_ship_archetype_fighter_light", "preset_ship_archetype_trader_light", "ship_default", "ship_hostile_default"],
		"The archetypes as the store sells them, then the stock hulls; no parts")
	TemplateDatabase.presets = saved_presets
	TemplateDatabase.assets_ships = saved_ships


func test_a_hull_swap_keeps_place_speed_and_the_parts_that_still_fit():
	var small := ShipTemplate.new()
	small.template_id = "dev_small"
	small.ship_model_name = "Dev Small"
	small.hull_integrity = 50
	small.mass = 3000.0
	small.tool_slots_small = 2
	small.module_slots = 0
	var saved_ships: Dictionary = TemplateDatabase.assets_ships
	TemplateDatabase.assets_ships = {"dev_small": small}
	var spawner := FakeSpawner.new()
	spawner.parent = self
	add_child_autofree(spawner)
	var saved_spawner = GlobalRefs.agent_spawner
	GlobalRefs.agent_spawner = spawner
	ship.fit = {"tools": ["preset_laser_light"], "modules": ["preset_plating_light"]}
	ship.global_transform.origin = Vector3(5000, 0, -2000)
	ship.linear_velocity = Vector3(0, 0, -80)
	GameState.player_hull_scars = [Vector3.ONE]
	tools.swap_hull("dev_small")
	var flown = GlobalRefs.player_agent_body
	assert_eq(spawner.calls, 1)
	assert_eq(GameState.player_ship_template_id, "dev_small")
	assert_eq(flown.fit.tools, ["preset_laser_light", ""], "The laser kept, the new slot empty")
	assert_eq(flown.fit.modules, [], "No module bay: the plating goes")
	assert_eq(flown.global_transform.origin, Vector3(5000, 0, -2000), "Where it was")
	assert_eq(flown.linear_velocity, Vector3(0, 0, -80), "as fast")
	assert_eq(GameState.player_hull, -1.0, "repaired")
	assert_true(GameState.player_hull_scars.empty(), "and unmarked")
	assert_true(GameState.player_storage.empty(), "Free: storage untouched")
	tools.swap_hull("dev_small")
	assert_eq(spawner.calls, 1, "The hull flown already: nothing")
	TemplateDatabase.assets_ships = saved_ships
	GlobalRefs.agent_spawner = saved_spawner
	GlobalRefs.player_agent_body = null
	if is_instance_valid(flown):
		flown.queue_free()
