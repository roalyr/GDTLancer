# SaveRepair: makes a loaded play save fit the game's content as it is now. Content changes (a hull,
# part, haven, commodity or faction removed or renamed) would otherwise leave a save naming things
# that no longer exist: a ship with no model, a home station where nothing can be bought, parts
# and cargo nobody takes. repair() puts each in order in GameState (GameStateManager runs it after
# loading a play save) and returns what it changed, for the player (WorldManager announces it):
#   hull gone      -> the game start's ship, its default fit, repaired (the fitted parts with it);
#   home gone      -> the game start's home station;
#   parts gone     -> out of the fit and out of storage;
#   cargo gone     -> out of the hold;
#   factions and stations gone -> their standing, bounties, markups and travellers dropped (silent:
#                     the game rebuilds them).
# Sectors and the docked station are put right by WorldManager as the sector loads.

extends Reference

const Havens = preload("res://src/core/systems/havens.gd")


# `game_start`: the save's game start (GameStateManager.game_start), null for the fallbacks.
# Nothing indexed (TemplateDatabase empty: no content to check against): changes nothing.
static func repair(game_start: Resource) -> Array:
	var notes: Array = []
	if TemplateDatabase.assets_ships.empty() and TemplateDatabase.presets.empty():
		return notes
	var start_ship: String = game_start.player_ship_template if game_start != null else Constants.FALLBACK_SHIP_TEMPLATE_ID
	var start_home: String = game_start.player_starting_location if game_start != null else ""
	if not ship_known(GameState.player_ship_template_id):
		notes.append("Your ship (%s) is no longer built: you fly the starting ship" % GameState.player_ship_template_id)
		GameState.player_ship_template_id = start_ship
		GameState.player_fit = {}  # The hull's default fit
		GameState.player_hull = -1.0
		GameState.player_hull_scars = []
		GameState.player_lance_nails = -1
		GameState.player_tool_ammo = []
	if not haven_known(GameState.home_location_id) and haven_known(start_home):
		notes.append("Your home station (%s) is gone: your home is now %s" % [
			GameState.home_location_id if GameState.home_location_id != "" else "none", Havens.spec(start_home).get("name", start_home)])
		GameState.home_location_id = start_home
	var fitted: int = 0
	for kind in ["tools", "modules"]:
		var slots = GameState.player_fit.get(kind, [])
		if not slots is Array:
			continue
		for index in range(slots.size()):
			if str(slots[index]) != "" and not part_known(str(slots[index])):
				slots[index] = ""
				fitted += 1
	var stored: int = _drop_unknown(GameState.player_storage, "part")
	if fitted + stored > 0:
		notes.append("%d part%s no longer made %s removed (%d fitted, %d stored)" % [fitted + stored, "" if fitted + stored == 1 else "s", "was" if fitted + stored == 1 else "were", fitted, stored])
	var cargo: int = _drop_unknown(GameState.player_cargo, "commodity")
	if cargo > 0:
		notes.append("%d kind%s of cargo no longer traded %s thrown out of the hold" % [cargo, "" if cargo == 1 else "s", "was" if cargo == 1 else "were"])
	_drop_unknown(GameState.player_standing, "faction")
	_drop_unknown(GameState.player_bounties, "faction")
	_drop_unknown(GameState.station_markups, "haven")
	_drop_unknown(GameState.station_markup_until, "haven")
	for record in GameState.travelers.duplicate():
		if not (record is Dictionary and faction_known(str(record.get("faction", "")))):
			GameState.travelers.erase(record)  # Traffic fills the roster again
	return notes


static func ship_known(ship_id: String) -> bool:
	return ship_id != "" and (TemplateDatabase.assets_ships.has(ship_id) or TemplateDatabase.presets.get(ship_id) is ShipTemplate)


static func part_known(part_id: String) -> bool:
	var part = TemplateDatabase.get_template(part_id)
	return part is UtilityToolTemplate or part is ModuleTemplate


static func commodity_known(commodity_id: String) -> bool:
	return TemplateDatabase.assets_commodities.has(commodity_id)


static func faction_known(faction_id: String) -> bool:
	return TemplateDatabase.factions.has(faction_id)


static func haven_known(location_id: String) -> bool:
	return location_id != "" and not Havens.spec(location_id).empty()


static func known(kind: String, id: String) -> bool:
	match kind:
		"part":
			return part_known(id)
		"commodity":
			return commodity_known(id)
		"faction":
			return faction_known(id)
		"haven":
			return haven_known(id)
	return false


# Removes the keys that are no `kind` ("part", "commodity", "faction", "haven") the game knows; how many.
static func _drop_unknown(values: Dictionary, kind: String) -> int:
	var dropped: int = 0
	for key in values.keys():
		if not known(kind, str(key)):
			values.erase(key)
			dropped += 1
	return dropped
