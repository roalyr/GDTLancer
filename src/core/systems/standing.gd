# Standing: the player's name with each faction, -1 (hated) to 1 (trusted), as in Freelancer. It
# starts at the faction's "standing" (TemplateDatabase.factions, 0 if none) and moves with what the player
# does to its ships: the first hit on a ship costs STANDING_ATTACK, a kill STANDING_KILL; the first hit
# earns STANDING_ATTACK_ENEMY and a kill STANDING_KILL_ENEMY with each faction at war with the victim's
# (at_war: either one's `enemies` names the other, as havens and bounties read wars). So killing
# Verdant pleases Violet and the other way, killing raiders pleases every faction they war on, and
# hitting or killing those pleases the raiders. At STANDING_HOSTILE or below
# its ships attack the player on sight (Agent.is_enemy_of) and its stations refuse docking; its
# prices follow it too (Market). Factions outside TemplateDatabase.factions, or marked no_standing (aliens),
# have none: they react on the spot. Kept in GameState.player_standing (saved).

extends Reference


static func has_standing(faction) -> bool:
	return faction is String and TemplateDatabase.factions.has(faction) and not TemplateDatabase.factions[faction].get("no_standing", false)


static func of(faction) -> float:
	if not has_standing(faction):
		return 0.0
	return float(GameState.player_standing.get(faction, TemplateDatabase.factions[faction].get("standing", 0.0)))


static func is_hostile(faction) -> bool:
	return has_standing(faction) and of(faction) <= Constants.STANDING_HOSTILE


# "HOSTILE", "NEUTRAL" or "FRIENDLY".
static func label(faction) -> String:
	var value: float = of(faction)
	if is_hostile(faction):
		return "HOSTILE"
	return "FRIENDLY" if value >= Constants.STANDING_FRIENDLY else "NEUTRAL"


# Moves the standing by `amount`; says so when it crosses into hostile or friendly, or out of them.
static func change(faction, amount: float) -> void:
	if not has_standing(faction) or amount == 0.0:
		return
	var before: String = label(faction)
	GameState.player_standing[faction] = clamp(of(faction) + amount, -1.0, 1.0)
	var after: String = label(faction)
	if after != before:
		var name: String = TemplateDatabase.factions[faction].get("name", faction)
		EventBus.emit_signal("announcement", "%s: %s" % [name, Strings.word(after)], "danger" if after == "HOSTILE" else "info")


# Whether factions `a` and `b` are at war: either one's `enemies` names the other.
static func at_war(a, b) -> bool:
	var factions: Dictionary = TemplateDatabase.factions
	return a != b and (b in factions.get(a, {}).get("enemies", []) or a in factions.get(b, {}).get("enemies", []))


# The factions with a standing at war with `faction`.
static func rivals(faction) -> Array:
	var out: Array = []
	for other in TemplateDatabase.factions:
		if has_standing(other) and at_war(faction, other):
			out.append(other)
	return out


static func on_player_attacked(faction) -> void:
	if not has_standing(faction):
		return
	change(faction, -Constants.STANDING_ATTACK)
	for other in rivals(faction):
		change(other, Constants.STANDING_ATTACK_ENEMY)


static func on_player_killed(faction) -> void:
	if not has_standing(faction):
		return
	change(faction, -Constants.STANDING_KILL)
	for other in rivals(faction):
		change(other, Constants.STANDING_KILL_ENEMY)
