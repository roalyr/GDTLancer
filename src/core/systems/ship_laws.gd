# ShipLaws: the governing equations. Ship and part stats follow from their genes (masses, a laser's
# shot energy) by the power laws in Constants (SHIP AND PART LAWS), so anything evolution makes
# obeys the same physics. Builds the templates the game flies from those genes.
#   Ship genes: {"type": 1-3, "size": s, "shares": {structure, engine, reactor, capacitor, hold}}
#   Laser genes: {"mass": kg, "energy": power per shot}; module genes: {"mass": kg}, except the
#   lance's: {"nail_mass": kg per lance, "count": lances in the quiver}

extends Reference

const SHARE_KEYS = ["structure", "engine", "reactor", "capacitor", "hold"]
const MODULE_KINDS = ["plating", "thruster", "power_cell", "capacitor", "lance"]
const MODULE_LAWS = {"plating": "hull", "thruster": "linear_thrust", "power_cell": "power_regen", "capacitor": "power_capacity"}


# amount = law[1] * (mass / law[0]) ^ law[2]; nothing for no mass.
static func apply_law(law: Array, mass: float) -> float:
	if mass <= 0.0:
		return 0.0
	return float(law[1]) * pow(mass / float(law[0]), float(law[2]))


static func _law_for_stat(stat: String) -> Array:
	match stat:
		"hull":
			return Constants.LAW_HULL
		"linear_thrust":
			return Constants.LAW_THRUST
		"power_regen":
			return Constants.LAW_REGEN
		"power_capacity":
			return Constants.LAW_CAPACITY
	return Constants.LAW_HOLD


# --- Ships ---

# Shares raised to their minimums, then scaled to add up to 1.
static func normalized_shares(shares: Dictionary) -> Dictionary:
	var result := {}
	var total := 0.0
	for key in SHARE_KEYS:
		result[key] = max(float(shares.get(key, Constants.LAW_SHIP_SHARES[key])), Constants.LAW_SHIP_SHARE_MIN[key])
		total += result[key]
	for key in SHARE_KEYS:
		result[key] /= total
	return result


static func clamp_size(size: float) -> float:
	return clamp(size, Constants.LAW_SHIP_SIZE_MIN, Constants.LAW_SHIP_SIZE_MAX)


static func ship_length(size: float) -> float:
	return pow(clamp_size(size), 1.0 / 3.0)


static func tool_slot_count(size: float) -> int:
	return int(max(1, round(Constants.LAW_TOOL_SLOTS * pow(clamp_size(size), 2.0 / 3.0))))


static func module_slot_count(size: float) -> int:
	return int(max(0, round(Constants.LAW_MODULE_SLOTS * sqrt(clamp_size(size)))))


static func slot_size_for(size: float) -> String:
	if size >= Constants.LAW_SLOT_LARGE_SIZE:
		return "large"
	if size >= Constants.LAW_SLOT_MEDIUM_SIZE:
		return "medium"
	return "small"


# Every ShipTemplate field that follows from the genes.
static func ship_stats(genes: Dictionary) -> Dictionary:
	var size: float = clamp_size(float(genes.get("size", 1.0)))
	var shares: Dictionary = normalized_shares(genes.get("shares", {}))
	var mass: float = Constants.LAW_SHIP_REF_MASS * size
	var length: float = ship_length(size)
	var thrust: float = apply_law(Constants.LAW_THRUST, mass * shares.engine)
	var slots: int = tool_slot_count(size)
	var slot_size: String = slot_size_for(size)
	return {
		"mass": mass,
		"hull_integrity": int(max(1, round(apply_law(Constants.LAW_HULL, mass * shares.structure)))),
		"linear_thrust": thrust,
		"angular_thrust": Constants.LAW_TORQUE_PER_THRUST * thrust * length,
		"power_regen": apply_law(Constants.LAW_REGEN, mass * shares.reactor),
		"power_capacity": apply_law(Constants.LAW_CAPACITY, mass * shares.capacitor),
		"cargo_capacity": int(round(apply_law(Constants.LAW_HOLD, mass * shares.hold))),
		"signature": Constants.LAW_SHIP_SIGNATURE * length,
		"apparent_radius": Constants.LAW_SHIP_RADIUS * length,
		"interaction_radius": Constants.LAW_SHIP_INTERACTION_RADIUS * length,
		"model_scale": length,
		"tool_slots_small": slots if slot_size == "small" else 0,
		"tool_slots_medium": slots if slot_size == "medium" else 0,
		"tool_slots_large": slots if slot_size == "large" else 0,
		"module_slots": module_slot_count(size),
		"base_value": int(round(Constants.LAW_SHIP_VALUE_PER_KG * mass)),
		"salvage_yield": {
			"commodity_scrap": int(round(Constants.LAW_SCRAP_PER_KG * mass)),
			"commodity_tech": int(round(Constants.LAW_TECH_PER_KG * mass * (shares.engine + shares.reactor))),
		},
	}


static func build_ship_template(genes: Dictionary, template_id: String, model_name: String, faction: String) -> ShipTemplate:
	var ship := ShipTemplate.new()
	var stats: Dictionary = ship_stats(genes)
	for field in stats:
		ship.set(field, stats[field])
	ship.template_id = template_id
	ship.ship_model_name = model_name
	ship.variant_type = int(genes.get("type", 0))
	ship.law_genes = genes.duplicate(true)
	ship.panel_material = Constants.SHIP_TYPE_PANEL_MATERIALS.get(ship.variant_type, "")
	ship.ship_scene = load(Constants.SHIP_FACTION_SCENES.get(faction, Constants.SHIP_DEFAULT_SCENE))
	ship.sensor_strength = 1.0
	return ship


# --- Lasers ---

static func clamp_laser_genes(genes: Dictionary) -> Dictionary:
	return {
		"mass": clamp(float(genes.get("mass", Constants.LAW_LASER_REF_MASS)), Constants.LAW_LASER_MASS_RANGE[0], Constants.LAW_LASER_MASS_RANGE[1]),
		"energy": clamp(float(genes.get("energy", Constants.LAW_LASER_REF_ENERGY)), Constants.LAW_LASER_ENERGY_RANGE[0], Constants.LAW_LASER_ENERGY_RANGE[1]),
	}


static func laser_mount_size(mass: float) -> String:
	if mass >= Constants.LAW_LASER_LARGE_MASS:
		return "large"
	if mass >= Constants.LAW_LASER_MEDIUM_MASS:
		return "medium"
	return "small"


# Every UtilityToolTemplate field that follows from the genes.
static func laser_stats(genes: Dictionary) -> Dictionary:
	var g: Dictionary = clamp_laser_genes(genes)
	var m: float = g.mass / Constants.LAW_LASER_REF_MASS
	var e: float = g.energy / Constants.LAW_LASER_REF_ENERGY
	var optimal: float = Constants.LAW_LASER_RANGE[0] * pow(m, Constants.LAW_LASER_RANGE[1]) * pow(e, Constants.LAW_LASER_RANGE[2])
	var cycle: float = Constants.LAW_LASER_CYCLE[0] * e / pow(m, Constants.LAW_LASER_CYCLE[1])
	return {
		"mass": g.mass,
		"power_per_cycle": g.energy * Constants.LAW_LASER_POWER_PER_ENERGY,
		"damage": Constants.LAW_LASER_DAMAGE[0] * pow(e, Constants.LAW_LASER_DAMAGE[1]),
		"optimal_range": optimal,
		"falloff": optimal * Constants.LAW_LASER_FALLOFF_SHARE,
		"tracking": Constants.LAW_LASER_TRACKING[0] * pow(m, Constants.LAW_LASER_TRACKING[1]),
		"cycle_time": clamp(cycle, Constants.LAW_LASER_CYCLE_RANGE[0], Constants.LAW_LASER_CYCLE_RANGE[1]),
		"mount_size": laser_mount_size(g.mass),
		"base_value": int(round(Constants.LAW_LASER_VALUE[0] * g.mass + Constants.LAW_LASER_VALUE[1] * g.energy)),
	}


static func build_laser_template(genes: Dictionary, part_type: int, template_id: String) -> UtilityToolTemplate:
	var tool_template := UtilityToolTemplate.new()
	var stats: Dictionary = laser_stats(genes)
	for field in stats:
		tool_template.set(field, stats[field])
	tool_template.template_id = template_id
	tool_template.tool_type = "laser"
	tool_template.tool_name = "%s %s" % [Constants.PART_NAMES.laser, Constants.PART_TYPE_NAMES.get(part_type, "")]
	tool_template.hud_label = "LASER %s" % Constants.PART_TYPE_NAMES.get(part_type, "")
	tool_template.description = "%.0f kg, %.1f per shot." % [stats.mass, stats.power_per_cycle]
	tool_template.variant_type = part_type
	tool_template.law_genes = clamp_laser_genes(genes)
	return tool_template


# --- Missile racks ---

static func clamp_missile_genes(genes: Dictionary) -> Dictionary:
	return {
		"round_mass": clamp(float(genes.get("round_mass", Constants.LAW_MISSILE_REF_MASS)), Constants.LAW_MISSILE_MASS_RANGE[0], Constants.LAW_MISSILE_MASS_RANGE[1]),
		"count": clamp(float(genes.get("count", 4.0)), Constants.LAW_MISSILE_COUNT_RANGE[0], Constants.LAW_MISSILE_COUNT_RANGE[1]),
	}


# Every UtilityToolTemplate field that follows from a rack's genes (mass: loaded).
static func missile_stats(genes: Dictionary) -> Dictionary:
	var g: Dictionary = clamp_missile_genes(genes)
	var count: int = int(round(g.count))
	var speed: float = apply_law(Constants.LAW_MISSILE_SPEED, g.round_mass)
	var flight: float = apply_law(Constants.LAW_MISSILE_FLIGHT, g.round_mass)
	var reach: float = Constants.LAW_MISSILE_RANGE_SHARE * speed * flight
	var mass: float = g.round_mass * (count + Constants.LAW_MISSILE_RACK_ROUNDS)
	var round_value: int = int(round(Constants.LAW_MISSILE_VALUE_PER_KG * g.round_mass))
	return {
		"mass": mass,
		"ammo": count,
		"round_mass": g.round_mass,
		"round_value": round_value,
		"damage": apply_law(Constants.LAW_MISSILE_DAMAGE, g.round_mass),
		"projectile_speed": speed,
		"projectile_accel": apply_law(Constants.LAW_MISSILE_ACCEL, g.round_mass),
		"turn_rate": apply_law(Constants.LAW_MISSILE_TURN, g.round_mass),
		"flight_time": flight,
		"optimal_range": reach,
		"falloff": 0.0,
		"tracking": 0.0,
		"cycle_time": apply_law(Constants.LAW_MISSILE_CYCLE, g.round_mass),
		"power_per_cycle": Constants.LAW_MISSILE_POWER,
		"mount_size": laser_mount_size(mass),
		"base_value": int(round(Constants.LAW_PART_VALUE_PER_KG * g.round_mass * Constants.LAW_MISSILE_RACK_ROUNDS)) + round_value * count,
	}


# --- Cannons ---

static func clamp_cannon_genes(genes: Dictionary) -> Dictionary:
	return {
		"mass": clamp(float(genes.get("mass", Constants.LAW_CANNON_REF_MASS)), Constants.LAW_CANNON_MASS_RANGE[0], Constants.LAW_CANNON_MASS_RANGE[1]),
		"round_mass": clamp(float(genes.get("round_mass", Constants.LAW_CANNON_REF_ROUND)), Constants.LAW_CANNON_ROUND_RANGE[0], Constants.LAW_CANNON_ROUND_RANGE[1]),
		"count": clamp(float(genes.get("count", 60.0)), Constants.LAW_CANNON_COUNT_RANGE[0], Constants.LAW_CANNON_COUNT_RANGE[1]),
	}


# Every UtilityToolTemplate field that follows from a cannon's genes (mass: gun and full magazine).
static func cannon_stats(genes: Dictionary) -> Dictionary:
	var g: Dictionary = clamp_cannon_genes(genes)
	var count: int = int(round(g.count))
	var speed: float = apply_law(Constants.LAW_CANNON_SPEED, g.mass) * pow(g.round_mass / Constants.LAW_CANNON_REF_ROUND, Constants.LAW_CANNON_ROUND_SPEED_EXP)
	var optimal: float = speed * Constants.LAW_CANNON_AIM_TIME
	var mass: float = g.mass + g.round_mass * count
	var round_value: int = int(max(1, round(Constants.LAW_CANNON_VALUE[1] * g.round_mass)))
	return {
		"mass": mass,
		"ammo": count,
		"round_mass": g.round_mass,
		"round_value": round_value,
		"damage": apply_law(Constants.LAW_CANNON_DAMAGE, g.round_mass) * speed / Constants.LAW_CANNON_SPEED[1],
		"projectile_speed": speed,
		"flight_time": Constants.LAW_CANNON_FLIGHT,
		"optimal_range": optimal,
		"falloff": (speed * Constants.LAW_CANNON_FLIGHT - optimal) / Constants.TOOL_MAX_RANGE_FALLOFFS,  # Max range: as far as a round flies
		"tracking": 0.0,
		"cycle_time": apply_law(Constants.LAW_CANNON_CYCLE, g.round_mass),
		"power_per_cycle": apply_law(Constants.LAW_CANNON_POWER, g.round_mass),
		"mount_size": laser_mount_size(mass),
		"base_value": int(round(Constants.LAW_CANNON_VALUE[0] * g.mass)) + round_value * count,
	}


# A missile rack or a cannon (`kind`) from its genes.
static func build_weapon_template(kind: String, genes: Dictionary, part_type: int, template_id: String) -> UtilityToolTemplate:
	var tool_template := UtilityToolTemplate.new()
	var stats: Dictionary = missile_stats(genes) if kind == "missile" else cannon_stats(genes)
	for field in stats:
		tool_template.set(field, stats[field])
	tool_template.template_id = template_id
	tool_template.tool_type = kind
	tool_template.tool_name = "%s %s" % [Constants.PART_NAMES[kind], Constants.PART_TYPE_NAMES.get(part_type, "")]
	tool_template.hud_label = "%s %s" % ["MISSILE" if kind == "missile" else "CANNON", Constants.PART_TYPE_NAMES.get(part_type, "")]
	if kind == "missile":
		tool_template.description = "%.0f kg: %d missiles of %.0f kg, %.0f damage, %.0f m/s, %.0f m reach. Guided; more only at a base or from a missile ship's wreck." % [
			stats.mass, stats.ammo, stats.round_mass, stats.damage, stats.projectile_speed, stats.optimal_range]
		tool_template.law_genes = clamp_missile_genes(genes)
	else:
		tool_template.description = "%.0f kg: %d rounds of %.1f kg, %.0f damage each at %.0f m/s. Fixed forward: the ship aims, leading the target." % [
			stats.mass, stats.ammo, stats.round_mass, stats.damage, stats.projectile_speed]
		tool_template.law_genes = clamp_cannon_genes(genes)
	tool_template.variant_type = part_type
	return tool_template


# --- Modules ---

static func clamp_module_genes(genes: Dictionary, kind: String = "") -> Dictionary:
	if kind == "lance":
		return {
			"nail_mass": clamp(float(genes.get("nail_mass", 200.0)), Constants.LAW_LANCE_NAIL_MASS_RANGE[0], Constants.LAW_LANCE_NAIL_MASS_RANGE[1]),
			"count": clamp(float(genes.get("count", 3.0)), Constants.LAW_LANCE_COUNT_RANGE[0], Constants.LAW_LANCE_COUNT_RANGE[1]),  # Rounded in lance_stats, so small steps add up
		}
	return {"mass": clamp(float(genes.get("mass", 300.0)), Constants.LAW_MODULE_MASS_RANGE[0], Constants.LAW_MODULE_MASS_RANGE[1])}


# A kinetic lance (Constants LAW_LANCE_*): {"nail_mass", "count", "mass" (seat and quiver, full),
# "damage" (at LAW_LANCE_REF_SPEED), "length" (m past the nose), "reload" (s), "nail_value" (WP)}.
static func lance_stats(genes: Dictionary) -> Dictionary:
	var g: Dictionary = clamp_module_genes(genes, "lance")
	var count: int = int(round(g.count))
	return {
		"nail_mass": g.nail_mass,
		"count": count,
		"mass": g.nail_mass * (count + Constants.LAW_LANCE_SEAT_NAILS),
		"damage": apply_law(Constants.LAW_LANCE_DAMAGE, g.nail_mass),
		"length": apply_law(Constants.LAW_LANCE_LENGTH, g.nail_mass),
		"reload": apply_law(Constants.LAW_LANCE_RELOAD, g.nail_mass),
		"nail_value": int(round(Constants.LAW_PART_VALUE_PER_KG * g.nail_mass)),
	}


# Damage of a lance strike that goes in at `closing_speed` (m/s along the lance): 0 below
# LAW_LANCE_MIN_SPEED (it glances off). Whether it goes in at an angle: lance_hit_chance.
static func lance_damage(lance: Dictionary, closing_speed: float) -> float:
	if closing_speed < Constants.LAW_LANCE_MIN_SPEED:
		return 0.0
	return float(lance.damage) * pow(closing_speed / Constants.LAW_LANCE_REF_SPEED, Constants.LAW_LANCE_SPEED_EXP)


# Chance a lance meeting a hull `angle` degrees off square-on goes in rather than glancing off: 1
# square-on, falling as (angle / LAW_LANCE_GLANCE_ANGLE)^GLANCE_EXP to the slip chance at that
# angle; past it only the slip chance (a long lance can slip between parts), fading to 0 side-on.
static func lance_hit_chance(lance: Dictionary, angle: float) -> float:
	var slip: float = clamp(Constants.LAW_LANCE_SLIP_CHANCE * float(lance.length) / Constants.LAW_LANCE_LENGTH[1], 0.0, Constants.LAW_LANCE_SLIP_MAX)
	if angle <= Constants.LAW_LANCE_GLANCE_ANGLE:
		return 1.0 - (1.0 - slip) * pow(angle / Constants.LAW_LANCE_GLANCE_ANGLE, Constants.LAW_LANCE_GLANCE_EXP)
	return slip * clamp((90.0 - angle) / (90.0 - Constants.LAW_LANCE_GLANCE_ANGLE), 0.0, 1.0)


# {"mass", "stat_modifiers", "base_value"} of a module of `kind` (MODULE_KINDS); a lance adds "lance".
static func module_stats(kind: String, genes: Dictionary) -> Dictionary:
	if kind == "lance":
		var lance: Dictionary = lance_stats(genes)
		var prow: int = int(round(apply_law(Constants.LAW_HULL, lance.mass * Constants.LAW_LANCE_PROW_SHARE)))  # The seat armours the bow
		return {"mass": lance.mass, "stat_modifiers": {"hull": prow}, "base_value": int(round(Constants.LAW_PART_VALUE_PER_KG * lance.mass)), "lance": lance}
	var mass: float = clamp_module_genes(genes).mass
	var stat: String = MODULE_LAWS.get(kind, "hull")
	var amount: float = apply_law(_law_for_stat(stat), mass)
	return {
		"mass": mass,
		"stat_modifiers": {stat: int(round(amount)) if stat == "hull" else amount},
		"base_value": int(round(Constants.LAW_PART_VALUE_PER_KG * mass)),
	}


static func build_module_template(kind: String, genes: Dictionary, part_type: int, template_id: String) -> ModuleTemplate:
	var module := ModuleTemplate.new()
	var stats: Dictionary = module_stats(kind, genes)
	module.template_id = template_id
	module.mass = stats.mass
	module.stat_modifiers = stats.stat_modifiers
	module.base_value = stats.base_value
	module.module_name = "%s %s" % [Constants.PART_NAMES.get(kind, kind), Constants.PART_TYPE_NAMES.get(part_type, "")]
	module.description = "%.0f kg." % stats.mass
	if kind == "lance":
		module.lance = stats.lance
		module.description = "%.0f kg: %d lances of %.0f kg, %.0f damage at %.0f m/s (none under %.0f m/s); an armoured prow, +%d hull. One per ship." % [
			stats.mass, stats.lance.count, stats.lance.nail_mass, stats.lance.damage, Constants.LAW_LANCE_REF_SPEED, Constants.LAW_LANCE_MIN_SPEED, stats.stat_modifiers.hull]
	module.module_kind = kind
	module.variant_type = part_type
	module.law_genes = clamp_module_genes(genes, kind)
	return module


# --- Hand-made templates ---

# Sets a registry template's stats from its law_genes (tools/apply_laws.gd); returns what it set.
# Ships keep their slot sizes' place in the list (all hardpoints of the size the laws give).
static func reapply(template: Resource) -> Dictionary:
	var stats: Dictionary = {}
	if template is ShipTemplate:
		stats = ship_stats(template.law_genes)
		stats.erase("model_scale")  # Hand-made hulls keep their own model
	elif template is ModuleTemplate and template.module_kind != "":
		stats = module_stats(template.module_kind, template.law_genes)
	elif template is UtilityToolTemplate and template.tool_type == "laser":
		stats = laser_stats(template.law_genes)
	elif template is UtilityToolTemplate and template.tool_type == "missile":
		stats = missile_stats(template.law_genes)
	elif template is UtilityToolTemplate and template.tool_type == "cannon":
		stats = cannon_stats(template.law_genes)
	for field in stats:
		template.set(field, stats[field])
	return stats
