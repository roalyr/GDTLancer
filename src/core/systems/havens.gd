# Havens: what a sector's havens (Constants SECTOR_LAYOUTS) offer and to whom: their services
# (repair, rearm, what they buy at what price factor) and who is welcome. A station that is no
# haven (another sector's, a hand-made one) buys everything at its cargo price and serves everyone.

extends Reference


# The haven entry with id `location_id` in any sector's layout, or {}.
static func spec(location_id: String) -> Dictionary:
	for sector_id in Constants.SECTOR_LAYOUTS:
		for haven in Constants.SECTOR_LAYOUTS[sector_id].get("havens", []):
			if haven.id == location_id:
				return haven
	return {}


# The havens of `sector_id` with ships living from them (the evolving NPCs' groups).
static func populated(sector_id: String) -> Array:
	var found: Array = []
	for haven in Constants.SECTOR_LAYOUTS.get(sector_id, {}).get("havens", []):
		if not haven.get("ships", {}).empty():
			found.append(haven)
	return found


# Price factor the station pays for `commodity_id` on its cargo price; 0 if it does not buy it.
static func buys(location_id: String, commodity_id: String) -> float:
	var haven: Dictionary = spec(location_id)
	if haven.empty():
		return 1.0
	var prices: Dictionary = haven.get("services", {}).get("buys", {})
	return float(prices.get(commodity_id, prices.get("*", 0.0)))


# Whether the station repairs ("repair") or refills lances, rounds and decoys ("rearm").
static func offers(location_id: String, service: String) -> bool:
	var haven: Dictionary = spec(location_id)
	return haven.empty() or bool(haven.get("services", {}).get(service, false))


static func faction_of(location_id: String) -> String:
	return str(spec(location_id).get("faction", ""))


# Whether an NPC of `faction` docks there: its own faction's haven, or a neutral one unless it is a
# raider or the xenohive (outlaws and aliens have only their own).
static func welcome(faction: String, location_id: String) -> bool:
	var owner: String = faction_of(location_id)
	if owner != "":
		return owner == faction
	return not faction in ["raiders", "xenohive"]
