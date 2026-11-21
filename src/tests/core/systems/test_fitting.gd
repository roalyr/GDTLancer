# Tests for ShipFit (slots, default fit, stats), Fitting (buying, selling, refitting at home) and the
# station window shown while docked there.

extends GutTest

const ShipFit = preload("res://src/core/systems/ship_fit.gd")
const Fitting = preload("res://src/core/systems/fitting.gd")
const AgentScript = preload("res://src/core/agents/agent.gd")
const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")
const ShipLaws = preload("res://src/core/systems/ship_laws.gd")
const PartCatalog = preload("res://src/core/systems/part_catalog.gd")

var ship: ShipTemplate = null
var _saved: Dictionary = {}


func before_each():
	for category in ["utility_tools", "assets_modules"]:
		_saved[category] = TemplateDatabase.get(category)
	TemplateDatabase.utility_tools = {
		"preset_laser_light": _tool("preset_laser_light", "small", 100, 300.0),
		"preset_laser_medium": _tool("preset_laser_medium", "medium", 200, 600.0),
	}
	TemplateDatabase.assets_modules = {
		"preset_plating_heavy": _module("preset_plating_heavy", 120, 1500.0, {"hull": 300}),
		"preset_thruster_medium": _module("preset_thruster_medium", 150, 400.0, {"linear_thrust": 100000}),
	}
	ship = ShipTemplate.new()
	ship.hull_integrity = 100
	ship.mass = 6000.0
	ship.linear_thrust = 500000.0
	ship.tool_slots_small = 1
	ship.tool_slots_medium = 1
	ship.module_slots = 2
	ship.equipped_tools = ["preset_laser_light"]
	ship.equipped_modules = ["preset_plating_heavy"]
	GameState.reset_state()
	GameState.home_location_id = "home"
	GameState.player_docked_at = "home"
	GameState.station_markups = {"home": 0.0}  # Prices at physics value


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


func test_random_fit_arms_the_first_slot_and_fills_slots_by_size():
	for attempt in range(20):
		var fit: Dictionary = ShipFit.random_fit(ship)
		assert_eq(fit.tools.size(), ShipFit.tool_slot_sizes(ship).size())
		assert_eq(fit.modules.size(), ship.module_slots)
		assert_eq_deep(ShipFit.normalized(ship, fit), fit)  # Every part fits its slot
		var first = TemplateDatabase.get_template(fit.tools[0])
		assert_true(first == null or first.tool_type == "laser", "A weapon first, if one fits.")


func test_default_fit_places_tools_by_size_and_modules_in_order():
	var fit: Dictionary = ShipFit.default_fit(ship)
	assert_eq(fit.tools, ["preset_laser_light", ""], "Small tool takes the small slot, the medium slot stays free.")
	assert_eq(fit.modules, ["preset_plating_heavy", ""])


func test_tools_fit_slots_of_their_size_or_larger():
	var fit: Dictionary = ShipFit.empty_fit(ship)
	assert_eq(ShipFit.free_tool_slot(ship, fit, "preset_laser_light"), 0, "Prefers the smallest slot that takes it.")
	assert_eq(ShipFit.free_tool_slot(ship, fit, "preset_laser_medium"), 1, "A medium tool needs a medium or large slot.")
	fit.tools[1] = "preset_laser_medium"
	assert_eq(ShipFit.free_tool_slot(ship, fit, "preset_laser_medium"), -1)


func test_stats_add_module_modifiers_and_every_part_mass():
	var stats: Dictionary = ShipFit.compute_stats(ship, {"tools": ["preset_laser_light", "preset_laser_medium"], "modules": ["preset_plating_heavy", "preset_thruster_medium"]})
	assert_eq(stats.hull, 400.0)
	assert_eq(stats.linear_thrust, 600000.0)
	assert_eq(stats.mass, 6000.0 + 300.0 + 600.0 + 1500.0 + 400.0)


func test_buying_spends_the_bank_and_selling_returns_half():
	GameState.player_bank = 250
	assert_eq(Fitting.buy("preset_thruster_medium"), "")
	assert_eq(GameState.player_bank, 100)
	assert_eq(GameState.player_storage.get("preset_thruster_medium"), 1)
	assert_ne(Fitting.buy("preset_thruster_medium"), "", "Cannot afford a second one.")
	assert_eq(Fitting.sell("preset_thruster_medium"), "")
	assert_eq(GameState.player_bank, 175)
	assert_false(GameState.player_storage.has("preset_thruster_medium"))


func test_refitting_only_at_the_home_port():
	GameState.player_bank = 1000
	GameState.player_docked_at = ""
	assert_ne(Fitting.buy("preset_thruster_medium"), "")
	GameState.player_docked_at = "elsewhere"
	assert_ne(Fitting.buy("preset_thruster_medium"), "")


func test_fitting_and_unfitting_update_the_live_ship():
	var body = _player_ship()
	assert_eq(body.hull_max, 400.0, "Default fit includes the plating.")
	var base_mass: float = body.mass
	GameState.player_storage = {"preset_thruster_medium": 1, "preset_laser_medium": 1}
	assert_eq(Fitting.fit_part(body, "preset_thruster_medium"), "")
	assert_eq(body.movement_system, null)
	assert_almost_eq(body.mass, base_mass + 400.0, 0.01, "The module's mass is carried.")
	assert_eq(body.fit.modules, ["preset_plating_heavy", "preset_thruster_medium"])
	assert_eq(GameState.player_fit.modules, ["preset_plating_heavy", "preset_thruster_medium"], "The player's fit is kept in GameState.")
	assert_false(GameState.player_storage.has("preset_thruster_medium"))
	assert_eq(Fitting.fit_part(body, "preset_laser_medium"), "")
	assert_eq(body.get_fitted_tool_ids(), ["preset_laser_light", "preset_laser_medium"])
	assert_eq(body.get_node("ToolController").get_tool_count(), 2, "Tools reload with the fit.")
	assert_eq(Fitting.unfit(body, "modules", 0), "")
	assert_eq(body.hull_max, 100.0, "Plating removed.")
	assert_eq(GameState.player_storage.get("preset_plating_heavy"), 1, "Unfitted parts go back to storage.")
	assert_ne(Fitting.fit_part(body, "preset_thruster_medium"), "", "Nothing left in storage to fit.")


func test_lance_launchers_side_by_side_and_spent_lances_lighten_the_ship():
	var lance_genes := {"nail_mass": 200.0, "count": 3.0}
	TemplateDatabase.assets_modules["m_lance"] = ShipLaws.build_module_template("lance", lance_genes, 2, "m_lance")
	TemplateDatabase.assets_modules["m_lance_2"] = ShipLaws.build_module_template("lance", lance_genes, 2, "m_lance_2")
	var body = _player_ship()
	GameState.player_storage = {"m_lance": 1, "m_lance_2": 1}
	assert_eq(Fitting.unfit(body, "modules", 0), "")
	var base_mass: float = body.mass
	assert_eq(Fitting.fit_part(body, "m_lance"), "")
	assert_almost_eq(body.hull_max, 100.0 + ShipLaws.module_stats("lance", lance_genes).stat_modifiers.hull, 0.01, "The prow armours the bow")
	assert_gt(ShipLaws.module_stats("lance", lance_genes).stat_modifiers.hull, 0)
	assert_almost_eq(body.mass, base_mass + 1000.0, 0.01)
	assert_eq(Fitting.fit_part(body, "m_lance_2"), "", "A second launcher fits beside the first")
	assert_eq(ShipFit.normalized(ship, {"tools": [], "modules": ["m_lance", "m_lance_2"]}).modules, ["m_lance", "m_lance_2"])
	var lances: Array = body.get_lances()
	assert_eq(lances.size(), 2)
	assert_almost_eq(lances[0].mount_offset, -lances[1].mount_offset, 0.001, "Side by side, either side of the axis")
	assert_ne(lances[0].mount_offset, 0.0)
	assert_almost_eq(body.mass, base_mass + 2000.0, 0.01)
	var lance = lances[1]
	lance.nails -= 1
	lance.emit_signal("nails_changed", lance.nails)
	assert_almost_eq(body.mass, base_mass + 1800.0, 0.01, "A spent lance is gone from the ship")
	assert_eq(GameState.player_lance_nails, 5, "Saved: the lances left in both")
	lance.restock()
	assert_almost_eq(body.mass, base_mass + 2000.0, 0.01, "Restocked")


class SpawnerStub:
	extends Node
	var replaced := 0
	func replace_player():
		replaced += 1


func _with_ships_and_cargo() -> void:
	_saved["assets_ships"] = TemplateDatabase.assets_ships
	_saved["presets"] = TemplateDatabase.presets
	_saved["assets_commodities"] = TemplateDatabase.assets_commodities
	var heavy = ShipTemplate.new()
	heavy.template_id = "preset_ship_archetype_fighter_heavy"
	heavy.base_value = 4000
	ship.template_id = "preset_ship_archetype_fighter_light"
	ship.base_value = 1200
	var stock = ShipTemplate.new()
	stock.template_id = "s_stock"
	TemplateDatabase.assets_ships = {"s_stock": stock}  # A stock hull: not sold (every ship flies a design)
	TemplateDatabase.presets = {"preset_ship_archetype_fighter_light": ship, "preset_ship_archetype_fighter_heavy": heavy}
	var fuel = CommodityTemplate.new()
	fuel.template_id = "c_fuel"
	fuel.base_value = 25
	TemplateDatabase.assets_commodities = {"c_fuel": fuel}


func test_store_sells_every_ship_part_and_only_the_cargo_the_station_makes():
	_with_ships_and_cargo()
	var drill = _tool("t_drill", "medium", 120, 900.0)
	drill.tool_type = "drill"
	TemplateDatabase.utility_tools["t_drill"] = drill
	assert_does_not_have(Fitting.catalog(), "t_drill", "Only the catalogue's parts")
	assert_has(Fitting.catalog(), "preset_thruster_medium", "every module of it")
	assert_has(Fitting.catalog(), "preset_laser_light", "and tool")
	for part_id in Fitting.catalog():
		assert_true(PartCatalog.has(part_id), part_id)
	assert_eq(Fitting.ship_catalog(), ["preset_ship_archetype_fighter_heavy", "preset_ship_archetype_fighter_light"], "the archetypes' hulls, no stock one")
	assert_eq(Fitting.cargo_stock(), [], "Cargo only where the station makes it: this one (no haven) makes none.")


func test_store_sells_the_archetypes_hulls_not_the_drafts():
	_with_ships_and_cargo()
	var design = ShipTemplate.new()
	design.template_id = "preset_ship_x1"
	design.base_value = 900
	var gun = _tool("preset_laser_x1", "small", 80, 500.0)
	TemplateDatabase.presets["preset_ship_x1"] = design
	TemplateDatabase.presets["preset_laser_x1"] = gun
	assert_does_not_have(Fitting.ship_catalog(), "preset_ship_x1", "Evolution's drafts are not for sale")
	assert_does_not_have(Fitting.catalog(), "preset_laser_x1", "nor their own parts")
	TemplateDatabase.presets.erase("preset_ship_x1")
	design.template_id = "preset_ship_archetype_x1"
	TemplateDatabase.presets["preset_ship_archetype_x1"] = design
	assert_has(Fitting.ship_catalog(), "preset_ship_archetype_x1", "an archetype's hull is")
	assert_eq(TemplateDatabase.get_template("preset_ship_archetype_x1"), design)
	design.tool_slots_small = 1
	design.module_slots = 1
	design.equipped_tools = ["preset_laser_x1"]
	var spawner = SpawnerStub.new()
	add_child_autofree(spawner)
	var saved_spawner = GlobalRefs.agent_spawner
	GlobalRefs.agent_spawner = spawner
	GameState.player_ship_template_id = "preset_ship_archetype_fighter_light"
	GameState.player_bank = 5000
	assert_eq(Fitting.buy_ship("preset_ship_archetype_x1"), "")
	assert_eq_deep(GameState.player_fit, {"tools": [""], "modules": [""]})  # A preset's hull comes bare: its price is the hull's
	GlobalRefs.agent_spawner = saved_spawner


func test_buying_a_ship_trades_the_old_one_in_and_stores_its_fit():
	_with_ships_and_cargo()
	var spawner = SpawnerStub.new()
	add_child_autofree(spawner)
	var saved_spawner = GlobalRefs.agent_spawner
	GlobalRefs.agent_spawner = spawner
	GameState.player_ship_template_id = "preset_ship_archetype_fighter_light"
	GameState.player_fit = {"tools": ["preset_laser_light", ""], "modules": ["preset_plating_heavy", ""]}
	GameState.player_bank = 5000
	GameState.player_hull_scars = [[1.0]]
	assert_eq(Fitting.ship_cost("preset_ship_archetype_fighter_heavy"), 4000 - 600, "Half the old hull's price comes off")
	assert_eq(Fitting.buy_ship("preset_ship_archetype_fighter_heavy"), "")
	assert_eq(GameState.player_bank, 5000 - 3400)
	assert_eq(GameState.player_ship_template_id, "preset_ship_archetype_fighter_heavy")
	assert_eq_deep(GameState.player_storage, {"preset_laser_light": 1, "preset_plating_heavy": 1})
	assert_eq_deep(GameState.player_fit, ShipFit.empty_fit(TemplateDatabase.get_template("preset_ship_archetype_fighter_heavy")))  # the new (preset) hull comes bare
	assert_true(GameState.player_hull_scars.empty(), "unmarked,")
	assert_eq(spawner.replaced, 1, "and the player's body is rebuilt.")
	assert_ne(Fitting.buy_ship("preset_ship_archetype_fighter_heavy"), "", "Already flying it")
	GameState.player_bank = 0
	assert_eq(Fitting.buy_ship("preset_ship_archetype_fighter_light"), "", "Trading down pays")
	assert_eq(GameState.player_bank, 2000 - 1200, "the difference.")
	GameState.player_bank = 1000
	assert_ne(Fitting.buy_ship("preset_ship_archetype_fighter_heavy"), "", "Short of WP")
	GameState.player_docked_at = ""
	GameState.player_bank = 100000
	assert_ne(Fitting.buy_ship("preset_ship_archetype_fighter_heavy"), "", "or not docked at home: nothing changes.")
	assert_eq(spawner.replaced, 2)
	GlobalRefs.agent_spawner = saved_spawner


func _biotech() -> void:
	var biotech = CommodityTemplate.new()
	biotech.template_id = "commodity_biotech"
	biotech.base_value = 60
	TemplateDatabase.assets_commodities["commodity_biotech"] = biotech


# Elace's Verdant Haven makes biotech (sells it at 0.7 of its value) and buys it back at 0.5.
func test_cargo_is_bought_where_it_is_made_as_npc_traders_buy_it():
	_with_ships_and_cargo()
	_biotech()
	var body = _player_ship()
	body.cargo_capacity = 2
	GameState.player_docked_at = "verdant_haven"
	GameState.station_markups = {"verdant_haven": 0.0}
	GameState.player_standing = {"verdant": 0.0}
	GameState.player_bank = 100
	assert_eq(Fitting.cargo_stock(), ["commodity_biotech"], "What the haven makes")
	assert_eq(Fitting.cargo_price("commodity_biotech"), 42, "at its price: 0.7 of 60")
	assert_ne(Fitting.buy_cargo(body, "c_fuel"), "", "Nothing it does not make")
	assert_eq(Fitting.buy_cargo(body, "commodity_biotech"), "")
	assert_eq(Fitting.buy_cargo(body, "commodity_biotech"), "")
	assert_eq(GameState.player_bank, 16)
	assert_eq_deep(GameState.player_cargo, {"commodity_biotech": 2})
	assert_ne(Fitting.buy_cargo(body, "commodity_biotech"), "", "Hold full")
	assert_eq(GameState.player_bank, 16, "costs nothing.")
	assert_eq(Fitting.sell_cargo(body, "commodity_biotech"), "")
	assert_eq(GameState.player_bank, 16 + 24, "Sold back at its cargo price: 0.5 of 60, PRICE_CARGO_SELL_SHARE of it")
	GameState.player_docked_at = "home"
	assert_ne(Fitting.buy_cargo(body, "commodity_biotech"), "", "A station that makes nothing sells nothing, the home port too")
	GameState.player_docked_at = ""
	assert_ne(Fitting.buy_cargo(body, "commodity_biotech"), "", "and nothing is bought in flight.")


func test_standing_with_the_home_factions_counts_in_the_store():
	GameState.home_location_id = "station_elace_home"  # The free port's
	GameState.player_docked_at = "station_elace_home"
	GameState.station_markups = {"station_elace_home": 0.0}
	GameState.player_standing = {"freeport": 0.0}
	var even: int = Fitting.price("preset_thruster_medium")
	var even_sale: int = Fitting.sale_price("preset_thruster_medium")
	assert_eq(even, 150)
	GameState.player_standing = {"freeport": 1.0}
	assert_eq(Fitting.price("preset_thruster_medium"), int(round(150 * (1.0 - Constants.PRICE_STANDING_SHARE))), "Trusted: cheaper")
	assert_true(Fitting.sale_price("preset_thruster_medium") > even_sale, "and sold dearer")


# The store covers the HUD (its menu button too): its own MENU opens the main menu.
func test_station_window_menu_button_opens_the_main_menu():
	GlobalRefs.player_agent_body = _player_ship()
	var window = load("res://scenes/ui/menus/fitting_window.tscn").instance()
	add_child_autofree(window)
	watch_signals(EventBus)
	window.get_node("Panel/Layout/Header/ButtonMenu").emit_signal("pressed")
	assert_signal_emitted(EventBus, "main_menu_requested")


func test_station_window_is_shown_while_docked_at_home():
	GlobalRefs.player_agent_body = _player_ship()
	var window = load("res://scenes/ui/menus/fitting_window.tscn").instance()
	add_child_autofree(window)
	EventBus.emit_signal("player_docked", "home")
	yield(get_tree(), "idle_frame")
	assert_true(window.visible, "Docking at home shows the station window")
	assert_string_starts_with(window.get_node("Panel/Layout/Header/Title").text, "DOCKED AT", "and says where the ship is docked.")
	EventBus.emit_signal("player_undocked")
	GameState.player_docked_at = ""
	assert_false(window.visible, "Undocking hides it.")
	# Docking again in flight: in the game the window can hear the signal before the player
	# controller has set player_docked_at (signal handler order is not fixed).
	window._on_player_docked("home")
	GameState.player_docked_at = "home"
	yield(get_tree(), "idle_frame")
	assert_true(window.visible, "Docking again shows it again.")
	EventBus.emit_signal("player_undocked")
	GameState.player_docked_at = "elsewhere"
	EventBus.emit_signal("player_docked", "elsewhere")
	yield(get_tree(), "idle_frame")
	assert_true(window.visible, "Other stations open it too, to sell the hold,")
	assert_eq(window._tab, "cargo", "on the cargo tab only")
	assert_false(window._slots.get_parent().visible, "with no refitting,")
	assert_false(window.get_node("Panel/Layout/Header/TabFitting").visible, "and no views to pick.")
	GlobalRefs.player_agent_body = null


# At home, two views: FITTING (the ship and storage) and MARKET (storage and the store).
func test_the_station_window_has_a_fitting_and_a_market_view():
	GlobalRefs.player_agent_body = _player_ship()
	var window = load("res://scenes/ui/menus/fitting_window.tscn").instance()
	add_child_autofree(window)
	GameState.player_docked_at = "home"
	window.open()
	var ship_column: Control = window._slots.get_parent()
	var storage_column: Control = window._storage.get_parent().get_parent()
	var store_column: Control = window._store.get_parent().get_parent()
	assert_eq(window.view, window.FITTING)
	assert_true(ship_column.visible and storage_column.visible, "FITTING: the ship beside storage")
	assert_false(store_column.visible, "and no store")
	assert_gt(window._stats.get_node("Ship").get_child_count(), 0, "The ship's numbers")
	assert_eq(window._ship_preview.ship_id, GameState.player_ship_template_id, "and its hull, turning")
	window.get_node("Panel/Layout/Header/TabMarket").emit_signal("pressed")
	assert_eq(window.view, window.MARKET)
	assert_true(storage_column.visible and store_column.visible, "MARKET: storage beside the store")
	assert_false(ship_column.visible, "and no ship column")
	assert_eq(window.get_node("Panel/Layout/Header/TabMarket").text, "[MARKET]")
	window.get_node("Panel/Layout/Header/TabFitting").emit_signal("pressed")
	assert_true(ship_column.visible, "and back")
	GameState.player_docked_at = ""
	GlobalRefs.player_agent_body = null


func test_docking_never_sells_the_hold_the_player_sells_it_anywhere():
	_with_ships_and_cargo()
	var body = _player_ship()
	body.cargo_capacity = 10
	body.add_cargo("c_fuel", 3)
	GameState.player_docked_at = "elsewhere"
	GameState.player_bank = 0
	var price: int = Fitting.cargo_sale_price("c_fuel")
	assert_true(price > 0)
	assert_eq(Fitting.sell_cargo(body, "c_fuel", -1), "", "All of it")
	assert_eq(GameState.player_bank, 3 * price)
	assert_eq(int(body.cargo.get("c_fuel", 0)), 0)
	GameState.player_docked_at = ""
	body.add_cargo("c_fuel", 1)
	assert_ne(Fitting.sell_cargo(body, "c_fuel"), "", "Not docked: no sale")
	var HomePort = load("res://src/core/systems/home_port.gd")
	GameState.player_docked_at = GameState.home_location_id
	HomePort.service(body)
	assert_eq(int(body.cargo.get("c_fuel", 0)), 1, "Home service repairs and rearms; it sells nothing")


func test_a_small_reactor_runs_quieter():
	var reference: float = ShipLaws.apply_law(Constants.LAW_REGEN, 6000.0 * Constants.LAW_SHIP_SHARES.reactor)
	assert_almost_eq(ShipFit.reactor_signature_factor(6000.0, reference, reference), 1.0, 0.0001, "A reference ship's own reactor")
	assert_almost_eq(ShipFit.reactor_signature_factor(6000.0, reference, reference * 0.5), 1.0 - Constants.SIG_REACTOR_SHARE * 0.5, 0.0001, "Half the power: quieter")
	assert_gt(ShipFit.reactor_signature_factor(6000.0, reference, reference * 2.0), 1.0, "Power cells on top: louder")
	assert_eq(ShipFit.reactor_signature_factor(6000.0, 0.0, 0.0), 1.0, "No reactor law: as it is")


func test_a_damper_jams_and_draws_power():
	TemplateDatabase.assets_modules["m_damper"] = _module("m_damper", 75, 300.0, {"damper_mass": 300.0})
	ship.power_regen = 10.0
	var stats: Dictionary = ShipFit.compute_stats(ship, {"tools": [], "modules": ["m_damper"]})
	assert_almost_eq(stats.jamming, ShipFit.damper_share(300.0, 6000.0), 0.0001)
	assert_almost_eq(stats.power_regen, 10.0 - 300.0 * Constants.LAW_DAMPER_POWER_PER_KG, 0.0001, "Active: it runs off the reactor")


func test_a_damper_jams_more_for_a_small_hull():
	assert_almost_eq(ShipFit.damper_share(300.0, 6000.0), Constants.LAW_DAMPER_SHARE, 0.001, "5% of the hull's mass: the reference share")
	assert_lt(ShipFit.damper_share(300.0, 24000.0), ShipFit.damper_share(300.0, 6000.0), "The same damper hides less of a bigger ship")
	assert_eq(ShipFit.damper_share(5000.0, 6000.0), Constants.LAW_DAMPER_MAX, "and never all of it")
	assert_eq(ShipFit.damper_share(0.0, 6000.0), 0.0)


func test_the_home_port_sells_its_goods_and_fuel_not_ore():
	_with_ships_and_cargo()
	for id in ["commodity_biotech", "commodity_tech", "commodity_fuel", "commodity_ore"]:
		var item = CommodityTemplate.new()
		item.template_id = id
		item.base_value = 50
		TemplateDatabase.assets_commodities[id] = item
	GameState.home_location_id = "station_elace_home"
	GameState.player_docked_at = "station_elace_home"
	assert_eq(Fitting.cargo_stock(), ["commodity_biotech", "commodity_fuel", "commodity_tech"],
		"Elace's free port: what it makes, and fuel for jumps (as travellers buy it); no ore, which comes from the rocks")


# The hull preview's viewport renders only while it is seen: off on another tab or with the window
# closed, on in the ships tab.
func test_the_hull_preview_renders_only_while_seen():
	var window = load("res://scenes/ui/menus/fitting_window.tscn").instance()
	add_child_autofree(window)
	var preview = window.get_node("Panel/Layout/Body/Content/Columns/Store/HullPreview")
	var viewport: Viewport = preview.get_node("Viewport")
	assert_false(window.visible)
	assert_eq(viewport.render_target_update_mode, Viewport.UPDATE_DISABLED, "Window closed: not rendered")
	window.visible = true
	preview.visible = false
	assert_eq(viewport.render_target_update_mode, Viewport.UPDATE_DISABLED, "Another tab: not rendered")
	preview.visible = true
	assert_eq(viewport.render_target_update_mode, Viewport.UPDATE_ALWAYS, "Ships tab: rendered")
	window.visible = false
	assert_eq(viewport.render_target_update_mode, Viewport.UPDATE_DISABLED, "and not once the window closes.")
