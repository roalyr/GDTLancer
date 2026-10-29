# Tests for Havens and the market at them: each haven buys its own goods at its own price, offers
# its own services, and welcomes its own.

extends GutTest

const Havens = preload("res://src/core/systems/havens.gd")
const Market = preload("res://src/core/systems/market.gd")


func test_services_differ_by_haven():
	assert_true(Havens.offers("verdant_haven", "rearm"))
	assert_false(Havens.offers("verdant_post", "rearm"), "A post only repairs")
	assert_false(Havens.offers("elace_refinery", "repair"), "A refinery only buys")
	assert_true(Havens.offers("some_other_station", "repair"), "A station that is no haven serves everyone")


func test_ore_sells_best_at_the_refinery_and_not_everywhere():
	var saved: Dictionary = TemplateDatabase.assets_commodities
	var templates := {}
	for id in ["commodity_ore", "commodity_tech"]:
		var commodity = CommodityTemplate.new()
		commodity.template_id = id
		commodity.base_value = 100
		templates[id] = commodity
	TemplateDatabase.assets_commodities = templates
	for id in ["elace_refinery", "verdant_haven", "raider_den", "verdant_post"]:
		GameState.station_markups[id] = 0.0  # The same markup everywhere: only the havens' factors differ
		GameState.station_markup_until[id] = INF
	var refinery: int = Market.commodity_sale_price("commodity_ore", "elace_refinery")
	var haven: int = Market.commodity_sale_price("commodity_ore", "verdant_haven")
	var den: int = Market.commodity_sale_price("commodity_ore", "raider_den")
	var tech_at_refinery: int = Market.commodity_sale_price("commodity_tech", "elace_refinery")
	var tech_at_post: int = Market.commodity_sale_price("commodity_tech", "verdant_post")
	TemplateDatabase.assets_commodities = saved
	GameState.reset_state()
	assert_gt(refinery, haven)
	assert_gt(haven, den, "The den pays less")
	assert_eq(tech_at_refinery, 0, "The refinery buys no tech")
	assert_eq(tech_at_post, 0, "nor does a post")


func test_who_is_welcome():
	assert_true(Havens.welcome("verdant", "verdant_haven"))
	assert_false(Havens.welcome("violet", "verdant_haven"))
	assert_true(Havens.welcome("violet", "station_elace_home"), "Neutral ports take the factions")
	assert_false(Havens.welcome("raiders", "station_elace_home"), "but not raiders")
	assert_true(Havens.welcome("raiders", "raider_den"))


func test_populated_havens_are_those_with_ships():
	var ids: Array = []
	for haven in Havens.populated("sector_elace"):
		ids.append(haven.id)
	assert_eq(ids, ["verdant_haven", "verdant_post", "violet_haven", "violet_post", "raider_den", "xenohive"])
