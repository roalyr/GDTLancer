# ShipStats: a ship's numbers as the docking view shows them, the same for the ship flown (its
# header) and the store's hulls (their rows): each a small dim caption over its value, coloured by
# what it is about, as the HUD's bars are (main_theme's Stat* looks: hull white, power blue, cargo
# tan, motion green, sensors amber; what runs the power down, StatWarning). `entries` makes them,
# `fill` lays them out in a grid of fixed columns. Not a flow container: in a scrolled list its
# height hangs on its width and the layout never settled (the docking view hung).

extends Reference

const ShipFit = preload("res://src/core/systems/ship_fit.gd")

const SLOT_SIZES = ["small", "medium", "large"]
const HULL_LOW_SHARE = 0.35  # As the HUD's hull bar (awareness_zone.tscn Hull low_share)


# The fitted numbers (`stats`: ShipFit.compute_stats) of `ship` (a ShipTemplate, for its slots;
# null: none shown), `mass` kg. `brief`: what tells hulls apart in the store, not every number.
# [{"caption", "value", "look"}].
static func entries(stats: Dictionary, mass: float, ship = null, brief: bool = false) -> Array:
	var out: Array = []
	var thrust: float = float(stats.get("linear_thrust", 0.0))
	var top_speed: float = thrust / max(mass * Constants.LINEAR_DRAG, 0.001)
	out.append(_entry("HULL", "%d" % int(stats.get("hull", 0.0)), "StatHull"))
	out.append(_entry("POWER", "%d" % int(stats.get("power_capacity", 0.0)), "StatPower"))
	out.append(_entry("CHARGE", "+%d/s" % int(stats.get("power_regen", 0.0)), "StatPower"))
	out.append(_entry("CARGO", "%d" % int(stats.get("cargo_capacity", 0.0)), "StatCargo"))
	out.append(_entry("TOP SPEED", "%d m/s" % int(top_speed), "StatMotion"))
	if not brief:
		out.append(_entry("THRUST", "%d kN" % int(thrust / 1000.0), "StatMotion"))
	out.append(_entry("MASS", "%.1f t" % (mass / 1000.0), "StatMotion"))
	if not brief:
		out.append(_entry("SIGNATURE", "%.1f km" % (float(stats.get("signature", 0.0)) / 1000.0), "StatSensors"))
		out.append(_entry("SENSORS", "x%.1f" % float(stats.get("sensor_strength", 1.0)), "StatSensors"))
	if ship is ShipTemplate:
		var tools: Array = []
		for size in SLOT_SIZES:
			var count: int = int(ship.get("tool_slots_" + size))
			if count > 0:
				tools.append("%d %s" % [count, size.to_upper()])
		out.append(_entry("TOOLS", PoolStringArray(tools).join(" + ") if not tools.empty() else "NONE", "StatHull"))
		out.append(_entry("MODULES", "%d %s" % [ship.module_slots, ShipFit.module_slot_size(ship).to_upper()] if ship.module_slots > 0 else "NONE", "StatHull"))
	return out


# How the ship stands now (the HUD's SHIP window): hull, power and speed against their most;
# StatWarning when the hull is as low as the HUD's bar flags it.
static func now_entries(hull: float, hull_max: float, power: float, power_max: float, speed: float, top_speed: float) -> Array:
	var low: bool = hull_max > 0.0 and hull / hull_max < HULL_LOW_SHARE
	return [_entry("HULL NOW", "%d / %d" % [ceil(hull), hull_max], "StatWarning" if low else "StatHull"),
		_entry("POWER NOW", "%d / %d" % [floor(power), power_max], "StatPower"),
		_entry("SPEED NOW", "%d / %d m/s" % [speed, top_speed], "StatMotion")]


# Where the power goes (FittingWindow.power_flow's numbers): the reactor's charge, a damper's draw,
# the tools' draw all on, the net (StatWarning when it drains), the afterburner's.
static func power_entries(regen: float, damper: float, tools_draw: float, power_max: float, afterburner: float) -> Array:
	var out: Array = [_entry("REACTOR", "+%.1f/s" % (regen + damper), "StatPower")]
	if damper > 0.0:
		out.append(_entry("DAMPER", "-%.1f/s" % damper, "StatWarning"))
	if tools_draw > 0.0:
		var net: float = regen - tools_draw
		out.append(_entry("TOOLS ON", "-%.1f/s" % tools_draw, "StatPower"))
		out.append(_entry("NET", "%s%.1f/s" % ["+" if net >= 0.0 else "-", abs(net)], "StatPower" if net >= 0.0 else "StatWarning"))
		if net < 0.0:
			out.append(_entry("FULL TO EMPTY", "%d s" % int(power_max / -net), "StatWarning"))
	if afterburner > 0.0:
		out.append(_entry("AFTERBURNER", "-%.1f/s" % afterburner, "StatWarning"))
	return out


# Lays `items` out in `container` (a GridContainer: new_grid), its old ones gone.
static func fill(container: Control, items: Array) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for item in items:
		var cell := VBoxContainer.new()
		cell.name = item.caption.replace(" ", "_")
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_constant_override("separation", -2)
		var caption := Label.new()
		caption.name = "Caption"
		caption.theme_type_variation = "StatCaption"
		caption.text = item.caption
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var value := Label.new()
		value.name = "Value"
		value.theme_type_variation = item.look
		value.text = item.value
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(caption)
		cell.add_child(value)
		container.add_child(cell)


# A grid for `fill`, `columns` wide, spaced as the docking view's.
static func new_grid(columns: int, name: String = "Stats") -> GridContainer:
	var grid := GridContainer.new()
	grid.name = name
	grid.columns = columns
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_constant_override("hseparation", 36)
	grid.add_constant_override("vseparation", 6)
	return grid


# The entries as a line of text: "HULL 85   POWER 117   ..." (the ship window, the tests).
static func text(items: Array) -> String:
	var parts: Array = []
	for item in items:
		parts.append("%s %s" % [item.caption, item.value])
	return PoolStringArray(parts).join("   ")


static func _entry(caption: String, value: String, look: String) -> Dictionary:
	return {"caption": caption, "value": value, "look": look}
