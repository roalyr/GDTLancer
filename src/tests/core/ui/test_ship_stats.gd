# Tests for ShipStats: the docking view's ship numbers, one way for the ship flown and the store's
# hulls, each coloured by what it is about; and the power flow, red where it drains.

extends GutTest

const ShipStats = preload("res://src/core/ui/helpers/ship_stats.gd")

const STATS = {"hull": 85.0, "power_capacity": 117.0, "power_regen": 6.0, "cargo_capacity": 31.0, "linear_thrust": 480000.0,
	"signature": 1200.0, "sensor_strength": 1.0}


func _by_caption(items: Array) -> Dictionary:
	var out := {}
	for item in items:
		out[item.caption] = item
	return out


func test_the_numbers_and_their_looks():
	var ship := ShipTemplate.new()
	ship.tool_slots_small = 2
	ship.tool_slots_medium = 1
	ship.module_slots = 1
	var items: Dictionary = _by_caption(ShipStats.entries(STATS, 5600.0, ship))
	assert_eq(items.HULL.value, "85")
	assert_eq(items.HULL.look, "StatHull")
	assert_eq(items.POWER.look, "StatPower", "Power blue, as the HUD's energy bar")
	assert_eq(items.CARGO.look, "StatCargo", "cargo tan, as its bar")
	assert_eq(items["TOP SPEED"].value, "%d m/s" % int(480000.0 / (5600.0 * Constants.LINEAR_DRAG)))
	assert_eq(items.MASS.value, "5.6 t")
	assert_eq(items.TOOLS.value, "2 SMALL + 1 MEDIUM", "The slots, when the hull is known")
	var brief: Dictionary = _by_caption(ShipStats.entries(STATS, 5600.0, ship, true))
	assert_false(brief.has("SIGNATURE"), "The store's rows: what tells hulls apart")
	assert_true(brief.has("TOP SPEED"))
	var theme: Theme = load("res://assets/themes/main_theme.tres")
	for look in ["StatCaption", "StatHull", "StatPower", "StatCargo", "StatMotion", "StatSensors", "StatWarning"]:
		assert_true(theme.get(look + "/base_type") != null, "main_theme has the look " + look)


func test_the_power_flow_warns_when_it_drains():
	var items: Dictionary = _by_caption(ShipStats.power_entries(6.0, 0.0, 10.0, 120.0, 0.0))
	assert_eq(items.NET.value, "-4.0/s")
	assert_eq(items.NET.look, "StatWarning", "A drain reads red")
	assert_eq(items["FULL TO EMPTY"].value, "30 s")
	items = _by_caption(ShipStats.power_entries(6.0, 0.0, 5.0, 120.0, 0.0))
	assert_eq(items.NET.look, "StatPower")
	assert_false(items.has("FULL TO EMPTY"))


func test_fill_lays_out_a_caption_over_each_value():
	var grid = ShipStats.new_grid(4)
	add_child_autofree(grid)
	ShipStats.fill(grid, ShipStats.entries(STATS, 5600.0))
	var cell: Node = grid.get_node("HULL")
	assert_eq(cell.get_node("Caption").text, "HULL")
	assert_eq(cell.get_node("Value").text, "85")
	assert_eq(cell.get_node("Value").theme_type_variation, "StatHull")
	ShipStats.fill(grid, ShipStats.entries(STATS, 5600.0, null, true))
	assert_eq(grid.get_child_count(), 6, "Refilled: the old cells gone")
