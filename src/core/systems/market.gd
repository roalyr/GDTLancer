# Market: what a station charges and pays. A price is the physics value (ShipLaws base_value; a
# commodity's base value) plus the station's own markup, rolled in 0..PRICE_MARKUP_MAX and rolled
# again every PRICE_MARKUP_PERIOD s or so of world time (GameState.station_markups, saved), then the player's standing with the station's faction
# (Standing): standing 1 buys PRICE_STANDING_SHARE cheaper and sells as much dearer, -1 the reverse.
# A station pays PRICE_CARGO_SELL_SHARE of its price for cargo, PRICE_PART_SELL_SHARE for parts; the
# spread keeps buying and selling at one station from paying. Stations differ, so carrying cargo from
# one to another can. A haven (Havens) pays its own factor on that per commodity, and buys nothing
# it does not list.

extends Reference

const Standing = preload("res://src/core/systems/standing.gd")
const Havens = preload("res://src/core/systems/havens.gd")


static func markup(location_id: String) -> float:
	var known: bool = GameState.station_markups.has(location_id)
	if not known or GameState.world_time >= float(GameState.station_markup_until.get(location_id, INF)):
		GameState.station_markups[location_id] = randf() * Constants.PRICE_MARKUP_MAX
		known = false
	if not known or not GameState.station_markup_until.has(location_id):  # A markup from an older save keeps its value till then
		GameState.station_markup_until[location_id] = GameState.world_time + rand_range(Constants.PRICE_MARKUP_PERIOD[0], Constants.PRICE_MARKUP_PERIOD[1])
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


# What one unit of `commodity_id` fetches at the station (0: it does not buy it).
static func commodity_sale_price(commodity_id: String, location_id: String, faction: String = "") -> int:
	var commodity = TemplateDatabase.get_template(commodity_id)
	var share: float = Havens.buys(location_id, commodity_id)
	if not (commodity is CommodityTemplate) or share <= 0.0:
		return 0
	return cargo_sale_price(float(commodity.base_value) * share, location_id, faction)


# What the hold fetches at the station, all but the fuel and what it does not buy, at a stranger's
# price (no standing: NPCs). Returns {"value", "units", "mass" (kg), "sold": [commodity ids]}; the
# hold is left as it is.
static func hold_value(ship: Node, location_id: String) -> Dictionary:
	var result := {"value": 0, "units": 0, "mass": 0.0, "sold": []}
	for commodity_id in ship.cargo:
		if commodity_id == Constants.FUEL_COMMODITY or Havens.buys(location_id, commodity_id) <= 0.0:
			continue
		var commodity = TemplateDatabase.get_template(commodity_id)
		var units: int = int(ship.cargo[commodity_id])
		result.units += units
		result.sold.append(commodity_id)
		result.value += units * commodity_sale_price(commodity_id, location_id)
		if commodity is CommodityTemplate:
			result.mass += units * float(commodity.unit_mass)
	return result


# Sells the hold to the station into the bank, all but the fuel and what it does not buy. Returns
# {"banked", "units"}.
static func sell_hold(ship: Node, location_id: String, faction: String = "") -> Dictionary:
	var result := {"banked": 0, "units": 0}
	for commodity_id in ship.cargo.keys():
		if commodity_id == Constants.FUEL_COMMODITY or Havens.buys(location_id, commodity_id) <= 0.0:
			continue
		var units: int = int(ship.cargo[commodity_id])
		result.units += units
		result.banked += units * commodity_sale_price(commodity_id, location_id, faction)
		ship.remove_cargo(commodity_id, units)
	GameState.player_bank += result.banked
	return result
