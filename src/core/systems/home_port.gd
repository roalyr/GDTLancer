# HomePort: what docking at the run's home station does. Cargo is banked at its commodities'
# base value, and the ship is repaired (hull restored, scars cleared). Banked value is the
# run's score and, later, what fitting is paid with.

extends Reference


static func is_home(location_id: String) -> bool:
	return location_id != "" and location_id == GameState.home_location_id


# Banks the ship's cargo, repairs it and refills its lance quiver and magazines (paid from the bank,
# a lance's part value and a round's value each, as many as the bank covers). Returns {"banked":
# value added, "units": units sold, "repaired": hull points restored, "lances": lances bought,
# "lance_cost": WP paid, "rounds": missiles and rounds bought, "ammo_cost": WP paid}.
static func service(ship: Node) -> Dictionary:
	var result := {"banked": 0, "units": 0, "repaired": 0.0, "lances": 0, "lance_cost": 0, "rounds": 0, "ammo_cost": 0}
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
	var lance = ship.get_lance() if ship.has_method("get_lance") else null
	if lance != null:
		var price: int = int(lance.lance.nail_value)
		result.lances = lance.restock(-1 if price <= 0 else int(max(0, GameState.player_bank / price)))
		result.lance_cost = result.lances * price
		GameState.player_bank -= result.lance_cost
	var tools = ship.get_node_or_null("ToolController")
	if tools != null and tools.has_method("restock_ammo"):
		for index in range(tools.get_tool_count()):
			if not tools.has_magazine(index):
				continue
			var tool_template = tools.get_tool(index)
			var price: int = int(max(1, tool_template.round_value))
			var room: int = int(tool_template.ammo) - tools.get_ammo(index)
			var take: int = int(min(room, max(0, GameState.player_bank / price)))
			if take <= 0:
				continue
			tools._set_ammo(index, tools.get_ammo(index) + take)
			result.rounds += take
			result.ammo_cost += take * price
			GameState.player_bank -= take * price
	return result
