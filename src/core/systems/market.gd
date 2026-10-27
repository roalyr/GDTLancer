# Market: what a station charges and pays. A price is the physics value (ShipLaws base_value; a
# commodity's base value) plus the station's own markup, rolled once per game in 0..PRICE_MARKUP_MAX
# (GameState.station_markups, saved), then the player's standing with the station's faction
# (Standing): standing 1 buys PRICE_STANDING_SHARE cheaper and sells as much dearer, -1 the reverse.
# A station pays PRICE_CARGO_SELL_SHARE of its price for cargo, PRICE_PART_SELL_SHARE for parts; the
# spread keeps buying and selling at one station from paying. Stations differ, so carrying cargo from
# one to another can.

extends Reference

const Standing = preload("res://src/core/systems/standing.gd")


static func markup(location_id: String) -> float:
	if not GameState.station_markups.has(location_id):
		GameState.station_markups[location_id] = randf() * Constants.PRICE_MARKUP_MAX
	return float(GameState.station_markups[location_id])


# What the station charges per WP of value.
static func buy_factor(location_id: String, faction: String = "") -> float:
	return (1.0 + markup(location_id)) * (1.0 - Constants.PRICE_STANDING_SHARE * Standing.of(faction))


# What the station pays per WP of value, for cargo (for parts, times PRICE_PART_SELL_SHARE / PRICE_CARGO_SELL_SHARE: see part_sale_price).
static func sell_factor(location_id: String, faction: String = "") -> float:
	return (1.0 + markup(location_id)) * Constants.PRICE_CARGO_SELL_SHARE * (1.0 + Constants.PRICE_STANDING_SHARE * Standing.of(faction))


static func price(value: float, location_id: String, faction: String = "") -> int:
	return int(round(value * buy_factor(location_id, faction))) if value > 0.0 else 0


static func cargo_sale_price(value: float, location_id: String, faction: String = "") -> int:
	return int(round(value * sell_factor(location_id, faction))) if value > 0.0 else 0


static func part_sale_price(value: float, location_id: String, faction: String = "") -> int:
	return int(Constants.PRICE_PART_SELL_SHARE * price(value, location_id, faction))


# Sells the hold to the station into the bank, all but the fuel. Returns {"banked", "units"}.
static func sell_hold(ship: Node, location_id: String, faction: String = "") -> Dictionary:
	var result := {"banked": 0, "units": 0}
	for commodity_id in ship.cargo.keys():
		if commodity_id == Constants.FUEL_COMMODITY:
			continue
		var commodity = TemplateDatabase.get_template(commodity_id)
		var units: int = int(ship.cargo[commodity_id])
		result.units += units
		if commodity is CommodityTemplate:
			result.banked += units * cargo_sale_price(float(commodity.base_value), location_id, faction)
		ship.remove_cargo(commodity_id, units)
	GameState.player_bank += result.banked
	return result
