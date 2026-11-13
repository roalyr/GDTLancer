# SectorEconomy: a sector's market as Market prices it, from its havens' buys and sells (Havens):
# what each haven charges and pays for every commodity, every route from a haven that sells one to
# another of the sector that buys it, and what is wrong with them. Prices are a stranger's (standing
# 0) at even markups (none: each station's markup rolls 0..PRICE_MARKUP_MAX on top of both ends).
# The content validator (sectors) and the development tool's economy view (tools/devtool/economy.py)
# use it. Havens are specs (HavenMarker.to_spec: id, name, faction, services.buys / sells);
# commodities {id: {"name", "value" (WP), "mass" (kg a unit)}}.

extends Reference

# A haven's stock should fetch at least this share more than its price somewhere else in its sector.
const MIN_MARGIN_SHARE = 0.1
# 0.x has one sector to trade in: stock that pays nowhere in its sector pays nowhere, a content
# problem. Once ships carry cargo between sectors it may pay in another: make this false, and it is
# only a warning (the economy view still shows it).
const STOCK_MUST_PAY_IN_SECTOR = true


# WP one unit costs at the haven (0: it does not sell it).
static func charge(haven: Dictionary, commodity_id: String, value: float) -> float:
	var factor: float = float(haven.get("services", {}).get("sells", {}).get(commodity_id, 0.0))
	return value * factor if factor > 0.0 else 0.0


# WP one unit fetches at the haven (0: it does not buy it); Havens.buys' rule ("*": anything else).
static func pays(haven: Dictionary, commodity_id: String, value: float) -> float:
	var buys: Dictionary = haven.get("services", {}).get("buys", {})
	var factor: float = float(buys.get(commodity_id, buys.get("*", 0.0)))
	return value * factor * Constants.PRICE_CARGO_SELL_SHARE if factor > 0.0 else 0.0


# Every route: [{commodity, from, to (indexes in havens), buy, sale (WP a unit), worst, best (the
# margin with both markups against it, and for it)}].
static func routes(havens: Array, commodities: Dictionary) -> Array:
	var top: float = 1.0 + Constants.PRICE_MARKUP_MAX
	var out: Array = []
	for from in havens.size():
		for commodity_id in havens[from].get("services", {}).get("sells", {}):
			if not commodities.has(commodity_id):
				continue
			var value: float = float(commodities[commodity_id].value)
			var cost: float = charge(havens[from], commodity_id, value)
			if cost <= 0.0:
				continue
			for to in havens.size():
				var sale: float = pays(havens[to], commodity_id, value)
				if to == from or sale <= 0.0:
					continue
				out.append({"commodity": commodity_id, "from": from, "to": to, "buy": int(round(cost)), "sale": int(round(sale)),
					"worst": int(round(sale - cost * top)), "best": int(round(sale * top - cost))})
	return out


# What is wrong with the sector's market: [{kind, haven (id), commodity, hard (a content problem, not
# only a warning), text}]. Kinds:
#   "loop": the haven pays as much for its own stock as it charges, once standing helps both ways
#     (buying and selling back there pays, no flying needed);
#   "no_outlet": no other haven of the sector pays MIN_MARGIN_SHARE more than the haven charges.
# `practice`: a sector only NPCs see (the evolution arena) keeps its rules as warnings.
static func problems(havens: Array, commodities: Dictionary, practice: bool = false) -> Array:
	var out: Array = []
	var share: float = Constants.PRICE_STANDING_SHARE
	for haven in havens:
		for commodity_id in haven.get("services", {}).get("sells", {}):
			if not commodities.has(commodity_id):
				continue
			var item: Dictionary = commodities[commodity_id]
			var value: float = float(item.value)
			var cost: float = charge(haven, commodity_id, value)
			if cost <= 0.0:
				continue
			var name: String = str(item.get("name", commodity_id))
			var back: float = pays(haven, commodity_id, value)
			if back * (1.0 + share) >= cost * (1.0 - share):
				out.append({"kind": "loop", "haven": haven.id, "commodity": commodity_id, "hard": not practice,
					"text": "%s sells %s for %d WP and buys it back for %d (%d and %d with the best standing): buying and selling it there pays: its buys should pay at most %d for it" % [
						haven.name, name, round(cost), round(back), round(cost * (1.0 - share)), round(back * (1.0 + share)),
						floor(cost * (1.0 - share) / (1.0 + share))]})
			var best := 0.0
			var best_at := ""
			for other in havens:
				var sale: float = pays(other, commodity_id, value)
				if other.id != haven.id and sale > best:
					best = sale
					best_at = str(other.name)
			if best < cost * (1.0 + MIN_MARGIN_SHARE):
				out.append({"kind": "no_outlet", "haven": haven.id, "commodity": commodity_id, "hard": STOCK_MUST_PAY_IN_SECTOR and not practice,
					"text": "%s sells %s for %d WP, but %s: stock should fetch %d%% more somewhere in its sector (lower its sells, or raise a buyer's buys)" % [
						haven.name, name, round(cost), "nobody else here buys it" if best_at == "" else "the best price for it here is %d at %s (%+d%%)" % [
							round(best), best_at, round(100.0 * (best / cost - 1.0))], round(100.0 * MIN_MARGIN_SHARE)]})
	return out
