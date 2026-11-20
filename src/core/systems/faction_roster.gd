# FactionRoster: what a faction's havens fly in play, from two tables on its FactionTemplate:
# - pilot_shares: pilot level ("rookie", "regular", "veteran", "ace") -> share; empty means
#   Constants PILOT_LEVEL_SHARES;
# - family_shares: ship family ("fighter", "trader"...) -> share; empty means it flies nothing.
# A spawn rolls its pilot first, then its family (a haven's prefer_role takes the family's place
# prefer_share of the time), then its hull's weight by the pilot (pick_weight: mostly the heaviest
# the level may fly, PILOT_OWN_CLASS_SHARE of the time, otherwise a lighter one), and flies that
# family's archetype of that weight (archetype_for: the next lighter one if there is none, then the
# next heavier, the pilot raised to fly it). mix() is the share of each archetype that comes out.
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


# Family -> share, those above 0 only.
static func family_shares(spec: Dictionary) -> Dictionary:
	var out := {}
	var given: Dictionary = spec.get("family_shares", {})
	for family in given:
		if float(given[family]) > 0.0:
			out[str(family)] = float(given[family])
	return out


static func archetype_exists(name: String) -> bool:
	return ResourceLoader.exists(Constants.ARCHETYPES_DIR.plus_file("agent_archetype_%s.tres" % name))


# The archetype of `family` nearest `weight` (an index in PRESET_WEIGHT_CLASSES): that one, the next
# lighter, ..., then the next heavier; "" if the family has none.
static func archetype_for(family: String, weight: int) -> String:
	var order: Array = []
	for index in range(weight, -1, -1):
		order.append(index)
	for index in range(weight + 1, Constants.PRESET_WEIGHT_CLASSES.size()):
		order.append(index)
	for index in order:
		var name: String = "%s_%s" % [family, Constants.PRESET_WEIGHT_CLASSES[index][0]]
		if archetype_exists(name):
			return name
	return ""


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


# One spawn: {"name": archetype, "level": pilot level}, or {} if the faction flies nothing.
# `prefer_role`: a family taken instead of rolling one, prefer_share of the time (if it flies it).
static func pick(spec: Dictionary, prefer_role: String = "", prefer_share: float = 0.0) -> Dictionary:
	var families: Dictionary = family_shares(spec)
	if families.empty():
		return {}
	var level: int = _pick_index(pilot_shares(spec))
	var family: String = _pick_key(families)
	if prefer_role != "" and randf() < prefer_share and archetype_for(prefer_role, 0) != "":
		family = prefer_role
	var name: String = archetype_for(family, _pick_index(weight_odds(level)))
	if name == "":
		return {}
	return {"name": name, "level": int(max(level, weight_index(name.rsplit("_", true, 1)[-1])))}


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
	var families: Dictionary = family_shares(spec)
	var levels: Array = pilot_shares(spec)
	var family_total := 0.0
	var level_total := 0.0
	for family in families:
		family_total += families[family]
	for share in levels:
		level_total += share
	if family_total <= 0.0 or level_total <= 0.0:
		return out
	for family in families:
		for level in range(levels.size()):
			var odds: Array = weight_odds(level)
			for weight in range(odds.size()):
				var share: float = families[family] / family_total * levels[level] / level_total * float(odds[weight])
				if share <= 0.0:
					continue
				var name: String = archetype_for(family, weight)
				if name != "":
					out[name] = float(out.get(name, 0.0)) + share
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
