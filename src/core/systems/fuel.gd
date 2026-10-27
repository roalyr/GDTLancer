# Fuel: a jump between sectors burns fuel (FUEL_COMMODITY) from the hold, for everyone alike:
# ceil(ship mass / FUEL_MASS_PER_UNIT) units, so a heavy ship pays more to travel. Fuel is bought like
# any cargo and takes hold space; selling the hold at a station keeps it (Market.sell_hold).

extends Reference


static func jump_cost(ship) -> int:
	var mass: float = float(ship.mass) if is_instance_valid(ship) and ship.get("mass") != null else 0.0
	return int(max(1.0, ceil(mass / Constants.FUEL_MASS_PER_UNIT)))


static func carried(ship) -> int:
	return int(ship.cargo.get(Constants.FUEL_COMMODITY, 0)) if is_instance_valid(ship) else 0


# Burns a jump's fuel. Returns "" or why the ship cannot jump.
static func burn_for_jump(ship) -> String:
	var cost: int = jump_cost(ship)
	if carried(ship) < cost:
		return "Not enough fuel to jump: %d of %d units" % [carried(ship), cost]
	ship.remove_cargo(Constants.FUEL_COMMODITY, cost)
	return ""
