"""economy.py on a made-up sector: top speed with cargo, a trip's time and WP an hour, routes and
hulls ranked by it, the market grid, the scope, and the text report."""

import math
import unittest

from devtool import economy

ROUTE = {"commodity": "commodity_ore", "name": "Ore", "mass": 50.0, "sector": "sector_x", "from": "port", "from_name": "Port",
         "to": "mill", "to_name": "Mill", "layout": "res://l.tscn", "node": "Havens/Port", "buy": 40, "sale": 55, "worst": 35,
         "best": 75, "km": 10.0, "factions": ["blue"]}
ECONOMY = {
    "sector": "sector_x", "layout": "res://l.tscn", "practice": False, "drag": 0.5, "dock_time": 10.0, "markup_max": 0.5,
    "standing_share": 0.1, "sell_share": 0.8, "min_margin": 0.1, "must_pay_in_sector": True,
    "havens": [{"id": "port", "name": "Port", "faction": "", "node": "Havens/Port", "at": [0, 0, 0], "sells": {"commodity_ore": 40}, "buys": {}},
               {"id": "mill", "name": "Mill", "faction": "blue", "node": "Havens/Mill", "at": [10000, 0, 0], "sells": {}, "buys": {"commodity_ore": 55}}],
    "commodities": [{"id": "commodity_ore", "name": "Ore", "value": 50.0, "mass": 50.0, "sold_at": ["port"], "bought_at": ["mill"]},
                    {"id": "commodity_relic", "name": "Relic", "value": 120.0, "mass": 40.0, "sold_at": [], "bought_at": []}],
    "routes": [ROUTE, dict(ROUTE, to="dump", to_name="Dump", sale=30, worst=-30, best=-5, km=5.0, factions=[])],
    "problems": [],
    "ships": [{"id": "hauler", "mass": 1000.0, "thrust": 50000.0, "hold": 20, "value": 3000},
              {"id": "trader_medium", "mass": 2000.0, "thrust": 50000.0, "hold": 10, "value": 1000},
              {"id": "shuttle", "mass": 1000.0, "thrust": 50000.0, "hold": 0, "value": 500}],
}


class EconomyTest(unittest.TestCase):
    def test_cargo_slows_a_ship(self):
        hauler = economy.ship(ECONOMY, "hauler")
        self.assertEqual(economy.top_speed(hauler, 0.5), 100.0, "thrust / (mass * drag)")
        self.assertEqual(economy.top_speed(hauler, 0.5, 1000.0), 50.0, "A tonne of cargo doubles a tonne's mass")

    def test_the_default_ship_is_the_medium_trader(self):
        self.assertEqual(economy.ship(ECONOMY, "")["id"], "trader_medium")
        self.assertEqual(economy.ship(ECONOMY, "nobody")["id"], "trader_medium")
        self.assertIsNone(economy.ship({"ships": []}, ""))

    def test_a_trip_is_a_full_hold_out_and_back_empty(self):
        done = economy.trip(ROUTE, economy.ship(ECONOMY, "hauler"), ECONOMY)
        self.assertEqual(done["units"], 20)
        self.assertEqual(done["cargo_kg"], 1000.0)
        self.assertEqual(done["load"], 800)
        self.assertEqual(done["profit"], 300, "15 WP a unit, 20 units")
        self.assertAlmostEqual(done["loaded"], 10000.0 / 50.0 + 4.0, msg="Half speed loaded, plus 2/drag")
        self.assertAlmostEqual(done["empty"], 10000.0 / 100.0 + 4.0)
        self.assertAlmostEqual(done["stops"], 2 * (10.0 + economy.APPROACH_TIME))
        self.assertAlmostEqual(done["wp_hour"], 300 * 3600.0 / done["total"])

    def test_a_ship_with_no_hold_earns_nothing(self):
        done = economy.trip(ROUTE, economy.ship(ECONOMY, "shuttle"), ECONOMY)
        self.assertEqual(done["wp_hour"], 0.0)
        self.assertTrue(math.isinf(economy.leg_seconds(1.0, 0.0, 0.5)))

    def test_routes_and_hulls_rank_by_wp_an_hour(self):
        ranked = economy.ranked_routes(ECONOMY, economy.ship(ECONOMY, "hauler"))
        self.assertEqual([route["to"] for route, _ in ranked], ["mill", "dump"])
        rows = economy.ship_rows(ECONOMY)
        self.assertEqual(rows[0]["ship"]["id"], "hauler", "The biggest hold earns most")
        self.assertEqual(rows[0]["route"]["to"], "mill")
        self.assertAlmostEqual(rows[0]["hours"], 3000 / rows[0]["trip"]["wp_hour"])
        shuttle = next(row for row in rows if row["ship"]["id"] == "shuttle")
        self.assertIsNone(shuttle["route"])
        self.assertEqual(economy.duration(shuttle["hours"] * 3600.0), "never")

    def test_the_market_grid_leaves_out_goods_no_haven_trades(self):
        goods, rows = economy.market_grid(ECONOMY)
        self.assertEqual(goods, ["commodity_ore"])
        self.assertEqual(rows[0][1], [(40, None)])
        self.assertEqual(rows[1][1], [(None, 55)])

    def test_the_scope_has_the_sector_s_numbers_and_what_is_left(self):
        lines = economy.scope_lines(ECONOMY)
        self.assertIn("0..50%", dict((what, about) for what, about, _ in lines)["Markups"])
        statuses = {status for _, _, status in lines}
        self.assertTrue({"shown", "estimated", "to estimate", "after 0.x"} <= statuses)
        self.assertTrue(statuses <= set(economy.STATUS_COLOURS))

    def test_the_report_names_problems_routes_and_hulls(self):
        view = dict(ECONOMY, problems=[{"kind": "no_outlet", "haven": "port", "commodity": "commodity_ore", "hard": True, "text": "Port sells Ore"}])
        text = "\n".join(economy.report(view, "hauler"))
        self.assertIn("ERROR Port sells Ore", text)
        self.assertIn("Routes for hauler", text)
        self.assertIn("earns its 3000 WP", text)
        self.assertIn("after 0.x", text)
        self.assertEqual(economy.duration(75), "1:15")
        self.assertEqual(economy.duration(5400), "1.5 h")


if __name__ == "__main__":
    unittest.main()
