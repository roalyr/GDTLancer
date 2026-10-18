# CombatAssessment: how a fight between two ships looks, shared by NPCs (as numbers) and the player
# (as words on the HUD), so both judge by the same rule.
#   advantage = (own time to die) / (time to kill the target), from hulls and laser damage per second.
#   desire = advantage * gain factor (what the kill is worth); NPCs fight on desire, players judge worth themselves.

extends Reference


static func compute_advantage(own_hull: float, own_dps: float, target_hull: float, target_dps: float) -> float:
	if own_dps <= 0.0:
		return 0.0
	var time_to_kill: float = target_hull / own_dps
	var time_to_die: float = own_hull / max(target_dps, 0.001)
	return min(time_to_die / max(time_to_kill, 0.001), 100.0)


static func compute_desire(own_hull: float, own_dps: float, target_hull: float, target_dps: float, gain: float) -> float:
	var gain_factor: float = clamp(gain / Constants.AI_GAIN_REFERENCE, Constants.AI_GAIN_FACTOR_MIN, Constants.AI_GAIN_FACTOR_MAX)
	return compute_advantage(own_hull, own_dps, target_hull, target_dps) * gain_factor


static func advantage_between(own, target) -> float:
	return compute_advantage(own.hull, own.get_damage_per_second(), target.hull, target.get_damage_per_second())


# The player's at-a-glance read of a target.
static func difficulty_label(advantage: float) -> String:
	if advantage >= Constants.DIFFICULTY_EASY_ADVANTAGE:
		return "EASY"
	if advantage >= Constants.DIFFICULTY_EVEN_ADVANTAGE:
		return "EVEN"
	if advantage >= Constants.DIFFICULTY_HARD_ADVANTAGE:
		return "HARD"
	return "DEADLY"
