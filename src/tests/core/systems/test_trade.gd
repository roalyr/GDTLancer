# Tests for trading between stations: what havens sell, the best trade for a faction (its own havens
# and the neutral ones), the trader family, and a docked trader buying its cargo.

extends GutTest

const Market = preload("res://src/core/systems/market.gd")
const Havens = preload("res://src/core/systems/havens.gd")
const Genome = preload("res://src/core/evolution/genome.gd")

var _saved: Dictionary = {}


func before_each():
	_saved = TemplateDatabase.assets_commodities
	var goods := {}
	for id in ["commodity_biotech", "commodity_tech"]:
		var good := CommodityTemplate.new()
		good.template_id = id
		good.base_value = 60
		good.unit_mass = 25.0
		goods[id] = good
	TemplateDatabase.assets_commodities = goods
	GameState.station_markups = {}  # Every station at no markup, for good
	GameState.station_markup_until = {}
	for id in ["station_arena_home"] + Havens.neighbours("station_arena_home"):
		GameState.station_markups[id] = 0.0
		GameState.station_markup_until[id] = INF


func after_each():
	TemplateDatabase.assets_commodities = _saved
	GameState.reset_state()


func test_the_arena_trade_is_symmetric():
	var green: Dictionary = Market.best_trade("arena_verdant_haven", "verdant")
	var purple: Dictionary = Market.best_trade("arena_violet_haven", "violet")
	assert_eq(green.get("commodity"), "commodity_biotech", "Verdant makes biotech")
	assert_eq(purple.get("commodity"), "commodity_tech", "Violet makes tech")
	assert_eq(green.get("to"), "station_arena_home", "Sold at the free port")
	assert_eq(purple.get("to"), "station_arena_home")
	var port: Vector3 = Havens.spec("station_arena_home").at
	assert_almost_eq(port.distance_to(Havens.spec("arena_verdant_haven").at), port.distance_to(Havens.spec("arena_violet_haven").at), 1.0, "As far from either haven")


func test_a_trader_sells_only_where_it_is_welcome():
	var back: Dictionary = Market.best_trade("station_arena_home", "verdant")
	assert_eq(back.get("to"), "arena_verdant_haven", "Verdant brings tech home, not to violet")
	assert_eq(back.get("commodity"), "commodity_tech")
	assert_true(Market.best_trade("arena_raider_den", "raiders").empty(), "The den sells nothing")


func test_a_trade_round_pays_at_any_markup():
	var verdant_biotech: float = 60.0 * Havens.sells("arena_verdant_haven").commodity_biotech * (1.0 + Constants.PRICE_MARKUP_MAX)
	var port_biotech: float = 60.0 * Havens.buys("station_arena_home", "commodity_biotech") * Constants.PRICE_CARGO_SELL_SHARE
	assert_gt(port_biotech, verdant_biotech * 0.9, "Bought dearest, sold cheapest: about even at worst")


func test_traders_are_their_own_family():
	var genome: Dictionary = Genome.seed_genome(Constants.EVO_FACTION_SEEDS[8])  # The heavy trader, armed
	assert_eq(Genome.family(Genome.niche(genome)), "trader")
	assert_true(Genome.niche(genome).ends_with("|trader|-"), "Its guns make no range niche: " + Genome.niche(genome))
	genome.behavior.trade = 0.0
	assert_ne(Genome.family(Genome.niche(genome)), "trader", "Not without the gene")
