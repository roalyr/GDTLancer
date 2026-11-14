# Tests for SectorEconomy: a sector's market as Market prices it, its routes, and its problems (stock
# that pays nowhere in the sector, a haven that pays as much as it charges).

extends GutTest

const SectorEconomy = preload("res://src/core/validation/sector_economy.gd")
const GOODS = {"commodity_biotech": {"name": "Biotech", "value": 100.0, "mass": 30.0}}


func _haven(id: String, buys: Dictionary, sells: Dictionary) -> Dictionary:
	return {"id": id, "name": id.capitalize(), "faction": "", "services": {"buys": buys, "sells": sells}}


func test_prices_follow_the_havens_factors_and_the_sell_share():
	var maker := _haven("maker", {"*": 0.9}, {"commodity_biotech": 0.6})
	assert_eq(SectorEconomy.charge(maker, "commodity_biotech", 100.0), 60.0)
	assert_almost_eq(SectorEconomy.pays(maker, "commodity_biotech", 100.0), 90.0 * Constants.PRICE_CARGO_SELL_SHARE, 0.001, "* stands for anything else")
	assert_eq(SectorEconomy.pays(_haven("picky", {"commodity_ore": 1.0}, {}), "commodity_biotech", 100.0), 0.0, "It buys nothing it does not list")


func test_routes_run_from_each_seller_to_every_other_buyer():
	var havens := [_haven("maker", {"commodity_biotech": 0.3}, {"commodity_biotech": 0.6}), _haven("market", {"commodity_biotech": 1.4}, {}),
		_haven("dump", {"*": 0.5}, {})]
	var routes: Array = SectorEconomy.routes(havens, GOODS)
	assert_eq(routes.size(), 2, "The maker to each other buyer; never to itself")
	var to_market: Dictionary = routes[0] if routes[0].to == 1 else routes[1]
	assert_eq([to_market.buy, to_market.sale], [60, int(round(140.0 * Constants.PRICE_CARGO_SELL_SHARE))])
	assert_eq(to_market.worst, int(round(to_market.sale - 60.0 * (1.0 + Constants.PRICE_MARKUP_MAX))), "Markups against it: the seller's at its highest")


func test_stock_that_pays_nowhere_in_the_sector_is_a_problem():
	var havens := [_haven("port", {"commodity_biotech": 0.6}, {"commodity_biotech": 1.0}), _haven("buyer", {"commodity_biotech": 1.3}, {})]
	var found: Array = SectorEconomy.problems(havens, GOODS)
	assert_eq(found.size(), 1, "1.3 x the sell share is barely over 1.0")
	assert_eq(found[0].kind, "no_outlet")
	assert_true(found[0].hard, "In 0.x stock must pay in its own sector")
	assert_string_contains(found[0].text, "Buyer")
	havens[1].services.buys.commodity_biotech = 1.5
	assert_eq(SectorEconomy.problems(havens, GOODS), [], "1.5 x the share pays enough")


func test_a_haven_that_buys_back_its_stock_dearer_is_a_problem():
	var havens := [_haven("maker", {"*": 0.9}, {"commodity_biotech": 0.7}), _haven("buyer", {"commodity_biotech": 1.4}, {})]
	var found: Array = SectorEconomy.problems(havens, GOODS)
	assert_eq(found.size(), 1)
	assert_eq(found[0].kind, "loop", "0.9 x the share pays more than 0.7 with the best standing")
	havens[0].services.buys["commodity_biotech"] = 0.5
	assert_eq(SectorEconomy.problems(havens, GOODS), [], "Its own good bought back cheap")


func test_the_arena_keeps_its_problems_as_warnings():
	var havens := [_haven("port", {}, {"commodity_biotech": 1.0})]
	var found: Array = SectorEconomy.problems(havens, GOODS, true)
	assert_eq(found.size(), 1)
	assert_false(found[0].hard)
	assert_string_contains(found[0].text, "nobody else here buys it")


func test_every_played_sector_s_market_passes():
	var market: Array = []
	for problem in load("res://src/core/validation/content_validator.gd").sectors():
		if " sells " in problem.problem:
			market.append(problem.problem)
	assert_eq(market, [], "Every played sector's stock pays somewhere, and no haven pays to buy back")


func test_fuel_is_burnt_not_traded_it_needs_no_outlet_but_no_loop_either():
	var goods := {Constants.FUEL_COMMODITY: {"name": "Fuel", "value": 25.0, "mass": 10.0}}
	var port := _haven("port", {"*": 0.9}, {Constants.FUEL_COMMODITY: 1.0})
	var havens := [port, _haven("other", {"*": 0.9}, {})]
	assert_eq(SectorEconomy.routes(havens, goods).size(), 0, "No route: nobody hauls fuel to sell it")
	assert_eq(SectorEconomy.problems(havens, goods).size(), 0, "and no outlet needed")
	var leaky := _haven("leaky", {"*": 2.0}, {Constants.FUEL_COMMODITY: 1.0})
	var kinds: Array = []
	for problem in SectorEconomy.problems([leaky], goods):
		kinds.append(problem.kind)
	assert_eq(kinds, ["loop"], "Buying it back for what it costs still pays without flying")
