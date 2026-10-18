# Tests for ShipFit (slots, default fit, stats) and Fitting (buying, selling, refitting at home).

extends GutTest

const ShipFit = preload("res://src/core/systems/ship_fit.gd")
const Fitting = preload("res://src/core/systems/fitting.gd")
const AgentScript = preload("res://src/core/agents/agent.gd")
const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")

var ship: ShipTemplate = null
var _saved: Dictionary = {}


func before_each():
	for category in ["utility_tools", "assets_modules"]:
		_saved[category] = TemplateDatabase.get(category)
	TemplateDatabase.utility_tools = {
		"t_small": _tool("t_small", "small", 100, 300.0),
		"t_medium": _tool("t_medium", "medium", 200, 600.0),
	}
	TemplateDatabase.assets_modules = {
		"m_plate": _module("m_plate", 120, 1500.0, {"hull": 300}),
		"m_engine": _module("m_engine", 150, 400.0, {"linear_thrust": 100000}),
	}
	ship = ShipTemplate.new()
	ship.hull_integrity = 100
	ship.mass = 6000.0
	ship.linear_thrust = 500000.0
	ship.tool_slots_small = 1
	ship.tool_slots_medium = 1
	ship.module_slots = 2
	ship.equipped_tools = ["t_small"]
	ship.equipped_modules = ["m_plate"]
	GameState.reset_state()
	GameState.home_location_id = "home"
	GameState.player_docked_at = "home"


func after_each():
	for category in _saved:
		TemplateDatabase.set(category, _saved[category])
	GameState.reset_state()


func _tool(id: String, size: String, value: int, mass: float) -> UtilityToolTemplate:
	var t = UtilityToolTemplate.new()
	t.template_id = id
	t.tool_type = "laser"
	t.mount_size = size
	t.base_value = value
	t.mass = mass
	return t


func _module(id: String, value: int, mass: float, modifiers: Dictionary) -> ModuleTemplate:
	var m = ModuleTemplate.new()
	m.template_id = id
	m.base_value = value
	m.mass = mass
	m.stat_modifiers = modifiers
	return m


func _player_ship() -> RigidBody:
	var body = AgentScript.new()
	body.agent_type = "player"
	body.ship_template = ship
	add_child_autofree(body)
	var tools = ToolControllerScript.new()
	tools.name = "ToolController"
	body.add_child(tools)
	body._init_fit()
	body._init_hull_and_power()
	return body


func test_default_fit_places_tools_by_size_and_modules_in_order():
	var fit: Dictionary = ShipFit.default_fit(ship)
	assert_eq(fit.tools, ["t_small", ""], "Small tool takes the small slot, the medium slot stays free.")
	assert_eq(fit.modules, ["m_plate", ""])


func test_tools_fit_slots_of_their_size_or_larger():
	var fit: Dictionary = ShipFit.empty_fit(ship)
	assert_eq(ShipFit.free_tool_slot(ship, fit, "t_small"), 0, "Prefers the smallest slot that takes it.")
	assert_eq(ShipFit.free_tool_slot(ship, fit, "t_medium"), 1, "A medium tool needs a medium or large slot.")
	fit.tools[1] = "t_medium"
	assert_eq(ShipFit.free_tool_slot(ship, fit, "t_medium"), -1)


func test_stats_add_module_modifiers_and_every_part_mass():
	var stats: Dictionary = ShipFit.compute_stats(ship, {"tools": ["t_small", "t_medium"], "modules": ["m_plate", "m_engine"]})
	assert_eq(stats.hull, 400.0)
	assert_eq(stats.linear_thrust, 600000.0)
	assert_eq(stats.mass, 6000.0 + 300.0 + 600.0 + 1500.0 + 400.0)


func test_buying_spends_the_bank_and_selling_returns_half():
	GameState.player_bank = 250
	assert_eq(Fitting.buy("m_engine"), "")
	assert_eq(GameState.player_bank, 100)
	assert_eq(GameState.player_storage.get("m_engine"), 1)
	assert_ne(Fitting.buy("m_engine"), "", "Cannot afford a second one.")
	assert_eq(Fitting.sell("m_engine"), "")
	assert_eq(GameState.player_bank, 175)
	assert_false(GameState.player_storage.has("m_engine"))


func test_refitting_only_at_the_home_port():
	GameState.player_bank = 1000
	GameState.player_docked_at = ""
	assert_ne(Fitting.buy("m_engine"), "")
	GameState.player_docked_at = "elsewhere"
	assert_ne(Fitting.buy("m_engine"), "")


func test_fitting_and_unfitting_update_the_live_ship():
	var body = _player_ship()
	assert_eq(body.hull_max, 400.0, "Default fit includes the plating.")
	var base_mass: float = body.mass
	GameState.player_storage = {"m_engine": 1, "t_medium": 1}
	assert_eq(Fitting.fit_part(body, "m_engine"), "")
	assert_eq(body.movement_system, null)
	assert_almost_eq(body.mass, base_mass + 400.0, 0.01, "The module's mass is carried.")
	assert_eq(body.fit.modules, ["m_plate", "m_engine"])
	assert_eq(GameState.player_fit.modules, ["m_plate", "m_engine"], "The player's fit is kept in GameState.")
	assert_false(GameState.player_storage.has("m_engine"))
	assert_eq(Fitting.fit_part(body, "t_medium"), "")
	assert_eq(body.get_fitted_tool_ids(), ["t_small", "t_medium"])
	assert_eq(body.get_node("ToolController").get_tool_count(), 2, "Tools reload with the fit.")
	assert_eq(Fitting.unfit(body, "modules", 0), "")
	assert_eq(body.hull_max, 100.0, "Plating removed.")
	assert_eq(GameState.player_storage.get("m_plate"), 1, "Unfitted parts go back to storage.")
	assert_ne(Fitting.fit_part(body, "m_engine"), "", "Nothing left in storage to fit.")
