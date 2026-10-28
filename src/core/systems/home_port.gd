# HomePort: what docking at the run's home station does. Cargo is sold into the bank at the
# station's cargo price (Market), and the ship is repaired (hull restored, scars cleared). Banked
# value is the run's score and what fitting is paid with.

extends Reference

const Market = preload("res://src/core/systems/market.gd")


static func is_home(location_id: String) -> bool:
	return location_id != "" and location_id == GameState.home_location_id


# Banks the ship's cargo, repairs it and refills its lance quiver and magazines (paid from the bank,
# a lance's part value and a round's value each at the station's prices, as many as the bank covers). Returns {"banked":
# value added, "units": units sold, "repaired": hull points restored, "lances": lances bought,
# "lance_cost": WP paid, "rounds": missiles and rounds bought, "ammo_cost": WP paid, "decoys": decoys
# bought, at LAW_DECOY_VALUE each before the markup, "decoy_cost"}.
static func service(ship: Node) -> Dictionary:
	var result := {"banked": 0, "units": 0, "repaired": 0.0, "lances": 0, "lance_cost": 0, "rounds": 0, "ammo_cost": 0, "decoys": 0, "decoy_cost": 0}
	if not is_instance_valid(ship):
		return result
	var sold: Dictionary = Market.sell_hold(ship, GameState.home_location_id)
	result.banked = sold.banked
	result.units = sold.units
	result.repaired = ship.repair_hull()
	for lance in (ship.get_lances() if ship.has_method("get_lances") else []):
		var price: int = Market.price(float(lance.lance.nail_value), GameState.home_location_id)
		var bought: int = lance.restock(-1 if price <= 0 else int(max(0, GameState.player_bank / price)))
		result.lances += bought
		result.lance_cost += bought * price
		GameState.player_bank -= bought * price
	var tools = ship.get_node_or_null("ToolController")
	if tools != null and tools.has_method("restock_ammo"):
		for index in range(tools.get_tool_count()):
			if not tools.has_magazine(index):
				continue
			var tool_template = tools.get_tool(index)
			var price: int = int(max(1, Market.price(float(tool_template.round_value), GameState.home_location_id)))
			var room: int = int(tool_template.ammo) - tools.get_ammo(index)
			var take: int = int(min(room, max(0, GameState.player_bank / price)))
			if take <= 0:
				continue
			tools._set_ammo(index, tools.get_ammo(index) + take)
			result.rounds += take
			result.ammo_cost += take * price
			GameState.player_bank -= take * price
	if ship.has_method("restock_decoys"):
		var want: int = ship.get_decoy_capacity() - ship.decoys
		var decoy_price: int = int(max(1, Market.price(float(Constants.LAW_DECOY_VALUE), GameState.home_location_id)))
		var afford: int = int(min(want, max(0, GameState.player_bank / decoy_price)))
		if afford > 0:
			ship.decoys += afford
			result.decoys = afford
			result.decoy_cost = afford * decoy_price
			GameState.player_bank -= result.decoy_cost
	return result
