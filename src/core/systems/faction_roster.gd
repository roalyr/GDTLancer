# FactionRoster: what a faction's havens fly in play, from two tables on its FactionTemplate:
# - pilot_shares: pilot level ("rookie", "regular", "veteran", "ace") -> share; empty means
#   Constants PILOT_LEVEL_SHARES;
# - archetype_shares: archetype ("trader_medium") -> share; empty means it flies nothing.
# A spawn rolls its pilot first, then one of the faction's archetypes its level may fly: each by its
# share times weight_odds (mostly the heaviest class the level may fly, PILOT_OWN_CLASS_SHARE of the
# time, otherwise a lighter one). A haven's prefer_role narrows the roll to that family prefer_share
# of the time (to all its archetypes alike if the faction lists none). If none of them fits the level,
# the lightest heavier ones do, the pilot raised to fly them. mix() is the share of each archetype
# that comes out. An archetype's share is its family's old share for the same mix as when factions
# listed families (each family's weights came out of weight_odds alone).
# Uses Constants only (no other autoload): the dev tool's bridge and the content rules read it too.

extends Reference



static func level_key(level: int) -> String:
	return Constants.PILOT_LEVELS[level].to_lower()


# Level index -> share, from the faction's pilot_shares (Constants PILOT_LEVEL_SHARES if empty).
static func pilot_shares(spec: Dictionary) -> Array:
	var given: Dictionary = spec.get("pilot_shares", {})
	var out: Array = []
	for level in range(Constants.PILOT_LEVELS.size()):
		out.append(max(float(given.get(level_key(level), 0.0)), 0.0) if not given.empty() else float(Constants.PILOT_LEVEL_SHARES[level]))
	return out


# Archetype -> share, those above 0 whose archetype exists.
static func archetype_shares(spec: Dictionary) -> Dictionary:
	var out := {}
	var given: Dictionary = spec.get("archetype_shares", {})
	for name in given:
		if float(given[name]) > 0.0 and archetype_exists(str(name)):
			out[str(name)] = float(given[name])
	return out


static func archetype_exists(name: String) -> bool:
	return ResourceLoader.exists(Constants.ARCHETYPES_DIR.plus_file("agent_archetype_%s.tres" % name))


# An archetype's family and weight class: "trader_medium" -> ["trader", "medium"].
static func split(name: String) -> Array:
	var parts: PoolStringArray = name.rsplit("_", true, 1)
	return [parts[0], parts[1] if parts.size() > 1 else ""]


# The archetypes of `family` that exist, light to superheavy.
static func family_archetypes(family: String) -> Array:
	var out: Array = []
	for weight in Constants.PRESET_WEIGHT_CLASSES:
		var name: String = "%s_%s" % [family, weight[0]]
		if archetype_exists(name):
			out.append(name)
	return out


# Weight index -> chance, for a pilot of `level`: its own class PILOT_OWN_CLASS_SHARE of the time,
# the rest spread evenly over the lighter ones (a rookie: always light).
static func weight_odds(level: int) -> Array:
	var odds: Array = []
	for index in range(Constants.PRESET_WEIGHT_CLASSES.size()):
		odds.append(0.0)
	var own: int = int(min(level, odds.size() - 1))
	if own <= 0:
		odds[0] = 1.0
		return odds
	odds[own] = Constants.PILOT_OWN_CLASS_SHARE
	for index in range(own):
		odds[index] = (1.0 - Constants.PILOT_OWN_CLASS_SHARE) / own
	return odds


static func _pick_index(odds: Array) -> int:
	var total := 0.0
	for odd in odds:
		total += float(odd)
	var pick: float = randf() * total
	for index in range(odds.size()):
		pick -= float(odds[index])
		if pick < 0.0 and float(odds[index]) > 0.0:
			return index
	for index in range(odds.size() - 1, -1, -1):
		if float(odds[index]) > 0.0:
			return index
	return 0


static func _pick_key(table: Dictionary) -> String:
	var keys: Array = table.keys()
	keys.sort()
	var odds: Array = []
	for key in keys:
		odds.append(table[key])
	return str(keys[_pick_index(odds)]) if not keys.empty() else ""


# Archetype -> chance for a pilot of `level`, from `shares` (archetype -> share): each it may fly by
# its share times weight_odds; if it may fly none, the lightest heavier ones by their shares.
static func odds_for(shares: Dictionary, level: int) -> Dictionary:
	var odds: Array = weight_odds(level)
	var out := {}
	var least: int = Constants.PRESET_WEIGHT_CLASSES.size()
	for name in shares:
		var weight: int = weight_index(split(name)[1])
		if weight < odds.size() and float(odds[weight]) > 0.0:
			out[name] = float(shares[name]) * float(odds[weight])
		elif weight > level:
			least = int(min(least, weight))
	if out.empty():
		for name in shares:
			if weight_index(split(name)[1]) == least:
				out[name] = float(shares[name])
	return out


# The shares a spawn rolls from: the faction's, or its archetypes of `family` only (all that family's
# alike if it lists none of them).
static func _narrowed(shares: Dictionary, family: String) -> Dictionary:
	if family == "":
		return shares
	var out := {}
	for name in shares:
		if split(name)[0] == family:
			out[name] = shares[name]
	if out.empty():
		for name in family_archetypes(family):
			out[name] = 1.0
	return out


# One spawn: {"name": archetype, "level": pilot level}, or {} if the faction flies nothing.
# `prefer_role`: a family the roll is narrowed to, prefer_share of the time (if it has archetypes).
static func pick(spec: Dictionary, prefer_role: String = "", prefer_share: float = 0.0) -> Dictionary:
	var shares: Dictionary = archetype_shares(spec)
	if shares.empty():
		return {}
	var level: int = _pick_index(pilot_shares(spec))
	if prefer_role != "" and randf() < prefer_share and not family_archetypes(prefer_role).empty():
		shares = _narrowed(shares, prefer_role)
	var name: String = _pick_key(odds_for(shares, level))
	if name == "":
		return {}
	return {"name": name, "level": int(max(level, weight_index(split(name)[1])))}


# A weight class's index in PRESET_WEIGHT_CLASSES (0 if unknown): the least pilot level flying it.
static func weight_index(weight_class: String) -> int:
	for index in range(Constants.PRESET_WEIGHT_CLASSES.size()):
		if Constants.PRESET_WEIGHT_CLASSES[index][0] == weight_class:
			return index
	return 0


# Archetype name -> the share of the faction's spawns that fly it (no haven preference), the shares
# summing to 1; {} if it flies nothing.
static func mix(spec: Dictionary) -> Dictionary:
	var out := {}
	var shares: Dictionary = archetype_shares(spec)
	var levels: Array = pilot_shares(spec)
	var level_total := 0.0
	for share in levels:
		level_total += share
	if shares.empty() or level_total <= 0.0:
		return out
	for level in range(levels.size()):
		if levels[level] <= 0.0:
			continue
		var odds: Dictionary = odds_for(shares, level)
		var total := 0.0
		for name in odds:
			total += odds[name]
		for name in odds:
			out[name] = float(out.get(name, 0.0)) + levels[level] / level_total * odds[name] / total
	return out


# Whether the faction's havens fly `name` at all.
static func flies(spec: Dictionary, name: String) -> bool:
	return float(mix(spec).get(name, 0.0)) > 0.0


# The faction's archetypes of `family` ("" any) it flies, most flown first.
static func flown(spec: Dictionary, family: String = "") -> Array:
	var shares: Dictionary = mix(spec)
	var names: Array = []
	for name in shares:
		if family == "" or name.begins_with(family + "_"):
			names.append(name)
	names.sort()
	return names
