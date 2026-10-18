# HomePort: what docking at the run's home station does. Cargo is banked at its commodities'
# base value, and the ship is repaired (hull restored, damage marks cleared). Banked value is the
# run's score and, later, what fitting is paid with.

extends Reference


static func is_home(location_id: String) -> bool:
	return location_id != "" and location_id == GameState.home_location_id


# Banks the ship's cargo and repairs it. Returns {"banked": value added, "units": units sold,
# "repaired": hull points restored}.
static func service(ship: Node) -> Dictionary:
	var result := {"banked": 0, "units": 0, "repaired": 0.0}
	if not is_instance_valid(ship):
		return result
	for commodity_id in ship.cargo:
		var commodity = TemplateDatabase.get_template(commodity_id)
		var units: int = int(ship.cargo[commodity_id])
		result.units += units
		if commodity is CommodityTemplate:
			result.banked += units * commodity.base_value
	ship.clear_cargo()
	GameState.player_bank += result.banked
	result.repaired = ship.repair_hull()
	return result
