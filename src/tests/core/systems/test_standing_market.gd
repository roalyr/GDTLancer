# Tests for Standing (the player's name with each faction) and Market (station prices).

extends GutTest

const Standing = preload("res://src/core/systems/standing.gd")
const Market = preload("res://src/core/systems/market.gd")
const AgentScript = preload("res://src/core/agents/agent.gd")


func before_each():
	GameState.reset_state()


func after_each():
	GameState.reset_state()


func _ship(faction: String, agent_type: String = "npc") -> Node:
	var body = AgentScript.new()
	body.agent_type = agent_type
	body.faction = faction
	body.hull = 100.0
	body.hull_max = 100.0
	body.ship_template = ShipTemplate.new()
	body.ship_template.base_value = 1000  # get_value: 1000 WP
	add_child_autofree(body)
	return body


func test_standing_starts_at_the_factions_own_and_hostile_ones_attack_on_sight():
	var player = _ship("player", "player")
	assert_eq(Standing.of("verdant"), 0.0)
	assert_true(Standing.is_hostile("raiders"), "Raiders start hostile")
	assert_true(_ship("raiders").is_enemy_of(player))
	assert_false(_ship("verdant").is_enemy_of(player))
	assert_false(Standing.has_standing("xenohive"), "Factions outside the list react on the spot")


func test_the_first_hit_on_a_ship_costs_standing_once_and_a_kill_more_and_pleases_its_enemies():
	var player = _ship("player", "player")
	var victim = _ship("verdant")
	victim.apply_damage(10.0, player)
	victim.apply_damage(10.0, player)
	assert_almost_eq(Standing.of("verdant"), -Constants.STANDING_ATTACK, 0.0001, "Once per ship")
	victim.apply_damage(200.0, player)
	assert_almost_eq(Standing.of("verdant"), -Constants.STANDING_ATTACK - Constants.STANDING_KILL, 0.0001)
	assert_almost_eq(Standing.of("violet"), Constants.STANDING_KILL_ENEMY, 0.0001, "Verdant's enemy")
	assert_almost_eq(Standing.of("raiders"), -1.0 + Constants.STANDING_KILL_ENEMY, 0.0001, "Raiders are at war with Verdant too")


func test_kills_by_others_leave_standing_alone():
	var victim = _ship("verdant")
	victim.apply_damage(200.0, _ship("violet"))
	assert_eq(Standing.of("verdant"), 0.0)
	assert_eq(Standing.of("violet"), 0.0)


func test_enough_bad_blood_turns_a_faction_hostile():
	var player = _ship("player", "player")
	Standing.change("verdant", Constants.STANDING_HOSTILE - 0.01)
	assert_true(Standing.is_hostile("verdant"))
	assert_true(_ship("verdant").is_enemy_of(player))
	Standing.change("verdant", -5.0)
	assert_eq(Standing.of("verdant"), -1.0, "Clamped")


func test_a_station_rolls_its_markup_once_and_keeps_it():
	var markup: float = Market.markup("station_a")
	assert_between(markup, 0.0, Constants.PRICE_MARKUP_MAX)
	assert_eq(Market.markup("station_a"), markup)
	assert_true(GameState.station_markups.has("station_a"), "Saved with the game")


func test_prices_follow_value_markup_and_standing():
	GameState.station_markups = {"s": 0.2}
	assert_eq(Market.price(1000.0, "s"), 1200)
	Standing.change("verdant", 1.0)
	assert_eq(Market.price(1000.0, "s", "verdant"), int(round(1200 * (1.0 - Constants.PRICE_STANDING_SHARE))), "Trusted: cheaper")
	assert_eq(Market.part_sale_price(1000.0, "s"), 600)


func test_buying_and_selling_at_one_station_never_pays_whatever_the_standing():
	GameState.station_markups = {"s": 0.3}
	for value in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		GameState.player_standing["verdant"] = value
		assert_true(Market.cargo_sale_price(1000.0, "s", "verdant") < Market.price(1000.0, "s", "verdant"), "Standing %.1f" % value)


func test_a_war_kill_pays_the_war_bounty_and_posts_one_on_the_killer():
	var hunter = _ship("verdant")
	var prey = _ship("violet")
	hunter.wallet = 0.0
	prey.apply_damage(500.0, hunter)
	var war: float = Constants.BOUNTY_WAR_SHARE * prey.get_value()
	assert_true(war > 0.0)
	assert_almost_eq(prey.bounty_paid, war, 0.01)
	assert_almost_eq(hunter.wallet, war, 0.01, "Paid into the wallet")
	assert_almost_eq(float(hunter.bounties.get("violet", 0.0)), Constants.BOUNTY_POST_SHARE * prey.get_value(), 0.01, "Violet wants it dead")


func test_the_player_collects_a_posting_from_a_faction_that_is_not_hostile_and_carries_its_own():
	var player = _ship("player", "player")
	var ace = _ship("violet")
	ace.bounties = {"verdant": 300.0, "violet": 50.0}
	GameState.player_bank = 0
	ace.apply_damage(500.0, player)
	var expected: float = 300.0 + 50.0 + Constants.BOUNTY_WAR_SHARE * ace.get_value()  # Verdant's war bounty
	assert_eq(GameState.player_bank, int(round(expected)))
	assert_true(ace.bounties.empty(), "Postings lapse with the ship")
	assert_true(GameState.player_bounties.has("violet"), "Violet posts on the player")


func test_ships_hunt_a_ship_with_a_claimable_posting_worth_their_while():
	var player = _ship("player", "player")
	var hunter = _ship("verdant")
	assert_false(hunter.is_enemy_of(player))
	GameState.player_bounties = {"verdant": 1000000.0}
	assert_true(hunter.is_enemy_of(player), "Verdant pays its own postings")
	assert_false(_ship("violet").is_enemy_of(player), "Violet is at war with Verdant: it does not claim Verdant's postings")


func test_a_jump_burns_fuel_by_mass_and_selling_the_hold_keeps_it():
	var Fuel = load("res://src/core/systems/fuel.gd")
	var ship = _ship("player", "player")
	ship.cargo_capacity = 1000
	ship.mass = 6000.0
	assert_eq(Fuel.jump_cost(ship), int(ceil(6000.0 / Constants.FUEL_MASS_PER_UNIT)))
	assert_ne(Fuel.burn_for_jump(ship), "", "No fuel, no jump")
	ship.add_cargo(Constants.FUEL_COMMODITY, 100)
	ship.add_cargo("commodity_scrap", 2)
	var cost: int = Fuel.jump_cost(ship)  # The load counts
	assert_eq(Fuel.burn_for_jump(ship), "")
	assert_eq(Fuel.carried(ship), 100 - cost)
	GameState.station_markups = {"s": 0.0}
	Market.sell_hold(ship, "s")
	assert_eq(Fuel.carried(ship), 100 - cost, "Fuel stays aboard")
	assert_false(ship.cargo.has("commodity_scrap"))
