# Standing: the player's name with each faction, -1 (hated) to 1 (trusted), as in Freelancer. It
# starts at the faction's "standing" (Constants.FACTIONS, 0 if none) and moves with what the player
# does to its ships: the first hit on a ship costs STANDING_ATTACK, a kill STANDING_KILL, and a kill
# earns STANDING_KILL_ENEMY with each faction at war with the victim's. At STANDING_HOSTILE or below
# its ships attack the player on sight (Agent.is_enemy_of) and its stations refuse docking; its
# prices follow it too (Market). Factions outside Constants.FACTIONS have no standing: they react on
# the spot. Kept in GameState.player_standing (saved).

extends Reference


static func has_standing(faction) -> bool:
	return faction is String and Constants.FACTIONS.has(faction)


static func of(faction) -> float:
	if not has_standing(faction):
		return 0.0
	return float(GameState.player_standing.get(faction, Constants.FACTIONS[faction].get("standing", 0.0)))


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
		var name: String = Constants.FACTIONS[faction].get("name", faction)
		EventBus.emit_signal("announcement", "%s: %s" % [name, after], "danger" if after == "HOSTILE" else "info")


static func on_player_attacked(faction) -> void:
	change(faction, -Constants.STANDING_ATTACK)


static func on_player_killed(faction) -> void:
	if not has_standing(faction):
		return
	change(faction, -Constants.STANDING_KILL)
	for other in Constants.FACTIONS:
		if faction in Constants.FACTIONS[other].get("enemies", []):
			change(other, Constants.STANDING_KILL_ENEMY)
