# Havens: what a sector's havens (the sector's layout scene) offer and to whom: their services
# (repair, rearm, what they buy at what price factor) and who is welcome. A station that is no
# haven (another sector's, a hand-made one) buys everything at its cargo price and serves everyone.

extends Reference


# The haven entry with id `location_id` in any sector's layout, or {}.
static func spec(location_id: String) -> Dictionary:
	for sector_id in TemplateDatabase.sector_layouts:
		for haven in TemplateDatabase.sector_layouts[sector_id].get("havens", []):
			if haven.id == location_id:
				return haven
	return {}


# The ids of the other havens in the sector of the haven `location_id` (where its traders can sell).
static func neighbours(location_id: String) -> Array:
	for sector_id in TemplateDatabase.sector_layouts:
		var ids: Array = []
		var found := false
		for haven in TemplateDatabase.sector_layouts[sector_id].get("havens", []):
			if haven.id == location_id:
				found = true
			else:
				ids.append(haven.id)
		if found:
			return ids
	return []


# Whether `faction` has anywhere to trade: a haven that welcomes it and sells something. Without
# one its traders would only fly between stations (the raiders, the xenohive: the trade gene is
# inert for them, Evolution keeps it at 0).
static func trades(faction: String) -> bool:
	for sector_id in TemplateDatabase.sector_layouts:
		for haven in TemplateDatabase.sector_layouts[sector_id].get("havens", []):
			if not haven.get("services", {}).get("sells", {}).empty() and welcome(faction, haven.id):
				return true
	return false


# The havens of `sector_id` with ships living from them (the evolving NPCs' groups).
static func populated(sector_id: String) -> Array:
	var found: Array = []
	for haven in TemplateDatabase.sector_layouts.get(sector_id, {}).get("havens", []):
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


# What the station sells, commodity id -> price factor on its value ({} if nothing): what it makes.
static func sells(location_id: String) -> Dictionary:
	return spec(location_id).get("services", {}).get("sells", {})


# Whether the station repairs ("repair") or refills lances, rounds and decoys ("rearm").
static func offers(location_id: String, service: String) -> bool:
	var haven: Dictionary = spec(location_id)
	return haven.empty() or bool(haven.get("services", {}).get(service, false))


static func faction_of(location_id: String) -> String:
	return str(spec(location_id).get("faction", ""))


# Outlaws (FactionTemplate.outlaw) and aliens (no_standing) dock only at their own havens and let no
# other faction dock at theirs.
# `factions`: faction id -> FactionTemplate.to_spec() (TemplateDatabase.factions in play).
static func keeps_to_itself(faction: String, factions = null) -> bool:
	var faction_spec: Dictionary = (TemplateDatabase.factions if factions == null else factions).get(faction, {})
	return faction_spec.get("outlaw", false) or faction_spec.get("no_standing", false)


# Whether an NPC of `faction` docks there: its own faction's haven, or a neutral one (or an open
# faction's: FactionTemplate.open_havens, the free port) unless it is an outlaw or an alien
# (keeps_to_itself). An open faction's own ships (the free port's: it trades with everyone) dock at
# any other faction's haven too, but the outlaws', the aliens' and those at war with it.
static func welcome(faction: String, location_id: String) -> bool:
	return welcome_at(faction, faction_of(location_id), TemplateDatabase.factions)


# The same rule for a haven owned by `owner` ("" neutral), with the factions given (the dev tool
# passes the faction files as they are on disk).
static func welcome_at(faction: String, owner: String, factions: Dictionary) -> bool:
	if owner == faction and owner != "":
		return true
	if keeps_to_itself(faction, factions):
		return false
	if owner == "" or factions.get(owner, {}).get("open_havens", false):
		return true
	if not factions.get(faction, {}).get("open_havens", false) or keeps_to_itself(owner, factions):
		return false
	return not (owner in factions.get(faction, {}).get("enemies", []) or faction in factions.get(owner, {}).get("enemies", []))
