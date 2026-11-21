# ShipWindow (scenes/ui/menus/ship_window.tscn): the HUD's SHIP button. The ship flown, read only:
# what it is worth, how it stands now (hull, power, speed), its stats and power flow (ShipStats, as
# the docking view shows them), every slot and what sits in it (rounds left in a magazine, lances in a quiver),
# decoys and the hold. Refitting is at home, docked.

extends "res://src/core/ui/info_window/info_window.gd"

const Fitting = preload("res://src/core/systems/fitting.gd")
const ShipFit = preload("res://src/core/systems/ship_fit.gd")
const FittingWindow = preload("res://src/core/ui/fitting_window/fitting_window.gd")
const ShipStats = preload("res://src/core/ui/helpers/ship_stats.gd")


func fill() -> void:
	var ship = GlobalRefs.player_agent_body
	if not is_instance_valid(ship) or ship.get("fit") == null or ship.get("fit_stats") == null:
		_title.text = "SHIP"
		_summary.text = "NO SHIP"
		_summary.visible = true
		$Panel/Layout/Stats.visible = false
		return
	_summary.visible = false
	_title.text = "%s  -  WORTH %d WP" % [Fitting.part_name(GameState.player_ship_template_id).to_upper(), int(ship.get_value())]
	var stats: Node = $Panel/Layout/Stats
	stats.visible = true
	ShipStats.fill(stats.get_node("Now"), ShipStats.now_entries(ship.hull, ship.hull_max, ship.power, ship.power_max,
		ship.linear_velocity.length(), ship.get_top_speed()))
	ShipStats.fill(stats.get_node("Ship"), ShipStats.entries(ship.fit_stats, ship.mass, ship.get("ship_template")))
	var flow: Dictionary = FittingWindow.power_numbers(ship)
	ShipStats.fill(stats.get_node("Power"), ShipStats.power_entries(flow.regen, flow.damper, flow.tools_draw, flow.power_max, flow.afterburner))
	_fill_tools(ship)
	_fill_modules(ship)
	_fill_hold(ship)
	add_note("Refit at home: dock at %s." % station_name(GameState.home_location_id))


func _fill_tools(ship) -> void:
	add_heading("Tools")
	var sizes: Array = ShipFit.tool_slot_sizes(ship.ship_template)
	var tools = ship.get_node_or_null("ToolController")
	var fitted_index: int = 0  # ToolController holds the fitted tools only, in slot order
	for i in range(ship.fit.tools.size()):
		var part_id: String = ship.fit.tools[i]
		var size: String = str(sizes[i]).capitalize() if i < sizes.size() else ""
		if part_id == "":
			add_row("%s slot: empty" % size, "")
			continue
		var detail: String = FittingWindow.part_detail(part_id)
		if is_instance_valid(tools) and fitted_index < tools.get_tool_count() and tools.has_magazine(fitted_index):
			detail += "\n%d / %d rounds" % [tools.get_ammo(fitted_index), tools.get_capacity(fitted_index)]
		fitted_index += 1
		add_row("%s slot: %s" % [size, Fitting.part_name(part_id)], detail)
	if ship.fit.tools.empty():
		add_note("No tool slots")


func _fill_modules(ship) -> void:
	add_heading("Modules")
	var size: String = ShipFit.module_slot_size(ship.ship_template).capitalize()
	for i in range(ship.fit.modules.size()):
		var part_id: String = ship.fit.modules[i]
		add_row("%s slot: %s" % [size, Fitting.part_name(part_id) if part_id != "" else "empty"], FittingWindow.part_detail(part_id) if part_id != "" else "")
	if ship.fit.modules.empty():
		add_note("No module slots")
	var stores: Array = []
	for lance in ship.get_lances():
		stores.append("%d / %d lances" % [lance.nails, int(lance.lance.count)])
	if ship.get_decoy_capacity() > 0:
		stores.append("%d / %d decoys" % [ship.decoys, ship.get_decoy_capacity()])
	if not stores.empty():
		add_note("Carried: " + PoolStringArray(stores).join(", ") + ". Home restocks them when you dock.")


func _fill_hold(ship) -> void:
	add_heading("Hold  %d / %d  worth %d WP" % [ship.get_cargo_units(), ship.cargo_capacity, int(ship.get_cargo_value())])
	var ids: Array = ship.cargo.keys()
	ids.sort()
	for commodity_id in ids:
		if int(ship.cargo[commodity_id]) > 0:
			add_row("%s  x%d" % [Fitting.part_name(commodity_id), int(ship.cargo[commodity_id])], "")
	if ship.get_cargo_units() <= 0:
		add_note("The hold is empty")
