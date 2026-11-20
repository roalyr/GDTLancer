# PilotLevel: how good an NPC pilot is, ROOKIE to ACE (Constants PILOT_LEVELS), and what of a pilot
# is public: what the player can read about any ship (the interaction window's PILOT tab).
# The level is the player's cue for an NPC's judgement (parity): NPCs misjudge opponents by it
# (ShipControllerAI.desire_against), and the player sees it as pips under a hostile's mark, on
# the HUD's top strip and in the PILOT tab. At a spawn the level comes first, the hull after
# (FactionRoster; play only).

extends Reference

const Bounty = preload("res://src/core/systems/bounty.gd")
const Radio = preload("res://src/core/systems/radio.gd")
const TargetKinds = preload("res://src/core/ui/main_hud/target_kinds.gd")


# A level by PILOT_LEVEL_SHARES, at least `least`.
static func roll(least: int = 0) -> int:
	var pick: float = randf()
	var level := 0
	for index in range(Constants.PILOT_LEVEL_SHARES.size()):
		pick -= float(Constants.PILOT_LEVEL_SHARES[index])
		level = index
		if pick < 0.0:
			break
	return int(clamp(max(level, least), 0, Constants.PILOT_LEVELS.size() - 1))


# The least level that may fly a hull of `weight_class` ("light" .. "superheavy").
static func least_for_weight(weight_class: String) -> int:
	for index in range(Constants.PRESET_WEIGHT_CLASSES.size()):
		if Constants.PRESET_WEIGHT_CLASSES[index][0] == weight_class:
			return int(min(index, Constants.PILOT_LEVELS.size() - 1))
	return 0


# Whether a pilot of `level` may fly a hull of `weight_class`.
static func may_fly(level: int, weight_class: String) -> bool:
	return level >= least_for_weight(weight_class)


static func skill_for(level: int) -> float:
	var span: Array = Constants.PILOT_LEVEL_SKILL[int(clamp(level, 0, Constants.PILOT_LEVEL_SKILL.size() - 1))]
	return rand_range(span[0], span[1])


# Chance of reading an opponent right; 1 for a ship without a level.
static func judgement_for(level: int) -> float:
	if level < 0:
		return 1.0
	return float(Constants.PILOT_LEVEL_JUDGEMENT[int(min(level, Constants.PILOT_LEVEL_JUDGEMENT.size() - 1))])


# A ship's level, -1 if it has none (the player, platforms, ships outside play).
static func of(ship) -> int:
	if not is_instance_valid(ship) or ship.get("pilot_level") == null:
		return -1
	return int(ship.get("pilot_level"))


static func name_of(level: int) -> String:
	return Constants.PILOT_LEVELS[level] if level >= 0 and level < Constants.PILOT_LEVELS.size() else ""


# How an opponent looks to a pilot of `judgement`: 1 (as it is) with that chance, otherwise
# PILOT_MISREAD_FACTOR times weaker or stronger, either way as likely.
static func misread_factor(judgement: float) -> float:
	if judgement >= 1.0 or randf() < judgement:
		return 1.0
	var factor: float = rand_range(Constants.PILOT_MISREAD_FACTOR[0], Constants.PILOT_MISREAD_FACTOR[1])
	return factor if randf() < 0.5 else 1.0 / factor


# The faction tag written before a ship's name on the HUD ("[VERDANT]"), "" for none.
static func faction_tag(ship) -> String:
	var name: String = ship.get_faction_name() if is_instance_valid(ship) and ship.has_method("get_faction_name") else ""
	return "[%s]" % name.to_upper() if name != "" else ""


# What anyone may know of `ship`'s pilot, as [label, value] rows (empty values left out): its call
# sign, whom it flies for and how that side stands with the player, its level, ship, what it is
# doing, its place in its group, kills on record and the bounties on it. Nothing of its wallet,
# genes or numbers behind its decisions.
static func public_record(player, ship) -> Array:
	var rows: Array = []
	if not is_instance_valid(ship):
		return rows
	rows.append(["CALL SIGN", Radio.call_sign(ship).to_upper()])
	var faction_name: String = ship.get_faction_name() if ship.has_method("get_faction_name") else ""
	rows.append(["FLIES FOR", faction_name.to_upper() if faction_name != "" else "NO ONE"])
	if is_instance_valid(player):
		rows.append(["TO YOU", TargetKinds.side_of(ship, player).to_upper()])
	rows.append(["LEVEL", name_of(of(ship))])
	var template = ship.get("ship_template")
	rows.append(["SHIP", str(template.ship_model_name).to_upper() if is_instance_valid(template) else ""])
	var ai = ship.get_node_or_null(Constants.AI_CONTROLLER_NODE_NAME)
	rows.append(["DOING", ai.get_activity_label() if ai != null and ai.has_method("get_activity_label") else ""])
	var uid: String = str(ship.get("evo_uid")) if ship.get("evo_uid") != null else ""
	if uid != "":
		var record: Dictionary = Evolution.get_record(uid)
		if not record.empty():
			var faction = ship.get("faction")
			if Evolution.leader_of(str(faction), str(record.get("zone", ""))) == ship:
				rows.append(["GROUP", "LEADS IT"])
			rows.append(["KILLS ON RECORD", str(int(record.get("kills", 0)))])
	var wanted: Array = []
	var postings: Dictionary = Bounty.postings(ship)
	for faction in postings:
		if float(postings[faction]) >= 1.0:
			wanted.append("%s %d WP" % [str(TemplateDatabase.factions.get(faction, {}).get("name", faction)).to_upper(), int(round(float(postings[faction])))])
	rows.append(["WANTED BY", PoolStringArray(wanted).join(", ") if not wanted.empty() else "NO ONE"])
	if is_instance_valid(player):
		var price: float = Bounty.claimable(player, ship)
		rows.append(["PAID TO YOU FOR IT", "%d WP" % int(round(price)) if price >= 1.0 else "NOTHING"])
	var shown: Array = []
	for row in rows:
		if str(row[1]) != "":
			shown.append(row)
	return shown
